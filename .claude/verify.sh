#!/usr/bin/env bash
# Done-gate for the codex branch: runs the Codex hook regression suite.
set -e
cd "$(dirname "$0")/.."
bash codex/tests/verify-hooks.test.sh
