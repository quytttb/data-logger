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
#    - ./datalogger              (binary Nuitka --onefile; gồm segno + provision QR)
#    - ./config/                 (config mẫu)
#    - ./ui/qml/                 (assets QML, gồm ProvisionQrPopup.qml)
#    - ./docs/                   (provision-qr-v1.md — tuỳ chọn)
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

if [ -d "${REPO_ROOT}/docs" ]; then
    cp -a "${REPO_ROOT}/docs" "${STAGE_DIR}${INSTALL_PREFIX}/docs"
fi

# ── Desktop entry + icon (system menus & Alt-Tab) ───────────────────────────
DESKTOP_SRC="${REPO_ROOT}/scripts/data-logger.desktop.in"
if [ -f "${DESKTOP_SRC}" ]; then
    mkdir -p "${STAGE_DIR}/usr/share/applications"
    DESKTOP_DST="${STAGE_DIR}/usr/share/applications/data-logger.desktop"
    sed \
        -e "s|@APP_DIR@/scripts/launch-data-logger.sh|/usr/bin/datalogger|g" \
        -e "s|@APP_DIR@/assets/app-icon.png|data-logger|g" \
        -e "s|@APP_DIR@/assets/app-icon.svg|data-logger|g" \
        -e "s|@APP_DIR@|${INSTALL_PREFIX}|g" \
        "${DESKTOP_SRC}" > "${DESKTOP_DST}"
    chmod 0644 "${DESKTOP_DST}"
fi

ICON_PNG="${REPO_ROOT}/assets/app-icon.png"
ICON_SVG="${REPO_ROOT}/assets/app-icon.svg"
if [ -f "${ICON_PNG}" ]; then
    mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps" \
             "${STAGE_DIR}/usr/share/pixmaps"
    install -m 0644 "${ICON_PNG}" "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps/data-logger.png"
    install -m 0644 "${ICON_PNG}" "${STAGE_DIR}/usr/share/pixmaps/data-logger.png"
fi
if [ -f "${ICON_SVG}" ]; then
    mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps"
    install -m 0644 "${ICON_SVG}" "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps/data-logger.svg"
fi

echo "${VERSION}" > "${STAGE_DIR}${INSTALL_PREFIX}/VERSION"

# ── systemd unit ────────────────────────────────────────────────────────────
SERVICE_SRC="${REPO_ROOT}/scripts/datalogger.service"
SERVICE_DST="${STAGE_DIR}/lib/systemd/system/datalogger.service"

if [ -f "${SERVICE_SRC}" ]; then
    cp "${SERVICE_SRC}" "${SERVICE_DST}"
    # Không dùng mẫu ^;?ExecStart — nó khớp cả dòng ExecStart= hợp lệ và tạo trùng ExecStart (systemd lỗi "more than one ExecStart").
    sed -i \
        -e "s|^User=.*|User=${SERVICE_USER}|" \
        -e "/^;ExecStart=/d" \
        -e "/^;WorkingDirectory=/d" \
        -e "s|^WorkingDirectory=.*|WorkingDirectory=${INSTALL_PREFIX}|" \
        -e "s|^ExecStart=.*|ExecStart=${INSTALL_PREFIX}/datalogger|" \
        -e "s|DATALOGGER_DATA_DIR=[^\"]*|DATALOGGER_DATA_DIR=${INSTALL_PREFIX}/var/data|" \
        -e "s|DATALOGGER_CONFIG_DIR=[^\"]*|DATALOGGER_CONFIG_DIR=${INSTALL_PREFIX}/config|" \
        -e "s|DATALOGGER_LOG_DIR=[^\"]*|DATALOGGER_LOG_DIR=${INSTALL_PREFIX}/var/logs|" \
        -e "s|XAUTHORITY=/home/[^/]*/|XAUTHORITY=/home/${SERVICE_USER}/|" \
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

# ── CLI launcher (gõ `datalogger` trong terminal) ───────────────────────────
mkdir -p "${STAGE_DIR}/usr/bin"
cat > "${STAGE_DIR}/usr/bin/datalogger" <<LAUNCH
#!/bin/sh
# Defaults for GUI on Pi / desktop; override by exporting before calling.
export DISPLAY="\${DISPLAY:-:0}"
if [ -z "\${XAUTHORITY:-}" ] && [ -n "\${HOME:-}" ] && [ -f "\${HOME}/.Xauthority" ]; then
  export XAUTHORITY="\${HOME}/.Xauthority"
fi
# Nuitka bundle may omit Qt QML imports — use distro Qt6 QML when present (Debian/Raspberry Pi OS).
for _qml in /usr/lib/aarch64-linux-gnu/qt6/qml /usr/lib/arm-linux-gnueabihf/qt6/qml /usr/lib/x86_64-linux-gnu/qt6/qml /usr/lib/qt6/qml; do
  if [ -d "\${_qml}/QtQuick" ]; then
    export QT_QML_IMPORT_PATH="\${_qml}\${QT_QML_IMPORT_PATH:+:\${QT_QML_IMPORT_PATH}}"
    break
  fi
done
export DATALOGGER_DATA_DIR="\${DATALOGGER_DATA_DIR:-${INSTALL_PREFIX}/var/data}"
export DATALOGGER_CONFIG_DIR="\${DATALOGGER_CONFIG_DIR:-${INSTALL_PREFIX}/config}"
export DATALOGGER_LOG_DIR="\${DATALOGGER_LOG_DIR:-${INSTALL_PREFIX}/var/logs}"
cd "${INSTALL_PREFIX}" || exit 1
exec "${INSTALL_PREFIX}/datalogger" "\$@"
LAUNCH
chmod 0755 "${STAGE_DIR}/usr/bin/datalogger"

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
Suggests: qt6-qpa-plugins, qml6-module-qtquick, qml6-module-qtquick-controls, qml6-module-qtquick-layouts, qml6-module-qtquick-window, qml6-module-qtquick-dialogs, qml6-module-qtcharts
Description: IoT Data Logger
 Modbus polling, SQLite storage and sFTP report uploader,
 packaged as a Nuitka standalone binary with systemd integration.
 Includes HTTP REST remote config and LAN provisioning QR (central-logger-provision/v1).
 Schema reference: /opt/datalogger/docs/provision-qr-v1.md when docs are shipped.
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

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -f /usr/share/icons/hicolor || true
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
