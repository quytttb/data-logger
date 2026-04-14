#!/usr/bin/env bash
# ============================================================
# deploy.sh — Build & Deploy DataLogger lên Raspberry Pi
#
# CÁCH DÙNG:
#   ./deploy.sh              → Sync + Build Nuitka + Restart service
#   ./deploy.sh --quick      → Sync + setup venv (nếu cần) + chạy Python source
#   ./deploy.sh --build-only → Chỉ build Nuitka trên RPi
#   ./deploy.sh --install    → Cài systemd service (chạy 1 lần đầu)
#   ./deploy.sh --uninstall  → Gỡ service + dừng tiến trình + xóa thư mục app trên Pi
#   ./deploy.sh --uninstall --purge-data  → Thêm: xóa luôn var/ (DB, config, log)
#   ./deploy.sh --help       → Hiện hướng dẫn này
#
# Cấu hình qua biến môi trường:
#   PI_HOST=192.168.31.186 ./deploy.sh --quick
#   PI_USER=pi PI_PASS=pi PI_HOST=x.x.x.x ./deploy.sh
# ============================================================

set -uo pipefail   # -e bỏ để lệnh || true hoạt động đúng

# ─── Cấu hình RPi ───────────────────────────────────────────
PI_USER="${PI_USER:-pi}"
PI_HOST="${PI_HOST:-192.168.31.185}"
PI_PASS="${PI_PASS:-pi}"
PI_BASE_DIR="/home/${PI_USER}/data-logger"
PI_APP_DIR="${PI_BASE_DIR}/data-logger"
PI_VAR_DIR="${PI_BASE_DIR}/var"
SERVICE_NAME="datalogger"
SERVICE_FILE="${PI_APP_DIR}/scripts/datalogger.service"

# ─── Colors ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Helper: chạy lệnh trên RPi ─────────────────────────────
ssh_run() {
    sshpass -p "${PI_PASS}" ssh \
        -o StrictHostKeyChecking=no \
        -o ConnectTimeout=10 \
        -o ServerAliveInterval=30 \
        "${PI_USER}@${PI_HOST}" "$@"
}

# ─── Xử lý tham số ──────────────────────────────────────────
MODE="full"
PURGE_DATA=false
for arg in "$@"; do
    case "$arg" in
        --quick)       MODE="quick" ;;
        --build-only)  MODE="build" ;;
        --install)     MODE="install" ;;
        --uninstall)   MODE="uninstall" ;;
        --purge-data)  PURGE_DATA=true ;;
        --help|-h)     sed -n '2,17p' "$0"; exit 0 ;;
        *) die "Tham số không hợp lệ: $arg" ;;
    esac
done

if [[ "$MODE" != "uninstall" ]] && [[ "$PURGE_DATA" == true ]]; then
    die "Chỉ dùng --purge-data cùng với --uninstall"
fi

# ─── Kiểm tra công cụ trên máy dev ──────────────────────────
for tool in sshpass rsync; do
    command -v "$tool" &>/dev/null || die "Cần cài: sudo apt install $tool"
done

# ─── Kiểm tra kết nối Pi ────────────────────────────────────
step_check_connection() {
    info "Kiểm tra kết nối ${PI_USER}@${PI_HOST}..."
    ssh_run "echo 'OK'" || die "Không kết nối được tới ${PI_HOST}. Kiểm tra IP, SSH, và sshpass."
    success "Kết nối OK"
}

# ─── Bước 1: Đồng bộ source lên RPi ────────────────────────
step_sync() {
    info "Đồng bộ source code → ${PI_USER}@${PI_HOST}:${PI_APP_DIR}/"
    # Đảm bảo thư mục đích tồn tại (cần cho fresh Pi)
    ssh_run "mkdir -p '${PI_APP_DIR}'"
    sshpass -p "${PI_PASS}" rsync -avz --progress \
        --exclude='.venv/' \
        --exclude='dist/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='.git/' \
        --exclude='tests/' \
        --exclude='data/datalogger.db' \
        --exclude='data/reports/' \
        --exclude='data/screenshots/' \
        --exclude='logs/' \
        "$(dirname "$(realpath "$0")")/" \
        "${PI_USER}@${PI_HOST}:${PI_APP_DIR}/"
    success "Sync hoàn tất"
}

