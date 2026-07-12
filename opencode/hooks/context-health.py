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
                          MODEL_BUDGETS below (unknown ids -> 200k fallback).
  CTX_WARN / CTX_ACT / CTX_CRIT   band fractions     (default .70/.85/.95)
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
# Known model-id prefixes -> context window (verified against the models docs,
# 2026-07: the current Fable/Opus/Sonnet generation is natively 1M; Haiku 4.5
# and older models are 200k). Prefix match tolerates date-suffixed ids.
# Unknown ids fall back to DEFAULT_BUDGET — the safe direction (over-warn).
# Caveat: 200k-default models running the 1M beta (a settings suffix like
# "[1m]" that never appears in the transcript model id) map low — those users
# must keep CLAUDE_CONTEXT_BUDGET set; it always wins.
MODEL_BUDGETS = (
    ("claude-fable-5", 1_000_000),
    ("claude-mythos-5", 1_000_000),
    ("claude-opus-4-8", 1_000_000),
    ("claude-opus-4-7", 1_000_000),
    ("claude-opus-4-6", 1_000_000),
    ("claude-sonnet-5", 1_000_000),
    ("claude-sonnet-4-6", 1_000_000),
)


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

    # Budget: env var always wins; else map the transcript's model id;
    # unknown/missing id -> conservative 200k default.
    env_budget = os.environ.get("CLAUDE_CONTEXT_BUDGET")
    if env_budget:
        try:
            budget = int(env_budget)
        except ValueError:
            return
    else:
        budget = DEFAULT_BUDGET
        for prefix, window in MODEL_BUDGETS:
            if model and model.startswith(prefix):
                budget = window
                break
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
