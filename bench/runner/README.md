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

## Not built yet (next)

Cell execution (provision → fire `claude -p` under `portable_timeout` → harvest
the per-run bundle: session JSONL, hook log, agent diff, hidden-verifier output),
the hidden-verifier harness (scrubbed checkout, diff-apply through a path
allowlist, test-config reset), failure-disposition + drift-canary, `RESULTS.md`
logging, and the task-mining pipeline + dev tasks. Verification items #3–#6
(`../FINDINGS.md`) close as these land.
