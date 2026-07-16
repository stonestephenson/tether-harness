# paper/ — the harness bake-off study (plan to publication)

**What this is.** A pre-registered, reproducible study of what verification scaffolding
actually does to coding-agent outcomes, built on the `bench/` instrument (ROADMAP #6,
reframed 2026-07-12 from a zero-budget self-check to a paper-grade study — "Option B").
Target: arXiv preprint + an agents/evaluation workshop; a main-conference submission
upgrades in only via the pre-committed scope-upgrade criteria at the Phase-1 gate.

**Thesis.** Deterministic verification scaffolding — hooks carrying a real, external
verification signal — causally improves coding-agent outcomes on tasks where its
target failure mode occurs, costs ≈nothing where it doesn't, and the effect varies by
mechanism and by model capability. tether is the *instantiation under test*, not the
thesis: the ablation arms isolate mechanisms, not the brand, and the harness version
is a documented parameter (treatment versioning, under Conventions).

**Status: Phase 2 (instrument build), in progress.** Phase 1 gate passed —
[`DESIGN.md`](DESIGN.md) v2 **approved by the user 2026-07-15**. Phase 2 opened by
de-risking the six-item verification list first: the `stop_hook` probe is built and
self-tested (model-free), awaiting the user's authenticated fire; results log in
[`../bench/FINDINGS.md`](../bench/FINDINGS.md). Each phase below ends at a gate;
nothing advances past a gate without the user.

## Why paper-grade (decision record, 2026-07-12)

- The user already has personal verification from daily use; the marginal value of the
  bench is **rigorous public evidence**, so the study is designed for publication from
  day one rather than retrofitted.
- Nobody publishes a reproducible harness bake-off (the only public comparison is
  anecdote-tier — [`LANDSCAPE.md`](../references/LANDSCAPE.md)). Terminal-Bench (ICLR
  2026) showed harness choice moves scores more than model choice but treated each
  harness as a black box — the *mechanism-level* decomposition is open (to be confirmed
  in Phase 0).
- Compute: the user's Max ($100) subscription makes reps, ablation arms, and
  competitor-framework arms **zero marginal cost** (headless runs in sandboxed
  `CLAUDE_CONFIG_DIR` arms; calendar-limited by weekly caps). This supersedes the old
  ROADMAP tier structure that treated framework arms as API spend. API-key auth is
  supported in the runner **only** so third parties can reproduce.

## Candidate contributions (verdicts: [`RELATED-WORK.md`](RELATED-WORK.md))

- **C1 — mechanism decomposition.** Ablation arms (vanilla / single-hook / full harness)
  with held-out verifiers: *which* scaffolding components move outcomes, and when.
- **C2 — scaffolding × model capability.** Does deterministic verification matter more
  for weaker models? (Within Claude family: Haiku / Sonnet / Opus.)
- **C3 — doc-set differential.** Same task, three doc conditions (as-shipped / pruned to
  the documentation policy / none). Nearest published work: the 2026 AGENTS.md studies
  (workshop-tier).
- **C4 — the methodology + open instrument.** Pre-registration, hidden verifiers the
  agent never sees (SpecBench pattern), all-runs-reported, reproducible runner.

## Threats to validity (each demands a design answer before any run)

- **Author-constructed tasks favor the harness** → Phase 1's mechanical
  task-construction protocol: trap and neutral tasks seeded from real repos by a
  documented procedure (target 15–30 tasks), not hand-authored showcases. This is the
  paper's credibility centerpiece.
- **Single model family** → within-family capability sweep, framed honestly; runner
  reproducible by others on any auth.
- **Small-n binary outcomes** → power analysis up front; exact tests
  (Fisher/bootstrap), CIs on everything.
- **Experimenter degrees of freedom** → pre-registration frozen at a tagged commit
  before main runs; later changes are documented deviations.
- **Run-budget explosion** — a full crossing (4 arms × 3 models × ~20 tasks × 5 reps
  ≈ 1,200 runs) exceeds even Max caps; Phase 1 must prioritize (e.g. primary contrast
  on the full suite, ablations on the trap subset, capability sweep on a subset).

## Phases and gates

0. **Scaffold + novelty audit.** ✅ 2026-07-12 — verdicts in
   [`RELATED-WORK.md`](RELATED-WORK.md); gate passed: **reframe approved by user**
   (headline C1, C2 secondary, C3 cut, C4 framing).
