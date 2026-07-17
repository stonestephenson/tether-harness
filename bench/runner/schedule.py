#!/usr/bin/env python3
"""Deterministic run-schedule generator (DESIGN.md 'Run schedule, drift, and
failure disposition').

A *group* is one (block, model, task, rep) tuple; its cells are the arms tested on
it. Groups are shuffled with a seed — this interleaves the blocks and spreads
serving drift across the schedule — while the arms WITHIN a group stay contiguous
in the output, so each paired comparison runs temporally local (drift can't
confound an arm contrast). Pure function of (blocks, seed): reproducible, and the
seed is pre-registered.

    block = {"name": str, "model": str, "arms": [str], "tasks": [str], "reps": int}
    cell  = {"run": int, "group": int, "block": str, "model": str,
             "task": str, "rep": int, "arm": str}
"""
import argparse
import json
import random


def build_groups(blocks):
    groups = []
    for b in blocks:
        for task in b["tasks"]:
            for rep in range(1, b["reps"] + 1):
                groups.append([
                    {"block": b["name"], "model": b["model"],
                     "task": task, "rep": rep, "arm": arm}
                    for arm in b["arms"]
                ])
    return groups


def order_schedule(blocks, seed):
    rng = random.Random(seed)
    groups = build_groups(blocks)
    rng.shuffle(groups)                 # interleave blocks; spread drift
    schedule = []
    for gi, cells in enumerate(groups):
        cs = cells[:]
        rng.shuffle(cs)                 # randomize arm order within the group
        for c in cs:
            c["group"] = gi
            c["run"] = len(schedule)
            schedule.append(c)
    return schedule


def summarize(schedule):
    from collections import Counter
    by_block = Counter(c["block"] for c in schedule)
    by_arm = Counter(c["arm"] for c in schedule)
    return {"total_runs": len(schedule),
            "groups": 1 + max((c["group"] for c in schedule), default=-1),
            "by_block": dict(by_block), "by_arm": dict(by_arm)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("blocks_json", help="path to a JSON list of block dicts")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--out", help="write the full schedule as JSON here")
    args = ap.parse_args()
    with open(args.blocks_json) as f:
        blocks = json.load(f)
    schedule = order_schedule(blocks, args.seed)
    if args.out:
        with open(args.out, "w") as f:
            json.dump(schedule, f, indent=2)
    print(json.dumps(summarize(schedule), indent=2))


if __name__ == "__main__":
    main()
