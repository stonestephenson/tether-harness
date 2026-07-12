#!/usr/bin/env bash
# Done-gate for the generic branch: runs the hook regression suite.
set -e
cd "$(dirname "$0")/.."
bash tests/verify-hooks.test.sh
