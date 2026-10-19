#!/bin/sh
# Single entry point for "ask an LLM CLI". Prompt on stdin, answer on stdout,
# diagnostics on stderr. Backend is $UX_LOOP_LLM (opencode | codex | claude |
# gemini), default opencode — verified headless here (codex also works but
# rate-limits; claude OAuth expired; gemini wants a browser).
# Retries up to 3 times on empty output.
set -eu

BACKEND=${UX_LOOP_LLM:-opencode}
PROMPT_FILE=$(mktemp)
cat > "$PROMPT_FILE"

call() {
  case "$1" in
    opencode)
      timeout "${UX_LOOP_LLM_TIMEOUT:-240}" opencode run "$(cat "$PROMPT_FILE")" \
        < /dev/null 2>/dev/null \
        | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e '/^> /d' -e '/^$/d'
      ;;
    codex)
      timeout "${UX_LOOP_LLM_TIMEOUT:-240}" \
        codex exec --skip-git-repo-check "$(cat "$PROMPT_FILE")" \
        < /dev/null 2>/dev/null
      ;;
    claude)
      claude -p "$(cat "$PROMPT_FILE")" < /dev/null 2>/dev/null
      ;;
    gemini)
      gemini -p "$(cat "$PROMPT_FILE")" < /dev/null 2>/dev/null
      ;;
    *) echo "llm.sh: unknown backend $1" >&2; return 2 ;;
  esac
}

i=1
while [ "$i" -le 3 ]; do
  OUT=$(call "$BACKEND") || OUT=""
  if [ -n "$OUT" ]; then
    printf '%s\n' "$OUT"
    rm -f "$PROMPT_FILE"
    exit 0
  fi
  echo "llm.sh: $BACKEND empty output (attempt $i)" >&2
  i=$((i + 1))
  sleep 5
done
rm -f "$PROMPT_FILE"
echo "llm.sh: $BACKEND gave no output after 3 attempts" >&2
exit 1
