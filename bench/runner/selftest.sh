#!/usr/bin/env bash
# Model-free self-test of the runner foundation: arm provisioning (incl. a live
# done-gate block through the telemetry wrapper) and the schedule generator's
# invariants. No `claude` calls.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/tether-runner-self.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0

# 1) provisioning writes valid, correct settings.json per arm.
for arm in A0 A1 A2 A3; do
  python3 "$HERE/provision_arm.py" "$arm" "$T/$arm" "$T/$arm/tele.jsonl" >/dev/null
  jq empty "$T/$arm/settings.json" || { echo "FAIL $arm settings not JSON"; fail=1; }
done
[ "$(jq '.hooks // {} | length' "$T/A0/settings.json")" = "0" ] \
  && echo "PASS A0 has no hooks" || { echo "FAIL A0 should have no hooks"; fail=1; }
jq -e '.hooks.Stop[0].hooks[0].command | test("done-gate.py")' "$T/A2/settings.json" >/dev/null \
  && echo "PASS A2 wires done-gate on Stop" || { echo "FAIL A2 done-gate wiring"; fail=1; }
jq -e '.hooks.PostToolUse[0].matcher == "Edit|Write|NotebookEdit"' "$T/A1/settings.json" >/dev/null \
  && echo "PASS A1 wires verify-on-edit with matcher" || { echo "FAIL A1 matcher"; fail=1; }
[ "$(jq '.hooks | keys | length' "$T/A3/settings.json")" = "4" ] \
  && echo "PASS A3 wires 4 events" || { echo "FAIL A3 event count"; fail=1; }

# 2) telemetry wrapper: A2's wired command blocks on a red verifier AND logs it.
P="$T/proj"; mkdir -p "$P/.claude"
printf '#!/usr/bin/env bash\nexit 1\n' > "$P/.claude/verify.sh"; chmod +x "$P/.claude/verify.sh"
cmd="$(jq -r '.hooks.Stop[0].hooks[0].command' "$T/A2/settings.json")"
out="$(cd "$P" && printf '{"cwd":"%s","session_id":"self","stop_hook_active":false}' "$P" \
  | eval "$cmd")"
if echo "$out" | grep -q '"decision": "block"' \
   && [ -f "$T/A2/tele.jsonl" ] \
   && [ "$(jq -r 'select(.hook=="done-gate.py") | .blocked' "$T/A2/tele.jsonl" | head -1)" = "true" ]; then
  echo "PASS telemetry wrapper: done-gate blocks + logs blocked=true"
else
  echo "FAIL telemetry wrapper: out=${out:0:60} log=$(cat "$T/A2/tele.jsonl" 2>/dev/null || echo none)"; fail=1
fi

# 3) schedule generator invariants (mirrors DESIGN's blocks, shrunk).
cat > "$T/blocks.json" <<'JSON'
[
 {"name":"conf","model":"sonnet","arms":["A0","A2","A3"],"tasks":["t1","t2","t3"],"reps":5},
 {"name":"s2","model":"haiku","arms":["A0","A2"],"tasks":["t1","t2"],"reps":5},
 {"name":"e1","model":"sonnet","arms":["A0","A1"],"tasks":["v1"],"reps":5}
]
JSON
python3 - "$HERE" "$T/blocks.json" <<'PY'
import sys, json
sys.path.insert(0, sys.argv[1])
import schedule
blocks = json.load(open(sys.argv[2]))
s = schedule.order_schedule(blocks, seed=1234)
expect = 3*3*5 + 2*2*5 + 2*1*5
assert len(s) == expect, f"count {len(s)} != {expect}"
# every (block,task,rep,arm) exactly once
keys = {(c["block"],c["task"],c["rep"],c["arm"]) for c in s}
assert len(keys) == expect, "duplicate/missing cells"
# each group's cells are contiguous and share (block,model,task,rep)
from itertools import groupby
for gi, cells in groupby(s, key=lambda c: c["group"]):
    cells = list(cells)
    runs = [c["run"] for c in cells]
    assert runs == list(range(runs[0], runs[0]+len(runs))), f"group {gi} not contiguous"
    base = {(c["block"],c["model"],c["task"],c["rep"]) for c in cells}
    assert len(base) == 1, f"group {gi} mixes tuples"
    arms = [c["arm"] for c in cells]
    assert len(arms) == len(set(arms)), f"group {gi} repeats an arm"
# determinism + seed-sensitivity
s2 = schedule.order_schedule(json.load(open(sys.argv[2])), seed=1234)
assert [c["run"] for c in s]==[c["run"] for c in s2] and \
       [c["arm"] for c in s]==[c["arm"] for c in s2], "not deterministic"
s3 = schedule.order_schedule(json.load(open(sys.argv[2])), seed=9999)
assert [c["arm"] for c in s] != [c["arm"] for c in s3], "seed had no effect"
print("PASS schedule: count, coverage, contiguity, determinism, seed-sensitivity")
PY

if [ "$fail" -eq 0 ]; then echo "ALL RUNNER SELFTESTS PASS"; else echo "RUNNER SELFTEST FAILURES"; exit 1; fi
