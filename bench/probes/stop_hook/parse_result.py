#!/usr/bin/env python3
"""Extract the fields DESIGN.md verification item #2 needs from a
`claude -p --output-format json` result. The point is to learn what subscription
headless runs actually expose, so it reports which fields are PRESENT vs absent.

Usage: parse_result.py [result.json]   (reads stdin if no path given)
"""
import json
import sys


def get(d, *path):
    for p in path:
        if not isinstance(d, dict):
            return None
        d = d.get(p)
    return d


def main():
    raw = (open(sys.argv[1]).read() if len(sys.argv) > 1 else sys.stdin.read()).strip()
    if not raw:
        print("EMPTY result — likely an auth failure or a crash before the first turn.")
        return
    try:
        d = json.loads(raw)
    except json.JSONDecodeError as e:
        print(f"NON-JSON result ({e}). First 300 chars:\n{raw[:300]}")
        return
    fields = {
        "subtype": d.get("subtype"),
        "is_error": d.get("is_error"),
        "num_turns": d.get("num_turns"),
        "duration_ms": d.get("duration_ms"),
        "duration_api_ms": d.get("duration_api_ms"),
        "total_cost_usd": d.get("total_cost_usd"),
        "session_id": d.get("session_id"),
        "model (result top-level)": d.get("model"),
        "usage.input_tokens": get(d, "usage", "input_tokens"),
        "usage.output_tokens": get(d, "usage", "output_tokens"),
        "usage.cache_read_input_tokens": get(d, "usage", "cache_read_input_tokens"),
        "usage.cache_creation_input_tokens": get(d, "usage", "cache_creation_input_tokens"),
    }
    print("=== result JSON field presence (verification item #2) ===")
    for k, v in fields.items():
        print(f"  {k}: {'—(absent)' if v is None else v}")
    mu = d.get("modelUsage") or d.get("model_usage")
    if isinstance(mu, dict):
        print("  modelUsage keys (served model ids):", list(mu.keys()))
    print("\nTop-level keys present:", sorted(d.keys()))


if __name__ == "__main__":
    main()
