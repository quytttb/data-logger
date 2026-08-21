#!/usr/bin/env bash
# Build the C++ Data Logger application.
# Usage: ./build.sh [Release|Debug] [-- extra cmake args]
set -euo pipefail

BUILD_TYPE="${1:-Release}"
BUILD_DIR="build-${BUILD_TYPE,,}"

# Phiên bản Qt dùng chung cho CI + scripts: packaging/qt_version.txt
# (override qua QT_VERSION / QT_DIR env nếu cài Qt nơi khác).
ROOT="$(cd "$(dirname "$0")" && pwd)"
QT_VERSION="${QT_VERSION:-$(tr -d '[:space:]' < "${ROOT}/packaging/qt_version.txt" 2>/dev/null || echo 6.11.1)}"
QT_DIR="${QT_DIR:-$HOME/Qt/${QT_VERSION}/gcc_64}"

if [[ ! -f "$QT_DIR/lib/cmake/Qt6/Qt6Config.cmake" ]]; then
    echo "Error: Qt not found at $QT_DIR" >&2
    echo "Set QT_DIR to your Qt kit, e.g. export QT_DIR=\$HOME/Qt/6.11.1/gcc_64" >&2
    exit 1
fi

if [[ ! -f "$QT_DIR/lib/cmake/Qt6HttpServer/Qt6HttpServerConfig.cmake" ]]; then
    echo "Error: Qt6 HttpServer module not installed in $QT_DIR" >&2
    echo "Open Qt Maintenance Tool → Add or remove components → Qt 6.11.1 → Additional Libraries → Qt HTTP Server" >&2
    exit 1
fi

cmake -B "$BUILD_DIR" \
      -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
      -DCMAKE_C_COMPILER="${CC:-gcc-15}" \
      -DCMAKE_CXX_COMPILER="${CXX:-g++-15}" \
      -DCMAKE_PREFIX_PATH="$QT_DIR" \
      "${@:2}"

cmake --build "$BUILD_DIR" --parallel "$(nproc)"

echo ""
echo "Build complete: $BUILD_DIR/bin/DataLogger"
