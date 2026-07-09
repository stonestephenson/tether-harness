---
name: experiment-log
description: Record a research/experiment run so it's reproducible and comparable — config, seed, code version, command, environment, metrics, and observations — appended to the project's experiment log. Use after running a training/eval/benchmark script, when the user says "log this run", "record the result", "track this experiment", or when comparing runs. The research analog of verification: an experiment you can't reproduce is an unverified claim.
---

# experiment-log — make runs reproducible and comparable

In coding, the verifier is a test. In research, it's **reproducibility**: a result
you can't regenerate is a vibe, not a finding. This skill captures exactly what's
needed to re-create and compare a run, and externalizes it to a durable log (which
also survives compaction/clear — it's real state, not conversation).

## What to capture (per run)
Append one entry to the project's experiment log (`EXPERIMENTS.md` at repo root, or
an existing `experiments/`/logbook convention — discover it; create `EXPERIMENTS.md`
if none). Include:

- **Date/time** and a short **ID or purpose/hypothesis** ("does X improve Y?").
- **Code version:** `git rev-parse --short HEAD`, and whether the tree was **dirty**
  (`git status --porcelain` non-empty). A result from an uncommitted tree is not
  reproducible — flag it and prefer committing/stashing first.
- **Exact command** run (copy-pasteable), including overrides/flags.
- **Config:** the hyperparameters/settings that differ from default (don't dump the
  whole config — link the config file + note the diffs that matter).
- **Seed(s).** If none was set, say so — non-determinism is itself a finding to fix.
- **Environment:** key dep versions, hardware/accelerator, dataset + version/split.
- **Results:** the headline metric(s) with numbers, and where artifacts/logs/
  checkpoints were written.
- **Observations & next step:** what it means, anomalies, what to try next.

## Reproducibility sanity check (lightweight)
Before logging as a real result, sanity-check the output: metric within a plausible
range, output shapes/counts as expected, no silent NaN/empty-eval. A run that
"finished" but produced a degenerate metric is a failure to catch now, not later.
If the tree was dirty or no seed was set, record the result but mark it **provisional**.

## Fit with the rest of the harness
- The log is externalized state → `/handoff` verifies it's enough to resume; `/catchup`
  reads it to reconstruct "what have we tried" next session.
- Pairs with `/context-health`: the log is where run detail *belongs*, so the
  conversation can be compacted without losing experimental history.
- Commit the log with `/ship` so the record versions alongside the code that produced it.
