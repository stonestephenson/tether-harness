# RELATED-WORK — Phase 0 novelty audit (2026-07-12)

Verdict per candidate contribution ([`PLAN.md`](PLAN.md) defines C1–C4), from a web
sweep run 2026-07-12 (arXiv + industry sources; abstract-level reads — the four
load-bearing papers below get full reads in Phase 1 before the design freezes).
Harness evidence already cited by the plugin lives in
[`PAPERS.md`](../plugins/tether/references/PAPERS.md) (SpecBench, EvilGenie,
Terminal-Bench, mini-swe-agent) and is not restated here.

| # | Candidate contribution | Verdict | One-line reason |
|---|---|---|---|
| C1 | Mechanism decomposition of verification scaffolding (coding agents) | **OPEN — loudly** | Two 2026 papers name exactly this gap; nearest causal study is in a non-coding domain; window visibly closing |
| C2 | Scaffolding × model capability | **CROWDED** | Cross-model harness variation shown descriptively; inverse-capability gains shown for adjacent mechanisms; keep as secondary hypothesis |
| C3 | Doc-set differential | **TAKEN (as designed)** | A 5+ paper literature now exists, incl. a factorial study and a curation-tuning paper; cut or demote |
| C4 | Pre-registered bake-off methodology + open instrument | **CROWDED as a claim, strong as framing** | Position paper demands it, black-box benchmark exists; we'd be the first to *execute* the causal version |

**Recommended reframe (user gate):** headline = C1; C2 secondary hypothesis inside
C1's design; C3 cut from the paper (optionally an exploratory appendix); C4 becomes
the framing — "the causal instrument the field is asking for" — not a standalone claim.

## C1 — mechanism decomposition: OPEN, and the field says so itself

- **Harness-Bench: Measuring Harness Effects across Models in Realistic Agent
  Workflows** — 2026. arXiv:[2605.27922](https://arxiv.org/abs/2605.27922).
  The nearest neighbor. 106 sandboxed tasks, 5,194 trajectories, 6 harnesses × 8
  models, verifiers hidden from the agent. **Explicitly does not ablate mechanisms**:
  "evaluates complete harness configurations rather than isolating individual
  mechanisms"; results are "not … causal decompositions of individual harness
  mechanisms" — named as a limitation. No formal interaction statistics (descriptive
  variance only). *This is the open door C1 walks through, in the authors' own words.*
