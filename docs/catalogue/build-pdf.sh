#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

chrome="${CHROME_BIN:-google-chrome}"
command -v "$chrome" >/dev/null 2>&1 || {
  echo "Không tìm thấy Google Chrome. Đặt CHROME_BIN hoặc cài google-chrome." >&2
  exit 1
}

"$chrome" --headless=new --disable-gpu --hide-scrollbars --no-pdf-header-footer \
  --print-to-pdf="$PWD/4M-DataLogger-Catalogue.pdf" "$PWD/catalogue.html"

"$chrome" --headless=new --disable-gpu --hide-scrollbars --no-pdf-header-footer \
  --print-to-pdf="$PWD/4M-DataLogger-Datasheet.pdf" "$PWD/datasheet.html"
