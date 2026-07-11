#!/usr/bin/env python3
"""
done-gate hook (Stop) — Tier-1 verification, at task completion.

When the agent tries to finish, run the project's fast check command. If it fails,
BLOCK the stop and hand the failures back so the agent fixes them before claiming
done — closing the "I think I'm done" gap with an objective signal (Self-Debug,
AlphaCodium, Reflexion: iterate against a real verifier).

This is where the PROJECT-WIDE checks live (type-check, clippy, unit tests) —
things that need the whole project to resolve, unlike the per-file verify-on-edit.

Opt-in per project (so it never runs a heavy suite by surprise). It runs iff:
  * env CLAUDE_VERIFY_CMD is set, OR
  * a `.claude/verify.sh` exists in the project (cwd).
Keep that command FAST (seconds, not minutes) — it runs every time the agent stops.

Verifier-integrity guard (anti-tamper):
  "Green means green" only holds if the verifier itself didn't change under us —
  and agents have been observed weakening tests/verifiers to get green (EvilGenie,
  SpecBench). So the first invocation that resolves a verifier records its SHA-256
  in per-session state; later invocations re-hash. On a change it always tells the
  user (systemMessage), and when the run is green it blocks ONCE with the diff so
  the agent surfaces the change for confirmation or reverts it — then re-baselines
  so it can never loop. A red run just gets a tamper note on the normal red block
  (no re-baseline: reverting to the accepted verifier goes green silently).

Safety:
  * `stop_hook_active` guard: never block twice in a row (no infinite loop).
  * time-boxed; on timeout it fails OPEN (lets the agent stop) with a note.
  * fails open on any internal error; the tamper guard never reverts anything.
"""
import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

TIMEOUT = 180        # seconds for the whole verify command
REASON_CAP = 5000    # chars of failure output handed back
CONTENT_CAP = 20000  # bytes of verifier text kept in state for diffing
DIFF_CAP = 1500      # chars of verifier diff shown in a tamper block

# Per-session baseline of the resolved verifier — ephemeral, in the OS temp dir
# so it works no matter how the plugin is installed (same pattern as
# context-health's state dir).
STATE_DIR = os.path.join(tempfile.gettempdir(), "claude-done-gate-state")


def resolve_verifier(cwd):
    """The verifier to run -> (cmd, identity, content_bytes) or (None,)*3.

    `identity` names the source (env cmd vs verify.sh path) so switching sources
    counts as a change; `content_bytes` is what gets hashed (the literal command
    string, or the script's bytes; None if the script can't be read).
    """
    cmd = os.environ.get("CLAUDE_VERIFY_CMD")
    if cmd:
        return cmd, "env:CLAUDE_VERIFY_CMD", cmd.encode()
    script = os.path.join(cwd, ".claude", "verify.sh")
    if os.path.isfile(script):
        try:
            with open(script, "rb") as f:
                content = f.read()
        except OSError:
            content = None
        return f'bash "{script}"', "file:" + os.path.abspath(script), content
    return None, None, None


def _state_path(session_id):
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", session_id) or "default"
    return os.path.join(STATE_DIR, safe)


def read_baseline(session_id):
    try:
        with open(_state_path(session_id)) as f:
            d = json.load(f)
        if isinstance(d, dict) and "identity" in d and "hash" in d:
            return d
    except (OSError, ValueError, json.JSONDecodeError):
        pass
    return None


def write_baseline(session_id, identity, digest, text):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(_state_path(session_id), "w") as f:
            json.dump({"identity": identity, "hash": digest, "text": text}, f)
    except OSError:
        pass


def describe_change(base, identity, digest, text):
    """One human-readable account of how the verifier differs from baseline."""
    if base["identity"] != identity:
        return f"verifier source changed: {base['identity']} -> {identity}"
    old_text = base.get("text")
    if old_text is not None and text is not None:
        diff = "\n".join(difflib.unified_diff(
            old_text.splitlines(), text.splitlines(),
            fromfile="verifier (session baseline)", tofile="verifier (now)",
            lineterm="",
        ))
        if len(diff) > DIFF_CAP:
            diff = diff[:DIFF_CAP] + "\n... (diff truncated)"
        if diff:
            return "verifier content changed:\n" + diff
    return (f"verifier content changed "
            f"(sha256 {base['hash'][:12]}... -> {digest[:12]}...)")


def main():
    data = json.loads(sys.stdin.read() or "{}")

    # Don't re-block if we're already inside a stop-hook-triggered continuation.
    if data.get("stop_hook_active"):
        return
    cwd = data.get("cwd") or os.getcwd()
    session_id = data.get("session_id", "default")

    cmd, identity, content = resolve_verifier(cwd)
    if not cmd:
        return  # project hasn't opted in

    # Integrity check: has the verifier changed since this session baselined it?
    # Any internal error here must fail open — the guard is advisory scaffolding.
    tamper = None
    digest = text = None
    if content is not None:
        try:
            digest = hashlib.sha256(content).hexdigest()
            if len(content) <= CONTENT_CAP:
                text = content.decode("utf-8", errors="replace")
            base = read_baseline(session_id)
            if base is None:
                write_baseline(session_id, identity, digest, text)
            elif base["identity"] != identity or base["hash"] != digest:
                tamper = describe_change(base, identity, digest, text)
        except Exception:
            tamper = None

    try:
        r = subprocess.run(
            cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT
        )
    except subprocess.TimeoutExpired:
        msg = (f"[done-gate] verify command timed out after {TIMEOUT}s "
               "— not blocking. Consider a faster check.")
        if tamper:
            msg += " NOTE: the verifier changed during this session."
        print(json.dumps({"systemMessage": msg}))
        return
    except Exception:
        return  # can't run it → fail open

    if r.returncode == 0:
        if not tamper:
            return  # green — let the agent stop
        # Green but the verifier changed: surface it, block exactly once, then
        # re-baseline so a repeat stop passes (never a wall, never a loop).
        write_baseline(session_id, identity, digest, text)
        print(json.dumps({
            "decision": "block",
            "reason": "The verifier itself CHANGED during this session, so this "
                      "green result can't be taken at face value.\n\n"
                      f"{tamper}\n\n"
                      "If the user asked for this change, tell them the verifier "
                      "was altered and stop again — this gate blocks at most once "
                      "per change. Otherwise, revert the verifier change and "
                      "re-run.",
            "systemMessage": "[done-gate] verifier changed during this session "
                             "— review the change before trusting green.",
        }))
        return

    out = ((r.stdout or "") + (r.stderr or "")).strip() or f"verify exited {r.returncode}"
    if len(out) > REASON_CAP:
        out = out[-REASON_CAP:]  # tail: the failing summary is usually at the end
    reason = ("Project verification is failing — resolve it before finishing "
              f"(command: {cmd}):\n\n{out}\n\nFix these, then stop.")
    block = {"decision": "block", "reason": reason}
    if tamper:
        # No re-baseline on red: reverting to the accepted verifier should go
        # green silently, while a further-weakened one still earns its block.
        block["reason"] += ("\n\nNOTE: the verifier itself changed during this "
                            f"session:\n{tamper}")
        block["systemMessage"] = ("[done-gate] verifier changed during this "
                                  "session — review the change.")
    print(json.dumps(block))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never trap the agent because the gate itself errored
    sys.exit(0)
