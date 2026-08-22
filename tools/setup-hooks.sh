#!/bin/sh
# Point git at the hooks that are checked in.
#
# .git/hooks is not versioned, so a hook committed to the repository does
# nothing until core.hooksPath says where to look.  This does that, and it is
# idempotent and quiet when already set, because .claude/settings.json runs it
# from a SessionStart hook -- every Claude Code session in this repository
# installs the git hooks without anyone remembering to.
#
# Safe to run by hand in a fresh clone:  tools/setup-hooks.sh
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# Not a git repository (a tarball, a vendored copy): nothing to do, and no
# reason to fail a session over it.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

chmod +x .githooks/* 2>/dev/null || true

current=$(git config --get core.hooksPath 2>/dev/null || true)
if [ "$current" = .githooks ]; then
  exit 0
fi

if [ -n "$current" ]; then
  echo "setup-hooks: core.hooksPath is '$current', leaving it alone." >&2
  echo "setup-hooks: to use the hooks in this repo: git config core.hooksPath .githooks" >&2
  exit 0
fi

git config core.hooksPath .githooks
echo "setup-hooks: core.hooksPath -> .githooks (pre-commit, pre-push now active)"
