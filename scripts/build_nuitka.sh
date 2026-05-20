#!/usr/bin/env bash
# Build standalone onefile binary with Nuitka (CI / local on Linux ARM64).
# QML: --include-qt-plugins=qml (after stripping *.a from PySide6 Qt/qml).
# Do not bundle PySide6 QML via --include-data-dir (avoids duplicate warnings).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PYTHON="${PYTHON:-${REPO_ROOT}/venv-build/bin/python}"

if [ ! -x "$PYTHON" ]; then
    echo "[build_nuitka] ERROR: PYTHON not executable: ${PYTHON}" >&2
    exit 1
fi

chmod +x "${REPO_ROOT}/scripts/strip_pyside_qml_static.sh"
PYTHON="$PYTHON" "${REPO_ROOT}/scripts/strip_pyside_qml_static.sh"

QT_PLUGINS="qml,platforms,imageformats,iconengines,xcbglintegrations,generic"

echo "[build_nuitka] Running Nuitka (onefile) ..."
"$PYTHON" -m nuitka --standalone --onefile \
    --include-data-dir=config=config \
    --include-data-dir=ui/qml=ui/qml \
    --include-data-dir=assets=assets \
    --include-package=segno \
    --include-module=core.provision_qr \
    --include-module=core.lan_ip \
    --plugin-enable=pyside6 \
    --include-qt-plugins="${QT_PLUGINS}" \
    --output-filename=datalogger \
    main.py

if [ ! -f "${REPO_ROOT}/datalogger" ]; then
    echo "[build_nuitka] ERROR: output binary ./datalogger not found" >&2
    exit 1
fi

echo "[build_nuitka] DONE: ${REPO_ROOT}/datalogger"
