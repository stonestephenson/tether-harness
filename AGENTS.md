# tether harness — operating defaults (opencode edition)

For projects you're actively building or maintaining (skip for throwaway scripts,
one-off questions, or repos that aren't yours). Skills are opencode **commands** —
invoke them as `/<name>`.

- **Start:** run `/catchup` when opening a project cold or after compaction.
- **Approach:** for non-trivial (multi-file / unfamiliar / long-horizon) work, run
  `/plan-change` (localize → plan → implement → validate). Skip for small edits.
- **Consequential decisions:** run `/council` before a hard-to-reverse design or
  experiment choice with several valid options.
- **Verify, don't self-certify:** fix the diagnostics the verify-on-edit plugin
  reports, and use `/test-first` for changes with a checkable outcome. "Done" = the
  verifier passes, not that it looks right; never weaken a test to make it green.
- **Arm the done-gate:** add a fast `.tether/verify.sh` (seconds, not minutes) — or set
  `VERIFY_CMD` — so project verification runs when the session goes idle.
- **Ship:** run `/ship` when a change lands.
- **Research runs:** run `/experiment-log` to record config/seed/version/metrics.
- **Invariant:** externalize state (doc or commit) *before* compacting or clearing, and
  leave irreversible steps (clear, publish, push) to a human. Externalize → verify → discard.

Background on the *why* of each piece: `references/HARNESS.md` and `references/WORKFLOW.md`.
