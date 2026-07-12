# PLATFORM-ASSUMPTIONS — the Claude Code facts the harness depends on

The drift-tripwire checklist for the `sota-radar` skill (Step 1): every externally-owned
fact the hooks rely on, with where it's used and how to re-verify. If a sweep finds any
of these changed, that's a **break** (fix the harness) or an **opportunity** (exploit it)
— either way it goes in the RADAR entry.

All facts verified **2026-07-09** against <https://code.claude.com/docs/en/hooks>, the
regression suites, and a live transcript parse. Re-confirmed doc-side by the 2026-07-09
cloud sweep (facts 2–3 pending behavioral re-verify on the next local sweep; also
re-baseline the doc's event count, read as 29 vs 32 across the two fetches).

## Contracts the hooks rely on (breaks if changed)

| # | Fact | Relied on by |
|---|------|--------------|
| 1 | `PostToolUse` exit 2 = non-blocking error; stderr is shown to Claude | `verify-on-edit.py` (its entire feedback path) |
| 2 | `Stop` accepts `{"decision":"block","reason":…}` on stdout; blocks the stop and feeds `reason` back | `done-gate.py` |
| 3 | `Stop` input includes `stop_hook_active: true` inside a stop-hook continuation | `done-gate.py` loop guard |
| 4 | `UserPromptSubmit` accepts `hookSpecificOutput.additionalContext` (injected into model context) | `context-health.py` model-facing nudge |
| 5 | `systemMessage` on stdout is shown to the user (any event) | `context-health.py`, `done-gate.py` timeout note |
| 6 | Hook stdin always carries `session_id`, `cwd`, `transcript_path`, `hook_event_name`, `tool_name`/`tool_input` (tool events) | all three hooks |
| 7 | Edit tools are named `Edit`, `Write`, `NotebookEdit`; input field `file_path` (or `notebook_path`) | `hooks.json` matcher + `verify-on-edit.py` (`MultiEdit` removed — ROADMAP 5a, 2026-07-11) |
| 8 | `${CLAUDE_PLUGIN_ROOT}` expands in plugin `hooks.json` commands | `hooks.json` |
| 9 | Transcript is JSONL; main-thread assistant lines have `type:"assistant"`, `message.usage.{input_tokens,cache_read_input_tokens,cache_creation_input_tokens}`, and sidechains are marked `isSidechain:true` | `context-health.py` occupancy measurement (live-fire verified 2026-07-09) |
| 10 | `settings.json` `env` vars reach hook subprocesses (`CLAUDE_CONTEXT_BUDGET` flow) | `context-health.py` |
| 11 | Project opt-in convention: `.claude/verify.sh` + `CLAUDE_VERIFY_CMD` override | `done-gate.py` |
| 12 | Hook inputs carry **no** context-window size and no model id (except an optional `model` on `SessionStart`) | why context-health reads `message.model` from the transcript instead (5b, 2026-07-11) and `CLAUDE_CONTEXT_BUDGET` stays the always-wins knob |
| 13 | Hooks docs live at `code.claude.com/docs/en/hooks` (`docs.claude.com` 301s there) | the radar itself |

## Opportunities watch (new capabilities → harness upgrades)

- `PreCompact` is blockable (exit 2 / `continue:false`), no instruction injection —
  **landed as `pre-compact-guard.py` (ROADMAP #3, 2026-07-11).** `manual`/`auto` matcher
  values are documented (confirmed by the 2026-07-09 cloud sweep); the hook branches on
  the `trigger` field in code and treats an absent value as auto (never blocks).
  Remaining watch: instruction injection.
- `PostCompact` is logging-only today. Watch: if it ever accepts `additionalContext`,
  re-injecting branch/verify-status/file:line after compaction becomes possible.
- Watch for a **context-window/occupancy field** in hook input or a supported API —
  would supersede 5b's transcript-model→budget map (landed 2026-07-11) with true
  auto-calibration, and remove the `[1m]`-beta env-var caveat.
- `SessionStart` can inject `additionalContext` + register `watchPaths`; `FileChanged`
  fires on watched paths — candidate strengthening for ROADMAP #1 (verifier watch).
- Unexploited events as of 2026-07: `PostToolUseFailure`, `PostToolBatch`,
  `SubagentStart/Stop`, `ConfigChange` (blockable), `InstructionsLoaded`. No harness use
  identified yet — re-evaluate only with a concrete need.

## Port-branch facts (tracked on their branches; radar sweeps them too)

The `codex` / `opencode` branches pin their own contracts in their READMEs; the two
fragile ones worth a tripwire here (verified 2026-07-11):

- **Codex `PreCompact` blocks via `{"continue": false, "stopReason": …}` JSON, not
  exit 2** (learn.chatgpt.com/docs/hooks) — relied on by the codex `pre-compact-guard.py`.
- **opencode's pre-compaction hook is `experimental.session.compacting`** (inject-only —
  `output.context` reaches the compaction prompt; no block channel, no manual/auto
  field; verified against the 1.17.15 `@opencode-ai/plugin` typedefs). Relied on by the
  opencode plugin's pre-compact wiring. The `experimental.` prefix means this can rename
  or change shape in any release — re-check the typedefs on opencode upgrades.

## How to re-verify (the radar's Step 1 recipe)

1. Fetch the hooks doc; check facts 1–8, 12, 13 against its event/output tables.
2. `bash .claude/verify.sh` — both suites green re-verifies 1–3, 5–7, 11 behaviorally.
3. Live-fire fact 9: pipe `{"hook_event_name":"UserPromptSubmit","session_id":"radar-test","transcript_path":"<a real current transcript>"}` into `plugins/tether/hooks/context-health.py` with `CTX_WARN=0.01` — expect a JSON nudge; clean up the tmp state file.
4. Changelog scan for hook/skill/context/memory changes since the last RADAR entry.
