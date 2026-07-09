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
| **`opencode`** | ✅ verified live on **1.17.15** (2026-07) | edit → lint → agent-fix loop closes (agent removed an unused import after an `F401`); done-gate **failing path verified live** (`session.idle` → failing `.tether/verify.sh` surfaces the block, repeatedly). Also drives a **local model** now (qwen3-coder via Ollama @ 64k ctx — see `opencode/LOCAL-MODELS.md`). Caveat: done-gate is reliable **interactively**; under headless `opencode run` the process can exit before the async hook writes. |
| **`codex`** | ✅ verified live on **0.143.0** (2026-07) | Codex's hooks are a near-clone of Claude Code's (same events + JSON stdin/stdout), so both fire in an authenticated turn: verify-on-edit parses `apply_patch` (V4A) payloads and blocks the edit with lint feedback; done-gate blocks a failing finish via `{"decision":"block"}`. Skills ship as **native Codex skills** (`~/.codex/skills/`); the installer merges a tether block into `AGENTS.md` without clobbering an existing one. `context-health` stays unwired (needs transcript tokens Codex doesn't expose). |
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
