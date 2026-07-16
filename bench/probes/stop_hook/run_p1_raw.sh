#!/usr/bin/env bash
# P1-raw — the raw ceiling of headless `claude -p` under an unconditionally-blocking
# Stop hook (ignores stop_hook_active). Answers verification item #1: does the CLI
# enforce a single block, or keep re-inviting the agent until the hook stops
# blocking? The hook self-caps at PROBE_MAX_BLOCKS so quota is bounded. Sandboxed.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_timeout.sh
. "$HERE/_timeout.sh"
SBX="$(mktemp -d "${TMPDIR:-/tmp}/tether-p1raw.XXXXXX")"
CONFIG="$SBX/config"; PROJ="$SBX/proj"
mkdir -p "$CONFIG" "$PROJ/.claude"
COUNTER="$SBX/blockcount"; MAXB="${PROBE_MAX_BLOCKS:-6}"

cat > "$CONFIG/settings.json" <<EOF
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command",
        "command": "python3 \"$HERE/always_block_stop.py\"" } ] }
    ]
  }
}
EOF

echo "sandbox: $SBX   (self-caps at $MAXB blocks)"
set +e
(
  cd "$PROJ"
  export CLAUDE_CONFIG_DIR="$CONFIG" DISABLE_AUTOUPDATER=1
  export PROBE_COUNTER="$COUNTER" PROBE_MAX_BLOCKS="$MAXB"
  portable_timeout 300 claude -p \
    "Create a file hello.txt containing the word hi, then finish." \
    --output-format json
) < /dev/null > "$SBX/result.json" 2> "$SBX/stderr.log"
code=$?
set -e
echo "claude -p exit code: $code   (124 == hit the cap)"
echo "blocks reached: $(cat "$COUNTER" 2>/dev/null || echo 0) / $MAXB"
echo "  == $MAXB => CLI loops as long as the hook blocks; the run-time cap policy is load-bearing"
echo "  <  $MAXB => CLI enforces its own ceiling at that many blocks"
echo
python3 "$HERE/parse_result.py" "$SBX/result.json" || true
echo
echo "stderr (first 20 lines):"; head -20 "$SBX/stderr.log" 2>/dev/null || true
echo
echo "artifacts kept in: $SBX   (remove with: rm -rf \"$SBX\")"
