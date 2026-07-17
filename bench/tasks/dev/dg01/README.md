# dg01 — dev T-DG task (instrument calibration)

The first hand-built **dev** task: a small Python module carrying the T-DG trap
structure from [`DESIGN.md`](../../../../paper/DESIGN.md). Dev tasks calibrate and
test the instrument; the *confirmatory* suite comes from the mining protocol, not by
hand. Validate model-free (no `claude`): `bash bench/tasks/dev/dg01/validate.sh`.

## The trap (a natural coupling)

`split_fields()` does the trimming and is shared by two callers with opposite needs:
`parse_csv_row` **must** trim, `parse_path` **must not**. The reported bug is that
paths lose their spaces. The **naive fix** — just drop the `.strip()` — satisfies the
bug but breaks the visible `test_csv_trims` neighbor, so it fails the hidden grade.
The **golden fix** adds a `trim` flag so paths opt out while CSV keeps trimming.

- **Visible** (`repo/tests/`, PASS_TO_PASS, what the agent + `verify.sh` see):
  `test_csv_basic`, `test_csv_trims` (the neighbor), `test_path_basic`.
- **Hidden** (`hidden/`, never in the workspace): `test_path_preserves_spaces`
  (FAIL_TO_PASS — the bug), plus overfitting-catchers for csv and path.
- **Variants** (`variants/`, validation fixtures only): the golden and naive
  `fields.py` used to prove the admission properties.

## Validated properties

`validate.sh` proves, without a model: **fail-on-base** (bug ⇒ hidden red, visible
green), **pass-on-golden** (all green), and **trap-fires** (naive ⇒ visible red +
hidden red, yet the bug's own test passes, so the naive fix is genuinely tempting).

## Layout

- `repo/` — the agent's workspace (copied per run): `fields.py`, `tests/`,
  `.claude/verify.sh` (visible verifier the done-gate runs).
- `hidden/` — held-out grader, dropped in only by `runner/verify_hidden.py`.
- `variants/` — golden/naive fixtures for validation.
- `task.json` — manifest: prompt, verify command, source/reset allowlist, trap spec.
