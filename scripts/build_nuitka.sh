#!/usr/bin/env bash
# Build standalone onefile binary with Nuitka (CI / local on Linux ARM64).
# QML: staged via scripts/stage_pyside_qml.sh (data files only).
# Qt plugins: explicit list — never use include-qt-plugins=all or qml (avoids patchelf on *.a).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PYTHON="${PYTHON:-${REPO_ROOT}/venv-build/bin/python}"
STAGE_DIR="${STAGE_DIR:-${REPO_ROOT}/build/pyside6-qml}"

if [ ! -x "$PYTHON" ]; then
    echo "[build_nuitka] ERROR: PYTHON not executable: ${PYTHON}" >&2
    exit 1
fi

chmod +x "${REPO_ROOT}/scripts/stage_pyside_qml.sh"
PYTHON="$PYTHON" STAGE_DIR="$STAGE_DIR" "${REPO_ROOT}/scripts/stage_pyside_qml.sh"

if [ ! -d "${STAGE_DIR}/QtQuick" ]; then
    echo "[build_nuitka] ERROR: staged QML tree invalid: ${STAGE_DIR}" >&2
    exit 1
fi

# Match pysidedeploy.spec platform plugins; omit qml/all (QML bundled as data above).
QT_PLUGINS="platforms,imageformats,iconengines,xcbglintegrations,generic"

echo "[build_nuitka] Running Nuitka (onefile) ..."
"$PYTHON" -m nuitka --standalone --onefile \
    --include-data-dir=config=config \
    --include-data-dir=ui/qml=ui/qml \
    --include-data-dir=assets=assets \
    --include-data-dir="${STAGE_DIR}=PySide6/Qt/qml" \
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
