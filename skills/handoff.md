
# handoff — is this repo ready for a cold pickup?

The real test of documentation is whether an agent with **no conversation context**
can continue the work. This skill runs that test with fresh subagents, then fixes
whatever they trip on. It is project-agnostic: discover the project's specifics from
its own files rather than assuming a stack or toolchain.

Run the steps in order. Do not skip the fix/re-verify steps — an audit that only
reports gaps is half the job.

## Step 0 — Orient (you, the main agent)
Read the project's entry docs (e.g. `README`, `CLAUDE.md`/`AGENTS.md`, any
`ROADMAP`/`CHANGELOG`, and a `docs/` reference if present). Identify: the doc set,
the build/run/test commands, the test/verification tracks, and any backlog. You need
this to (a) run the right verification later and (b) know which doc owns which fact
when you fix gaps. **Do NOT pass this understanding to the subagents** — their value
is that they start cold and rediscover it from the repo, which is exactly what tests
the docs.

## Step 1 — Deterministic pass (if available)
If the project has a mechanical doc/sanity check (a `doc_lint`/`doc-check` script, a
link checker, a docs test, etc.), run it and note failures. If none exists, skip —
the cold audit still covers it. (Consider suggesting one if drift is a recurring problem.)

## Step 2 — Cold audit (the core)
Spawn **two `general-purpose` subagents IN PARALLEL** (two Agent calls in one
message). They have zero context by design. Substitute the absolute repo path for
`<REPO>`. Use these prompts close to verbatim — they are tuned to catch the full
range of handoff gaps:

**Agent A — build / onboarding readiness (may build & run):**
> You are an engineer handed the repository at `<REPO>` with ZERO prior context.
> Assess whether its documentation lets a fresh engineer understand, build, run,
> test, and continue it. Be critical and specific — find gaps, don't praise.
> 1. Read the entry docs (README, CLAUDE.md/AGENTS.md, ROADMAP/CHANGELOG, docs/).
>    Skim the source tree.
> 2. Following ONLY the docs (don't guess commands), try to: install/build it, run
>    it (every documented run mode), and run every test/verification track. Record
>    which documented commands worked and which failed / were missing / ambiguous.
> 3. Answer: (a) in 2-3 sentences, what is this and its current state? (b) could you
>    build/run/test from the docs alone — what worked, what didn't? (c) do you
>    understand the high-level architecture? (d) if asked to "push it forward" (a
>    backlog item, or tune a feature), would you know which files to touch, which
>    knobs are build-time vs config/runtime, and the workflow (the edit→verify loop,
>    the test tracks, how to update any golden/snapshot baselines)?
> 4. Produce a CRITICAL, SPECIFIC, PRIORITIZED list of doc gaps: missing info,
>    ambiguities, stale or factually-wrong statements, undocumented commands/flags,
>    things clearly only in the author's head. Cite file/section. Most blocking first.
> Constraints: DO NOT modify any source or docs. You MAY build/test/run. DO NOT
> delete generated outputs or assets (build dirs, render/output dirs, data, etc.).
> End with a one-line verdict: could a cold agent continue from the docs alone —
> Yes / Partially / No — and the single most important thing to add.

**Agent B — domain / architecture extensibility (READ-ONLY, no build):**
> You are a domain engineer who just inherited the repository at `<REPO>` with ZERO
> prior context. Assess whether the docs AND code comments are enough to UNDERSTAND
> and EXTEND the core technical content (the algorithms, data flow, and hardest
> subsystems) — not merely run it. READ-ONLY: do not modify, build, or run anything;
> only read and reason.
> 1. Identify the project's hardest / most load-bearing subsystems from the docs +
>    code. For each: documented well enough to understand, or would you have to
>    reverse-engineer it? (yes / partly / no + one-line justification).
> 2. If asked to tune or extend the trickiest feature, would the docs tell you which
>    knobs to turn and where? Name the specific tunables you'd find vs. the ones
>    you'd have to discover by reading code.
> 3. List SPECIFIC gaps with file citations: undocumented conventions / units /
>    coordinate systems, unexplained magic numbers, architecture or data flow that's
>    only inferable from code, and any place the docs CLAIM something the code doesn't do.
> End with a one-line verdict (Yes / Partially / No to "could a cold agent extend
> this from docs+comments alone") and the top thing to add.

Run them in parallel; only Agent A builds (Agent B is read-only) so they don't
collide. If the harness can't spawn subagents, fall back to doing both audits
yourself under an explicit "pretend you have never seen this repo; trust only what
the files say" framing — weaker, but better than nothing; tell the user you fell back.

## Step 3 — Synthesize
Merge the deterministic output and both agents' findings into one deduped, prioritized
gap list. Map each gap to the doc that should own the fix:
- **README** — purpose, quickstart, features, layout, prerequisites.
- **CLAUDE.md / AGENTS.md** — workflow, commands/flags, conventions, architecture
  summary, gotchas, which knobs are build-time vs config/runtime, definition of done.
- **`docs/` reference** — the algorithms/design; MUST match what the code actually does.
- **ROADMAP / CHANGELOG** — history + the open-tasks backlog.
- **Inline comments** — load-bearing magic (initial conditions, tuning constants,
  non-obvious invariants) that no prose will realistically carry.

## Step 4 — Fix
Close the gaps. Rules:
- Edit **docs and comments only**. Do **not** change code behavior to make a doc
  true. If a gap is actually a *code* bug, or a docs-claim-the-code-doesn't-honor
  mismatch, FLAG IT to the user separately — don't paper over it.
- For shipped features, write present-tense docs about what they do; delete
  future-tense/aspirational wording and dead/placeholder text.
- If "all done / no backlog" leaves a cold agent without targets, add an
  **open-tasks** section (the natural next pushes surfaced by the audit).

## Step 5 — Re-verify
- Re-run the deterministic check (Step 1) → expect clean.
- Run the project's own test/verification tracks → ensure your doc edits caused no
  regression and the documented commands still work.
- If you intentionally changed any rendered/visual/snapshot baseline, regenerate and
  re-bless it.

## Step 6 — Report
Give the user a concise summary: a table of gaps found → fixes made, any residual
**known** gaps left deliberately (with why), any code/doc mismatches you flagged for
them, and a one-line verdict on cold-start readiness (Yes / Partially / No). If the
verdict isn't "Yes", say exactly what still blocks it.

## What "caught everything necessary" means (coverage checklist)
The audit must surface gaps across all of these — if the subagents didn't touch one,
probe it yourself before reporting:
- **Onboarding:** state purpose + current state; build; run *every* mode; run *every*
  test track; update any baselines.
- **Comprehension:** each major subsystem; the conventions; environment/platform
  gotchas; which knobs are build-time vs config/runtime.
- **Extensibility:** implement the next backlog item; tune the trickiest feature; add
  a test — knowing which files/knobs and the workflow.
- **Accuracy:** no doc names a file/flag/command that doesn't exist; no future-tense
  for shipped features; option/flag/control lists are complete; documented commands
  actually run; any deliberately-uncovered area is stated as a known gap.
