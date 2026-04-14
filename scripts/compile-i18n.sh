#!/usr/bin/env bash
# Biên dịch data_logger_vi.ts → data_logger_vi.qm (cần qt6-l10n-tools hoặc qttools5-dev-tools).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/i18n"
VENV_LRELEASE=""
if [[ -x "$ROOT/.venv/bin/python" ]]; then
  VENV_LRELEASE="$("$ROOT/.venv/bin/python" -c "import pathlib, PySide6; print(pathlib.Path(PySide6.__file__).parent / 'lrelease')" 2>/dev/null || true)"
fi
if command -v lrelease-qt6 &>/dev/null; then
  lrelease-qt6 data_logger_vi.ts -qm data_logger_vi.qm
elif [[ -n "$VENV_LRELEASE" && -x "$VENV_LRELEASE" ]]; then
  "$VENV_LRELEASE" data_logger_vi.ts -qm data_logger_vi.qm
elif command -v lrelease &>/dev/null; then
  lrelease data_logger_vi.ts -qm data_logger_vi.qm
else
  echo "Cài: sudo apt install qt6-l10n-tools   (hoặc qttools5-dev-tools), hoặc uv pip install PySide6 và dùng .venv" >&2
  exit 1
fi
echo "OK: i18n/data_logger_vi.qm"
