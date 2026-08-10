#!/usr/bin/env python3
"""Stop hook: render the agent's last message as a plain-English triage panel.

Personal maintainer tooling — NOT part of the tether plugin and never shipped to
tether users. It reads the transcript the same way context-health.py does, hands the
last assistant message to a local model, and writes the result to a file you tail in
a second pane. Nothing is ever sent back to the agent.

Three properties this is built around, in order:

  1. It never touches the model's context. No additionalContext, ever. The whole
     point is a side-channel for the human; injecting anything would change the
     output we're trying to read unmodified.
  2. It never costs the turn any time. Local inference is ~18s median / ~28s p90
     (measured, qwen3:8b). The hook forks a detached worker and exits in
     milliseconds; the pane fills in a beat later.
  3. It fails open and silent. Ollama down, model missing, disk full — the hook
     still exits 0 with empty stdout. A broken side-channel must never wedge a
     session.

Config (all optional):
  PLAIN_DISABLE=1     turn it off entirely
  PLAIN_MODEL         default qwen3:8b — thinking ON; see the bake-off, disabling
                      thinking is 2.8x faster and misses 36% of asks
  PLAIN_MIN_CHARS     default 1200 — shorter replies don't need triaging
  PLAIN_NUM_CTX       default 16384 — MUST exceed prompt+message or Ollama silently
                      truncates the input and summarises only the first part
  PLAIN_TIMEOUT       default 150 seconds
  PLAIN_DIR           default ~/.claude/plain
  PLAIN_OLLAMA_URL    default http://127.0.0.1:11434/api/chat
"""
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request

MODEL = os.environ.get("PLAIN_MODEL", "qwen3:8b")
MIN_CHARS = int(os.environ.get("PLAIN_MIN_CHARS", "1200"))
NUM_CTX = int(os.environ.get("PLAIN_NUM_CTX", "16384"))
TIMEOUT = float(os.environ.get("PLAIN_TIMEOUT", "150"))
OUT_DIR = os.environ.get("PLAIN_DIR", os.path.expanduser("~/.claude/plain"))
OLLAMA = os.environ.get("PLAIN_OLLAMA_URL", "http://127.0.0.1:11434/api/chat")
STATE_DIR = os.path.join(tempfile.gettempdir(), "claude-plain-english-state")

PROMPT = """You are a translator, not an assistant. You will be given the last message a
coding agent sent to its user. The user owns the project and is technically
expert, but the message is long and they need to know, fast, what it means
for them.

Rewrite it under exactly these headings. Under 150 words total.

BOTTOM LINE
One sentence: what actually happened, or what the answer is.

NEEDS YOU
Anything the agent asked, offered, or is blocked on. Quote questions
verbatim. If there is nothing, write "Nothing — FYI only."

WHAT CHANGED
Bullets. Files, commands, decisions. Skip anything that didn't change state.

WATCH OUT
Caveats, risks, uncertainty, or things the agent said it did NOT do.
Omit this heading entirely if there are none.

Rules:
- Never add information that is not in the message. Give no advice of your own.
- Never soften or drop a caveat, a failure, or an admission of uncertainty.
  Those are the highest-value parts of the message.
- Preserve exact identifiers: filenames, commands, flags, numbers, error text.
- If you are unsure what a passage means, quote it rather than paraphrase it.
- Plain sentences. No jargon the message didn't already use."""


def last_assistant_text(path):
    """(text, uuid) of the most recent MAIN-thread assistant turn that is pure text.

    Turns carrying tool_use are mid-flight narration, not the message the human reads
    at the end of a turn — skipping them is what keeps the panel one-per-response.
    Sidechain (subagent) turns never belong to the main conversation.
    """
    try:
        with open(path, "r", encoding="utf-8") as f:
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
        if obj.get("isSidechain") or obj.get("type") != "assistant":
            continue
        blocks = (obj.get("message") or {}).get("content")
        if not isinstance(blocks, list) or not blocks:
            continue
        kinds = {b.get("type") for b in blocks if isinstance(b, dict)}
        if kinds != {"text"}:
            return None, None           # last turn was tool use — nothing to render yet
        text = "".join(b.get("text", "") for b in blocks if isinstance(b, dict))
        return text, obj.get("uuid") or hashlib.sha256(text.encode()).hexdigest()[:16]
    return None, None


