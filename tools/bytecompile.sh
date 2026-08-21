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

# The .lc files are not interchangeable between the targets.  The reader decides
# pointer widths while compiling (#+:64bit in lisp/foreign.l), so a library
# compiled by the 64 bit build makes the 32 bit one read every pointer as 8
# bytes: nothing complains at load time, the FFI just hands out garbage and the
# process dies.  They live in the shared source tree, so leave a stamp saying
# which target wrote them and recompile when it is the wrong one.
stamp=$root/lisp/.bytecompile-arch
if [ "$force" = no ] && [ -f "$root/lisp/startup.lc" ]; then
  if [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$arch" ]; then
    echo "bytecompile.sh: lisp/*.lc are already there and were built for $arch, nothing to do"
    exit 0
  fi
  if [ -f "$stamp" ]; then
    echo "bytecompile.sh: lisp/*.lc were built for $(cat "$stamp"), recompiling for $arch"
  else
    echo "bytecompile.sh: lisp/*.lc are there but nothing says which target built them, recompiling for $arch"
  fi
  find "$root/lisp" -name '*.lc' -delete
  rm -f "$stamp"
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

# And again afterwards, for a different reason: xyzzy-batch writes the dump at
# *startup*, i.e. before it compiles anything, so the image it leaves behind
# holds the Lisp state built from the *previous* .lc set.  It is newer than the
# exe, so the staleness guards above accept it, and every later run silently
# preloads the old state -- a changed builtin.l or defvar appears to have no
# effect.  The image is only a cache; dropping it costs one slow startup.
rm -f "$build"/*.wxp

count=$(find "$root/lisp" -name '*.lc' | wc -l)
echo "bytecompile.sh: $count .lc file(s) present"

# The count alone says nothing.  makelc used to abandon the whole loop on the
# first file that failed, so everything after it kept its old .lc -- and since
# those .lc existed, this script called it a success.  A Lisp change could sit
# undeployed for hours that way.  Check the thing we actually care about:
# no .l may be newer than its .lc.
# lisp/wip/ は makelc も対象外にしている (作業中で require されておらず、
# コンパイラがスタックを溢れさせる)。検査からも外す。
stale=$(find "$root/lisp" -name '*.l' -not -path '*/wip/*' -print | while read -r l; do
          lc=${l%.l}.lc
          if [ ! -f "$lc" ] || [ "$l" -nt "$lc" ]; then
            echo "  $l"
          fi
        done)
if [ -n "$stale" ]; then
  echo "bytecompile.sh: these .l are newer than their .lc:" >&2
  echo "$stale" >&2
  echo "bytecompile.sh: see $log for the compiler's own error" >&2
  exit 1
fi

# The count is what matters.  xyzzy exiting non-zero after writing the whole
# library is not a reason to stop; nothing written is.
[ "$count" -gt 0 ] || {
  echo "bytecompile.sh: no .lc files were produced (xyzzy-batch exit $status)" >&2
  exit 1
}

echo "$arch" > "$stamp"
