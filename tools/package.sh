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

# The .lc in the source tree belong to whichever architecture byte compiled them
# last (lisp/.bytecompile-arch), and handing them to an exe of the other one
# makes the FFI read every pointer at the wrong width -- nothing complains at
# load time, it just starts returning garbage.  The release jobs never hit this
# because each one byte compiles with its own binary; a package made by hand
# can, so drop them when the stamp does not match.  xyzzy then reads the .l
# sources, which only costs start up time.
stamp=$dist/lisp/.bytecompile-arch
if [ -f "$stamp" ] && [ "$(cat "$stamp")" != "$arch" ]; then
  echo "package.sh: lisp/*.lc were byte compiled for $(cat "$stamp"), not $arch"
  echo "package.sh: dropping them; run \"tools/x bytecompile $arch --force\" to get them"
  find "$dist/lisp" -name '*.lc' -delete
  rm -f "$stamp"
fi

echo "package.sh: $dist"
ls -lh "$dist"/*.exe
echo "package.sh: lisp/*.lc $(find "$dist/lisp" -name '*.lc' | wc -l) files"
