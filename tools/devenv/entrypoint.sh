#!/bin/bash
# Bring up a virtual X server and the Wine prefixes, then exec the requested
# command.  xyzzy is a GUI application: without a working display driver Wine
# falls back to the null driver and every CreateWindow call fails.
set -e

display=99
export DISPLAY=:$display

if ! xdpyinfo >/dev/null 2>&1; then
  rm -f /tmp/.X11-unix/X$display
  Xvfb :$display -screen 0 1280x1024x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
  for _ in $(seq 1 100); do
    xdpyinfo >/dev/null 2>&1 && break
    sleep 0.1
  done
  xdpyinfo >/dev/null 2>&1 || { echo "entrypoint: Xvfb failed to start" >&2; cat /tmp/xvfb.log >&2; exit 1; }
fi

for prefix in /wine:win64 /wine32:win32; do
  dir=${prefix%:*}
  arch=${prefix#*:}
  if [ ! -f "$dir/system.reg" ]; then
    WINEPREFIX=$dir WINEARCH=$arch wineboot --init >/dev/null 2>&1 || true
    WINEPREFIX=$dir wineserver -w || true
  fi
  # A crashing program must not stop at winedbg's dialog: batch runs would hang.
  if [ ! -f "$dir/.no-crash-dialog" ]; then
    WINEPREFIX=$dir wine reg add 'HKCU\Software\Wine\WineDbg' \
      /v ShowCrashDialog /t REG_DWORD /d 0 /f >/dev/null 2>&1 || true
    WINEPREFIX=$dir wineserver -w || true
    touch "$dir/.no-crash-dialog"
  fi
done

exec "$@"
