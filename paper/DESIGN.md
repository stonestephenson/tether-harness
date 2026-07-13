# DESIGN — experimental design (Phase 1, v2 after council)

Drafted 2026-07-12 from the reframed contributions ([`RELATED-WORK.md`](RELATED-WORK.md))
and full reads of the four load-bearing papers (`paper/papers/`). **v2 same day:** a
4-lens council review found v1's T-DG trap definition mechanically broken (the
done-gate could never fire on the designed failure path), an admission-rule
contradiction, and two underpowered hypotheses; v1 and the council synthesis are in
git history. Status: **council done — user approval pending (the Phase-1 gate).**
Frozen into PREREGISTRATION.md at Phase 4.

## The claim this design can actually support (claims discipline)

*In Claude Code at a pinned version, on Python tasks constructed by a pre-registered
mechanical protocol so that a targeted failure mode occurs, **deterministic
enforcement of an available verifier beats instruction-only availability** on hidden
verifiers, at bounded cost where the failure mode is absent.* Every arm has the same
repo, the same visible checks, the same `.claude/verify.sh`, and a task prompt that
**explicitly instructs the agent to make `verify.sh` pass** — so the vanilla arm's
failures are non-compliance despite instruction, and the manipulated variable is
enforcement alone. Wild-prevalence claims, other CLIs, and other model families are
explicitly out of scope (the opencode port is the pre-committed extension path).

## Research questions and hypotheses

**Confirmatory (α = .05, exact paired sign-flip permutation test, one-sided):**

- **H1 (done-gate, the headline).** On T-DG tasks, the done-gate arm (A2) beats
  vanilla (A0) on hidden-verifier pass₁. Causal path (explicit): the trap makes the
  *naive* fix break a coupled **visible** test; vanilla's modal trajectory finishes
  visible-red (ships anyway or stops early); the done-gate blocks Stop until
  `verify.sh` is green, forcing the repair. Hidden suite = visible suite **plus a
  disjoint held-out margin** (withheld tests policing overfitting-to-visible).
  Primary endpoint: full hidden pass. Reported alongside, pre-registered: the
  **disjoint-margin pass** (the transfer component) and the **mediator manipulation
  check** — A0's finish-while-visible-red rate. **Falsifier:** if A0's finish-red
  rate < 25% realized, T-DG cannot test H1 and H1 is reported *untestable*, not
  confirmed.

**Secondary (estimation, not hypothesis tests):**

- **S1 (overhead).** On T-N (neutral) tasks: paired Δ success with 90% BCa CI
  against a pre-stated ±10pp reference band, plus token/wall-clock deltas. Reported
  as cost accounting; equivalence is claimed only if the CI sits inside the band
  (council: a formal TOST is mathematically unreachable at this n — pre-registering
  it would be pre-registering a failure).
- **S2 (capability, descriptive).** Haiku A0+A2 on T-DG only: effect-size estimate
  with CI next to Sonnet's. No confirmatory interaction test (council: a
  contrast-of-contrasts at this n has <20% power; Opus block cut).

**Exploratory (labeled as such, no α):** E1 verify-on-edit (A1) on a 4-task T-VoE
block — hazards seeded so consequences surface in hidden *tests*, not a hidden lint
config (council: manufactured-outcome risk). E2 skills layer (A4): **cut from runs**;
ETH's context-file null (2602.11988) is cited instead — one sentence does the work of
120 runs.

## Arms and models

| Arm | Sandbox config | Role |
|---|---|---|
| A0 | vanilla Claude Code | control (instruction without enforcement) |
| A2 | done-gate + its tamper guard only | H1 |
| A3 | full tether hooks | deployed-layer estimate; A3−A2 gap descriptive |
| A1 | verify-on-edit only | E1 exploratory block only |

Models: **Sonnet 5** (confirmatory), **Haiku 4.5** (S2 descriptive block). Exact
dated snapshot ids pinned at pre-registration.

## Task suite and construction protocol

