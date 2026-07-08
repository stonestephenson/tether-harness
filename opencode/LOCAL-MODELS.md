# Running the tether harness on a local model (opencode) — findings

> **Status: PARKED / UNRESOLVED (2026-07).** Two integration fixes were found and are
> *necessary but not sufficient*: local models still would not reliably drive opencode's
> full agentic loop on the test machine. This documents what was tried, the root causes
> found, and the ranked next steps so a future session can resume without re-deriving it.

**Goal:** run opencode + the tether harness against a *local* model (privacy/offline/cost),
picking the best coding model for the hardware.

**Test machine:** Apple **M1 Max, 32 GB** unified memory, macOS. Serving via **Ollama**.

---

## TL;DR — the two things that actually matter (but weren't enough)

1. **Ollama ≥ 0.31.** The machine started on **0.23.0** (8 minor versions behind). Upgrading to
   **0.31.1** fixed gpt-oss harmony-token leakage and made Devstral emit structured tool calls
   via the raw API. Older Ollama ships broken/incomplete per-model tool templates.
   `brew upgrade ollama && brew services restart ollama` — **models are preserved** (stored in
   `~/.ollama`, independent of the binary), so no multi-GB re-download.

2. **`tool_call: true` on every custom model entry in `opencode.jsonc`.** Without it, opencode
   assumes the model has **no function-calling** and falls back to *describing tools as text* in
   the prompt. That is what made every local model misbehave (see failure log). See the reference
   config below.

Even with **both** applied, the models still failed in the real opencode loop. The problem is the
**local-model ↔ Ollama ↔ opencode tool-calling integration**, not the models (all three write
correct code in isolation) and not the harness (the hooks never got a fair run — no model
completed an edit).

---

## Reference `opencode.jsonc` (the correct starting point)

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "ollama": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Ollama (local)",
      "options": { "baseURL": "http://localhost:11434/v1", "apiKey": "ollama" },
      "models": {
        // tool_call:true is REQUIRED — without it opencode text-describes tools and
        // local models hallucinate/recite tools instead of calling them.
        "qwen3-coder:30b":  { "name": "Qwen3-Coder 30B (local)",            "tool_call": true },
        "gpt-oss:20b":      { "name": "gpt-oss 20B (local, agentic)",        "tool_call": true, "reasoning": true },
        "devstral:latest":  { "name": "Devstral 24B (local, agentic-coding)","tool_call": true }
      }
    }
  }
}
```

---

## Models evaluated (all fit 32 GB; all write correct code standalone)

| Model | Ollama tag | Size (4-bit) | Why picked |
|---|---|---|---|
| **Qwen3-Coder-30B-A3B** | `qwen3-coder:30b` | 18 GB | MoE, ~3B active → fast on Apple Silicon; strong coding + long context. **52 tok/s decode measured** on this M1 Max. |
| **gpt-oss-20b** | `gpt-oss:20b` | 13 GB | OpenAI open weights, heavy tool-use training, MoE (fast), most memory headroom. |
| **Devstral-Small-24B** | `devstral:latest` | 14 GB | Mistral; purpose-built for *agentic* coding (OpenHands scaffold), tops open SWE-bench in an agent loop. |

## Failure log (each model failed differently — the diagnostic value)

Same prompt every time: *"Add a `factorial(n)` function to fib.py that computes n! iteratively."*

| Model | Failure mode in opencode | What it told us |
|---|---|---|
| qwen3-coder:30b | Drifts (reads file, then asks *you* what to do), then emits `<function=todowrite>` / `</tool_call>` **as text**; spirals inventing todos. | Mangles meta-tools under the full tool load. |
| gpt-oss:20b | Tries to call `container.exec` — an **OpenAI-native** tool that doesn't exist in opencode. Pre-upgrade also leaked `<\|channel\|>analysis` harmony tokens into the tool name. | Harmony-format handling; reaches for trained-in tools. |
| devstral:latest | **Emits no tool calls at all** — "I don't have the capability to modify files." Yet returns a clean `read` tool call against the **raw Ollama `/v1` API**. | Tools weren't reaching the model *through opencode*. |

**The pivotal observation:** Devstral tool-calls correctly against `curl …/v1/chat/completions`
with a `tools` param, but does nothing in opencode → opencode wasn't sending native tools →
root cause was the missing `tool_call: true`. After adding it (and restarting opencode), the
models still failed — so at least one more layer remains broken.

---

## Next steps to resume (ranked)

1. **Swap the provider off the `/v1` OpenAI-compat shim.** Try opencode's native Ollama provider
   (e.g. `ollama-ai-provider-v2`, or the models.dev `ollama` provider) which speaks Ollama's
   native `/api/chat` with first-class tool support. **Top suspect now** — the `@ai-sdk/openai-compatible`
   `/v1` shim round-tripped single tool calls in isolation but not opencode's multi-tool loop.
2. **Trim opencode's tool surface** with a restricted primary agent (schema verified):
   ```jsonc
   { "agent": { "local": { "mode": "primary", "model": "ollama/devstral:latest",
     "permission": { "task": "deny", "todowrite": "deny", "skill": "deny",
                     "webfetch": "deny", "websearch": "deny" } } } }
   ```
   Both prior failures got tangled in the meta-tools (`task`/`todowrite`). Denying `question` too
   would stop a model bailing out to ask instead of acting (the 30B's drift).
3. **Raise Ollama's context window.** Default `num_ctx` may truncate the tool/system prompt.
   Set `options.num_ctx` (e.g. 32768) in the provider config or a custom Modelfile.
4. **Different serving stack.** LM Studio (MLX + its own tool-call parser, native gpt-oss harmony
   support) or `mlx-lm` — MLX is also ~20–40% faster on Apple Silicon.
5. **Accept the split (fallback).** Use local models for single-file edits / generation / offline
   work, and **Claude for the full agentic loop** — sustained multi-step tool orchestration is the
   hardest thing to run locally, harder than raw code generation.

## Performance data point

`qwen3-coder:30b` (4-bit, Ollama, M1 Max): **~52 tok/s decode, ~45 tok/s prompt eval**, ~8.6 s
first-load. The MoE (~3B active) speed advantage is real and makes 30B-class models usable locally
— *when* the tool-calling integration works.

## Bottom line

On a 32 GB M1 Max via Ollama, local models are **not yet a reliable driver for opencode's full
agentic loop** — as of Ollama 0.31.1 + opencode 1.17.x with `tool_call: true`. They are capable
coders in isolation; the gap is the agentic tool-calling integration. Resume at step 1.
