#!/usr/bin/env bash
# Execute one bench cell end-to-end: provision an arm sandbox, run the agent on a
# task under a wall-clock cap, harvest the run, and grade it with the hidden
# verifier. Sandboxed (throwaway CLAUDE_CONFIG_DIR); never touches ~/.claude.
# The real path is user-fired (needs CLAUDE_CODE_OAUTH_TOKEN); --dry-run VARIANT
# skips the model and simulates the agent with a task variant (no quota).
#
# Usage:
#   run_cell.sh <task_dir> <arm> [--model M] [--cap SECONDS] [--out DIR]
#                                [--dry-run base|golden|naive]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
PROBES="$REPO/bench/probes/stop_hook"
# shellcheck source=../probes/stop_hook/_timeout.sh
. "$PROBES/_timeout.sh"
# shellcheck source=../probes/stop_hook/_auth_preflight.sh
. "$PROBES/_auth_preflight.sh"

task_dir=""; arm=""; model="claude-sonnet-5"; cap=1800; out=""; dry=""
while [ $# -gt 0 ]; do
  case "$1" in
    --model) model="$2"; shift 2;;
    --cap) cap="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --dry-run) dry="$2"; shift 2;;
    *) if [ -z "$task_dir" ]; then task_dir="$1"; elif [ -z "$arm" ]; then arm="$1"; fi; shift;;
  esac
done
[ -n "$task_dir" ] && [ -n "$arm" ] || { echo "usage: run_cell.sh <task_dir> <arm> [--model M] [--cap S] [--out DIR] [--dry-run V]" >&2; exit 2; }
task_dir="$(cd "$task_dir" && pwd)"
[ -n "$dry" ] || require_oauth_token

out="${out:-$(mktemp -d "${TMPDIR:-/tmp}/tether-cell.XXXXXX")}"
CONFIG="$out/config"; WORK="$out/work"; TELE="$out/hooks.jsonl"
python3 "$HERE/provision_arm.py" "$arm" "$CONFIG" "$TELE" >/dev/null
cp -r "$task_dir/repo" "$WORK"                 # agent workspace (no .git shipped)
prompt="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["prompt"])' "$task_dir/task.json")"

echo "cell: task=$(basename "$task_dir") arm=$arm model=$model  out=$out"
if [ -n "$dry" ]; then
  echo "[dry-run] simulating agent = '$dry' variant (no model call)"
  [ "$dry" = base ] || cp "$task_dir/variants/fields_$dry.py" "$WORK/fields.py"
  printf '{"subtype":"dry-run","is_error":false,"num_turns":0}' > "$out/result.json"
  code=0
else
  set +e
  (
    cd "$WORK"
    export CLAUDE_CONFIG_DIR="$CONFIG" DISABLE_AUTOUPDATER=1
    # bypassPermissions: headless has no one to approve edits/bash, and the agent
    # must freely edit + run verify.sh. Uniform across ALL arms (not a treatment
    # variable); the workspace is a throwaway isolated copy.
    portable_timeout "$cap" claude -p "$prompt" --model "$model" \
      --permission-mode bypassPermissions --output-format json
  ) < /dev/null > "$out/result.json" 2> "$out/stderr.log"
  code=$?
  set -e
fi

# Auth failures produce a "successful" envelope with is_error + a 401/login result
# and zero work — catch it so it can't masquerade as a graded cell.
if [ -z "$dry" ] && python3 - "$out/result.json" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
r = str(d.get("result", "")).lower()
bad = d.get("is_error") and (d.get("api_error_status") == 401
      or "authenticate" in r or "not logged in" in r or "bearer token" in r)
sys.exit(0 if bad else 1)
PY
then
  echo "!! AUTH FAILED — the run did no work; grading skipped (it would be meaningless)."
  python3 -c 'import json,sys; print("   error:", json.load(open(sys.argv[1])).get("result"))' "$out/result.json" 2>/dev/null || true
  echo "   Your CLAUDE_CODE_OAUTH_TOKEN is missing or invalid in THIS shell. Fix:"
  echo "     claude setup-token"
  echo "     export CLAUDE_CODE_OAUTH_TOKEN='<paste the fresh token>'"
  echo "   then re-run in the same shell."
  exit 3
fi

diff -ruN "$task_dir/repo" "$WORK" > "$out/agent.diff" 2>/dev/null || true   # for the record
python3 "$HERE/verify_hidden.py" "$task_dir" "$WORK" --out "$out/hidden.json" >/dev/null 2>&1 || true

python3 - "$out" "$arm" "$model" "$code" "$TELE" "$(basename "$task_dir")" <<'PY'
import json, os, sys
out, arm, model, code, tele, task = sys.argv[1:7]
def load(p):
    try: return json.load(open(p))
    except Exception: return {}
res, hid = load(f"{out}/result.json"), load(f"{out}/hidden.json")
blocks = 0
if os.path.isfile(tele):
    for line in open(tele):
        try: blocks += 1 if json.loads(line).get("blocked") else 0
        except Exception: pass
u = res.get("usage", {}) or {}
try: no_edits = os.path.getsize(f"{out}/agent.diff") == 0
except OSError: no_edits = None
summary = {
    "task": task, "arm": arm, "model": model, "exit": int(code),
    "turns": res.get("num_turns"), "hook_blocks": blocks,
    "cost_usd": res.get("total_cost_usd"),
    "output_tokens": u.get("output_tokens"),
    "cache_read_tokens": u.get("cache_read_input_tokens"),
    "overall_pass": hid.get("overall_pass"), "visible_pass": hid.get("visible_pass"),
    "hidden_pass": hid.get("hidden_pass"), "failures": hid.get("failures"),
    "no_edits": no_edits, "out": out,
}
json.dump(summary, open(f"{out}/summary.json", "w"), indent=2)
print("---- cell summary ----")
print(f"task={task} arm={arm} model={model} exit={code} turns={res.get('num_turns')} "
      f"hook_blocks={blocks} cost_usd~{res.get('total_cost_usd')}")
print(f"output_tok={u.get('output_tokens')} cache_read_tok={u.get('cache_read_input_tokens')}")
print(f"HIDDEN GRADE: overall_pass={hid.get('overall_pass')} "
      f"visible_pass={hid.get('visible_pass')} hidden_pass={hid.get('hidden_pass')}")
if hid.get("failures"): print("  failures:", ", ".join(hid["failures"]))
if no_edits: print("  NOTE: agent made no file edits (check permissions / the result text).")
print(f"artifacts: {out}  (result.json, hidden.json, agent.diff, hooks.jsonl, summary.json)")
PY
