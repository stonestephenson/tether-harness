# tether

A verification-first, context-managed agentic harness for Claude Code — deterministic
hooks plus judgment skills, grounded in the research on context rot and external-feedback
verification. `references/HARNESS.md` has the full "what / why / when" of every piece and
the evidence base; `references/WORKFLOW.md` has the per-session loop.

## What you get

**Hooks (automatic — you never invoke these):**
- **context-health** (`Stop` + `UserPromptSubmit`) — measures how full the context window
  is from real transcript token counts and nudges at 70 / 85 / 95%. Never acts. Window
  size auto-detected from the model id; `CLAUDE_CONTEXT_BUDGET` overrides.
- **verify-on-edit** (`PostToolUse`) — after each edit, runs **real-bug lint**
  (`ruff --select E9,F`, `shellcheck`) everywhere; **formatting/style is opt-in**
  (clang-format, `ruff format`) and runs only when the project ships a style config
  (`.clang-format`, or any `ruff.toml`/`pyproject.toml`), so hand-formatted code isn't
  churned. Exception: `rustfmt` and `gersemi`/`cmake-format` run on every `.rs`/CMake
  edit unconditionally — those toolchains define one universal default style.
- **done-gate** (`Stop`) — runs a project's `.claude/verify.sh` when the agent finishes and
  blocks on failure — once per stop cycle (the loop guard lets an immediately repeated
  stop through rather than trapping the agent). Opt-in per project; fails open.
  Anti-tamper: baselines the verifier's SHA-256 per session and flags + blocks once if
  it changes mid-session (limits: the baseline starts at the first finish, and scripts
  the verifier *calls* aren't hashed — see `HARNESS.md` §4).
- **pre-compact-guard** (`PreCompact`) — blocks a **manual** `/compact` once while the git
  tree has un-externalized changes (run `/ship` / `/handoff` first, or re-run `/compact`
  to override). Auto-compaction never blocks; fails open.

**Skills:** `/catchup`, `/context-health`, `/handoff`, `/ship` (session lifecycle);
`/plan-change`, `/test-first`, `/council`, `/harden` (execution quality);
`/experiment-log` (research).

## Install

```
/plugin marketplace add stonestephenson/tether-harness
/plugin install tether@tether
```

Hooks start firing and skills become available the next session.

## Prerequisites (optional — hooks degrade gracefully if a tool is missing)

The verify hooks use whatever is installed:

```
pip install ruff pyright          # Python real-bug lint (+ types for verify.sh)
brew install clang-format         # C/C++ format (only runs with a .clang-format)
brew install shellcheck           # shell lint
# rustfmt / clippy ship with the Rust toolchain
```

## Per-project: arm the done-gate

`done-gate` runs only if the project defines a fast check. Add `.claude/verify.sh` to a repo
(keep it seconds-fast) — or set `CLAUDE_VERIFY_CMD`:

```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright          # python example
cargo clippy -q --all-targets    # rust example
ctest --output-on-failure        # c/c++ example (a fast subset)
```

## Config (env vars, all optional)

- `CLAUDE_CONTEXT_BUDGET` — window size in tokens; always wins when set. When unset, the
  budget is auto-mapped from the transcript's model id (current-gen models → 1M; unknown
  ids → `200000`). Set it only for a 200k-default model running the `[1m]` beta (that
  suffix never appears in the transcript) or to override the map.
- `CTX_WARN` / `CTX_ACT` / `CTX_CRIT` — band fractions (default `.70` / `.85` / `.95`).
- `CLAUDE_VERIFY_CMD` — command the done-gate runs on finish (overrides `.claude/verify.sh`).

## Tests

From this directory (`plugins/tether/`):

```
bash tests/context-health.test.sh    # 18 checks
bash tests/verify-hooks.test.sh      # 46 checks (verify-on-edit, done-gate + tamper, pre-compact-guard)
```

Or one command from the repo root: `bash .claude/verify.sh` (runs both — it's this
repo's own done-gate).

## Developing tether (maintainers)

The edit→verify loop for hook changes: edit the hook, extend the matching suite in
`tests/`, and keep `bash .claude/verify.sh` green (every branch has one). Runtime knobs
are the env vars above; everything else (`TIMEOUT`, output caps, `MODEL_BUDGETS`, the
`C_FAMILY`/`EDIT_TOOLS` sets) is a constant at the top of the relevant hook — edit
source to tune. The suites drive the hooks headlessly by piping the documented JSON
payloads, so no Claude Code session is needed for regression coverage. Bump
`.claude-plugin/plugin.json`'s `version` when user-visible behavior lands.

To live-verify in a real session **without touching your own install**, use a sandboxed
config dir and add the working tree as a local marketplace:

```
CLAUDE_CONFIG_DIR=$(mktemp -d) claude
> /plugin marketplace add /path/to/tether-harness
> /plugin install tether@tether        # then restart the session
```

Per-hook live trips: edit a `.py` file with an unused import (verify-on-edit feedback);
add a failing `.claude/verify.sh` and try to finish (done-gate block); weaken that
verify.sh and finish green (one-time tamper block); `/compact` with a dirty tree
(pre-compact-guard block, re-run to override).

## Notes vs. a manual `~/.claude` install

- Hooks live in the plugin (`${CLAUDE_PLUGIN_ROOT}/hooks`), **not** your `settings.json` —
  so installing or removing the plugin is clean and never edits your config.
- `references/WORKFLOW.md` / `HARNESS.md` describe the standalone `~/.claude` layout for
  background; under the plugin the mechanics are identical, just relocated.
- The operating defaults (run `/catchup` on arrival, `/ship` when a change lands, respond to
  context-health nudges, verify-don't-self-certify) live inside the skills. If you also want
  them as always-loaded guidance, add a short pointer to your own `~/.claude/CLAUDE.md`.
