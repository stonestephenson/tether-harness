# bench/ — the tether-vs-vanilla evaluation instrument (ROADMAP #6)

The measurement rig for the evaluation whose goal, design, and findings live in
[`../eval/README.md`](../eval/README.md). `bench/` is the *instrument*; `eval/` is the
*study*. Neither ships to plugin users (installs carry only `plugins/tether/`).

**Status: study concluded 2026-07-17.** The question is answered — the done-gate
carries ~no weight for frontier models on solvable tasks (they self-verify / write
correct code first-try); [`../eval/README.md`](../eval/README.md) has the finding and
the stop decision. `bench/` stays as the reproducible instrument and durable record.
The de-risking probes below resolved the design's load-bearing unknowns *before* the
runner was built — cheap probes first; results are logged in
[`FINDINGS.md`](FINDINGS.md).

## Layout

- [`FINDINGS.md`](FINDINGS.md) — the verification-list results and pilot findings.
- [`RESULTS.md`](RESULTS.md) — the run log: one experiment-log row per executed cell.
- `probes/` — self-contained, sandboxed probes for the design's verification list.
  Each provisions its own throwaway `CLAUDE_CONFIG_DIR` under `$TMPDIR` and **never
  touches the live `~/.claude`** (standing ground rule). Model-calling probes are
  *user-fired* under the user's own auth; every probe ships a model-free `selftest`.
- `runner/` — the execution rig: arm provisioning, hook telemetry, hidden-verifier
  grading, single-cell and batch executors.
- `tasks/` — the hand-built dev tasks (`dg01`, `dg02`): repo, hidden tests, variants.
- `runs/` — the pilot batch specs.
