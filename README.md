# tether

**tether** is a verification-first, context-managed harness for agentic coding tools —
a layer of deterministic **hooks** plus judgment **skills** that wraps an AI coding agent
(Claude Code, OpenAI Codex, opencode, …) to make it markedly more reliable and efficient.

## Why an agent is better with tether

An LLM coding agent has two structural weaknesses. It works inside a **finite context
window** that quietly degrades as it fills, and it **cannot reliably tell when it's wrong
on its own**. Unaided, agents confidently "finish" code that doesn't compile, get sloppier
as the conversation grows, and lose the thread between sessions.

tether is the scaffolding that compensates for exactly those two limits:

- **Verification, looped.** Deterministic hooks feed the agent real external signals: after
  every edit a linter hands the errors straight back, and the agent *can't finish* a task
  until the project's own checks pass. It corrects against ground truth instead of
  self-certifying.
- **Context, curated.** A hook measures how full the window is and nudges *before* the model
  degrades; skills push durable state into commits, docs, and logs so the conversation stays
  disposable and a fresh session resumes cleanly.
- **Judgment, on tap.** Skills for the high-leverage moments — plan before diving in, drive
  from a failing test, pressure-test an irreversible decision, hand off so the next agent
  can pick up cold.

The net effect: the agent stays **correct** (because it verifies), stays **sharp** (because
the context stays curated), and stays **resumable** (because state lives in durable
artifacts) — instead of drifting, self-certifying, and forgetting.

**Grounded in research, not anecdote.** Every design choice traces to a published finding —
that LLMs can't self-correct without an external signal, that performance "rots" as context
fills, that iterating against tests beats one-shot generation, and more. The evidence base
is in [`HARNESS.md`](plugins/tether/references/HARNESS.md) §10, with full citations and links
in [`PAPERS.md`](plugins/tether/references/PAPERS.md).

## Which branch do I use?

tether ships one branch per tool — all sharing the same skills, operating defaults, and
verification hooks. Pick the branch for your agent:

| Branch | Your tool | Install |
|---|---|---|
| **`main`** | Claude Code | the two commands under *Install* below |
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

This branch (`main`) is the Claude Code edition, distributed as a one-plugin marketplace:

```
/plugin marketplace add stonestephenson/tether-harness
/plugin install tether@tether
```

The plugin lives in [`plugins/tether/`](plugins/tether/) — see its README for what it does,
prerequisites, per-project setup, configuration, and tests. (Using a different tool? See the
branch table above.)

## Layout (main branch)

```
.claude-plugin/marketplace.json     # this marketplace
plugins/tether/            # the plugin
  .claude-plugin/plugin.json
  hooks/        context-health.py, verify-on-edit.py, done-gate.py, hooks.json
  skills/       catchup, context-health, handoff, ship, plan-change,
                test-first, council, experiment-log
  references/   HARNESS.md (what/why/when + evidence), PAPERS.md (bibliography),
                WORKFLOW.md (the loop)
  tests/        hook regression suites
```
