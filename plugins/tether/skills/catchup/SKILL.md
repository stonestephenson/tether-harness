---
name: catchup
description: Reconstruct your context at the START of a session for whatever project you're in — what it is, its current state (branch, clean/dirty, tests green or red), what changed since last time, and what to do next. Reads the entry doc (CLAUDE.md / AGENTS.md) and follows ITS pointers to the other docs, then layers in the transient state (git, test status, WIP) that docs don't hold. Project-agnostic. Use when you open a project cold, return after time away, after /clear or compaction, or when the user says "where were we", "catch me up", "get oriented", or "what's the state".
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash
---

# catchup — get oriented in this project, fast

The mirror of `/handoff`: handoff *exports* context before you leave; catchup
*imports* it when you arrive. Reconstruct enough state to start working in a few
minutes, without re-reading the whole repo. Project-agnostic — discover specifics
from the project's own files; assume nothing about the stack.

## If the invocation names a focus (honor it)
Anything the user adds after `/catchup` is your steer — e.g. "focus on the
simulation", "I'm about to edit the renderer", "we're debugging auth". When a focus
is present:
- Keep Steps 1-3 **brief** for the rest of the project (just enough to orient).
- Go **deep** on the named area: read its actual source files, trace its data flow /
  key types / entry points and how it connects to the rest, note its tests, its
  tunable knobs, and the docs section that covers it.
- Weight Step 4's report and recommended next action toward that area.
The goal: a **working mental model of that subsystem, ready to edit** — general
context plus the specific files the upcoming task will touch.

## Step 1 — Read the entry doc, then FOLLOW ITS POINTERS
Read the project's entry doc — prefer `CLAUDE.md`, else `AGENTS.md`, else top-level
`README`. Treat it as the **map**: it should point to the other docs (a roadmap, a
design/architecture reference, a changelog, etc.).
- **Follow the pointers it gives** — read the docs it links/names, not every `.md`
  in the tree. A big project can have dozens of markdown files; the entry doc tells
  you which few matter. Don't slurp them all.
- If the entry doc is **missing or doesn't point** to the others, fall back to the
  top-level `README` plus an obvious-docs scan (`ROADMAP*`, `CHANGELOG*`, `docs/`),
  and note this gap — a project whose entry doc doesn't map the others is a handoff
  smell worth flagging (suggest `/handoff`).

From these, extract: what the project is (1-2 sentences), the build/run/test
commands, the conventions/definition-of-done, and any backlog / "next" tasks.

## Step 2 — Reconstruct the transient state (what the docs can't hold)
This is catchup's real value — the live state, not the prose.
- **Git** (if a repo): current branch; `git status` (clean vs uncommitted/staged
  work = WIP in progress); recent history (`git log --oneline -15`); and *what*
  changed recently (`git log --stat -3` or `git diff --stat`). If it's **not** a git
  repo, say so.
- **Health**: identify the project's verification commands (from Step 1). Run the
  **fast, side-effect-free** ones (unit tests, lint, a doc/sanity check) to report
  green/red. Do **not** kick off heavy/expensive steps (full builds, long renders,
  deploys) unprovoked — name them instead and offer to run them.
- **Done-gate check**: see whether `.claude/verify.sh` (or `CLAUDE_VERIFY_CMD`)
  exists. If not, the Stop done-gate is dormant — from the fast checks you just
  identified, **offer to create a `.claude/verify.sh`** (seconds-fast: e.g.
  `ruff check . && pyright`, `cargo clippy`, or a quick `ctest` subset) so
  green-on-finish is enforced from now on. Propose it; don't write it unprompted.
- **Loose ends**: scan for `TODO`/`FIXME` near recently-changed files, a failing
  test, or uncommitted work that looks half-finished.

## Step 3 — Locate "where we left off" and "what's next"
Synthesize: the most recent commits + any WIP diff tell you what was being worked on;
the backlog/roadmap tells you what's queued; a red test or stray WIP tells you what
might be unfinished. Form a concrete recommended next action (or 2-3 options).

## Step 4 — Report, then hand control back
Give a tight orientation, not a dump:
- **What / state:** one line on the project; branch; clean or N uncommitted files;
  tests green/red.
- **Recently:** the last meaningful change(s).
- **Next:** the queued task(s) and anything unfinished or broken.
- **Verification:** whether the done-gate is armed (`.claude/verify.sh` present); if
  not, offer to add it (see Step 2).
Then **ask the user what they want to work on** (offer the recommended next task as
the default). Don't start changing things — catchup orients; it doesn't act.

## Coupling — handoff's cold audit invokes this skill
`/handoff`'s Agent A opens its audit by running `/catchup` for real, and holds its
orientation to a contract: what/state, build/run/test commands, conventions, backlog
(handoff Step 2). If you change Step 1's pointer-following behavior or the shape of
Step 4's report, re-check handoff Step 2 — a silent mismatch there degrades the audit.
