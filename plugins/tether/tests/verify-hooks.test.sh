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
out=$(printf '{"hook_event_name":"Stop","cwd":"%s"}' "$FIX" | CLAUDE_VERIFY_CMD="false" python3 "$DG" 2>&1)
check "failing verify blocks the stop"     "$out" contains '"decision": "block"'

out=$(printf '{"hook_event_name":"Stop","cwd":"%s"}' "$FIX" | CLAUDE_VERIFY_CMD="true" python3 "$DG" 2>&1)
check "passing verify lets it stop"        "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","stop_hook_active":true,"cwd":"%s"}' "$FIX" | CLAUDE_VERIFY_CMD="false" python3 "$DG" 2>&1)
check "stop_hook_active guard prevents loop" "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","cwd":"%s"}' "$FIX" | python3 "$DG" 2>&1)
check "no opt-in -> gate is silent"        "$out" empty ""

mkdir -p "$FIX/.claude"
printf '#!/usr/bin/env bash\necho fail >&2\nexit 1\n' > "$FIX/.claude/verify.sh"
out=$(printf '{"hook_event_name":"Stop","cwd":"%s"}' "$FIX" | python3 "$DG" 2>&1)
check ".claude/verify.sh failure blocks"   "$out" contains '"decision": "block"'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
