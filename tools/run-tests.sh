#!/bin/bash
# Drive the lisp test suite: under Wine with the cross built xyzzy-batch, or
# natively for the POSIX build.  Runs inside the container image (see tools/x
# test).
#
#   tools/run-tests.sh <i686|x86_64|linux> [--bytecompile]
#
# ARCH "linux" runs _build/linux/xyzzy --batch directly -- no Wine, no
# xyzzy-batch.exe (the POSIX build has no separate batch binary; --batch is a
# flag).  It has its own exclude list and its own known-failures baseline: the
# POSIX frontend is not finished, so it fails things the Windows builds pass.
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
# shellcheck source=lc-stale.sh
. "$root/tools/lc-stale.sh"

# native=yes means "no Wine anywhere in this script": the loader, the kill path
# and the stuck-screenshot are all Wine specific.
native=no
case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  linux)  native=yes ;;
  aarch64)
    echo "run-tests.sh: Wine here executes x86 machine code, so an ARM64 build" >&2
    echo "run-tests.sh: cannot be run; that stays with the MSVC job on" >&2
    echo "run-tests.sh: windows-11-arm.  aarch64 is build only." >&2
    exit 2 ;;
  *) echo "run-tests.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

if [ "$native" = yes ]; then
  exe=$build/xyzzy
  # stdbuf -o0: **出力がブロックバッファされると見張りが誤爆する。** 下の
  # ループは「$stall 秒ログが伸びなければ詰まった」と判断して殺すので、
  # 4KB 単位でしか flush されない健全な run を止めてしまう (実際に止めた)。
  # Wine 側の Windows バイナリは十分に flush しているので、ここだけ要る。
  runner=(stdbuf -o0 "$exe" --batch)
else
  trap 'wineserver -k 2>/dev/null || true' EXIT
  exe=$build/xyzzy-batch.exe
  runner=(wine "$exe")
fi

[ -x "$exe" ] || { echo "run-tests.sh: $exe not built" >&2; exit 2; }

if [ "$bytecompile" = yes ]; then
  "$root/tools/bytecompile.sh" "$arch"
fi

# .lc is portable bytecode (lisp/foreign.l resolves pointer-width-dependent C
# types from the *loading* process's own *features*), so there is no "wrong
# target" case to check for here, only staleness: a .l newer than its .lc
# means the FFI/struct-size/etc. tests below would be exercising whatever the
# previous compile left behind, not the current source.
stale=$(stale_files)
if [ -n "$stale" ]; then
  echo "run-tests.sh: these .l are newer than their .lc:" >&2
  echo "$stale" >&2
  echo "run-tests.sh: run \"tools/x bytecompile $arch\" first (or pass --bytecompile)." >&2
  exit 2
fi

# A dump image holds absolute addresses from the binary it was written by.
dump=${exe%.exe}.wxp
if [ -f "$dump" ] && [ "$exe" -nt "$dump" ]; then
  echo "run-tests.sh: the dump image is older than the exe, removing it" >&2
  rm -f "$dump"
fi

unset XYZZYINIFILE XYZZYCONFIGPATH
export XYZZYHOME=$root
cd "$root"

# Tests that take the process down on this toolchain.  A dead process ends the
# run, so everything after them goes unmeasured: skipping them buys back the
# rest of the suite.  XYZZY_TEST_EXCLUDE_EXTRA adds to the default list in
# misc/run-tests-batch.l rather than replacing it.
#
#   win32-exception-slots, pack/unpack-bad-ptr
#     Raise an access violation on purpose and expect it back as a
#     win32-exception condition.  The translation is _set_se_translator, an MSVC
#     extension, so src/frontend/win32/init.cc installs se_handler only under
#     _MSC_VER and on this build nobody catches the fault.
#
#   handle-divide-by-zero, handle-access-violation, handle-access-violation-2
#   (i686 only)
#     Raise a hardware exception inside a DLL call and expect it back as a
#     win32-exception condition.  dll.cc catches those with __try/__except, and
#     Clang cannot compile that for i686-w64-mingw32: LLVM's 32-bit x86 SEH
#     wants the MSVC exception tables, which this target does not have.
#
#       error: assembler label 'L__ehtable$f' can not be undefined
#
#     The reason it builds at all is that the __try bodies in dll.cc hold only
#     inline asm, which LLVM does not treat as able to throw, so it drops the
#     handler and emits nothing -- no SEH frame, no protection.  Put a call in
#     there and the build stops with the error above.  x86_64 is unaffected
#     (llvm-mingw uses real SEH there) and passes all three.
#
#   kill-xyzzy-exit-code (linux only)
#     Starts (si:system-path) **without --batch** and waits for it.  On Windows
#     a GUI opens minimized and exits; the terminal frontend takes over the same
#     tty and never comes back.  ":show :minimize" is a Win32 idea to begin
#     with.
#
#   ole-tests.l (linux only, the whole file)
#     Drives Internet Explorer through COM.  There is no COM here, so every test
#     in the file is meaningless -- and fix-ole-for-each-2 does not merely fail,
#     it wedges: the loop is "while ReadyState /= 4, sit-for", and ReadyState
#     never becomes anything.  Excluding by file name rather than by test name
#     because the whole file is about one thing this build does not have.
#
#   git-tests.l (linux only, the whole file)
#     Runs its assertions at *load* time (the older style), and one of them
#     touches windows: "既にウィンドウがありません".  A file that fails to load
#     is a failure the known-failures list cannot express -- it is not one test
#     failing, it is the file's tests not running -- so it has to be skipped
#     here instead.  Rewriting it as deftest would let the rest of it run; that
#     is #50 work.
skip=win32-exception-slots,pack/unpack-bad-ptr
case $arch in
  i686) skip=$skip,handle-divide-by-zero,handle-access-violation,handle-access-violation-2 ;;
  linux) skip=$skip,kill-xyzzy-exit-code,ole-tests.l,git-tests.l ;;
