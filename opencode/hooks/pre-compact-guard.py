#!/usr/bin/env python3
"""
pre-compact-guard hook (experimental.session.compacting) — invariant #1, adapted.

"Externalize state BEFORE compacting" was enforced only by convention (the
context-health skill asks nicely). Compaction is lossy: if the working tree is
dirty and un-externalized, a compact can silently strand work the summary won't
preserve.

The opencode contract is the INVERSE of Claude Code's PreCompact (verified
against the 1.17.15 plugin typedefs): the `experimental.session.compacting` hook
fires before compaction and can INJECT context strings into the compaction
prompt, but it has no block channel and no manual/auto trigger field. So where
the Claude Code edition blocks a manual compact once, this edition:
  * stdout → a summarizer-directed context block (the plugin appends it to the
    compaction prompt): list the dirty files and instruct the summary to
    preserve that un-externalized state verbatim, so the work survives the
    compaction it can't prevent;
  * stderr → a short user-facing warning (surfaced via console.error) pointing
    at /ship, /handoff, or /context-health.
No once-per-compaction state machinery is needed — nothing blocks, so there is
no override path; the hook fires once per compaction by construction.

Fail open everywhere: not a git repo, git missing/slow, bad stdin, any internal
error → stay silent and let the compaction proceed untouched. Exit 2 signals
"dirty, advisory emitted"; 0 is silent.
"""
import json
import os
import subprocess
import sys

GIT_TIMEOUT = 10   # seconds for git status
FILES_SHOWN = 20   # dirty files listed in the advisory


def dirty_files(cwd):
    """Porcelain status lines, or None when the answer is 'stay silent'."""
    try:
        r = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=cwd, capture_output=True, text=True, timeout=GIT_TIMEOUT,
        )
    except Exception:
        return None  # git missing, timeout, bad cwd → fail open
    if r.returncode != 0:
        return None  # not a git repo → fail open
    lines = [ln for ln in (r.stdout or "").splitlines() if ln.strip()]
    return lines or None


def main():
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except (json.JSONDecodeError, UnicodeDecodeError):
        return 0

    cwd = data.get("cwd") or os.getcwd()

    files = dirty_files(cwd)
    if files is None:
        return 0  # clean (or unknowable) → silent

    shown = "\n".join("  " + ln for ln in files[:FILES_SHOWN])
    more = len(files) - FILES_SHOWN
    if more > 0:
        shown += f"\n  … and {more} more"

    # stdout: appended to the compaction prompt — talk to the summarizer.
    sys.stdout.write(
        "IMPORTANT — un-externalized work in flight: the git working tree has "
        f"{len(files)} uncommitted change(s):\n{shown}\n"
        "Preserve in the summary the exact state of this work — which files "
        "are modified and why, what remains to be done to finish and commit "
        "them — and remind the user to externalize (/ship to commit, /handoff "
        "to write state down) as the next step.\n"
    )
    # stderr: surfaced to the user — say what just happened and what to do.
    sys.stderr.write(
        "[pre-compact-guard] Compacting with un-externalized changes "
        f"({len(files)} file(s)) — opencode cannot block a compaction, so the "
        "dirty-tree state was injected into the compaction prompt instead. "
        "Externalize soon: /ship (commit), /handoff (write state down), or "
        "/context-health (decide).\n"
    )
    return 2


if __name__ == "__main__":
    try:
        rc = main()
    except Exception:
        rc = 0  # the guard must never wedge a compaction it can't reason about
    sys.exit(rc)
