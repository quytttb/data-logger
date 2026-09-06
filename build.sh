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

# A build directory may have been copied from another checkout path. CMake
# refuses to reuse such a cache; keep the old artifacts as a backup and start
# a fresh configure instead of requiring a manual delete.
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    CACHED_SOURCE=""
    while IFS='=' read -r key value; do
        if [[ "$key" == CMAKE_HOME_DIRECTORY:* ]]; then
            CACHED_SOURCE="$value"
            break
        fi
    done < "$BUILD_DIR/CMakeCache.txt"

    if [[ -n "$CACHED_SOURCE" && "$CACHED_SOURCE" != "$ROOT" ]]; then
        BACKUP_DIR="${BUILD_DIR}.stale-$(date +%Y%m%d%H%M%S)"
        echo "Warning: $BUILD_DIR belongs to $CACHED_SOURCE"
        echo "Moving stale build directory to $BACKUP_DIR"
        mv "$BUILD_DIR" "$BACKUP_DIR"
    fi
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