def already_done(session, uid):
    """Stop can fire repeatedly for one message; render each message at most once."""
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        p = os.path.join(STATE_DIR, f"{session}.last")
        if os.path.exists(p) and open(p, encoding="utf-8").read().strip() == uid:
            return True
        with open(p, "w", encoding="utf-8") as f:
            f.write(uid)
    except OSError:
        pass                            # state unavailable → render anyway, never block
    return False


def worker(session, text):
    """Detached: call the model, append the panel. Any failure is written, not raised."""
    stamp = time.strftime("%H:%M:%S")
    body = json.dumps({
        "model": MODEL, "stream": False,
        "options": {"num_ctx": NUM_CTX, "temperature": 0.2},
        "messages": [{"role": "system", "content": PROMPT},
                     {"role": "user", "content": text}],
    }).encode()
    try:
        req = urllib.request.Request(
            OLLAMA, data=body, headers={"Content-Type": "application/json"})
        t0 = time.monotonic()
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            resp = json.loads(r.read())
        out = (resp.get("message") or {}).get("content", "").strip()
        secs = time.monotonic() - t0
        # thinking models emit <think>…</think>; it is reasoning, not the answer
        while "<think>" in out and "</think>" in out:
            out = (out[:out.index("<think>")] + out[out.index("</think>") + 8:]).strip()
        prompt_tokens = resp.get("prompt_eval_count", 0)
        note = ""
        # a truncated prompt produces a confident summary of only the first part —
        # the one failure that looks like success, so say it out loud
        if prompt_tokens and prompt_tokens >= NUM_CTX - 64:
            note = (f"\n\n> ⚠ input may have been truncated "
                    f"({prompt_tokens} prompt tokens vs num_ctx {NUM_CTX}) — "
                    f"raise PLAIN_NUM_CTX.")
        panel = (f"\n\n---\n\n### {stamp}  ·  {len(text)} chars → {len(out.split())} words  "
                 f"·  {secs:.0f}s  ·  {MODEL}\n\n{out}{note}\n")
    except Exception as e:                                    # noqa: BLE001 - fail loud in the pane, never to the agent
        panel = (f"\n\n---\n\n### {stamp}  ·  summariser unavailable\n\n"
                 f"`{type(e).__name__}: {e}`\n\n"
                 f"Original response was {len(text)} chars. Is `ollama serve` up, "
                 f"and is `{MODEL}` pulled?\n")
    try:
        os.makedirs(OUT_DIR, exist_ok=True)
        with open(os.path.join(OUT_DIR, f"{session}.md"), "a", encoding="utf-8") as f:
            f.write(panel)
    except OSError:
        pass


def main():
    if os.environ.get("PLAIN_DISABLE"):
        return
    if len(sys.argv) > 2 and sys.argv[1] == "--worker":
        worker(sys.argv[2], sys.stdin.read())
        return
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, ValueError):
        return
    if not isinstance(data, dict) or data.get("stop_hook_active"):
        return
    path = data.get("transcript_path")
    session = str(data.get("session_id") or "session").replace("/", "_")[:64]
    if not path:
        return
    text, uid = last_assistant_text(path)
    if not text or len(text) < MIN_CHARS or already_done(session, uid):
        return
    try:
        # detached: the turn must not wait on ~18s of local inference
        p = subprocess.Popen(
            [sys.executable, os.path.abspath(__file__), "--worker", session],
            stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True)
        assert p.stdin is not None      # PIPE was requested
        p.stdin.write(text.encode())
        p.stdin.close()
    except Exception:                                          # noqa: BLE001 - never block the stop
        pass


if __name__ == "__main__":
    try:
        main()
    except Exception:                                          # noqa: BLE001 - a side-channel must never wedge a session
        pass
    sys.stdout.write("")                # explicitly nothing: no additionalContext, ever
    sys.exit(0)
