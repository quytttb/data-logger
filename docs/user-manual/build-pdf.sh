#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 build_manual.py
chrome="${CHROME_BIN:-google-chrome}"
command -v "$chrome" >/dev/null 2>&1 || { echo "Cần Google Chrome/Chromium; đặt CHROME_BIN nếu cần." >&2; exit 1; }
"$chrome" --headless=new --disable-gpu --hide-scrollbars --no-pdf-header-footer \
  --print-to-pdf="$PWD/4M-DataLogger-Huong-Dan-Su-Dung.pdf" "$PWD/huong-dan-su-dung.html"
