#!/bin/bash
# Byte compile the lisp library with the cross built xyzzy-batch, the way the
# bytecompile cmake target does on Windows.  Runs inside the container
# (tools/x bytecompile).
#
#   tools/bytecompile.sh <i686|x86_64> [--force]
#
# Without the .lc files every start up reads the whole library as source, which
# takes minutes under Wine; with them it takes seconds.  The files land next to
# the .l files and are ignored by git.
#
# The cmake bytecompile target is not used here: it calls the exe directly
# through execute_process, which a Linux host cannot do for a PE binary.
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

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  aarch64)
    echo "bytecompile.sh: an ARM64 build cannot be run here; aarch64 is build only" >&2
    exit 2 ;;
  *) echo "bytecompile.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy-batch.exe" ] || {
  echo "bytecompile.sh: $build/xyzzy-batch.exe not built" >&2; exit 2; }

if [ "$force" = no ] && [ -f "$root/lisp/startup.lc" ]; then
  echo "bytecompile.sh: lisp/startup.lc is already there, nothing to do"
  exit 0
fi

# A dump image holds absolute addresses from the binary that wrote it.
rm -f "$build/xyzzy-batch.wxp"

unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$root
cd "$root"

log=$build/bytecompile-output.txt
echo "bytecompile.sh: byte compiling the lisp library ($arch)..."

# Keep the output rather than letting set -e drop it: a console program run
# through Wine that writes nothing and exits non-zero says nothing about why,
# and the exit code alone is what this step used to report.
set +e
wine "$build/xyzzy-batch.exe" -q -load misc/bytecompile-batch.l >"$log" 2>&1
status=$?
set -e
wineserver -w || true

echo "----- xyzzy-batch output (exit $status) -----"
cat "$log" || true
echo "---------------------------------------------"

count=$(find "$root/lisp" -name '*.lc' | wc -l)
echo "bytecompile.sh: $count .lc file(s) present"

# The count is what matters.  xyzzy exiting non-zero after writing the whole
# library is not a reason to stop; nothing written is.
[ "$count" -gt 0 ] || {
  echo "bytecompile.sh: no .lc files were produced (xyzzy-batch exit $status)" >&2
  exit 1
}
