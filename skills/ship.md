
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

## Step 3 — Review the diff (cold reviewer, not self-review)
The context that wrote the code must not be the only context that grades it —
models self-evaluate leniently (Huang et al.), and generator–evaluator separation
exists precisely because a writer "confidently praises" its own mediocre output.
Two parts:

1. **Mechanical scan, in-thread** (these are checks, not judgment): leftover debug
   prints / `console.log` / commented-out code; secrets or credentials; large
   unintended or generated files sneaking in; **docs not updated** for a
   behavior/flag/API change; missing tests for new logic.
2. **Fresh-context review of the judgment questions.** Spawn **one** cold
   read-only pass of your tool given ONLY the diff and a one-line statement of
   intent — e.g. `codex exec --sandbox read-only`, `opencode run --pure --agent
   plan -f <diff-file>`, a read-only subagent, or a fresh session pointed at the
   diff: "Review this diff. It is supposed to <intent>. Report correctness
   risks, simpler alternatives, and anything that contradicts the stated
   intent." One reviewer, no personas — the value is the fresh context, not a
   role label. If a cold run isn't possible in your tool, fall back to careful
   in-thread review and say so — the review happened, but it wasn't cold.

The reviewer is **advisory** — findings feed the shipper; they don't auto-gate.
Weigh them: fix what's real (re-run Step 2 on whatever you change), or proceed and
tell the user why the finding doesn't apply. Surface anything risky to the user
rather than burying it. A nit that has now come up in two ships is a harden
gather-candidate — mention it.

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
