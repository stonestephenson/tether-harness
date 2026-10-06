#!/usr/bin/env python3
"""
context-health hook — Layer 1: the deterministic trigger.

Wired to TWO events (same script, branches on hook_event_name):
  * Stop             — fires the instant a task finishes. Surfaces a user-facing
                       nudge at that natural boundary. (Cannot inject into the
                       model without forcing it to keep working, so it doesn't.)
  * UserPromptSubmit — fires at the start of the next task. Injects the
                       recommendation into the MODEL's context so it can act.

It measures how full the MAIN context window is from the real token counts in the
session transcript (not a guess), and only speaks up when occupancy ESCALATES into
a higher band. It NEVER acts and never blocks the prompt — measure and recommend.
The judgment (continue/compact/handoff+clear, what to keep) lives in the
`context-health` skill.

Two notification channels are debounced INDEPENDENTLY so they don't cannibalize
each other:
  * user_band  — the user-visible systemMessage (either event can raise it)
  * model_band — the model-visible additionalContext (only UserPromptSubmit)
Both re-arm when occupancy falls back down (after you compact/clear).

Config via env vars (all optional):
  CLAUDE_CONTEXT_BUDGET   total window tokens — ALWAYS wins when set. When unset,
                          the budget comes from the transcript's model id via
                          MODEL_BUDGETS below (unknown ids -> 200k fallback),
                          then is lowered by the platform's own window caps.
  CTX_WARN / CTX_ACT / CTX_CRIT   band fractions     (default .70/.85/.95)

Read but not owned (Claude Code's window caps; they only ever LOWER the budget,
and only when CLAUDE_CONTEXT_BUDGET is unset):
  CLAUDE_CODE_DISABLE_1M_CONTEXT    on -> a 1M model is held to 200k
  CLAUDE_CODE_MAX_CONTEXT_TOKENS    tokens -> the window declared for the model
  CLAUDE_CODE_AUTO_COMPACT_WINDOW   tokens -> the session compacts there
  CLAUDE_AUTOCOMPACT_PCT_OVERRIDE   1-100 -> ...at this percent of the window
"""
import json
import os
import re
import sys
import tempfile

# Session debounce state — ephemeral, in the OS temp dir so it works no matter
# how the plugin is installed (not tied to ~/.claude).
STATE_DIR = os.path.join(tempfile.gettempdir(), "claude-context-health-state")
BAND_NAME = {1: "getting heavy", 2: "act soon", 3: "critical"}

DEFAULT_BUDGET = 200000
# Known model-id prefixes -> context window (verified against the model-config
# docs, 2026-10: Fable, Sonnet 5+, and Opus 4.7+ are natively 1M; Haiku 4.5 and
# older models are 200k). Prefix match tolerates date-suffixed ids.
# Unknown ids fall back to DEFAULT_BUDGET — the safe direction (over-warn).
# This allowlist lags every frontier launch by design (a denylist would flip
# the safe direction to under-warning). Adding each new model id is a standing
# chore for the monthly maintainer sweep.
MODEL_BUDGETS = (
    ("claude-fable-5", 1_000_000),
    ("claude-mythos-5", 1_000_000),
    ("claude-opus-5", 1_000_000),
    ("claude-opus-4-8", 1_000_000),
    ("claude-opus-4-7", 1_000_000),
    ("claude-sonnet-5", 1_000_000),
)
# Opus 4.6 / Sonnet 4.6 are deliberately NOT in the map: they reach 1M only
# through their "[1m]" variant, and a bare id is a 200k session. The tag is the
# signal — an id carrying it (any casing) is one the platform itself sizes at
# 1M, whatever the model. If a 1M session's transcript id arrives untagged it
# maps low (over-warn); those users keep CLAUDE_CONTEXT_BUDGET set.
TAG_1M = "[1m]"
TAGGED_WINDOW = 1_000_000

# The dangerous direction: the window belongs to the SESSION, not the model. A
# 1M-mapped id can be running at 200k, where a 1M budget never reaches WARN and
# the gauge stays silent through a real exhaustion. apply_platform_caps() closes
# the cases the environment reveals. The rest leave no env signal — a plan
# without 1M usage credits, a window set with `/autocompact` or the
# `autoCompactWindow` setting, a model pinned without "[1m]" on a third-party
# provider, and a 1M->200k fallback unless the transcript id changes with it.
# Those sessions must set CLAUDE_CODE_AUTO_COMPACT_WINDOW (which also fixes the
# session) or CLAUDE_CONTEXT_BUDGET.
DISABLED_1M_WINDOW = 200_000  # what CLAUDE_CODE_DISABLE_1M_CONTEXT holds a 1M model to
AUTO_COMPACT_MIN = 100_000  # the platform clamps its auto-compact window up to this


def _env_number(name):
    """A positive finite number from an env var, or None when unset or unreadable."""
    try:
        value = float(os.environ.get(name, ""))
    except ValueError:
        return None
    return value if 0 < value < float("inf") else None


