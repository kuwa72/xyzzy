#!/bin/bash
# Start the natively built POSIX binaries once and check that they come up.
#
#   tools/linux-smoke.sh [BUILD_DIR]     (default: _build/linux)
#
# The Linux build has no test suite of its own: misc/run-tests-batch.l wedges
# under it, and the known-failures baselines in misc/known-failures/ are written
# against the Windows builds.  So this is the entire runtime gate for it.
#
# It is deliberately more than "the exe exists".  A Linux build that compiles
# and links but cannot get through lisp/startup.l is the failure mode this has
# already caught once (user-config-path was left unbound outside Win32, and
# lisp/backup.l reads it at start up), and nothing about the build itself says
# so: the binaries appear, and only running one shows the library never loads.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
build=${1:-$root/_build/linux}

for exe in xyzzy xyzzy-cli; do
  [ -x "$build/$exe" ] || {
    echo "linux-smoke.sh: $build/$exe not built" >&2; exit 2; }
done

# XYZZYHOME points the binaries at this tree's lisp/ rather than at whatever
# may be installed on the machine.
export XYZZYHOME=$root

fail=0

# xyzzy-ncurses in batch mode: loads lisp/startup.l (which loads the whole
# library) and then evaluates what -e hands it.  kill-xyzzy is how a batch run
# ends normally, so the exit code alone proves nothing -- the marker line does.
log=$build/smoke-ncurses.txt
"$build/xyzzy" --batch \
  -e '(progn (format t "SMOKE-NCURSES ~A~%" (lisp-implementation-version)) (kill-xyzzy))' \
  >"$log" 2>&1 || true
if grep -q '^SMOKE-NCURSES ' "$log"; then
  echo "smoke: ncurses batch OK -- $(grep '^SMOKE-NCURSES ' "$log")"
else
  echo "smoke: ncurses batch FAILED, see $log" >&2
  cat "$log" >&2
  fail=1
fi

# File operations, in the frontend that has the lisp library loaded.  Every
# call below reached a "return FALSE" stub in platform.h until the POSIX side
# was written (see src/core/vfs-posix.cc): copy-file copied nothing, and every
# file was dated 1601-01-01, which is what the "changed on disk since you read
# it" check was comparing against.  The equality against get-universal-time is
# the point -- a timestamp that merely exists was there before, and it was
# wrong by three centuries.
tmp=$build/smoke-fileops
rm -rf "$tmp" && mkdir -p "$tmp"
log=$build/smoke-fileops.txt
"$build/xyzzy" --batch -e "(progn
  (with-open-file (s \"$tmp/a.txt\" :direction :output :if-exists :supersede)
    (princ \"SMOKE\" s))
  (copy-file \"$tmp/a.txt\" \"$tmp/b.txt\" :if-exists :overwrite)
  (format t \"SMOKE-FILEOPS ~S ~S ~S~%\"
          (with-open-file (s \"$tmp/b.txt\") (read-line s nil))
          (< (abs (- (file-write-time \"$tmp/a.txt\") (get-universal-time))) 60)
          (equal (file-write-time \"$tmp/a.txt\") (file-write-time \"$tmp/b.txt\")))
  (kill-xyzzy))" >"$log" 2>&1 || true
if grep -qE '^SMOKE-FILEOPS "SMOKE" t t[[:space:]]*$' "$log"; then
  echo 'smoke: file operations OK -- copy-file copies, timestamps are this century'
else
  echo "smoke: file operations FAILED, see $log" >&2
  grep '^SMOKE-FILEOPS' "$log" >&2 || cat "$log" >&2
  fail=1
fi

# xyzzy-cli links xyzzy-core alone and reads a REPL from stdin.  It exists as
# the core separation test: anything the core leaks that only the Win32
# frontend can satisfy shows up here as a link error or as a start up crash.
#
# The second expression is the filesystem: directory goes through WINFS
# (src/core/vfs.h), whose POSIX side is src/core/vfs-posix.cc.  When that side
# was still inside the ncurses frontend, this frontend got a WINFS that
# forwarded to the always-fail stubs in platform.h and could not list, open or
# create anything -- while still starting up and evaluating (+ 1 2) happily.
# Note that xyzzy-cli does not load lisp/, so only builtins are available here.
log=$build/smoke-cli.txt
printf '%s\n' \
  '(+ 1 2)' \
  "(if (> (length (directory \"$root/lisp/\")) 100) 424242 0)" \
  | "$build/xyzzy-cli" >"$log" 2>&1 || true
# The lisp streams write CRLF even here, so the result line ends "3\r".
if grep -qE '^> 3[[:space:]]*$' "$log" && grep -qE '^> 424242[[:space:]]*$' "$log"; then
  echo "smoke: cli REPL OK -- (+ 1 2) => 3, lisp/ listed through WINFS"
else
  echo "smoke: cli REPL FAILED, see $log" >&2
  cat "$log" >&2
  fail=1
fi

exit $fail
