#!/usr/bin/env bash
# ============================================================
#  build_deb.sh — Đóng gói Data Logger thành file Debian (.deb)
#
#  Dùng trên Ubuntu/Debian runner trong CI/CD (sau khi Nuitka đã build xong).
#
#  Cách dùng:
#    VERSION=2.0.3 ARCH=arm64 scripts/build_deb.sh
#    scripts/build_deb.sh 2.0.3 arm64
#
#  Yêu cầu sẵn có trong thư mục gốc repo:
#    - ./datalogger              (binary Nuitka --onefile)
#    - ./config/                 (config mẫu)
#    - ./ui/qml/                 (assets QML)
#    - ./migrations/             (alembic migrations)
#    - ./alembic.ini
#    - ./scripts/datalogger.service  (tuỳ chọn; nếu thiếu sẽ sinh template)
# ============================================================

set -euo pipefail

VERSION="${1:-${VERSION:-}}"
ARCH="${2:-${ARCH:-arm64}}"

if [ -z "${VERSION}" ]; then
    if [ -f VERSION ]; then
        VERSION="$(cat VERSION | tr -d '[:space:]')"
    else
        echo "[build_deb] ERROR: VERSION không được cung cấp (env/arg/VERSION file)." >&2
        exit 1
    fi
fi

VERSION="${VERSION#v}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PKG_NAME="datalogger"
INSTALL_PREFIX="/opt/datalogger"
SERVICE_USER="pi"
BUILD_DIR="${REPO_ROOT}/build/deb"
STAGE_DIR="${BUILD_DIR}/${PKG_NAME}_${VERSION}_${ARCH}"
OUTPUT_DEB="${REPO_ROOT}/${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "[build_deb] VERSION=${VERSION} ARCH=${ARCH}"
echo "[build_deb] Staging: ${STAGE_DIR}"
echo "[build_deb] Output : ${OUTPUT_DEB}"

rm -rf "${STAGE_DIR}"
mkdir -p \
    "${STAGE_DIR}/DEBIAN" \
    "${STAGE_DIR}${INSTALL_PREFIX}" \
    "${STAGE_DIR}/lib/systemd/system"

# ── Copy runtime artifacts ──────────────────────────────────────────────────
if [ ! -f "${REPO_ROOT}/datalogger" ]; then
    echo "[build_deb] ERROR: Không tìm thấy binary ./datalogger ở repo root." >&2
    exit 1
fi
install -m 0755 "${REPO_ROOT}/datalogger" "${STAGE_DIR}${INSTALL_PREFIX}/datalogger"

if [ -d "${REPO_ROOT}/config" ]; then
    cp -a "${REPO_ROOT}/config" "${STAGE_DIR}${INSTALL_PREFIX}/config.default"
else
    echo "[build_deb] WARN: Không có thư mục ./config — bỏ qua config.default." >&2
fi

if [ -d "${REPO_ROOT}/ui/qml" ]; then
    mkdir -p "${STAGE_DIR}${INSTALL_PREFIX}/ui"
    cp -a "${REPO_ROOT}/ui/qml" "${STAGE_DIR}${INSTALL_PREFIX}/ui/qml"
fi

if [ -d "${REPO_ROOT}/migrations" ]; then
    cp -a "${REPO_ROOT}/migrations" "${STAGE_DIR}${INSTALL_PREFIX}/migrations"
fi
if [ -f "${REPO_ROOT}/alembic.ini" ]; then
    install -m 0644 "${REPO_ROOT}/alembic.ini" "${STAGE_DIR}${INSTALL_PREFIX}/alembic.ini"
fi
if [ -d "${REPO_ROOT}/assets" ]; then
    cp -a "${REPO_ROOT}/assets" "${STAGE_DIR}${INSTALL_PREFIX}/assets"
fi

echo "${VERSION}" > "${STAGE_DIR}${INSTALL_PREFIX}/VERSION"

# ── systemd unit ────────────────────────────────────────────────────────────
SERVICE_SRC="${REPO_ROOT}/scripts/datalogger.service"
SERVICE_DST="${STAGE_DIR}/lib/systemd/system/datalogger.service"

