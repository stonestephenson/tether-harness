---
description: Get the current change merge-ready and committed LOCALLY. Runs the project's own quality gates (tests, lint, doc/sanity checks, regenerate generated artifacts), self-reviews the diff, then stages the right files and makes a local commit with a message drafted from the diff. STOPS before push / PR — publishing is a separate explicit step. Discovers each project's gates and conventions; project-agnostic. Use when the user says "ship it", "ready to commit", "wrap this up", "commit this", or wants a change finalized and committed locally.
---

# ship — make this change merge-ready, then commit locally

The pre-commit ritual you'd otherwise do by hand (and skip steps on when rushed).
It ends at a **local commit** and goes no further. Project-agnostic: discover the
gates and conventions from the project's own files.

## Step 0 — Preconditions (bail early, cleanly)
- **Is this a git repo?** (`git rev-parse --is-inside-work-tree`). If not, STOP and
  tell the user this needs `git init` first — do **not** init unilaterally.
- **Are there changes to ship?** (`git status --porcelain`). If clean, say so and stop.
- **What branch?** If on the default branch (`main`/`master`) and the project looks
  PR-based (has a remote / CI config), note it and offer to branch first; otherwise
  proceed on the current branch. Don't force a branch switch unprompted.

## Step 1 — Discover the gates
Find this project's "definition of done" / quality gates from its own files:
`CLAUDE.md`/`AGENTS.md` (a definition-of-done section), `Makefile`, `package.json`
scripts, `pyproject.toml`, CI config, a `tests/` dir, lint configs, any doc/sanity
check. Build the list: tests, lint/format, doc-lint, build, regenerate-generated-
artifacts, any visual/eval check the project documents.

## Step 2 — Run the gates (stop on red)
Run them. **If anything fails, STOP** — report what failed and do not commit broken
work. Offer to fix it or hand back to the user; don't paper over a red gate.
Regenerate any generated/derived artifacts the project expects (lockfiles, golden
baselines, generated docs) so they're in sync with the change.

## Step 3 — Self-review the diff
Read `git diff` (staged + unstaged). Check for: leftover debug prints / `console.log`
/ commented-out code; secrets or credentials; large unintended or generated files
sneaking in; **docs not updated** for a behavior/flag/API change; missing tests for
new logic. Surface anything risky to the user rather than burying it.

## Step 4 — Stage deliberately
`git add` the files that belong in this change. Respect `.gitignore`; do **not**
blind-`add -A` if it would sweep in generated output, local config, or junk. If the
working tree mixes unrelated changes, stage only the coherent set for this commit
(mention the rest).

## Step 5 — Draft the commit message from the diff
Write a clear message that explains **what and why**, not just what: a concise
imperative subject line, then a short body if the change warrants it. Follow the
repo's existing commit style (look at `git log`; honor Conventional Commits if used).
Include any co-author/trailer your harness conventions require.

## Step 6 — Commit locally, then STOP
Show the user the staged summary (`git diff --cached --stat`) and the proposed
message, then commit (`git commit`). Report the resulting short hash + subject.
**Do not push and do not open a PR** — publishing is a deliberate, separate step the
user triggers explicitly. Close by stating exactly that: committed locally on
`<branch>`; push/PR is the next manual step when they're ready.
