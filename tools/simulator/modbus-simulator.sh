#!/bin/sh
# Wrapper modbus-simulator: socat tao cap pty + Python chay slave Modbus RTU.
#
# Auto-heal tren restart/reboot:
#   1. Kill socat cu con sot (pattern dung theo link pty cua service nay),
#      tranh "Device or resource busy" khi app dang giu pty master cu.
#   2. Don symlink cu trong RuntimeDirectory truoc khi tao pty moi.
#   3. Doi pty1 duoc tao xong roi moi chay slave (tranh race luc boot).
#   4. Chay python o foreground; het python (vi bat ky ly do) => kill socat,
#      bo symlink, thoat -> systemd Restart=always tao cap pty sach khac.
#
# Tham so qua Environment trong unit (xem modbus-simulator.service).
set -u

RUN_DIR=${RUN_DIR:-/run/data-logger}
PTY0="$RUN_DIR/ttyVIRT0"
PTY1="$RUN_DIR/ttyVIRT1"
PY=${SIM_PY:-/usr/local/lib/data-logger/modbus_rtu_simulator.py}

# Kill socat cu cua chinh service nay (chi khop dung link pty cua chung ta).
pkill -f "socat pty,link=$PTY0,raw,echo=0,mode=0660 pty,link=$PTY1,raw,echo=0,mode=0660" 2>/dev/null || true

mkdir -p "$RUN_DIR"
rm -f "$PTY0" "$PTY1"

# Tao cap pty; master A <-> master B, slave ttyVIRT0 cho app, ttyVIRT1 cho slave.
${SOCAT_BIN:-/usr/bin/socat} pty,link="$PTY0",raw,echo=0,mode=0660 \
               pty,link="$PTY1",raw,echo=0,mode=0660 &
SOCAT_PID=$!
trap 'kill "$SOCAT_PID" 2>/dev/null || true; rm -f "$PTY0" "$PTY1"' EXIT INT TERM

# Doi toi da 10 giay cho ca 2 link xuat hien.
i=0
while [ ! -e "$PTY0" ] || [ ! -e "$PTY1" ]; do
    i=$((i + 1))
    if [ "$i" -ge 100 ]; then
        echo "modbus-simulator: timeout cho pty pair" >&2
        exit 1
    fi
    sleep 0.1
done

[ -r "$PTY1" ] && [ -w "$PTY1" ] || {
    echo "modbus-simulator: $PTY1 khong mo duoc (read/write)" >&2
    exit 1
}

# Chay slave o foreground; khi python dung lai (cheat/restart), trap o tren
# se kill socat va don symlink -> vong lap moi cua systemd khong dinh pty cu.
/usr/bin/python3 "$PY" \
    --port "$PTY1" \
    --slave-id "${SLAVE_ID:-1}" \
    --baudrate "${BAUDRATE:-9600}" \
    --value "${SIM_VALUE:-25.0}" \
    --amplitude "${SIM_AMPLITUDE:-10.0}" \
    --period "${SIM_PERIOD:-60.0}"

RC=$?
echo "modbus-simulator: python slave thoat (rc=$RC)" >&2
exit "$RC"