if [ -f "${SERVICE_SRC}" ]; then
    cp "${SERVICE_SRC}" "${SERVICE_DST}"
    sed -i \
        -e "s|^User=.*|User=${SERVICE_USER}|" \
        -e "s|^WorkingDirectory=.*|WorkingDirectory=${INSTALL_PREFIX}|" \
        -e "s|^ExecStart=.*|ExecStart=${INSTALL_PREFIX}/datalogger|" \
        -e "s|^;\\?ExecStart=.*|ExecStart=${INSTALL_PREFIX}/datalogger|" \
        -e "s|^;\\?WorkingDirectory=.*|WorkingDirectory=${INSTALL_PREFIX}|" \
        -e "s|DATALOGGER_DATA_DIR=[^\"]*|DATALOGGER_DATA_DIR=${INSTALL_PREFIX}/var/data|" \
        -e "s|DATALOGGER_CONFIG_DIR=[^\"]*|DATALOGGER_CONFIG_DIR=${INSTALL_PREFIX}/config|" \
        -e "s|DATALOGGER_LOG_DIR=[^\"]*|DATALOGGER_LOG_DIR=${INSTALL_PREFIX}/var/logs|" \
        "${SERVICE_DST}"
else
    cat > "${SERVICE_DST}" <<SERVICE
[Unit]
Description=IoT Data Logger — Modbus sensors, SQLite, sFTP uploader
After=network.target
Wants=network.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=dialout
WorkingDirectory=${INSTALL_PREFIX}
ExecStart=${INSTALL_PREFIX}/datalogger
Environment="DATALOGGER_DATA_DIR=${INSTALL_PREFIX}/var/data"
Environment="DATALOGGER_CONFIG_DIR=${INSTALL_PREFIX}/config"
Environment="DATALOGGER_LOG_DIR=${INSTALL_PREFIX}/var/logs"
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/${SERVICE_USER}/.Xauthority"
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=datalogger

[Install]
WantedBy=graphical.target
SERVICE
fi
chmod 0644 "${SERVICE_DST}"

# ── DEBIAN/control ──────────────────────────────────────────────────────────
INSTALLED_SIZE=$(du -sk "${STAGE_DIR}${INSTALL_PREFIX}" | awk '{print $1}')
cat > "${STAGE_DIR}/DEBIAN/control" <<CONTROL
Package: ${PKG_NAME}
Version: ${VERSION}
Section: net
Priority: optional
Architecture: ${ARCH}
Maintainer: Data Logger Team <ops@example.com>
Installed-Size: ${INSTALLED_SIZE}
Depends: libc6, systemd
Description: IoT Data Logger
 Modbus polling, SQLite storage and sFTP report uploader,
 packaged as a Nuitka standalone binary with systemd integration.
CONTROL

# ── DEBIAN/postinst ─────────────────────────────────────────────────────────
cat > "${STAGE_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/bin/bash
set -e

INSTALL_PREFIX="/opt/datalogger"
SERVICE_USER="pi"

mkdir -p "${INSTALL_PREFIX}/var/data" "${INSTALL_PREFIX}/var/logs"

if [ ! -d "${INSTALL_PREFIX}/config" ] && [ -d "${INSTALL_PREFIX}/config.default" ]; then
    cp -a "${INSTALL_PREFIX}/config.default/." "${INSTALL_PREFIX}/config/"
fi

if id "${SERVICE_USER}" >/dev/null 2>&1; then
    chown -R "${SERVICE_USER}:${SERVICE_USER}" "${INSTALL_PREFIX}" || true
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable datalogger.service || true
    systemctl restart datalogger.service || true
fi

exit 0
POSTINST
chmod 0755 "${STAGE_DIR}/DEBIAN/postinst"

# ── DEBIAN/prerm ────────────────────────────────────────────────────────────
cat > "${STAGE_DIR}/DEBIAN/prerm" <<'PRERM'
#!/bin/bash
set -e

if command -v systemctl >/dev/null 2>&1; then
    systemctl stop datalogger.service || true
fi

exit 0
PRERM
chmod 0755 "${STAGE_DIR}/DEBIAN/prerm"

# ── Mark config files (không bị ghi đè bởi dpkg) ───────────────────────────
# config thực tế nằm trong config/ (do postinst sinh ra), nên không cần khai báo
# conffiles cho package; config.default/ là payload do package quản lý.

# ── Build .deb ──────────────────────────────────────────────────────────────
rm -f "${OUTPUT_DEB}"
dpkg-deb --build --root-owner-group "${STAGE_DIR}" "${OUTPUT_DEB}"

echo "[build_deb] DONE: ${OUTPUT_DEB}"
echo "${OUTPUT_DEB}"
