#!/usr/bin/env python3
"""
done-gate hook (Stop) — Tier-1 verification, at task completion.

When the agent tries to finish, run the project's fast check command. If it fails,
exit 2 and hand the failures back so the agent fixes them before claiming done —
closing the "I think I'm done" gap with an objective signal (Self-Debug,
AlphaCodium, Reflexion: iterate against a real verifier). On Claude Code / Codex
exit-2 blocks the stop; on opencode the plugin surfaces the failure on
`session.idle` but cannot hard-block (it reports).

This is where the PROJECT-WIDE checks live (type-check, clippy, unit tests) —
things that need the whole project to resolve, unlike the per-file verify-on-edit.

Opt-in per project (so it never runs a heavy suite by surprise). It runs iff:
  * env VERIFY_CMD or CLAUDE_VERIFY_CMD is set, OR
  * a `.tether/`, `.codex/`, or `.claude/verify.sh` exists — searched from the
    given cwd UP to the repo root, so it still fires after a subdirectory edit.
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
    # Walk up from cwd toward the project root so a root-level verify.sh still fires
    # after an edit in a subdirectory (opencode passes the edited file's dir as cwd).
    # Bounded to the git repo — stop at the dir containing .git — so we never escape
    # into $HOME and pick up an unrelated verify.sh.
    d = os.path.abspath(cwd)
    while True:
        for rel in (".tether/verify.sh", ".codex/verify.sh", ".claude/verify.sh"):
            script = os.path.join(d, rel)
            if os.path.isfile(script):
                return f'bash "{script}"'
        if os.path.isdir(os.path.join(d, ".git")):
            break  # reached the repo root; don't search past it
        parent = os.path.dirname(d)
        if parent == d:
            break  # filesystem root
        d = parent
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
        return  # timed out → fail open (don't block finishing on a slow check)
    except Exception:
        return  # can't run it → fail open

    if r.returncode == 0:
        return  # green — let the agent stop

    out = ((r.stdout or "") + (r.stderr or "")).strip() or f"verify exited {r.returncode}"
    if len(out) > REASON_CAP:
        out = out[-REASON_CAP:]  # tail: the failing summary is usually at the end
    sys.stderr.write(
        "Project verification is failing — resolve it before finishing "
        f"(command: {cmd}):\n\n{out}\n\nFix these, then finish.\n"
    )
    sys.exit(2)  # exit 2 = block-and-feed-back; portable across Codex & Claude Code


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never trap the agent because the gate itself errored
    sys.exit(0)
