#!/bin/bash
# Produce src/core/gen/ for a target that cannot run its own code generators.
# Runs inside the container image (see tools/x arm-prep).
#
# The ARM64 build is in that position: Wine here executes x86 machine code, so
# an ARM64 gen-src1.exe cannot be started.  The generated files are plain tables
# and declarations, the same for every architecture, and they land in the source
# tree, so the x86_64 toolchain -- which does run under Wine -- writes them and
# the ARM64 build reads them.  See XYZZY_RUN_CODEGEN in CMakeLists.txt.
#
# Only the two generator targets are built, not the whole tree: this is meant to
# be a minute of work in front of an ARM64 build, not a second full build.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/x86_64

cmake -S "$root" -B "$build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$root/cmake/mingw-x86_64.cmake" \
  -DCMAKE_BUILD_TYPE=Release

cmake --build "$build" --target gen-src1-run gen-src2-run

echo "arm-prep: src/core/gen/ now holds:"
ls -l "$root/src/core/gen"
