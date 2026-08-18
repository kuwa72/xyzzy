#!/bin/bash
# Run the cross-built xyzzy under Wine with the same environment the test suite
# uses.  Runs inside the container image (see tools/x wine).
#
#   tools/wine-run.sh <i686|x86_64> [xyzzy arguments...]
set -eu

arch=${1:-x86_64}
shift || true

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "wine-run.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "wine-run.sh: $build/xyzzy.exe not built" >&2; exit 2; }

mkdir -p "$run"
for dir in lisp etc unittest misc reference; do
  ln -sfn "$root/$dir" "$run/$dir"
done
# -p keeps the build time so that dump image staleness can be judged
cp -pf "$build"/xyzzy.exe "$build"/xyzzycli.exe "$build"/xyzzyenv.exe "$run/"

# xyzzy tells an unset variable from an empty one, so clear them properly.
unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$run

cd "$run"
exec wine ./xyzzy.exe "$@"
