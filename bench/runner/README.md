# runner/ — the bake-off execution rig

Provisions sandboxed arms and executes the run matrix for the study in
[`../../eval/README.md`](../../eval/README.md). Built on the two mechanisms the
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

- **`run_batch.sh`** — turns a blocks spec + seed into a reproducible schedule
  (`schedule.py`), fires each cell (`run_cell.sh`), and appends one experiment-log
  row per cell to `../RESULTS.md`. `--dry-run V` runs the whole batch model-free.
  Specs live in `../runs/` (e.g. `pilot_dg01.json`). Fire the pilot:
  `bash bench/runner/run_batch.sh bench/runs/pilot_dg01.json --seed 1234`.

## Not built (the study concluded first)

Failure-disposition + drift-canary hardening in the batch loop, more dev tasks,
and the task-mining pipeline (verification item #6) — the pilot answered the
question before these were needed. The instrument is otherwise end-to-end:
provision → real `claude -p` → harvest → hidden grade → logged.
