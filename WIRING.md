# Wiring the tether hooks into any agentic tool

The four scripts in `hooks/` are standalone, with one simple tool-agnostic contract:
they read a **JSON object on stdin** and communicate back via **exit code + stderr**
(one of them also uses stdout — noted below).

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
{ "hook_event_name": "Stop", "cwd": "<project directory>", "session_id": "<stable per-session id>" }
```
Runs the project's fast check — `$VERIFY_CMD` (or `$CLAUDE_VERIFY_CMD`), else
`.tether/verify.sh` (or `.codex` / `.claude`), searched from `cwd` up to the repo root —
and exits 2 with the failures if red. Stays silent (lets you finish) if the project
hasn't opted in.

**Verifier-integrity guard (anti-tamper).** Agents have been observed *weakening the
verifier* to get green instead of fixing the code (EvilGenie, SpecBench — and a live
Codex session rewriting its own `verify.sh`). So the gate SHA-256-baselines the resolved
verifier (the script's bytes, or the env command string; switching sources counts as a
change) the first time it runs in a session, and re-hashes on every later run:

- **changed + green** → exit 2 once, with the verifier diff on stderr, then it
  re-baselines — so a legitimate change costs one confirmation and a tampered one gets
  surfaced; it never nags twice for the same change.
- **changed + red** → the normal red report plus a tamper note (no re-baseline:
  reverting to the accepted verifier goes green silently).
- Never auto-reverts; any internal error fails open.

This is why `session_id` matters: it keys the baseline (state lives under the OS temp
dir, `tether-done-gate-state/`). Pass any string that's stable within one session and
different across sessions — without it, all sessions share one baseline and a legitimate
between-session verifier edit would false-flag. If your tool can block "finishing", the
exit-2 report doubles as that block; if it can't, surface stderr to the user.

## pre-compact-guard.py — before a compaction / summarization  *(uses stdout)*
Fire before your tool compacts or summarizes the conversation. Input:
```json
{ "cwd": "<project directory>", "session_id": "<optional>" }
```
Compaction is lossy: a dirty git tree at compaction time is exactly the work the summary
will strand. On a **clean** tree (or any error — not a repo, no git): exit 0, silent. On
a **dirty** tree it emits on two channels — wire whichever your tool supports:

- **stdout** → a summarizer-directed context block (the dirty file list + an instruction
  to preserve that un-externalized state in the summary). If your tool can inject
  context into the compaction prompt (e.g. opencode's `experimental.session.compacting`
  hook), append stdout to it — the summary then carries the in-flight work it can't
  otherwise know about.
- **stderr** → a short user-facing warning pointing at `/ship` / `/handoff` /
  `/context-health`.

Exit 2 = "dirty, advisory emitted". This edition never blocks and keeps no state. If
your tool's pre-compact event **can** block (Claude Code's manual PreCompact can), use
the blocking edition from the `main` branch instead — it blocks a manual compact once,
with a re-run override.

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
- `VERIFY_CMD` (or `CLAUDE_VERIFY_CMD`) — command the done-gate runs (overrides the
  `.tether/verify.sh` file; either name is honored).
- `CLAUDE_CONTEXT_BUDGET` — window size in tokens. When unset, the hook maps the
  transcript's model id to a window size (unknown ids → `200000`).
- `CTX_WARN` / `CTX_ACT` / `CTX_CRIT` — occupancy bands (default `.70` / `.85` / `.95`).

## Testing
`bash tests/verify-hooks.test.sh` drives all the hook scripts with the exact payload
shapes documented above (42 checks — done-gate discovery + anti-tamper, the compact
advisory's stdout/stderr split, verify-on-edit's opt-in formatting rules).
