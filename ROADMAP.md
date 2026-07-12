# ROADMAP — the vetted backlog (from the 2026-07 SOTA audit)

**Read this if you're an agent picking up work on tether.** On 2026-07-09 the harness was
audited against 2025–26 research and industry practice (verdict: behaves as designed, and
its shape — thin deterministic verification hooks + judgment skills — is where the field
converged). The audit produced five needle-mover tasks; all five landed on `main` and were
ported to every branch on 2026-07-11 (see **Completed** below — their behavior, evidence,
and contracts are documented in the shipped docs, not here). What remains is below.
Everything else evaluated was **rejected on evidence** (last section — don't re-propose
those without new evidence).

Full citations with local PDFs: [`PAPERS.md`](plugins/tether/references/PAPERS.md)
§"2026 audit additions"; the PDFs/snapshots live in `references/papers/` (gitignored —
re-fetch by arXiv id if missing).

**Before starting any item, confirm with the user that it's in scope for the current
goal.** The list is approved as a backlog; items are green-lit individually.

## Ground rules for implementing agents

- Implement on **`main`** (Claude Code edition) first. Port to `codex` / `opencode` /
  `generic` only after main is verified — each port has its own contract (see the branch
  READMEs and `references/PLATFORM-ASSUMPTIONS.md`'s port-branch tripwires; e.g. Codex
  hooks parse `apply_patch` payloads and block PreCompact via `continue:false` JSON;
  opencode's compacting hook is inject-only).
- Hooks stay **minimal and fail open** — a broken hook must never block an edit, trap the
  agent, or wedge a session. Time-box every subprocess. Never auto-revert user files.
- Every hook change lands with regression coverage (each branch has its own suite;
  `.claude/verify.sh` runs it — the repo's own done-gate on every branch).
- **New hooks/skills carry a burden of proof — and never enter unprompted.** (Reworded
  2026-07-12: the earlier flat "no new skills" was the audit's scoping rule, not a
  research finding.) Minimal-*sufficient* scaffolding is the evidence-backed position
  (mini-swe-agent: ~74% SWE-bench Verified from ~100 lines — heavy scaffolding isn't
  *necessary*; the landscape survey: process-heavy scaffolding without verification
  signal audits badly). A new piece must (a) sit at a high-leverage moment no existing
  piece covers — extend before adding; (b) be the right kind (must-happen → hook,
  judgment → skill); (c) pay for its standing context + maintenance cost; (d) land
  main-first with regression coverage + docs; (e) get the user's explicit green-light.
  Agents propose; they never add scaffolding unprompted. The meta-posture (bottom)
  runs the same test in reverse on the existing pieces.
- The user's live install (`~/.claude`) is **not a test bed**. Verify in-repo with the
  suites and temp dirs. Touching the live install requires their explicit OK.
- When behavior changes, update `HARNESS.md` / `WORKFLOW.md` / the plugin README, and keep
  `PAPERS.md` in sync with any new evidence.
- New items enter this file through the monthly **`sota-radar`** sweep
  (`.claude/skills/sota-radar/SKILL.md` → log in `references/RADAR.md`) and only after the
  user confirms them. Platform-drift facts: `references/PLATFORM-ASSUMPTIONS.md`.

## Status

### Active

| # | Task | Priority | Status |
|---|------|----------|--------|
| 6 | Harness self-benchmark (`bench/`, zero-budget Tier 0) | low | on hold (user, 2026-07-11) |
| 8b | Live verification of the ports (user-run: codex + opencode) | medium | pending — checklists below; both branches pushed 2026-07-11 (ports refreshed 2026-07-12 with #7 + doc-accuracy fixes) |
| 9 | Docs-diet batch (documentation policy + excess-hunting audit + link check) | low | ✅ done on main (2026-07-12) — see §9 below; **ports pending** (handoff skill copies; the verify.sh link check is per-branch maintainer tooling, optional) |
| 8e | Close out #8 | low | ✅ `/handoff` cold audit run + gaps fixed 2026-07-11 (two cold agents; verdicts "Partially" → fixes landed: rustfmt opt-in claim, done-gate wording, tamper limits, WORKFLOW stale paths, dev-loop doc, root CLAUDE.md); remaining: fold in 8b results when they land |

### Completed (2026-07-11, documented in the shipped docs — details in git history)

| # | Task | Landed | Documented in |
|---|------|--------|---------------|
| 1 | Verifier-integrity guard (done-gate anti-tamper) | `8b28028` + all branches | HARNESS.md §4 (Integrity), WORKFLOW.md hook table, branch READMEs |
| 2 | `/harden` corrections→enforcement compiler | `2142040` + all branches | the skill itself, HARNESS.md skills, WORKFLOW.md |
| 3 | PreCompact externalize-guard (opencode/generic: advisory/inject variant) | `9eae004` + all branches | HARNESS.md §4, WORKFLOW.md, WIRING.md (generic), PLATFORM-ASSUMPTIONS |
| 4 | `/ship` cold reviewer | `f1fe1f1` + all branches | the skill itself, HARNESS.md skills |
| 5 | Hygiene (MultiEdit drop, model→budget map, live-install sync) | `79fe261` + all branches | PLATFORM-ASSUMPTIONS facts 7/12 |
| 7 | handoff × catchup — audit the real onboarding path | `c8d8bbe` (main, 2026-07-12) + all branches (2026-07-12: codex `075a8eb`, opencode `9e9f69d`, generic `3517dc9`) | the handoff/catchup skills themselves (coupling notes), HARNESS.md §5; live-tested on main (cold Agent A run — catchup invocable in-subagent, contract + provenance + pointer-graph checks fired); codex/opencode ship a layered invocation (native → read the installed file → verbatim fallback) — live confirmation rides the 8b demos |
| 8a/8c/8d | Ports: codex (`0ff5b54`) · opencode (`0bdc41c`) · generic (`6487d13`) | per branch | branch READMEs (contract deltas), PLATFORM-ASSUMPTIONS port tripwires |

---

## 6. Harness self-benchmark (`bench/`) — reproducible A/B vs vanilla

**Provenance.** Not from the audit five: commissioned by the user 2026-07-09 as the
follow-up to the landscape survey (`references/LANDSCAPE.md`; RADAR entry same date).
**Budget constraint (user-set): no API spend.** Tier 0 below is designed to complete at
zero marginal cost on the user's existing subscription; the paid tiers are optional
extensions and are NOT required to close this item.

**Problem.** tether's design is research-backed but has never been self-measured, and the
only public framework bake-off is anecdote-tier (single-run YouTube video, no published
prompt — LANDSCAPE.md). The meta-posture at the bottom of this file — "periodically
re-test whether each hook/skill still earns its place" — has no instrument. Nobody in the
field publishes a reproducible harness bake-off; shipping one is itself a frontier
position.

**Evidence.** SpecBench (2605.21384) — held-out verifiers the agent never sees are what
make agent evals trustworthy; EvilGenie (2511.21654) — tamper-bait task design;
Terminal-Bench (ICLR 2026) — harness choice moves scores more than model choice (same
model, 5.2-pt spread across harnesses), i.e. this measurement is worth making;
mini-swe-agent — predicts ≈parity on easy tasks (an overhead check, not a win condition).

**Design sketch.**
- New top-level `bench/`: task templates + a runner + `RESULTS.md`. Each task = a
  self-contained temp-repo template with a pre-registered prompt, visible checks, and a
  **hidden verifier** the runner executes only after the session ends — it never enters
  the agent's context (SpecBench pattern; this is what keeps a "showcase" honest).
- Arms = per-arm `CLAUDE_CONFIG_DIR` sandboxes provisioned by the runner. The live
  `~/.claude` is never touched (standing ground rule).
- v1 task set, one per mechanism: **finish-red trap** (done-gate: the obvious fix breaks a
  neighboring test; metric = hidden-suite pass at session end) · **lint-landmine
  refactor** (verify-on-edit: metric = residual F-class lint + fix-loop turns) ·
  **greenfield parity check** (overhead tax: metric = token/time delta vs vanilla;
  expected result ≈parity, and that parity is the point) · **doc-set differential**
  (added 2026-07-12 from the docs discussion: same task on three copies of one repo —
  docs as-shipped / pruned to HARNESS §9's documentation policy / no docs; metric =
  hidden-verifier pass + tokens + turns; directly answers "same quality with less
  context?" — the closest published work, the 2026 AGENTS.md studies, is new and
  workshop-tier, so this is worth measuring ourselves). Deferred: long-horizon context
  task (hard to score cheaply); tamper-bait (#1 landed, so this now measures the guard —
  include the before/after framing when designed).
- Metrics per run: hidden-verifier pass rate, tokens, wall time, turn count. **All runs
  reported** — no cherry-picking. Parity or a loss is the prune signal working, not a
  failed benchmark.
- **Tier 0 (zero marginal cost — the acceptance target):** 2 arms (vanilla, tether) ×
  3 tasks × 3 reps = 18 serial headless runs on the user's subscription, spread over days
  to respect limits. The agent prepares tasks/runner/sandboxes; the user fires the runs
  under their own auth.
- **Tier 1 (optional, small API spend):** framework arms from LANDSCAPE.md — superpowers,
  SuperClaude, BMAD, gstack as installed-config arms; spec-kit scripted or excluded with
  rationale; ruflo included specifically to measure its token overhead. Documented caveat:
  headless runs measure automatic behavior + passive overhead — fair to tether/superpowers
  (auto-trigger), generous to pipeline-driven frameworks.
- **Tier 2 (optional, real spend):** Terminal-Bench 2.1 subset via Harbor's Claude Code
  adapter for external validation. Note TB task repos ship no `.claude/verify.sh`, so the
  done-gate idles — TB answers "never worse?", not "catches what vanilla misses?".

**Acceptance.** `bench/` exists with ≥3 tasks (each: pre-registered prompt + visible
checks + hidden verifier) and a runner that provisions sandboxed arms without touching the
live install; the Tier-0 matrix has been run to completion with every run logged in
`bench/RESULTS.md` (experiment-log format: command, config, model id, metrics); results
summarized in LANDSCAPE.md regardless of direction. Tiers 1–2 explicitly out of scope for
closing the item.

**Files.** `bench/` (new — tasks, runner, RESULTS.md); LANDSCAPE.md results section;
README one-liner. No hook or skill changes.

---
## 7. handoff × catchup — audit the real onboarding path

**✅ Landed on main 2026-07-12** (user-commissioned 2026-07-10; design-reasoning tier —
internal-consistency fix, no paper needed). The full design sketch is in this file's
git history; the behavior now lives in the shipped skills:

- `plugins/tether/skills/handoff/SKILL.md` — Agent A orients by invoking `/catchup`
  for real (contract-with-fallback: missing deliverables → verbatim entry-doc list,
  reported loudly), tags comprehension answers `[docs]` vs `[spelunked]`
  (spelunking-only = doc gap), and checks for docs unreachable from the entry-doc
  pointer graph. Agent B is unchanged — the catchup-free control. Step 6 reports the
  catchup path's health to the user.
- `plugins/tether/skills/catchup/SKILL.md` — coupling note (change-site guard).
- `HARNESS.md` §5 `/handoff` — one line on the coupling.

**Live-tested 2026-07-12** (one cold Agent A run against this repo): `/catchup` was
invocable inside the subagent, delivered the full four-part contract, no fallback
needed; provenance tags and the pointer-graph check both produced real findings.

**Ports: ✅ done 2026-07-12** (codex `075a8eb`, opencode `9e9f69d`, generic
`3517dc9`). Each uses its tool's native cold-spawn mechanism (`codex exec` /
`opencode run` children / tool-neutral wording) and a **layered catchup invocation**
— native skill where available, else *read the installed catchup file and follow it*
(which preserves the anti-drift property: always the current version), else the
verbatim entry-doc fallback, reported loudly. Live confirmation of the codex and
opencode paths rides the 8b demos.

---

## 8. Remaining port work — live verification (8b) + close-out (8e)

Items #1–#5 are ported everywhere (see Completed). What's left is user-run:

- **8b — live verification (user-run): codex + opencode.** Both branches are pushed
  (2026-07-11, user call) — 8b confirms the ported pieces live and updates the
  coverage claims.
  *Codex* (authenticated session): trip verify-on-edit, finish red for the done-gate,
  weaken the verifier for the one-time tamper block, `/compact` on a dirty tree for
  the guard. Optional: run the handoff skill once — confirms a `codex exec` child
  can run/read the catchup skill (#7's layered invocation).
  *opencode* (interactive session): trip verify-on-edit, fail
  `.tether/verify.sh` at idle, weaken the verifier for the one-time tamper report
  (console), and compact with a dirty tree — expect the injected context in the
  summary + the console warning. Optional: run the handoff command once — confirms
  the `opencode run` child reads and follows the installed catchup command (#7).
- **8e — close out.** Docs refreshed and the final `/handoff` cold audit run
  2026-07-11 (with the pre-#7 handoff skill, user call — re-audit if #7 lands and
  materially changes the procedure). Both cold agents verdicted "Partially"; every
  blocking gap they found was fixed same-day (see the 8e status row). Remaining: fold
  the 8b live-verify results into the branch READMEs' coverage claims when they land.

---

## 9. Docs-diet batch — documentation as agent context

**Provenance.** User-commissioned 2026-07-12 from a research discussion on context
management and documentation (evidence: distraction/input-length/knowledge-conflict
literature + the 2026 AGENTS.md studies — PAPERS.md §"Documentation as agent
context"). **✅ Landed on main 2026-07-12:**

- **Documentation policy** — HARNESS.md §9: one home per fact; docs carry only what
  code/git can't; finished work leaves the working set for git history; entry doc =
  map, load-bearing facts early; context files minimal + human-curated; clear
  structured Markdown, no "AI shorthand".
- **Docs-diet gap class** — handoff's Agent A (step 4) and Agent B (step 3) now hunt
  *excess* (drifting duplicates, completed material in active docs, dead pointers),
  and Step 4's fix rules make deletion a fix (user confirms deletions of hand-written
  or unique content). Coverage checklist gains an **Economy** item.
- **Dead-link check** — this repo's `.claude/verify.sh` fails on relative `.md` links
  to missing files (maintainer tooling; test-first verified red→green).
- **Bench doc-set differential** — added to #6's v1 task set (measures "same quality
  with less context?" when #6 runs).

**Live-tested 2026-07-12** (one cold Agent A run with the new prompt): the excess
class fired and caught, among real drift, a header my own policy edit had swallowed —
the mirror-image audit earns its keep. **Known residuals from that run** (accepted,
not hidden): shellcheck's verify-on-edit path has no suite case (docs now say so);
hook behavior is restated across ~4 docs (consistent today — collapse is a candidate
follow-up); HARNESS §12's interview section is author-personal content in user-facing
docs (user's call); the link check validates file targets, not `#section` anchors.

**Ports pending:** the handoff-skill edits to `codex`/`opencode`/`generic` (same
pattern as #7); the link check is optional per-branch. Rejected within this batch:
rewriting docs in compressed "AI-native" style (out of distribution; breaks the human
audit loop), auto-generated doc files (measured harm — ETH study), a standalone
docs-diet skill (rides handoff), and any hook that edits docs automatically.

---

## Rejected on evidence — do not re-propose without new evidence

- **Mutation-testing gate.** Real at org scale (Meta's LLM mutation testing, InfoQ 2026),
  but agent-level evidence says mid-task test machinery doesn't move outcomes
  ("Rethinking the Value of Agent-Generated Tests", arXiv 2602.07900 — test-writing volume
  doesn't correlate with success; prompting for more tests doesn't help), and
  `/test-first`'s "watch it fail first" already delivers the core guarantee.
- **Skill sprawl / process-heavy scaffolding without verification signal.** What the
  evidence rejects is not "new scaffolding" but scaffolding that adds process without
  adding signal: mini-swe-agent (~74% SWE-bench Verified, ~100 lines, swebench.com)
  shows heavy scaffolds aren't *necessary*, and the 2026-07 landscape survey found
  persona/pipeline-heavy frameworks audit badly. Twenty marginal skills mean nothing;
  a piece that passes the ground-rules burden-of-proof test is fine — `/harden` and
  #7 entered exactly that way.
  *Field check 2026-07 (anecdote-tier — single-run YouTuber bake-off, via EveryDev):*
  vanilla Claude Code beat all five big frameworks (20 min/200k tokens vs 60–110+ min);
  directional corroboration only — see `references/LANDSCAPE.md`.
- **Personas / multi-agent implementation.** Base evidence unchanged (Cognition; Zheng
  et al.; Du et al.) — one writer, many readers; structure over persona. *Field check
  2026-07:* BMAD's QA persona observed reporting success without running code, and
  Ruflo's swarm audited as ~97% non-functional (`references/LANDSCAPE.md`).
- **Auto-acting compaction (hook compacts/clears by itself).** 2026 result: model-invoked,
  rubric-guided compaction beats fixed-interval (Self-Compacting Agents, 2606.23525) —
  which is exactly the current gauge(hook) + judgment(skill) split. Lossy steps keep
  human confirmation.
- **SessionStart auto-orientation.** Claude Code injects git status natively; `/catchup`
  covers the rest. Marginal.
- **Repo-map / vector-RAG memory.** Platform LSP + search tools cover localization;
  file-based memory is the adopted industry pattern.
- **Spec-driven formal artifacts (Kiro/Spec-Kit style).** `/plan-change`'s
  independently-checkable steps + `/test-first` already embody testable done-criteria
  (Anthropic's "sprint contracts" are the same idea).
- **LLM-judge gates.** Judges detect reward hacking well *offline* (EvilGenie), but as
  live gates they're nondeterministic; deterministic gates stay primary.
- **Autonomous ralph-style loops.** Conflicts with the human-gated-irreversibility
  invariant; the platform's `/loop` exists when the user wants it.

**Meta-posture** (from Anthropic's harness work): *iteratively prune scaffolding* — as
models improve, periodically re-test whether each hook/skill still earns its place. The
audit that produced this file is the template — its method is codified in the
`sota-radar` skill (`.claude/skills/sota-radar/SKILL.md`), and this file's git history
holds the full audit write-up.
