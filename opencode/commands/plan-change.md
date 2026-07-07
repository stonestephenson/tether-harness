---
description: Approach a non-trivial code change with a localize → plan → implement → validate pipeline instead of diving in. Use for multi-file changes, unfamiliar areas of a codebase, or long-horizon tasks; when the user says "plan this out", "how should we approach", "scope this", or "map the change". Skip for small, localized edits where the fix is obvious — planning is overhead there.
---

# plan-change — localize, plan, implement, validate

For anything non-trivial, structure beats autonomy. The strongest SWE-bench result
per dollar came from a *rigid* `localize → repair → validate` pipeline that beat
open-ended agents at a tenth of the cost (Agentless), and explicit planning/goal-
decomposition consistently lifts long-horizon success (Plan-and-Act and the
decomposition literature). This skill applies that shape.

## When to run it
Multi-file changes, unfamiliar code, or long-horizon work. **Skip** obvious localized
edits — jumping straight to the fix is correct there; don't ceremony-ize small work.

## 1. Localize (find the real code, don't assume)
Identify the exact files/functions/symbols the change touches. For anything broad or
read-heavy, **delegate the search to `Explore` subagents** and have them return
summaries — this keeps the main window lean (context isolation is the one place
multi-agent reliably wins: breadth-first *reading*, per Anthropic's research system).
Read the actual code before planning against it.

## 2. Plan (decompose into verifiable steps)
Write a short, ordered plan: each step small enough to implement and **independently
checkable**. For each step note its verification (which test/command proves it),
the invariants it must not break, and files it must not touch. Surface unknowns and
resolve them now, not mid-implementation.

If the approach itself is a **consequential, hard-to-reverse choice** (a design or
experiment-design decision with several valid options), convene `/council` *before*
locking it in — that's a divergent decision, exactly what the council is for. Once the
approach is chosen, planning and implementation are convergent again.

## 3. Implement (one step at a time, in the feedback loop)
Do steps in order. For steps with a checkable outcome, use `/test-first`. After each
edit, the **verify-on-edit** hook feeds back lint/format issues — fix inline. Don't
batch six steps then hope; land and verify each.

## 4. Validate (green, not vibes)
Run the project's checks (the **done-gate** / `.claude/verify.sh`, then the full
suite via `/ship`). The task is done when the verifier says so, not when it looks
done. If validation reveals the plan was wrong, revise the plan explicitly.

## Fit with the rest of the harness
- **Explore subagents** = the localize phase *and* context-health's "offload reads"
  prevention — one move, two wins.
- **verify-on-edit / done-gate / /ship** = the validate phase, continuous then final.
- At step boundaries the **context-health** hook may nudge; externalize the plan
  (write it to the scratchpad or a task doc) so a compact/clear can't lose it.
- `/handoff` + `/catchup` carry the plan across sessions for long-horizon work.
