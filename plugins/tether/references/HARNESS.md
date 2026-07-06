# The Harness — every tool, what it does, why, and when

A reference for the agentic-engineering setup used across my C/C++, Python, and
Rust/CMake projects (coding + CS research). Two companion docs:
- **This file (`HARNESS.md`)** — the encyclopedia: each tool explained, the concepts
  behind it, the evidence, and how it all fits.
- **`WORKFLOW.md`** — the operational loop: how a session actually runs, plus config.

---

## 1. The one idea

An LLM is a reasoning engine with two hard limits: it has a **finite context
window**, and it **cannot reliably tell when it's wrong on its own**. A good harness
is the scaffolding around the model that compensates for exactly those two limits:

1. **Verification, looped** — feed the model a real external signal (tests, linters,
   type-checkers) and make it iterate until that signal is green.
2. **Context, curated** — treat the window as a scarce resource; keep durable state
   in files (docs, commits, logs) so the conversation stays disposable.

Everything below is one of those two ideas, made concrete.

---

## 2. Concepts (plain-English definitions)

- **Context window / tokens** — the model's working memory for a session, measured in
  tokens (~¾ of a word each). Everything it "knows" right now — your messages, files
  it read, tool output — lives here. It's finite.
- **Context rot** — the measured fact that as the window fills, the model gets *less*
  reliable, even on easy tasks. More context ≠ better. (Chroma, 2025.)
- **Lost in the middle** — models attend well to the start and end of a long context
  and under-use the middle. (Liu et al., 2023.)
- **Context engineering** — deliberately curating what's in the window at each step to
  keep it "informative yet tight." (Anthropic.)
- **Hook** — a shell command the *harness* runs automatically at a fixed lifecycle
  moment (e.g. after an edit). Deterministic: it always fires, independent of the
  model's judgment. Used for things that must happen every time.
- **Skill** — a reusable procedure/playbook the *model* follows in-context when the
  situation matches. Soft-triggered: the model decides to use it (or you invoke it
  with `/name`). Used for judgment-heavy tasks that want the full conversation context.
- **Subagent (agent)** — a *separate* model instance with its own fresh context window
  and tool set, which does a sub-task and returns a summary. Used to **isolate** work
  (keep noise out of the main thread) or **parallelize** independent work.
- **LSP (Language Server Protocol)** — the same engine that powers IDE "go to
  definition / find references / show error." Gives the agent real code intelligence
  instead of guessing at symbols.
- **Verification loop / external feedback** — the pattern of: act → run a real check →
  read the result → fix → repeat. The single highest-leverage thing a coding harness
  can provide.
- **Convergent vs divergent task** — *convergent* = one roughly-right answer (implement
  a feature, fix a bug); wants coherence + verification. *divergent* = many valid
  answers (design choices, strategy); wants diverse perspectives. They need opposite
  tooling.
- **Compaction / handoff / clear** — ways to manage a full window: *compact* = shrink
  the current thread but keep going; *handoff* = write state to docs so a fresh agent
  can resume; *clear* = wipe the thread entirely (start fresh next session).

---

## 3. The three building blocks (and how to choose)

The whole harness is built from three primitives. The trick is knowing which fits a
given job — a great interview answer, because most people conflate them:

| Primitive | Runs when | Decided by | Use it for |
|---|---|---|---|
| **Hook** | a fixed lifecycle event | the harness (deterministic) | things that must *always* happen (verify, measure context) |
| **Skill** | the model judges it relevant, or you invoke it | the model (soft) | judgment tasks that need shared context (plan, test, ship) |
| **Agent** | spawned by a skill/the main agent | explicit spawn | isolating or parallelizing sub-work (search, independent review) |

Rule of thumb: **must-happen → hook; procedure-with-context → skill; needs-isolation-
or-parallelism → agent.** The distinguishing feature of an agent is the *separate
context window*, not "specialization."

---

## 4. Hooks (automatic — I never invoke these)

### `context-health.py` — context pressure gauge
- **What:** on every task boundary it reads the real token count from the session
  transcript and, if the window crosses 70 / 85 / 95%, nudges (you *and* me) to do
  something about it. Runs on `Stop` (task ends) and `UserPromptSubmit` (next task).
- **Why:** context rot is real and invisible from the inside — the model won't notice
  it's degrading. A deterministic gauge catches it every time; the model wouldn't.
