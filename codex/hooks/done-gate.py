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

Safety:
  * `stop_hook_active` guard: never block twice in a row (no infinite loop).
  * time-boxed; on timeout it fails OPEN (lets the agent stop) with a note.
  * fails open on any internal error.
"""
import json
import os
import subprocess
import sys

TIMEOUT = 180        # seconds for the whole verify command
REASON_CAP = 5000    # chars of failure output handed back


def find_verify_command(cwd):
    cmd = os.environ.get("VERIFY_CMD") or os.environ.get("CLAUDE_VERIFY_CMD")
    if cmd:
        return cmd
    for rel in (".tether/verify.sh", ".codex/verify.sh", ".claude/verify.sh"):
        script = os.path.join(cwd, rel)
        if os.path.isfile(script):
            return f'bash "{script}"'
    return None


def main():
    data = json.loads(sys.stdin.read() or "{}")

    # Don't re-block if we're already inside a stop-hook-triggered continuation.
    if data.get("stop_hook_active"):
        return
    cwd = data.get("cwd") or os.getcwd()

    cmd = find_verify_command(cwd)
    if not cmd:
        return  # project hasn't opted in

    try:
        r = subprocess.run(
            cmd, shell=True, cwd=cwd, capture_output=True, text=True, timeout=TIMEOUT
        )
    except subprocess.TimeoutExpired:
        # fail open (don't trap the agent on a slow check), but say why.
        print(json.dumps({
            "systemMessage": f"[done-gate] verify command timed out after {TIMEOUT}s "
                             "— not blocking. Consider a faster check.",
        }))
        return
    except Exception:
        return  # can't run it → fail open

    if r.returncode == 0:
        return  # green — let the agent stop

    out = ((r.stdout or "") + (r.stderr or "")).strip() or f"verify exited {r.returncode}"
    if len(out) > REASON_CAP:
        out = out[-REASON_CAP:]  # tail: the failing summary is usually at the end
    # Codex Stop: decision=block tells Codex to continue with a new prompt carrying
    # `reason`, so the agent fixes the failures instead of finishing. Schema-backed
    # (same output shape as the Claude Code edition), more robust than exit-2/stderr.
    print(json.dumps({
        "decision": "block",
        "reason": "Project verification is failing — resolve it before finishing "
                  f"(command: {cmd}):\n\n{out}\n\nFix these, then stop.",
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never trap the agent because the gate itself errored
    sys.exit(0)
