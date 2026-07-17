#!/usr/bin/env python3
"""Provision a per-arm CLAUDE_CONFIG_DIR sandbox: write settings.json wiring the
arm's hook subset, each hook routed through hook_wrap.py (telemetry). Never
touches ~/.claude. One config dir per run (cheap; keeps runs isolated).

Arms (DESIGN.md 'Arms and models'):
  A0  vanilla (no hooks)          — control
  A1  verify-on-edit only         — E1 exploratory block
  A2  done-gate (+ tamper guard)  — H1
  A3  full tether hooks           — deployed-layer estimate
(A4 skills arm is cut from runs per DESIGN E2 — ETH context-file null cited.)

Usage:
    provision_arm.py <arm> <config_dir> <telemetry_jsonl> [--repo REPO]
"""
import json
import os
import sys

# arm -> list of (event, matcher|None, hook_script). Mirrors plugins/tether/hooks/hooks.json.
HOOKS = {
    "A0": [],
    "A1": [("PostToolUse", "Edit|Write|NotebookEdit", "verify-on-edit.py")],
    "A2": [("Stop", None, "done-gate.py")],
    "A3": [
        ("UserPromptSubmit", None, "context-health.py"),
        ("PostToolUse", "Edit|Write|NotebookEdit", "verify-on-edit.py"),
        ("Stop", None, "context-health.py"),
        ("Stop", None, "done-gate.py"),
        ("PreCompact", None, "pre-compact-guard.py"),
    ],
}


def build_settings(arm, repo, wrap, log):
    hooks_root = os.path.join(repo, "plugins", "tether", "hooks")
    events = {}
    for event, matcher, script in HOOKS[arm]:
        target = os.path.join(hooks_root, script)
        cmd = f'python3 "{wrap}" "{log}" "{target}"'
        entry = {"hooks": [{"type": "command", "command": cmd}]}
        if matcher:
            entry["matcher"] = matcher
        events.setdefault(event, []).append(entry)
    return {"hooks": events} if events else {}


def main():
    args = [a for a in sys.argv[1:] if a != "--repo"]
    if "--repo" in sys.argv:
        i = sys.argv.index("--repo")
        repo = sys.argv[i + 1]
        args = [a for a in args if a != repo]
    else:
        repo = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    if len(args) < 3:
        sys.exit("usage: provision_arm.py <arm> <config_dir> <telemetry_jsonl> [--repo REPO]")
    arm, config_dir, log = args[0], args[1], args[2]
    if arm not in HOOKS:
        sys.exit(f"unknown arm {arm!r}; known: {', '.join(sorted(HOOKS))}")

    wrap = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hook_wrap.py")
    for script in (s for _, _, s in HOOKS[arm]):
        p = os.path.join(repo, "plugins", "tether", "hooks", script)
        if not os.path.isfile(p):
            sys.exit(f"hook script missing: {p} (wrong --repo?)")

    os.makedirs(config_dir, exist_ok=True)
    settings = build_settings(arm, repo, wrap, log)
    with open(os.path.join(config_dir, "settings.json"), "w") as f:
        json.dump(settings, f, indent=2)
    n_events = len(settings.get("hooks", {}))
    n_hooks = sum(len(v) for v in settings.get("hooks", {}).values())
    print(f"provisioned {arm} -> {config_dir}/settings.json "
          f"({n_events} events, {n_hooks} hooks)")


if __name__ == "__main__":
    main()