- **When:** fully automatic. It only *nudges*; it never compacts or clears on its own.

### `verify-on-edit.py` — per-edit checker
- **What:** after I edit a file, it runs fast, file-local checks for that language and
  hands any problems straight back to me to fix. Check-only — it never rewrites your file.
  **Real-bug lint** (unused imports / undefined names via `ruff --select E9,F`, plus
  `shellcheck`) runs everywhere; **formatting/style** (clang-format, `ruff format`) is
  **opt-in** — it runs only when the project ships a style config (`.clang-format`, or
  `ruff.toml`/`pyproject.toml`). That keeps hand-formatted codebases from being churned.
- **Why:** this is the verification loop at its tightest. Research is blunt here: models
  can't self-correct without an external signal, and a linter-on-edit was the core of
  the first state-of-the-art SWE agent. Catching issues per-edit beats a big cleanup.
  Gating *formatting* on opt-in is the same lesson: no universal style exists, so
  imposing one on hand-formatted code is noise, not signal.
- **When:** automatic after every `Edit`/`Write`. Missing a tool → silently skips (so a
  partial toolchain is fine). Type-checkers/tests are deliberately *not* here (a lone
  file would false-positive) — those run at finish.

### `done-gate.py` — finish gate
- **What:** when I try to end a turn, it runs the project's fast check command
  (`.claude/verify.sh`) and, if it's red, **blocks me from finishing** until it's green.
- **Why:** closes the "I think I'm done" gap with an objective signal — the model
  claiming success is not the same as tests passing. This is where whole-project checks
  live (type-check, `clippy`, unit tests), because they need the full project to resolve.
- **When:** automatic on `Stop`, but **opt-in per project** (only runs if a
  `.claude/verify.sh` exists) so it never surprises you with a slow suite. Loop-guarded
  and time-boxed; fails open if anything goes wrong.

---

## 5. Skills — context lifecycle

### `/catchup` — import context at the start
- **What:** reconstructs where a project is — what it is, branch, clean/dirty, tests
  green/red, what changed last, what's next — by reading the entry doc and layering in
  live git/test state. Also offers to add a `.claude/verify.sh` if missing.
- **Why:** a fresh session starts blind. Rebuilding state from durable artifacts (not
  by re-reading the whole repo) is fast and cheap, and it's the mirror of `/handoff`.
- **When:** you run it when opening a project cold, after a `/clear`, or "where were we."

### `/context-health` — the compaction decision
- **What:** decides continue / compact / handoff+clear when the window is heavy, and
  executes it safely (externalize first, confirm the lossy steps).
- **Why:** *when* and *how* to shed context is a judgment the gauge (the hook) can't
  make — especially the difference between "keep building" and "we're now discussing
  what was built" (where the detail is the point and you should NOT compact).
- **When:** when the `context-health` hook nudges, or "should we compact/clear."

### `/handoff` — export context before you leave
- **What:** spawns fresh cold subagents to prove a zero-context agent could build, run,
  test, and extend the project from the docs alone — then fixes whatever they trip on.
- **Why:** the real test of documentation is a cold pickup. This is the safety gate
  before `/clear`: if a fresh agent couldn't resume, you're not allowed to wipe the
  thread yet.
- **When:** before `/clear`, at milestones, or before handing the repo to someone else.

### `/ship` — finalize a change
- **What:** runs the project's full quality gates, self-reviews the diff, then makes a
  **local** commit with a generated message. Stops before push/PR.
- **Why:** a durable checkpoint. Externalizing work into a commit is what makes clearing
  the conversation safe (the code is saved, so the chat is disposable).
- **When:** you run it when a change is done ("ship it", "commit this").

---

## 6. Skills — execution quality (the verification-driven core)

### `/plan-change` — approach non-trivial work with structure
- **What:** a `localize → plan → implement → validate` pipeline. Find the real code
  (often via `Explore` subagents), write a short plan of independently-checkable steps,
  implement one at a time in the verify loop, validate against tests.
- **Why:** for multi-file/unfamiliar/long-horizon work, structure beats diving in —
  the cheapest state-of-the-art SWE result came from exactly this rigid pipeline
  (Agentless), and explicit planning lifts long-horizon success (Plan-and-Act).
- **When:** multi-file changes, unfamiliar areas, long tasks. **Skip** small obvious
  edits — planning is overhead there.

