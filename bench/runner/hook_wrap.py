#!/usr/bin/env python3
"""Telemetry wrapper for a bench arm's hooks: append one JSONL record per
invocation, then run the real hook transparently. Passes stdin through, mirrors
the hook's stdout, stderr, AND exit code (verify-on-edit blocks via exit 2;
done-gate blocks via a JSON `decision`), so wrapping never changes behavior.
Fails open — a wrapper error must never trap the agent.

Usage (as a hook command in a sandbox settings.json):
    hook_wrap.py <telemetry_jsonl> <real_hook.py>
"""
import json
import os
import subprocess
import sys
import time


def main():
    log_path, target = sys.argv[1], sys.argv[2]
    data = sys.stdin.read()
    rec = {"ts": time.time(), "hook": os.path.basename(target)}
    try:
        d = json.loads(data or "{}")
        rec["session_id"] = d.get("session_id")
        rec["stop_hook_active"] = d.get("stop_hook_active")
    except Exception:
        pass

    r = subprocess.run(
        [sys.executable, target], input=data, capture_output=True, text=True
    )
    out, err = r.stdout or "", r.stderr or ""

    decision = None
    if out.strip():
        try:
            decision = json.loads(out).get("decision")
        except Exception:
            pass
    rec["exit"] = r.returncode
    rec["decision"] = decision
    rec["blocked"] = (r.returncode == 2) or (decision == "block")

    try:
        os.makedirs(os.path.dirname(log_path), exist_ok=True)
        with open(log_path, "a") as f:
            f.write(json.dumps(rec) + "\n")
    except OSError:
        pass

    sys.stdout.write(out)
    sys.stderr.write(err)
    sys.exit(r.returncode)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(0)  # fail open
