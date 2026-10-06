# PLATFORM-ASSUMPTIONS — the Claude Code facts the harness depends on

The drift-tripwire checklist for the `sota-radar` skill (Step 1): every externally-owned
fact the hooks rely on, with where it's used and how to re-verify. If a sweep finds any
of these changed, that's a **break** (fix the harness) or an **opportunity** (exploit it)
— either way it goes in the RADAR entry.

All facts verified **2026-07-09** against <https://code.claude.com/docs/en/hooks>, the
regression suites, and a live transcript parse. Re-confirmed doc-side by the 2026-07-09
cloud sweep (facts 2–3 pending behavioral re-verify on the next local sweep; also
re-baseline the doc's event count, read as 29 vs 32 across the two fetches).

Re-checked doc-side **2026-08-01** (cloud sweep): no contract breaks; facts 4 and 12
explicitly re-confirmed, fact 13 amended with the changelog URL. Fact 3
(`stop_hook_active`) is still absent from the doc — the same doc-vs-behavior gap the
2026-07-09 sweep flagged; the local suite exercises it behaviourally. One drift found
and fixed: the model→budget map (ROADMAP #11). **Caution from that sweep:** a
single doc fetch's summary wrongly reported fact 4 as broken and a focused re-fetch
corrected it — double-check any break a lone fetch reports before acting on it.

Re-checked **2026-10-01** (cloud sweep) and again **2026-10-05** (local, against the
raw `hooks.md` source): no contract breaks. Fact 3 is now documented, closing the gap
carried since 2026-07-09. Fact 12 moved for the first time (see the opportunities
watch). Facts 14–16 are new. The summarizer misreported fact 4 as broken for the third
sweep running, so the recipe below now greps the doc source instead.

## Contracts the hooks rely on (breaks if changed)

| # | Fact | Relied on by |
|---|------|--------------|
| 1 | `PostToolUse` exit 2 = non-blocking error; stderr is shown to Claude | `verify-on-edit.py` (its entire feedback path) |
| 2 | `Stop` accepts `{"decision":"block","reason":…}` on stdout; blocks the stop and feeds `reason` back | `done-gate.py` |
| 3 | `Stop` input includes `stop_hook_active: true` inside a stop-hook continuation (documented since the 2026-10 doc: "`true` when Claude Code is already continuing as a result of a stop hook") | `done-gate.py` loop guard |
| 4 | `UserPromptSubmit` accepts `hookSpecificOutput.additionalContext` (injected into model context) | `context-health.py` model-facing nudge |
| 5 | `systemMessage` on stdout is shown to the user (any event) | `context-health.py`, `done-gate.py` timeout note |
| 6 | Hook stdin always carries `session_id`, `cwd`, `transcript_path`, `hook_event_name`, `tool_name`/`tool_input` (tool events) | all three hooks |
| 7 | Edit tools are named `Edit`, `Write`, `NotebookEdit`; input field `file_path` (or `notebook_path`) | `hooks.json` matcher + `verify-on-edit.py` (`MultiEdit` removed — ROADMAP 5a, 2026-07-11) |
| 8 | `${CLAUDE_PLUGIN_ROOT}` expands in plugin `hooks.json` commands | `hooks.json` |
| 9 | Transcript is JSONL; main-thread assistant lines have `type:"assistant"`, `message.usage.{input_tokens,cache_read_input_tokens,cache_creation_input_tokens}`, and sidechains are marked `isSidechain:true`. The file is written **asynchronously and may lag** the in-memory conversation (doc, 2026-10), so a `Stop`-time read can be one turn behind — acceptable for a gauge; the next `UserPromptSubmit` read catches up | `context-health.py` occupancy measurement (live-fire verified 2026-07-09) |
| 10 | `settings.json` `env` vars reach hook subprocesses (`CLAUDE_CONTEXT_BUDGET` flow) | `context-health.py` |
| 11 | Project opt-in convention: `.claude/verify.sh` + `CLAUDE_VERIFY_CMD` override | `done-gate.py` |
| 12 | Hook inputs carry **no** context-window size on any event, and no model id on `UserPromptSubmit`/`Stop` (an optional `model` on `SessionStart`; `from_model`/`to_model` on the model-switch events) | why context-health reads `message.model` from the transcript instead (5b, 2026-07-11; re-verified 2026-10-05) and `CLAUDE_CONTEXT_BUDGET` stays the always-wins knob. Corollary 1: the `MODEL_BUDGETS` allowlist must be hand-updated per model launch — a standing radar chore (ROADMAP #11) until an occupancy primitive ships. Corollary 2: the window is a property of the session, not the model, so a 1M-mapped id can run at 200k and the gauge goes silent — ROADMAP #13 |
| 13 | Hooks docs live at `code.claude.com/docs/en/hooks` (`docs.claude.com` 301s there), and **`code.claude.com/docs/en/hooks.md` serves the raw markdown source** — grep that, don't summarize it; the **changelog** is `raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` — `code.claude.com/docs/en/release-notes` 404s (cost the 2026-08-01 cloud sweep a fetch) | the radar itself |
| 14 | `Stop` hooks have an **8-consecutive-continuation cap**: after eight stop-hook continuations in a row Claude Code overrides the next block and ends the turn (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` raises it; the count resets when Claude calls a tool) | non-binding for `done-gate.py` today — its `stop_hook_active` guard never blocks twice in a row — but it is the real ceiling if that guard is ever relaxed |
| 15 | `additionalContext`, `systemMessage`, `initialUserMessage`, and plain stdout are each **capped at 10,000 characters**, with no setting to raise it; over-cap text is replaced by a file path and a 2,000-character preview that Claude is not asked to read. The doc does not list `decision:"block"`'s `reason` under this cap | `context-health.py`'s nudge and both hooks' `systemMessage` (all far below it). `done-gate.py`'s `reason` is not documented as capped, but its worst case (`REASON_CAP = 5000` + fixed wording + a 1,500-char tamper diff) stays under 10,000 anyway — keep it there; don't raise that constant blindly |
| 16 | Window sizing the gauge mirrors (source: `code.claude.com/docs/en/model-config.md` + `env-vars.md`, 2026-10). **Model ids:** Fable, Sonnet 5+, and Opus 4.7+ are natively 1M with no `[1m]` variant; Opus 4.6 and Sonnet 4.6 reach 1M *only* through `[1m]`, and an id carrying that tag is sized at 1M even when unrecognized. **Caps:** `CLAUDE_CODE_DISABLE_1M_CONTEXT` (on = `1/true/yes/on`) holds every native-1M model to 200k; `CLAUDE_CODE_MAX_CONTEXT_TOKENS` declares the window for a gateway/custom id (ignored for recognized ids unless `DISABLE_COMPACT` is set); `CLAUDE_CODE_AUTO_COMPACT_WINDOW` sets the auto-compact window (plain integer, 100000–1000000; `500k` reads as `500` and clamps to the 100k minimum; capped at the model's window); `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` (1–100) lowers the compaction trigger to that percent of the window and cannot raise it | `context-health.py`'s model sizing and `apply_platform_caps()` (ROADMAP #13). The hook reads each var lower-only and errs toward "capped", so a change in meaning miscalibrates the gauge — in the over-warn direction if the var is narrowed, the silent direction if a new cap appears |

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
  auto-calibration, remove the 1M-beta env-var caveat, and retire the per-launch
  map-update chore (ROADMAP #11). Still absent as of the 2026-08-01 sweep; re-check
  every sweep, since this is the only fix that stops the allowlist lagging launches.
  **Partially arrived 2026-10:** a `context_tokens` field now ships on `SessionStart` for resumed sessions and on
  `PreModelSwitch`/`PostModelSwitch` — but not on `UserPromptSubmit`/`Stop`, where the
  gauge runs, and there is still no window-size field anywhere. It is close to the
  numerator the hook computes by hand, with one difference worth resolving at
  promotion: the platform's figure also counts the last response's *output* tokens
  (they are re-sent next turn), which the hook omits — a small standing undercount.
  Promote when `context_tokens` reaches those two events, or when any window-size
  field ships.
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

1. `curl` the raw doc source (`code.claude.com/docs/en/hooks.md`) and **grep it** fact by
   fact for 1–8 and 12–15; fact 16 lives in `model-config.md` and `env-vars.md` on the
   same host (also check the model roster there against `MODEL_BUDGETS`). Use a summarizing fetch for orientation only — it has reported fact 4 as
   broken in three consecutive sweeps while the source said otherwise.
2. `bash .claude/verify.sh` — all suites green re-verifies 1–3, 5–7, 11 behaviorally.
3. Live-fire fact 9: pipe `{"hook_event_name":"UserPromptSubmit","session_id":"radar-test","transcript_path":"<a real current transcript>"}` into `plugins/tether/hooks/context-health.py` with `CTX_WARN=0.01` — expect a JSON nudge; clean up the tmp state file (`$TMPDIR/claude-context-health-state/radar-test`).
4. Changelog scan for hook/skill/context/memory changes since the last RADAR entry.
