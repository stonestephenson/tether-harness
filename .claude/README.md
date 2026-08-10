# `.claude/` — maintainer tooling (not shipped)

Everything here serves the person maintaining this repo. **None of it is part of the
tether plugin**, none of it reaches tether users, and none of it is subject to the
ROADMAP's new-scaffolding burden of proof — that rule governs `plugins/tether/`, which
is the product. Kept in this repo for version control and because `.claude/verify.sh`
can gate it.

| Piece | What it is |
|---|---|
| `verify.sh` | The repo's done-gate. Runs both plugin suites, this directory's suite, and the doc-link check. |
| `skills/sota-radar/` | The monthly SOTA sweep. Read-only; proposes, never edits `ROADMAP.md`. |
| `hooks/plain-english.py` | Stop hook: renders the agent's last message as a plain-English triage panel via a local model. |
| `tests/plain-english.test.sh` | 22 hermetic checks for the above (stub HTTP server; no model needed). |

---

## `plain-english.py`

**Why it exists.** Opus 5 writes long. The work is right, but finding *what it's asking
of you* inside a thousand words is slow. This renders each response into a fixed
four-heading panel — BOTTOM LINE / NEEDS YOU / WHAT CHANGED / WATCH OUT — in a second
pane you glance at when a response is dense.

**It is a reading aid, not a replacement.** The panel can be wrong in ways the original
is not. Treat a disagreement between panel and response as the panel being wrong.

### Setup

```sh
ollama pull qwen3:8b
mkdir -p ~/.claude/plain
```

Wire it as a `Stop` hook in `~/.claude/settings.json`:

```json
{ "hooks": { "Stop": [ { "hooks": [ {
  "type": "command",
  "command": "python3 ~/.claude/hooks/plain-english.py"
} ] } ] } }
```

Then keep a pane open beside your session:

```sh
tail -f ~/.claude/plain/$(ls -t ~/.claude/plain | head -1)   # newest session
```

### Configuration

| Env var | Default | Notes |
|---|---|---|
| `PLAIN_DISABLE` | unset | Any value turns it off. |
| `PLAIN_MODEL` | `qwen3:8b` | **Thinking must stay on** — see the measurement below. |
| `PLAIN_MIN_CHARS` | `1200` | Shorter replies are skipped; they don't need triaging. |
| `PLAIN_NUM_CTX` | `16384` | Must exceed prompt + message. Too small silently truncates. |
| `PLAIN_TIMEOUT` | `150` | Seconds. |
| `PLAIN_DIR` | `~/.claude/plain` | One append-only `<session>.md` per session. |
| `PLAIN_OLLAMA_URL` | `http://127.0.0.1:11434/api/chat` | |

### The three properties the tests exist to protect

1. **It never touches the model's context.** Empty stdout, always — no
   `additionalContext`, no `systemMessage`. Injecting anything would alter the very
   output we're trying to read unmodified, which defeats the point.
2. **It costs the turn nothing.** Inference is ~18s median / ~28s p90. The hook forks a
   detached worker and returns in milliseconds; the panel lands a beat after the
   response. Tested at <1500ms.
3. **It fails open and silent.** Ollama down, model missing, disk full — exit 0, empty
   stdout, and the *reason* written to the pane so a blank panel is never ambiguous.

### Why `qwen3:8b` with thinking on

Measured 2026-08-10 over 20 real responses from 20 sessions across 6 projects, on an
M1 Max / 32GB. "Ask missed" = the original contained an explicit question and the
summary's NEEDS YOU said "Nothing — FYI only" — a false negative on the field the tool
exists to produce.

| config | med s | p90 s | ask missed | hedges kept |
|---|--:|--:|--:|--:|
| **`qwen3:8b` thinking on** | 18.2 | 27.7 | **0/11 (0%)** | 15/18 |
| `gemma3:12b` | 17.1 | 20.6 | 3/11 (27%) | 9/18 |
| `qwen3:8b` thinking off | 6.6 | 9.2 | 4/11 (36%) | 9/18 |
| `llama3.1:8b` | 6.6 | 9.4 | 8/11 (73%) | 12/18 |
| `qwen3:4b` | 116+ | — | — | ignores the word cap (3272 words) |

Two findings worth keeping:

- **Speed and accuracy are the same axis, and it is steep.** Every config fast enough to
  feel instant misses the ask a third to three-quarters of the time. `llama3.1:8b` is
  fastest and worst — it reports "Nothing — FYI only" on 8 of 11 messages that contained
  a real question, which is worse than no tool, because the failure is silent and lands
  exactly where you'd rely on it.
- **The thinking tokens do the work.** Turning thinking off on the same model with the
  same prompt is a clean 2.8× speedup that takes it from 0% missed to 36% missed. You
  cannot buy the speed without buying the regression. **Don't "optimise" this by setting
  `PLAIN_MODEL` to something faster without re-running the bake-off.**

### Known limits

- Only the model→panel step is measured. Whether the BOTTOM LINE is the sentence *you*
  would have written was judged by eye over 20 samples, not scored.
- Hedge retention is 15/18 — roughly one caveat-bearing response in six loses its caveat.
  This is the residual risk, and it is why the panel is a reading aid, not a substitute.
- 20 samples separate 0% from 73% confidently; they do not separate 0% from 10%.
- macOS/Linux only (`start_new_session`), same as the rest of the harness.
