#!/bin/sh
# Judge every transcript in a run with the LLM. Argument: <run-dir>
# Writes <run-dir>/judge.json  {tasks:{id:{outcome,feedback,friction,
# discoverability,note}}, mean_ux}
set -eu

RUN_DIR=$1
LOOP_ROOT=$(cd "$(dirname "$0")/.." && pwd)

PROMPT_FILE=$(mktemp)
{
  echo "You are a UX judge for a text-editor improvement loop."
  echo
  cat "$LOOP_ROOT/rubric.md"
  echo
  echo "== RUN =="
  for d in "$RUN_DIR"/*/; do
    [ -f "$d/task.id" ] || basename "$d" > "$d/task.id"
    tid=$(basename "$d")
    task_json="$LOOP_ROOT/tasks/$tid/task.json"
    [ -f "$task_json" ] || continue
    echo "--- task: $tid ---"
    jq -r '.title, "GOAL: " + .goal' "$task_json"
    echo "--- transcript ---"
    # cap each transcript: tail keeps the end state visible
    tail -n 260 "$d/transcript.txt"
    echo
  done
  echo "Score every task now. JSON only."
} > "$PROMPT_FILE"

"$LOOP_ROOT/lib/llm.sh" < "$PROMPT_FILE" > "$RUN_DIR/judge.raw" || true
rm -f "$PROMPT_FILE"

# extract the JSON object (model may wrap it in prose)
python3 - "$RUN_DIR/judge.raw" "$RUN_DIR/judge.json" <<'PY'
import json, re, sys
raw = open(sys.argv[1]).read()
m = re.search(r'\{.*\}', raw, re.S)
if not m:
    print("judge: no JSON in model output", file=sys.stderr); sys.exit(1)
data = json.loads(m.group(0))
tasks = data.get("tasks", {})
axes = ("outcome","feedback","friction","discoverability")
scores = [t[a] for t in tasks.values() for a in axes if a in t]
data["mean_ux"] = round(sum(scores)/len(scores), 2) if scores else 0
json.dump(data, open(sys.argv[2], "w"), indent=2, ensure_ascii=False)
print(f"judge: mean_ux={data['mean_ux']}  -> {sys.argv[2]}")
PY
