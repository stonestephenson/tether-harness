# LANDSCAPE — tether vs. the popular harnesses

`RADAR.md` tracks research drift; this file tracks the **competition** — the most-starred
harness/scaffolding frameworks on GitHub: what each is, why it falls short, and where
tether is genuinely better. Two purposes:

1. **Stay at the frontier** — know what the field is doing and adopt what's actually good
   (through the normal ROADMAP gate, never directly).
2. **Don't re-sweep** — a repo graded in a survey below has been read and judged.
   Re-examine it only if it ships a *mechanism-level* change (a new enforcement tier, a
   published evaluation, a real architecture shift). Star growth, README rewrites, and new
   command packs don't count. Frameworks not listed here are fair game.

Maintainer-facing, like everything in repo-root `references/` — this does not ship to
users. Citations are short-form; full entries live in
[`PAPERS.md`](../plugins/tether/references/PAPERS.md).

---

## Survey 2026-07-09 (stars checked that day via the GitHub API)

**Verdict in one line:** the field convergently rediscovered tether's skills layer but
enforces all of it in prose — nobody has a deterministic tier, nobody measures context
occupancy, and nobody cites evidence. The one head-to-head bake-off that exists (EveryDev,
2026) had **vanilla Claude Code beating all five big frameworks** — 20 min / 200k tokens
vs. 60–110+ min — which is the minimal-scaffold result (mini-swe-agent) showing up in the
wild.

### obra/superpowers — 250.7k★ — the serious one
**What:** 14 skills + subagent-driven development: brainstorm → plan → implement with
mandatory TDD, fresh-context subagent per task, two-stage review. Its skill list maps
almost 1:1 onto tether's (writing-plans ≈ `/plan-change`, test-driven-development ≈
`/test-first`, verification-before-completion ≈ the done-gate…).
**Why it falls short:** everything is prose. Its only hook is a session-start *loader*;
"verification-before-completion" is a skill the model may skip — and reviewers observe the
"mandatory" TDD getting ignored under pressure. That's the TRACE result exactly (prose
rules violated ~57% of the time; compiled runtime checks 2–38%), plus Huang et al. (no
reliable self-policing without an external signal). Also heavyweight: 48–60 min builds,
over-engineers simple tasks.
**Why tether is better:** same instincts, one enforcement tier up — the done-gate and
verify-on-edit are hooks the model *cannot* skip, and the skills stay opt-in so simple
tasks pay zero ceremony.

