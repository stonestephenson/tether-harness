---
name: context-health
description: Decide whether the current conversation should continue, compact, or hand off + clear — then execute that choice safely. The judgment layer paired with the context-health hook: it reads the occupancy signal and the task boundary, picks the right branch, and (for compact/clear) externalizes state FIRST via /handoff or /ship so nothing important is lost. Project-agnostic. Use when the context-health hook flags heavy context, at a task/milestone boundary, before /clear or /compact, or when the user asks "should we compact/clear", "is the context getting too big", "wrap up and hand off", or "manage the context".
---

# context-health — continue, compact, or hand off?

The hook (Layer 1) measures *how full* the window is and nudges. This skill
(Layer 3) decides *what to do about it* and does it without losing state. The
mechanical part is already done for you; your job is the judgment the rule can't
make.

**The one invariant, above everything:** never `/clear` and never compact away
state that isn't already written down somewhere durable (a handoff doc, a
scratchpad, a commit). **Externalize → verify → discard.** If you can't confirm a
cold agent could resume, you are not allowed to clear yet.

Why bother: model reliability degrades as the window fills — measurably, even on
easy tasks ("context rot"), and information in the middle of a long history gets
under-used ("lost in the middle"). Compacting/clearing at the right boundary is
about *output quality*, not just fitting under a limit.

## Step 0 — Read the signal (don't re-measure by feel)
If the hook fired, the token count and band are already in context — use them. If
you were invoked manually, estimate occupancy from the conversation's size and how
much raw tool output it holds. Then answer one gating question: **is a unit of work
actually complete right now, or are we mid-step?** Never compact mid-step.

## Step 1 — Classify the boundary
Four cheap facts decide the branch:
1. **State of work:** DONE (task finished / tests green / clean checkpoint) vs
   IN-PROGRESS (edits open, a step half-done).
2. **Mode of what's next:** DOING (more building) vs UNDERSTANDING (a Socratic
   review / Q&A / retro *about what's already in context*). This one dominates —
   in UNDERSTANDING mode the "heavy" context (implementation detail, tool output,
   the paths you took *and abandoned*) is the raw material the discussion feeds on.
   Compacting it away defeats the purpose. Don't assume "task done" means "detail
   disposable."
3. **Coupling of next work:** does what's coming next SHARE state with what's in
   context (same files/feature) or is it INDEPENDENT (new area, fresh task)?
4. **Occupancy band:** healthy (<70%) / warn (70–85%) / act (85–95%) / critical (≥95%).

You cannot always read the mode from the finished task alone — if it's ambiguous
whether the user wants to keep building, discuss, or move on, **ask** rather than
compact on a guess.

## Step 2 — Pick the branch
| Situation | Branch |
|---|---|
| IN-PROGRESS, band < critical | **CONTINUE** — don't disrupt mid-task |
| IN-PROGRESS, band critical | Get to the nearest safe checkpoint (finish the current edit, start nothing new), then re-evaluate as DONE |
| DONE, band < warn | **CONTINUE** — nothing to do |
| DONE, next is UNDERSTANDING (discuss/review what's here), band < critical | **CONTINUE** — the detail is the material; do not compact it away |
| DONE, next is UNDERSTANDING, band critical | Externalize the built work to a doc, then **propose** a *discussion-aware* compact (keep implementation specifics) — user confirms |
| DONE, next is DOING, SHARES state, band warn/act | **COMPACT** (propose first) — keep the thread, shrink it |
| DONE, next is DOING, INDEPENDENT, band act/critical | **HANDOFF + CLEAR** — end the thread cleanly |
| Mode unclear | **ASK** — don't compact on a guess |
| Critical, independent next step | Externalize now, then clear (or compact if you must keep going) |

When unsure between compact and handoff+clear, prefer **compact** — it's reversible;
clear is not. When unsure whether to compact *at all*, prefer **CONTINUE and ask** —
compaction is lossy and you can't always predict what the next turn will need.

**Why compact externalizes lightly but clear runs `/handoff`:** compact keeps the
thread, so you retain the curated summary — a full cold-pickup audit is overkill, and
`/handoff` spawns subagents that would burn the very budget you're trying to reclaim.
Clear destroys the thread, so the docs are the *only* safety net and must be verified.
Match externalization effort to how irreversible the discard is.

## Step 3 — Execute

**CONTINUE:** say so in one line and proceed. Don't ceremony-ize it.

**COMPACT (keep the thread, drop the bloat) — propose, then confirm:**
1. Externalize durable state first — update the project's scratchpad/working notes
   (or handoff doc if it has one): the goal + acceptance criteria, decisions and
   *why*, open TODOs, the exact `file:line` you're working, invariants, and what
   NOT to touch.
2. **Curate** — this is the judgment the hook can't do:
   - **Keep:** task goal & acceptance criteria; decisions + rationale; open threads/
     TODOs; exact paths/identifiers in play; gotchas/constraints; last known-good
     (test) state.
   - **Drop:** verbatim tool-output dumps; superseded attempts and dead ends; file
     contents already saved to disk; resolved sub-questions.
   - *Discussion-aware exception:* if the next turn is a review/Q&A, KEEP the
     implementation specifics and the paths you abandoned — that's what gets probed.
3. **Show the user what you'll keep vs drop and get their OK before compacting.**
   Compaction is lossy and irreversible-in-practice; it is not a silent step. Once
   approved, run `/compact` (or hand your curated summary to the harness's compaction
   so it keeps the right things rather than guessing).

**HANDOFF + CLEAR (end the thread):**
1. If there's uncommitted work at a committable point, run `/ship` — that
   externalizes it into git (a durable checkpoint).
2. Run `/handoff` — it verifies a cold agent could resume and fixes doc gaps. **This
   is the safety gate:** if it can't confirm a cold pickup, fix the gaps or fall back
   to COMPACT. Do not clear.
3. `/clear` is destructive and human-owned — **confirm with the user first**, then
   clear. Next session, `/catchup` rehydrates from the artifacts you just wrote.

## Step 4 — Report
State the branch, the reason (boundary + band + mode), what you externalized, and the
next command. For **both COMPACT and CLEAR**, stop and wait for the user's go-ahead —
propose, don't perform.

## Guardrails
- Never clear or compact-away un-externalized state. Externalize → verify → discard.
- **Confirm before compacting, not just before clearing.** Compaction discards
  information and you can't always predict what the next turn (e.g. a Socratic review
  of what was just built) will need. Propose keep/drop; let the user decide.
- Never compact mid-step; wait for a checkpoint.
- **Prevention beats cleanup:** if an upcoming subtask will read a lot (large files,
  wide searches), delegate it to a subagent that returns only a summary — that keeps
  this thread from bloating in the first place, which is cheaper than compacting later.
- The hook only nudges. You make the call, and the human owns `/clear`.
- Don't over-manage: for short or fast-iterating sessions where a compaction would
  disrupt more than it helps, CONTINUE and say why.
