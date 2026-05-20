#!/usr/bin/env bash
# Stage a minimal PySide6 Qt/qml tree for Nuitka --include-data-dir (data only, no patchelf).
# Whitelist only modules the app imports; never copy Qt/labs (assetdownloader *.a breaks patchelf).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PYTHON="${PYTHON:-${REPO_ROOT}/venv-build/bin/python}"
if [ ! -x "$PYTHON" ]; then
    PYTHON="$(command -v python3)"
fi

PYSIDE_QML="$("$PYTHON" -c 'import os, PySide6; print(os.path.join(PySide6.__path__[0], "Qt", "qml"))')"
STAGE_DIR="${STAGE_DIR:-${REPO_ROOT}/build/pyside6-qml}"

if [ ! -d "${PYSIDE_QML}/QtQuick" ]; then
    echo "[stage_pyside_qml] ERROR: PySide6 QML root missing QtQuick: ${PYSIDE_QML}" >&2
    exit 1
fi

# Top-level QML import modules (ui/qml: QtQuick, Controls, Layouts, Window, Dialogs, QtCharts).
MODULES=(
    QtQml
    QtQuick
    QtCharts
)

RSYNC_EXCLUDES=(
    --exclude='*.a'
    --exclude='*.debug'
    --exclude='*.prl'
)

echo "[stage_pyside_qml] Source: ${PYSIDE_QML}"
echo "[stage_pyside_qml] Stage : ${STAGE_DIR}"

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"

for mod in "${MODULES[@]}"; do
    src="${PYSIDE_QML}/${mod}"
    if [ -d "${src}" ]; then
        rsync -a "${RSYNC_EXCLUDES[@]}" "${src}/" "${STAGE_DIR}/${mod}/"
        echo "[stage_pyside_qml]   + ${mod}/"
    else
        echo "[stage_pyside_qml] WARN: missing ${mod}/ (skipped)" >&2
    fi
done

a_count="$(find "${STAGE_DIR}" -name '*.a' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${a_count}" != "0" ]; then
    echo "[stage_pyside_qml] ERROR: staged tree still contains ${a_count} *.a file(s)" >&2
    find "${STAGE_DIR}" -name '*.a' >&2
    exit 1
fi

if [ ! -d "${STAGE_DIR}/QtQuick" ]; then
    echo "[stage_pyside_qml] ERROR: staged QtQuick missing" >&2
    exit 1
fi

echo "[stage_pyside_qml] DONE ($(du -sh "${STAGE_DIR}" | awk '{print $1}'))"
