# Wiring the tether hooks into any agentic tool

The three scripts in `hooks/` are standalone, with one simple tool-agnostic contract:
they read a **JSON object on stdin** and communicate back via **exit code + stderr**.

- **exit 0, no output** → all good; stay silent.
- **exit 2, message on stderr** → there's a problem; the message is feedback for the agent
  to act on (and, where the tool supports it, a signal to block "finishing").

Your job is to fire each script at the right lifecycle moment and hand it the JSON it
expects. Missing external tools (ruff, clang-format, …) are skipped gracefully.

## verify-on-edit.py — after a file edit
Fire whenever the agent edits or writes a file. Input:
```json
{ "tool_name": "Edit", "tool_input": { "file_path": "<edited file>" } }
```
Runs fast, file-local checks — real-bug lint always; formatting/style **only if the project
ships a style config** (`.clang-format`, `ruff.toml`/`pyproject.toml`) so hand-formatted
code isn't churned — and exits 2 with the diagnostics if any.

## done-gate.py — when a turn finishes / the agent goes idle
Fire when the agent tries to finish. Input:
```json
{ "hook_event_name": "Stop", "cwd": "<project directory>" }
```
Runs the project's fast check — `$VERIFY_CMD`, else `.tether/verify.sh` (or `.codex` /
`.claude`) — and exits 2 with the failures if red. Stays silent (lets you finish) if the
project hasn't opted in.

## context-health.py — context-pressure nudges  *(Claude Code-specific)*
Fire at turn stop / prompt submit. Input:
```json
{ "hook_event_name": "Stop", "transcript_path": "<JSONL transcript>" }
```
It needs a transcript JSONL with per-assistant-turn `message.usage` token counts (the
Claude Code format). If your tool doesn't expose that, this hook can't measure occupancy
and no-ops. **This is the one piece that doesn't generalize.**

## How to fire them
- **Shell/command hook system** (Claude Code, Codex): point the hook at
  `python3 <path>/<hook>.py` for the matching event — the JSON-on-stdin + exit-2 contract
  matches directly. The **`codex`** branch has a ready `hooks.json` + installer.
- **Plugin/JS hook system** (opencode): build the JSON and pipe it to the script, surfacing
  stderr. The **`opencode`** branch has a ready plugin.
- **Neither?** You can still run a `verify.sh`-style check manually, and `AGENTS.md` + the
  skills give you the full workflow regardless.

## Config (env vars)
- `VERIFY_CMD` — command the done-gate runs (overrides the `.tether/verify.sh` file).
- `CLAUDE_CONTEXT_BUDGET` — window size in tokens (default `200000`).
- `CTX_WARN` / `CTX_ACT` / `CTX_CRIT` — occupancy bands (default `.70` / `.85` / `.95`).
