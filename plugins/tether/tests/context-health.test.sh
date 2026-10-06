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
# CLAUDE_CONTEXT_BUDGET (or band overrides) from settings.json/env, nor the
# platform's window-capping vars the hook also reads.
export CLAUDE_CONTEXT_BUDGET=200000
unset CTX_WARN CTX_ACT CTX_CRIT
unset CLAUDE_CODE_DISABLE_1M_CONTEXT CLAUDE_CODE_AUTO_COMPACT_WINDOW
unset CLAUDE_AUTOCOMPACT_PCT_OVERRIDE CLAUDE_CODE_MAX_CONTEXT_TOKENS

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

# T15/T16 opus-5 is natively 1M. The id also ships a "[1m]" deployment suffix
# (claude-opus-5[1m]) — both forms must size at 1M, or the gauge over-warns ~5x
# on the current flagship. Regression for the 2026-08-01 sweep.
printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-5","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_opus5"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-5[1m]","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_opus5_suffixed"

check "claude-opus-5 maps to 1M (150k silent)"    "$(run UserPromptSubmit "$FIX/model_opus5" cht_m4 -u CLAUDE_CONTEXT_BUDGET)" empty ""
check "claude-opus-5[1m] suffix maps to 1M too"   "$(run UserPromptSubmit "$FIX/model_opus5_suffixed" cht_m5 -u CLAUDE_CONTEXT_BUDGET)" empty ""

# --- platform window caps (ROADMAP #13, 2026-10-01 sweep) ---
# The window is a property of the SESSION, not the model: a 1M-mapped id can run
# at 200k, where a 1M budget would keep the gauge silent through a real
# exhaustion. When CLAUDE_CONTEXT_BUDGET is unset the hook honors the same env
# vars Claude Code itself reads to cap the window. Caps only ever LOWER the
# budget (the over-warn direction). Each case asserts the budget the message
# reports ("of 200k tokens"), not just a band — a band alone can't tell a right
# cap from a nearby wrong one, and "silent" can't tell "ignored" from "crashed".
cap() { # desc  fixture  session  expected-substring  env assignments...
  local desc="$1" fx="$2" sess="$3" want="$4"; shift 4
  check "$desc" "$(run UserPromptSubmit "$FIX/$fx" "$sess" -u CLAUDE_CONTEXT_BUDGET "$@")" contains "$want"
}

# T17/T18 CLAUDE_CODE_DISABLE_1M_CONTEXT holds a 1M model to 200k; an explicit off doesn't
cap "DISABLE_1M caps a 1M model at 200k"          model_opus5   cht_w1 "of 200k tokens" CLAUDE_CODE_DISABLE_1M_CONTEXT=1
check "DISABLE_1M=0 does not cap"                 "$(run UserPromptSubmit "$FIX/model_opus5" cht_w2 -u CLAUDE_CONTEXT_BUDGET CLAUDE_CODE_DISABLE_1M_CONTEXT=0)" empty ""

# T19-T23 the auto-compact window is the session's real ceiling. Mirror the
# platform's parse: leading digits ("500k" reads as 500), clamped UP to 100k.
cap "AUTO_COMPACT_WINDOW caps the budget"         model_opus5   cht_w3 "of 150k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=150000
cap "AUTO_COMPACT_WINDOW '500k' reads as 500"     model_opus5   cht_w4 "of 100k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=500k
cap "AUTO_COMPACT_WINDOW clamps up to 100k"       model_opus5   cht_w5 "of 100k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=50000
cap "AUTO_COMPACT_WINDOW accepts a leading sign"  model_opus5   cht_w6 "of 150k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=+150000
cap "AUTO_COMPACT_WINDOW never raises a budget"   model_unknown cht_w7 "of 200k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000
# garbage is ignored, not a crash: the unknown-id fixture still warns at 200k
cap "garbage AUTO_COMPACT_WINDOW is ignored"      model_unknown cht_w8 "of 200k tokens" CLAUDE_CODE_AUTO_COMPACT_WINDOW=abc

# T24/T25 CLAUDE_AUTOCOMPACT_PCT_OVERRIDE moves the compaction point below the
# window, so the bands must scale with it (80% of 200k = 160k) — never above it
cap "PCT_OVERRIDE scales the budget down"         model_unknown cht_w9 "of 160k tokens" CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80
cap "PCT_OVERRIDE above 100 never raises"         model_unknown cht_wa "of 200k tokens" CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=200

# T26/T27 CLAUDE_CODE_MAX_CONTEXT_TOKENS declares a gateway model's real window
cap "MAX_CONTEXT_TOKENS lowers the budget"        model_unknown cht_wb "of 128k tokens" CLAUDE_CODE_MAX_CONTEXT_TOKENS=128000
cap "MAX_CONTEXT_TOKENS never raises a budget"    model_unknown cht_wc "of 200k tokens" CLAUDE_CODE_MAX_CONTEXT_TOKENS=1000000
# a non-finite value must be ignored, not crash the hook into silence
cap "MAX_CONTEXT_TOKENS=inf is ignored"           model_unknown cht_we "of 200k tokens" CLAUDE_CODE_MAX_CONTEXT_TOKENS=inf

# T28 CLAUDE_CONTEXT_BUDGET still always wins (150k of an explicit 1M silent)
check "env budget beats the platform caps"        "$(run UserPromptSubmit "$FIX/model_opus5" cht_wd CLAUDE_CONTEXT_BUDGET=1000000 CLAUDE_CODE_DISABLE_1M_CONTEXT=1 CLAUDE_CODE_AUTO_COMPACT_WINDOW=150000)" empty ""

# --- "[1m]" is the 1M signal for the 4.6 generation (ROADMAP #13) ---
# Opus 4.6 / Sonnet 4.6 reach 1M ONLY through their "[1m]" variant; a bare id is
# a 200k session. Any id carrying the tag (any casing) is one the platform
# itself sizes at 1M.
printf '%s\n' '{"type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_s46"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-sonnet-4-6[1m]","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_s46_tagged"
printf '%s\n' '{"type":"assistant","message":{"model":"gateway/opus-4-6[1M]","usage":{"input_tokens":30000,"cache_read_input_tokens":110000,"cache_creation_input_tokens":10000}}}' > "$FIX/model_custom_tagged"

cap "bare claude-sonnet-4-6 is a 200k session"    model_s46     cht_t1 "of 200k tokens"
check "claude-sonnet-4-6[1m] maps to 1M (silent)" "$(run UserPromptSubmit "$FIX/model_s46_tagged" cht_t2 -u CLAUDE_CONTEXT_BUDGET)" empty ""
check "any id tagged [1M] maps to 1M (silent)"    "$(run UserPromptSubmit "$FIX/model_custom_tagged" cht_t3 -u CLAUDE_CONTEXT_BUDGET)" empty ""
cap "DISABLE_1M caps a tagged id too"             model_s46_tagged cht_t4 "of 200k tokens" CLAUDE_CODE_DISABLE_1M_CONTEXT=1

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
