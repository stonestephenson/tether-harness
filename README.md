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

## Port status (what's verified, what's next)

| Branch | State | Notes |
|---|---|---|
| **`main`** (Claude Code) | ✅ verified end-to-end | hooks fire, skills load, regression suites pass |
| **`opencode`** | ✅ verified live on **1.17.14** (2026-07) | edit → lint → agent-fix loop closes (agent removed an unused import after an `F401`); done-gate runs on `session.idle`. **Pending:** live check of the done-gate *failing* path (drop a failing `.tether/verify.sh`, go idle). |
| **`codex`** | ⏳ ported, **not yet live-smoke-tested** — next step | hook model mirrors Claude Code's (PostToolUse/Stop, JSON stdin, exit-2); needs a real Codex session to confirm `apply_patch` path extraction and `Stop`-block behavior on the installed version. |
| **`generic`** | 📄 wiring documented (`WIRING.md`) | verify per-tool when adopting |

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
