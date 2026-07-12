#!/usr/bin/env bash
# Regression test for the generic edition of verify-on-edit.py, done-gate.py,
# and pre-compact-guard.py.
# Run:  bash tests/verify-hooks.test.sh   (from the repo root)
#
# The generic contract (see WIRING.md): your wiring feeds Claude-Code-shaped
# JSON on stdin, and a hook signals "problem" with a NON-ZERO EXIT + text on
# stderr. pre-compact-guard emits on two channels: stdout is context to INJECT
# into the compaction prompt (where the tool supports it), stderr goes to the
# user; it never blocks. These tests drive the Python hooks with the exact
# payload shapes WIRING.md documents.

VOE="$(cd "$(dirname "$0")/../hooks" && pwd)/verify-on-edit.py"
DG="$(cd "$(dirname "$0")/../hooks" && pwd)/done-gate.py"
PCG="$(cd "$(dirname "$0")/../hooks" && pwd)/pre-compact-guard.py"
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

# ---- verify-on-edit (tool.execute.after; plugin sends {tool_name:"Edit", tool_input:{file_path}}) ----
if command -v ruff >/dev/null 2>&1; then
  mkdir -p "$FIX/proj"
  printf 'import os\n' > "$FIX/proj/bad.py"            # F401 unused import (real bug)
  printf 'print("ok")\n' > "$FIX/proj/good.py"

  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
        "$FIX/proj/bad.py" | python3 "$VOE" 2>&1); rc=$?
  check "F401 is reported"                           "$out" contains "ruff"
  check "diagnostic exits 2 (feed back to agent)"    "$rc"  contains "2"
  check "diagnostic names the file"                  "$out" contains "bad.py"

  out=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' \
        "$FIX/proj/good.py" | python3 "$VOE" 2>&1)
  check "clean file is silent"                       "$out" empty ""

  # Style-only issue without a ruff/pyproject config -> NOT reported (opt-in).
  printf 'import os, sys\nprint(os.getcwd(), sys.argv)\n' > "$FIX/proj/style.py"
  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
        "$FIX/proj/style.py" | python3 "$VOE" 2>&1)
  check "python style-only (E401) NOT reported"      "$out" empty ""
else
  echo "SKIP  ruff not installed — skipping Python verify checks"
fi

if command -v rustfmt >/dev/null 2>&1; then
  printf 'fn main(){let x=1;println!("{}",x);}\n' > "$FIX/bad.rs"
  out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' \
        "$FIX/bad.rs" | python3 "$VOE" 2>&1)
  check ".rs runs rustfmt"                           "$out" contains "rustfmt"
else
  echo "SKIP  rustfmt not installed — skipping Rust verify check"
fi

out=$(printf '{"tool_name":"Bash","tool_input":{"command":"ls"}}' | python3 "$VOE" 2>&1)
check "non-edit tool is ignored"                   "$out" empty ""

out=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"/nope/missing.py"}}' | python3 "$VOE" 2>&1)
check "missing file is silent"                     "$out" empty ""

out=$(printf 'garbage' | python3 "$VOE" 2>&1); rc=$?
check "garbage stdin is silent"                    "$out" empty ""
check "garbage stdin exits 0"                      "$rc"  contains "0"

# ---- done-gate (session.idle) — exit 2 + stderr is the report mechanism ----
# Every invocation gets a unique dgt_* session_id and TMPDIR="$FIX" so the
# anti-tamper per-session state is isolated per test and cleaned up with $FIX.
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_red","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="false" python3 "$DG" 2>&1); rc=$?
check "failing verify reports"                     "$out" contains "Project verification is failing"
check "failing verify exits 2"                     "$rc"  contains "2"

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_green","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="true" python3 "$DG" 2>&1); rc=$?
check "passing verify is silent"                   "$out" empty ""
check "passing verify exits 0"                     "$rc"  contains "0"

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_loop","stop_hook_active":true,"cwd":"%s"}' "$FIX" | TMPDIR="$FIX" VERIFY_CMD="false" python3 "$DG" 2>&1)
check "stop_hook_active guard prevents loop"       "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_noopt","cwd":"%s"}' "$FIX" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check "no opt-in -> gate is silent"                "$out" empty ""

# .tether/verify.sh discovery, including the cwd-upward walk from a subdirectory.
WALK="$FIX/walk"; mkdir -p "$WALK/.tether" "$WALK/src/deep" "$WALK/.git"
printf '#!/usr/bin/env bash\necho walkfail >&2\nexit 1\n' > "$WALK/.tether/verify.sh"
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_file","cwd":"%s"}' "$WALK" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check ".tether/verify.sh failure reports"          "$out" contains "walkfail"
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_walk","cwd":"%s"}' "$WALK/src/deep" | TMPDIR="$FIX" python3 "$DG" 2>&1)
check "verify.sh found from a subdirectory (walk-up)" "$out" contains "walkfail"

