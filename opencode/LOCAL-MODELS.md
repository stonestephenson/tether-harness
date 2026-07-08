# Running the tether harness on a local model (opencode) — findings

> **Status: SOLVED (2026-07-08).** Local models now drive opencode's full agentic loop *and*
> the tether verification loop. The blocker was **Ollama's default 4096-token context window
> truncating opencode's tool prompt** — not the provider, not the harness. Raise it to ≥64k and
> `qwen3-coder:30b` and `gpt-oss:20b` both complete the loop. History and diagnostics kept below.

**Goal:** run opencode + the tether harness against a *local* model (privacy/offline/cost),
picking the best coding model for the hardware.

**Test machine:** Apple **M1 Max, 32 GB** unified memory, macOS. Ollama **0.31.1**, opencode **1.17.15**.

---

## TL;DR — the fix (three things, in priority order)

1. **Raise Ollama's context window to ≥64k. THIS was the real blocker.** Ollama defaults *every*
   model to a **4096-token** context, even when the weights support 128k+. opencode's tool +
   system prompt is **~8.8k tokens** (measured), so at 4096 it was silently truncated and the
   model **never saw the tool definitions** — which is why models narrated, recited tool syntax as
   text, or said "I can't edit files." Set it on the server:

   ```bash
   OLLAMA_CONTEXT_LENGTH=65536   # opencode's own Ollama docs say "64k or higher"
   ```
   Apply it to the running server, e.g. `launchctl setenv OLLAMA_CONTEXT_LENGTH 65536 && brew services restart ollama`
   (see **Making it durable** below — brew regenerates the plist, so the naive edits don't stick).

2. **Ollama ≥ 0.31.** Older Ollama (the machine started on 0.23.0) ships broken/incomplete per-model
   tool templates — gpt-oss leaked harmony tokens, Devstral wouldn't emit structured tool calls.
   `brew upgrade ollama && brew services restart ollama` — **models are preserved** (`~/.ollama`).

3. **`tool_call: true` on every custom model entry in `opencode.jsonc`.** Without it opencode assumes
   the model has no function-calling and text-describes tools. Necessary, but on its own it does
   nothing while the prompt is being truncated at 4096 — which is why #1 had to come first.

All three are necessary. #2 and #3 were found first (and documented here as "necessary but not
sufficient"); **#1 is what actually closed the gap.** The `@ai-sdk/openai-compatible` `/v1` shim is
**fine** — no native-provider swap is needed (an earlier version of this doc wrongly suspected it).

---

## Reference `opencode.jsonc` (verified working)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": { "baseURL": "http://localhost:11434/v1", "apiKey": "ollama" },
      "models": {
        // tool_call:true is REQUIRED — without it opencode text-describes tools.
        // The other half of the fix is server-side: OLLAMA_CONTEXT_LENGTH=65536.
        "qwen3-coder:30b":  { "name": "Qwen3-Coder 30B (local)",            "tool_call": true },
        "gpt-oss:20b":      { "name": "gpt-oss 20B (local, agentic)",        "tool_call": true, "reasoning": true },
        "devstral:latest":  { "name": "Devstral 24B (local, agentic-coding)","tool_call": true }
      }
    }
  }
}
```

---

## Reproducible test harness (no TUI eyeballing)

The key to debugging this was driving opencode **headlessly** and checking the file actually changed:

```bash
opencode run --auto --format json --dir "$PROJ" -m ollama/qwen3-coder:30b \
  "Add a factorial(n) function to fib.py that computes n! iteratively."
grep -q "def factorial" "$PROJ/fib.py" && echo PASS || echo FAIL   # objective signal
# inspect tool calls in the JSON stream:  grep -oE '"tool":"[a-z_]+"' log.json | sort | uniq -c
```

`--auto` auto-approves permissions; `--format json` streams `tool_use` events so you can see
whether opencode sent a real tool call or the model emitted text.

## Results (Ollama 0.31.1, opencode 1.17.15, 64k context)

| Model | Ollama tag | Size | Verdict at **4096** (old) | Verdict at **64k** (fixed) |
|---|---|---|---|---|
| **Qwen3-Coder-30B-A3B** | `qwen3-coder:30b` | 18 GB | ❌ drifted, recited tools as text | ✅ **clean** — `glob→read→edit`, and **self-corrected** an F401 from verify-on-edit. **Recommended driver.** |
| **gpt-oss-20b** | `gpt-oss:20b` | 13 GB | ❌ reached for OpenAI-native tools | ✅ works — but first tries a trained-in `apply_patch` (errors `invalid`), then recovers with `edit`. Usable, slightly wasteful. |
| **Devstral-Small-24B** | `devstral:latest` | 14 GB | ❌ "I can't modify files" | ❌ still narrates ("let me check if fib.py exists") but emits **no tool call**. Model-specific — same transport qwen/gpt-oss succeed on. Avoid for now. |

**End-to-end harness proof (qwen3-coder):** asked for factorial *plus* an unused `import json`.
qwen added both → `verify-on-edit` caught `F401 json imported but unused` and fed it back → qwen
made a second edit **removing the import**. That is the full tether loop — external-feedback
verification driving self-correction — running on a local model.

## Making the context setting durable

`brew services` **regenerates** the launchd plist from the stock homebrew formula on every
`brew services …` command (the stock formula ships `OLLAMA_FLASH_ATTENTION`/`OLLAMA_KV_CACHE_TYPE`
but not `OLLAMA_CONTEXT_LENGTH`). So editing the plist **or** `.brew/ollama.rb` is **inert** — the
next restart wipes it. Two durable options:

- **Login agent (used on the test machine).** `~/Library/LaunchAgents/com.tether.ollama-ctx.plist`
  with `RunAtLoad` running `launchctl setenv OLLAMA_CONTEXT_LENGTH 65536; brew services restart ollama`.
  Survives reboot; remove with `launchctl bootout gui/$(id -u)/com.tether.ollama-ctx && rm` the plist.
- **Bake it per model.** `ollama run qwen3-coder:30b` → `/set parameter num_ctx 65536` → `/save qwen3-coder:30b-64k`,
  then point the config at the new tag. Survives everything (incl. brew upgrades) but is per-model.

## Performance data point

`qwen3-coder:30b` (4-bit MoE, ~3B active, Ollama, M1 Max): **~52 tok/s decode, ~45 tok/s prompt
eval**, ~8.6 s first-load. A full 3–4 step edit task completes in ~25–90 s. The MoE speed advantage
makes 30B-class models genuinely usable locally.

## Bottom line

On a 32 GB M1 Max via Ollama, the tether harness runs on a local model today: use
**`qwen3-coder:30b`** with **`OLLAMA_CONTEXT_LENGTH=65536`**, Ollama ≥ 0.31, and `tool_call: true`.
`gpt-oss:20b` is a working fallback; `devstral` is not yet reliable in opencode. The one setting that
mattered most was the context window — at Ollama's 4096 default, *nothing* works.
