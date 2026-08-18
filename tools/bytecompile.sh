#!/bin/bash
# Byte compile the lisp library with a cross built xyzzy, the way
# bytecompile.bat does on Windows.  Runs inside the container (tools/x
# bytecompile).
#
#   tools/bytecompile.sh <i686|x86_64> [--force]
#
# Without the .lc files every start up reads the whole library as source, which
# takes minutes; with them it takes seconds.  The files land next to the .l
# files and are ignored by git.
set -eu

arch=${1:-x86_64}
shift || true

force=no
for arg in "$@"; do
  case $arg in
    --force) force=yes ;;
    *) echo "bytecompile.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "bytecompile.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "bytecompile.sh: $build/xyzzy.exe not built" >&2; exit 2; }

if [ "$force" = no ] && [ -f "$root/lisp/startup.lc" ]; then
  echo "bytecompile.sh: lisp/startup.lc is already there, nothing to do"
  exit 0
fi

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
rm -f xyzzy.wxp

echo "bytecompile.sh: byte compiling the lisp library ($arch)..."
wine ./xyzzy.exe -q -trace -load misc/makelc.l -e "(makelc:makelc-and-exit t)"
wineserver -k 2>/dev/null || true
rm -f xyzzy.wxp

[ -f "$root/lisp/startup.lc" ] || {
  echo "bytecompile.sh: no .lc files were produced" >&2
  exit 1
}
echo "bytecompile.sh: $(find "$root/lisp" -name '*.lc' | wc -l) file(s) compiled"
