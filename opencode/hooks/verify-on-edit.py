#!/usr/bin/env python3
"""
verify-on-edit hook (PostToolUse) — Tier-1 verification, per edit.

After the agent edits a file, run the FAST, file-local checks that are installed
for that file's language and feed any diagnostics straight back to the agent
(exit 2 -> stderr is shown to Claude), so it fixes them before moving on. This is
the external-feedback loop the research says dominates coding-agent quality
(SWE-agent's linter-on-edit; "LLMs can't self-correct without external feedback").

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
import shutil
import subprocess
import sys

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


def main():
    data = json.loads(sys.stdin.read() or "{}")
    if data.get("tool_name") not in EDIT_TOOLS:
        return
    ti = data.get("tool_input") or {}
    path = ti.get("file_path") or ti.get("notebook_path") or ti.get("path")
    if not path or not os.path.isfile(path):
        return

    findings = []
    for label, argv in build_checks(path):
        diag = run_check(label, argv)
        if diag:
            findings.append(f"── {label} ──\n{diag}")

    if not findings:
        return

    report = "\n".join(findings)
    if len(report) > TOTAL_CAP:
        report = report[:TOTAL_CAP] + "\n… (truncated)"
    sys.stderr.write(
        "Verification found issues in the file you just edited "
        f"({os.path.basename(path)}). Fix these before continuing:\n\n"
        + report
        + "\n"
    )
    sys.exit(2)  # PostToolUse: exit 2 feeds stderr back to the agent


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass  # never block an edit because the verifier itself errored
    sys.exit(0)
