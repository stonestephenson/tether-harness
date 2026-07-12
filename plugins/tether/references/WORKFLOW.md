# Project workflow (context-managed + verification-driven)

A per-session loop for working on any project (C/C++, Python, Rust/CMake here),
built on two evidence-backed pillars:

1. **Verification, looped.** The dominant lever in coding-agent research is iterating
   against a *real external verifier* (tests/linters/types) — models can't reliably
   self-correct without one. So the harness supplies cheap, automatic checks and
   feeds failures back.
2. **Context as a finite resource.** Reliability degrades as the window fills
   ("context rot"), so we curate it and keep durable state in artifacts (docs,
   commits, experiment logs), leaving the conversation disposable.

## The loop

```
  NEW / CLEARED SESSION
     └─ /catchup ............ reconstruct state (import context)

  APPROACH (non-trivial work)
     ├─ /council ............ (consequential, hard-to-reverse decision only)
     │                         independent multi-lens critique → you decide
     └─ /plan-change ........ localize → plan → implement → validate
            └─ localize via Explore subagents (read-heavy, returns summaries)

  IMPLEMENT
     ├─ /test-first ......... write the failing test/repro, then satisfy it
     ├─ edit ─► [verify-on-edit HOOK] per-file fmt/lint feedback (auto)
     └─ [context-health HOOK] nudges at 70/85/95% of the window (auto)

  FINISH A CHANGE
     ├─ agent tries to stop ─► [done-gate HOOK] runs .claude/verify.sh (auto)
     │                          └─ red? blocked with failures until green
     └─ /ship ............... full gates + cold review + local commit

  RESEARCH RUNS
     └─ /experiment-log ..... record config/seed/version/metrics (reproducible)

  BEFORE CLEARING
     └─ /handoff ............ verify a cold pickup works, fix docs  (safety gate)

  /clear (your OK) ──► /catchup next session
```

## Tools, by when you reach for them

| Phase | Tool | Kind | What it does |
|---|---|---|---|
| Arrive | `/catchup` | skill | Rebuild state from docs + git/tests/WIP. |
| Approach | `/plan-change` | skill | `localize → plan → implement → validate` for non-trivial work. Gated: skip small edits. |
| Decide (divergent) | `/council` | skill | Independent multi-lens critique of a consequential, hard-to-reverse decision; reports consensus / disagreement / what-needs-verifying. Deliberation aid, not an oracle. Divergent decisions only. |
| Localize / read | `Explore` | subagent | Breadth-first search in an isolated window; returns summaries. Keeps the main thread lean. |
| Implement | `/test-first` | skill | Failing test/repro first, then make it pass. The external-verifier loop. |
| Verify (per edit) | **verify-on-edit** | hook (auto) | Fast file-local fmt/lint on the changed file; feeds diagnostics back. |
| Verify (on finish) | **done-gate** | hook (auto) | Runs the project's fast check on Stop; blocks finishing while it's red. Opt-in. |
| Monitor context | **context-health** | hook (auto) | Measures window occupancy; nudges at 70/85/95%. |
| Decide context | `/context-health` | skill | continue / compact / handoff+clear. Confirms the lossy/destructive steps. |
| Checkpoint | `/ship` | skill | Full gates + **cold** diff review (fresh-context, advisory) + **local** commit. Stops before push/PR. |
| Harden | `/harden` | skill | Compile repeated corrections into mechanical enforcement (linter rule / `verify.sh` check / deny rule). Proposes before writing; provenance-annotated. |
| Research | `/experiment-log` | skill | Record a run so it's reproducible and comparable. |
| Depart | `/handoff` | skill | Prove a zero-context agent could resume; fix doc gaps. |

## The automatic hooks (Layer 1 — triggers, wired in the plugin's `hooks/hooks.json`; a standalone `~/.claude` install wires the same blocks into `settings.json`)

| Hook | Event(s) | Fires | Acts? |
|---|---|---|---|
| `verify-on-edit.py` | `PostToolUse` (Edit/Write/…) | after every file edit | Reports diagnostics (exit 2 → agent sees them). Never rewrites the file. |
| `done-gate.py` | `Stop` | when the agent tries to finish | Blocks the stop if `verify` is red (once per stop cycle — an immediately repeated stop passes; it prods, never traps). Anti-tamper: baselines the verifier's SHA-256 per session; if it changed, flags the user and blocks once with the diff. Opt-in; time-boxed. |
| `context-health.py` | `Stop` + `UserPromptSubmit` | task boundaries | Nudges only; never acts. |
| `pre-compact-guard.py` | `PreCompact` | before a compaction | Blocks a **manual** compact once while the git tree is dirty; re-run `/compact` to override. Auto-compact never blocks. |

