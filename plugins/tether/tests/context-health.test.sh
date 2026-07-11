#!/usr/bin/env bash
# Regression test for context-health.py.
# Run:  bash tests/context-health.test.sh   (from the plugin root)
# Exits non-zero if any assertion fails. Touches only "cht_*" test sessions.

HOOK="$(cd "$(dirname "$0")/../hooks" && pwd)/context-health.py"
STATE_DIR="$(python3 -c 'import os,tempfile;print(os.path.join(tempfile.gettempdir(),"claude-context-health-state"))')"
FIX="$(mktemp -d)"
pass=0
fail=0

# Hermetic: fixtures are sized for a 200k window — don't inherit the session's
# CLAUDE_CONTEXT_BUDGET (or band overrides) from settings.json/env.
export CLAUDE_CONTEXT_BUDGET=200000
unset CTX_WARN CTX_ACT CTX_CRIT

cleanup() { rm -rf "$FIX"; rm -f "$STATE_DIR"/cht_*; }
trap cleanup EXIT

rm -f "$STATE_DIR"/cht_*   # start clean

# --- fixtures: one assistant turn per band (input + cached inputs = window use) ---
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":4000,"cache_creation_input_tokens":0}}}' > "$FIX/light"   # 14k  ~7%   band0
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/warn" # 150k ~75%  band1
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":30000,"cache_read_input_tokens":140000,"cache_creation_input_tokens":10000}}}' > "$FIX/act"  # 180k ~90%  band2
printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":36000,"cache_read_input_tokens":150000,"cache_creation_input_tokens":10000}}}' > "$FIX/crit" # 196k ~98%  band3
# last MAIN turn is light, but a heavier SIDECHAIN turn follows it (should be ignored)
{
  printf '%s\n' '{"type":"assistant","message":{"usage":{"input_tokens":10000,"cache_read_input_tokens":4000,"cache_creation_input_tokens":0}}}'
  printf '%s\n' '{"type":"assistant","isSidechain":true,"message":{"usage":{"input_tokens":190000,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}'
} > "$FIX/sidechain"

run() { # event  transcript  session  [extra env assignments...]
  local event="$1" tr="$2" sess="$3"; shift 3
  env "$@" python3 "$HOOK" <<EOF
{"session_id":"$sess","hook_event_name":"$event","transcript_path":"$tr"}
EOF
}

check() { # desc  actual  mode(contains|absent|empty)  expected
  local desc="$1" actual="$2" mode="$3" expected="$4" ok=0
  case "$mode" in
    contains) [[ "$actual" == *"$expected"* ]] && ok=1 ;;
    absent)   [[ "$actual" != *"$expected"* ]] && ok=1 ;;
    empty)    [[ -z "$actual" ]] && ok=1 ;;
  esac
  if [[ $ok -eq 1 ]]; then
    printf 'PASS  %s\n' "$desc"; pass=$((pass+1))
  else
    printf 'FAIL  %s\n      got: %s\n' "$desc" "${actual:-<empty>}"; fail=$((fail+1))
  fi
}

# T1 healthy band -> silent
check "band0 (healthy) is silent" "$(run UserPromptSubmit "$FIX/light" cht_a)" empty ""

# T2 warn band injects to model
o=$(run UserPromptSubmit "$FIX/warn" cht_b)
check "band1 (warn) injects additionalContext" "$o" contains "additionalContext"
check "band1 message says 'getting heavy'"     "$o" contains "getting heavy"

# T3 Stop at act -> user notice only, no model injection
o=$(run Stop "$FIX/act" cht_c)
check "Stop@band2 emits systemMessage (user)"   "$o" contains "act soon"
check "Stop@band2 does NOT inject to model"      "$o" absent "additionalContext"

# T4 UserPromptSubmit at same band/session -> model injected, user NOT re-notified
o=$(run UserPromptSubmit "$FIX/act" cht_c)
check "Prompt@band2 injects to model"            "$o" contains "additionalContext"
check "Prompt@band2 no duplicate systemMessage"  "$o" absent "systemMessage"

# T5 debounce: same band again -> fully silent
check "same band again is debounced (silent)"    "$(run UserPromptSubmit "$FIX/act" cht_c)" empty ""

# T6 escalation past the debounce
check "escalation band2->band3 re-notifies user" "$(run Stop "$FIX/crit" cht_c)" contains "critical"

# T7 re-arm after occupancy drops
run Stop "$FIX/light" cht_c >/dev/null   # drop to band0 re-arms channels
check "re-armed after drop, band2 fires again"   "$(run Stop "$FIX/act" cht_c)" contains "act soon"

# T8 sidechain turns are ignored (main window is what counts)
check "heavy SIDECHAIN turn is ignored"          "$(run UserPromptSubmit "$FIX/sidechain" cht_d)" empty ""

# T9 missing transcript -> silent, no crash
check "missing transcript is silent"             "$(run UserPromptSubmit "/no/such.jsonl" cht_e)" empty ""

# T10 garbage stdin -> silent, no crash, exit 0
o=$(printf 'not json at all' | python3 "$HOOK"); rc=$?
check "garbage stdin is silent"                  "$o" empty ""
check "garbage stdin exits 0"                    "$rc" contains "0"

# T11 budget override changes banding (150k of 100k -> critical)
check "CLAUDE_CONTEXT_BUDGET override applies"    "$(run UserPromptSubmit "$FIX/warn" cht_f CLAUDE_CONTEXT_BUDGET=100000)" contains "critical"

# --- model -> budget map (no env var: budget comes from the transcript model id) ---
printf '%s\n' '{"type":"assistant","message":{"model":"claude-fable-5","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_1m"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-test-9","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_unknown"

# T12 mapped id + NO env -> 1M budget, 150k is ~15% -> silent
check "mapped model id sets budget (150k of 1M silent)" "$(run UserPromptSubmit "$FIX/model_1m" cht_m1 -u CLAUDE_CONTEXT_BUDGET)" empty ""

# T13 env var always wins over the map (150k of 200k -> warn)
check "env var beats the model map"               "$(run UserPromptSubmit "$FIX/model_1m" cht_m2)" contains "getting heavy"

# T14 unknown id + NO env -> 200k fallback (150k -> warn)
check "unknown model id falls back to 200k"       "$(run UserPromptSubmit "$FIX/model_unknown" cht_m3 -u CLAUDE_CONTEXT_BUDGET)" contains "getting heavy"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
