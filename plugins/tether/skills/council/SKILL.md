---
name: council
description: Convene a technical advisory council — 3–4 independent, distinct-lens reviewers — to pressure-test a DIVERGENT decision (architecture choice, experiment design, approach selection, risk/red-team review), then report where they agree, where they genuinely disagree, and which claims need external verification. A deliberation aid, not an oracle. Use at decision points before implementation, or when the user says "run this by the council/board", "what are we missing", "pressure-test / red-team this", or "get advice on this approach". NOT for convergent execution (implementing, debugging with a clear signal) — use the verification loop there.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Agent, Write
---

# council — pressure-test a decision from independent angles

For **divergent** questions (many valid answers, the goal is to surface considerations
and disagreement), multiple independent reviewers beat one. Multi-agent deliberation
measurably improves reasoning and reduces blind spots on exactly this kind of task
(Du et al., multiagent debate). But note *what* creates the value: it's the
**independent critique + reconciliation structure**, NOT the personas — role labels
alone don't improve output (Zheng et al.). So the lenses here are **handles to force
diverse critique, not authorities to trust.** This skill is a decision aid; you still
own the decision, and load-bearing claims still need a real verifier.

## When to convene it (and when not)
- **Convene** for consequential, hard-to-reverse **decisions**: architecture/design
  choices, experiment or eval design, picking an approach, a pre-mortem/red-team.
- **Don't** convene for convergent execution — implementing, or debugging with a clear
  signal. There, the verify loop (`verify-on-edit` / `done-gate` / `/test-first`) is
  the right tool; a council is wasted tokens.
- It's **token-heavy** (parallel subagents ≈ many× a single pass). Reserve it for
  decisions that justify the cost.

## 1. Frame the decision (garbage in → garbage out)
Write the question crisply: the proposal/approach, the goal + constraints, and what
"good" looks like. Gather the **real artifact** the council will judge — the design
doc, the diff, the experiment plan, the relevant code — not a vague summary. A fuzzy
prompt yields fuzzy critique.

## 2. Choose the lenses (adapt to the question)
Pick **3–4 distinct, relevant** lenses, and include **at least one deliberate skeptic**
to guard against false consensus. Tailor them to the decision — examples:
- *Systems/perf:* concurrency, failure modes, scaling, resource use.
- *Correctness:* edge cases, invariants, what breaks the assumptions.
- *Research validity:* statistical soundness, baselines/ablations, confounds.
- *Reproducibility hawk:* seeds, environment, "could someone re-run this?"
- *Simplicity/YAGNI:* is there a materially simpler design?
- *Red-team/pre-mortem:* "it's 6 months later and this failed — why?"

## 3. Independent review (parallel, no cross-contamination)
Spawn **one subagent per lens, all in the same batch so they run in parallel and none
sees the others' output** — independence is what preserves diversity; let them see each
other and they collapse toward one view. Give each the *same* framed proposal + artifact
and its lens. Instruct each to **critique only, not modify anything**, and to return:
- its 2–4 **most important, specific, grounded** concerns (no generic "consider X");
- what it would **change or de-risk**;
- any claim it's asserting that is **not yet verified** (so we can mark it).

## 4. Synthesize (separate signal from theater)
Produce a report that explicitly separates:
- **Consensus** — what they agree on. Note if agreement came *too* easily (possible
  mode-collapse, not real validation).
- **Disagreement** — the genuine conflicts, each with the **crux**: *why* they diverge
  and what fact/assumption would settle it.
- **Unverified load-bearing claims** — assertions the decision rests on that no one
  actually checked, each paired with the **external check** that would resolve it (a
  benchmark, a test, a paper, a measurement).

## 5. Report, then hand the decision back
Give a tight report (not a transcript). State plainly that it's a **decision aid, not a
verdict** — the lenses are simulated angles, not experts. Offer an optional **round 2**:
a focused cross-examination on the single sharpest disagreement (spawn the two opposing
lenses again, each shown the other's argument). Then the decision is the user's; once
made, it feeds `/plan-change` and the convergent implementation loop takes over.

## Guardrails
- **Not an oracle.** Personas are lenses; a "Bezos/Huang"-style label simulates a
  stereotype, not a person's judgment. Value = broadened considerations + surfaced
  disagreement, never authority.
- **Verify the load-bearing claims** externally — the council's job is to *find* what
  needs checking, the verify loop's job is to check it.
- **Independence in round 1**; only cross-examine after the independent takes exist.
- **Always seat a skeptic**; flag suspiciously unanimous verdicts.
- **Reserve for divergent, consequential decisions** — cost discipline.
