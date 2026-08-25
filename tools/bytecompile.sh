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

trap 'wineserver -k 2>/dev/null || true' EXIT

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
# shellcheck source=lc-stale.sh
. "$root/tools/lc-stale.sh"

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

# .lc is portable bytecode: lisp/foreign.l resolves pointer-width-dependent C
# types from the *loading* process's own *features*, not from whichever exe
# compiled it.  So there is no "wrong target" case to detect here any more,
# only per-file staleness against the current sources.
stale=$(stale_files)
if [ "$force" = no ] && [ -z "$stale" ]; then
  echo "bytecompile.sh: lisp/*.lc are already up to date, nothing to do"
  exit 0
fi

# A dump image holds absolute addresses from the binary that wrote it.
rm -f "$build/xyzzy-batch.wxp"

unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$root
cd "$root"

if [ "$force" = yes ]; then
  export XYZZY_BYTECOMPILE_FORCE=1
else
  # Recompile only what stale_files() above found stale; the rest keep
  # their existing .lc.  misc/bytecompile-batch.l reads this and passes
  # force-recompile on to makelc:compile-files accordingly.
  unset XYZZY_BYTECOMPILE_FORCE
fi

log=$build/bytecompile-output.txt
echo "bytecompile.sh: byte compiling the lisp library ($arch)..."

# Keep the output rather than letting set -e drop it: a console program run
# through Wine that writes nothing and exits non-zero says nothing about why,
# and the exit code alone is what this step used to report.
set +e
wine "$build/xyzzy-batch.exe" -q -load misc/bytecompile-batch.l >"$log" 2>&1
status=$?
set -e
wineserver -k 2>/dev/null || true

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
stale=$(stale_files)
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
