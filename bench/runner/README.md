# runner/ — the bake-off execution rig

Provisions sandboxed arms and (soon) executes the run matrix for the study in
[`../../paper/DESIGN.md`](../../paper/DESIGN.md). Built on the two mechanisms the
`stop_hook` probes proved out: `CLAUDE_CODE_OAUTH_TOKEN` auth (subscription, zero
API cost) and `../probes/stop_hook/_timeout.sh`'s `portable_timeout` for per-run
wall-clock caps. Never touches `~/.claude`. Validate model-free:
`bash bench/runner/selftest.sh`.

## Built so far

- **`provision_arm.py`** — writes a per-arm `CLAUDE_CONFIG_DIR/settings.json`
  wiring the arm's hook subset, each hook routed through `hook_wrap.py`:
  `A0` none · `A1` verify-on-edit · `A2` done-gate · `A3` full hooks. (A4 skills
  arm cut per DESIGN E2.) Mirrors `plugins/tether/hooks/hooks.json` so an arm's
  hooks behave exactly as shipped.
- **`hook_wrap.py`** — telemetry: appends one JSONL record per hook invocation
  (`hook`, `session_id`, `stop_hook_active`, `exit`, `decision`, `blocked`), then
  runs the real hook transparently — passes stdin through, mirrors stdout, stderr,
  and exit code (so verify-on-edit's exit-2 block and done-gate's JSON block both
  survive). Feeds firing counts + the per-hook precision audit (RLVM Table 6).
- **`schedule.py`** — deterministic run order from `(blocks, seed)`: groups by
  `(block, model, task, rep)` and keeps each group's arms contiguous (temporally
  local paired comparisons) while shuffling groups to interleave blocks and spread
  serving drift. Reproducible; the seed is pre-registered.

- **`verify_hidden.py`** — the hidden-verifier harness: fresh scrubbed checkout of
  a task's `repo/`, overlay ONLY the agent's source edits (path allowlist —
  test/config files stay at base so a weakened visible test can't leak into the
  grade), drop in the held-out hidden tests, run the full suite, report
  visible/hidden/overall pass. Validated end-to-end by
  `../tasks/dev/dg01/validate.sh` (fail-on-base, pass-on-golden, trap-fires).

- **`run_cell.sh`** — executes one cell end-to-end: provision the arm → copy the
  task's `repo/` into a workspace → fire `claude -p --model` under
  `portable_timeout` → harvest (`result.json`, `agent.diff`, `hooks.jsonl`) →
  grade with `verify_hidden` → print a summary (turns, hook-blocks, cost, hidden
  grade). Sandboxed; user-fired (needs the OAuth token). `--dry-run base|golden|
  naive` skips the model and simulates the agent with a task variant — the whole
  provision→harvest→grade path is validated model-free that way.

## Not built yet (next)

A batch driver over `schedule.py` (fire the ordered cell list, failure-disposition
+ drift-canary, append to `RESULTS.md`), more dev tasks, and the task-mining
pipeline. Verification items #3–#6 (`../FINDINGS.md`) close as these land — the
first user-fired `run_cell.sh` on `dg01` (A0 then A2) answers #5 (A0's spontaneous
verify.sh-run rate) and #3 (real cap-vs-burn), and gives the first live signal on
whether the done-gate nudge helps.
