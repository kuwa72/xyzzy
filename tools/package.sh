#!/bin/bash
# Install a built tree into _dist/<arch>: an exe + lisp + etc + grammars set
# that runs as-is when copied to a Windows box.  Runs inside the container
# image (see tools/x package).
#
#   tools/package.sh <i686|x86_64|aarch64>
#
# This is the same install step the release job runs, so the layout matches the
# ZIP it ships.
set -eu

arch=${1:-x86_64}
root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
dist=$root/_dist/$arch

[ -d "$build" ] || { echo "package.sh: $build not configured" >&2; exit 2; }

cmake --install "$build" --prefix "$dist"

echo "package.sh: $dist"
ls -lh "$dist"/*.exe
echo "package.sh: lisp/*.lc $(find "$dist/lisp" -name '*.lc' | wc -l) files"