### garrytan/gstack — 120.8k★ — real QA buried under persona theater
**What:** 23 corporate-role skills (CEO, designer, QA lead…) in a fixed sprint pipeline;
underneath, some genuinely external verification — live-Chromium QA and cross-model review.
**Why it falls short:** the role framing adds nothing (Zheng et al. — persona labels don't
improve accuracy); the pipeline runs every task through the whole org chart; enforcement is
prose. Cites Karpathy's rules, no research.
**Why tether is better:** keeps the two ideas that are real — external ground truth
(built-in `/verify` + `/run` drive the actual app) and separated review (ROADMAP #4) —
without the costume or the mandatory pipeline.

### github/spec-kit — 119.1k★ — honest experiment, team-scale problem
**What:** spec-driven development: constitution → specify → plan → tasks → implement, with
persistent spec artifacts. Openly labels itself an unvalidated experiment.
**Why it falls short (for us):** its verification is the LLM auditing its own artifacts —
checklist self-report, the self-certification Huang et al. warns about. The artifacts solve
an org-scale *coordination* problem a single developer doesn't have; already in tether's
rejected list (spec-driven formal artifacts) as redundant with `/plan-change` +
`/test-first`'s checkable steps.
**Why tether is better:** done-criteria live in executable checks, not in documents the
model grades itself on.

### gsd-build/get-shit-done — 64.7k★ — right instinct, dead project
**What:** meta-prompting + per-step subcontexts to fight context rot (sound instinct — same
motive as tether's isolation invariant, per Chroma's context-rot result). Archived 2026-06
after the maintainer vanished; community fork at `open-gsd/gsd-core`.
**Why it falls short:** verification by checklist; assumes linear waterfall; measured
burning ~1.2M tokens per project in the bake-off. And the abandonment is the bus-factor
argument for tether's thin, self-documented scaffold.
**Why tether is better:** context hygiene is *measured* (the gauge hook reads real token
counts) rather than structurally assumed, and the whole harness is small enough to maintain.

### ruvnet/ruflo (ex claude-flow) — 63.7k★ — the cautionary tale
**What:** "hive-mind" swarm orchestration — queens, workers, Byzantine consensus, neural
training, 300+ MCP tools.
**Why it falls short:** an independent audit (roman-rr, 2026) found ~10 of 300+ tools
functional: agent "spawning" that creates map entries and never executes, consensus whose
signature check unconditionally returns true, "neural training" returning hardcoded
predictions — and a measured token *increase* while claiming 30–50% reduction. Even the
honest version of the idea is coupled multi-agent implementation, which Cognition's essay
argues against.
**Why tether is better:** every mechanism in tether is real, regression-tested
(`.claude/verify.sh` runs the suites), and fail-open. Nothing is claimed that isn't tested.

### bmad-code-org/BMAD-METHOD — 50.3k★ — Agile org simulation
**What:** 12+ personas (analyst → PM → architect → SM → dev → QA) running a full Agile
pipeline in prompt-space.
**Why it falls short:** persona theater (Zheng et al.) with the worst observed failure in
the survey: the QA *persona* reporting success without running code — self-certification in
a QA costume (Huang et al.). Reviewers also report context death spirals on long sessions
(Chroma: exactly when quality quietly drops).
**Why tether is better:** verification is a process exit code, not a character; context
pressure is measured and surfaced, not accumulated.

### SuperClaude-Org/SuperClaude_Framework — 23.5k★ — persona configuration pack
**What:** 20 "cognitive personas," 30 commands, 7 behavioral modes; claims "30–50% fewer
tokens, 2–3× faster."
**Why it falls short:** personas again (Zheng et al.), no verification mechanism at all,
and the headline numbers ship with no methodology (the same claim Ruflo made — and where an
auditor checked, consumption went *up*).
**Why tether is better:** no unfalsifiable claims — the evidence table in `HARNESS.md` §10
cites the measurement behind every design choice.

### Noted, not graded (lower stars or different category)
wshobson/agents (37.7k★, persona/subagent marketplace — Zheng critique applies) ·
davila7/claude-code-templates (28.5k★, config CLI, not a methodology) ·
eyaltoledano/claude-task-master (27.8k★, task-management MCP) · automazeio/ccpm (8.3k★,
GitHub-Issues PM) · buildermethods/agent-os (5.0k★, spec standards).

## What they got right (credit where due — and where tether already covers it)

- **Fresh-context subagent dispatch** (superpowers) → tether's isolation invariant /
  Explore usage.
- **Generator–evaluator separation** (superpowers two-stage review; gstack cross-model
  review) → ROADMAP #4, now field-corroborated by the two top frameworks independently.
- **Real-browser QA loop** (gstack `/qa`) — the best single idea in the survey; genuine
  external signal → covered by the built-in `/verify` + `/run`.
- **Artifact-driven state / checkpoint commits** (gstack, GSD) → the externalize-first
  invariant, `/ship` + `/handoff`.

## The structural gap, in one paragraph

Every framework above *asks* the model to follow its methodology; tether *makes the
must-happen parts happen*. That's the whole difference. The field's instincts are fine —
plans, TDD, fresh-context review, external state — but a rule that lives in prose binds
only as well as the model's self-discipline, which is the very thing the research says not
to trust (Huang et al.; TRACE's 57%-violation measurement; EvilGenie catching agents gaming
their own tests). tether's split — deterministic hooks for guarantees, skills for judgment,
evidence for every choice, and a rejected-ideas list to keep it minimal — is what none of
600k+ combined stars of harness code has.

## Sources (2026-07-09)

GitHub API star counts + repo READMEs/trees (the eight graded above) ·
[EveryDev five-framework comparison](https://www.everydev.ai/p/blog-five-claude-code-frameworks-compared-when-to-use-each-when-to-use-none)
(bake-off + per-framework criticisms) ·
[roman-rr Ruflo audit](https://gist.github.com/roman-rr/ed603b676af019b8740423d2bb8e4bf6) ·
papers cited short-form above: TRACE (2606.13174), Zheng et al. 2024, Huang et al. 2023,
Cognition "Don't Build Multi-Agents", Chroma context rot, mini-swe-agent, EvilGenie
(2511.21654) — all in `PAPERS.md`.