def apply_platform_caps(budget):
    """Lower `budget` to the ceiling Claude Code's own env vars imply.

    Never raises it. Each var is read the way the platform documents reading it
    (model-config + env-vars docs, 2026-10), erring toward "capped" wherever the
    two could differ — that is the over-warn direction:
      * the 1M switch counts as on for any value but an explicit off (a
        superset of the platform's 1/true/yes/on);
      * the declared window lowers the budget even for ids where the platform
        would ignore it;
      * the auto-compact window takes its leading integer ("500k" reads as
        500) clamped up to the 100k minimum;
      * the percent override moves the compaction point below the window, so
        the bands scale down with it.
    """
    off = ("", "0", "false", "no", "off")
    if os.environ.get("CLAUDE_CODE_DISABLE_1M_CONTEXT", "").strip().lower() not in off:
        budget = min(budget, DISABLED_1M_WINDOW)
    declared = _env_number("CLAUDE_CODE_MAX_CONTEXT_TOKENS")
    if declared:
        budget = min(budget, int(declared))
    window = re.match(r"\s*([+-]?\d+)", os.environ.get("CLAUDE_CODE_AUTO_COMPACT_WINDOW", ""))
    if window:
        budget = min(budget, max(int(window.group(1)), AUTO_COMPACT_MIN))
    percent = _env_number("CLAUDE_AUTOCOMPACT_PCT_OVERRIDE")
    if percent:
        budget = int(budget * min(percent, 100) / 100)
    return budget


def latest_context_tokens(path):
    """(prompt tokens, model id) of the most recent MAIN-thread assistant turn.

    The token figure (new input + cached input) is what was actually fed to the
    model on its last call, so it is the best available proxy for current window
    use; the model id from the same line feeds the MODEL_BUDGETS lookup.
    Sidechain (subagent) turns are skipped — they don't sit in the main window.
    """
    try:
        with open(path, "r") as f:
            lines = f.readlines()
    except OSError:
        return None, None
    for line in reversed(lines):
        line = line.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except json.JSONDecodeError:
            continue
        if obj.get("isSidechain"):
            continue
        if obj.get("type") != "assistant":
            continue
        message = obj.get("message") or {}
        usage = message.get("usage")
        if not usage:
            continue
        tokens = (
            usage.get("input_tokens", 0)
            + usage.get("cache_read_input_tokens", 0)
            + usage.get("cache_creation_input_tokens", 0)
        )
        return tokens, message.get("model")
    return None, None


def _state_path(session_id):
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", session_id) or "default"
    return os.path.join(STATE_DIR, safe)


def read_state(session_id):
    try:
        with open(_state_path(session_id)) as f:
            d = json.load(f)
            return int(d.get("user_band", 0)), int(d.get("model_band", 0))
    except (OSError, ValueError, json.JSONDecodeError):
        return 0, 0


def write_state(session_id, user_band, model_band):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(_state_path(session_id), "w") as f:
            json.dump({"user_band": user_band, "model_band": model_band}, f)
    except OSError:
        pass


def build_message(band, used, budget, pct):
    head = f"CONTEXT HEALTH — {used:,}/{budget:,} tokens (~{pct * 100:.0f}% of the window)."
    if band == 1:
        body = (
            "Context is getting heavy. Finish the current task; at the NEXT natural "
            "checkpoint consider `/context-health` to decide compact vs hand off. "
            "No action needed mid-task."
        )
    elif band == 2:
        body = (
            "Externalize before you lose signal. Run `/context-health` at the next "
            "boundary — it proposes compact vs hand off and ASKS before doing either. "
            "(If the next step is discussing what was built, not building more, just "
            "continue — the detail is the material.)"
        )
    else:
        body = (
            "Stop accumulating context. Run `/context-health` now — it externalizes via "
            "`/handoff` (or commit via `/ship`), confirms a cold pickup, then clears with "
            "your OK. Reliability degrades sharply past this point (context rot)."
        )
    return head + " " + body


def main():
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except json.JSONDecodeError:
        return

    event = data.get("hook_event_name", "")
    transcript = data.get("transcript_path")
    session_id = data.get("session_id", "default")
    if not transcript or not os.path.exists(transcript):
        return

    try:
        warn = float(os.environ.get("CTX_WARN", "0.70"))
        act = float(os.environ.get("CTX_ACT", "0.85"))
        crit = float(os.environ.get("CTX_CRIT", "0.95"))
    except ValueError:
        return

    used, model = latest_context_tokens(transcript)
    if used is None:
        return

    # Budget: env var always wins; else size the transcript's model id (a
    # "[1m]" tag or the map; unknown/missing id -> conservative 200k default),
    # then let the platform's own window caps lower it — never raise it.
    env_budget = os.environ.get("CLAUDE_CONTEXT_BUDGET")
    if env_budget:
        try:
            budget = int(env_budget)
        except ValueError:
            return
    else:
        budget = DEFAULT_BUDGET
        if model and TAG_1M in model.lower():
            budget = TAGGED_WINDOW
        else:
            for prefix, window in MODEL_BUDGETS:
                if model and model.startswith(prefix):
                    budget = window
                    break
        budget = apply_platform_caps(budget)
    if budget <= 0:
        return

    pct = used / budget
    band = 3 if pct >= crit else 2 if pct >= act else 1 if pct >= warn else 0

    user_band, model_band = read_state(session_id)
    # Re-arm both channels when occupancy drops (clamp stored bands down to now).
    user_band = min(user_band, band)
    model_band = min(model_band, band)

    notify_user = band > 0 and band > user_band
    # Only UserPromptSubmit can put text in front of the model without forcing
    # the agent to keep working, so model injection is gated to that event.
    inject_model = event == "UserPromptSubmit" and band > 0 and band > model_band

    out = {}
    if inject_model:
        out["hookSpecificOutput"] = {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": build_message(band, used, budget, pct),
        }
        model_band = band
    if notify_user:
        out["systemMessage"] = (
            f"[context-health] ~{pct * 100:.0f}% of {budget // 1000}k tokens used "
            f"— {BAND_NAME[band]}."
        )
        user_band = band

    write_state(session_id, user_band, model_band)
    if out:
        print(json.dumps(out))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        # A health check must never break the user's prompt. Fail silent.
        pass
    sys.exit(0)
