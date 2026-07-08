#!/usr/bin/env bash
# Installer for the tether harness — opencode edition.
# Copies commands + the verification plugin + shared hook scripts into
# ~/.config/opencode. Local plugins and commands auto-load; no config edit needed.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"                 # the opencode/ dir
OC="${OPENCODE_CONFIG:-$HOME/.config/opencode}"
mkdir -p "$OC/commands" "$OC/plugins" "$OC/tether/hooks"

echo "• commands -> $OC/commands       (invoke as /<name>)"
cp "$SRC/commands/"*.md "$OC/commands/"
echo "• plugin   -> $OC/plugins"
cp "$SRC/plugins/"*.js "$OC/plugins/"
echo "• hooks    -> $OC/tether/hooks"
cp "$SRC/hooks/"*.py "$OC/tether/hooks/"
echo "• AGENTS   -> $OC/AGENTS.md"
cp "$SRC/../AGENTS.md" "$OC/AGENTS.md"

echo
echo "Done. Restart opencode to load the plugin + commands."
echo "NOTE: context-health is Claude-Code-only (needs transcript token data) and is not"
echo "      wired here. verify-on-edit runs on tool.execute.after (edit/write);"
echo "      done-gate on session.idle. Arm done-gate with a .tether/verify.sh"
echo "      (or .codex / .claude) or \$VERIFY_CMD."
