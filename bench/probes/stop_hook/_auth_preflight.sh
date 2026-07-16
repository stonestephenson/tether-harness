#!/usr/bin/env bash
# require_oauth_token — fail fast (before spending a doomed run) if the sandbox
# has no way to authenticate. A fresh CLAUDE_CONFIG_DIR does NOT inherit the
# macOS-keychain login, so sandboxed headless runs need CLAUDE_CODE_OAUTH_TOKEN
# (from `claude setup-token`). This is the runner's auth mechanism too.
# Never prints the token value.
require_oauth_token() {
  if [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    return 0
  fi
  cat >&2 <<'MSG'
[auth] CLAUDE_CODE_OAUTH_TOKEN is not set.
A sandboxed CLAUDE_CONFIG_DIR does not inherit your keychain login, so the run
would fail with "Not logged in · Please run /login".

One-time fix (uses your subscription — zero API cost):
    claude setup-token                          # interactive; prints a token
    export CLAUDE_CODE_OAUTH_TOKEN='<paste it>' # in THIS shell
Then re-run this script in the same shell. Never commit the token.
MSG
  return 1
}