# ─── Biên dịch Qt Linguist trên Pi (.ts → .qm) ─────────────
step_i18n_qm() {
    info "Biên dịch i18n trên Pi (cài qt6-l10n-tools nếu cần + lrelease)…"
    ssh_run "cd '${PI_APP_DIR}' && if ! command -v lrelease-qt6 >/dev/null 2>&1 && ! command -v lrelease >/dev/null 2>&1; then sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qt6-l10n-tools 2>/dev/null || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qttools5-dev-tools 2>/dev/null || true; fi && if command -v lrelease-qt6 >/dev/null 2>&1; then lrelease-qt6 i18n/data_logger_vi.ts -qm i18n/data_logger_vi.qm && echo '[i18n] lrelease-qt6 OK'; elif command -v lrelease >/dev/null 2>&1; then lrelease i18n/data_logger_vi.ts -qm i18n/data_logger_vi.qm && echo '[i18n] lrelease OK'; else echo '[i18n] bỏ qua (cài tay: sudo apt install qt6-l10n-tools)'; fi" \
        || warn "lrelease trên Pi thất bại — chạy trên Pi: sudo apt install qt6-l10n-tools && bash scripts/compile-i18n.sh"
}

# ─── Bước 2: Chuẩn bị hệ thống & venv ──────────────────────
# Truyền PI_APP_DIR qua biến môi trường (tránh nhầm user khi dùng ls /home/*/)
step_setup_venv() {
    info "Kiểm tra và cài đặt môi trường Python..."
    ssh_run "APP_DIR='${PI_APP_DIR}' bash -s" <<'EOS'
set -e
cd "$APP_DIR"

echo "[SETUP] App dir: $APP_DIR"

# Đảm bảo python3-venv có sẵn
if ! python3 -c "import venv" &>/dev/null; then
    echo "[SETUP] Cài python3-venv..."
    sudo apt-get install -y python3-venv python3-pip --quiet
fi

need_venv=false
if [ ! -x ".venv/bin/python" ]; then
    need_venv=true
    echo "[SETUP] Thiếu .venv/bin/python"
elif [ ! -x ".venv/bin/pip" ]; then
    need_venv=true
    echo "[SETUP] Thiếu .venv/bin/pip (venv hỏng)"
elif ! .venv/bin/python -m pip --version &>/dev/null; then
    need_venv=true
    echo "[SETUP] python -m pip không chạy được (venv hỏng)"
fi

if [ "$need_venv" = true ]; then
    echo "[SETUP] Tạo lại virtual environment từ đầu..."
    rm -rf .venv
    python3 -m venv .venv
    echo "[SETUP] venv mới đã tạo"
fi

echo "[SETUP] Cập nhật pip..."
.venv/bin/python -m pip install --upgrade pip --quiet

echo "[SETUP] Cài dependencies (có thể mất 5-15 phút với PySide6)..."
.venv/bin/pip install \
    "pyside6>=6.7" \
    "sqlmodel>=0.0.22" \
    "pymodbus[serial]>=3.7" \
    "pyserial>=3.5" \
    "asyncssh>=2.17" \
    "cryptography>=43.0" \
    "bcrypt>=4.0" \
    --quiet

echo "[SETUP] Kiểm tra import..."
.venv/bin/python -c "
from PySide6.QtCore import QCoreApplication
import sqlmodel, pymodbus, asyncssh, cryptography
print('All imports OK')
"

if ! groups | grep -q dialout; then
    echo "[SETUP] Thêm user vào group dialout..."
    sudo usermod -a -G dialout "$USER" || true
fi

echo "[SETUP] Done!"
EOS
    success "Venv và dependencies đã sẵn sàng"
}

