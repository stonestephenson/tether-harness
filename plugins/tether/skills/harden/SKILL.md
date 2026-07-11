---
name: harden
description: Compile accumulated corrections ("never use X", "always run Y first") from prose — CLAUDE.md rules, feedback memories, nits the user has repeated — into MECHANICAL enforcement at the cheapest sufficient tier (existing linter config → a .claude/verify.sh check → a permissions deny rule → last-resort PreToolUse guard). Use when a correction gets repeated, when feedback has accumulated, at a hardening milestone, or when the user says "harden this", "make that stick", "enforce this rule", "stop letting me/you do X", or "compile my corrections". Always proposes before writing; judgment-only preferences stay prose.
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# harden — compile corrections into enforcement

Prose doesn't bind. TRACE measured that preferences kept as retrievable notes were
still violated **~57%** of the time, while the same preferences **compiled into
mandatory runtime checks** dropped violations to **2–38%** (Zhou et al., 2026).
This skill is invariant #6 — *anything that must happen is a hook; judgment stays
a skill* — applied to the corrections a project accumulates: it converts existing
prose into enforcement; it never adds new process.

## When to run it
- A correction has been given **twice** (a done-gate failure recurring with the
  same cause counts, and so does the same nit in two `/ship` reviews).
- CLAUDE.md / feedback memories have accumulated "never/always/don't" lines.
- A hardening milestone ("make the rules stick before we hand this off").

**Skip** when there's nothing accumulated to compile — this skill converts
existing corrections; it doesn't invent rules a correction never asked for.

## Step 1 — Gather candidates
Collect each candidate as *(rule text, origin, date)* from:
- **CLAUDE.md / AGENTS.md** (project first, then user-global): imperative
  "never / always / don't / must" lines.
- **Feedback-type memories**, if a memory directory exists.
- **Repetition in the record:** a correction the user has given more than once,
  or a done-gate failure that recurs with the same cause.

## Step 2 — Classify: mechanically checkable, or judgment-only?
A rule is *mechanically checkable* iff a deterministic command can decide
compliance (a grep over the tree, a linter rule, a path/tool predicate).
Judgment calls ("keep functions small", "prefer clarity over cleverness") stay
prose — report them as prose-only and move on. Compiling judgment into a brittle
grep creates false blocks, and a wrong gate is worse than no gate.

## Step 3 — Compile to the cheapest sufficient tier

| Tier | Mechanism | Use when | Runs at |
|---|---|---|---|
| **a** | existing linter's config (ruff / clippy / eslint rule) | the rule maps to a lint code the project's linter already knows (e.g. a banned import → ruff `flake8-tidy-imports` banned-api) | every edit (verify-on-edit) + every stop |
| **b** | check appended to **`.claude/verify.sh`** | expressible as a fast text/path predicate | every stop (done-gate) |
| **c** | permissions **deny** rule in project `.claude/settings.json` | "never touch/run X" — a tool-call shape, not a code shape | at the tool call itself |
| **d** | tiny PreToolUse guard script + hooks.json wiring | the check needs to inspect tool *input* at call time | at the tool call itself |

Work strictly a → b → c → d and stop at the first tier that suffices. Tier (d) is
a **last resort**: it's hook code to maintain, so it inherits the hook ground
rules — minimal, time-boxed, fail open, and it lands with regression coverage.

## Step 4 — Propose, never impose
Show the user every compiled rule as *correction → tier → the exact line/diff*
**before writing anything**, including which candidates stayed prose and why.
Enforcement is added only with their OK — they may know why a rule shouldn't bind.

## Step 5 — Write with provenance
Annotate every compiled rule at the write site with origin + date, e.g.:

```bash
# harden(2026-07-11): from correction "use net.http, not requests directly" (repeated 2026-07-02, 2026-07-09)
```

so every rule stays auditable and removable — when a check blocks someone next
month, the annotation answers "who asked for this?".

## Worked example — correction → verify.sh line

> User, twice: "don't call `requests` directly — go through our `net.http`
> wrapper, it handles retry/backoff."

Checkable (an import is a text shape) → tier (a) if the project configures ruff
(banned-api); this project doesn't → tier (b), appended to `.claude/verify.sh`:

```bash
# harden(2026-07-11): from correction "use net.http, not requests directly" (2026-07-02, 2026-07-09)
if grep -rnE '^\s*(import requests|from requests\b)' src/ --include='*.py'; then
  echo 'banned: direct requests import — use net.http (see harden note above)' >&2
  exit 1
fi
```

The grep prints the offending lines, the message says what to do instead, and the
done-gate now blocks any "done" that violates the correction.

## Guardrails
- **Style stays opt-in.** Never compile style/formatting preferences into a
  project that hasn't opted into a style config (`.clang-format`,
  `ruff.toml`/`pyproject.toml`) — same philosophy as verify-on-edit's opt-in
  formatting.
- **Add, don't reshape.** Compiled checks append; never rewrite, reorder, or
  weaken the gates already in `verify.sh`.
- **Keep the gate fast.** `verify.sh` must stay seconds-fast — greps are fine;
  no new test suites enter through this path.
- **Expect the tamper flag.** Appending to `verify.sh` mid-session trips the
  done-gate's verifier-integrity guard at the next stop — that's the guard
  working. Tell the user the change was the approved `/harden` write and stop
  again; it blocks at most once.

## Fit with the rest of the harness
- Tier (a) rides **verify-on-edit**; tiers (a)–(b) ride the **done-gate** — the
  compiled rule is enforced by machinery that already exists, which is the point.
- `/ship` review nits that recur are gather-candidates for the next `/harden` run.
- Mirrors `/test-first`'s ethic: encode the expectation where a machine checks it.
