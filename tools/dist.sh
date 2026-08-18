#!/bin/bash
# Assemble a distribution archive from a cross build, in the layout archive.bat
# produces on Windows.  Runs inside the container (tools/x dist).
#
#   tools/dist.sh <i686|x86_64> [VERSION] [--no-bytecompile]
#
# The lisp library is byte compiled first, as the Windows release process does:
# without the .lc files every start up reads the whole library as source.
set -eu

arch=${1:-x86_64}
shift || true

version=dev
bytecompile=yes
for arg in "$@"; do
  case $arg in
    --no-bytecompile) bytecompile=no ;;
    -*) echo "dist.sh: unknown option $arg" >&2; exit 2 ;;
    *) version=$arg ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run
dist=$root/_dist
stage=$dist/xyzzy
archive=$dist/xyzzy-$version-$arch.zip

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "dist.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "dist.sh: $build/xyzzy.exe not built" >&2; exit 2; }

mkdir -p "$run"
for dir in lisp etc unittest misc reference; do
  ln -sfn "$root/$dir" "$run/$dir"
done
cp -pf "$build"/xyzzy.exe "$build"/xyzzycli.exe "$build"/xyzzyenv.exe "$run/"

export XYZZYHOME=$run XYZZYINIFILE= XYZZYCONFIGPATH=

if [ "$bytecompile" = yes ]; then
  echo "dist.sh: byte compiling the lisp library..."
  (cd "$run" && rm -f xyzzy.wxp \
   && wine ./xyzzy.exe -q -trace -load misc/makelc.l -e "(makelc:makelc-and-exit t)")
  wineserver -k 2>/dev/null || true
  [ -f "$root/lisp/startup.lc" ] || { echo "dist.sh: byte compile produced no .lc" >&2; exit 1; }
fi

rm -rf "$stage" "$archive"
mkdir -p "$stage/lisp" "$stage/etc" "$stage/docs" "$stage/reference" "$stage/site-lisp"
cp -p "$build"/xyzzy.exe "$build"/xyzzycli.exe "$build"/xyzzyenv.exe "$stage/"
cp -p "$root/LICENSE" "$root/LEGAL.md" "$stage/docs/"
for dir in lisp etc docs reference; do
  cp -pR "$root/$dir/." "$stage/$dir/"
done
# Not part of a release: the dump image is regenerated per install, and the
# unit tests are not shipped.
rm -f "$stage/xyzzy.wxp"

mkdir -p "$dist"
(cd "$dist" && python3 -m zipfile -c "$archive" xyzzy)
ls -l "$archive"
echo "dist.sh: wrote $archive"
