#!/bin/bash
# Run a cross-built binary under Wine with the environment the test suite uses.
# Runs inside the container image (see tools/x wine).
#
#   tools/wine-run.sh <i686|x86_64> [arguments...]
#
# Without arguments it starts xyzzy-batch.exe, which is the console build and
# the one CI drives; pass a different exe name as the first argument to pick
# another target (xyzzy.exe is the GUI one and needs the virtual display).
set -eu

arch=${1:-x86_64}
shift || true

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "wine-run.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

exe=xyzzy-batch.exe
case "${1:-}" in
  *.exe) exe=$1; shift ;;
esac

[ -x "$build/$exe" ] || { echo "wine-run.sh: $build/$exe not built" >&2; exit 2; }

# xyzzy tells an unset variable from an empty one, so clear them properly
# rather than setting them to the empty string.
unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$root

cd "$root"
exec wine "$build/$exe" "$@"
