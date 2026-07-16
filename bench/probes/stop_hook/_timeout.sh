#!/usr/bin/env bash
# portable_timeout SECONDS COMMAND [ARGS...]
# A wall-clock cap that works without GNU coreutils. macOS ships no `timeout`,
# and this study runs on the author's Mac, so the runner needs this too. Returns
# the command's exit code, or 124 if the cap fired (matching GNU `timeout`).
# Safe under `set -e` (all fallible steps are guarded).
portable_timeout() {
  local secs="$1"; shift
  local rc=0
  if command -v timeout  >/dev/null 2>&1; then timeout  "$secs" "$@" || rc=$?; return "$rc"; fi
  if command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@" || rc=$?; return "$rc"; fi
  # Pure-bash fallback: run in the background, watchdog kills it after the cap.
  local marker; marker="$(mktemp)"; rm -f "$marker"
  "$@" &
  local pid=$!
  ( sleep "$secs"; : > "$marker"; kill -TERM "$pid" 2>/dev/null
    sleep 3; kill -KILL "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local wpid=$!
  wait "$pid" || rc=$?
  kill "$wpid" >/dev/null 2>&1 || true
  wait "$wpid" 2>/dev/null || true
  if [ -f "$marker" ]; then rm -f "$marker"; return 124; fi
  return "$rc"
}
