# tether-harness — entry map (main = Claude Code branch)

tether wraps AI coding agents in deterministic verification hooks + judgment skills.
Where everything lives:

- [`README.md`](README.md) — what tether is, the per-tool branch table, install, layout.
- [`ROADMAP.md`](ROADMAP.md) — the active backlog, **ground rules for implementing
  agents**, and the rejected-on-evidence list. Read it before changing anything.
- [`plugins/tether/README.md`](plugins/tether/README.md) — the plugin itself: hooks,
  skills, config, tests, and the maintainer dev loop (sandboxed live-testing).
- [`plugins/tether/references/`](plugins/tether/references/) — `HARNESS.md` (every
  piece's what/why/when + the evidence base), `WORKFLOW.md` (the session loop),
  `PAPERS.md` (bibliography).
- [`references/`](references/) — `PLATFORM-ASSUMPTIONS.md` (pinned platform facts the
  hooks depend on, incl. port-branch tripwires), `RADAR.md` (monthly sweep log),
  `LANDSCAPE.md` (graded competitor survey).

Definition of done: `bash .claude/verify.sh` green (both regression suites, 18 + 46
checks), and docs kept in sync when behavior changes (HARNESS / WORKFLOW / plugin
README / PAPERS). The ports live on branches `codex` / `opencode` / `generic` — same
skills, per-tool contracts; local worktrees may exist at `../tether-harness-<branch>`.
