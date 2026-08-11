#!/usr/bin/env python3
"""Score candidate local models for the plain-english hook.

Run this before changing PLAIN_MODEL. The 2026-08-10 round found that ranking on speed
inverts the ranking on usefulness — the fastest model missed the ask in 73% of samples —
so "it felt quicker" is not evidence. The metric that decides it is ask-detection.

  python3 .claude/bench/extract_samples.py 20 samples.json
  python3 .claude/bench/bakeoff.py qwen3:8b,gemma3:12b,llama3.1:8b

Append ":think0" to a spec to disable thinking for that run (e.g. qwen3:8b:think0).
The prompt is imported from the hook so there is exactly one copy of it.
"""
import importlib.util
import json
import os
import re
import statistics as st
import sys
import time
import urllib.request

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hooks",
                    "plain-english.py")
_spec = importlib.util.spec_from_file_location("plain_english", HOOK)
if _spec is None or _spec.loader is None:
    sys.exit(f"cannot import the hook at {HOOK}")
_mod = importlib.util.module_from_spec(_spec)
sys.modules["plain_english"] = _mod
_spec.loader.exec_module(_mod)
PROMPT = _mod.PROMPT                                  # single source of truth

OLLAMA = os.environ.get("PLAIN_OLLAMA_URL", "http://127.0.0.1:11434/api/chat")
NUM_CTX = int(os.environ.get("PLAIN_NUM_CTX", "16384"))
SAMPLES = json.load(open(sys.argv[2] if len(sys.argv) > 2 else "samples.json",
                         encoding="utf-8"))

# An original that poses a question, against a summary that claims none — the false
# negative that makes the tool worse than nothing, since it lands on the one field
# you'd rely on.
ASK = re.compile(r"\?|tell me if|let me know|say the word|want me to|shall i|would you|"
                 r"your call|if you'd rather|confirm|which (one|option)", re.I)
NONE = re.compile(r"nothing\s*[—\-–]\s*fyi|nothing needed|no action", re.I)
HEDGES = re.compile(
    r"\b(caveat|however|but |note that|did not|didn'?t|not yet|unverified|assum\w+|"
    r"risk|fail\w*|unless|pending|blocked|uncertain|might|may |should probably|"
    r"wrong|error|gap|missing|untested|pre-existing)\b", re.I)
HEADS = ("BOTTOM LINE", "NEEDS YOU", "WHAT CHANGED")


def call(model, text, think):
    body = {"model": model, "stream": False,
            "options": {"num_ctx": NUM_CTX, "temperature": 0.2},
            "messages": [{"role": "system", "content": PROMPT},
                         {"role": "user", "content": text}]}
    if not think:
        body["think"] = False
    req = urllib.request.Request(OLLAMA, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=300) as r:
        o = json.loads(r.read())
    return o["message"]["content"], time.monotonic() - t0, o.get("prompt_eval_count", 0)


rows, detail = [], []
for spec in sys.argv[1].split(","):
    think = not spec.endswith(":think0")
    model = spec.replace(":think0", "")
    secs, words, missed, asks, hedge_ok, hedge_n, fmt, trunc = [], [], 0, 0, 0, 0, 0, 0
    print(f"\n{spec}", flush=True)
    for i, s in enumerate(SAMPLES, 1):
        try:
            out, dt, ptok = call(model, s["text"], think)
        except Exception as e:                                        # noqa: BLE001
            print(f"  {i:2d} ERROR {type(e).__name__}: {e}", flush=True)
            continue
        body = re.sub(r"<think>.*?</think>", "", out, flags=re.S)
        secs.append(dt)
        words.append(len(body.split()))
        fmt += all(h in out for h in HEADS)
        trunc += ptok >= NUM_CTX - 64          # silent truncation would fake a good score
        if ASK.search(s["text"]):
            asks += 1
            missed += bool(NONE.search(out))
        if HEDGES.search(s["text"]):
            hedge_n += 1
            hedge_ok += bool(HEDGES.search(body))
        detail.append({"model": spec, "idx": i, "secs": round(dt, 1),
                       "words": len(body.split()), "out": body.strip(), "src": s["text"]})
        print(f"  {i:2d} {dt:5.1f}s {len(body.split()):3d}w  ptok {ptok:5d}", flush=True)
    if not secs:
        continue
    rows.append((spec, st.median(secs), sorted(secs)[int(len(secs) * .9) - 1],
                 st.median(words), missed, asks, hedge_ok, hedge_n, fmt, len(secs), trunc))

print("\n| config | med s | p90 s | words | ask missed | hedges kept | format | truncated |")
print("|---|--:|--:|--:|--:|--:|--:|--:|")
for (spec, med, p90, w, miss, asks, hk, hn, fmt, n, trunc) in rows:
    print(f"| `{spec}` | {med:.1f} | {p90:.1f} | {w:.0f} | "
          f"{miss}/{asks} ({100*miss//max(asks,1)}%) | {hk}/{hn} | {fmt}/{n} | {trunc} |")
json.dump(detail, open("results.json", "w"), indent=1)
print("\nwrote results.json — read the summaries before trusting the table; "
      "the scorer proves the ask survived, not that the summary is good.")
