# tether marketplace

A Claude Code marketplace hosting one plugin: **tether** — a verification-first,
context-managed agentic harness (deterministic hooks + judgment skills).

## Install

```
/plugin marketplace add <git-url-of-this-repo>
/plugin install tether@tether
```

The plugin lives in [`plugins/tether/`](plugins/tether/) — see its
README for what it does, prerequisites, per-project setup, configuration, and tests.

## Layout

```
.claude-plugin/marketplace.json     # this marketplace
plugins/tether/            # the plugin
  .claude-plugin/plugin.json
  hooks/        context-health.py, verify-on-edit.py, done-gate.py, hooks.json
  skills/       catchup, context-health, handoff, ship, plan-change,
                test-first, council, experiment-log
  references/   HARNESS.md (what/why/when + evidence), WORKFLOW.md (the loop)
  tests/        hook regression suites
```
