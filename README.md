# tether harness — opencode edition (`opencode` branch)

A port of the [tether](https://github.com/stonestephenson/tether-harness) verification-first,
context-managed agentic harness to **opencode**. opencode uses JavaScript/TypeScript plugins
for lifecycle hooks and markdown files for commands, so the skills port as commands and the
verify hooks port as a small plugin that reuses the shared Python scripts.

> The Claude Code version (a one-command plugin) is on **`main`**; the Codex version is on **`codex`**.

## Install

```
git clone -b opencode https://github.com/stonestephenson/tether-harness
bash tether-harness/opencode/install.sh
```

The installer copies into `~/.config/opencode/`:
- **skills as commands** → `commands/` — invoke as `/catchup`, `/plan-change`, etc.
- **verification plugin** → `plugins/tether-verify.js` (auto-loads)
- **shared hook scripts** → `tether/hooks/`
- **operating defaults** → `AGENTS.md`

Restart opencode afterward. If your opencode build doesn't read a global
`~/.config/opencode/AGENTS.md`, paste `AGENTS.md`'s contents into your project's `AGENTS.md`.

## What you get + honest coverage

| Piece | Status on opencode |
|---|---|
| **Skills** (`/catchup`, `/plan-change`, `/test-first`, `/council`, `/experiment-log`, `/handoff`, `/ship`, `/context-health`) | ✅ full — markdown commands |
| **verify-on-edit** (plugin, `file.edited`) | ✅ runs the fast file-local checks on each edited file and prints diagnostics. Whether they're injected back into the model vs. surfaced to you depends on opencode's plugin-feedback API — either way the checks run. |
| **done-gate** (plugin, `session.idle`) | ✅ runs your project check when the session goes idle and surfaces failures. `session.idle` is the closest event to "turn finished"; it reports rather than hard-blocks. |
| **context-health** (context-pressure nudges) | ⚠️ **Claude-Code-only** — needs per-turn transcript token counts opencode plugins don't expose. Shipped but not wired. |

## Prerequisites (optional — checks skip a tool that's missing)

```
pip install ruff pyright          # Python real-bug lint
brew install clang-format         # C/C++ format (only runs with a .clang-format)
brew install shellcheck
# rustfmt / clippy ship with the Rust toolchain
```
The plugin shells out to `python3`, so Python 3 must be on PATH.

## Arm the done-gate (per project)

Add a fast `.tether/verify.sh` (seconds), or set `VERIFY_CMD`:

```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright          # example
```

## Config

- `VERIFY_CMD` — command the done-gate runs (overrides the `.tether/verify.sh` file).
- Formatting/style checks are **opt-in**: they run only when the project ships a config
  (`.clang-format`, `ruff.toml`/`pyproject.toml`), so hand-formatted code isn't churned.

## Background

`references/HARNESS.md` (what/why/when + the research) and `references/WORKFLOW.md` (the loop).
