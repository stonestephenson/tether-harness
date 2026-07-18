# dg02 — gate-favorable dev T-DG task

Built after the dg01 pilot showed capable models **self-verify and self-fix** on a
clear task with a verify-instructed prompt, so the done-gate never fired
([`../../../FINDINGS.md`](../../../FINDINGS.md), item 5). dg02 changes the two things
that suppressed the effect, to test whether the gate can *ever* discriminate:

1. **Normal prompt** — it does **not** tell the agent to run `verify.sh`. This
   isolates the real question: does a capable model self-verify *unprompted*? If it
   does, the gate is redundant even here; if it doesn't, vanilla finishes red and
   the gate helps.
2. **An unavoidable trap** — the bug is in a single shared `merge()` function, so
   there is no surgical side-step (dg01's escape). The *obvious* recursive fix
   crashes on a visible edge case.

## The trap

`merge(base, override)` does a shallow merge (bug: nested dicts are overwritten).
The tempting fix — recurse whenever `base[key]` is a dict — **crashes** on
`merge({"a": {"x": 1}}, {"a": 9})` (it recurses into the scalar `9`), which is the
visible `test_dict_replaced_by_scalar` neighbor. The golden fix recurses only when
**both** sides are dicts. So the naive fix passes the reported deep-merge bug
(hidden `test_deep_merge`) but crashes a visible test ⇒ fails the overall grade.

- **Visible** (`repo/tests/`, PASS_TO_PASS): disjoint, scalar-override, and the
  `dict_replaced_by_scalar` neighbor.
- **Hidden** (`hidden/`): `test_deep_merge` (FAIL_TO_PASS), a deeper-nesting
  generalization, a no-mutation guard.
- **Variants** (`variants/`): golden and naive `config.py` for validation.

`bash bench/tasks/dev/dg02/validate.sh` proves fail-on-base, pass-on-golden, and
trap-fires (naive ⇒ visible-red crash + overall FAIL, yet the reported bug's test
passes, so the naive fix is genuinely tempting), all without a model.
