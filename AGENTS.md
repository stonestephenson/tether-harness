# tether harness — operating defaults (generic / tool-agnostic)

Most agentic coding tools read an `AGENTS.md`; these defaults work in any of them. The
"skills" are playbooks in `skills/<name>.md` — invoke them however your tool supports (a
custom command/prompt, or by pasting the playbook), or just follow them.

For projects you're actively building or maintaining (skip for throwaway scripts, one-off
questions, or repos that aren't yours):

- **Start:** follow the `catchup` playbook when opening a project cold or after compaction.
- **Approach:** for non-trivial (multi-file / unfamiliar / long-horizon) work, follow
  `plan-change` (localize → plan → implement → validate). Skip for small edits.
- **Consequential decisions:** follow `council` before a hard-to-reverse design or
  experiment choice with several valid options.
- **Verify, don't self-certify:** fix what the verify hook reports, and follow `test-first`
  for changes with a checkable outcome. "Done" = the verifier passes, not that it looks
  right; never weaken a test to make it green.
- **Arm the done-gate:** add a fast `.tether/verify.sh` (seconds) — or set `VERIFY_CMD` — so
  project verification runs when you finish and blocks on failure.
- **Ship:** follow `ship` when a change lands.
- **Research runs:** follow `experiment-log` to record config/seed/version/metrics.
- **Invariant:** externalize state (doc or commit) *before* compacting or clearing, and
  leave irreversible steps (clear, publish, push) to a human. Externalize → verify → discard.

The deterministic hooks live in `hooks/` — see `WIRING.md` to connect them to your tool's
event system. Why each piece: `references/HARNESS.md` and `references/WORKFLOW.md`.
