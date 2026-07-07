# tether harness — generic / tool-agnostic (`generic` branch)

For any agentic AI **not** covered by the tool-specific branches
(`main` = Claude Code, `codex` = OpenAI Codex CLI, `opencode` = opencode). This branch ships
the harness as portable parts you wire into whatever tool you use.

## What's here

- **`AGENTS.md`** — the operating defaults. Most agentic tools read `AGENTS.md`; drop it in
  your project root or your tool's global config.
- **`skills/`** — the eight playbooks as plain markdown. Use them as your tool's custom
  commands/prompts, or just follow them.
- **`hooks/`** — the three deterministic verification/context scripts (standalone).
- **`WIRING.md`** — the hook contract (JSON in → exit-2 + stderr out) and how to connect the
  scripts to your tool's event system.
- **`references/`** — `HARNESS.md` (what/why/when + the research), `WORKFLOW.md` (the loop).

## How portable is each part

| Part | Portability |
|---|---|
| `AGENTS.md` + skills | ✅ anywhere — plain markdown; `AGENTS.md` is widely read |
| verify-on-edit + done-gate | ✅ any tool with a shell/command or plugin hook system — wire per `WIRING.md` |
| context-health | ⚠️ Claude-Code-specific (needs transcript token counts); no-ops elsewhere |

## Quick start

1. Put `AGENTS.md` where your tool reads instructions (project root, or its global config).
2. Make the skills invokable — copy them into your tool's command/prompt directory, or keep
   them as playbooks to follow.
3. Wire `hooks/` into your tool's lifecycle events — see **`WIRING.md`**.
4. Add a fast `.tether/verify.sh` to arm the done-gate.

Prereqs (optional; checks skip a missing tool): `ruff`, `pyright`, `clang-format`,
`shellcheck`; `rustfmt`/`clippy` come with Rust. The hooks need `python3` on PATH.

## The other branches

| Branch | Tool | Install |
|---|---|---|
| `main` | Claude Code | `/plugin marketplace add stonestephenson/tether-harness` + `/plugin install tether@tether` |
| `codex` | OpenAI Codex CLI | `bash codex/install.sh` |
| `opencode` | opencode | `bash opencode/install.sh` |
| `generic` | anything else | this branch — wire per `WIRING.md` |
