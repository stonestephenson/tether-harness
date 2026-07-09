# RADAR — the harness's SOTA log

Dated entries from the `sota-radar` sweep (`.claude/skills/sota-radar/SKILL.md`): does new
research/industry evidence or Claude Code platform drift warrant harness updates? Newest
entry first; the newest entry's date is the next sweep's watermark. Entries **propose**;
only the user promotes findings into `ROADMAP.md`. A **NULL verdict is a successful sweep**
— it means the harness is still current.

Scheduled: monthly cloud routine (1st of the month, 13:00 UTC) — read-only on the repo, so
cloud-run entries arrive as session reports and get appended here in a confirmed session.

---

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
