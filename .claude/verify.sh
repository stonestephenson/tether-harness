#!/usr/bin/env bash
# Done-gate for the opencode branch: runs the opencode hook regression suite.
set -e
cd "$(dirname "$0")/.."
bash opencode/tests/verify-hooks.test.sh
