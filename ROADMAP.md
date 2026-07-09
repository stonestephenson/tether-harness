# ROADMAP — the vetted backlog (from the 2026-07 SOTA audit)

**Read this if you're an agent picking up work on tether.** On 2026-07-09 the harness was
audited against 2025–26 research and industry practice. Verdict: it behaves as designed
(all regression suites green; hook contracts match the July-2026 Claude Code hooks API;
a live-transcript parse confirmed context-health still reads the real format) and its
shape — thin deterministic verification hooks + judgment skills, no multi-agent theater —
is where the field converged. Roughly fifteen candidate additions were evaluated; the five
below are the only ones that cleared the "genuinely moves the needle" bar. Everything else
was **rejected on evidence** (see the last section — don't re-propose those without new
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

## Status

| # | Task | Priority | Status |
|---|------|----------|--------|
| 1 | Verifier-integrity guard (done-gate anti-tamper) | high | not started |
| 2 | Corrections→enforcement compiler (`/harden`) | high | not started |
| 3 | PreCompact externalize-guard | medium | not started |
| 4 | `/ship` cold reviewer | medium | not started |
| 5 | Hygiene batch | low | not started |

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
instructions; `PostCompact` exists but is logging-only. **Confirm at implementation time**
whether PreCompact still distinguishes manual vs auto compaction (the older API had a
`manual`/`auto` matcher; the current docs page didn't confirm either way). If they can't
be distinguished, rescope — blocking what might be an auto-compact at a full window could
wedge the session, which violates fail-open.

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

## Rejected on evidence — do not re-propose without new evidence

- **Mutation-testing gate.** Real at org scale (Meta's LLM mutation testing, InfoQ 2026),
  but agent-level evidence says mid-task test machinery doesn't move outcomes
  ("Rethinking the Value of Agent-Generated Tests", arXiv 2602.07900 — test-writing volume
  doesn't correlate with success; prompting for more tests doesn't help), and
  `/test-first`'s "watch it fail first" already delivers the core guarantee.
- **More skills / skill sprawl.** Minimal scaffolds are SOTA (mini-swe-agent ~74%
  SWE-bench Verified, ~100 lines, swebench.com). Twenty marginal skills mean nothing.
- **Personas / multi-agent implementation.** Base evidence unchanged (Cognition; Zheng
  et al.; Du et al.) — one writer, many readers; structure over persona.
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
