#!/bin/bash
# Drive the lisp test suite under Wine with the cross built xyzzy-batch.
# Runs inside the container image (see tools/x test).
#
#   tools/run-tests.sh <i686|x86_64> [--bytecompile]
#
# This is the same command the MSVC job runs on Windows:
#
#   xyzzy-batch.exe -q -load misc/run-tests-batch.l
#
# so a difference in the result is a difference between the toolchains, not
# between two ways of running the suite.
#
# The suite is watched from out here as well as from inside: a test that wedges
# the process (a modal dialog, a blocking read) cannot be timed out by the lisp
# driver, because that only fires while the message loop is being pumped.
set -eu

arch=${1:-x86_64}
shift || true

for arg in "$@"; do
  case $arg in
    --bytecompile|--no-bytecompile) ;;
    *) echo "run-tests.sh: unknown option $arg" >&2; exit 2 ;;
  esac
done

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  aarch64)
    echo "run-tests.sh: Wine here executes x86 machine code, so an ARM64 build" >&2
    echo "run-tests.sh: cannot be run; that stays with the MSVC job on" >&2
    echo "run-tests.sh: windows-11-arm.  aarch64 is build only." >&2
    exit 2 ;;
  *) echo "run-tests.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy-batch.exe" ] || {
  echo "run-tests.sh: $build/xyzzy-batch.exe not built" >&2; exit 2; }

# A dump image holds absolute addresses from the binary it was written by.
if [ -f "$build/xyzzy-batch.wxp" ] \
   && [ "$build/xyzzy-batch.exe" -nt "$build/xyzzy-batch.wxp" ]; then
  echo "run-tests.sh: the dump image is older than the exe, removing it" >&2
  rm -f "$build/xyzzy-batch.wxp"
fi

unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$root
cd "$root"

# Two tests raise an access violation on purpose and expect it back as a
# win32-exception condition.  That translation is _set_se_translator, an MSVC
# extension, so src/frontend/win32/init.cc only installs se_handler under
# _MSC_VER; on this build the fault is not caught and Wine takes the process
# down, which ends the run there and leaves the rest of the suite unmeasured.
# Skip the two rather than lose everything after them.  XYZZY_TEST_EXCLUDE_EXTRA
# adds to the default list in misc/run-tests-batch.l instead of replacing it.
: "${XYZZY_TEST_EXCLUDE_EXTRA:=win32-exception-slots,pack/unpack-bad-ptr}"
export XYZZY_TEST_EXCLUDE_EXTRA

timeout=${XYZZY_TEST_TIMEOUT:-1800}
stall=${XYZZY_TEST_STALL:-300}
log=$build/test-output.txt
: > "$log"

echo "run-tests.sh: running the test suite ($arch)..."
echo "run-tests.sh: giving up after ${timeout}s, or ${stall}s without output"

set +e
wine "$build/xyzzy-batch.exe" -q -load misc/run-tests-batch.l >"$log" 2>&1 &
wine_pid=$!

tail -f -n +1 "$log" &
tail_pid=$!

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
  size=$(wc -c < "$log" 2>/dev/null || echo 0)
  if [ "$size" -eq "$last_size" ]; then
    quiet=$((quiet + 5))
  else
    quiet=0
    last_size=$size
  fi
  if [ "$quiet" -ge "$stall" ]; then
    echo "run-tests.sh: no output for ${quiet}s, the suite is stuck" >&2
    status=2
    break
  fi
  if [ "$waited" -ge "$timeout" ]; then
    echo "run-tests.sh: still running after ${waited}s, giving up" >&2
    status=2
    break
  fi
done

if [ "$status" = 2 ]; then
  echo "run-tests.sh: last output:" >&2
  tail -n 10 "$log" >&2 || true
  # A modal dialog is the usual reason to stop dead, and it shows in a shot.
  import -window root "$build/test-stuck.png" 2>/dev/null || true
fi

sleep 1
kill "$tail_pid" 2>/dev/null

if [ "$status" = 2 ]; then
  # Waiting on a process that never exits is how this step runs for two hours.
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

# The output comes from a Windows binary, so the lines may end with CRLF;
# anchoring these patterns at the end would then never match.
echo "----- summary -----"
grep -c '\.\.\.OK'     "$log" | sed 's/^/passed: /' || true
grep -c '\.\.\.Failed' "$log" | sed 's/^/failed: /' || true
grep '\.\.\.Failed'    "$log" || true
echo "-------------------"

case $status in
  0) echo "run-tests.sh: all tests passed" ;;
  1) echo "run-tests.sh: tests failed" >&2 ;;
  2) echo "run-tests.sh: the suite did not finish" >&2 ;;
  *) echo "run-tests.sh: xyzzy-batch exited with $status" >&2 ;;
esac
exit "$status"
