#!/usr/bin/env python3
"""
pre-compact-guard hook (PreCompact) — invariant #1, mechanized. Codex edition.

"Externalize state BEFORE compacting" was enforced only by convention (the
context-health skill asks nicely). Compaction is lossy: if the working tree is
dirty and un-externalized, a compact can silently strand work the summary won't
preserve. This hook blocks a MANUAL compact exactly once while the git tree is
dirty, pointing at ship / handoff / context-health — re-running compact
overrides (per-session flag), so it's one block, never a wall.

Codex contract delta (vs the Claude Code edition): PreCompact blocks via JSON
`{"continue": false, "stopReason": ...}` on stdout — exit 2 is NOT a documented
blocking mechanism for this event in Codex. Payload carries `trigger`
("manual"/"auto"), `session_id`, and `cwd`, same as Claude Code.

Scope, deliberately narrow (v1):
  * "un-externalized" = inside a git repo AND `git status --porcelain` non-empty
    (staged, unstaged, or untracked — a never-committed file is exactly the
    strandable work this protects).
  * MANUAL compaction only. Auto-compaction (the window is full; blocking would
    wedge the session) never blocks — at most a user-visible systemMessage.
    If the `trigger` field is absent at runtime, treat it as auto: never block.

Fail open everywhere: not a git repo, git missing/slow, bad stdin, any internal
error → allow the compaction.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

GIT_TIMEOUT = 10   # seconds for git status
FILES_SHOWN = 20   # dirty files listed in the block message

STATE_DIR = os.path.join(tempfile.gettempdir(), "codex-pre-compact-guard-state")


def _state_path(session_id):
    safe = re.sub(r"[^A-Za-z0-9._-]", "_", session_id) or "default"
    return os.path.join(STATE_DIR, safe)


def override_armed(session_id):
    try:
        return os.path.isfile(_state_path(session_id))
    except OSError:
        return False


def arm_override(session_id):
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(_state_path(session_id), "w") as f:
            f.write("blocked-once")
    except OSError:
        pass


def clear_override(session_id):
    try:
        os.remove(_state_path(session_id))
    except OSError:
        pass


def dirty_files(cwd):
    """Porcelain status lines, or None when the answer is 'don't block'."""
    try:
        r = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=cwd, capture_output=True, text=True, timeout=GIT_TIMEOUT,
        )
    except Exception:
        return None  # git missing, timeout, bad cwd → fail open
    if r.returncode != 0:
        return None  # not a git repo → fail open
    lines = [ln for ln in (r.stdout or "").splitlines() if ln.strip()]
    return lines or None


def main():
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return

    # Only a MANUAL compact may block. Absent/unknown trigger → treat as auto.
    trigger = data.get("trigger")
    cwd = data.get("cwd") or os.getcwd()
    session_id = data.get("session_id", "default")

    files = dirty_files(cwd)

    if trigger != "manual":
        if trigger == "auto" and files:
            print(json.dumps({
                "systemMessage": "[pre-compact-guard] auto-compaction with "
                                 f"{len(files)} uncommitted change(s) — the summary "
                                 "won't preserve them; externalize soon (ship or "
                                 "handoff).",
            }))
        return

    if files is None:
        clear_override(session_id)  # clean (or unknowable) → allow, re-arm
        return

    if override_armed(session_id):
        # Second consecutive manual attempt: honor the override, then re-arm the
        # guard so a LATER compact in this session gets fresh protection.
        clear_override(session_id)
        return

    arm_override(session_id)
    shown = "\n".join("  " + ln for ln in files[:FILES_SHOWN])
    more = len(files) - FILES_SHOWN
    if more > 0:
        shown += f"\n  … and {more} more"
    print(json.dumps({
        "continue": False,
        "stopReason": "[pre-compact-guard] Manual compaction is lossy and the "
                      "working tree has un-externalized changes "
                      f"({len(files)} file(s)):\n{shown}\n\n"
                      "Externalize first — ship (commit), handoff (write state "
                      "down), or context-health (decide) — or re-run compact to "
                      "override this block.",
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # the guard must never wedge a compaction it can't reason about
    sys.exit(0)
