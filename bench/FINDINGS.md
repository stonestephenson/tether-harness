# FINDINGS — Phase 2 verification list + pilot

The six unknowns DESIGN.md flagged as *assumed, not verified* (its Phase-2
verification list), tracked to resolution. Each is a gate on the Phase-4
pre-registration freeze: a surprising answer can change the design. Probes that call
the model are **user-fired** (author's subscription auth); the harness for each is in
`probes/` and self-tests model-free first.

| # | Question | Probe | Status | Finding |
|---|----------|-------|--------|---------|
| 1 | Headless `claude -p` under a **blocking Stop hook** — does it loop, or hit an internal turn ceiling? And how many times does the **real done-gate** actually block (its `stop_hook_active` guard may block only once, not "until green")? | `probes/stop_hook/` (P1-real) | **✅ ANSWERED (2026-07-16 clean run)** | **Done-gate = a SINGLE finish-time nudge.** Against a perpetually-red verifier: invocations 2, **blocks 1**, clean exit (code 0), 4 turns, 27s. The gate blocks the first finish attempt with the failing output; its `stop_hook_active` guard then lets the next attempt through **even though still red**. So **no infinite-loop risk** with the real gate → the per-run wall-clock cap is a backstop, not load-bearing for the done-gate arm. H1's mechanism wording is corrected in DESIGN.md. *Residual:* whether `stop_hook_active` resets after substantial work (this verifier was unfixable, so the agent gave up in 2 turns) — the pilot on real tasks shows if the gate ever re-blocks. **P1-raw (2026-07-16): the CLI has NO internal re-block ceiling** — an unconditional-block hook looped to the 6/6 self-cap (18 turns, 65s), so the per-run wall-clock/turn cap IS load-bearing as a backstop for any guard-less hook (the real done-gate stays safe via its guard). |
| 1b | **Auth: how does a sandboxed arm authenticate as the subscription?** (surfaced by the 2nd fire) | same | **✅ ANSWERED — runner design decision** | A fresh `CLAUDE_CONFIG_DIR` does NOT inherit the macOS-keychain login (run returned `"Not logged in · Please run /login"`). Solution: `claude setup-token` → export **`CLAUDE_CODE_OAUTH_TOKEN`** (confirmed the CLI reads it: `Authorization: Bearer $CLAUDE_CODE_OAUTH_TOKEN`). Subscription auth, zero API cost, works across sandboxes. The runner sets this env for every arm; probes fail fast without it (`_auth_preflight.sh`). Token is gitignored, never logged. |
| 2 | Does subscription auth accept dated model-snapshot ids, and does the result JSON reliably report usage (incl. cache-read tokens), `num_turns`, served model id? | `probes/stop_hook/` (parse_result on any run) | **✅ ANSWERED (clean run), one sub-item open** | Clean run populated everything: `num_turns` 4, `usage` = input 8 / output 1097 / **cache_read 120918** / cache_creation 9346 (cache reads dominate ⇒ the cost metric MUST exclude them, as designed), `total_cost_usd` 0.109 (reported even on subscription — an API-equivalent cost proxy, usable), plus `ttft_ms`/`time_to_request_ms`/`fast_mode_state`/`permission_denials`. **`modelUsage` = `{claude-haiku-4-5-20251001, claude-sonnet-5}`** — every session runs a **background Haiku** alongside the main model; the runner must attribute the *requested* `--model` as the arm's model and treat the background Haiku as harness overhead (its tokens still count toward cost). Default resolved to the alias `claude-sonnet-5`. **Open:** does `--model <dated-snapshot>` work under subscription? (test when the runner sets models.) |
| 3 | Weekly cap sizes vs measured gated-arm token burn — do ~610 runs fit in ~2–3 weeks? | first real cells (dg01, Sonnet) | **answered (dev-task scale)** | A real dev-task cell ≈ **5 turns, ~$0.11–0.12 API-equiv, ~600–900 output tok, ~155k cache-read, well under the 30-min/50-turn cap** (subscription — dollars phantom). ~610 such runs is very affordable in quota/calendar terms. Harder/longer confirmatory tasks may cost more; the cap bounds worst-case. |
| 4 | Is autoupdate-disable effective in headless sandboxes (CLI version stays pinned across the window)? | `probes/stop_hook/` sets `DISABLE_AUTOUPDATER=1`; check `claude --version` before/after | **partially covered by P1** | — |
| 5 | A0's **spontaneous** `verify.sh`-run rate on dev tasks (grounds H1's mediator baseline — how often does vanilla finish red when told to verify?) | dg01 (Sonnet, n=1) | **partial — task-dependent** | On dg01/Sonnet, vanilla wrote a correct fix and finished **green** (hidden PASS), so finish-red ≈ 0 here ⇒ dg01 can't test H1 on Sonnet (the falsifier). The rate is a property of task × model, not a constant — the confirmatory tasks must be constructed to induce a visible-red finish (see the task-design lesson below). Needs more reps + tasks + Haiku. |
| 6 | Realized mining yield through stage 5 (council estimate: 1–3% of candidate PRs) | needs the mining pipeline (later in Phase 2) | pending | — |
| 7 | **Headless permission mode** (surfaced by the first real cell) | `runner/run_cell.sh` | **✅ ANSWERED — runner design decision** | Default headless `claude -p` prompts before edits/bash; with no one to approve, the agent does **zero work** and asks for approval in its final message (first A0 fire: 5 turns, empty diff, `result:"I need permission to edit fields.py"`). Fix: `--permission-mode bypassPermissions` (choices confirmed via `claude --help`). Applied **uniformly to all arms** — permission mode is harness environment, **not** a treatment variable — and the workspace is a throwaway isolated copy. |

