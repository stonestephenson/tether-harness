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

Verifier-integrity guard (anti-tamper):
  "Green means green" only holds if the verifier itself didn't change under us —
  and agents have been observed weakening tests/verifiers to get green (EvilGenie,
  SpecBench). The first invocation that resolves a verifier records its SHA-256 in
  per-session state; later invocations re-hash. On a change with a GREEN run it
  reports ONCE (exit 2 + the verifier diff on stderr — on opencode this surfaces
  to the user, it cannot block the agent) and then re-baselines so it never nags
  twice for the same change. A RED run just gets a tamper note on the normal red
  report (no re-baseline: reverting to the accepted verifier goes green silently).

Safety:
  * `stop_hook_active` guard: never block twice in a row (no infinite loop).
  * time-boxed; on timeout it fails OPEN (lets the agent stop) — silently on
    opencode: stderr only surfaces on a non-zero exit, and a slow check must not
    earn an error report every idle.
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
DIFF_CAP = 1500      # chars of verifier diff shown in a tamper report

# Per-session baseline of the resolved verifier — ephemeral, in the OS temp dir
# so it works no matter where the hooks are installed (not tied to
# ~/.config/opencode). The plugin passes session_id from the session.idle event.
STATE_DIR = os.path.join(tempfile.gettempdir(), "opencode-done-gate-state")


def resolve_verifier(cwd):
    """The verifier to run -> (cmd, identity, content_bytes) or (None,)*3.

    `identity` names the source (env cmd vs script path) so switching sources
    counts as a change; `content_bytes` is what gets hashed (the literal command
    string, or the script's bytes; None if the script can't be read).
    """
    for var in ("VERIFY_CMD", "CLAUDE_VERIFY_CMD"):
        cmd = os.environ.get(var)
        if cmd:
            return cmd, f"env:{var}", cmd.encode()
    # Walk up from cwd toward the project root so a root-level verify.sh still fires
    # after an edit in a subdirectory (opencode passes the edited file's dir as cwd).
    # Bounded to the git repo — stop at the dir containing .git — so we never escape
    # into $HOME and pick up an unrelated verify.sh.
    d = os.path.abspath(cwd)
    while True:
        for rel in (".tether/verify.sh", ".codex/verify.sh", ".claude/verify.sh"):
            script = os.path.join(d, rel)
            if os.path.isfile(script):
                try:
                    with open(script, "rb") as f:
                        content = f.read()
                except OSError:
                    content = None
                return f'bash "{script}"', "file:" + os.path.abspath(script), content
        if os.path.isdir(os.path.join(d, ".git")):
            break  # reached the repo root; don't search past it
        parent = os.path.dirname(d)
        if parent == d:
            break  # filesystem root
        d = parent
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
        return  # timed out → fail open (don't block finishing on a slow check)
    except Exception:
        return  # can't run it → fail open

    if r.returncode == 0:
        if not tamper:
            return  # green — let the agent stop
        # Green but the verifier changed: report it exactly once, then
        # re-baseline so the next idle is silent (never a nag loop).
        write_baseline(session_id, identity, digest, text)
        sys.stderr.write(
            "[done-gate] The verifier itself CHANGED during this session, so "
            "this green result can't be taken at face value.\n\n"
            f"{tamper}\n\n"
            "If this change was asked for, ignore this note — it is reported "
            "at most once per change. Otherwise, review and revert the "
            "verifier change.\n"
        )
        sys.exit(2)

    out = ((r.stdout or "") + (r.stderr or "")).strip() or f"verify exited {r.returncode}"
    if len(out) > REASON_CAP:
        out = out[-REASON_CAP:]  # tail: the failing summary is usually at the end
    report = (
        "Project verification is failing — resolve it before finishing "
        f"(command: {cmd}):\n\n{out}\n\nFix these, then finish.\n"
    )
    if tamper:
        # No re-baseline on red: reverting to the accepted verifier should go
        # green silently, while a further-weakened one still earns its report.
        report += ("\nNOTE: the verifier itself changed during this "
                   f"session:\n{tamper}\n")
    sys.stderr.write(report)
    sys.exit(2)  # exit 2 = block-and-feed-back; portable across Codex & Claude Code


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never trap the agent because the gate itself errored
    sys.exit(0)
