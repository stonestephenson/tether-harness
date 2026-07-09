# RADAR — the harness's SOTA log

Dated entries from the `sota-radar` sweep (`.claude/skills/sota-radar/SKILL.md`): does new
research/industry evidence or Claude Code platform drift warrant harness updates? Newest
entry first; the newest entry's date is the next sweep's watermark. Entries **propose**;
only the user promotes findings into `ROADMAP.md`. A **NULL verdict is a successful sweep**
— it means the harness is still current.

Scheduled: monthly cloud routine (1st of the month, 13:00 UTC) — read-only on the repo, so
cloud-run entries arrive as session reports and get appended here in a confirmed session.

---

## RADAR 2026-07-09 · cloud smoke run (window: 2026-07-09 → 2026-07-09)

**Verdict: NULL** — first scheduled-cloud sweep, fired the same day as the inaugural baseline,
so a near-zero window. Contracts intact; everything surfaced clusters onto already-incorporated
or already-queued items. Run: routine `tether-sota-radar`, session
`cse_01EwBrX1RbvixN8NefJaNuoB` (claude-opus-4-8, read-only tools).

**Platform drift:** none. 13/13 PLATFORM-ASSUMPTIONS facts checked against the hooks doc — 11
confirmed outright; facts 2–3 (`decision:block` confirmed; `stop_hook_active` not surfaced by
the fetch) marked unverified-this-fetch → behavioral re-verify on the next local sweep.
**De-risk:** PreCompact now documents `manual`/`auto` matcher values — resolves ROADMAP #3's
open caveat (folded into ROADMAP same day). Event count read as 29 vs the baseline's "32" —
presumed summarizer delta; re-baseline next local sweep. Changelog (July 2026): Notification
hook gains agent_needs_input/agent_completed, background agents auto-commit/PR, subagents run
in background by default — none touch tether's contracts.
**Suites:** N/A (cloud mode); green 18/18 + 15/15 at the same-day local baseline.

**Needle-movers:** none.

**Watchlist:**
- Compaction-as-judgment — corroborated as *validation* (blakecrosley "compaction is a
  decision"; ClawVM arXiv 2604.10352, MemGPT-lineage). No action; watch for an agent-invoked
  compaction platform primitive.
- "Memory notes don't measurably improve agents" — unchanged; still single-source.
- Co-evolving/capped verifiers — candidate mechanism appeared (capped evaluation with
  randomized tests, arXiv 2606.07379) but it's eval-side; promote only if a project-scale
  harness adaptation shows up.
- CompactionRL — **dropped** (training-side, per prior note; no new signal).
- NEW: reward-hacking corroboration cluster → extra weight behind ROADMAP #1 (RHB arXiv
  2605.02964, exploit rates to 13.9%; Cursor SWE-bench Pro study — hacking inflates Opus 4.8
  87.1%→73.0%; contrastive detection arXiv 2601.20103). Corroboration, not a new item —
  noted under #1.

**Rejected this sweep:** Anthropic three-agent app-building harness (already incorporated via
the harness-design post backing #4; doesn't overturn one-writer for interactive use);
SWE-bench scaffold movement (Confucius 2512.10398; Epoch v2 environment) — confirms scaffolds
matter, surfaces no adoptable technique. Standing rejections unchanged.

**Sources swept:** 5 searches / 1 fetch — hooks doc + July changelog · arXiv 2605.02964,
2606.07379, 2601.20103, 2604.10352, 2512.10398 · Epoch SWE-bench Verified · blakecrosley
compaction post.

**Ops notes:** the agent freelanced a "NULL doesn't warrant a notification" policy
(notifications are platform-side; skill patched to say so) and briefly mis-resolved the
reference paths before self-correcting (skill Step-0 paths clarified). Network allowlist:
no blocked domains reported.

## RADAR 2026-07-09 (window: baseline — ~8-month lookback)

**Verdict: PROPOSE (2 needle-movers + 2 sharpenings + hygiene)** — inaugural full audit;
all findings user-confirmed same day and promoted into `ROADMAP.md` #1–5.

**Platform drift:** breaks: `MultiEdit` tool no longer exists (matcher token defunct →
ROADMAP 5a). opportunities: hooks API now spans 32 events; `PreCompact` is blockable
(→ ROADMAP #3); `SessionStart` additionalContext + `watchPaths`/`FileChanged` (candidate
for #1's optional layer); confirmed **no** window/model info in hook inputs (constrains
5b). Full fact table established: `references/PLATFORM-ASSUMPTIONS.md`.
**Suites:** green, 18/18 + 15/15; context-health live-fire against a real 2026-07
transcript parsed correctly.

**Needle-movers:**
1. **Verifier-integrity guard** (→ ROADMAP #1) — test/verifier tampering went from
   anecdote to benchmarked failure mode; EvilGenie (arXiv 2511.21654) caught Claude Code
   itself reward hacking, and ships test-file **edit detection** as a working detector.
   Tier: actionable (multiple independent benchmarks: SpecBench 2605.21384, Verification
   Horizon 2606.26300).
2. **Corrections→enforcement compiler** (→ ROADMAP #2) — TRACE (arXiv 2606.13174): prose
   preference memory violated ~57% of the time; compiled runtime checks → 2–38%. Tier:
   actionable (large measured effect, converging replication that prose memory alone
   doesn't improve agents).

**Sharpenings:** PreCompact externalize-guard (→ #3, platform-unlock); /ship cold
reviewer (→ #4, generator–evaluator evidence from Anthropic harness-design post).

**Watchlist:**
- **Self-Compacting agents** (2606.23525) — currently *validates* the gauge+skill split;
  watch for agent-invoked compaction becoming a platform feature worth wiring.
- **"Memory notes don't measurably improve agents"** — single-source strands today;
  corroboration would further strengthen ROADMAP #2. Re-check next sweep.
- **Co-evolving verifiers** (Verification Horizon) — theory today; watch for practical
  mechanisms a project-scale harness could adopt.
- **Compaction-aware training** (CompactionRL 2607.05378) — training-side, not
  harness-actionable; drop unless it surfaces as an inference-time technique.

**Rejected this sweep:** mutation-testing gate (agent-level evidence negative: 2602.07900);
skill sprawl / personas / coupled multi-agent (minimal-scaffold SOTA: mini-swe-agent ~74%
SWE-bench Verified); auto-acting compaction; SessionStart auto-orientation (platform-native);
repo-map/vector-RAG; spec-driven formal artifacts; LLM-judge live gates; autonomous loops.
Reasons + citations: `ROADMAP.md` §Rejected.

**Sources swept:** 8 searches / 10 fetches. Load-bearing: code.claude.com/docs/en/hooks ·
arXiv 2511.21654, 2605.21384, 2606.26300, 2606.13174, 2602.07900, 2606.23525 ·
anthropic.com/engineering (effective-harnesses, harness-design) · swebench.com/verified ·
InfoQ Meta mutation-testing. Papers local: `references/papers/` (see PAPERS.md §2026).
