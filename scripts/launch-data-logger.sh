#!/usr/bin/env bash
# Khởi chạy Data Logger từ menu desktop (Raspberry Pi OS — labwc/Wayland).
APP_DIR="${HOME}/data-logger/data-logger"
VAR_DIR="${HOME}/data-logger/var"
LAUNCH_LOG="${VAR_DIR}/logs/launch-desktop.log"

# ── Đảm bảo thư mục log tồn tại trước khi redirect ──────────────────────────
mkdir -p "${VAR_DIR}/logs"
exec >> "${LAUNCH_LOG}" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === launch-data-logger.sh start ==="

# ── Kiểm tra thư mục app ─────────────────────────────────────────────────────
cd "${APP_DIR}" || {
    notify-send "Data Logger" "Không tìm thấy: ${APP_DIR}" 2>/dev/null || true
    echo "ERROR: APP_DIR not found: ${APP_DIR}"; exit 1
}

# ── Biến display — labwc có thể không forward đủ env khi launch từ desktop ──
# Giữ nguyên nếu đã có, ngược lại dùng giá trị mặc định của Pi OS
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"

# ── Biến DataLogger ──────────────────────────────────────────────────────────
export DATALOGGER_DATA_DIR="${VAR_DIR}/data"
export DATALOGGER_CONFIG_DIR="${VAR_DIR}/config"
export DATALOGGER_LOG_DIR="${VAR_DIR}/logs"

echo "DISPLAY=${DISPLAY} WAYLAND_DISPLAY=${WAYLAND_DISPLAY} XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}"

if [ ! -x "${APP_DIR}/.venv/bin/python" ]; then
    notify-send "Data Logger" "Chưa có .venv — chạy deploy.sh --quick trên máy dev" 2>/dev/null || true
    echo "ERROR: .venv not found"; exit 1
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Launching python..."
# WM_CLASS được set qua argv_for_qt() trong main.py — KHÔNG dùng exec -a
exec "${APP_DIR}/.venv/bin/python" "${APP_DIR}/main.py"
