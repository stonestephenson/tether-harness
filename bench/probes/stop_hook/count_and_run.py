#!/usr/bin/env python3
"""P1-real probe wrapper: count how many times the REAL done-gate is invoked and
how many times it BLOCKS, without altering its behavior.

Usage (as the Stop hook command):
    count_and_run.py <target_hook.py> <counter_dir>

Reads the Stop event on stdin, feeds it to the target hook unchanged (so the
target sees the real `stop_hook_active`, `cwd`, `session_id`), passes the target's
stdout through verbatim, and bumps counters `invocations` and `blocks` in
<counter_dir>. Fails open — never blocks the agent on its own.
"""
import json
import os
import subprocess
import sys


def bump(path):
    try:
        n = 0
        if os.path.isfile(path):
            with open(path) as f:
                n = int(f.read().strip() or "0")
        with open(path, "w") as f:
            f.write(str(n + 1))
    except (OSError, ValueError):
        pass


def main():
    target, counter_dir = sys.argv[1], sys.argv[2]
    os.makedirs(counter_dir, exist_ok=True)
    data = sys.stdin.read()
    bump(os.path.join(counter_dir, "invocations"))
    r = subprocess.run(
        [sys.executable, target], input=data, capture_output=True, text=True
    )
    out = r.stdout or ""
    try:
        if '"decision"' in out and json.loads(out).get("decision") == "block":
            bump(os.path.join(counter_dir, "blocks"))
    except Exception:
        pass
    sys.stdout.write(out)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
