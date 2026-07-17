#!/usr/bin/env python3
"""Hidden-verifier harness (DESIGN.md). Grade an agent's work on a task WITHOUT
the agent ever having seen the grader:

  1. fresh scrubbed checkout of ``<task>/repo`` (base; no `.git`),
  2. overlay ONLY the agent's source edits — a path allowlist (``source_globs``
     minus ``reset_paths``) means test files and test-config the agent touched
     stay at BASE, so a weakened visible test can't leak into the grade,
  3. drop in the held-out hidden tests,
  4. run the full suite (visible PASS_TO_PASS + hidden FAIL_TO_PASS),
  5. report per-suite + overall pass.

Usage: verify_hidden.py <task_dir> <agent_workdir> [--out result.json]
Exit 0 iff the overall hidden grade passes.
"""
import argparse
import fnmatch
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# unittest -v line, e.g.: "test_csv_basic (test_fields.TestFields.test_csv_basic) ... ok"
LINE = re.compile(r"^(test_\w+) \(([\w.]+)\) \.\.\. (ok|FAIL|ERROR|skipped)")


def _is_reset(rel, reset_paths):
    return any(rel == p.rstrip("/") or rel.startswith(p) for p in reset_paths)


def _overlay_sources(agent, fresh, globs, reset_paths):
    for root, _dirs, files in os.walk(agent):
        for fn in files:
            rel = os.path.relpath(os.path.join(root, fn), agent)
            if _is_reset(rel, reset_paths):
                continue
            if not any(fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(fn, g) for g in globs):
                continue
            dst = os.path.join(fresh, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(os.path.join(root, fn), dst)


def _run_suite(fresh):
    try:
        r = subprocess.run(
            [sys.executable, "-m", "unittest", "discover", "-s", "tests", "-t", ".", "-v"],
            cwd=fresh, capture_output=True, text=True, timeout=120,
        )
    except subprocess.TimeoutExpired:
        return False, {}, "TIMEOUT"
    per = {}
    for line in (r.stderr or "").splitlines():
        m = LINE.match(line.strip())
        if m:
            per[m.group(2)] = m.group(3)
    return r.returncode == 0, per, r.stderr


def verify(task_dir, agent_workdir):
    with open(os.path.join(task_dir, "task.json")) as f:
        man = json.load(f)
    base = os.path.join(task_dir, "repo")
    hidden = os.path.join(task_dir, man.get("hidden_dir", "hidden"))
    globs = man.get("source_globs", ["*.py"])
    reset = man.get("reset_paths", ["tests/"])

    tmp = tempfile.mkdtemp(prefix="tether-hv-")
    try:
        fresh = os.path.join(tmp, "x")
        shutil.copytree(base, fresh)  # base checkout (copytree omits any .git we don't ship)
        _overlay_sources(agent_workdir, fresh, globs, reset)
        for fn in os.listdir(hidden):
            if fn.endswith(".py"):
                shutil.copy2(os.path.join(hidden, fn), os.path.join(fresh, "tests", fn))
        ok, per, _log = _run_suite(fresh)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    vis = {k: v for k, v in per.items() if "test_hidden" not in k}
    hid = {k: v for k, v in per.items() if "test_hidden" in k}
    return {
        "task": man["id"],
        "overall_pass": ok,
        "visible_pass": bool(vis) and all(v == "ok" for v in vis.values()),
        "hidden_pass": bool(hid) and all(v == "ok" for v in hid.values()),
        "failures": sorted(k for k, v in per.items() if v in ("FAIL", "ERROR")),
        "per_test": per,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("task_dir")
    ap.add_argument("agent_workdir")
    ap.add_argument("--out")
    a = ap.parse_args()
    result = verify(a.task_dir, a.agent_workdir)
    text = json.dumps(result, indent=2)
    if a.out:
        with open(a.out, "w") as f:
            f.write(text)
    print(text)
    sys.exit(0 if result["overall_pass"] else 1)


if __name__ == "__main__":
    main()
