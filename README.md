# tether harness — Codex edition (`codex` branch)

A port of the [tether](https://github.com/stonestephenson/tether-harness) verification-first,
context-managed agentic harness to **OpenAI Codex CLI**. Codex's hook system is a near-clone
of Claude Code's — same event names, same JSON-on-stdin/stdout contract — and Codex ships a
native **skills** system in the same `SKILL.md` format, so the harness ports cleanly.

> The Claude Code version (a one-command plugin) is on the **`main`** branch.

## Prerequisites

- **Codex CLI** with the hooks + skills systems. Verified on **0.143.0**; if
  `codex --version` is older than ~0.129, run `codex update` first.
- **python3** on your PATH (the hooks are Python; nothing else to install).
- Optional linters — hooks silently skip whatever isn't installed:
  ```
  pip install ruff pyright          # Python real-bug lint
  brew install shellcheck           # shell lint
  brew install clang-format         # C/C++ format (only runs with a .clang-format)
  # rustfmt / clippy ship with the Rust toolchain
  ```

## Install

```
git clone -b codex https://github.com/stonestephenson/tether-harness
bash tether-harness/codex/install.sh
```

Then **start a new Codex session** (skills and hooks load on session start). The installer
is idempotent — re-run it any time to upgrade. It honors `CODEX_HOME` if you've moved it.

What it puts in `~/.codex/` (nothing outside it, and it never clobbers your own config):

| Item | Destination | Notes |
|---|---|---|
| hooks | `~/.codex/tether/hooks/*.py` | wired into `~/.codex/hooks.json`, **merged** with any hooks you already have |
| skills | `~/.codex/skills/<name>/` | 8 native skills; other skills you have are left alone |
| operating defaults | `~/.codex/AGENTS.md` | inserted between managed markers; **your existing AGENTS.md content is preserved** |

## Using the skills

The 8 skills **auto-trigger** when your task matches their description (same as Claude Code).
You can also run **`/skills`** to browse, or type **`$catchup`** (etc.) to invoke one by name:
`catchup`, `plan-change`, `test-first`, `council`, `experiment-log`, `handoff`, `ship`,
`context-health`.

## What you get + honest coverage

| Piece | Status on Codex |
|---|---|
| **Skills** | ✅ full — installed as native Codex skills; auto-trigger by description |
| **verify-on-edit** (PostToolUse) | ✅ parses Codex's `apply_patch` (V4A) payloads to find the edited file(s) and lints them, feeding diagnostics back via `{"decision":"block","reason":…}`. Also handles structured `file_path`. |
| **done-gate** (Stop) | ✅ runs your project check on finish; on failure returns `decision:"block"` so Codex continues and hands the failures back. Loop-guarded via `stop_hook_active`. |
| **context-health** (context-pressure nudges) | ⚠️ **Claude-Code-only** — it needs per-turn transcript token counts Codex hooks don't expose. The *skill* installs (useful for manual "should we compact?" calls); the **hook is intentionally not wired**. |

## Arm the done-gate (per project)

`done-gate` only runs if the project opts in. Add a fast `.codex/verify.sh` (seconds), or set
`VERIFY_CMD`:

```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright          # example
```

## Config

- `VERIFY_CMD` — command the done-gate runs on finish (overrides the `.codex/verify.sh` file).
- Formatting/style checks are **opt-in**: they run only when the project ships a config
  (`.clang-format`, `ruff.toml`/`pyproject.toml`), so hand-formatted code isn't churned.

## Verify your install (no login required)

These three checks confirm the wiring without spending a token:

```bash
# 1. Codex loads a healthy config and the hooks feature is enabled:
codex doctor --json | grep -q hooks && echo "config OK; hooks feature enabled"

# 2. The verify-on-edit hook fires on a real apply_patch payload (prints a decision:block).
#    Note the \\n — the patch text lives inside a JSON string, so newlines must be escaped:
printf 'import os\n' > /tmp/bad.py
printf '{"tool_name":"apply_patch","cwd":"/tmp","tool_input":{"command":"*** Begin Patch\\n*** Update File: bad.py\\n*** End Patch"}}' \
  | python3 ~/.codex/tether/hooks/verify-on-edit.py    # -> {"decision": "block", "reason": "...ruff...F401..."}

# 3. Your global AGENTS.md + the skills actually reach the model:
codex debug prompt-input "hi" | grep -c "operating defaults"   # -> 1 (AGENTS.md loaded)
```

The regression suite that backs the hooks is `codex/tests/verify-hooks.test.sh` (`bash` it from
the repo root).

**The one step that needs your login:** a full authenticated Codex turn, where the model edits
a file and you watch verify-on-edit hand back a lint error, or finish with a failing
`.codex/verify.sh` and watch the done-gate push it to keep going. To see it live:

```bash
cd some-project-with-a-.codex/verify.sh
codex "make a trivial edit to any file"      # verify-on-edit reacts to the edit
```

## Background

`references/HARNESS.md` (what/why/when + the research) and `references/WORKFLOW.md` (the loop).
