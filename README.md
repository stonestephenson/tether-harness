# tether harness — Codex edition (`codex` branch)

A port of the [tether](https://github.com/stonestephenson/tether-harness) verification-first,
context-managed agentic harness to **OpenAI Codex CLI**. Codex's hook system is very close to
Claude Code's, so most of the harness ports cleanly.

> The Claude Code version (a one-command plugin) is on the **`main`** branch.

## Install

```
git clone -b codex https://github.com/stonestephenson/tether-harness
bash tether-harness/codex/install.sh
```

The installer copies into `~/.codex/`:
- **hooks** → `~/.codex/tether/hooks/`, wired into `~/.codex/hooks.json` (merged, not clobbered)
- **skills as custom prompts** → `~/.codex/prompts/` — invoke as `/prompts:catchup`, `/prompts:plan-change`, etc.
- **operating defaults** → `~/.codex/AGENTS.md`

Start a new Codex session afterward. If your Codex build doesn't read a global
`~/.codex/AGENTS.md`, paste `AGENTS.md`'s contents into your project's `AGENTS.md`.

## What you get + honest coverage

| Piece | Status on Codex |
|---|---|
| **Skills** (`/prompts:catchup`, `plan-change`, `test-first`, `council`, `experiment-log`, `handoff`, `ship`, `context-health`) | ✅ full — plain prompts |
| **verify-on-edit** (PostToolUse) | ✅ works. It matches Codex's `apply_patch` and reads the edited file path from the tool payload; if your Codex version keys that differently, tweak `EDIT_TOOLS` / the `path =` line in `verify-on-edit.py`. |
| **done-gate** (Stop) | ✅ runs your project check on finish and blocks via exit code 2. Hard-block behavior on `Stop` can vary by Codex version; even if it doesn't hard-block, it still runs and prints the failures. |
| **context-health** (context-pressure nudges) | ⚠️ **Claude-Code-only** — it needs per-turn transcript token counts that Codex hooks don't expose. Shipped but not wired. |

## Prerequisites (optional — hooks skip a tool that's missing)

```
pip install ruff pyright          # Python real-bug lint
brew install clang-format         # C/C++ format (only runs with a .clang-format)
brew install shellcheck
# rustfmt / clippy ship with the Rust toolchain
```

## Arm the done-gate (per project)

Add a fast `.codex/verify.sh` (seconds), or set `VERIFY_CMD`:

```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright          # example
```

## Config

- `VERIFY_CMD` — command the done-gate runs on finish (overrides the `.codex/verify.sh` file).
- Formatting/style checks are **opt-in**: they run only when the project ships a config
  (`.clang-format`, `ruff.toml`/`pyproject.toml`), so hand-formatted code isn't churned.

## Background

`references/HARNESS.md` (what/why/when + the research) and `references/WORKFLOW.md` (the loop).
