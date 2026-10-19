#!/bin/sh
# One full improvement iteration:
#   propose -> run suite on candidate -> judge -> adopt or revert -> reflect
# Usage: lib/iterate.sh <iter-label>   (e.g. iter-001)
set -eu

LABEL=$1
LOOP_ROOT=$(cd "$(dirname "$0")/.." && pwd)
CAND="$LOOP_ROOT/config/candidate"
OUT="$LOOP_ROOT/runs/$LABEL"

# the last run before this one (excluding ours) is the reference
PREV=$(ls -d "$LOOP_ROOT"/runs/*/ 2>/dev/null | sort | tail -1 || true)

mkdir -p "$OUT"
cp "$CAND/.xyzzy" "$OUT/.xyzzy.before"

"$LOOP_ROOT/lib/propose.sh" "${PREV%/}" 2> "$OUT/propose.log" || {
  echo "iterate: propose failed"; cp "$OUT/.xyzzy.before" "$CAND/.xyzzy"; exit 1; }
cp "$LOOP_ROOT/config/candidate/.xyzzy.proposed" "$OUT/.xyzzy.proposed"
mv "$LOOP_ROOT/config/candidate/.xyzzy.proposed" "$CAND/.xyzzy"

echo "iterate: running suite for candidate..."
"$LOOP_ROOT/lib/run-suite.sh" candidate "$LABEL"
"$LOOP_ROOT/lib/judge.sh" "$OUT"

NEW_UX=$(jq -r '.mean_ux // 0' "$OUT/judge.json")
NEW_PASS=$(jq -r '.checks_passed // 0' "$OUT/summary.json")
NEW_TOTAL=$(jq -r '.checks_total // 0' "$OUT/summary.json")

if [ -n "$PREV" ] && [ -f "${PREV}judge.json" ]; then
  OLD_UX=$(jq -r '.mean_ux // 0' "${PREV}judge.json")
  OLD_PASS=$(jq -r '.checks_passed // 0' "${PREV}summary.json")
else
  OLD_UX=0; OLD_PASS=0
fi

ADOPT=false
# adopt iff no expectation regressed and mean_ux did not drop
if [ "$NEW_PASS" -ge "$OLD_PASS" ] \
   && [ "$(echo "$NEW_UX >= $OLD_UX" | bc -l)" = "1" ]; then
  ADOPT=true
else
  cp "$OUT/.xyzzy.before" "$CAND/.xyzzy"
fi

printf '%s\t%s\tpass %s/%s\tmean_ux %s (prev %s)\n' \
  "$LABEL" "$ADOPT" "$NEW_PASS" "$NEW_TOTAL" "$NEW_UX" "$OLD_UX" \
  >> "$LOOP_ROOT/history.tsv"
echo "iterate: $LABEL adopted=$ADOPT  ux=$NEW_UX (prev $OLD_UX)  checks=$NEW_PASS/$NEW_TOTAL"

# reflect: append a lesson entry
{
  echo "Iteration $LABEL was $([ "$ADOPT" = true ] && echo ADOPTED || echo REJECTED)."
  echo "Old mean_ux=$OLD_UX new=$NEW_UX, checks $NEW_PASS/$NEW_TOTAL."
  echo "New .xyzzy:"; cat "$OUT/.xyzzy.proposed" 2>/dev/null || true
  echo "Judge notes:"; jq -r '.tasks[]?.note // empty' "$OUT/judge.json" 2>/dev/null || true
  echo "Write ONE library entry in the '## $LABEL — adopted|rejected' format:"
  echo "change / evidence / lesson. Output only that markdown block."
} | "$LOOP_ROOT/lib/llm.sh" >> "$LOOP_ROOT/library/lessons.md" || true
echo >> "$LOOP_ROOT/library/lessons.md"
