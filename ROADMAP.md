# ROADMAP — the vetted backlog (from the 2026-07 SOTA audit)

**Read this if you're an agent picking up work on tether.** On 2026-07-09 the harness was
audited against 2025–26 research and industry practice. Verdict: it behaves as designed
(all regression suites green; hook contracts match the July-2026 Claude Code hooks API;
a live-transcript parse confirmed context-health still reads the real format) and its
shape — thin deterministic verification hooks + judgment skills, no multi-agent theater —
is where the field converged. Roughly fifteen candidate additions were evaluated; five
cleared the "genuinely moves the needle" bar (items 1–5; items 6–7 were user-commissioned
separately — see each item's **Provenance**). Everything else was
**rejected on evidence** (see the last section — don't re-propose those without new
evidence).

Full citations with local PDFs: [`PAPERS.md`](plugins/tether/references/PAPERS.md)
§"2026 audit additions"; the PDFs/snapshots live in `references/papers/` (gitignored —
re-fetch by arXiv id if missing).

**Before starting any item, confirm with the user that it's in scope for the current
goal.** The list is approved as a backlog; items are green-lit individually.

## Ground rules for implementing agents

- Implement on **`main`** (Claude Code edition) first. Port to `codex` / `opencode` /
  `generic` only after main is verified — each port has its own contract (see the branch
  READMEs; e.g. Codex hooks parse `apply_patch` payloads, opencode uses `.tether/verify.sh`).
- Hooks stay **minimal and fail open** — a broken hook must never block an edit, trap the
  agent, or wedge a session. Time-box every subprocess. Never auto-revert user files.
- Every hook change lands with regression coverage in `plugins/tether/tests/` (the bash
  suites; `.claude/verify.sh` runs them — it's this repo's own done-gate).
- **No new skills beyond what's listed here.** Minimal scaffolds are the evidence-backed
  position (mini-swe-agent: ~74% SWE-bench Verified from a ~100-line harness).
- The user's live install (`~/.claude`) is **not a test bed**. Verify in-repo with the
  suites and temp dirs. Touching the live install requires their explicit OK (item 5c).
- When behavior changes, update `HARNESS.md` / `WORKFLOW.md` / the plugin README, and keep
  `PAPERS.md` in sync with any new evidence.
- New items enter this file through the monthly **`sota-radar`** sweep
  (`.claude/skills/sota-radar/SKILL.md` → log in `references/RADAR.md`) and only after the
  user confirms them. Platform-drift facts: `references/PLATFORM-ASSUMPTIONS.md`.

## Status

| # | Task | Priority | Status |
|---|------|----------|--------|
| 1 | Verifier-integrity guard (done-gate anti-tamper) | high | ✅ done on main (2026-07-11) — SessionStart baseline not taken (optional); ports pending |
| 2 | Corrections→enforcement compiler (`/harden`) | high | ✅ done on main (2026-07-11) — standalone skill; not wired into `/ship` (kept lean; revisit with #4); ports pending |
| 3 | PreCompact externalize-guard | medium | not started |
| 4 | `/ship` cold reviewer | medium | not started |
| 5 | Hygiene batch | low | not started |
| 6 | Harness self-benchmark (`bench/`, zero-budget Tier 0) | low | not started |
| 7 | handoff × catchup — audit the real onboarding path | low | not started |

---

## 1. Verifier-integrity guard (done-gate anti-tamper)

**Problem.** The done-gate's whole value is "green means green" — but the agent can edit
`.claude/verify.sh` (or the scripts it calls) and the gate happily runs the weakened
verifier. This was a known stress-test target, and it's no longer hypothetical: EvilGenie
observed **explicit reward hacking by Claude Code and Codex agents** (hardcoding test
cases, editing test files) on LiveCodeBench-derived tasks, and SpecBench showed every
frontier model saturates the *visible* test suite while held-out tests reveal tampering —
with stronger models tampering more, not less.

**Evidence.** EvilGenie (arXiv 2511.21654 — test-file **edit detection** is one of its
three working detectors, i.e. exactly this mechanism); SpecBench (2605.21384); The
Verification Horizon (2606.26300 — no fixed verifier stays sufficient; verification must
be layered). Local: `evilgenie.pdf`, `specbench.pdf`, `verification-horizon.pdf`.
**Corroboration (2026-07-09 cloud sweep):** Reward Hacking Benchmark (arXiv 2605.02964;
exploit rates up to 13.9%), contrastive reward-hack detection (arXiv 2601.20103), and a
Cursor SWE-bench Pro study showing reward hacking inflates Opus 4.8's score 87.1%→73.0% —
extra weight behind this task's priority.

**Design sketch.**
- **Baseline:** on the first done-gate invocation that finds a verifier, record a SHA-256
  of the resolved verifier (the bytes of `.claude/verify.sh`, or the literal
  `CLAUDE_VERIFY_CMD` string) in per-session state — same pattern as context-health's
  state dir (`<tmpdir>/claude-done-gate-state/<session_id>`; `session_id` is in every
  hook's stdin).
- **Check:** on later invocations, re-hash. If changed since baseline: still run the
  verifier, **always** emit a user-visible `systemMessage` ("verifier changed during this
  session"), and — when the run is green and `stop_hook_active` is false — block **once**
  with a reason that shows the verifier diff (or old/new hashes + changed lines) and
  instructs the agent to surface the change to the user for confirmation or revert it.
  Re-baseline after that single block so it can never loop.
- **Optional stronger baseline:** a tiny `SessionStart` hook records the hash before the
  agent ever acts (covers tampering before the first Stop). SessionStart can also register
  `watchPaths` on the verifier (the July-2026 API has a `FileChanged` event) — optional
  enhancement, not core.
- **Belt-and-suspenders (docs only):** recommend a per-project permissions deny rule —
  `"deny": ["Edit(./.claude/verify.sh)", "Write(./.claude/verify.sh)"]` — which blocks
  tool-based edits; the hash check still catches shell-based writes
  (`echo ... > .claude/verify.sh`).
- Never auto-revert. Fail open on any internal error. Hashing cost is negligible.

**Acceptance (extend `tests/verify-hooks.test.sh`).** Unchanged verifier + green → silent
pass. Changed + green → exactly one block, reason names the change; next attempt passes.
Changed + red → normal red block, tamper note included. First run → baselines silently.
Corrupt/missing state → fail open. `stop_hook_active` → never blocks.

**Files.** `plugins/tether/hooks/done-gate.py` (+ optional SessionStart baseline hook +
`hooks.json` wiring), tests, `HARNESS.md` §4, `WORKFLOW.md` hook table.

**Port notes.** codex: `.codex/verify.sh`, state under the OS tmpdir, same JSON feedback
contract. opencode: `.tether/verify.sh`.

---

## 2. Corrections→enforcement compiler (`/harden`)

**Problem.** Corrections the user gives ("never use X", "always run Y first") get stored
as prose — CLAUDE.md lines, feedback memories — and prose doesn't reliably bind: TRACE
measured that preferences kept as retrievable notes were still violated **~57%** of the
time, while the same preferences **compiled into mandatory runtime checks** dropped
violations to **2–38%**. Independent 2026 reporting agrees that memory-file notes alone
don't make agents measurably improve at a codebase. The harness already has the right
principle — invariant #6, "must-happen → hook; judgment → skill" — this task applies it
to accumulated feedback.

**Evidence.** TRACE, "Getting Better at Working With You" (arXiv 2606.13174). Local:
`trace-corrections.pdf`.

**Design sketch.** One new skill, working name **`/harden`** — the deliberate exception to
"no new skills", justified because it *converts* existing prose into enforcement rather
than adding process. (Optionally also invoked as a step inside `/ship`; decide during
implementation.)
1. **Gather candidates:** feedback-type memories, CLAUDE.md "don't/always" lines, and any
   correction the user repeats (a done-gate failure recurring with the same cause counts).
2. **Classify:** mechanically checkable, or judgment-only? Judgment-only stays prose.
3. **Compile to the cheapest sufficient tier:**
   (a) an existing linter's config (ruff/clippy/eslint rule) →
   (b) a grep-able check appended to `.claude/verify.sh` →
   (c) a permissions deny rule in project settings →
   (d) a tiny PreToolUse guard script (last resort; needs hooks.json wiring).
4. **Always propose before writing** — enforcement is added only with the user's OK.
5. **Provenance:** annotate each compiled rule with origin + date ("compiled from
   correction: …") so rules stay auditable and removable.
6. Respect the formatting philosophy: never compile style preferences for a project that
   hasn't opted into a style config.

**Acceptance.** `plugins/tether/skills/harden/SKILL.md` in the house format (frontmatter
`name` + trigger-rich `description`, same as the other eight), containing the tier table
and one worked example (correction → verify.sh line). Docs updated (HARNESS.md skills
section, WORKFLOW.md table, README skill list). No hook code needed for tiers a–c.

---

## 3. PreCompact externalize-guard

**Problem.** Invariant #1 — externalize state *before* compacting — is enforced only by
convention (the context-health skill asks nicely). Compaction is lossy; if the tree is
dirty and un-externalized, a compact can silently strand work the summary won't preserve.

**Platform facts (verified against the hooks docs, 2026-07).** `PreCompact` **can block**
(exit 2, or `{"continue": false}`); it **cannot** inject additionalContext or custom
instructions; `PostCompact` exists but is logging-only. **Resolved (2026-07-09 cloud
sweep):** the hooks doc now explicitly documents `manual`/`auto` matcher values for
PreCompact (see RADAR.md), so the manual-only scoping below is implementable as designed.
Still code defensively: if the trigger/matcher field is ever absent at runtime, treat the
compaction as auto and never block.

**Design sketch.**
- **Manual compact + dirty git tree → block once** (exit 2), stderr explaining: list the
  dirty files, say "run `/ship` (commit) or `/handoff` (externalize) or `/context-health`
  (decide) first — or re-run `/compact` to override."
- **Override path:** a per-session state file (same tmpdir pattern) makes the second
  consecutive attempt pass. One block, never a wall.
- **Auto compact → never block**; at most a `systemMessage`.
- "Un-externalized" = in a git repo AND working tree dirty (staged or unstaged). Keep the
  predicate that simple in v1 — no handoff-doc freshness heuristics.
- Fail open: not a git repo, git missing, any error → allow.

**Acceptance (new suite section).** manual+dirty → exit 2 once, override passes;
manual+clean → silent; auto+dirty → no block; non-repo → silent; error → silent.

**Files.** New `plugins/tether/hooks/pre-compact-guard.py`, `hooks.json` wiring, tests,
HARNESS.md §4 + WORKFLOW.md invariants ("invariant #1 is now mechanized for manual
compaction").

---

## 4. `/ship` cold reviewer

**Problem.** `/ship`'s review step is a *self*-review — the one place left where the same
context that wrote the code grades it. The evidence base already says models self-evaluate
leniently (Huang et al., cited in PAPERS.md), and Anthropic's long-running-harness work
found generator–evaluator **separation** necessary because models "confidently praise"
mediocre output.

**Evidence.** Anthropic "Harness design for long-running application development" (2026,
local snapshot `harness-design-long-running-apps.html`); Huang et al. (already in base).
**Corroboration (2026-07-09 landscape survey):** the field converged here independently —
superpowers (250k★) ships two-stage fresh-context subagent review, gstack (121k★) ships
cross-model review. See `references/LANDSCAPE.md`.

**Design sketch.** Edit `plugins/tether/skills/ship/SKILL.md` only: replace the
self-review step with fresh-context review — prefer the built-in `/code-review` skill when
the environment has it; otherwise spawn one cold read-only subagent given only the diff
and a one-line intent statement, reporting findings back. One reviewer, no personas
(Zheng et al. still holds). `/ship` remains the decider; gates unchanged.

**Acceptance.** SKILL.md edit; the skill still stops before push/PR; wording keeps the
reviewer advisory (findings feed the shipper, not an auto-gate).

---

## 5. Hygiene batch

- **5a — drop `MultiEdit` from the PostToolUse matcher** in
  `plugins/tether/hooks/hooks.json` (tool no longer exists in Claude Code — confirmed
  absent from the July-2026 docs; the token is harmless dead weight). Keep `NotebookEdit`.
  Also remove `MultiEdit` from `EDIT_TOOLS` in `verify-on-edit.py`. Config-only; suites
  unaffected.
- **5b — context-health model→budget map.** The hook's `CLAUDE_CONTEXT_BUDGET` is static;
  switch models and the gauge miscalibrates silently. Hook inputs carry **no**
  model/window fields (SessionStart has an optional `model`, not guaranteed), so the only
  in-band source is the transcript: read `message.model` from the same last-assistant line
  the hook already parses, map known model ids to window sizes in a small table, keep
  `CLAUDE_CONTEXT_BUDGET` as the always-wins override, fall back to the current 200k
  default for unknown ids. **Documented caveat:** the 1M-context beta is a settings suffix
  (`[1m]`) that does *not* appear in the transcript model id — beta users (the user is
  one) must keep the env var. Add 1–2 suite cases (mapped id + no env → mapped budget;
  env set → env wins).
- **5c — sync the user's live install.** `~/.claude/hooks/context-health.py` is one
  line behind main (`STATE_DIR` → OS tmpdir). Apply together with whatever lands from this
  roadmap. **Requires the user's explicit OK first** — the live install is off-limits by
  default.
- **5d — optional cruft sweep:** untracked ignored `opencode/__pycache__/` left on main by
  branch switching; safe to delete locally.

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
  task (hard to score cheaply); tamper-bait (run after #1 lands — today it would measure
  #1's known gap, which is informative but must be labeled as such).
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
