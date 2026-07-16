#!/usr/bin/env bash
# P1-real — how the REAL done-gate behaves under headless `claude -p` when the
# project verifier is perpetually red. Answers verification items #1 (mechanism)
# and #2 (result-JSON fields): does the gate block ONCE (its stop_hook_active
# guard) or repeatedly? => whether DESIGN.md's H1 wording ("blocks until green")
# is accurate. Sandboxed under $TMPDIR; never touches ~/.claude.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
GATE="$REPO/plugins/tether/hooks/done-gate.py"
[ -f "$GATE" ] || { echo "cannot find done-gate at $GATE" >&2; exit 1; }
# shellcheck source=_timeout.sh
. "$HERE/_timeout.sh"

SBX="$(mktemp -d "${TMPDIR:-/tmp}/tether-p1real.XXXXXX")"
CONFIG="$SBX/config"; PROJ="$SBX/proj"; COUNTERS="$SBX/counters"
mkdir -p "$CONFIG" "$PROJ/.claude" "$COUNTERS"

cat > "$PROJ/.claude/verify.sh" <<'EOF'
#!/usr/bin/env bash
echo "verify: intentionally failing (probe P1-real)"
exit 1
EOF
chmod +x "$PROJ/.claude/verify.sh"

cat > "$CONFIG/settings.json" <<EOF
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "python3 \"$HERE/count_and_run.py\" \"$GATE\" \"$COUNTERS\"" } ] }
    ]
  }
}
EOF

echo "sandbox: $SBX"
echo "CLI version: $(claude --version 2>/dev/null || echo '??')"
echo "firing claude -p (300s cap backstop; expected to finish well under)..."
set +e
(
  cd "$PROJ"
  export CLAUDE_CONFIG_DIR="$CONFIG" DISABLE_AUTOUPDATER=1
  portable_timeout 300 claude -p \
    "Create a file hello.txt containing the word hi, then finish." \
    --output-format json
) < /dev/null > "$SBX/result.json" 2> "$SBX/stderr.log"
code=$?
set -e
echo "claude -p exit code: $code   (124 == hit the 300s cap => it LOOPED)"
echo "done-gate invocations: $(cat "$COUNTERS/invocations" 2>/dev/null || echo 0)"
echo "done-gate blocks:      $(cat "$COUNTERS/blocks" 2>/dev/null || echo 0)"
echo "  1 block  => single forced nudge (H1 wording must change from 'until green')"
echo "  >1 block => repeated enforcement (H1 wording as written may hold)"
echo
python3 "$HERE/parse_result.py" "$SBX/result.json" || true
echo
echo "stderr (first 20 lines):"; head -20 "$SBX/stderr.log" 2>/dev/null || true
echo
echo "artifacts kept in: $SBX   (remove with: rm -rf \"$SBX\")"