esac
: "${XYZZY_TEST_EXCLUDE_EXTRA:=$skip}"
export XYZZY_TEST_EXCLUDE_EXTRA

# Tests that run to the end and fail, as opposed to the ones above that take the
# process down.  Listing them by name is what lets this script gate on the
# result at all: an unlisted failure exits non zero, and so does a listed test
# that starts passing.  misc/known-failures/README.md has the details, including
# how to rewrite a list from a run.
# The two Windows architectures share a list: everything that fails there fails
# on both.  The POSIX build has its own, because what fails there is the frontend
# not being finished rather than a difference between two Windows toolchains.
case $arch in
  linux) known=misc/known-failures/common.txt,misc/known-failures/linux.txt ;;
  *)     known=misc/known-failures/common.txt,misc/known-failures/mingw.txt ;;
esac
: "${XYZZY_TEST_KNOWN_FAILURES:=$known}"
export XYZZY_TEST_KNOWN_FAILURES

timeout=${XYZZY_TEST_TIMEOUT:-1800}
stall=${XYZZY_TEST_STALL:-300}
log=$build/test-output.txt
: > "$log"

echo "run-tests.sh: running the test suite ($arch)..."
echo "run-tests.sh: giving up after ${timeout}s, or ${stall}s without output"

set +e
"${runner[@]}" -q -load misc/run-tests-batch.l >"$log" 2>&1 &
run_pid=$!

tail -f -n +1 "$log" &
tail_pid=$!

status=
waited=0
quiet=0
last_size=0
while :; do
  if ! kill -0 "$run_pid" 2>/dev/null; then
    wait "$run_pid"
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
  # There is no X display in the native run, and no dialog to catch either.
  if [ "$native" = no ]; then
    import -window root "$build/test-stuck.png" 2>/dev/null || true
  fi
fi

sleep 1
kill "$tail_pid" 2>/dev/null

if [ "$status" = 2 ]; then
  # Waiting on a process that never exits is how this step runs for two hours.
  # wineserver -k first: $! is the wine loader, not the whole process tree.
  if [ "$native" = no ]; then
    wineserver -k 2>/dev/null
  fi
  kill "$run_pid" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "$run_pid" 2>/dev/null || break
    sleep 1
  done
  kill -9 "$run_pid" 2>/dev/null
fi
wait "$run_pid" 2>/dev/null
set -e

# The output comes from a Windows binary, so the lines may end with CRLF;
# anchoring these patterns at the end would then never match.
#
# **-a is not optional.** The terminal build writes escape sequences to stdout
# even under --batch (mouse reporting off: ESC [ ? 1002 l), so the log counts as
# binary and grep without -a matches nothing at all -- including the "Total N
# tests" check below, which then reads every native run as "did not finish".
echo "----- summary -----"
grep -ac '\.\.\.OK'     "$log" | sed 's/^/passed: /' || true
grep -ac '\.\.\.Failed' "$log" | sed 's/^/failed: /' || true
grep -a '\.\.\.Failed'  "$log" || true
# The verdict, repeated at the end so it is not buried in the scroll.  These
# counts are every failure; the "===" lines are the ones that decide the exit
# status.  They disagree on purpose: a known failure is a failure that does not
# fail the run.
grep -aE '^=== (known failures|unexpected failures|now passing|listed but did not run|wrote )' "$log" || true
echo "-------------------"

# Wine lets a crashing process exit 0, so the status alone would read a run that
# stopped halfway as a pass.  Natively a segfault does reach the status, but only
# as 139 after the shell has turned it into one.  The summary line is what says
# it got to the end, on both.
if ! grep -aq 'Total [0-9]* tests' "$log"; then
  echo "run-tests.sh: no summary line in the output: the suite did not finish" >&2
  status=2
fi

case $status in
  0) echo "run-tests.sh: no failures outside misc/known-failures" ;;
  1) echo "run-tests.sh: see the \"===\" lines above: either something failed" >&2
     echo "run-tests.sh: that is not a known failure, or a known failure has" >&2
     echo "run-tests.sh: started passing and its entry has to come off the list." >&2 ;;
  2) echo "run-tests.sh: the suite did not finish" >&2 ;;
  *) echo "run-tests.sh: the suite exited with $status" >&2 ;;
esac
exit "$status"
