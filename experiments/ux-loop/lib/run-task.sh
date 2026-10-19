#!/bin/sh
# Run one task under one config. Arguments: <task-dir> <config-dir> <run-dir>
# Produces in <run-dir>:
#   transcript.txt   pty-drive output (screen dump per step + cursor)
#   status.json      per-expectation pass/fail + summary
#
# The task's fixture is copied to <run-dir>/home/work and its .xyzzy comes
# from <config-dir>. steps come from <config-dir>/steps/<task-id>.txt when
# present (candidate-specific interaction), else the task's own steps.txt.
set -eu

TASK_DIR=$(cd "$1" && pwd)
CONFIG_DIR=$(cd "$2" && pwd)
RUN_DIR=$3
LOOP_ROOT=$(cd "$(dirname "$0")/.." && pwd)
REPO_ROOT=$(cd "$LOOP_ROOT/../.." && pwd)
mkdir -p "$RUN_DIR"
RUN_DIR=$(cd "$RUN_DIR" && pwd)

TASK_ID=$(basename "$TASK_DIR")
mkdir -p "$RUN_DIR/home"

# fresh HOME: candidate .xyzzy + fixture project
cp "$CONFIG_DIR/.xyzzy" "$RUN_DIR/home/.xyzzy"
if [ -d "$TASK_DIR/fixture" ]; then
  mkdir -p "$RUN_DIR/home/work"
  cp -r "$TASK_DIR/fixture/." "$RUN_DIR/home/work/"
fi

# steps: candidate override wins
if [ -f "$CONFIG_DIR/steps/$TASK_ID.txt" ]; then
  STEPS_FILE="$CONFIG_DIR/steps/$TASK_ID.txt"
else
  STEPS_FILE="$TASK_DIR/steps.txt"
fi

OPEN=$(jq -r '.open // empty' "$TASK_DIR/task.json")
EXTRA=$(jq -r '.args // empty' "$TASK_DIR/task.json")

# container-visible paths (repo root is /work inside tools/x)
HOME_IN_C="/work/${RUN_DIR#"$REPO_ROOT"/}"
ARGS_IN_C="-no-image $EXTRA"
[ -n "$OPEN" ] && ARGS_IN_C="$ARGS_IN_C $HOME_IN_C/home/$OPEN"

set --
while IFS= read -r line; do
  case "$line" in '' | \#*) continue ;; esac
  set -- "$@" "$line"
done < "$STEPS_FILE"

NSTEPS=$#
cd "$REPO_ROOT"
START=$(date +%s)
timeout 300 tools/x run env \
  "XYZZYHOME=$HOME_IN_C/home" \
  "XYZZY_PTY_ARGS=$ARGS_IN_C" \
  python3 tools/pty-drive.py "$@" \
  > "$RUN_DIR/transcript.txt" 2> "$RUN_DIR/stderr.log" || true
ELAPSED=$(( $(date +%s) - START ))

# expectations: expect[] greps the whole transcript, expect_last[] greps
# only the final screen block (everything after the last '===' marker).
awk '/^=== (startup|after) /{b=""} {b=b $0 "\n"} \
  END{printf "%s", b}' "$RUN_DIR/transcript.txt" > "$RUN_DIR/.last_screen.txt"

TOTAL=0; PASSED=0
: > "$RUN_DIR/checks.jsonl"
check() {  # $1 pattern  $2 scope  $3 haystack
  TOTAL=$((TOTAL + 1))
  if grep -q "$1" "$3"; then
    PASSED=$((PASSED + 1)); ok=true
  else
    ok=false
  fi
  jq -n --arg pat "$1" --arg scope "$2" --argjson ok "$ok" \
    '{pattern:$pat,scope:$scope,pass:$ok}' >> "$RUN_DIR/checks.jsonl"
}
jq -r '.expect[]?' "$TASK_DIR/task.json" > "$RUN_DIR/.exp_whole"
jq -r '.expect_last[]?' "$TASK_DIR/task.json" > "$RUN_DIR/.exp_last"
while IFS= read -r pat; do
  check "$pat" transcript "$RUN_DIR/transcript.txt"
done < "$RUN_DIR/.exp_whole"
while IFS= read -r pat; do
  check "$pat" last "$RUN_DIR/.last_screen.txt"
done < "$RUN_DIR/.exp_last"
rm -f "$RUN_DIR/.exp_whole" "$RUN_DIR/.exp_last"

jq -n --arg id "$TASK_ID" --argjson steps "$NSTEPS" \
  --argjson elapsed "$ELAPSED" \
  --argjson total "$TOTAL" --argjson passed "$PASSED" \
  '{task:$id, steps:$steps, elapsed_s:$elapsed,
    expects:{total:$total, passed:$passed}}' > "$RUN_DIR/status.json"
echo "run-task: $TASK_ID  $PASSED/$TOTAL checks, $NSTEPS steps, ${ELAPSED}s"
