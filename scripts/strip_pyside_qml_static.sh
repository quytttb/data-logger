#!/usr/bin/env bash
# Remove non-ELF Qt/QML build artifacts before Nuitka --include-qt-plugins=qml.
# Nuitka treats non-data suffix files as DLLs and runs patchelf/readelf on them.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PYTHON="${PYTHON:-${REPO_ROOT}/venv-build/bin/python}"
if [ ! -x "$PYTHON" ]; then
    PYTHON="$(command -v python3)"
fi

PYSIDE_QML="$("$PYTHON" -c 'import os, PySide6; print(os.path.join(PySide6.__path__[0], "Qt", "qml"))')"

if [ ! -d "${PYSIDE_QML}" ]; then
    echo "[strip_pyside_qml_static] ERROR: PySide6 QML root not found: ${PYSIDE_QML}" >&2
    exit 1
fi

# Suffixes that are not shared libraries but get picked up as "QML plugin DLLs".
STRIP_SUFFIXES=(a prl debug)

total=0
for suffix in "${STRIP_SUFFIXES[@]}"; do
    mapfile -t files < <(find "${PYSIDE_QML}" -name "*.${suffix}" 2>/dev/null || true)
    for f in "${files[@]}"; do
        rm -f "${f}"
        echo "[strip_pyside_qml_static]   removed ${f}"
        total=$((total + 1))
    done
done

for suffix in "${STRIP_SUFFIXES[@]}"; do
    remaining="$(find "${PYSIDE_QML}" -name "*.${suffix}" 2>/dev/null | wc -l | tr -d ' ')"
    if [ "${remaining}" != "0" ]; then
        echo "[strip_pyside_qml_static] ERROR: ${remaining} *.${suffix} file(s) still present" >&2
        exit 1
    fi
done

if [ "${total}" -eq 0 ]; then
    echo "[strip_pyside_qml_static] No *.a/*.prl/*.debug under ${PYSIDE_QML}"
else
    echo "[strip_pyside_qml_static] DONE: removed ${total} non-ELF artifact(s)"
fi

# App does not use Qt/labs QML; assetdownloader ships .a/.prl that break Nuitka.
ASSET_DOWNLOADER="${PYSIDE_QML}/Qt/labs/assetdownloader"
if [ -d "${ASSET_DOWNLOADER}" ]; then
    rm -rf "${ASSET_DOWNLOADER}"
    echo "[strip_pyside_qml_static]   removed unused ${ASSET_DOWNLOADER}"
fi
