# ux-loop — judge-in-the-loop iterative UX improvement for xyzzy

A SELF-REFINE-style loop that improves how xyzzy works as a generic
software-development environment, evaluated by driving the real editor on a
pty and letting an LLM judge the transcripts.

## What is being optimized

`config/candidate/.xyzzy` — the user init file (xyzzy's Common-Lisp dialect).
This is the "harness": the settings, required libraries, key bindings and
small helpers that shape the IDE experience. `config/base/.xyzzy` is the
stock baseline for comparison.

Optionally a config may also ship `steps/<task-id>.txt` to replace a task's
default keystroke script — that is how a proposal can demonstrate a *shorter*
workflow (e.g. a new command that replaces five steps with one).

## Tasks

`tasks/<id>/`:

| file | meaning |
|---|---|
| `task.json` | `id`, `title`, `goal` (judge sees this), `open` (fixture file opened at startup), `expect` (strings/regex that must appear in the transcript) |
| `fixture/` | the mini project copied into the run's `$HOME/work` |
| `steps.txt` | pty-drive steps, one per line (`\e` ESC `\r` RET `\Cx` ctrl `\w` wait) |

Current suite: T01 isearch navigation, T02 `build` + `next-error`,
T03 buffer `grep` + jump to hit, T04 dabbrev completion, T05 `imenu` jump.

## How a run works

`lib/run-task.sh` copies the candidate `.xyzzy` and the fixture into a fresh
`runs/<label>/<task>/home`, then runs the real editor in the tools/x
container via `tools/pty-drive.py` and saves `transcript.txt` +
`status.json` (per-expectation pass/fail, step count, wall time).

`lib/judge.sh` sends all transcripts plus `rubric.md` to the LLM backend and
writes `judge.json` with per-task scores on 4 axes (outcome, feedback,
friction, discoverability) and `mean_ux`.

## Commands

```sh
# baseline measurement (do this first, once)
experiments/ux-loop/lib/run-suite.sh base base-000
experiments/ux-loop/lib/judge.sh experiments/ux-loop/runs/base-000

# one full iteration: propose -> run -> judge -> adopt/revert -> reflect
experiments/ux-loop/lib/iterate.sh iter-001

# repeat
experiments/ux-loop/lib/iterate.sh iter-002
```

Adoption rule: candidate is kept iff no expectation check regressed and
`mean_ux` did not drop. Every iteration appends one line to `history.tsv`
and one lesson entry to `library/lessons.md` — the library is the persistent
"improvement harness" the next proposal reads.

## LLM backend

`lib/llm.sh` wraps a headless CLI; select with `UX_LOOP_LLM`:

| value | command | status here |
|---|---|---|
| `codex` (default) | `codex exec --skip-git-repo-check` | verified |
| `claude` | `claude -p` | OAuth expired |
| `gemini` | `gemini -p` | needs browser auth |

Alternatively run the phases manually (`run-suite.sh`, `judge.sh`,
`propose.sh`) and let any agent session act as proposer/judge — the prompts
are plain text in those scripts.

## Honest limits

- The interaction script is fixed per task (unless a config overrides it), so
  what varies is whether the same gestures produce a better outcome — not
  free-form discovery. A genuinely agentic driver (LLM emits keystrokes
  step-by-step) is phase 2.
- `expect` checks are transcript greps; the judge's 1-5 scores carry the UX
  signal. Treat `mean_ux` as a trend, not ground truth.
- Runs are deterministic enough for regression detection, not for
  benchmarking.