CTXBENCH's five-stage mining pipeline (ETH 2602.11988 §3.2) + scripted trap
injection. **Council yield warning (budgeted for):** CTXBENCH's realized yield was
~2.4% (138 instances / ~5.7k candidate PRs, multi-author team) — task construction,
not runs, is the critical path. Hence: 2 confirmatory classes only, yield checkpoints
with pre-registered descope triggers ("if <10 T-DG candidates survive after 12 repo
environments, descope T-DG to n=8 and grow T-N"), and no scale-to-50 promises.

1. **Mine:** GitHub search — Python, permissive license, working test suite, ≥200
   PRs, one-session scale; prefer post-model-cutoff PRs (contamination); exclude
   anything in the plugin's history.
2. **Filter PRs** mechanically (references issue, touches source, deterministic
   testable behavior); filter prompts published and hash-pinned.
3. **Instantiate:** agent-built env script; keep instances green-on-golden.
4. **Standardize prompts** (CTXBENCH 6-section template; includes the fixed
   "make `bash .claude/verify.sh` pass before finishing" sentence; no solution
   leakage; manually reviewed; pre-registered per task).
5. **Inject (scripted, hash-pinned):**
   - **T-DG (n=12 target):** couple the naive fix to a *visible* neighboring test
     (the trap fires in plain sight); hidden = visible + withheld disjoint margin
     (fail-on-base / pass-on-golden validated).
   - **T-N (n=12 target):** same pipeline, no injection.
   - **T-VoE (n=4, exploratory):** seeded hazards with test-visible consequences.

**Admission (static, scripted — no outcome screening):** Realism, Solvability,
Oracle-checkability, Integrity (hidden margin never in workspace; checkout shipped
**without** `.git`; hidden runner applies the agent diff through a **path allowlist**
and resets `conftest.py`/`pytest.ini`/`setup.cfg`-class files to base — EvilGenie+),
and *Violation-inducing by construction* — injection rules calibrated on **dev tasks
only**; confirmatory tasks are **never executed before Phase 5** (council resolution:
no per-task vanilla screening — instead the **predicted** A0 finish-red rate is
pre-registered and the realized rate is reported, converting a selection bias into a
falsifiable prediction; dud-trap risk is carried openly by the H1 falsifier above).
Population statement: inference is to protocol-mined, admission-passing tasks under
the pinned model/CLI/host, conditional on task class.

**Dev/confirmatory split:** ~6 dev tasks for Phase 2–3 instrument work, pilot, and
injector calibration; confirmatory suite generated by the frozen protocol.

**Contamination probe (pre-registered):** per task × model, attempt golden-patch
reproduction from the issue text alone (no repo); reported as a covariate.

## Metrics and instrumentation

- Primary: hidden pass₁; pass_k reliability curves (RLVM §5.4). Disjoint-margin pass
  and mediator rates as above.
- Cost: tokens defined as **output + non-cache-read input** from the headless result
  JSON (cache reads excluded — council: they dominate and drift); wall-clock. Turns
  reported **descriptive-only** (arm-endogenous: gate blocks create turns).
- **Hook telemetry (Phase-2 deliverable, frozen with the tag):** every hook emits one
  JSONL record per invocation (hook, event, decision, session, ts) to a
  runner-collected path — feeds firing counts and the per-hook **precision audit**
  (true/false blocks vs golden trajectory, RLVM Table 6).
- Per-run artifact bundle harvested before sandbox teardown: session JSONL, hook log,
  agent diff, hidden-verifier output. `bench/RESULTS.md` is the human log; bundles
  are the data store.

## Statistics

- Reps pooled to one value per (task, arm); **exact paired sign-flip permutation**
  for H1 (analytic floor: n=12 ⇒ min two-sided p ≈ 0.0005; ≥10/12 concordant
  needed at α=.05 — stated openly); BCa bootstrap CIs on all effect sizes.
- **Power simulation before the freeze (Phase-2 deliverable):** simulated under
  pilot-informed variance; H1 must clear 80% power at the design MDE or the task-n
  descope triggers fire the other way (grow T-DG at T-N's expense).
- Single confirmatory test ⇒ no multiplicity correction needed; S/E tiers are
  estimation/exploratory by label. Effect sizes reported as risk differences *and*
  log-odds (scale robustness). Variance decomposition reported in Stop-Comparing's
  HV/MV vocabulary.

## Run schedule, drift, and failure disposition (council additions)

- **Schedule:** full (task, arm, rep, model) cell list generated up front;
  seeded-RNG permutation constrained so all arms of a (task, rep, model) tuple run
  **consecutively** (temporally local pairs neutralize serving drift); Haiku block
  interleaved, not trailing.
- **Drift canary:** fixed mini-block (2 dev tasks × A0 × 3 reps) at every week
  boundary; a shift beyond the pre-set bound makes that week a reported stratum.
- **Pinning:** exact CLI version, autoupdate disabled in every sandbox, per-run log
  of `claude --version`, requested + served model id, timestamps, cap-window id.
  Temperature/seed are not controllable in the CLI — reps are the variance
  instrument (stated in the paper).
- **Per-run caps:** hard wall-clock and turn cap (set from pilot; ~30 min / 50
  turns initial); cap-hit ⇒ pass₁ = 0, **included** (a gate arm that loops forever
  is a real cost of the mechanism, not missing data).
- **Failure-disposition table (pre-registered):** quota/cap kill → reschedule same
  cell after reset, never dropped; infra failure before first model turn → rerun
  (max 2) then missing; mid-session API abort → counts as failure (frozen now);
  hidden-verifier infra failure → rerun verifier only. CONSORT-style run-flow
  counts (scheduled/completed/rerun/missing per arm) published in RESULTS.md.

## Run budget (Tier-0, subscription)

| Block | Cells | Runs |
|---|---|---|
| Confirmatory (Sonnet): A0, A2, A3 × 24 tasks (T-DG 12 + T-N 12) × 5 reps | | 360 |
| S2 (Haiku): A0, A2 × 12 T-DG × 5 reps | | 120 |
| E1 (Sonnet): A0, A1 × 4 T-VoE × 5 reps | | 40 |
| Pilot + canaries (dev tasks) | | ~90 |
| **Total** | | **~610** |

Gated arms burn more tokens/time than vanilla (retry loops) — the pilot measures the
multiplier before the schedule is finalized. Pre-registered descope order if caps
bite: drop Haiku block (−120) → drop E1 (−40) → reps 5→4 (−96). Never by results.

## Reproduction

Runner supports API-key auth; a pre-registered **repro-lite subset** (~60 runs) with
an estimated dollar cost is published for third parties. Stated assumption:
subscription and API traffic share a serving stack (unverifiable from outside);
dated-snapshot deprecation risk noted for late reproducers.

## Phase-2 verification list (council's unverified load-bearing claims)

Must be empirically checked in Phase 2 dry-runs/pilot, before the freeze:
1. Headless `claude -p` behavior under a blocking Stop hook (loop? internal turn
   ceiling?) — H1's mechanism and the cap policy depend on it.
2. Subscription auth accepts dated snapshot ids; result JSON reliably reports usage
   breakdown (incl. cache reads), num_turns, served model id.
3. Weekly cap sizes vs measured gated-arm token burn (fits ~610 runs in ~2–3 weeks?).
4. Autoupdate-disable is effective in headless sandboxes.
5. A0's spontaneous verify.sh-run rate on dev tasks (grounds the mediator baseline).
6. Realized mining yield through stage 5 (council estimate: 1–3% of candidate PRs).
