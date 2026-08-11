# tether-harness — entry map (main = Claude Code branch)

tether wraps AI coding agents in deterministic verification hooks + judgment skills.
Where everything lives:

- [`README.md`](README.md) — what tether is, the per-tool branch table, install, layout.
- [`ROADMAP.md`](ROADMAP.md) — the active backlog, **ground rules for implementing
  agents**, and the rejected-on-evidence list. Read it before changing anything.
- [`eval/README.md`](eval/README.md) — the tether-vs-vanilla mechanism evaluation
  (ROADMAP #6, **concluded**): what we tested and found (done-gate ~null for frontier
  models). `bench/` is the instrument + detail; `bench/FINDINGS.md` has the specifics.
- [`plugins/tether/README.md`](plugins/tether/README.md) — the plugin itself: hooks,
  skills, config, tests, and the maintainer dev loop (sandboxed live-testing).
- [`plugins/tether/references/`](plugins/tether/references/) — `HARNESS.md` (every
  piece's what/why/when + the evidence base), `WORKFLOW.md` (the session loop),
  `PAPERS.md` (bibliography).
- [`references/`](references/) — `PLATFORM-ASSUMPTIONS.md` (pinned platform facts the
  hooks depend on, incl. port-branch tripwires), `RADAR.md` (monthly sweep log),
  `LANDSCAPE.md` (graded competitor survey).
- [`.claude/README.md`](.claude/README.md) — **maintainer tooling, not shipped**: the
  `sota-radar` sweep skill and the `plain-english` triage hook. Nothing here reaches
  tether users, and the ROADMAP's new-scaffolding burden of proof doesn't govern it.

Definition of done: `bash .claude/verify.sh` green (three regression suites — 20 + 46 +
27 checks with the full optional toolchain; missing tools skip their blocks — plus a
doc-link check), and docs kept in sync when behavior changes (HARNESS / WORKFLOW /
plugin README / PAPERS). **This is the one place the check counts are stated** — other
docs point here rather than repeating a number that drifts.

## Porting to the other tools (read before changing a hook or skill)

`ROADMAP.md`'s ground rules require every change to land on `main` first, then port to
`codex` / `opencode` / `generic`. Those are **branches, not directories** — nothing about
them is visible from a `main` checkout, which is the usual reason a port gets missed.

- **Reach them via worktrees**, already checked out at `../tether-harness-<branch>`
  (`git worktree list` to confirm). Each branch has its own entry doc — `codex` uses
  `AGENTS.md`, the others `README.md` — plus its own suite and `.claude/verify.sh`.
- **Each port has a different contract**, so a file is rarely a straight copy. The two
  fragile deltas are pinned in
  [`references/PLATFORM-ASSUMPTIONS.md`](references/PLATFORM-ASSUMPTIONS.md)
  ("Port-branch facts"): Codex blocks `PreCompact` via `{"continue": false}` JSON rather
  than exit 2, and opencode's compacting hook is **inject-only** — it cannot block.
- **Verify inside each worktree** (`bash .claude/verify.sh`); the totals differ from
  main's, and each branch prints its own.
- **Batching is allowed for docs-only deltas** — flush the queue before a live demo on
  that branch, when a behavior-critical change enters it, or at 2–3 queued items.

One useful invariant: `context-health.py` is byte-identical across all four branches, so
a plain `diff` against main is a reliable drift check for that file. It ships on the ports
but is **unwired** on codex/opencode, and only `main` has a suite for it.
