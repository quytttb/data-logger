#!/usr/bin/env bash
# Remove static archives (*.a) from PySide6 Qt/qml before Nuitka --include-qt-plugins=qml.
# Nuitka treats non-.qml files as DLLs and runs patchelf on them; *.a are not ELF.

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

mapfile -t A_FILES < <(find "${PYSIDE_QML}" -name '*.a' 2>/dev/null || true)
count="${#A_FILES[@]}"

if [ "${count}" -eq 0 ]; then
    echo "[strip_pyside_qml_static] No *.a under ${PYSIDE_QML}"
    exit 0
fi

for f in "${A_FILES[@]}"; do
    rm -f "${f}"
    echo "[strip_pyside_qml_static]   removed ${f}"
done

remaining="$(find "${PYSIDE_QML}" -name '*.a' 2>/dev/null | wc -l | tr -d ' ')"
if [ "${remaining}" != "0" ]; then
    echo "[strip_pyside_qml_static] ERROR: ${remaining} *.a file(s) still present" >&2
    exit 1
fi

echo "[strip_pyside_qml_static] DONE: removed ${count} static archive(s)"
