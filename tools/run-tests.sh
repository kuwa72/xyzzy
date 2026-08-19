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

# The driver appends a line per test here; tail it so that a run which stops
# making progress is visible while it is still happening, and so the last line
# names the test it stopped on.
export XYZZY_TEST_PROGRESS=$run/test-progress.txt
: > "$XYZZY_TEST_PROGRESS"
stall=${XYZZY_TEST_STALL:-300}

echo "run-tests.sh: running the test suite ($arch)..."
echo "run-tests.sh: giving up after ${XYZZY_TEST_TIMEOUT}s, or ${stall}s without progress"

set +e
wine ./xyzzy.exe -q -trace -l unittest/run-tests-batch.l -e "(user::batch-run-all-tests)" &
wine_pid=$!

tail -f -n +1 "$XYZZY_TEST_PROGRESS" &
tail_pid=$!

# The timeout inside the lisp driver only fires while the message loop is being
# pumped, so it cannot help when xyzzy itself blocks -- on a modal dialog, for
# instance.  Watch from out here instead.
status=
waited=0
quiet=0
last_size=0
while :; do
  if ! kill -0 "$wine_pid" 2>/dev/null; then
    wait "$wine_pid"
    status=$?
    break
  fi
  sleep 5
  waited=$((waited + 5))
  size=$(wc -c < "$XYZZY_TEST_PROGRESS" 2>/dev/null || echo 0)
  if [ "$size" -eq "$last_size" ]; then
    quiet=$((quiet + 5))
  else
    quiet=0
    last_size=$size
  fi
  if [ "$quiet" -ge "$stall" ]; then
    echo "run-tests.sh: no progress for ${quiet}s, the suite is stuck" >&2
    status=2
    break
  fi
  if [ "$waited" -ge "$XYZZY_TEST_TIMEOUT" ]; then
    echo "run-tests.sh: still running after ${waited}s, giving up" >&2
    status=2
    break
  fi
done

if [ "$status" = 2 ]; then
  echo "run-tests.sh: last progress:" >&2
  tail -n 5 "$XYZZY_TEST_PROGRESS" >&2 || true
  # A modal dialog is the usual reason to stop dead, and it shows in a shot.
  import -window root "$build/test-stuck.png" 2>/dev/null || true
  echo "run-tests.sh: screenshot at _build/$arch/test-stuck.png" >&2
fi

sleep 1
kill "$tail_pid" 2>/dev/null

if [ "$status" = 2 ]; then
  # Whatever it is stuck on, it is not going to finish, and waiting on a
  # process that never exits is how this step used to run for two hours.
  # wineserver -k first: $! is the wine loader, not the whole process tree.
  wineserver -k 2>/dev/null
  kill "$wine_pid" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$wine_pid" 2>/dev/null || break
    sleep 1
  done
  kill -9 "$wine_pid" 2>/dev/null
fi
wait "$wine_pid" 2>/dev/null
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
  2) echo "run-tests.sh: the suite did not finish" >&2 ;;
  3) echo "run-tests.sh: no tests ran" >&2 ;;
  *) echo "run-tests.sh: xyzzy exited with $status" >&2 ;;
esac
exit $status
