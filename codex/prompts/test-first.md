
# test-first — make the target checkable before you chase it

The strongest, most replicated result in coding-agent research is that **iterating
against a real verifier** beats one-shot generation, and that models **cannot
reliably self-correct without an external signal**. A test is that signal. Writing
one first turns "I think this is right" into "this is green."

Evidence, briefly: AlphaCodium went 19%→44% pass@5 purely by looping on tests;
Reflexion 80%→91% on HumanEval by reflecting on a feedback signal; and a key
finding — *generating a useful test is easier than generating correct code*, so the
test is cheap leverage.

## When to run it
Non-trivial change with a checkable outcome (a feature, a bug with a reproduction,
a function with clear I/O). **Skip** trivial edits, pure formatting, or refactors
already covered by tests — there the verify-on-edit hook and existing suite suffice.

## The loop
1. **Write the check first.** Encode the desired behavior as a test (or, for a bug,
   a minimal reproduction) in the project's existing test framework and layout —
   discover it, don't impose one. For a bug, the test should *fail the way the bug
   manifests*.
2. **Run it; confirm it fails for the right reason.** A test that passes immediately,
   or fails on a typo/import error, is testing nothing. Watch the failure before
   trusting it.
3. **Implement the minimum** to make it pass. The verify-on-edit hook will surface
   lint/format issues as you go — fix them inline.
4. **Run until green.** Let the real signal, not your judgment, decide "done."
5. **Do not weaken the test to pass.** Deleting the assertion, loosening the expected
   value, or `skip`-ing it defeats the entire point. If the test was wrong, fix the
   *test* deliberately and say so.

## Fit with the rest of the harness
- The test you write becomes (or feeds) the project's `.claude/verify.sh`, so the
  **done-gate** hook keeps enforcing it at every stop.
- `/ship` runs the full suite as a final gate; this skill front-loads the one test
  that matters for the change.
- For a larger change, `/plan-change` decomposes it into steps — apply test-first to
  each step that has a checkable outcome.
