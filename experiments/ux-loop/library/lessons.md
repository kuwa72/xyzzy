# Improvement library

Evidence-supported lessons accumulated by the ux-loop. The proposer reads this
before editing the candidate config; the reflector appends after each adopted
or rejected iteration.

Format per entry:

    ## <iteration id> — adopted|rejected
    - change: one line
    - evidence: which task/metric moved
    - lesson: what to keep doing / never do again

## iter-001 — rejected
- change: require imenu/grep/wsl/dabbrev; set *find-errors-find-buffers* t
- evidence: checks 9/10 unchanged, mean_ux 3.7 -> 3.6
- lesson: `next-error` fails even with find-buffers on. Root cause is in
  lisp/errors.l, not config: goto-error pops the current error onto
  *rerror-list* before visiting it, so with exactly one error (T02's
  fixture) rebuild-error-list returns empty and C-x ` reports
  "これ以上エラーはありません". With 3 hits (T03) it jumps but skips the
  first hit. Config cannot fix this; it needs a product patch.
