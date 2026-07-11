#!/usr/bin/env bash
# Regression test for verify-on-edit.py and done-gate.py.
# Run:  bash tests/verify-hooks.test.sh   (from the plugin root)
# Uses only rustfmt (assumed present); skips the Rust checks if it's missing.

VOE="$(cd "$(dirname "$0")/../hooks" && pwd)/verify-on-edit.py"
DG="$(cd "$(dirname "$0")/../hooks" && pwd)/done-gate.py"
FIX="$(mktemp -d)"
pass=0; fail=0
trap 'rm -rf "$FIX"' EXIT

check() { # desc  actual  mode(contains|absent|empty)  expected
  local desc="$1" actual="$2" mode="$3" expected="$4" ok=0
  case "$mode" in
    contains) [[ "$actual" == *"$expected"* ]] && ok=1 ;;
    absent)   [[ "$actual" != *"$expected"* ]] && ok=1 ;;
    empty)    [[ -z "$actual" ]] && ok=1 ;;
  esac
  if [[ $ok -eq 1 ]]; then printf 'PASS  %s\n' "$desc"; pass=$((pass+1))
  else printf 'FAIL  %s\n      got: %s\n' "$desc" "${actual:-<empty>}"; fail=$((fail+1)); fi
}

# ---- verify-on-edit ----
if command -v rustfmt >/dev/null 2>&1; then
  printf 'fn main(){let x=1;println!("{}",x);}\n' > "$FIX/bad.rs"
  printf 'fn main() {\n    let x = 1;\n    println!("{}", x);\n}\n' > "$FIX/good.rs"

  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FIX/bad.rs" | python3 "$VOE" 2>&1); rc=$?
  check "unformatted .rs is reported"      "$out" contains "rustfmt"
  check "unformatted .rs exits 2 (feedback)" "$rc"  contains "2"

  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$FIX/good.rs" | python3 "$VOE" 2>&1)
  check "formatted .rs is silent"          "$out" empty ""
else
  echo "SKIP  rustfmt not installed — skipping Rust verify checks"
fi

out=$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | python3 "$VOE" 2>&1)
check "non-edit tool is ignored"           "$out" empty ""

# unsupported extension -> always silent (no checker configured for it)
printf 'hello\n' > "$FIX/note.md"
out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/note.md" | python3 "$VOE" 2>&1)
check "unsupported extension is silent"    "$out" empty ""

# C/C++: format-check is OPT-IN (only when a .clang-format is present).
if command -v clang-format >/dev/null 2>&1; then
  mkdir -p "$FIX/cpp_optin"; printf 'BasedOnStyle: LLVM\n' > "$FIX/cpp_optin/.clang-format"
  printf 'int main(){return 0;}\n' > "$FIX/cpp_optin/x.cpp"
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/cpp_optin/x.cpp" | python3 "$VOE" 2>&1)
  check "unformatted .cpp reported WHEN .clang-format present" "$out" contains "clang-format"

  mkdir -p "$FIX/cpp_noopt"; printf 'int main(){return 0;}\n' > "$FIX/cpp_noopt/y.cpp"
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/cpp_noopt/y.cpp" | python3 "$VOE" 2>&1)
  check "C++ NOT checked without .clang-format (opt-in)"       "$out" empty ""

  mkdir -p "$FIX/cpp_disable"; printf 'DisableFormat: true\n' > "$FIX/cpp_disable/.clang-format"
  printf 'int main(){return 0;}\n' > "$FIX/cpp_disable/z.cpp"
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/cpp_disable/z.cpp" | python3 "$VOE" 2>&1)
  check "DisableFormat keeps clang-format silent"              "$out" empty ""
else
  echo "SKIP  clang-format not installed — skipping C/C++ checks"
fi

# Python: real-bug lint always; style/format is opt-in (ruff/pyproject config).
if command -v ruff >/dev/null 2>&1; then
  mkdir -p "$FIX/py_noopt"
  printf 'import os\n' > "$FIX/py_noopt/bad.py"                       # F401 unused import (real bug)
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/py_noopt/bad.py" | python3 "$VOE" 2>&1)
  check "python real-bug (F401) reported without config"       "$out" contains "ruff"

  printf 'import os, sys\nprint(os.getcwd(), sys.argv)\n' > "$FIX/py_noopt/style.py"  # E401 only, both used
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$FIX/py_noopt/style.py" | python3 "$VOE" 2>&1)
  check "python style-only (E401) NOT reported without config" "$out" empty ""
else
  echo "SKIP  ruff not installed — skipping Python checks"
