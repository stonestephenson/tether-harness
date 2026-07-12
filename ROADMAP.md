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
- **No new skills beyond what's listed here.** Minimal scaffolds are the evidence-backed
  position (mini-swe-agent: ~74% SWE-bench Verified from a ~100-line harness).
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
| 7 | handoff × catchup — audit the real onboarding path | low | on hold (user, 2026-07-11) |
| 8b | Live verification of the ports (user-run: codex + opencode) | medium | pending — checklists below; codex branch stays local until it passes |
| 8e | Close out #8 | low | docs refreshed 2026-07-11; `/handoff` audit next; remaining: fold in 8b results when they land |

### Completed (2026-07-11, documented in the shipped docs — details in git history)

| # | Task | Landed | Documented in |
|---|------|--------|---------------|
| 1 | Verifier-integrity guard (done-gate anti-tamper) | `8b28028` + all branches | HARNESS.md §4 (Integrity), WORKFLOW.md hook table, branch READMEs |
| 2 | `/harden` corrections→enforcement compiler | `2142040` + all branches | the skill itself, HARNESS.md skills, WORKFLOW.md |
| 3 | PreCompact externalize-guard (opencode/generic: advisory/inject variant) | `9eae004` + all branches | HARNESS.md §4, WORKFLOW.md, WIRING.md (generic), PLATFORM-ASSUMPTIONS |
| 4 | `/ship` cold reviewer | `f1fe1f1` + all branches | the skill itself, HARNESS.md skills |
| 5 | Hygiene (MultiEdit drop, model→budget map, live-install sync) | `79fe261` + all branches | PLATFORM-ASSUMPTIONS facts 7/12 |
| 8a/8c/8d | Ports: codex (`0ff5b54`, local until 8b) · opencode (`0bdc41c`) · generic (`6487d13`) | per branch | branch READMEs (contract deltas), PLATFORM-ASSUMPTIONS port tripwires |

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
  expected result ≈parity, and that parity is the point). Deferred: long-horizon context
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

**Provenance.** User-commissioned 2026-07-10 from a design review of the handoff/catchup
mirror pair. No radar sweep behind it and no paper needed — this is an
internal-consistency fix (design-reasoning tier), not an evidence-tier claim.

**Problem.** handoff's cold Agent A audits a path no real agent takes. Its prompt names
the doc set ("Read the entry docs (README, CLAUDE.md/AGENTS.md, ROADMAP/CHANGELOG,
docs/)"), so it finds e.g. an unlinked ROADMAP by listing files. But every future cold
agent in this ecosystem starts with `/catchup`, which reads the entry doc and follows
only **its pointers** — catchup itself flags an unmapped entry doc as a handoff smell.
So a failure class the audit structurally cannot catch today: **docs that exist but are
unreachable from the entry doc's pointer graph**, and catchup orientations that come out
wrong (wrong test command, missed backlog). The audit should test the composed system
(docs × catchup), because that's what cold agents actually experience.

**Design sketch.**
- **Agent A's first act = literally run `/catchup`** (Skill invocation, not an inlined
  paraphrase — a copy would drift from the real catchup and defeat the realism purpose;
  when catchup evolves, the audit should test the evolved version). Agent A's existing
  build/run/test probing (its steps 2–4) stays unchanged: catchup is orientation, not
  audit — it never tries every documented run mode, probes extension questions, or hunts
  stale claims.
- **New gap class in A's step 4:** docs unreachable from the entry-doc pointer graph;
  anything wrong or missing in the catchup orientation (commands, backlog, conventions).
- **Provenance rule (anti-masking):** when A answers the comprehension questions, it
  notes whether each answer came from the docs or from git/code spelunking;
  spelunking-only answers count as doc gaps. This guard is catchup-version-independent —
  catchup getting "better" at git archaeology can't silently mask doc gaps.
- **Contract-with-fallback (anti-quiet-regression):** handoff's prompt states what the
  catchup orientation must deliver — build/run/test commands, the backlog, the
  conventions. If any are missing, A falls back to the current verbatim step 1 **and
  reports the fallback in its findings** — a catchup regression becomes a loud line in
  the audit report instead of a silent weakening.
- **Agent B unchanged** — it is READ-ONLY (catchup runs checks; would collide with A) and
  stays the catchup-free control in every run, so the verdict never rests solely on the
  catchup path.
- **Coupling note in catchup's SKILL.md** (change-site guard): handoff's cold audit
  invokes this skill; if you change Step 1's pointer-following or the orientation report
  shape, re-check handoff Step 2.
- The existing "harness can't spawn subagents" fallback gains a sibling: `/catchup` not
  invocable inside the subagent → use the verbatim step 1.

**Rejected during design — standing third agent** (a copy of A without catchup) as a
catchup-regression detector: permanent per-run cost to detect a rare event with a noisy
instrument (two stochastic cold agents differ run-to-run anyway, so attribution needs
repetition), and it mixes auditing-this-repo with regression-testing-catchup. Catchup
breakage is already the loudest failure in the workflow (it runs at every session start),
and the masking direction is covered by the provenance rule + Agent B. If "does
catchup-first change audit quality?" ever needs a measured answer, run it once as a
`bench/` (#6) differential experiment when catchup materially changes — not as a fixture.

**Acceptance.** `plugins/tether/skills/handoff/SKILL.md`: Agent A's prompt opens with the
`/catchup` invocation + contract-with-fallback + provenance rule + the new gap class;
Agent B and the fix/re-verify steps untouched. `plugins/tether/skills/catchup/SKILL.md`:
coupling note added. `HARNESS.md` skills section: one line on the handoff↔catchup
coupling. No hook changes; regression suites unaffected.

**Port notes.** Apply to the `codex` / `opencode` skill copies only after main is
verified; confirm each tool's skill-invocation mechanism supports a subagent calling
catchup, else ship the verbatim-step-1 form there.

---

## 8. Remaining port work — live verification (8b) + close-out (8e)

Items #1–#5 are ported everywhere (see Completed). What's left is user-run:

- **8b — live verification (user-run): codex + opencode.**
  *Codex* (authenticated session): trip verify-on-edit, finish red for the done-gate,
  weaken the verifier for the one-time tamper block, `/compact` on a dirty tree for
  the guard. Then push the branch (`0ff5b54` stays local until this passes).
  *opencode* (interactive session; branch already pushed): trip verify-on-edit, fail
  `.tether/verify.sh` at idle, weaken the verifier for the one-time tamper report
  (console), and compact with a dirty tree — expect the injected context in the
  summary + the console warning.
- **8e — close out.** Docs refreshed 2026-07-11. The final `/handoff` audit runs with
  the pre-#7 handoff skill (user call, 2026-07-11) — re-audit if #7 lands and
  materially changes the procedure. Remaining: fold the 8b live-verify results into
  the branch READMEs' coverage claims when they land.

---

## Rejected on evidence — do not re-propose without new evidence

- **Mutation-testing gate.** Real at org scale (Meta's LLM mutation testing, InfoQ 2026),
  but agent-level evidence says mid-task test machinery doesn't move outcomes
  ("Rethinking the Value of Agent-Generated Tests", arXiv 2602.07900 — test-writing volume
  doesn't correlate with success; prompting for more tests doesn't help), and
  `/test-first`'s "watch it fail first" already delivers the core guarantee.
- **More skills / skill sprawl.** Minimal scaffolds are SOTA (mini-swe-agent ~74%
  SWE-bench Verified, ~100 lines, swebench.com). Twenty marginal skills mean nothing.
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
audit that produced this file is the template (memory note: `sota-audit-2026-07`).
