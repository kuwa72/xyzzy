#!/bin/sh
# Run every task under a config. Arguments: <config-name> <run-label>
# Output dir: runs/<label>/
set -eu

CONFIG_NAME=$1
LABEL=$2
LOOP_ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONFIG_DIR="$LOOP_ROOT/config/$CONFIG_NAME"
OUT="$LOOP_ROOT/runs/$LABEL"

mkdir -p "$OUT"
for t in "$LOOP_ROOT"/tasks/*/; do
  tid=$(basename "$t")
  "$LOOP_ROOT/lib/run-task.sh" "$t" "$CONFIG_DIR" "$OUT/$tid"
done

jq -s --arg label "$LABEL" --arg cfg "$CONFIG_NAME" \
  '{label:$label, config:$cfg,
    tasks: map({key:.task, value:{steps,elapsed_s,expects}}) | from_entries,
    checks_passed: (map(.expects.passed) | add),
    checks_total: (map(.expects.total) | add)}' \
  "$OUT"/*/status.json > "$OUT/summary.json"
echo "run-suite: $LABEL  $OUT/summary.json"
cat "$OUT/summary.json"
