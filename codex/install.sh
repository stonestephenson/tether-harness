#!/usr/bin/env bash
# Installer for the tether harness — Codex edition.
# Copies hooks + prompts into ~/.codex and wires the hooks into ~/.codex/hooks.json
# (merging, not clobbering, any hooks you already have). Idempotent.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"            # the codex/ dir
CODEX="${CODEX_HOME:-$HOME/.codex}"
HOOKS_DIR="$CODEX/tether/hooks"
mkdir -p "$HOOKS_DIR" "$CODEX/prompts"

echo "• hooks   -> $HOOKS_DIR"
cp "$SRC/hooks/"*.py "$HOOKS_DIR/"

echo "• prompts -> $CODEX/prompts   (invoke as /prompts:<name>)"
cp "$SRC/prompts/"*.md "$CODEX/prompts/"

echo "• AGENTS  -> $CODEX/AGENTS.md  (global operating defaults)"
cp "$SRC/../AGENTS.md" "$CODEX/AGENTS.md"

# hooks.json: resolve the hooks-dir placeholder and MERGE into any existing config.
python3 - "$SRC/hooks.json" "$CODEX/hooks.json" "$HOOKS_DIR" <<'PY'
import json, os, sys
tmpl_path, dst_path, hooks_dir = sys.argv[1:4]

def resolve(o):
    if isinstance(o, str):  return o.replace("__HOOKS_DIR__", hooks_dir)
    if isinstance(o, list): return [resolve(x) for x in o]
    if isinstance(o, dict): return {k: resolve(v) for k, v in o.items()}
    return o

tmpl = resolve(json.load(open(tmpl_path)))
dst = {"hooks": {}}
if os.path.exists(dst_path):
    try: dst = json.load(open(dst_path))
    except Exception: dst = {"hooks": {}}
dst.setdefault("hooks", {})
for event, groups in tmpl["hooks"].items():
    existing = dst["hooks"].setdefault(event, [])
    # drop any prior tether entries so re-running doesn't duplicate them
    existing = [g for g in existing if "tether" not in json.dumps(g)]
    existing.extend(groups)
    dst["hooks"][event] = existing
json.dump(dst, open(dst_path, "w"), indent=2)
print("• hooks.json ->", dst_path)
PY

echo
echo "Done. Start a new Codex session to load the hooks."
echo "NOTE: context-health is Claude-Code-only (it needs transcript token data Codex"
echo "      does not expose), so it is installed but NOT wired. verify-on-edit +"
echo "      done-gate are active. Arm done-gate with a .codex/verify.sh or VERIFY_CMD."