# ─── Gỡ cài đặt hoàn toàn trên Pi ────────────────────────────
step_uninstall() {
    info "Gỡ DataLogger trên ${PI_USER}@${PI_HOST}..."
    if [[ "$PURGE_DATA" == true ]]; then
        warn "Kèm --purge-data: sẽ xóa DB, secret.key và toàn bộ log tại ${PI_VAR_DIR}/"
    fi

    ssh_run "APP_DIR='${PI_APP_DIR}' VAR_DIR='${PI_VAR_DIR}' BASE_DIR='${PI_BASE_DIR}' SVC='${SERVICE_NAME}' PURGE='${PURGE_DATA}' bash -s" <<'EOS'
set -e
echo "[UNINSTALL] Dừng systemd service..."
sudo systemctl stop "$SVC" 2>/dev/null || true
sudo systemctl disable "$SVC" 2>/dev/null || true
sudo rm -f "/etc/systemd/system/${SVC}.service"
sudo systemctl daemon-reload
sudo systemctl reset-failed "$SVC" 2>/dev/null || true

echo "[UNINSTALL] Dừng tiến trình GUI / Python / binary..."
pkill -f "data-logger/data-logger.*main.py" 2>/dev/null || true
pkill -f ".venv/bin/python main.py" 2>/dev/null || true
pkill -f "python main.py" 2>/dev/null || true
# Binary Nuitka (tên output mặc định)
pkill -f "DataLogger.dist/DataLogger" 2>/dev/null || true
pkill -f "/dist/DataLogger.dist/DataLogger" 2>/dev/null || true
sleep 2

echo "[UNINSTALL] Xóa shortcut menu..."
rm -f "${HOME}/.local/share/applications/data-logger.desktop"
update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true

if [ -d "$APP_DIR" ]; then
    echo "[UNINSTALL] Xóa thư mục ứng dụng: $APP_DIR"
    rm -rf "$APP_DIR"
fi

if [ "$PURGE" = "true" ] && [ -d "$VAR_DIR" ]; then
    echo "[UNINSTALL] Xóa dữ liệu persistent: $VAR_DIR"
    rm -rf "$VAR_DIR"
fi

# Xóa thư mục gốc nếu trống (chỉ khi đã xóa app)
if [ -d "$BASE_DIR" ]; then
    rmdir "$BASE_DIR" 2>/dev/null && echo "[UNINSTALL] Đã xóa $BASE_DIR (trống)" || true
fi

echo "[UNINSTALL] Hoàn tất."
EOS
    success "Đã gỡ cài đặt trên Pi"
}

# ─── Bước 3: Tạo thư mục var/ persistent ───────────────────
step_init_var() {
    info "Khởi tạo thư mục persistent ${PI_VAR_DIR}/"
    ssh_run "mkdir -p '${PI_VAR_DIR}'/{data,config,logs,data/reports,data/screenshots}"

    # Di chuyển DB và key cũ sang var/ (migrate một lần)
    ssh_run "
        if [ -f '${PI_APP_DIR}/data/datalogger.db' ] && \
           [ ! -f '${PI_VAR_DIR}/data/datalogger.db' ]; then
            cp '${PI_APP_DIR}/data/datalogger.db' '${PI_VAR_DIR}/data/'
            echo 'Migrated: DB → var/data/'
        fi
        if [ -f '${PI_APP_DIR}/config/secret.key' ] && \
           [ ! -f '${PI_VAR_DIR}/config/secret.key' ]; then
            cp '${PI_APP_DIR}/config/secret.key' '${PI_VAR_DIR}/config/'
            echo 'Migrated: secret.key → var/config/'
        fi
    " || true
    success "var/ đã sẵn sàng"
}

# ─── Shortcut menu Raspberry Pi (.desktop) ─────────────────
step_install_desktop() {
    info "Cài shortcut menu (Data Logger + icon PNG + StartupWMClass)..."
    ssh_run "
        chmod +x '${PI_APP_DIR}/scripts/launch-data-logger.sh'
        chmod +x '${PI_APP_DIR}/deploy.sh' 2>/dev/null || true
        mkdir -p '/home/${PI_USER}/.local/share/applications'
        sed \"s|@APP_DIR@|${PI_APP_DIR}|g\" '${PI_APP_DIR}/scripts/data-logger.desktop.in' > '/home/${PI_USER}/.local/share/applications/data-logger.desktop'
        chmod 644 '/home/${PI_USER}/.local/share/applications/data-logger.desktop'
        update-desktop-database '/home/${PI_USER}/.local/share/applications' 2>/dev/null || true
    "
    success "Đã cập nhật ~/.local/share/applications/data-logger.desktop"
}

# ─── Bước 4a: Build Nuitka trên RPi ─────────────────────────
step_build() {
    info "Bắt đầu build Nuitka trên RPi (lần đầu mất ~10-20 phút)..."
    info "Theo dõi: ssh ${PI_USER}@${PI_HOST} 'tail -f /tmp/nuitka-build.log'"

    ssh_run bash <<REMOTE
set -e
cd '${PI_APP_DIR}'

if ! .venv/bin/python -m nuitka --version &>/dev/null; then
    echo '[BUILD] Cài Nuitka + patchelf + zstandard...'
    .venv/bin/pip install --quiet nuitka zstandard patchelf
fi

echo '[BUILD] Khởi động Nuitka standalone build...'
.venv/bin/python -m nuitka \\
    --standalone \\
    --enable-plugin=pyside6 \\
    --include-package=core \\
    --include-package=models \\
    --include-package=ui \\
    --include-package=workers \\
    --include-data-dir=ui/qml=ui/qml \\
    --include-data-dir=assets=assets \\
    --include-package=asyncssh \\
    --include-package=pymodbus \\
    --include-package=sqlmodel \\
    --include-package=cryptography \\
    --include-package=serial \\
    --noinclude-qt-translations \\
    --lto=yes \\
    --jobs=4 \\
    --output-dir=dist \\
    --output-filename=DataLogger \\
    main.py 2>&1 | tee /tmp/nuitka-build.log

echo '[BUILD] Xong!'
ls -lh dist/DataLogger.dist/DataLogger
REMOTE
    success "Build hoàn tất"
}

