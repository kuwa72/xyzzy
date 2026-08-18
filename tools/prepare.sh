#!/bin/bash
# One slow startup that writes a dump image, so every later run starts from it
# instead of reading the whole lisp library as source.  Runs inside the
# container (tools/x prepare).
#
#   tools/prepare.sh <i686|x86_64> [seconds]
#
# The image holds absolute addresses, so it has to be regenerated whenever
# xyzzy.exe is rebuilt.
set -eu

arch=${1:-x86_64}
wait_for=${2:-3600}

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "prepare.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "prepare.sh: $build/xyzzy.exe not built" >&2; exit 2; }

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

echo "prepare.sh: starting $arch from source and dumping an image (up to ${wait_for}s)..."
timeout "$wait_for" wine ./xyzzy.exe -q -e "(progn (dump-xyzzy) (kill-xyzzy 0))" || true
wineserver -k 2>/dev/null || true

if [ -f xyzzy.wxp ]; then
  ls -l xyzzy.wxp
  echo "prepare.sh: dump image written"
else
  echo "prepare.sh: no dump image was written" >&2
  exit 1
fi