### `/test-first` — make the target checkable before chasing it
- **What:** write the failing test (or bug reproduction) first, watch it fail for the
  right reason, then implement until it's green. Don't weaken the test to pass.
- **Why:** a test turns "I think this is right" into "this is green." AlphaCodium went
  19%→44% purely by looping on tests; and generating a good test is often easier than
  generating correct code, so it's cheap leverage.
- **When:** any change with a checkable outcome. Skip trivial edits / covered refactors.

### `/council` — pressure-test a divergent decision
- **What:** spawns 3–4 *independent, distinct-lens* reviewers (e.g. a perf skeptic, a
  correctness reviewer, a reproducibility hawk) in parallel, then reports where they
  agree, where they genuinely disagree, and which claims need external verification.
- **Why:** for *divergent* decisions, multiple independent perspectives beat one
  (multi-agent debate improves reasoning — Du et al.). Crucially, the value is the
  **independent-critique structure, not the personas** — role labels alone don't
  improve output (Zheng et al.), so it's built as a deliberation aid, not an oracle.
- **When:** consequential, hard-to-reverse design/experiment/approach choices. **Not**
  for implementation (that's convergent — use the verify loop). It's token-heavy, so
  reserve it for decisions that justify the cost.

---

## 7. Skills — research

### `/experiment-log` — make runs reproducible
- **What:** records a run — date, hypothesis, exact command, config, seed, code version
  (commit + whether the tree was dirty), environment, metrics, artifacts, next step —
  appended to the project's `EXPERIMENTS.md`.
- **Why:** in research the "verifier" is reproducibility. A result you can't regenerate
  is an unverified claim. Capturing seed + commit + command is what makes a run real.
- **When:** after a training/eval/benchmark run, or "log this result." Flags a run
  *provisional* if the tree was dirty or no seed was set.

---

## 8. Agents

### `Explore` (and subagents generally)
- **What:** a read-only agent with its own fresh context that searches/reads broadly and
  returns just a summary. `/plan-change` uses it to localize; `/handoff` uses cold
  subagents to audit docs; `/council` uses parallel subagents as its reviewers.
- **Why:** two legitimate wins — **isolation** (heavy reading happens in a throwaway
  window, so the main thread stays lean — "prevention beats cleanup") and **parallelism
  + independence** (breadth-first search, or independent reviews that don't contaminate
  each other). Anthropic's multi-agent research system beat a single agent by ~90% on
  breadth-first tasks *for these reasons* — but at ~15× the tokens.
- **When:** read-heavy search/localization, or independent parallel review. **Never**
  for coupled implementation — splitting code-writing across agents loses the shared
  context and cascades errors (Cognition). One writer, many readers.

### Leveraged built-ins
`/code-review` and `/security-review` (diff review), `/verify` and `/run` (drive the
real app to confirm behavior), `/simplify` (cleanup). These predate the custom harness
and slot into the same loop — e.g. `/code-review` after `/ship`'s gates are green.

---

## 9. Why it's shaped this way — the invariants

1. **Externalize → verify → discard.** Never drop context (compact/clear) that isn't
   saved somewhere durable first.
2. **Effort scales with irreversibility.** Compact (reversible) = light notes; clear
   (destructive) = full verified handoff.
3. **Verify, don't self-certify.** "Done" = the checker passes, not that it looks right.
   Never weaken a test to make it green.
4. **Prevention beats cleanup.** Offload heavy reads to subagents so the thread never
   bloats — cheaper than compacting later.
5. **Convergent vs divergent.** Coupled execution → single thread + skills + verify;
   divergent decisions → `/council`. The value is the structure/boundary, never a persona.
6. **Hooks guarantee; skills bias.** Anything that *must* happen is a hook; judgment
   stays a skill. Destructive steps (clear, compact) always ask.

---

## 10. The evidence base (for the "why", and for interviews)

| Finding | Source |
|---|---|
| Performance degrades as context fills ("context rot") | Chroma, 2025 |
| Models under-use the middle of long context | Liu et al., 2023 (Lost in the Middle) |
| Curate context as a finite resource | Anthropic, "Effective context engineering" |
| Iterating on tests ≫ one-shot (19%→44%) | Ridnik et al., 2024 (AlphaCodium) |
| Reflecting on a feedback signal (80%→91% HumanEval) | Shinn et al., 2023 (Reflexion) |
| Execute→feedback→fix beats blind generation | Chen et al., 2023 (Self-Debug) |
| A good tool interface (linter-on-edit) drives SOTA | Yang et al., 2024 (SWE-agent) |
| Rigid localize→repair→validate beats complex agents, cheaper | Xia et al., 2024 (Agentless) |
| LLMs can't self-correct without external feedback | Huang et al., 2023 |
| Multi-agent helps breadth-first reading (~90%), ~15× cost | Anthropic multi-agent system |
| Don't split coupled coding across agents | Cognition, "Don't Build Multi-Agents" |
| Multi-agent debate improves divergent reasoning | Du et al., 2023 |
| Persona/role labels alone don't improve accuracy | Zheng et al., 2024 |
| OS-style memory tiers extend effective context | Packer et al., 2023 (MemGPT) |

---

## 11. How it all comes together

```
                          ┌───────────────────────────────────────────────┐
                          │  PRINCIPLE: verify what you can't self-judge,  │
                          │            curate what won't fit               │
                          └───────────────────────────────────────────────┘

   SESSION START                 DO THE WORK                     SESSION END
   ─────────────                 ───────────                     ───────────
   /catchup ──────►  ┌─ decide? ─ /council ─(divergent)          ...heavy? the
   (import state)    │            └► you choose                  context-health
        │            │                                           HOOK nudges ──►
        │            ├─ /plan-change ─ localize(Explore) ─►      /context-health
        ▼            │        plan ─► implement ─► validate       │ externalize
   [ context-health  │            │         │           │         ▼
     HOOK watches ]  │       /test-first    │      done-gate     /ship (commit)
        ▲            │       (write test)   │      HOOK (green      │
        │            │            │         ▼      -on-finish)      ▼
        │            │            └─► edit ─► verify-on-edit       /handoff
        │            │                       HOOK (per-edit)       (prove cold
        └── research:│                            │                 pickup)
         /experiment-log records the run          │                  │
                     └────────────────────────────┘                  ▼
                              (fix loop)                           /clear
                                                                     │
                                                       next session ─┘► /catchup

   AUTOMATIC (hooks):  context-health · verify-on-edit · done-gate
   YOU / MODEL (skills): catchup · plan-change · test-first · council ·
                         experiment-log · context-health · ship · handoff
   ISOLATED (agents):  Explore (read) · council reviewers · handoff auditors
```

**Read it as three concentric responsibilities:**
- **Hooks** form the always-on safety net (verification + context pressure) — you never
  touch them.
- **Skills** are the plays you (or I) call for judgment work — planning, testing,
  deciding, shipping, orienting.
- **Agents** are the isolated hands that do read-heavy or independent work without
  polluting the main thread.

The loop is self-reinforcing: verification keeps the code correct, which keeps the
context *meaningful*; context hygiene keeps the model sharp, which keeps its
verification and judgment good. Neither works well without the other.

---

## 12. Explaining this in an interview (30-second version)

> "I treat the model as a reasoning engine with two weaknesses — a finite context
> window and no reliable self-judgment — and I build scaffolding around both. For
> self-judgment, I wire *deterministic verification hooks*: after every edit a linter
> feeds errors straight back, and I can't 'finish' until the project's checks pass —
> because the research is clear that LLMs can't self-correct without an external signal.
> For context, I treat the window as a scarce resource: a hook watches how full it is,
> and I externalize state into commits, docs, and experiment logs so the conversation
> stays disposable — that's context engineering, motivated by 'context rot.' On top
> sit soft-triggered *skills* for judgment work — a plan→implement→validate pipeline, a
> test-first loop, a multi-perspective 'council' for irreversible design decisions — and
> *subagents* that isolate heavy reading so they don't bloat the main thread. The core
> insight is matching the tool to the task: deterministic checks for execution,
> diverse perspectives only for open-ended decisions, and never confusing a role label
> with a capability."

**Follow-up talking points:**
- *Convergent vs divergent* — one agent + verification for building; multiple
  perspectives only for deciding.
- *Why hooks, not prompts* — guarantees vs. the model remembering.
- *Cost awareness* — multi-agent is ~15× tokens, so it's scoped to breadth-first
  reading and high-stakes decisions, not the default.
- *What I deliberately DON'T do* — no self-critique without a ground-truth signal, no
  multi-agent for coupled implementation, no persona theater.
