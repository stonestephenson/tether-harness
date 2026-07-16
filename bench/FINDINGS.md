# FINDINGS — Phase 2 verification list + pilot

The six unknowns DESIGN.md flagged as *assumed, not verified* (its Phase-2
verification list), tracked to resolution. Each is a gate on the Phase-4
pre-registration freeze: a surprising answer can change the design. Probes that call
the model are **user-fired** (author's subscription auth); the harness for each is in
`probes/` and self-tests model-free first.

| # | Question | Probe | Status | Finding |
|---|----------|-------|--------|---------|
| 1 | Headless `claude -p` under a **blocking Stop hook** — does it loop, or hit an internal turn ceiling? And how many times does the **real done-gate** actually block (its `stop_hook_active` guard may block only once, not "until green")? | `probes/stop_hook/` (P1-raw + P1-real) | **rebuilt, awaiting re-fire** | 1st fire (2026-07-16) hit a portability bug, not a result — see log below |
| 2 | Does subscription auth accept dated model-snapshot ids, and does the result JSON reliably report usage (incl. cache-read tokens), `num_turns`, served model id? | `probes/stop_hook/` (parse_result on any run) | **built, awaiting user fire** | — |
| 3 | Weekly cap sizes vs measured gated-arm token burn — do ~610 runs fit in ~2–3 weeks? | (needs the burn multiplier from a pilot cell) | pending | — |
| 4 | Is autoupdate-disable effective in headless sandboxes (CLI version stays pinned across the window)? | `probes/stop_hook/` sets `DISABLE_AUTOUPDATER=1`; check `claude --version` before/after | **partially covered by P1** | — |
| 5 | A0's **spontaneous** `verify.sh`-run rate on dev tasks (grounds H1's mediator baseline — how often does vanilla finish red when told to verify?) | needs dev tasks (later in Phase 2) | pending | — |
| 6 | Realized mining yield through stage 5 (council estimate: 1–3% of candidate PRs) | needs the mining pipeline (later in Phase 2) | pending | — |

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

## Open note carried from the done-gate source read (2026-07-15)

`plugins/tether/hooks/done-gate.py` guards against infinite loops with
`stop_hook_active` (docstring: "never block twice in a row"). If that means the gate
delivers a **single** forced repair-nudge rather than blocking until the verifier is
green, then DESIGN.md's H1 mechanism wording ("blocks Stop until `verify.sh` is
green, forcing the repair") is inaccurate and must be corrected before the freeze.
**P1-real measures exactly this** (invocation + block counts against a perpetually-red
verifier). Whatever it shows, H1's mechanism paragraph gets reconciled to the
observed behavior — the hypothesis (one nudge or a wall, does enforcement beat
instruction?) is unchanged; only the mechanism description is at stake.
