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

Verified live on **opencode 1.17.14** (2026-07). opencode delivers bus events through a single
`event` hook you switch on by type, and edits through `tool.execute.after` — the plugin uses both.

| Piece | Status on opencode |
|---|---|
| **Skills** (`/catchup`, `/plan-change`, `/test-first`, `/council`, `/experiment-log`, `/handoff`, `/ship`, `/context-health`) | ✅ full — markdown commands |
| **verify-on-edit** (plugin, `tool.execute.after` on `edit`/`write`) | ✅ **verified** — runs the fast file-local checks on each edited file and appends the diagnostics to the tool result, so the **agent sees and fixes them** (confirmed: the agent removed an unused import after an `F401`). |
| **done-gate** (plugin, `session.idle`) | ✅ runs your project check when the session goes idle and surfaces failures. `session.idle` is the closest event to "turn finished"; it reports (does not hard-block). *Failing-path not yet exercised live — the pass path and wiring are verified.* |
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

## Running on a local model (works — Ollama)

The tether harness drives opencode on a **local** model: `qwen3-coder:30b` completes the full
agentic loop *and* self-corrects from `verify-on-edit` feedback (verified on a 32 GB M1 Max,
Ollama 0.31.1, opencode 1.17.15). Three things are needed, in priority order:

1. **`OLLAMA_CONTEXT_LENGTH=65536`** on the Ollama server — the one that actually mattered.
   Ollama defaults every model to a **4096-token** context, which truncates opencode's ~8.8k-token
   tool prompt so the model never sees the tools. opencode needs ≥64k.
2. **Ollama ≥ 0.31** (older ships broken per-model tool templates).
3. **`tool_call: true`** on each model entry in `opencode.jsonc`.

The `@ai-sdk/openai-compatible` `/v1` shim is fine — no native-provider swap needed.
`gpt-oss:20b` also works (fallback); `devstral` isn't reliable in opencode yet. See
[`opencode/LOCAL-MODELS.md`](opencode/LOCAL-MODELS.md) for the reference config, the headless
repro harness, per-model results, and how to make the context setting survive a reboot.

## Background

`references/HARNESS.md` (what/why/when + the research) and `references/WORKFLOW.md` (the loop).
