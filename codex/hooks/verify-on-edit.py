#!/usr/bin/env python3
"""
verify-on-edit hook (PostToolUse) — Tier-1 verification, per edit.

After the agent edits a file, run the FAST, file-local checks that are installed
for that file's language and feed any diagnostics straight back to the agent
(JSON {"decision":"block","reason":...} on stdout — Codex's documented PostToolUse
feedback channel), so it fixes them before moving on. This is the external-feedback
loop the research says dominates coding-agent quality (SWE-agent's linter-on-edit;
"LLMs can't self-correct without external feedback").

Codex edits files with `apply_patch`: its tool_input is {"command": "<V4A patch>"},
so the edited paths live INSIDE the patch text ("*** Add/Update/Delete File: <path>",
relative to cwd) rather than a structured field. We parse those out, and still honor
the structured file_path/path keys that other edit tools use.

Scope on purpose:
  * Only FAST, file-local, low-false-positive checks live here: formatters in
    --check mode + ruff lint + shellcheck. These don't need the whole project and
    rarely false-positive on a single file.
  * Heavy / project-wide checks (type-checkers, clippy, tests) belong in the Stop
    'done-gate' hook, where project imports resolve — NOT here, where a lone file
    would produce spurious "cannot find module" noise.
  * check-only: never rewrites the file (that would desync the agent's edits).
  * Any tool that isn't installed is silently skipped (partial toolchains are fine).
  * Per-tool timeout; a hook must never hang the session. Fails open on error.
"""
import json
import os
import re
import shutil
import subprocess
import sys

# V4A apply_patch headers that name a file, e.g. "*** Update File: src/a.py".
# Add/Update/Delete + the "Move to:" rename target all name a path.
_PATCH_FILE_RE = re.compile(r"^\*\*\*\s+(?:Add|Update|Delete)\s+File:\s*(.+?)\s*$", re.M)
_PATCH_MOVE_RE = re.compile(r"^\*\*\*\s+Move\s+to:\s*(.+?)\s*$", re.M)

TIMEOUT = 20          # seconds per tool
PER_TOOL_CAP = 1500   # chars of output kept per tool
TOTAL_CAP = 5000      # chars of combined output

EDIT_TOOLS = {"Edit", "Write", "NotebookEdit", "apply_patch"}  # apply_patch = Codex's edit tool

C_FAMILY = {".c", ".cc", ".cpp", ".cxx", ".c++", ".h", ".hpp", ".hh",
            ".hxx", ".ipp", ".cu", ".cuh", ".m", ".mm"}


def _find_up(path, names):
    """True if any of `names` exists in the file's directory or an ancestor
    (stopping at a repo root / filesystem root). Used to detect whether a
    project has OPTED IN to machine formatting for its language."""
    d = os.path.dirname(os.path.abspath(path))
    while True:
        if any(os.path.exists(os.path.join(d, n)) for n in names):
            return True
        if os.path.isdir(os.path.join(d, ".git")):
            return False
        parent = os.path.dirname(d)
        if parent == d:
            return False
        d = parent


def build_checks(path):
    """Return [(label, argv), ...] for installed fast checks matching this file."""
    ext = os.path.splitext(path)[1].lower()
    base = os.path.basename(path)
    checks = []

    def add(tool, args, label):
        if shutil.which(tool):
            checks.append((label, [tool] + args))
            return True
        return False

    if ext in (".py", ".pyi"):
        # Real-bug lint always; impose FORMATTING/style only when the project
        # opts in with a ruff/pyproject config — otherwise we'd churn
        # hand-formatted code (same reasoning as the C/C++ note below).
        if _find_up(path, ("pyproject.toml", "ruff.toml", ".ruff.toml")):
            add("ruff", ["check", "--quiet", path], "ruff")           # respect their config
            add("ruff", ["format", "--check", "--quiet", path], "ruff-format")
        else:
            add("ruff", ["check", "--quiet", "--select", "E9,F", path], "ruff")
    elif ext in C_FAMILY:
        # clang-format has no universal style; run it only when the project ships
        # a .clang-format (opt-in), else we'd flag every hand-formatted file on
        # every edit. (A project can use `DisableFormat: true` to opt out.)
        if _find_up(path, (".clang-format", "_clang-format")):
            add("clang-format", ["--dry-run", "--Werror", path], "clang-format")
    elif ext == ".rs":
        add("rustfmt", ["--edition", "2021", "--check", path], "rustfmt")
    elif base == "CMakeLists.txt" or ext == ".cmake":
        if not add("gersemi", ["--check", path], "gersemi"):
            add("cmake-format", ["--check", path], "cmake-format")
    elif ext in (".sh", ".bash"):
        add("shellcheck", [path], "shellcheck")

    return checks


def run_check(label, argv):
    """Run one check; return diagnostic text if it failed, else None."""
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return f"({label} timed out after {TIMEOUT}s — skipped)"
    except Exception:
        return None  # tool blew up; don't punish the edit for our problem
    if r.returncode == 0:
        return None
    out = (r.stdout or "") + (r.stderr or "")
    out = out.strip() or f"{label} exited {r.returncode} (no output)"
    if len(out) > PER_TOOL_CAP:
        out = out[:PER_TOOL_CAP] + "\n… (truncated)"
    return out


def extract_paths(data):
    """Every file this edit touched, as existing absolute paths.

    Handles both Codex's apply_patch (paths embedded in the V4A patch text under
    tool_input.command, relative to cwd) and the structured edit tools that pass
    file_path/notebook_path/path. Deleted files and paths that don't resolve to a
    real file are dropped (nothing to lint)."""
    ti = data.get("tool_input") or {}
    cwd = data.get("cwd") or os.getcwd()
    candidates = []

    # structured edit tools (Edit/Write/NotebookEdit, or a future Codex that
    # keys a path directly)
    for key in ("file_path", "notebook_path", "path"):
        v = ti.get(key)
        if isinstance(v, str) and v:
            candidates.append(v)

    # apply_patch: pull paths out of the V4A patch text
    cmd = ti.get("command")
    if isinstance(cmd, str):
        candidates += _PATCH_FILE_RE.findall(cmd)
        candidates += _PATCH_MOVE_RE.findall(cmd)

    out, seen = [], set()
    for p in candidates:
        ap = os.path.normpath(p if os.path.isabs(p) else os.path.join(cwd, p))
        if ap not in seen and os.path.isfile(ap):
            seen.add(ap)
            out.append(ap)
    return out


def main():
    data = json.loads(sys.stdin.read() or "{}")
    if data.get("tool_name") not in EDIT_TOOLS:
        return

    findings = []
    for path in extract_paths(data):
        for label, argv in build_checks(path):
            diag = run_check(label, argv)
            if diag:
                findings.append(f"── {os.path.basename(path)}: {label} ──\n{diag}")

    if not findings:
        return

    report = "\n".join(findings)
    if len(report) > TOTAL_CAP:
        report = report[:TOTAL_CAP] + "\n… (truncated)"
    # Codex PostToolUse: decision=block surfaces `reason` to the model and makes it
    # address the issue before continuing (schema-guaranteed; more robust than exit-2).
    print(json.dumps({
        "decision": "block",
        "reason": "Verification found issues in the file(s) you just edited. "
                  "Fix these before continuing:\n\n" + report,
    }))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never block an edit because the verifier itself errored
    sys.exit(0)
