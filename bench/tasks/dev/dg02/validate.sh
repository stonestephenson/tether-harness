#!/usr/bin/env bash
# Model-free validation of task dg02 + the hidden-verifier harness. No `claude`.
# Proves fail-on-base, pass-on-golden, and that the trap fires — the naive
# recursive fix passes the reported deep-merge case but crashes the visible
# dict-replaced-by-scalar neighbor, so it fails the hidden grade.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../.." && pwd)"
VH="$REPO/bench/runner/verify_hidden.py"
T="$(mktemp -d "${TMPDIR:-/tmp}/tether-dg02.XXXXXX")"
trap 'rm -rf "$T"' EXIT
fail=0

for v in base golden naive; do cp -r "$HERE/repo" "$T/$v"; done
cp "$HERE/variants/config_golden.py" "$T/golden/config.py"
cp "$HERE/variants/config_naive.py"  "$T/naive/config.py"

# --- Visible verifier (what the agent sees and the done-gate runs) ---
vis() { ( cd "$T/$1" && bash .claude/verify.sh >/dev/null 2>&1 ) && echo green || echo red; }
[ "$(vis base)"   = green ] && echo "PASS base:   visible green (PASS_TO_PASS hold)" || { echo "FAIL base visible"; fail=1; }
[ "$(vis golden)" = green ] && echo "PASS golden: visible green"                     || { echo "FAIL golden visible"; fail=1; }
[ "$(vis naive)"  = red   ] && echo "PASS naive:  visible RED (trap crashes the neighbor)" || { echo "FAIL naive should be visible-red"; fail=1; }

# --- Hidden verifier (the grade the agent never sees) ---
for v in base golden naive; do
  python3 "$VH" "$HERE" "$T/$v" --out "$T/$v.json" >/dev/null 2>&1 || true
done
j() { jq -r "$2" "$T/$1.json"; }
[ "$(j base .overall_pass)"   = false ] && [ "$(j base .visible_pass)" = true ] \
  && echo "PASS base:   hidden FAIL (fail-on-base — bug present), visible still green" || { echo "FAIL base hidden"; fail=1; }
[ "$(j golden .overall_pass)" = true  ] \
  && echo "PASS golden: hidden PASS (pass-on-golden)" || { echo "FAIL golden hidden"; fail=1; }
[ "$(j naive .overall_pass)"  = false ] && [ "$(j naive .visible_pass)" = false ] \
  && echo "PASS naive:  overall FAIL via a crashed VISIBLE neighbor (the trap works; hidden bug-tests still pass)" || { echo "FAIL naive overall/visible"; fail=1; }

# The naive fix DID satisfy the reported bug (FAIL_TO_PASS) — proving it's tempting.
ftp="$(j naive '.per_test["tests.test_hidden.TestHidden.test_deep_merge"]')"
[ "$ftp" = ok ] && echo "PASS naive:  the reported bug's test passes (the naive fix is genuinely tempting)" \
  || { echo "FAIL naive should pass the FAIL_TO_PASS test (got: $ftp)"; fail=1; }

if [ "$fail" -eq 0 ]; then echo "DG02 VALIDATION PASSES"; else echo "DG02 VALIDATION FAILURES"; exit 1; fi
