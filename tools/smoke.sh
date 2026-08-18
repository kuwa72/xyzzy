#!/bin/bash
# Start the cross-built xyzzy under Wine, wait for its window to appear, take a
# screenshot and shut it down again.  Runs inside the container (tools/x smoke).
#
#   tools/smoke.sh <i686|x86_64> [seconds]
set -eu

arch=${1:-x86_64}
wait_for=${2:-120}

root=$(cd "$(dirname "$0")/.." && pwd)
build=$root/_build/$arch
run=$build/run
shot=$build/smoke.png

case $arch in
  i686)   export WINEPREFIX=/wine32 WINEARCH=win32 ;;
  x86_64) export WINEPREFIX=/wine   WINEARCH=win64 ;;
  *) echo "smoke.sh: unknown architecture $arch" >&2; exit 2 ;;
esac

[ -x "$build/xyzzy.exe" ] || { echo "smoke.sh: $build/xyzzy.exe not built" >&2; exit 2; }

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
export XYZZYHOME=$run XYZZYINIFILE= XYZZYCONFIGPATH=
cd "$run"

# The marker is written by lisp once startup has run to completion.
marker=$run/smoke-ok.txt
rm -f "$marker" "$shot"

wine ./xyzzy.exe -q -e "(progn (with-open-file (s \"smoke-ok.txt\" :direction :output :if-exists :supersede :if-does-not-exist :create) (format s \"~A~%\" (software-version))) (kill-xyzzy 0))" &
wine_pid=$!

status=1
for _ in $(seq 1 "$wait_for"); do
  if [ -f "$marker" ]; then
    status=0
    break
  fi
  kill -0 "$wine_pid" 2>/dev/null || break
  sleep 1
done

import -window root "$shot" 2>/dev/null || true
# Shut wine down first: waiting on a process that never exits would hang here.
wineserver -k 2>/dev/null || true
wait "$wine_pid" 2>/dev/null || true

if [ "$status" = 0 ]; then
  echo "smoke.sh: $arch started and evaluated lisp: $(cat "$marker")"
else
  echo "smoke.sh: $arch did not finish startup within ${wait_for}s" >&2
fi
echo "smoke.sh: screenshot at _build/$arch/smoke.png"
exit $status
