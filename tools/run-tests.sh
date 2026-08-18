#!/bin/bash
# Build a run directory for a cross-built xyzzy and drive the lisp test suite
# under Wine.  Runs inside the container image (see tools/x); the first argument
# selects the architecture that was built.
#
#   tools/run-tests.sh <i686|x86_64> [--bytecompile]
#
# Startup reads the whole lisp library as source unless there is a dump image or
# byte compiled files, which costs minutes under emulation: run
# "tools/x prepare <ARCH>" first.
set -eu

arch=${1:-x86_64}
shift || true

bytecompile=no
for arg in "$@"; do
  case $arg in
    --bytecompile) bytecompile=yes ;;
    --no-bytecompile) bytecompile=no ;;
    *) echo "run-tests.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "run-tests.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "run-tests.sh: $build/xyzzy.exe not built" >&2; exit 2; }

# xyzzy looks for lisp/ and etc/ next to itself, so give it a directory holding
# the fresh binaries and links to the tree it was built from.
mkdir -p "$run"
for dir in lisp etc unittest misc reference; do
  ln -sfn "$root/$dir" "$run/$dir"
done
# -p keeps the build time, so the dump image staleness check below is meaningful
cp -pf "$build"/xyzzy.exe "$build"/xyzzycli.exe "$build"/xyzzyenv.exe "$run/"

# A dump image holds absolute addresses from the binary it was written by; drop
# it if the executable is newer.
if [ -f "$run/xyzzy.wxp" ] && [ "$run/xyzzy.exe" -nt "$run/xyzzy.wxp" ]; then
  echo "$(basename "$0"): the dump image is older than xyzzy.exe, removing it" >&2
  rm -f "$run/xyzzy.wxp"
fi
# xyzzy tells an unset variable from an empty one, so clear them properly.
unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$run
export XYZZY_TEST_REPORT=$run/test-report.txt
export XYZZY_TEST_TIMEOUT=${XYZZY_TEST_TIMEOUT:-1800}

cd "$run"
rm -f "$XYZZY_TEST_REPORT"

if [ "$bytecompile" = yes ] && [ ! -f "$root/lisp/startup.lc" ]; then
  echo "run-tests.sh: byte compiling the lisp library (slow)..."
  rm -f "$run/xyzzy.wxp"
  wine ./xyzzy.exe -q -trace -load misc/makelc.l -e "(makelc:makelc-and-exit t)" || {
    echo "run-tests.sh: byte compile failed" >&2
    exit 1
  }
fi

if [ ! -f "$run/xyzzy.wxp" ] && [ ! -f "$root/lisp/startup.lc" ]; then
  echo "run-tests.sh: no dump image and no .lc files; startup will be slow." >&2
  echo "run-tests.sh: consider running tools/x prepare $arch first." >&2
fi

echo "run-tests.sh: running the test suite ($arch)..."
set +e
wine ./xyzzy.exe -q -trace -l unittest/run-tests-batch.l -e "(user::batch-run-all-tests)"
status=$?
set -e

if [ -f "$XYZZY_TEST_REPORT" ]; then
  echo "----- test report -----"
  cat "$XYZZY_TEST_REPORT"
  echo "-----------------------"
else
  echo "run-tests.sh: no report was written" >&2
fi

case $status in
  0) echo "run-tests.sh: all tests passed" ;;
  1) echo "run-tests.sh: tests failed" >&2 ;;
  2) echo "run-tests.sh: timed out after ${XYZZY_TEST_TIMEOUT}s" >&2 ;;
  3) echo "run-tests.sh: no tests ran" >&2 ;;
  *) echo "run-tests.sh: xyzzy exited with $status" >&2 ;;
esac
exit $status
