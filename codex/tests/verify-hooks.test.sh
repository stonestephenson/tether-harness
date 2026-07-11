#!/usr/bin/env bash
# Regression test for the Codex edition of verify-on-edit.py and done-gate.py.
# Run:  bash codex/tests/verify-hooks.test.sh   (from the repo root)
#
# Codex's hook contract is a near-clone of Claude Code's: JSON on stdin, and
# feedback via JSON on stdout ({"decision":"block","reason":...}). The one real
# Codex delta is the EDIT tool: Codex edits files with `apply_patch`, whose
# tool_input is {"command": "<V4A patch text>"} — the edited paths live INSIDE
# the patch ("*** Add/Update/Delete File: <path>"), not in a structured field.
# These tests drive the hooks with the REAL Codex payload shapes.

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

# ---- verify-on-edit: Codex apply_patch (paths embedded in the V4A patch) ----
if command -v ruff >/dev/null 2>&1; then
  mkdir -p "$FIX/proj"
  printf 'import os\n' > "$FIX/proj/bad.py"            # F401 unused import (real bug)
  printf 'print("ok")\n' > "$FIX/proj/good.py"

  # apply_patch Update with a RELATIVE path — must resolve against payload cwd.
  patch='*** Begin Patch\n*** Update File: bad.py\n@@\n+import os\n*** End Patch'
  out=$(printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"%s"}}' \
        "$FIX/proj" "$patch" | python3 "$VOE" 2>&1)
  check "apply_patch F401 is reported"              "$out" contains "ruff"
  check "apply_patch feedback uses decision:block"  "$out" contains '"decision": "block"'
  check "apply_patch reports the right file"        "$out" contains "bad.py"

  # A clean file added via apply_patch -> silent.
  patch='*** Begin Patch\n*** Add File: good.py\n+print(\"ok\")\n*** End Patch'
  out=$(printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"%s"}}' \
        "$FIX/proj" "$patch" | python3 "$VOE" 2>&1)
  check "clean apply_patch is silent"               "$out" empty ""

  # Delete File -> the file is already gone post-apply (PostToolUse fires after
  # the patch lands), so there's nothing on disk to lint -> silent.
  printf 'import os\n' > "$FIX/proj/gone.py"; rm -f "$FIX/proj/gone.py"
  patch='*** Begin Patch\n*** Delete File: gone.py\n*** End Patch'
  out=$(printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"%s"}}' \
        "$FIX/proj" "$patch" | python3 "$VOE" 2>&1)
  check "apply_patch Delete is silent"              "$out" empty ""

  # Structured edit tools (Edit/Write with file_path) must still work.
  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' \
        "$FIX/proj/bad.py" | python3 "$VOE" 2>&1)
  check "structured file_path still works"          "$out" contains "ruff"

  # Style-only issue without a ruff/pyproject config -> NOT reported (opt-in).
  printf 'import os, sys\nprint(os.getcwd(), sys.argv)\n' > "$FIX/proj/style.py"
  patch='*** Begin Patch\n*** Update File: style.py\n@@\n+x\n*** End Patch'
  out=$(printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"%s"}}' \
        "$FIX/proj" "$patch" | python3 "$VOE" 2>&1)
  check "python style-only (E401) NOT reported"     "$out" empty ""
else
  echo "SKIP  ruff not installed — skipping Python verify checks"
fi

# rustfmt path (structured tool) — proves the non-apply_patch route too.
if command -v rustfmt >/dev/null 2>&1; then
  printf 'fn main(){let x=1;println!("{}",x);}\n' > "$FIX/bad.rs"
  out=$(printf '{"tool_name":"apply_patch","cwd":"%s","tool_input":{"command":"*** Begin Patch\\n*** Add File: bad.rs\\n+x\\n*** End Patch"}}' \
        "$FIX" | python3 "$VOE" 2>&1)
  check "apply_patch .rs runs rustfmt"              "$out" contains "rustfmt"
else
  echo "SKIP  rustfmt not installed — skipping Rust verify check"
fi

out=$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | python3 "$VOE" 2>&1)
check "non-edit tool is ignored"                   "$out" empty ""

out=$(printf '{"tool_name":"apply_patch","cwd":"/tmp","tool_input":{"command":"*** Begin Patch\\n*** Update File: nope-does-not-exist.py\\n*** End Patch"}}' | python3 "$VOE" 2>&1)
check "apply_patch missing file is silent"         "$out" empty ""

out=$(printf 'garbage' | python3 "$VOE" 2>&1); rc=$?
check "garbage stdin is silent"                    "$out" empty ""
check "garbage stdin exits 0"                      "$rc"  contains "0"

# ---- done-gate (Stop) — JSON decision:block, the Codex-documented mechanism ----
# Every invocation gets a unique dgt_* session_id and TMPDIR="$FIX" so the
# anti-tamper per-session state is isolated per test and cleaned up with $FIX.
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_red","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="false" python3 "$DG" 2>&1)
check "failing verify blocks the stop"             "$out" contains '"decision": "block"'

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_green","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="true" python3 "$DG" 2>&1)
check "passing verify lets it stop"                "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_loop","stop_hook_active":true,"cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="false" python3 "$DG" 2>&1)
check "stop_hook_active guard prevents loop"       "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_noopt","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check "no opt-in -> gate is silent"                "$out" empty ""

