# eval/ — does tether beat vanilla, and which parts carry the weight?

**Goal.** Objectively measure whether tether-harness improves coding-agent outcomes
over vanilla Claude Code — and, more usefully, **which mechanisms actually carry the
weight vs. which are fluff** — on the models actually used (Sonnet 5 / Opus), on
*real* work. This is an **internal engineering evaluation**, not a paper: the bar is
"convince a skeptical engineer," not a reviewer. A short public writeup is an optional
downstream bonus if a crisp result emerges, never the driver. (Reframed 2026-07-17
from an earlier paper-track study — see "How we got here".)

**Instrument.** [`../bench/`](../bench/) — per-arm sandboxes, hidden verifiers the
agent never sees, mechanism decomposition. Built and working end-to-end. Findings:
[`../bench/FINDINGS.md`](../bench/FINDINGS.md); run log:
[`../bench/RESULTS.md`](../bench/RESULTS.md).

## What we've learned so far

- **The instrument works** end-to-end: provision a per-arm sandbox → real `claude -p`
  → harvest → grade on held-out tests → log.
- **The done-gate carries ~no weight for frontier models on solvable tasks.** Across
  20 pilot cells (2 hand-built trap tasks × Sonnet 5 + Haiku 4.5 × vanilla/done-gate):
  zero discrimination, zero gate firings. Capable models self-verify or write correct
  code first-try, so the "finish with tests red" failure mode the gate targets doesn't
  occur. Consistent with the research (RLVM: gates help only where the model can't
  self-check; mini-swe-agent: minimal scaffolds win). A genuine anti-fluff result — the
  most *intrusive* verification mechanism is the least necessary for capable models.
  Detail + the runner gotchas found along the way: [`../bench/FINDINGS.md`](../bench/FINDINGS.md).

## The design

Same task in every arm (same repo, same visible tests, same `.claude/verify.sh`); the
only difference is which tether hooks are installed:

| Arm | Installed | Isolates |
|---|---|---|
| A0 | nothing (vanilla) | control |
| A1 | verify-on-edit | continuous lint/type feedback per edit |
| A2 | done-gate | finish-time verify enforcement |
| A3 | full tether hooks | the deployed hook layer |

Grade = a **hidden** test suite the agent never sees (a held-out margin catches
overfitting to the visible tests). Metrics: hidden-pass, tokens, wall-time, turns,
hook-firing counts. Runner: [`../bench/runner/`](../bench/runner/). Controls learned
the hard way (see FINDINGS): sandboxed `CLAUDE_CONFIG_DIR` per arm (never touches
`~/.claude`); subscription auth via `CLAUDE_CODE_OAUTH_TOKEN` (zero API cost);
`--permission-mode bypassPermissions` (headless has no approver); a portable timeout
(macOS ships no GNU `timeout`). Those are uniform across arms — environment, not
treatment.

## How we got here (condensed decision record)

- **2026-07-09** — commissioned as a zero-budget self-benchmark of tether.
- **2026-07-12 ("Option B")** — reframed to a pre-registered *publishable* study
  (mechanism ablation, task-mining pipeline, power analysis, multi-model, workshop
  target).
- **2026-07-17 — reframed to this internal evaluation.** The pilot showed the headline
  mechanism (done-gate) is ~null on capable models solving small hand-built tasks, and
  surfaced the deeper point: **tether's value splits into easy-to-measure parts
  (deterministic hooks, which capable models mostly don't need) and hard-to-measure
  parts (context management, planning, long-horizon coherence — where the value likely
  lives).** A formal paper needed multi-frontier-model runs, a mining pipeline, and
  pre-registration — high cost, and aimed at the wrong question. So: keep the
  instrument, drop the paper apparatus, measure the real thing on real tasks.

**Explicitly dropped** (in git history — don't resurrect without a new reason):
pre-registration/OSF, power analysis, the mechanical task-mining pipeline, the
multi-frontier-model requirement, workshop/venue targeting, the doc-set differential,
and capability-sweep-as-headline (a weak-model win isn't the goal — the point is the
models actually used).

## Next: real tasks (path A)

Hand-built trap tasks don't discriminate on capable models — they just solve them. The
value, if any, lives in *real, hard* work, so use real tasks rather than construct them:

- Wire a small subset of **SWE-bench-Verified** (real GitHub bugs, real repos, real
  `FAIL_TO_PASS` + `PASS_TO_PASS` suites) into the existing runner. Real difficulty,
  real hidden tests, and it sidesteps author bias entirely.
- Fire tether-vs-vanilla and per-mechanism (A0/A1/A2/A3) on **Sonnet 5** (Opus if
  worthwhile).
- Report which mechanisms move hidden-pass / efficiency — honestly, nulls included.

The question this answers: does the done-gate null hold when the model genuinely
struggles (real hard tasks), or was it an easy-task artifact? And do *any* deterministic
hooks carry weight for frontier models on real work?

## Evidence base

Load-bearing papers (PDFs in `papers/`, gitignored — re-fetch by arXiv id):

- **RLVM** (2607.07405) — deterministic gates lift outcomes only where the model can't
  self-check; the organizing theory for why the done-gate nulls on self-verifiable
  coding tasks.
- **mini-swe-agent** — ~74% SWE-bench-Verified from ~100 lines; minimal scaffolds win.
- **SpecBench (2605.21384) / EvilGenie (2511.21654)** — the reward-hacking regime where
  a hidden-verifier + anti-tamper mechanism *would* matter (tether's guard isn't built
  for it — see FINDINGS).
- **Harness-Bench (2605.27922) / Stop-Comparing (2605.23950)** — the harness moves
  scores more than the model, yet nobody has published a mechanism-level ablation; this
  instrument is that.