# ─── Bước 4b: Cài systemd service ───────────────────────────
step_install_service() {
    info "Cài systemd service: ${SERVICE_NAME}"
    ssh_run "
        sudo cp '${SERVICE_FILE}' '/etc/systemd/system/${SERVICE_NAME}.service'
        sudo systemctl daemon-reload
        sudo systemctl enable '${SERVICE_NAME}'
        echo 'Service enabled OK'
    "
    success "Service đã cài và enable"
}

# ─── Bước 5a: Start app (Python source mode) ─────────────────
step_start_quick() {
    info "Dừng app cũ (nếu đang chạy)..."
    ssh_run "
        pkill -f 'data-logger/data-logger.*main.py' 2>/dev/null || true
        pkill -f '.venv/bin/python main.py' 2>/dev/null || true
        pkill -f 'python main.py' 2>/dev/null || true
        pkill -f 'DataLogger.dist/DataLogger' 2>/dev/null || true
        sleep 1
    "

    info "Khởi động app (Python source mode)..."
    ssh_run bash <<REMOTE
set -e
cd '${PI_APP_DIR}'
export DATALOGGER_DATA_DIR='${PI_VAR_DIR}/data'
export DATALOGGER_CONFIG_DIR='${PI_VAR_DIR}/config'
export DATALOGGER_LOG_DIR='${PI_VAR_DIR}/logs'
export DISPLAY=:0
export XAUTHORITY=/home/${PI_USER}/.Xauthority

nohup .venv/bin/python main.py > '${PI_VAR_DIR}/logs/app.log' 2>&1 &
APP_PID=\$!
echo "Started PID=\${APP_PID}"
sleep 3
if kill -0 "\${APP_PID}" 2>/dev/null; then
    echo "App đang chạy OK"
    tail -15 '${PI_VAR_DIR}/logs/app.log'
else
    echo "App đã dừng sớm — log:"
    cat '${PI_VAR_DIR}/logs/app.log'
    exit 1
fi
REMOTE
}

# ─── Bước 5b: Restart systemd service ───────────────────────
step_restart_service() {
    info "Restart service ${SERVICE_NAME}..."
    ssh_run "
        sudo systemctl restart '${SERVICE_NAME}'
        sleep 2
        sudo systemctl status '${SERVICE_NAME}' --no-pager -l | head -25
    " || warn "Kiểm tra log: ssh ${PI_USER}@${PI_HOST} 'journalctl -u ${SERVICE_NAME} -n 50'"
    success "Service đã restart"
}

# ─── Main Flow ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo "  DataLogger Deploy  |  ${PI_USER}@${PI_HOST}"
echo "  Mode: ${MODE}"
echo "════════════════════════════════════════════"
echo ""

step_check_connection

case "$MODE" in
    uninstall)
        step_uninstall
        echo ""
        success "Gỡ cài đặt hoàn tất!"
        echo ""
        echo "  Cài lại:  PI_HOST=${PI_HOST} bash deploy.sh --quick"
        echo ""
        exit 0
        ;;
    full)
        step_sync
        step_i18n_qm
        step_setup_venv
        step_init_var
        step_install_desktop
        step_build
        ssh_run "test -f '/etc/systemd/system/${SERVICE_NAME}.service'" || step_install_service
        step_restart_service
        ;;
    quick)
        step_sync
        step_i18n_qm
        step_setup_venv
        step_init_var
        step_install_desktop
        step_start_quick
        ;;
    build)
        step_sync
        step_i18n_qm
        step_setup_venv
        step_init_var
        step_install_desktop
        step_build
        ;;
    install)
        step_sync
        step_i18n_qm
        step_setup_venv
        step_init_var
        step_install_desktop
        step_install_service
        ;;
esac

echo ""
success "Deploy hoàn tất!"
echo ""
echo "  Xem log app:  ssh ${PI_USER}@${PI_HOST} 'tail -f ${PI_VAR_DIR}/logs/app.log'"
echo "  Xem log svc:  ssh ${PI_USER}@${PI_HOST} 'journalctl -u ${SERVICE_NAME} -f'"
echo "  SSH vào Pi:   ssh ${PI_USER}@${PI_HOST}"
echo ""