- **Stop Comparing LLM Agents Without Disclosing the Harness** — 2026.
  arXiv:[2605.23950](https://arxiv.org/abs/2605.23950). Position paper + variance
  decomposition: harness-induced variance can exceed model-induced variance and
  reverse model rankings; proposes locked-harness and **factorial** protocols and a
  disclosure standard. *Calls for exactly the study we'd run; we execute their
  protocol rather than invent one.*
- **Reason Less, Verify More: Deterministic Gates Recover a Silent Policy-Violation
  Failure Mode in Tool-Using LLM Agents** — Reddy, Challaram & Basu, 2026.
  arXiv:[2607.07405](https://arxiv.org/abs/2607.07405). The nearest *causal* study —
  published July 2026. Deterministic read-only pre-execution gates on **τ²-bench
  airline** (customer-service tool use, not coding): +12.4pp success on gpt-4o-mini
  (P=0.0012, replicated +12.3pp on a disjoint seed set), +10.4pp on gpt-5.2;
  **+19.2pp on tasks where gates fire, no significant movement on non-firing tasks**.
  *Does not touch coding agents, lint/test/done gates, or hidden-verifier outcomes —
  but it validates the thesis shape in a neighboring domain, supplies a directly
  reusable analysis pattern (paired task-level bootstrap; firing/non-firing split =
  our trap/neutral design), and signals the window is closing: the coding-agent
  version is the obvious next paper for someone.*
- **More Is Not Always Better: Cross-Component Interference in LLM Agent
  Scaffolding** — 2026. arXiv:[2605.05716](https://arxiv.org/abs/2605.05716). Full
  2⁵ ablation, but of *prompt-level* components (planning, tools, memory, reflection,
  retrieval — no deterministic verification), on general tasks (HotpotQA/GSM8K) with
  small open models. Adding everything underperforms optimized subsets; 56% of
  configurations violate submodularity. *Motivates per-mechanism arms (interactions
  are real) and leaves the verification-mechanism column untouched.*
- **Inside the Scaffold: A Source-Code Taxonomy of Coding Agent Architectures** —
  2026. arXiv:[2604.03515](https://arxiv.org/abs/2604.03515). Taxonomy of 13
  open-source coding agents; descriptive, no outcome measurement. Useful vocabulary
  for naming the mechanisms we ablate. Similarly descriptive:
  [Dive-into-Claude-Code](https://github.com/VILA-Lab/Dive-into-Claude-Code)
  (VILA-Lab) analyzes Claude Code's design without measuring it, and practitioner
  posts on Claude Code hook gates are observational only — no formal study.

**What remains unclaimed:** causal, per-mechanism ablation of *deterministic
verification* scaffolding (verify-on-edit, done-gate, tamper guard) in a real coding
CLI, on coding tasks, with hidden verifiers and pre-registration. That is C1.

## C2 — × capability: CROWDED; demote to secondary hypothesis

- Harness-Bench (above) spans 8 models and reports "substantial variation across
  model–harness pairings" — but descriptively, no significance tests. "Report at the
  model-harness configuration level" is their takeaway; the *interaction* is unmodeled.
- **One Interaction Is Worth a Thousand Guesses** — 2026.
  arXiv:[2601.06676](https://arxiv.org/abs/2601.06676). For interactive
  clarification (a different mechanism), gains are inverse to model capability. The
  "weaker models benefit more from support" prior exists in adjacent settings.
- Reason-Less-Verify-More (above) is mild *counter*-evidence in its domain: gates
  helped the weak and frontier model comparably (+12.4 vs +10.4pp).
- Industry practice measures across models on one harness ([GitHub Copilot harness
  evaluation](https://github.blog/ai-and-ml/github-copilot/evaluating-performance-and-efficiency-of-the-github-copilot-agentic-harness-across-models-and-tasks/)).

*A powered within-family interaction test for verification gates specifically is
still unclaimed but can't headline — run it as a pre-registered secondary hypothesis
inside C1's matrix (Haiku/Sonnet/Opus).*

## C3 — doc-set differential: TAKEN as designed; cut or demote

The ROADMAP's premise ("closest work is new and workshop-tier") is stale — there is
now a literature:

- **Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding
  Agents?** — Gloaguen et al. (ETH Zürich), 2026.
  arXiv:[2602.11988](https://arxiv.org/abs/2602.11988). SWE-bench tasks; no-file vs
  LLM-generated vs developer-committed context files; **no general improvement in
  success, >20% average cost increase**, across models and agents; agents *do* follow
  the files — following just doesn't help; repo overviews specifically unhelpful.
  (Already cited in PAPERS.md §Documentation as the "measured harm" result.)
- **Instruction Adherence in Coding Agent Configuration Files: A Factorial Study of
  Four File-Structure Variables** — 2026.
  arXiv:[2605.10039](https://arxiv.org/abs/2605.10039). Factorial design over file
  structure — the methodology slot our three-arm doc differential would have filled.
- **On the Impact of AGENTS.md Files on the Efficiency of AI Coding Agents** — 2026.
  arXiv:[2601.20404](https://arxiv.org/abs/2601.20404); **Probe-and-Refine Tuning of
  Repository Guidance for Coding Agents** — 2026.
  arXiv:[2606.20512](https://arxiv.org/abs/2606.20512) (automated curation tuning —
  occupies the "does principled curation help" niche our pruned arm targeted); plus
  an exploratory config study (arXiv:[2602.14690](https://arxiv.org/abs/2602.14690))
  and ZORO (arXiv:[2604.15625](https://arxiv.org/abs/2604.15625)).

*Residual value: ETH's null makes "hooks-only vs full tether" inside C1 more
interesting — the skills layer is prose context, and the literature now predicts it
adds little on short tasks. That's a C1 arm, not a standalone contribution.*

## C4 — methodology: CROWDED as a claim, adopt as framing

- Stop-Comparing (above) supplies the protocol demand and disclosure standard;
  Harness-Bench supplies the configuration-level foundation and hidden-verifier
  practice; **Beyond Static Leaderboards** — 2026.
  arXiv:[2606.19704](https://arxiv.org/abs/2606.19704) — brings pre-registration
  into agent evaluation (predictive-validity framing). DeepSWE
  (arXiv:[2607.07946](https://arxiv.org/html/2607.07946)) holds out its LLM-judge
  prompt — held-out components are becoming standard.

*Nobody has executed a pre-registered, causal, per-mechanism harness study — being
the first execution of the called-for protocol is the paper's framing and its
instrument release is the artifact, but the methodology itself is no longer claimable
as novel.*

## Consequences for Phase 1 (carried into DESIGN.md)

- Adopt 2607.07405's analysis pattern: paired task-level bootstrap; pre-registered
  firing/non-firing (trap/neutral) task split; report per-mechanism effects only
  where the mechanism can fire.
- Adopt 2605.23950's factorial/variance-decomposition language and disclosure
  checklist; position vs 2605.27922 using its own "not causal decompositions"
  limitation as motivation.
- Speed matters: 2607.07405 (July 2026) shows this exact question being answered in
  neighboring domains now. Favor the fast arXiv + workshop path (scope-upgrade
  criterion (a) is only *half* met: loudly open, but not contradictorily answered —
  and the closing window argues against slow venues anyway).
- Phase 1 full-reads before freeze: 2605.27922, 2605.23950, 2607.07405, 2602.11988.