1. **Experimental design** → [`DESIGN.md`](DESIGN.md): ✅ drafted + council-reviewed
   2026-07-12 (v2 fixes the trap-class causal path, drops per-task outcome
   screening, restructures H-family to one confirmatory test). **Gate: user
   approval — open.** The gate also fixes
   scope. Default = arXiv + workshop; upgrade toward a main-conference /
   datasets-and-benchmarks target only if the pre-committed criteria hold:
   (a) Phase 0 found the question loudly open or contradictorily answered;
   (b) the task protocol scales to 50+ tasks at acceptable AI-labor cost;
   (c) a second model family is feasible at ~zero marginal cost (the opencode
   port + local models — qwen3-coder already verified end-to-end); (d) the power
   analysis makes the C2 interaction detectable at feasible n. Either way the
   workshop → main-conf extension path stays open (workshops are non-archival;
   the frozen instrument re-runs later with more arms/tasks).
2. **Instrument build** → `bench/`: **in progress.** Opens with the verification-list
   probes (`bench/probes/`) since a surprising answer reshapes the design; then the
   runner + per-arm `CLAUDE_CONFIG_DIR` sandboxes (live `~/.claude` never touched),
   hidden-verifier harness, hook telemetry, and the task-mining pipeline + dev tasks.
   Dry-run self-tests with no model calls; test-first where checkable.
3. **Pilot** (user-fired, small matrix): validates the *instrument* — hidden-verifier
   reliability, task discrimination, cap/timing calibration, log completeness →
   FINDINGS.md. Fixes touch the instrument, never the hypotheses. **Gate:
   instrument checklist green.**
4. **Pre-registration freeze** → PREREGISTRATION.md (hypotheses, matrix, analysis
   plan, exclusion rules) at a tagged commit; OSF registration decided here.
   **Gate: user.**
5. **Main data collection** (user-fired, ~2–4 weeks under weekly caps): every run
   logged in `bench/RESULTS.md` in `/experiment-log` format; no peeking-and-tuning —
   interim looks only as pre-registered.
6. **Analysis + manuscript**: pre-registered analysis only; figures; draft under
   `paper/`; red-team via a cold review pass + council; reproducibility package.
7. **Publish**: arXiv + workshop picked by deadline; results summarized in
   [`LANDSCAPE.md`](../references/LANDSCAPE.md) **regardless of direction** (parity or
   a loss is the prune signal working); RADAR entry; README one-liner.

## Instrument concepts carried forward (from the original #6 sketch, superseded here)

The pre-Option-B design sketch (ROADMAP git history, commit `fd61a71` and earlier)
contributed four task archetypes that seed Phase 1's protocol — **finish-red trap**
(done-gate), **lint-landmine refactor** (verify-on-edit), **greenfield parity check**
(overhead; ≈parity *is* the win condition — mini-swe-agent predicts it), **doc-set
differential** (C3) — plus two deferrals that still stand: long-horizon context tasks
(hard to score cheaply) and tamper-bait (now measures the landed anti-tamper guard;
needs before/after framing). Evidence for the design choices: SpecBench, EvilGenie,
Terminal-Bench, mini-swe-agent — full citations in
[`PAPERS.md`](../plugins/tether/references/PAPERS.md).

## Conventions

- **Treatment versioning (decided 2026-07-12).** The harness evolves normally (the
  ROADMAP process) until the Phase-4 freeze; pre-freeze changes must be justified on
  their own evidence — never by task-suite performance (tuning the treatment to the
  instrument is overfitting, not improvement). Harness *bug* fixes surfaced by the
  pilot are allowed pre-freeze, documented. The Phase-4 tag pins design **and**
  treatment in one commit (plugin, tasks, and prereg share this repo); arms install
  tether at that tag and the paper cites it. During Phases 5–6 the harness does not
  change — new evidence queues via RADAR/ROADMAP and waits. Post-study, the bench
  becomes the harness's regression benchmark: improvements are *measured* against the
  published baseline on the same frozen task suite (the meta-posture's instrument).
- **One home per fact** (documentation policy, HARNESS §9): this file owns the study
  plan and its rationale; RELATED-WORK.md will own study citations (PAPERS.md-style
  format) — only evidence that changes *harness* design flows back to PAPERS.md;
  `bench/` will own instrument docs; run data lives in `bench/RESULTS.md` only.
- Files here appear when their phase produces content — no empty scaffolding. Link
  them from this file as they land (the repo's dead-link gate enforces validity).
- Nothing in `paper/` or `bench/` ships to plugin users (installs ship
  `plugins/tether/` only).
