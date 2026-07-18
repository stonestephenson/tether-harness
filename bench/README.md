# bench/ — the tether-vs-vanilla evaluation instrument (ROADMAP #6)

The measurement rig for the evaluation whose goal, design, and findings live in
[`../eval/README.md`](../eval/README.md). `bench/` is the *instrument*; `eval/` is the
*study*. Neither ships to plugin users (installs carry only `plugins/tether/`).

**Status: Phase 2 (instrument build), starting with de-risking probes.** Before
building the full runner we answer the six load-bearing unknowns DESIGN.md flagged as
*assumed, not verified* — cheap probes first, because any of them can reshape the
design before the Phase-4 freeze. Probe results are logged in
[`FINDINGS.md`](FINDINGS.md).

## Layout (grows as phases land — no empty scaffolding)

- [`FINDINGS.md`](FINDINGS.md) — the verification-list results and pilot findings.
- `probes/` — self-contained, sandboxed probes for the DESIGN.md verification list.
  Each provisions its own throwaway `CLAUDE_CONFIG_DIR` under `$TMPDIR` and **never
  touches the live `~/.claude`** (standing ground rule). Model-calling probes are
  *user-fired* under the user's own auth; every probe ships a model-free `selftest`.

Later phases add: the runner + per-arm sandbox provisioning, the hidden-verifier
harness, the task-mining pipeline + dev tasks, and `RESULTS.md` (the run log).
