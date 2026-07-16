#!/usr/bin/env python3
"""P1-raw probe hook: a Stop hook that BLOCKS unconditionally.

Purpose: measure the *raw* ceiling of headless `claude -p` under a blocking Stop
hook. It deliberately does NOT honor `stop_hook_active` — the question is whether
the CLI itself enforces a single block or keeps re-inviting the agent for as long
as the hook keeps blocking. A self-cap (PROBE_MAX_BLOCKS) guarantees termination so
the probe can never burn unbounded quota: once the cap is reached it allows the stop.

This is a measurement instrument, not part of the tether treatment. The real
done-gate (probed separately by P1-real) DOES honor `stop_hook_active`.

Env:
  PROBE_COUNTER    path to the block-count file (default: ./.probe_blockcount)
  PROBE_MAX_BLOCKS integer self-cap (default: 6)
"""
import json
import os
import sys

MAX_BLOCKS = int(os.environ.get("PROBE_MAX_BLOCKS", "6"))
COUNTER = os.environ.get(
    "PROBE_COUNTER", os.path.join(os.getcwd(), ".probe_blockcount")
)


def read_count():
    try:
        with open(COUNTER) as f:
            return int(f.read().strip() or "0")
    except (OSError, ValueError):
        return 0


def main():
    try:
        json.loads(sys.stdin.read() or "{}")
    except Exception:
        pass
    n = read_count()
    if n >= MAX_BLOCKS:
        return  # self-cap reached: allow the stop so the probe terminates
    try:
        with open(COUNTER, "w") as f:
            f.write(str(n + 1))
    except OSError:
        pass
    print(json.dumps({
        "decision": "block",
        "reason": f"[probe] blocking stop #{n + 1} (self-caps at {MAX_BLOCKS}). "
                  "Do a small amount of work, then try to finish again.",
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