## Probe run log

**2026-07-16 — P1-real, first fire (author's Mac, CLI 2.1.211): portability bug,
no result.** `run_p1_real.sh` exited 127 (`timeout: command not found`) — macOS
ships no GNU `timeout`, so `claude` never launched (counters 0, empty result). This
is a **runner requirement, not just a probe fix**: the study runs on macOS and the
per-run wall-clock cap (DESIGN.md) can't depend on GNU coreutils. Fixed with
`probes/stop_hook/_timeout.sh` (`portable_timeout`: prefers `timeout`/`gtimeout`,
else a pure-bash watchdog; self-tested on the no-`timeout` path). **The runner must
use this wrapper for its caps.** Re-fire pending. (Also observed: the live CLI is
2.1.211, up from 2.1.207 on 2026-07-12 — relevant to verification item #4; the
Phase-4 freeze must pin the installed binary version and disable background updates
for the collection window.)

**2026-07-16 — P1-real, second fire: auth wall, no result.** `claude` launched
(59ms, `num_turns:1`, `is_error:true`) and returned `result: "Not logged in ·
Please run /login"`, `terminal_reason: api_error`. Root cause + solution recorded
as item **1b** above (sandbox needs `CLAUDE_CODE_OAUTH_TOKEN`).

**2026-07-16 — P1-real, third fire: clean, the answer.** With
`CLAUDE_CODE_OAUTH_TOKEN` set: exit 0, `is_error:false`, 4 turns, 27s,
invocations 2 / **blocks 1** against a perpetually-red verifier. Resolves items #1
and #2 (above). **Consequence: DESIGN.md H1 mechanism reworded** from "blocks Stop
until green" → "a single deterministic finish-time nudge (blocks once, then the
`stop_hook_active` guard allows termination)". The hypothesis is unchanged (does
that one forced verification lift hidden pass?); only the mechanism description
moved to match reality. This is the design-vs-reality reconciliation the probe
phase exists for.

*(Resolved: the done-gate source-read note of 2026-07-15 — the `stop_hook_active`
single-block hypothesis is now confirmed empirically.)*

**2026-07-16 — first REAL cells (dg01, Sonnet 5, post permission-fix): the
pipeline works end-to-end.** A0 (vanilla) and A2 (done-gate) each: exit 0, 5
turns, ~$0.11–0.12, **both hidden PASS**, A2 `hook_blocks=0`. The agent read the
task, edited `fields.py`, ran `verify.sh`, and wrote a *correct* fix that kept the
visible suite green — so the done-gate never had a red finish to block.
**Milestone:** provision → real `claude -p` → harvest → hidden grade all work.

**Task-design lesson (dev tasks earning their keep).** dg01 does **not
discriminate** on Sonnet: a capable model writes the golden fix directly, vanilla
never ships visible-red, and the gate can't help. For a T-DG task to test H1, the
*obvious* fix must be the naive one (breaking a visible neighbor) so vanilla's
modal trajectory ends visible-red — OR the target model must be weak enough to
take that route. Two consequences: (a) the mining/injection protocol must
select/verify **visible-red-inducing** traps (calibrated per model on dev tasks);
(b) the capability angle (S2/Haiku) is live here — the same trap may spring on
Haiku where it doesn't on Sonnet. Next cheap probe: dg01 on Haiku (A0 vs A2).

**2026-07-16 — P1-raw: CLI raw ceiling.** An unconditional-block Stop hook (no
`stop_hook_active` guard, self-cap 6) drove `claude -p` to 6/6 blocks, 18 turns,
65s, exit 0. **The CLI imposes no ceiling of its own** — it re-invites the agent
for every block until the hook stops blocking. Conclusion: the per-run wall-clock/
turn cap is required infrastructure (a guard-less or buggy hook would loop), even
though the shipped done-gate is safe. Cost/turn floor recorded in item #3.