fi

out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"/no/such.rs"}}' | python3 "$VOE" 2>&1)
check "missing file is silent"             "$out" empty ""

out=$(printf 'garbage' | python3 "$VOE" 2>&1); rc=$?
check "garbage stdin is silent"            "$out" empty ""
check "garbage stdin exits 0"              "$rc"  contains "0"

# ---- done-gate ----
# Every invocation gets a unique dgt_* session_id and TMPDIR="$FIX" so the
# anti-tamper per-session state is isolated per test and cleaned up with $FIX.
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_red","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" CLAUDE_VERIFY_CMD="false" python3 "$DG" 2>&1)
check "failing verify blocks the stop"     "$out" contains '"decision": "block"'

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_green","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" CLAUDE_VERIFY_CMD="true" python3 "$DG" 2>&1)
check "passing verify lets it stop"        "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_loop","stop_hook_active":true,"cwd":"%s"}' "$FIX" | TMPDIR="$FIX" CLAUDE_VERIFY_CMD="false" python3 "$DG" 2>&1)
check "stop_hook_active guard prevents loop" "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_noopt","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check "no opt-in -> gate is silent"        "$out" empty ""

mkdir -p "$FIX/.claude"
printf '#!/usr/bin/env bash\necho fail >&2\nexit 1\n' > "$FIX/.claude/verify.sh"
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_file","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check ".claude/verify.sh failure blocks"   "$out" contains '"decision": "block"'

# ---- done-gate: verifier-integrity guard (anti-tamper) ----
TDIR="$FIX/tamper"; mkdir -p "$TDIR/.claude"
DG_STATE="$FIX/claude-done-gate-state"
dg() { # session  cwd  [extra-json]  — invoke done-gate with isolated state
  local sess="$1" cwd="$2" extra="${3:-}"
  printf '{"hook_event_name":"Stop","session_id":"%s","cwd":"%s"%s}' "$sess" "$cwd" "$extra" \
    | TMPDIR="$FIX" python3 "$DG" 2>&1
}

printf '#!/usr/bin/env bash\nexit 0\n' > "$TDIR/.claude/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: first run baselines silently"          "$out" empty ""

out=$(dg dgt_t1 "$TDIR")
check "tamper: unchanged verifier + green stays silent" "$out" empty ""

printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.claude/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: changed + green blocks"                "$out" contains '"decision": "block"'
check "tamper: block reason names the change"         "$out" contains "verifier"
check "tamper: block shows the diff"                  "$out" contains "weakened"
check "tamper: user-visible systemMessage emitted"    "$out" contains "systemMessage"

out=$(dg dgt_t1 "$TDIR")
check "tamper: next attempt after block passes"       "$out" empty ""

printf '#!/usr/bin/env bash\necho broken >&2\nexit 1\n' > "$TDIR/.claude/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: changed + red still red-blocks"        "$out" contains "Project verification is failing"
check "tamper: red block carries a tamper note"       "$out" contains "changed during this session"

# no re-baseline on red: reverting to the last accepted verifier goes green silently
printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.claude/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: revert to baseline goes green silently" "$out" empty ""

# stop_hook_active guard beats the tamper block too
T3="$FIX/tamper3"; mkdir -p "$T3/.claude"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T3/.claude/verify.sh"
out=$(dg dgt_t3 "$T3")
printf '#!/usr/bin/env bash\n# changed\nexit 0\n' > "$T3/.claude/verify.sh"
out=$(dg dgt_t3 "$T3" ',"stop_hook_active":true')
check "tamper: stop_hook_active never tamper-blocks"  "$out" empty ""

# corrupt state file -> fail open (silently re-baselines)
T2="$FIX/tamper2"; mkdir -p "$T2/.claude"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T2/.claude/verify.sh"
out=$(dg dgt_t2 "$T2")
printf 'not json' > "$DG_STATE/dgt_t2"
out=$(dg dgt_t2 "$T2")
check "tamper: corrupt state fails open"              "$out" empty ""

# CLAUDE_VERIFY_CMD change is a verifier change too
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t4","cwd":"%s"}' "$T2" | TMPDIR="$FIX" CLAUDE_VERIFY_CMD="true" python3 "$DG" 2>&1)
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t4","cwd":"%s"}' "$T2" | TMPDIR="$FIX" CLAUDE_VERIFY_CMD="echo ok" python3 "$DG" 2>&1)
check "tamper: changed CLAUDE_VERIFY_CMD blocks"      "$out" contains '"decision": "block"'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