# ---- done-gate: verifier-integrity guard (anti-tamper) ----
TDIR="$FIX/tamper"; mkdir -p "$TDIR/.tether"
DG_STATE="$FIX/tether-done-gate-state"
dg() { # session  cwd  [extra-json]
  local sess="$1" cwd="$2" extra="${3:-}"
  printf '{"hook_event_name":"Stop","session_id":"%s","cwd":"%s"%s}' "$sess" "$cwd" "$extra" \
    | TMPDIR="$FIX" python3 "$DG" 2>&1
}

printf '#!/usr/bin/env bash\nexit 0\n' > "$TDIR/.tether/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: first run baselines silently"          "$out" empty ""

out=$(dg dgt_t1 "$TDIR")
check "tamper: unchanged verifier + green stays silent" "$out" empty ""

printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.tether/verify.sh"
out=$(dg dgt_t1 "$TDIR"); rc=$?
check "tamper: changed + green reports once"          "$out" contains "CHANGED during this session"
check "tamper: report exits 2 (surfaces to the user)" "$rc"  contains "2"
check "tamper: report shows the diff"                 "$out" contains "weakened"

out=$(dg dgt_t1 "$TDIR")
check "tamper: next run after the report is silent"   "$out" empty ""

printf '#!/usr/bin/env bash\necho broken >&2\nexit 1\n' > "$TDIR/.tether/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: changed + red still red-reports"       "$out" contains "Project verification is failing"
check "tamper: red report carries a tamper note"      "$out" contains "changed during this session"

printf '#!/usr/bin/env bash\n# weakened\nexit 0\n' > "$TDIR/.tether/verify.sh"
out=$(dg dgt_t1 "$TDIR")
check "tamper: revert to baseline goes green silently" "$out" empty ""

out=$(dg dgt_t2 "$TDIR")
printf 'not json' > "$DG_STATE/dgt_t2"
out=$(dg dgt_t2 "$TDIR")
check "tamper: corrupt state fails open"              "$out" empty ""

out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t3","cwd":"%s"}' "$TDIR" | TMPDIR="$FIX" VERIFY_CMD="true" python3 "$DG" 2>&1)
out=$(printf '{"hook_event_name":"Stop","session_id":"dgt_t3","cwd":"%s"}' "$TDIR" | TMPDIR="$FIX" VERIFY_CMD="echo ok" python3 "$DG" 2>&1)
check "tamper: changed VERIFY_CMD reports"            "$out" contains "CHANGED during this session"

# ---- pre-compact-guard (experimental.session.compacting) — inject, never block ----
# stdout = summarizer-directed context (the plugin appends it to the compaction
# prompt); stderr = user-facing warning; exit 2 = "dirty, advisory emitted".
pcg() { # cwd -> combined output
  printf '{"cwd":"%s","session_id":"pcg_s"}' "$1" | python3 "$PCG" 2>&1
}

if command -v git >/dev/null 2>&1; then
  GDIRTY="$FIX/pcg_dirty"; mkdir -p "$GDIRTY"
  git -C "$GDIRTY" init -q
  printf 'wip\n' > "$GDIRTY/uncommitted.txt"
  GCLEAN="$FIX/pcg_clean"; mkdir -p "$GCLEAN"
  git -C "$GCLEAN" init -q

  out=$(pcg "$GDIRTY"); rc=$?
  check "pcg: dirty tree emits the advisory"          "$out" contains "uncommitted.txt"
  check "pcg: advisory exits 2"                       "$rc"  contains "2"

  ctx=$(printf '{"cwd":"%s","session_id":"pcg_s"}' "$GDIRTY" | python3 "$PCG" 2>/dev/null)
  check "pcg: stdout primes the summary (context)"    "$ctx" contains "Preserve in the summary"
  check "pcg: context lists the dirty file"           "$ctx" contains "uncommitted.txt"

  err=$(printf '{"cwd":"%s","session_id":"pcg_s"}' "$GDIRTY" | python3 "$PCG" 2>&1 >/dev/null)
  check "pcg: stderr warns the user"                  "$err" contains "cannot block a compaction"
  check "pcg: stderr points at externalizing"         "$err" contains "/ship"

  out=$(pcg "$GCLEAN"); rc=$?
  check "pcg: clean tree is silent"                   "$out" empty ""
  check "pcg: clean tree exits 0"                     "$rc"  contains "0"

  NOREPO="$FIX/pcg_norepo"; mkdir -p "$NOREPO"; printf 'x\n' > "$NOREPO/f.txt"
  out=$(pcg "$NOREPO")
  check "pcg: non-repo is silent"                     "$out" empty ""
else
  echo "SKIP  git not installed — skipping pre-compact-guard repo checks"
fi

out=$(pcg "/nope/does-not-exist"); rc=$?
check "pcg: bad cwd fails open"                       "$out" empty ""
check "pcg: bad cwd exits 0"                          "$rc"  contains "0"

out=$(printf 'garbage' | python3 "$PCG" 2>&1); rc=$?
check "pcg: garbage stdin is silent"                  "$out" empty ""
check "pcg: garbage stdin exits 0"                    "$rc"  contains "0"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
