#!/bin/bash
# fullbuild.sh - WSL2 → MSYS2 bridge build script for xyzzy (SBCL pattern)
#
# Usage:
#   From WSL2: ./fullbuild.sh [clean|rebuild]
#   From MSYS2: ./fullbuild.sh [clean|rebuild]

# WSL2 → MSYS2 bridge
if [ -z "$MSYS2_BUILD" ] && uname -r | grep -qi microsoft; then
    export MSYS2_BUILD=1
    XYZZY_DIR=$(cd "$(dirname "$0")" && pwd)
    # Convert WSL path to MSYS2 path
    MSYS2_PATH=$(echo "$XYZZY_DIR" | sed 's|^/mnt/c|/c|')
    exec /mnt/c/msys64/usr/bin/bash.exe -l -c \
        "cd '$MSYS2_PATH' && MSYS2_BUILD=1 ./fullbuild.sh $*"
fi

set -e

# Detect MSYS2 environment
if [ -d /clangarm64 ]; then
    MSYS2_ENV=clangarm64
    export PATH=/clangarm64/bin:$PATH
    CMAKE_C_COMPILER=clang
    CMAKE_CXX_COMPILER=clang++
    CMAKE_RC_COMPILER=llvm-windres
elif [ -d /mingw64 ]; then
    MSYS2_ENV=mingw64
    export PATH=/mingw64/bin:$PATH
    CMAKE_C_COMPILER=gcc
    CMAKE_CXX_COMPILER=g++
    CMAKE_RC_COMPILER=windres
else
    echo "Error: No supported MSYS2 environment found (clangarm64 or mingw64)"
    exit 1
fi

echo "=== xyzzy build ($MSYS2_ENV) ==="

BUILD_DIR="build-${MSYS2_ENV}"

case "${1:-build}" in
    clean)
        echo "Cleaning $BUILD_DIR..."
        rm -rf "$BUILD_DIR"
        exit 0
        ;;
    rebuild)
        rm -rf "$BUILD_DIR"
        ;;
    build)
        ;;
    *)
        echo "Usage: $0 [build|clean|rebuild]"
        exit 1
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

mingw32-make -j$(nproc) "$@"

echo "=== Build complete ==="
