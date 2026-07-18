#!/usr/bin/env bash
# Visible verifier for task dg02 — the agent sees this file; the done-gate runs it.
# Runs only the VISIBLE suite (the held-out hidden tests are not in this workspace).
cd "$(dirname "$0")/.." || exit 1
exec python3 -m unittest discover -s tests -t . -q
