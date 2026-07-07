# tether harness — operating defaults (Codex edition)

For projects you're actively building or maintaining, follow this loop. (Skip for
throwaway scripts, one-off questions, or repos that aren't yours.) Skills are Codex
**custom prompts** — invoke them as `/prompts:<name>`.

- **Start:** run `/prompts:catchup` when opening a project cold or after compaction.
- **Approach:** for non-trivial (multi-file / unfamiliar / long-horizon) work, run
  `/prompts:plan-change` (localize → plan → implement → validate). Skip for small edits.
- **Consequential decisions:** for a hard-to-reverse design/experiment choice with
  several valid options, run `/prompts:council` before committing to an approach.
- **Verify, don't self-certify:** fix the diagnostics the `verify-on-edit` hook hands
  back, and use `/prompts:test-first` for changes with a checkable outcome. "Done" =
  the verifier passes, not that it looks right; never weaken a test to make it green.
- **Arm the done-gate:** add a fast `.codex/verify.sh` (seconds, not minutes) — or set
  `VERIFY_CMD` — so project verification runs when you finish and blocks on failure.
- **Ship:** run `/prompts:ship` when a change lands.
- **Research runs:** run `/prompts:experiment-log` to record config/seed/version/metrics.
- **Invariant:** externalize state (doc or commit) *before* compacting or clearing, and
  leave irreversible steps (clear, publish, push) to a human. Externalize → verify → discard.

Background on the *why* of each piece: `references/HARNESS.md` and `references/WORKFLOW.md`.
