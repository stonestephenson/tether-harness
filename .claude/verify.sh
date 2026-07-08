#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../plugins/tether"
bash tests/context-health.test.sh
bash tests/verify-hooks.test.sh