mkdir -p "$FIX/.codex"
printf '#!/usr/bin/env bash\necho fail >&2\nexit 1\n' > "$FIX/.codex/verify.sh"
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_file","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check ".codex/verify.sh failure blocks"            "$out" contains '"decision": "block"'

# ---- done-gate: verifier-integrity guard (anti-tamper) ----
TDIR="$FIX/tamper"; mkdir -p "$TDIR/.codex"
DG_STATE="$FIX/codex-done-gate-state"
dg() { # session  cwd  [extra-json]
  local sess="$1" cwd="$2" extra="${3:-}"
  printf '{"hook_event_name":"Stop","session_id":"%s","cwd":"%s"%s}' "$sess" "$cwd" "$extra" \
    | TMPDIR="$FIX" python3 "$DG" 2>&1
}

printf '#!/usr/bin/env bash\nexit 0\n' > "$TDIR/.codex/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: first run baselines silently"          "$out" empty ""

out=$(dg dgt_t1 "$TDIR")
check "tamper: unchanged verifier + green stays silent" "$out" empty ""

printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.codex/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: changed + green blocks once"           "$out" contains '"decision": "block"'
check "tamper: block shows the diff"                  "$out" contains "weakened"
check "tamper: user-visible systemMessage emitted"    "$out" contains "systemMessage"

out=$(dg dgt_t1 "$TDIR")
check "tamper: next attempt after block passes"       "$out" empty ""

printf '#!/usr/bin/env bash\necho broken >&2\nexit 1\n' > "$TDIR/.codex/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: changed + red still red-blocks"        "$out" contains "Project verification is failing"
check "tamper: red block carries a tamper note"       "$out" contains "changed during this session"

printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.codex/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: revert to baseline goes green silently" "$out" empty ""

out=$(dg dgt_t2 "$TDIR")
printf 'not json' > "$DG_STATE/dgt_t2"
out=$(dg dgt_t2 "$TDIR")
check "tamper: corrupt state fails open"              "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t3","cwd":"%s"}' "$TDIR" | TMPDIR="$FIX" VERIFY_CMD="true" python3 "$DG" 2>&1)
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t3","cwd":"%s"}' "$TDIR" | TMPDIR="$FIX" VERIFY_CMD="echo ok" python3 "$DG" 2>&1)
check "tamper: changed VERIFY_CMD blocks"             "$out" contains '"decision": "block"'

# ---- pre-compact-guard (PreCompact) — Codex blocks via {"continue": false} ----
PCG="$(cd "$(dirname "$0")/../hooks" && pwd)/pre-compact-guard.py"
pcg() { # session  cwd  trigger-json-fragment
  local sess="$1" cwd="$2" frag="$3"
  printf '{"hook_event_name":"PreCompact","session_id":"%s","cwd":"%s"%s}' "$sess" "$cwd" "$frag" \
    | TMPDIR="$FIX" python3 "$PCG" 2>&1
}

if command -v git >/dev/null 2>&1; then
  GDIRTY="$FIX/pcg_dirty"; mkdir -p "$GDIRTY"
  git -C "$GDIRTY" init -q
  printf 'wip\n' > "$GDIRTY/uncommitted.txt"
  GCLEAN="$FIX/pcg_clean"; mkdir -p "$GCLEAN"
  git -C "$GCLEAN" init -q

  out=$(pcg pcg_t1 "$GDIRTY" ',"trigger":"manual"'); rc=$?
  check "pcg: manual+dirty blocks via continue:false" "$out" contains '"continue": false'
  check "pcg: block exits 0 (JSON is the mechanism)"  "$rc"  contains "0"
  check "pcg: block lists the dirty file"             "$out" contains "uncommitted.txt"
  check "pcg: block explains the override"            "$out" contains "override"

  out=$(pcg pcg_t1 "$GDIRTY" ',"trigger":"manual"')
  check "pcg: second consecutive attempt passes"      "$out" empty ""

  out=$(pcg pcg_t1 "$GDIRTY" ',"trigger":"manual"')
  check "pcg: guard re-arms after an override"        "$out" contains '"continue": false'

  out=$(pcg pcg_t2 "$GCLEAN" ',"trigger":"manual"')
  check "pcg: manual+clean is silent"                 "$out" empty ""

  out=$(pcg pcg_t3 "$GDIRTY" ',"trigger":"auto"')
  check "pcg: auto+dirty never blocks"                "$out" absent '"continue"'

  out=$(pcg pcg_t4 "$GDIRTY" '')
  check "pcg: missing trigger treated as auto"        "$out" empty ""

  NOREPO="$FIX/pcg_norepo"; mkdir -p "$NOREPO"; printf 'x\n' > "$NOREPO/f.txt"
  out=$(pcg pcg_t5 "$NOREPO" ',"trigger":"manual"')
  check "pcg: non-repo is silent"                     "$out" empty ""
else
  echo "SKIP  git not installed — skipping pre-compact-guard repo checks"
fi

out=$(printf 'garbage' | TMPDIR="$FIX" python3 "$PCG" 2>&1); rc=$?
check "pcg: garbage stdin is silent"                  "$out" empty ""
check "pcg: garbage stdin exits 0"                    "$rc"  contains "0"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
