# tether marketplace

A Claude Code marketplace hosting one plugin: **tether** — a verification-first,
context-managed agentic harness (deterministic hooks + judgment skills).

## Which tool are you on?

This branch (`main`) is the **Claude Code** plugin. Ports for other agentic tools live on
their own branches — all share the same skills, operating defaults, and verification hooks:

| Branch | Tool | Install |
|---|---|---|
| **`main`** | Claude Code | the two commands below |
| **`codex`** | OpenAI Codex CLI | `git clone -b codex … && bash codex/install.sh` |
| **`opencode`** | opencode | `git clone -b opencode … && bash opencode/install.sh` |
| **`generic`** | any other agentic AI | wire the hooks per `WIRING.md` |

`context-health` (context-pressure nudges) is Claude-Code-only — it needs transcript token
data other tools don't expose; the other branches ship it unwired. See each branch's README.

## Install (Claude Code)

```
/plugin marketplace add stonestephenson/tether-harness
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
