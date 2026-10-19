#!/bin/sh
# Propose the next candidate config. Arguments: <run-dir-of-last-iteration>
# Writes config/candidate/.xyzzy.proposed and prints a rationale to stderr.
set -eu

LAST_RUN=$1
LOOP_ROOT=$(cd "$(dirname "$0")/.." && pwd)

PROMPT_FILE=$(mktemp)
{
  cat <<'HDR'
You are improving the developer experience of xyzzy, an Emacs-like editor,
by editing its user init file `.xyzzy` (xyzzy's Common-Lisp dialect).
The goal is to make xyzzy work well as a generic software-development
environment: builds with error navigation, search/grep, code navigation,
completion, and clear feedback.

You may:
- (require "...") any library that ships in lisp/ (wsl [build command],
  grep, imenu, flymake, dabbrev, fuzzy-complete, snippet, recentf,
  saveplace, autopair, iedit, expand-region, project, tags, git, ...)
- define keys, hooks, aliases, small helper functions, and *-variable
  defaults
- keep it small: only changes motivated by the evidence below

Constraints:
- The file must be loadable by xyzzy on startup; no external packages.
- Do not wrap everything in ignore-errors to mask real failures.
- Output ONLY the complete new .xyzzy file content, no commentary, no
  markdown fences.
HDR
  echo
  echo "== accumulated lessons =="
  cat "$LOOP_ROOT/library/lessons.md"
  echo
  echo "== current candidate .xyzzy =="
  cat "$LOOP_ROOT/config/candidate/.xyzzy"
  echo
  if [ -n "$LAST_RUN" ] && [ -d "$LAST_RUN" ]; then
    echo "== last run summary =="
    cat "$LAST_RUN/summary.json" 2>/dev/null || true
    echo
    echo "== last judge notes =="
    cat "$LAST_RUN/judge.json" 2>/dev/null || true
  fi
} > "$PROMPT_FILE"

"$LOOP_ROOT/lib/llm.sh" < "$PROMPT_FILE" \
  > "$LOOP_ROOT/config/candidate/.xyzzy.proposed"

# strip markdown fences if the model added them anyway
python3 - "$LOOP_ROOT/config/candidate/.xyzzy.proposed" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'^```[a-zA-Z]*\n', '', s)
s = re.sub(r'\n```\s*$', '', s)
open(p, 'w').write(s)
PY
wc -l "$LOOP_ROOT/config/candidate/.xyzzy.proposed" >&2
