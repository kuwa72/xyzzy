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

# The mode line, drawn by the frontend from the % specifiers in
# mode-line-format.  Nothing in the lisp suite can see this: the suite runs on
# the Windows builds, and this is code that differs by platform.  It has already
# been wrong -- (const Char *)L"lf" is 16-bit-correct on Windows (wchar_t is 2
# bytes) and truncates to "l" on Linux (wchar_t is 4 bytes), so the terminal
# drew "[utf8n:l]" and neither the build nor the link said a word.  The check
# sets its own format instead of reading the default one, so that changing the
# default mode line cannot silently turn it off.  lisp/modeline.l rebuilds
# mode-line-format from *post-command-hook*, which would overwrite the format
# set here before it is ever drawn, so turn that off first (ignore-errors: the
# command does not exist on older trees).
log=$build/smoke-modeline.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(progn (ignore-errors (toggle-rich-modeline nil)) (setq mode-line-format "SMOKE-MODELINE[%k:%l][%*]") (update-mode-line t))\r' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-MODELINE\[utf8n:lf\]\[--\]' "$log"; then
  echo 'smoke: mode line OK -- % specifiers expand to their full strings'
else
  echo "smoke: mode line FAILED, see $log" >&2
  grep -n 'SMOKE-MODELINE' "$log" >&2 || tail -20 "$log" >&2
  fail=1
fi

# A prompt written right before a blocking read.  The command loop only paints
# between commands, so a command that writes with `message` and then waits for a
# key used to go into the wait undrawn: the prompt never reached the terminal
# (issue #66).  Anything that asks a question mid-command is on this path, so the
# failure reads as "the editor is not responding" rather than as a missing line.
log=$build/smoke-prompt.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(progn (message "SMOKE-PROMPT-VISIBLE") (read-char *keyboard*))\r' '\w' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-PROMPT-VISIBLE' "$log"; then
  echo 'smoke: mid-command prompt OK -- drawn before the read blocks'
else
  echo "smoke: mid-command prompt FAILED, see $log" >&2
  tail -20 "$log" >&2
  fail=1
fi

# Creating and destroying a window during a prefix key wait.  The layout grid
# (w_order) has to stay dense: deleting a window leaves the boundary number it
# used unreferenced, and the next split inserts a new boundary at that hole,
# where compute_geometry then read uninitialized alloca memory.  The result was
# a zero-height window that stayed *selected*, so **every following keystroke
# went to a window nobody could see and the screen stopped changing** (issue
# #83).  Nothing in the lisp suite can see it: the suite runs on the Windows
# builds, where the same sequence happens to survive.
#
# The check asks the editor for the height of the window it is left in rather
# than looking at the screen.  Reading the screen is what the bug reads like,
# but the dump depends on when the drain gives up, and that made the check
# flaky.  A zero-height selected window is the same defect and is a number.
#
# The expression *returns* the marker instead of calling `message': ESC ESC
# reports its own result with `message', so a message from inside is overwritten
# by "t" the moment the expression finishes.
#
# The hook only fires for C-x (char code 24), and tears down only while the
# temporary buffer is the selected one, so that the ESC ESC used to ask the
# question neither creates a second temporary window nor deletes a real one.
log=$build/smoke-prefix-window.txt
XYZZY_EXE=$build/xyzzy XYZZYHOME=$root \
  python3 "$root/tools/pty-drive.py" \
  '\e\e(setq *prefix-key-hook* (list (lambda (keymaps key) (if keymaps (when (eql (char-code key) 24) (pop-to-buffer (get-buffer-create "*T*") t)) (when (equal (buffer-name (selected-buffer)) "*T*") (delete-window) (delete-buffer (find-buffer "*T*")))))))\r\w' \
  '\Cx\w' '2\w' \
  '\e\e(format nil "SMOKE-PREFIX-WINDOW ~:[NG~;OK~] ~S" (and (> (window-lines) 4) t) (list (count-windows) (window-lines)))\r\w' \
  >"$log" 2>&1 || true
if grep -q 'SMOKE-PREFIX-WINDOW OK' "$log"; then
  echo 'smoke: window churn during a prefix key OK -- no zero-height window left'
else
  echo "smoke: window churn during a prefix key FAILED, see $log" >&2
  grep -n 'SMOKE-PREFIX-WINDOW' "$log" >&2 || tail -30 "$log" >&2
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
