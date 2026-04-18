#!/usr/bin/env bash
# ============================================================
#  setup.sh — Cài đặt & chạy Data Logger trực tiếp trên Pi
#  Dùng khi đã có code (git clone hoặc git pull) xong rồi.
#
#  Cách dùng:
#    chmod +x setup.sh
#    ./setup.sh            # cài + chạy ngay
#    ./setup.sh --install  # chỉ cài, không chạy
#    ./setup.sh --run      # chỉ chạy (đã cài rồi)
#    ./setup.sh --service  # cài + đăng ký systemd service
# ============================================================

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON="${PYTHON:-python3}"
VENV_DIR="$APP_DIR/.venv"
LOG_DIR="$APP_DIR/var/logs"
DATA_DIR="$APP_DIR/var/data"
SERVICE_NAME="datalogger"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
MODE="${1:-}"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok()      { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}════════════════════════════════════════${RESET}"; \
             echo -e "${BOLD}  $*${RESET}"; \
             echo -e "${BOLD}════════════════════════════════════════${RESET}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
check_python() {
    if ! command -v "$PYTHON" &>/dev/null; then
        error "Không tìm thấy $PYTHON. Cài đặt: sudo apt install python3"
        exit 1
    fi
    PY_VER=$("$PYTHON" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    info "Python version: $PY_VER"
    # Cần ít nhất Python 3.11
    "$PYTHON" -c "import sys; assert sys.version_info >= (3,11), 'Cần Python 3.11+'" || {
        error "Python >= 3.11 là bắt buộc. Hiện tại: $PY_VER"
        exit 1
    }
}

create_venv() {
    if [ ! -d "$VENV_DIR" ]; then
        info "Tạo virtual environment tại $VENV_DIR ..."
        "$PYTHON" -m venv "$VENV_DIR"
        ok "Virtual environment tạo thành công."
    else
        info "Virtual environment đã tồn tại, bỏ qua tạo mới."
    fi
}

install_deps() {
    info "Cập nhật pip ..."
    "$VENV_DIR/bin/pip" install --upgrade pip --quiet

    if [ -f "$APP_DIR/pyproject.toml" ]; then
        info "Cài dependencies từ pyproject.toml ..."
        "$VENV_DIR/bin/pip" install -e "$APP_DIR" --quiet
    elif [ -f "$APP_DIR/requirements.txt" ]; then
        info "Cài dependencies từ requirements.txt ..."
        "$VENV_DIR/bin/pip" install -r "$APP_DIR/requirements.txt" --quiet
    else
        warn "Không tìm thấy pyproject.toml hoặc requirements.txt. Bỏ qua cài deps."
    fi

    # Kiểm tra import quan trọng
    info "Kiểm tra import PySide6 ..."
    "$VENV_DIR/bin/python" -c "from PySide6.QtWidgets import QApplication" 2>/dev/null \
        && ok "PySide6 OK." \
        || { error "PySide6 không import được. Thử: pip install PySide6"; exit 1; }

    info "Kiểm tra import pyserial ..."
    "$VENV_DIR/bin/python" -c "import serial" 2>/dev/null \
        && ok "pyserial OK." \
        || { warn "pyserial chưa cài. Đang cài..."; "$VENV_DIR/bin/pip" install pyserial --quiet; }
}

create_dirs() {
    mkdir -p "$LOG_DIR" "$DATA_DIR"
    info "Thư mục var/ đã sẵn sàng."
}

install_step() {
    header "Cài đặt Data Logger"
    check_python
    create_venv
    install_deps
    create_dirs
    ok "Cài đặt hoàn tất!"
}

run_step() {
    header "Khởi động Data Logger"
    if [ ! -f "$VENV_DIR/bin/python" ]; then
        error "Chưa cài đặt. Chạy: ./setup.sh --install"
        exit 1
    fi
    create_dirs
    info "Khởi động app từ $APP_DIR ..."
    cd "$APP_DIR"
    # Nếu chạy trên Pi không có màn hình thật, cần đặt DISPLAY
    # Uncomment nếu cần:
    # export DISPLAY=:0
    exec "$VENV_DIR/bin/python" main.py
}

install_service() {
    header "Đăng ký systemd service"
    if [ "$EUID" -ne 0 ]; then
        error "Cần quyền root để tạo systemd service. Chạy: sudo ./setup.sh --service"
        exit 1
    fi

    VENV_PYTHON="$VENV_DIR/bin/python"
    CURRENT_USER="${SUDO_USER:-pi}"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Data Logger Application
After=network.target graphical.target
Wants=graphical.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${APP_DIR}
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/${CURRENT_USER}/.Xauthority
ExecStart=${VENV_PYTHON} ${APP_DIR}/main.py
Restart=always
RestartSec=5
StandardOutput=append:${LOG_DIR}/service.log
StandardError=append:${LOG_DIR}/service_err.log

[Install]
WantedBy=graphical.target
EOF

    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    ok "Service '$SERVICE_NAME' đã được đăng ký và enable."
    info "Để khởi động ngay: sudo systemctl start $SERVICE_NAME"
    info "Xem log:           sudo journalctl -u $SERVICE_NAME -f"
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "$MODE" in
    --install)
        install_step
        ;;
    --run)
        run_step
        ;;
    --service)
        install_step
        install_service
        ;;
    "")
        # Mặc định: cài rồi chạy
        install_step
        run_step
        ;;
    *)
        echo "Dùng: $0 [--install | --run | --service]"
        exit 1
        ;;
esac
