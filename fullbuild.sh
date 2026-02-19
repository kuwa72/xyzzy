#!/bin/bash
# fullbuild.sh - WSL2 → MSYS2 bridge build script for xyzzy (SBCL pattern)
#
# Usage:
#   ./fullbuild.sh [target] [action]
#
# Targets:
#   clangarm64  ARM64 (default on ARM64 host)
#   mingw64     x86_64
#   mingw32     i686 (XP compatible)
#
# Actions:
#   build       Build (default)
#   clean       Remove build directory
#   rebuild     Clean + build

# WSL2 → MSYS2 bridge
if [ -z "$MSYS2_BUILD" ] && uname -r | grep -qi microsoft; then
    export MSYS2_BUILD=1
    XYZZY_DIR=$(cd "$(dirname "$0")" && pwd)
    MSYS2_PATH=$(echo "$XYZZY_DIR" | sed 's|^/mnt/c|/c|')
    exec /mnt/c/msys64/usr/bin/bash.exe -l -c \
        "cd '$MSYS2_PATH' && MSYS2_BUILD=1 ./fullbuild.sh $*"
fi

set -e

# Parse arguments (order-free)
TARGET=""
ACTION=build
for arg in "$@"; do
    case "$arg" in
        clangarm64|mingw64|mingw32) TARGET="$arg" ;;
        build|clean|rebuild) ACTION="$arg" ;;
        *)
            echo "Usage: $0 [clangarm64|mingw64|mingw32] [build|clean|rebuild]"
            exit 1
            ;;
    esac
done

# Auto-detect target if not specified
if [ -z "$TARGET" ]; then
    if [ -d /clangarm64 ]; then
        TARGET=clangarm64
    elif [ -d /mingw64 ]; then
        TARGET=mingw64
    else
        echo "Error: Cannot auto-detect target. Specify one of: clangarm64 mingw64 mingw32"
        exit 1
    fi
fi

# Configure toolchain
case "$TARGET" in
    clangarm64)
        export PATH=/clangarm64/bin:$PATH
        CMAKE_C_COMPILER=clang
        CMAKE_CXX_COMPILER=clang++
        CMAKE_RC_COMPILER=llvm-windres
        ;;
    mingw64)
        export PATH=/mingw64/bin:$PATH
        CMAKE_C_COMPILER=gcc
        CMAKE_CXX_COMPILER=g++
        CMAKE_RC_COMPILER=windres
        ;;
    mingw32)
        export PATH=/mingw32/bin:$PATH
        CMAKE_C_COMPILER=gcc
        CMAKE_CXX_COMPILER=g++
        CMAKE_RC_COMPILER=windres
        ;;
esac

echo "=== xyzzy build ($TARGET) ==="

BUILD_DIR="build-${TARGET}"

case "$ACTION" in
    clean)
        echo "Cleaning $BUILD_DIR..."
        rm -rf "$BUILD_DIR"
        exit 0
        ;;
    rebuild)
        rm -rf "$BUILD_DIR"
        ;;
esac

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

cmake .. -G "MinGW Makefiles" \
    -DCMAKE_C_COMPILER="$CMAKE_C_COMPILER" \
    -DCMAKE_CXX_COMPILER="$CMAKE_CXX_COMPILER" \
    -DCMAKE_RC_COMPILER="$CMAKE_RC_COMPILER" \
    -DCMAKE_SYSTEM_NAME=Windows \
    -DCMAKE_BUILD_TYPE=Release

mingw32-make -j$(nproc)

echo "=== Build complete ==="
