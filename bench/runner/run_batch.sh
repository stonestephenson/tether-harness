#!/usr/bin/env bash
# Fire an ordered schedule of cells and append each to RESULTS.md. Turns a blocks
# spec + seed into a reproducible run order (schedule.py), executes each cell
# (run_cell.sh), and logs a one-line experiment-log record per cell. Sandboxed;
# user-fired (real path needs CLAUDE_CODE_OAUTH_TOKEN). --dry-run V simulates every
# cell's agent with a task variant (no quota) so the whole batch path is testable.
#
# Usage:
#   run_batch.sh <blocks.json> --seed N [--dry-run base|golden|naive]
#                [--tasks-root DIR] [--results FILE] [--cap SECONDS] [--out DIR]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"

blocks=""; seed=""; dry=""; tasks_root="$REPO/bench/tasks"; results="$REPO/bench/RESULTS.md"
cap=1800; batch_out=""
while [ $# -gt 0 ]; do
  case "$1" in
    --seed) seed="$2"; shift 2;;
    --dry-run) dry="$2"; shift 2;;
    --tasks-root) tasks_root="$2"; shift 2;;
    --results) results="$2"; shift 2;;
    --cap) cap="$2"; shift 2;;
    --out) batch_out="$2"; shift 2;;
    *) blocks="$1"; shift;;
  esac
done
[ -n "$blocks" ] && [ -n "$seed" ] || { echo "usage: run_batch.sh <blocks.json> --seed N [--dry-run V] [...]" >&2; exit 2; }

batch_out="${batch_out:-$(mktemp -d "${TMPDIR:-/tmp}/tether-batch.XXXXXX")}"
sched="$batch_out/schedule.json"
python3 "$HERE/schedule.py" "$blocks" --seed "$seed" --out "$sched" >/dev/null
n="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))))' "$sched")"
echo "batch: $n cells, seed=$seed, results -> $results   (artifacts: $batch_out)"

[ -f "$results" ] || printf '# RESULTS — bench run log\n\nOne row per cell (experiment-log format). Appended by `runner/run_batch.sh`.\n\n| ts | task | model | arm | hidden_pass | blocks | turns | cost~ | exit | run_dir |\n|---|---|---|---|---|---|---|---|---|---|\n' > "$results"

ndry=(); [ -n "$dry" ] && ndry=(--dry-run "$dry")
python3 - "$sched" > "$batch_out/cells.tsv" <<'CELLS'
import json, sys
for c in json.load(open(sys.argv[1])):
    print(f"{c['run']}\t{c['task']}\t{c['model']}\t{c['arm']}")
CELLS
while IFS=$'\t' read -r run task model arm; do
    cell_out="$batch_out/cell_$run"
    echo "  [$((run+1))/$n] task=$task model=$model arm=$arm"
    bash "$HERE/run_cell.sh" "$tasks_root/$task" "$arm" --model "$model" --cap "$cap" \
      --out "$cell_out" ${ndry[@]+"${ndry[@]}"} >/dev/null 2>&1 || true
    python3 - "$cell_out/summary.json" "$results" "$model" "$task" "$arm" <<'PY'
import json, sys, time
sm, results, model, task, arm = sys.argv[1:6]
try: s = json.load(open(sm))
except Exception: s = {}
tname = s.get("task") or task.split("/")[-1]
aname = s.get("arm") or arm
row = (f"| {time.strftime('%Y-%m-%dT%H:%M')} | {tname} | {model} | {aname} "
       f"| {s.get('hidden_pass')} | {s.get('hook_blocks')} | {s.get('turns')} "
       f"| {s.get('cost_usd')} | {s.get('exit', 'ERR')} | {s.get('out', '')} |")
open(results, "a").write(row + "\n")
print("     ->", s.get("hidden_pass"), "blocks=", s.get("hook_blocks"), "turns=", s.get("turns"))
PY
  done < "$batch_out/cells.tsv"
echo "batch done -> $results"
