# eval/ — tether vs. vanilla: what we tested and found (CONCLUDED)

**Status: concluded 2026-07-17.** An internal evaluation of whether tether's
deterministic verification hooks improve coding-agent outcomes over vanilla Claude
Code, and which mechanisms carry the weight. Stopped after the pilot answered the
first-order question and the marginal value of continuing didn't justify the cost.
Detail + run log: [`../bench/FINDINGS.md`](../bench/FINDINGS.md),
[`../bench/RESULTS.md`](../bench/RESULTS.md).

## What we found

- **The done-gate carries ~no weight for frontier models on solvable tasks.** 20 cells
  (dg01/dg02 trap tasks × Sonnet 5 + Haiku 4.5 × vanilla/done-gate): zero
  discrimination, zero gate firings. Capable models self-verify (ran `verify.sh` even
  unprompted) and write correct code first-try, so the "finish with tests red" failure
  mode the gate targets doesn't occur. Consistent with the research — RLVM (gates help
  only where the model can't self-check) and mini-swe-agent (minimal scaffolds win).
- **The deeper point:** tether's value splits into **easy-to-measure hooks** (the
  deterministic gates, which capable models mostly don't need on clean tasks) and
  **hard-to-measure judgment/context value** (planning, context management,
  long-horizon coherence — where the day-to-day value likely lives, and which a bugfix
  benchmark can't see).
- **The instrument works** end-to-end (per-arm sandboxes, hidden verifiers, mechanism
  decomposition) — kept in `../bench/` as the reproducible basis of the above.

## Why we stopped

The honest first-order answer was in hand: the most *intrusive* verification mechanism
is the least necessary for frontier models. A fuller answer — measuring the harder
context/planning value on real long-horizon work — needed substantial SWE-bench/Docker
infrastructure for diminishing return. tether's value on real projects is trusted from
daily use; a clean public benchmark of it isn't worth that cost. Focus returns to
improving the harness itself (the monthly `sota-radar` sweep + sharpening existing
tools).

## Design (for the record)

Arms, same task each: **A0** vanilla / **A1** verify-on-edit / **A2** done-gate / **A3**
full hooks; grade = a hidden test suite the agent never sees. Runner:
[`../bench/runner/`](../bench/runner/). Controls that took real debugging (see
FINDINGS): sandboxed `CLAUDE_CONFIG_DIR` per arm, subscription auth via
`CLAUDE_CODE_OAUTH_TOKEN`, `--permission-mode bypassPermissions`, a portable timeout
(macOS ships no GNU `timeout`), macOS bash-3.2 quirks.

## Evidence base

RLVM (2607.07405), mini-swe-agent, SpecBench (2605.21384) / EvilGenie (2511.21654),
Harness-Bench (2605.27922) / Stop-Comparing (2605.23950). PDFs in `papers/` (gitignored).
