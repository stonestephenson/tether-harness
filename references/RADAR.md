# RADAR — the harness's SOTA log

Dated entries from the `sota-radar` sweep (`.claude/skills/sota-radar/SKILL.md`): does new
research/industry evidence or Claude Code platform drift warrant harness updates? Newest
entry first; the newest entry's date is the next sweep's watermark. Entries **propose**;
only the user promotes findings into `ROADMAP.md`. A **NULL verdict is a successful sweep**
— it means the harness is still current.

Scheduled: monthly cloud routine (1st of the month, 13:00 UTC) — read-only on the repo, so
cloud-run entries arrive as session reports and get appended here in a confirmed session.

---

## RADAR 2026-08-01 · monthly cloud sweep (window: 2026-07-09 → 2026-08-01)

**Verdict: PROPOSE (1 needle-mover — platform-drift hygiene).** The research half is
clean: no new roadmap-worthy research or industry evidence, and everything surfaced
clustered onto already-incorporated, already-rejected, already-watchlisted, or
pre-watermark material. But a platform change in the window — Claude Opus 5's launch —
left the context-health budget map stale, miscalibrating the gauge on the newest
flagship. **Promoted to ROADMAP #11 and fixed 2026-08-10** (see below).

**Platform drift.**

- **DRIFT (actionable) — `claude-opus-5` missing from the context-budget map.** The
  changelog line for the window is "Claude Opus 5 introduced with 1M context window."
  `context-health.py`'s `MODEL_BUDGETS` allowlist listed opus-4-8/4-7/4-6, sonnet-5,
  fable-5, mythos-5 — but not opus-5. The lookup is a prefix match, and
  `"claude-opus-5".startswith("claude-opus-4-8")` is False, so Opus 5 sessions fell
  through to `DEFAULT_BUDGET = 200_000` and computed occupancy against 1/5 of the real
  window — firing WARN/ACT/CRIT at ~14%/17%/19% of actual capacity, i.e. nagging
  `/context-health`, compact, and handoff ~5× too early on the current flagship. It
  failed in the safe direction (over-warn, per the hook's own design comment) and never
  wedged a session, so this was a calibration defect rather than a break — but it
  materially degraded the gauge. Maps to fact 12 / ROADMAP 5b, the same hygiene lane the
  inaugural audit used.
- **No contract breaks.** Facts 1–13 re-checked against `code.claude.com/docs/en/hooks`.
  Fact 4 (`UserPromptSubmit` `additionalContext`) CONFIRMED — a first-pass fetch summary
  wrongly denied it and a focused re-fetch corrected it; context-health's model-facing
  path is intact. Fact 3 (`stop_hook_active`) still absent from the doc — the same
  doc-vs-behavior gap the 2026-07-09 cloud sweep flagged, not a new break; the local
  suite exercises it behaviourally. Fact 12 reconfirmed: still no context-window size in
  hook inputs, model id only optionally on `SessionStart` — which is precisely *why* a
  stale map is the failure mode, since there is no auto-calibration primitive to fall
  back on.
- **Opportunities (low value, noted not proposed):** `Stop` now also accepts
  `hookSpecificOutput.additionalContext` — marginal, since done-gate already feeds
  failures back via `decision:block` + `reason`. New/expanded events in the doc
  (`StopFailure`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`, `Setup`,
  `UserPromptExpansion`, `CwdChanged`, `WorktreeCreate/Remove`,
  `PermissionRequest/Denied`) — none map to tether's two pillars today. Changelog items
  with no contract impact: nested `.claude/skills` contextual loading, case-insensitive
  frontmatter keys, subagents spawning nested agents to depth 3, `TeamCreate`/`TeamDelete`
  removed (tether uses no teams), external-plugin install-consent.

**Suites:** N/A at sweep time (cloud mode — read-only, no `verify.sh` run). Re-run
locally on promotion: **20 + 46 green** with the new regression cases (2026-08-10).

**Needle-movers.**

1. **Add `claude-opus-5` to the context-health budget map** (→ ROADMAP #11, **done**).
   Evidence: the in-window changelog line above plus the in-code defect, verified by
   reading `MODEL_BUDGETS` and the `startswith` fallthrough. Tier: **actionable**
   (deterministic and verified in-code — not a judgment call). Harness delta: the gauge
   reports true occupancy on Opus 5 and the 5×-early nag disappears.

**Watchlist.**

- **The budget map is a permanent radar chore** (NEW framing, not a proposal). The
  allowlist lags every frontier launch by construction; the durable fix is a platform
  context-window/occupancy field (PLATFORM-ASSUMPTIONS "opportunities watch"), still
  absent this sweep. Until it exists, each new model id must be added by hand — re-check
  every sweep, and promote to a design change only if the platform ships an occupancy
  primitive, which would supersede 5b entirely.
- **Capped / co-evolving verifiers** — corroborated but unchanged. "Capped Evaluation
  with Randomized Tests" / CapCode–CapReward (arXiv 2606.07379) is still
  eval/RL-fine-tuning-side, not a harness-adoptable inference-time gate. Promote only if
  a project-scale adaptation appears.
- **"Memory notes don't measurably improve agents"** — still no clean corroboration. A
  March-2026 structured-memory paper (arXiv 2603.13258, pre-watermark) argues the
  opposite for *structured* memory, which is distinct from prose notes and
  repo-map/vector-RAG-adjacent (already rejected). No status change.
- **Agent-invoked / rubric-guided compaction as a platform primitive** — not shipped
  (the changelog shows auto-compact triggers for Opus 4.8 on Bedrock, not agent-invoked
  rubric compaction). The current gauge(hook) + judgment(skill) split still holds.

**Rejected this sweep.** Anthropic "Scaling Managed Agents: Decoupling the brain from the
hands" — pre-watermark (2026-04-08) and hosted-product/infra; its "harnesses go stale as
models improve" thesis only validates tether's prune-scaffolding meta-posture, no
adoptable mechanism. Latent Context Compilation / Context Codec — training-side (trainable
LoRA "compiler"), modifies the model, not scaffold-adoptable; same class as the
already-dropped CompactionRL. BenchJack (2605.12673) — benchmark-integrity tooling; tether
isn't a benchmark. Scaffold taxonomy / harness-design surveys (2604.03515, 2606.20683) —
survey-tier, no adoptable technique. Cursor Computer Use GUI-testing loop (Feb 2026) —
pre-watermark; external-signal QA already covered by `/verify` + `/run` (same reasoning as
the gstack `/qa` reject). Zylos "65% of enterprise failures = context degradation" — vendor
blog, no primary methodology, anecdote tier. SWE-bench Verified leaderboard — no
scaffold-technique frontier shift; mini-swe-agent's minimal-scaffold result reaffirmed.

**Sources swept:** 5 searches / 4 fetches (2 usable). Load-bearing:
code.claude.com/docs/en/hooks (×2 focused) ·
raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md (the Opus 5 / 1M line) ·
arXiv 2605.02964, 2605.21384, 2606.26300, 2606.07379, 2511.21654, 2604.10352, 2603.13258,
2604.03515, 2606.20683 · Cursor "reward hacking swamping" blog · Anthropic managed-agents
(date/thesis via secondary coverage — primary 403'd).

**Ops notes (for future cloud runs).**

- **Blocked domains:** `anthropic.com/engineering/*` returns 403 to the WebFetch fetcher
  (recurring — secondary coverage was needed for the managed-agents item). If primary
  anthropic.com fetches matter for this routine, the environment's network policy needs
  an allowlist entry.
- **Wrong changelog path:** `code.claude.com/docs/en/release-notes` 404s; the canonical
  source is the GitHub `CHANGELOG.md`. Now recorded alongside fact 13 so future sweeps
  don't rediscover it.
- **Fetch reliability:** the first hooks-doc fetch's summary wrongly reported fact 4 as
  broken. Double-check any break a single fetch reports before trusting it.

---

## RADAR 2026-07-09 · harness landscape survey (manual, user-directed)

**Verdict: NULL (no new roadmap items) + corroboration for #4** — surveyed the 8
most-starred harness/scaffolding frameworks (superpowers 250.7k★, gstack 120.8k★, spec-kit
119.1k★, GSD 64.7k★ [archived], ruflo 63.7k★, BMAD 50.3k★, SuperClaude 23.5k★ + 5 noted).
Nothing found that the roadmap or built-ins don't already cover. New doc:
`references/LANDSCAPE.md` — per-framework verdicts + the don't-re-sweep list; wired into
the sota-radar skill's Step 0.

**Key finding:** the field convergently rediscovered tether's skills layer (superpowers'
14 skills ≈ tether's 8 + #4) but enforces everything in prose — superpowers' only hook is
a session-start loader; "verification-before-completion" ships as a *skill*. No framework
has a deterministic tier, measures context occupancy, or cites research.
**Corroboration:** #4 cold reviewer — superpowers two-stage fresh-context review + gstack
cross-model review (noted under #4). Rejected-list reinforcement: personas (BMAD QA
persona self-certifies) and skill sprawl (Chase AI single-run bake-off via EveryDev —
anecdote-tier, directional: vanilla Claude Code beat all five frameworks) — both noted in
ROADMAP §Rejected.
**Rejected this sweep:** real-browser QA loop (gstack `/qa`) — sound external signal,
already covered by built-in `/verify` + `/run`; persistent KB memory (gstack GBrain) —
vector-RAG already rejected, and Ruflo's version audited as ~99% duplicate entries.
**Sources swept:** GitHub API (13 repos) · 8 README/tree fetches · roman-rr Ruflo audit
gist · EveryDev five-framework comparison (secondary — reports Chase AI's single-run
bake-off; anecdote tier). Links in `LANDSCAPE.md`.
**Addendum (same day):** the user commissioned one follow-up from this survey into
`ROADMAP.md` as item #6 — harness self-benchmark (`bench/`; zero-budget Tier 0 is the
acceptance target, paid framework/Terminal-Bench arms optional). The NULL verdict above
covers swept external findings; #6 is a user-initiated instrument, not a promoted finding.

## RADAR 2026-07-09 · cloud smoke run (window: 2026-07-09 → 2026-07-09)

**Verdict: NULL** — first scheduled-cloud sweep, fired the same day as the inaugural baseline,
so a near-zero window. Contracts intact; everything surfaced clusters onto already-incorporated
or already-queued items. Run: routine `tether-sota-radar` (claude-opus-4-8, read-only tools).

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
