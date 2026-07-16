#!/usr/bin/env bash
# Model-free self-test of the P1 harness — proves the plumbing before any quota is
# spent. Calls no `claude` binary; exercises the hooks and parser directly.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
GATE="$REPO/plugins/tether/hooks/done-gate.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/tether-p1self.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0

# 1) always_block_stop self-caps: blocks PROBE_MAX_BLOCKS times, then allows.
export PROBE_COUNTER="$T/bc" PROBE_MAX_BLOCKS=6
blocks=0; allows=0
for _ in $(seq 1 8); do
  out="$(echo '{"stop_hook_active":false}' | python3 "$HERE/always_block_stop.py")"
  if echo "$out" | grep -q '"decision": "block"'; then blocks=$((blocks + 1)); else allows=$((allows + 1)); fi
done
if [ "$blocks" -eq 6 ] && [ "$allows" -eq 2 ]; then
  echo "PASS  always_block self-cap (6 block / 2 allow)"
else
  echo "FAIL  always_block self-cap: blocks=$blocks allows=$allows"; fail=1
fi
unset PROBE_COUNTER PROBE_MAX_BLOCKS

# 2) count_and_run wraps the real done-gate: a red verifier => one block, counters bump.
P="$T/proj"; C="$T/ctr"; mkdir -p "$P/.claude"
printf '#!/usr/bin/env bash\nexit 1\n' > "$P/.claude/verify.sh"; chmod +x "$P/.claude/verify.sh"
out="$(cd "$P" && printf '{"cwd":"%s","session_id":"self","stop_hook_active":false}' "$P" \
  | python3 "$HERE/count_and_run.py" "$GATE" "$C")"
if echo "$out" | grep -q '"decision": "block"' && [ "$(cat "$C/blocks" 2>/dev/null)" = "1" ]; then
  echo "PASS  count_and_run + real done-gate blocks on red (blocks=1)"
else
  echo "FAIL  count_and_run wrap: out=${out:0:80} blocks=$(cat "$C/blocks" 2>/dev/null || echo none)"; fail=1
fi

# 3) parse_result handles empty + a sample result JSON.
if python3 "$HERE/parse_result.py" <<<'' | grep -q EMPTY; then
  echo "PASS  parse_result on empty input"
else echo "FAIL  parse_result empty"; fail=1; fi
if python3 "$HERE/parse_result.py" \
    <<<'{"num_turns":3,"usage":{"output_tokens":10,"cache_read_input_tokens":99},"subtype":"success"}' \
    | grep -q "num_turns: 3"; then
  echo "PASS  parse_result on sample JSON"
else echo "FAIL  parse_result sample"; fail=1; fi

# 4) portable_timeout: fires the cap on a slow command, passes a fast one through.
# shellcheck source=_timeout.sh
. "$HERE/_timeout.sh"
rc=0; portable_timeout 1 sleep 5 || rc=$?
[ "$rc" -eq 124 ] && echo "PASS  portable_timeout caps a slow command (rc=124)" \
  || { echo "FAIL  portable_timeout slow: rc=$rc (expected 124)"; fail=1; }
rc=0; portable_timeout 5 sleep 1 || rc=$?
[ "$rc" -eq 0 ] && echo "PASS  portable_timeout passes a fast command (rc=0)" \
  || { echo "FAIL  portable_timeout fast: rc=$rc (expected 0)"; fail=1; }

if [ "$fail" -eq 0 ]; then echo "ALL SELFTESTS PASS"; else echo "SELFTEST FAILURES"; exit 1; fi
