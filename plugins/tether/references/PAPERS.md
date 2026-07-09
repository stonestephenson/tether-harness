# The evidence base — papers behind the harness

Full citations for the research that motivates the harness. Each finding maps to the
`HARNESS.md` §10 evidence table; this file adds titles, authors, venues, and links.

PDFs of the arXiv papers (and HTML snapshots of the industry write-ups) are kept
**locally, not committed**, in the repo-root `references/papers/` directory — that path
is gitignored, so a clone won't pull ~15 MB of PDFs. To (re)fetch them, the arXiv IDs
below are all you need (`https://arxiv.org/pdf/<id>`).

Legend: 📄 = local PDF, 🌐 = local HTML snapshot (both in `references/papers/`).

## Context — the finite window

- **Lost in the Middle: How Language Models Use Long Contexts** — Liu et al., TACL 2024.
  arXiv:[2307.03172](https://arxiv.org/abs/2307.03172). 📄 `lost-in-the-middle.pdf`
  *Backs:* models under-use the middle of a long context.
- **Context Rot: How Increasing Input Tokens Impacts LLM Performance** — Hong et al.,
  Chroma Technical Report, 2025. <https://www.trychroma.com/research/context-rot>.
  🌐 `context-rot.html`
  *Backs:* performance degrades as the window fills — more context ≠ better.
- **Effective context engineering for AI agents** — Anthropic Engineering, 2025.
  <https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents>.
  🌐 `context-engineering.html`
  *Backs:* curate the window as a finite resource.
- **MemGPT: Towards LLMs as Operating Systems** — Packer et al., 2023.
  arXiv:[2310.08560](https://arxiv.org/abs/2310.08560). 📄 `memgpt.pdf`
  *Backs:* OS-style memory tiers extend effective context (externalize state to files).

## Verification — the external-feedback loop

- **Large Language Models Cannot Self-Correct Reasoning Yet** — Huang et al., ICLR 2024.
  arXiv:[2310.01798](https://arxiv.org/abs/2310.01798). 📄 `cannot-self-correct.pdf`
  *Backs:* LLMs can't self-correct without an external signal — the core premise for hooks.
- **Teaching Large Language Models to Self-Debug** — Chen et al., 2023.
  arXiv:[2304.05128](https://arxiv.org/abs/2304.05128). 📄 `self-debug.pdf`
  *Backs:* execute → read feedback → fix beats blind generation.
- **Reflexion: Language Agents with Verbal Reinforcement Learning** — Shinn et al.,
  NeurIPS 2023. arXiv:[2303.11366](https://arxiv.org/abs/2303.11366). 📄 `reflexion.pdf`
  *Backs:* reflecting on a feedback signal lifts pass rates (80%→91% HumanEval).
- **Code Generation with AlphaCodium** — Ridnik et al., 2024.
  arXiv:[2401.08500](https://arxiv.org/abs/2401.08500). 📄 `alphacodium.pdf`
  *Backs:* iterating on tests ≫ one-shot (19%→44%) — the `/test-first` loop.
- **SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering** — Yang
  et al., NeurIPS 2024. arXiv:[2405.15793](https://arxiv.org/abs/2405.15793).
  📄 `swe-agent.pdf`
  *Backs:* a good tool interface (linter-on-edit) drives SOTA — the `verify-on-edit` hook.
- **Agentless: Demystifying LLM-based Software Engineering Agents** — Xia et al., 2024.
  arXiv:[2407.01489](https://arxiv.org/abs/2407.01489). 📄 `agentless.pdf`
  *Backs:* a rigid localize→repair→validate pipeline beats complex agents, cheaper — `/plan-change`.

## Multi-agent — when (and when not) to split work

- **How we built our multi-agent research system** — Anthropic Engineering, 2025.
  <https://www.anthropic.com/engineering/multi-agent-research-system>.
  🌐 `multi-agent-research.html`
  *Backs:* multi-agent helps breadth-first reading (~90%) at ~15× cost — the `Explore` isolation pattern.
- **Don't Build Multi-Agents** — Yan (Cognition), 2025.
  <https://cognition.com/blog/dont-build-multi-agents>. 🌐 `dont-build-multi-agents.html`
  *Backs:* don't split coupled coding across agents — one writer, many readers.
- **Improving Factuality and Reasoning in Language Models through Multiagent Debate** —
  Du et al., 2024. arXiv:[2305.14325](https://arxiv.org/abs/2305.14325).
  📄 `multiagent-debate.pdf`
  *Backs:* independent perspectives improve *divergent* reasoning — the `/council` structure.
- **When "A Helpful Assistant" Is Not Really Helpful: Personas in System Prompts Do Not
  Improve Performances of LLMs** — Zheng et al., EMNLP Findings 2024.
  arXiv:[2311.10054](https://arxiv.org/abs/2311.10054). 📄 `personas.pdf`
  *Backs:* role/persona labels alone don't improve accuracy — `/council`'s value is the
  independent-critique structure, not the personas.

## Verification integrity & harness evolution — 2026 audit additions

Added 2026-07 by the SOTA audit (see repo-root [`ROADMAP.md`](../../../ROADMAP.md)). These
back the roadmap items — and, just as deliberately, the decisions to *reject* fashionable
alternatives.

- **EvilGenie: A Reward Hacking Benchmark** — Gabor et al., 2025.
  arXiv:[2511.21654](https://arxiv.org/abs/2511.21654). 📄 `evilgenie.pdf`
  *Backs:* coding agents — **Claude Code and Codex among them** — observed explicitly
  reward hacking (hardcoding test cases, editing test files); test-file **edit detection**
  is one of its three working detectors → ROADMAP #1 (verifier-integrity guard).
- **SpecBench: Measuring Reward Hacking in Long-Horizon Coding Agents** — Zhao et al.,
  2026. arXiv:[2605.21384](https://arxiv.org/abs/2605.21384). 📄 `specbench.pdf`
  *Backs:* every frontier model saturates the *visible* test suite while held-out tests
  reveal tampering; stronger models tamper more → ROADMAP #1.
- **The Verification Horizon: No Silver Bullet for Coding Agent Rewards** — Wang et al.,
  2026. arXiv:[2606.26300](https://arxiv.org/abs/2606.26300). 📄 `verification-horizon.pdf`
  *Backs:* no fixed verifier stays sufficient as capability grows — verification must be
  layered and co-evolve → ROADMAP #1's layered design (hash guard + deny rules + user ack).
- **Getting Better at Working With You: Compiling User Corrections into Runtime
  Enforcement for Coding Agents (TRACE)** — Zhou et al., 2026.
  arXiv:[2606.13174](https://arxiv.org/abs/2606.13174). 📄 `trace-corrections.pdf`
  *Backs:* corrections kept as prose/memory are still violated ~57% of the time; compiled
  into mandatory runtime checks → 2–38% → ROADMAP #2 (`/harden`), and the harness's own
  "hooks guarantee; skills bias" invariant applied to feedback.
- **Rethinking the Value of Agent-Generated Tests for LLM-Based Software Engineering
  Agents** — Chen et al., 2026.
  arXiv:[2602.07900](https://arxiv.org/abs/2602.07900). 📄 `rethinking-agent-tests.pdf`
  *Backs (a rejection):* mid-task test-writing volume doesn't correlate with task success,
  and prompting for more tests doesn't change outcomes — keeps `/test-first` gated to
  checkable outcomes and killed the mutation-testing-gate proposal.
- **Self-Compacting Language Model Agents** — Li et al., 2026.
  arXiv:[2606.23525](https://arxiv.org/abs/2606.23525). 📄 `self-compacting-agents.pdf`
  *Backs (validation):* model-invoked, rubric-guided compaction beats fixed-interval
  summarization — confirms the context-health gauge(hook) + judgment(skill) split.
- **Effective harnesses for long-running agents** — Anthropic Engineering, 2025.
  <https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents>.
  🌐 `effective-harnesses.html`
  *Backs (validation):* structured handoff artifacts + context resets over compaction —
  the `/handoff` ↔ `/catchup` mirror, published independently.
- **Harness design for long-running application development** — Anthropic Engineering,
  2026. <https://www.anthropic.com/engineering/harness-design-long-running-apps>.
  🌐 `harness-design-long-running-apps.html`
  *Backs:* generator–evaluator separation (models self-evaluate leniently) → ROADMAP #4
  (`/ship` cold reviewer); plus the "iteratively prune scaffolding" posture.
