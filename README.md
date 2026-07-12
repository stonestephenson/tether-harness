# tether harness — opencode edition (`opencode` branch)

A port of the [tether](https://github.com/stonestephenson/tether-harness/tree/main) verification-first,
context-managed agentic harness (the Claude Code original lives on `main`) to **opencode**. opencode uses JavaScript/TypeScript plugins
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

Verified live on **opencode 1.17.15** (2026-07). opencode delivers bus events through a single
`event` hook you switch on by type, and edits through `tool.execute.after` — the plugin uses both.

| Piece | Status on opencode |
|---|---|
| **Skills** (`/catchup`, `/plan-change`, `/test-first`, `/council`, `/experiment-log`, `/handoff`, `/ship`, `/harden`, `/context-health`) | ✅ full — markdown commands. `/ship` reviews the diff in **fresh context** (one cold read-only `opencode run --agent plan` pass, advisory); `/harden` compiles repeated corrections into mechanical enforcement (linter config → `.tether/verify.sh` check → opencode `permission` rule → plugin guard). |
| **verify-on-edit** (plugin, `tool.execute.after` on `edit`/`write`) | ✅ **verified** — runs the fast file-local checks on each edited file and appends the diagnostics to the tool result, so the **agent sees and fixes them** (confirmed: the agent removed an unused import after an `F401`). |
| **done-gate** (plugin, `session.idle`) | ✅ runs your project check when the session goes idle and surfaces failures; it reports (does not hard-block). **Both paths verified live:** a passing check stays silent, a failing `.tether/verify.sh` surfaces the *"Project verification is failing…"* block on `session.idle` (observed repeatedly in an interactive session). Includes the **verifier-integrity guard** (anti-tamper): the resolved verifier is SHA-256-baselined per session; a mid-session change is reported once **with the diff** — even when the run is green — so a weakened verifier can't silently buy a green. ⚠️ Timing caveat: reliable **interactively** (the normal "turn finished" signal); under headless `opencode run` the process can exit before the async hook finishes writing, so the gate may not fire there. |
| **pre-compact-guard** (plugin, `experimental.session.compacting`) | ⚠️ **advisory — inverted contract.** opencode's compacting hook can INJECT context into the compaction prompt but cannot block (the inverse of Claude Code's PreCompact, which blocks but can't inject; verified against the 1.17.15 plugin typedefs — the hook is `experimental.`, so re-check on upgrades). On a dirty git tree it injects the file list + a "preserve this un-externalized state" instruction into the summary prompt and warns via console, pointing at `/ship` / `/handoff`. |
| **context-health** (context-pressure nudges) | ⚠️ **Claude-Code-only** — needs per-turn transcript token counts opencode plugins don't expose. Shipped but not wired (source kept in sync with main, incl. the model→budget map). |

## Prerequisites (optional — checks skip a tool that's missing)

```
pip install ruff pyright          # Python real-bug lint
brew install clang-format         # C/C++ format (only runs with a .clang-format)
brew install shellcheck
# rustfmt / clippy ship with the Rust toolchain
```
The plugin shells out to `python3`, so Python 3 must be on PATH. (`pyright` is listed only
because a typical `.tether/verify.sh` calls it — the per-edit hook itself uses ruff/shellcheck/
clang-format/rustfmt/gersemi, never pyright.)

## Arm the done-gate (per project)

Add a fast `.tether/verify.sh` (seconds), or set `VERIFY_CMD`:

```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright          # example
```

## Config

- `VERIFY_CMD` (or `CLAUDE_VERIFY_CMD`) — command the done-gate runs (overrides the
  `.tether/verify.sh` file; either env name is honored).
- `OPENCODE_CONFIG` — install target for `install.sh` (defaults to `~/.config/opencode`).
- Formatting/style checks are **opt-in**: they run only when the project ships a config
  (`.clang-format`, `ruff.toml`/`pyproject.toml`), so hand-formatted code isn't churned.

## Testing & extending the port

The port is thin: opencode's JS plugin translates opencode events into the Claude-Code-shaped
JSON the **shared Python hooks** expect, then feeds their output back to the agent.

**The wiring contract** (`opencode/plugins/tether-verify.js`):
- `tool.execute.after` (edit/write) → `verify-on-edit.py` with `{tool_name:"Edit",
  tool_input:{file_path}}`; the hook's stderr is appended to the tool result so the agent sees it.
- `session.idle` → `done-gate.py` with `{hook_event_name:"Stop", cwd, session_id}`; failures
  surface via `console.error`. The `session_id` (from the event's `properties.sessionID`) keys
  the anti-tamper baseline — without it a stale baseline from an earlier session would
  false-flag a legitimate between-session verifier edit. (`session.idle` may not complete under
  headless `opencode run` — reliable interactively.)
- `experimental.session.compacting` → `pre-compact-guard.py` with `{cwd, session_id}`; the
  hook's **stdout is appended to the compaction prompt** (`output.context`) and its stderr goes
  to `console.error`. Exit 2 means "dirty tree, advisory emitted" — nothing can block.
- A hook signals "problem" with a **non-zero exit + text on stderr**; exit 2 is the block-and-
  feed-back convention.

**The bundled regression suite** covers all three hooks (tamper guard and compact advisory
included) against the exact payload shapes the plugin sends:

```bash
bash opencode/tests/verify-hooks.test.sh
```

You can also drive a hook directly by piping JSON to it:

```bash
# verify-on-edit: expect an F401 diagnostic + exit 2
printf 'import os\n' > /tmp/t.py
echo '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/t.py"}}' | python3 opencode/hooks/verify-on-edit.py; echo "exit=$?"

# done-gate: a failing .tether/verify.sh anywhere from cwd up to the repo root → exit 2
echo '{"hook_event_name":"Stop","cwd":"'"$PWD"'"}' | python3 opencode/hooks/done-gate.py; echo "exit=$?"
```

**To extend the checks:** the per-edit check matrix and default ruff rule set (`E9,F`) live in
`build_checks()` in `verify-on-edit.py`; the done-gate's opt-in file precedence
(`.tether` → `.codex` → `.claude`, searched cwd-upward to the repo root) lives in
`find_verify_command()` in `done-gate.py`. Both are code knobs, not config.

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