All hooks: measure real state, degrade gracefully on missing tools, and **fail open**
— a broken hook never blocks your edits or traps the agent.

## What runs where (per-file vs project-wide)

- **Per edit (verify-on-edit):** real-bug lint (`ruff --select E9,F`, `shellcheck`)
  always; **formatting/style is opt-in** — clang-format / `ruff format` run only when the
  project ships a style config (`.clang-format`, `ruff.toml`/`pyproject.toml`), so
  hand-formatted code isn't churned. Exception: rustfmt and gersemi/cmake-format run
  unconditionally on `.rs`/CMake edits (universal default styles — see HARNESS §4).
  *No* type-checkers here — a lone file would
  spuriously fail to resolve project imports.
- **On finish (done-gate) / `/ship`:** the project-wide checks — type-check
  (pyright/mypy), `clippy`, unit tests. These need the whole project to resolve.

## Grounding (LSP)

Whatever language servers the platform has enabled (e.g. `rust-analyzer`, `clangd`,
`pyright`) give the agent real go-to-def / find-refs / diagnostics instead of guessing
symbols — the ACI insight from SWE-agent. Their diagnostics complement the verify
hooks; the harness ships no LSP config of its own.

## Invariants

1. **Externalize → verify → discard.** Never `/clear` or compact-away un-externalized
   state (doc, commit, experiment log). *Mechanized for manual compaction:* the
   pre-compact-guard hook blocks a manual `/compact` once while the tree is dirty.
2. **Effort scales with irreversibility.** Compact keeps the thread → light notes;
   clear destroys it → full `/handoff`.
3. **Confirm the lossy/destructive steps.** Both COMPACT and CLEAR propose and wait.
4. **Green, not vibes.** "Done" means the verifier passes, not that it looks right.
   Don't weaken a test to pass. Don't self-certify without a signal.
5. **Prevention beats cleanup.** Offload heavy reads to subagents so the thread
   never bloats.
6. **Multi-agent only for breadth-first reading**, never for coupled implementation.
7. **Convergent vs divergent.** Coupled execution (implementing, debugging) → single
   thread + skills + verification; personas/debate hurt there. Divergent decisions
   (design, experiment choice, red-team) → `/council`'s independent lenses help. Match
   the tool to the task's shape; the value is the structure/boundary, never the persona.

## Config

`settings.json` (`env`) or your shell:
- `CLAUDE_CONTEXT_BUDGET` — window tokens; optional override that always wins. When
  unset, context-health maps the transcript's model id to its window (current
  Fable/Opus/Sonnet generation → 1M; unknown → 200k). Keep it set for 200k-default
  models running the `[1m]` beta (the suffix never appears in the transcript).
- `CTX_WARN` / `CTX_ACT` / `CTX_CRIT` — bands (`.70` / `.85` / `.95`).
- `CLAUDE_VERIFY_CMD` — command the done-gate runs on Stop (overrides the file below).

Those are the only runtime knobs. Everything else — subprocess timeouts, output caps,
the `MODEL_BUDGETS` model→window map, the `C_FAMILY`/`EDIT_TOOLS` sets — is a constant
at the top of the relevant hook; tune by editing source (and extend the suite).

Per project, opt into the done-gate by creating **`.claude/verify.sh`** — a FAST
check (seconds), e.g.:
```bash
#!/usr/bin/env bash
set -e
ruff check . && pyright        # python
cargo clippy -q --all-targets  # rust
ctest --output-on-failure      # c/c++ (or your fast unit subset)
```

Belt-and-suspenders (optional): deny tool-based edits to the verifier in the
project's `.claude/settings.json` — the gate's hash check still catches
shell-based writes:
```json
"permissions": { "deny": ["Edit(./.claude/verify.sh)", "Write(./.claude/verify.sh)"] }
```

Activate the linters the verify hook uses (all optional — a missing tool is skipped;
rustfmt/clippy come with a Rust toolchain if you have one):
```bash
pip install ruff pyright           # python lint/format + types
brew install clang-format          # c/c++ format (opt-in via .clang-format)
pip install gersemi                # cmake format   (optional)
brew install shellcheck            # shell lint     (optional)
```

Regression tests: from `plugins/tether/`, `bash tests/context-health.test.sh` and
`bash tests/verify-hooks.test.sh` — or `bash .claude/verify.sh` from the repo root.
Disable any hook: remove its block from the plugin's `hooks/hooks.json` (or, in a
standalone `~/.claude` install, from `settings.json`). Skills still work either way.
