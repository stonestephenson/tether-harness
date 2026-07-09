---
name: sota-radar
description: Monthly maintainer sweep for the tether harness — decide whether NEW research/industry evidence or Claude Code platform changes warrant harness updates. Filters hard against the harness's evidence bar and reports needle-movers / watchlist / NULL; never modifies the harness itself. Use on the scheduled monthly run, when the user says "run the radar", "sweep for new research", "is the harness still SOTA", or after a major Claude Code release. Maintainer tooling for THIS repo only — it does not ship to tether users.
---

# sota-radar — is the harness still state of the art?

You are the recurring audit that keeps tether current: a deterministic trigger (cron or
the user) fires you; you supply judgment; the **user** is the only gate that turns a
finding into work. Your output is one dated RADAR entry. The 2026-07-09 audit that
produced `ROADMAP.md` is the template run — match its rigor and its honesty (it examined
~15 candidates and kept 5).

## Modes

- **Local session (default):** full checks; append your entry to `references/RADAR.md`.
- **Cloud/scheduled run** (you'll know: no Write/Edit tools): everything is the same
  except delivery — put the COMPLETE entry in your final message, starting with a
  one-line TLDR (`verdict: NULL` or `verdict: PROPOSE (n items)`). Do not try to write
  to the repo, commit, or open PRs. A later human-confirmed session appends your entry.

## Step 0 — load the immune system (in this order)

1. `plugins/tether/references/HARNESS.md` §9–§10 — the invariants and the evidence table.
2. `plugins/tether/references/PAPERS.md` — what's already incorporated.
3. `ROADMAP.md` — the open backlog (don't propose what's already queued) and, critically,
   **"Rejected on evidence"** (don't re-surface those without materially NEW evidence —
   and if you have new evidence, say explicitly what changed).
4. `references/RADAR.md` — the log. **Watermark = the date of the newest entry**; your
   sweep covers watermark → today. Re-check every open watchlist item.
5. `references/PLATFORM-ASSUMPTIONS.md` — the platform facts the hooks depend on.

## Step 1 — platform drift check (deterministic half)

- Fetch the hooks reference (`https://code.claude.com/docs/en/hooks`) and diff reality
  against each fact in `PLATFORM-ASSUMPTIONS.md`. Classify: **breaks** (a contract the
  hooks rely on changed) vs **opportunities** (new events/fields the harness could use —
  the file's "opportunities watch" section says what to look for).
- Scan the Claude Code changelog/release notes since the watermark for hook-, skill-,
  context-, or memory-related changes.
- **Local mode only:** also run `bash .claude/verify.sh` (both suites) and live-fire
  `plugins/tether/hooks/context-health.py` against a real current transcript (read-only;
  fake `session_id`) to confirm the transcript format still parses.

## Step 2 — research & industry sweep (judgment half)

Search window: watermark → today. Budget: **~8–15 web calls total** — this is a monthly
delta, not a dissertation. If something demands a deep dive, watchlist it with a note
instead of chasing it.

Query starters (adapt; drop stale ones, add ones the current ROADMAP suggests):
- coding agent verification / reward hacking / test tampering (new benchmarks or defenses)
- agent context management: compaction, handoff, memory (and whether prose-memory
  limitations findings are being replicated)
- SWE-bench Verified leaderboard movement — did a *scaffold technique* (not just a model)
  shift the frontier?
- Anthropic engineering blog + Claude Code release notes (practice + platform)
- Cognition / Cursor / Sourcegraph (Amp) / OpenAI engineering posts with actual data

For anything promising, fetch the primary source (abstract at minimum). Never grade from
a headline or a tweet-length summary.

## Step 3 — the filter (this is the whole point)

The harness exists for two goals: **verification, looped** and **context, curated**.
"Better" = makes those more optimal, efficient, or verifiable. Apply in order:

1. **Alignment test** — does it serve the two pillars without violating the invariants
   (no persona theater, no coupled multi-agent implementation, human-gated irreversible
   steps, minimal scaffold)? If it fights the invariants, it needs evidence strong enough
   to *change* an invariant — that's a PROPOSE with a giant warning label, not a casual add.
2. **Evidence ladder** —
   - **Actionable:** replicated, benchmarked, or deployed-at-scale-with-numbers.
   - **Watchlist:** single preprint, or an industry post with real data but no replication.
     Track it; re-check next sweep; promote when corroborated.
   - **Ignore:** anecdote, hype, vendor marketing without data.
3. **Needle-mover test** — would this change `ROADMAP.md` within a quarter? Twenty
   marginal skills mean nothing. When unsure, it's a watchlist item, not a proposal.

**The default verdict is NULL. A null sweep is a successful sweep** — it means the
harness is still current, and saying so honestly is the job. Do not manufacture findings
to look productive.

## Step 4 — compose the entry

```markdown
## RADAR <YYYY-MM-DD> (window: <watermark> → <today>)

**Verdict: NULL | PROPOSE (n needle-movers)** — one-line TLDR.

**Platform drift:** none | breaks: … | opportunities: … (each with the doc/changelog cite)
**Suites (local runs only):** green/red, n/n.

**Needle-movers:** (omit section if none)
1. <finding> — evidence (primary link + ladder tier), expected harness delta,
   draft ROADMAP entry (task-shaped: problem / evidence / sketch / acceptance).

**Watchlist:** (new items + status change of old ones: corroborated / stale / dropped)
- <item> — what would promote it, when to re-check.

**Rejected this sweep:** (one line each, with the reason — feeds the anti-noise memory)

**Sources swept:** <n> searches / <n> fetches — the load-bearing links.
```

## Step 5 — deliver

- **Local:** append the entry to `references/RADAR.md` (newest entry at the TOP, under
  the header), then summarize to the user. If the verdict is PROPOSE, remind them:
  promotion into `ROADMAP.md` (+ PAPERS.md + downloading PDFs to `references/papers/`)
  happens only on their explicit confirm.
- **Cloud:** the final message IS the deliverable — full entry, TLDR first.

## Hard rules

- **Propose-only.** Never edit `ROADMAP.md`, `PAPERS.md`, hooks, or skills; never
  download papers; never commit, push, or open PRs. Those happen in a human-confirmed
  session.
- Never re-propose a rejected idea without naming the new evidence that reopens it.
- Cite primary sources for every claim; mark anything you couldn't verify as unverified.
- Stay inside the web-call budget. Watchlist beats rabbit hole.
- If this skill file and the reference files disagree with reality (moved docs, renamed
  files), report the discrepancy in the entry rather than improvising silently.
