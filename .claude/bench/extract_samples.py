#!/usr/bin/env python3
"""Sample real final-assistant messages from the Claude Code transcripts.

Input for bakeoff.py. Selection: non-sidechain `type:"assistant"` lines whose content is
text only — the messages you actually read at the end of a turn, as opposed to mid-flight
tool narration — round-robined across sessions so one chatty project can't dominate.

  python3 .claude/bench/extract_samples.py [N] [out.json]
"""
import glob
import json
import os
import random
import sys

ROOT = os.path.expanduser("~/.claude/projects")
MIN_CHARS, MAX_CHARS = 800, 9000
N = int(sys.argv[1]) if len(sys.argv) > 1 else 20
OUT = sys.argv[2] if len(sys.argv) > 2 else "samples.json"

by_session = {}
for p in sorted(glob.glob(f"{ROOT}/*/*.jsonl"), key=os.path.getmtime, reverse=True)[:60]:
    project = os.path.basename(os.path.dirname(p))
    try:
        lines = open(p, encoding="utf-8").read().splitlines()
    except OSError:
        continue
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            o = json.loads(line)
        except json.JSONDecodeError:
            continue
        if o.get("type") != "assistant" or o.get("isSidechain"):
            continue
        blocks = (o.get("message") or {}).get("content")
        if not isinstance(blocks, list):
            continue
        if {b.get("type") for b in blocks if isinstance(b, dict)} != {"text"}:
            continue
        text = "".join(b.get("text", "") for b in blocks if isinstance(b, dict))
        if MIN_CHARS <= len(text) <= MAX_CHARS:
            by_session.setdefault(p, []).append(
                {"project": project, "chars": len(text), "text": text})

random.seed(11)                                   # reproducible sample
pools = [random.sample(v, len(v)) for v in by_session.values()]
random.shuffle(pools)
picked, i = [], 0
while len(picked) < N and any(pools) and i < 5000:
    pool = pools[i % len(pools)]
    if pool:
        picked.append(pool.pop())
    i += 1

picked.sort(key=lambda s: s["chars"])
json.dump(picked, open(OUT, "w"), indent=1)
lens = [s["chars"] for s in picked]
print(f"{len(picked)} samples from {len(by_session)} sessions / "
      f"{len({s['project'] for s in picked})} projects")
if lens:
    print(f"length: min {min(lens)}  median {lens[len(lens)//2]}  max {max(lens)}")
