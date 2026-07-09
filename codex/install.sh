#!/usr/bin/env bash
# Installer for the tether harness — Codex edition.
# Copies hooks + skills into $CODEX_HOME (default ~/.codex), wires the hooks into
# hooks.json (MERGING, never clobbering hooks you already have), and installs the
# operating defaults into AGENTS.md between managed markers (your existing AGENTS.md
# content is preserved). Idempotent — safe to re-run to upgrade.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"            # the codex/ dir
CODEX="${CODEX_HOME:-$HOME/.codex}"
HOOKS_DIR="$CODEX/tether/hooks"
mkdir -p "$HOOKS_DIR" "$CODEX/skills"

echo "• hooks   -> $HOOKS_DIR"
cp "$SRC/hooks/"*.py "$HOOKS_DIR/"

echo "• skills  -> $CODEX/skills   (auto-trigger by description; browse with /skills, mention with \$name)"
cp -R "$SRC/skills/." "$CODEX/skills/"

# AGENTS.md: install our operating-defaults block between managed markers, WITHOUT
# destroying anything you already keep in your global AGENTS.md.
python3 - "$SRC/../AGENTS.md" "$CODEX/AGENTS.md" <<'PY'
import os, sys
src_path, dst_path = sys.argv[1:3]
BEGIN = "<!-- BEGIN tether operating defaults (managed by codex/install.sh) -->"
END   = "<!-- END tether operating defaults -->"
block = BEGIN + "\n" + open(src_path).read().strip() + "\n" + END + "\n"
cur = open(dst_path).read() if os.path.exists(dst_path) else ""
if BEGIN in cur and END in cur:                      # replace our managed region
    new = cur[:cur.index(BEGIN)] + block + cur[cur.index(END) + len(END):].lstrip("\n")
    note = "updated tether block; the rest of your AGENTS.md is untouched"
elif cur.strip():                                    # append after your content
    new = cur.rstrip("\n") + "\n\n" + block
    note = "appended tether block; your existing AGENTS.md content is preserved"
else:                                                # fresh file
    new = block
    note = "created"
open(dst_path, "w").write(new)
print(f"• AGENTS   -> {dst_path}  ({note})")
PY

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
echo "Done. Start a new Codex session (skills + hooks load on session start)."
echo "  • Skills auto-trigger by task; or run /skills to browse, or \$catchup to mention one."
echo "  • verify-on-edit + done-gate are active. Arm done-gate per project with a"
echo "    .codex/verify.sh (kept seconds-fast) or the VERIFY_CMD env var."
echo "  • context-health is Claude-Code-only (needs transcript token data Codex does"
echo "    not expose) — its skill installs, but the hook is intentionally NOT wired."
echo "  • Upgrading from the old prompts-based install? You can delete the stale"
echo "    ~/.codex/prompts/{catchup,ship,...}.md files — skills replace them."