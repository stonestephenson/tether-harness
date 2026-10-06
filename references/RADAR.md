# RADAR — the harness's SOTA log

Dated entries from the `sota-radar` sweep (`.claude/skills/sota-radar/SKILL.md`): does new
research/industry evidence or Claude Code platform drift warrant harness updates? Newest
entry first; the newest entry's date is the next sweep's watermark. Entries **propose**;
only the user promotes findings into `ROADMAP.md`. A **NULL verdict is a successful sweep**
— it means the harness is still current.

Scheduled: monthly cloud routine (1st of the month, 13:00 UTC) — read-only on the repo, so
cloud-run entries arrive as session reports and get appended here in a confirmed session.

---

## RADAR 2026-10-01 · monthly cloud sweep (window: 2026-08-01 → 2026-10-01)

**Verdict: PROPOSE (3 needle-movers)** — no hook contract breaks (all 13 facts hold; fact
3 is now *documented*, closing a gap two sweeps flagged), but the context-budget map has
an **under-warning** hole — the dangerous direction — and two in-window papers bear
directly on the harness. The research half is **evidence-capped**: arxiv.org and every
paper mirror are blocked by the environment's network policy, so no research item here
was graded from a primary source.

> **Local verification 2026-10-05 (human-confirmed session) — read this before the
> needle-movers below.** arxiv is reachable locally, so both papers were fetched and read
> (PDFs in `references/papers/`); needle-mover 1 was re-checked against the changelog,
> `context-health.py`, the model-config docs, and two months of local transcripts.
>
> 1. **Needle-mover 1 → ROADMAP #13, landed — with a code check the sweep did not
>    propose.** All three changelog paths confirmed. The "bare id with no `[1m]` suffix is
>    ambiguous" idea does not work for the current generation: 1M is the default *with no
>    suffix* (changelog), and local transcripts carry ~40,000 assistant lines with a bare
>    id against 69 suffixed. It is exactly right for Opus 4.6 / Sonnet 4.6, which reach 1M
>    *only* through `[1m]` — and the map had been sizing those bare ids at 1M since 5b, so
>    that was fixed too. Beyond the ids, four of the platform's own window caps are plain
>    env vars a hook can read (`CLAUDE_CODE_DISABLE_1M_CONTEXT`,
>    `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `CLAUDE_CODE_AUTO_COMPACT_WINDOW`,
>    `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`), so the gauge now lowers its budget to match them.
>    The rest stays documentation.
> 2. **Needle-mover 2 → ROADMAP #14, landed as a wording change on internal-consistency
>    grounds; the summary below overstates the paper.** 23.6% → 5.3% is the *combined* arm
>    (escalation tool **plus** a written anti-hacking policy). Alone, the tool reached
>    15.0% and the policy 9.7% — the prose policy did more than the tool — and a one-line
>    prompt instruction reached 16.9%. Single author, nine problems, one benchmark; the
>    author notes the tool's prompt also carried normative guidance ("always preferable to
>    gaming the tests"), so availability and instruction are confounded. Watchlist-tier
>    evidence, supporting a change that stands on its own: the red-path block said only
>    "fix these", while the tamper block already told the agent to inform the user.
> 3. **Needle-mover 3 → not promoted.** The study ran Nemotron-3 (30B/120B/550B) and
>    Mistral-Medium-3.5 at 32k–128k budgets on single tasks, one run per setting, and
>    tested automatic in-loop elision/summarization. It never looks at long sessions in a
>    large window, so it neither supports nor narrows HARNESS §11's claim. Filed in
>    PAPERS.md with that caveat; §11 untouched.
>
> Also: the September routine **did** fire and returned NULL (entry below). The
> PLATFORM-ASSUMPTIONS amendments (facts 14–16, fact 3 documented, the raw-`hooks.md`
> recipe) landed after re-checking each against the doc source. The "prose memory notes"
> watchlist item is dropped as recommended. Not actioned: the LANDSCAPE scope note, and
> the arxiv allowlist for the cloud environment (a user-side setting).

**Window note:** there is no `2026-09-01` entry, so this window spans two months. Either
the September routine didn't fire or its report was never appended. Worth confirming
before trusting the log as continuous.

**Platform drift.**

**No contract breaks.** Facts 1–13 re-checked against `code.claude.com/docs/en/hooks`,
this time by fetching the doc **source** (`hooks.md`, 249 KB) and grepping it, instead of
trusting a summarizer.

- **Fact 4 — CONFIRMED, and the summarizer lied again (3rd sweep running).** The broad
  fetch reported `UserPromptSubmit` `additionalContext` as "NOT accepted". The source has
  an explicit field table and a JSON example (`hookSpecificOutput.hookEventName:
  "UserPromptSubmit"`, `additionalContext`). context-health's model-facing path is intact.
  **The recipe should change** — see ops notes.
- **Fact 3 — CONFIRMED and now DOCUMENTED (de-risk).** `stop_hook_active` is explicitly
  specified for Stop hooks: *"`true` when Claude Code is already continuing as a result of
  a stop hook."* This resolves the doc-vs-behavior gap carried since 2026-07-09.
- **Fact 2 — CONFIRMED.** Stop's decision table documents `decision: "block"` + required
  `reason`, with an example.
- **Fact 12 — MATERIALLY CHANGED (the top watch item moved for the first time).** Detail
  under Watchlist. No break; tether's workaround still correct.
- **Facts 1, 5, 6, 7, 8, 13 — CONFIRMED.** Fact 10 not re-verified doc-side (no evidence
  of change); fact 9 isn't doc-verifiable.

**Three design choices vindicated** (changelog items that would have bitten a less careful
harness):

- `claude plugin validate` now warns when a shell-form hook leaves `${CLAUDE_PLUGIN_ROOT}`
  unquoted — tether already quotes it in all four hooks.
- A top-level `$schema` in `hooks/hooks.json` used to raise "unknown key" — tether's has
  none.
- Blocking auto-compaction *triggered to recover from a context-limit error* now surfaces
  the API error and fails the request. `pre-compact-guard.py` only ever blocks `manual`
  and treats an absent trigger as auto, so tether cannot trigger this.

**New facts worth pinning** (proposed `PLATFORM-ASSUMPTIONS.md` amendments):

- **Stop hooks have an 8-consecutive-continuation cap** (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`
  raises it); after 8 blocks Claude Code overrides and ends the turn. Non-binding for
  tether — done-gate's `stop_hook_active` guard never blocks twice in a row — but it
  becomes the real ceiling if that guard is ever relaxed. Pin it.
- **`additionalContext`, `systemMessage` and plain stdout are capped at 10,000
  characters**, with no env var to raise it; over-cap output is written to a file Claude
  is *not* asked to read. done-gate's `REASON_CAP = 5000` sits safely inside it. No
  action, but the cap should be a fact so nobody raises that constant blindly.
- **The transcript is written asynchronously and may lag** the in-memory conversation. The
  doc now says hooks needing the current turn's final assistant text should use
  `last_assistant_message` on Stop/SubagentStop rather than parsing the transcript.
  Relevant to fact 9's live-fire recipe.
- **Event count is 33** (31 events + `Elicitation`/`ElicitationResult`). Re-baselines the
  32 → "29" confusion: the 29 was a summarizer artifact. New since the last sweep:
  `PreModelSwitch`, `PostModelSwitch`, `MessageDisplay`, `DirectoryAdded`, `SessionEnd`.
- **Fact 13 gains a better recipe:** `code.claude.com/docs/en/hooks.md` serves raw
  markdown.

**Opportunities (noted, not proposed):** `PostCompact` still has no decision control and
no `additionalContext` — the watch item is unchanged. `last_assistant_message` on Stop
could save done-gate a transcript read, but done-gate doesn't read the transcript, so it's
moot.

**Suites:** N/A (cloud mode — read-only, no `verify.sh` run, no live-fire). Re-run locally
on promotion; main was 20 + 46 + 27 at last report.

**Needle-movers.**

1. **Context-budget map: a known-1M model can actually be running at 200K → the gauge
   goes silent (under-warning).** (→ ROADMAP #13, **done** — see the verification note.)

   *Evidence (primary, fully verified — the only verified needle-mover here).* Three
   independent changelog paths put a model that `MODEL_BUDGETS` maps to 1M into a 200K
   session: a custom-`ANTHROPIC_BASE_URL` gateway that "stops at 200K" (2.1.278-era line:
   "run `/autocompact 200k` if your gateway stops at 200K"); a plan without 1M usage
   credits ("Usage credits required for 1M context", plus Fable long-context 429s on
   Pro/Team); and a fallback that "dropped the context window from 1M to 200K tokens"
   (v2.1.286). Verified in-code against `context-health.py`.

   *Why it matters.* This is the exact direction ROADMAP #11's design note says the
   allowlist exists to prevent — but it reasons only about *unknown* ids. Here a *known*
   id has a situationally smaller window. With `budget = 1M` and a real window of 200K,
   WARN would need 700K tokens, which the session can never reach: **the gauge never
   fires at all, silently, through a real context exhaustion.** The existing code caveat
   documents only the mirror-image case (a 200k model on the 1M beta mapping low).

   *Tier:* **actionable** (deterministic, primary-sourced, verified in-code).
   *Harness delta:* the gauge stops being silently inert for gateway/credit-capped/
   fallback sessions.

   *Draft as proposed:* the cheap, in-character fix is documentation, not detection —
   amend the code caveat to name this direction, add a PLATFORM-ASSUMPTIONS fact 12
   corollary, and tell gateway/non-credit users to set `CLAUDE_CONTEXT_BUDGET` (which
   always wins). Consider only if cheap: treat a bare id with no `[1m]` suffix as
   ambiguous. Resist building fallback detection — there is no hook field for it.

2. **Escalation channels — a sanctioned exit next to done-gate's block.** (→ ROADMAP #14,
   **done** as a wording change — and see the verification note: the figures below are
   the combined arm, not the escalation tool alone.)

   *Evidence.* "Can escalation channels redirect reward hacking toward defect
   disclosure?" (arXiv 2608.29460, in-window). Abstract-level: structured reporting tools
   offered to the agent at points of conflict cut reward hacking 23.6% → 5.3% across 8
   frontier models in 5 families, eliminated entirely for 6 of 8, with no detectable cost
   or performance overhead, and added +10.1pp defect-detection coverage. Explicitly
   contrasted with containment-based approaches.

   *Why it fits tether.* done-gate is pure containment: red verify → block with "resolve
   it before finishing", plus anti-tamper if the verifier changes. When the task is
   genuinely impossible or the verifier itself is wrong, the agent's sanctioned exits are
   "fix it" or "loop"; tampering is the unsanctioned third, which is precisely the
   pressure the paper measures. An escalation affordance — *say so, to the human, instead
   of going green* — fills that gap, sits in the judgment tier (a skill/prompt
   affordance, not a hook), and is consistent with the human-gated-irreversibility
   invariant. It violates no invariant.

   *Tier:* **benchmarked-but-single-preprint, and UNVERIFIED-PRIMARY.** arxiv.org is
   blocked; this is abstract text via search snippet, not a fetched paper. Strictly the
   ladder puts a single preprint on the watchlist; I'm proposing it because the measured
   effect is large, multi-model, and mechanism-level — but **promotion must be gated on
   reading the PDF locally first.**
   *Harness delta:* closes the "no sanctioned way to report an impossible task or a
   broken verifier" gap that tether's own gate creates.

   *Draft as proposed:* extend before adding (ground rule a). Likely one paragraph in
   done-gate's block reason naming escalation as a legitimate response, plus a line in
   the `/harden` or `/ship` judgment path on how to escalate. No new hook; no new skill
   if an existing one can carry it. Acceptance: primary source read and the effect size
   confirmed; the wording gives a real exit without weakening "verify, don't
   self-certify" (the escalation goes to the human, never to the gate); regression
   coverage for the block message; then port.

3. **The context pillar's benefit is narrower than HARNESS claims — first external
   component ablation.** (**Not promoted** — see the verification note.)

   *Evidence.* "An Empirical Study of Harness Design for Coding Agents" (arXiv
   2609.20804, in-window): 176 matched harness configurations, 4 models, SWE-bench
   Verified + Terminal-Bench 2.1 — component ablations of planning, action space and
   context management. Headline findings: context management's value "mainly prevents
   overflow failures under tight budgets" and "becomes most valuable as the
   context-window budget tightens"; planning "shifts from an accuracy scaffold to a cost
   saver"; rule-based elision before LLM summarization is most efficient.

   *Why it matters, including where it cuts against tether.* This is the external
   replication eval #6 never got, and it agrees with #6's uncomfortable conclusion:
   harness components are mostly not accuracy scaffolds for capable models. It also
   sharpens — and narrows — the context pillar: HARNESS §11 claims "context hygiene
   keeps the model sharp, which keeps its verification and judgment good"; this study
   locates the measurable benefit in *overflow prevention under a tight budget* instead.
   With the current roster natively 1M (Opus 5/5.5, Sonnet 5/5.5, Fable — confirmed
   in-window), "tight budget" is rarer than when context-health was designed, which
   lowers the gauge's expected value on current flagships. The prune-scaffolding
   meta-posture says to take that seriously rather than bury it.

   *Caveat that keeps it from being conclusive:* the models are Nemotron-3 (three sizes)
   + Mistral-Medium-3.5-128B — not frontier Claude, and partly at small context budgets.
   External validity to Claude Code on Opus 5.5 is limited.

   *Tier:* **benchmarked, UNVERIFIED-PRIMARY** (arxiv blocked; abstract via search).
   *Draft as proposed:* docs + evidence only — add the paper to PAPERS.md; narrow the
   §11 claim; record it in `eval/README.md` as external corroboration; add one line to
   the meta-posture noting the gauge's value is now budget-conditional.

**Watchlist.**

- **Occupancy primitive — STATUS CHANGE: partially arrived (first movement in three
  sweeps).** `context_tokens` now ships in hook input — "the input, cache read, cache
  creation, and output tokens of the last response in the main conversation, combined" —
  which is essentially what `context-health.py` computes by hand. **But** it appears only
  on `SessionStart` (resume/fork) and `PreModelSwitch`/`PostModelSwitch`, not on
  `UserPromptSubmit`/`Stop` where the gauge runs, and there is still **no window-size
  field** anywhere. So the numerator partially arrived; the denominator did not. The
  chore and the map both stand. Separately, `PreModelSwitch`/`PostModelSwitch` carry
  `from_model`/`to_model` — the doc now recommends them to "follow the model as it
  changes during a session", which is a supported alternative to tether's transcript
  read (fact 12's workaround — still correct, no change needed). *Promote when:*
  `context_tokens` reaches `UserPromptSubmit`/`Stop`, or any window-size field ships.
- **"Prose memory notes don't improve agents" — recommend REFRAME or DROP** (**dropped
  2026-10-05**). Three sweeps have found no clean replication, and this sweep found the
  field answering a *different* question with the opposite sign: procedural/structured
  memory measurably helps (Memp; 2606.23127; *How Memory Management Impacts LLM Agents*,
  ACL 2026; trajectory notes 42.8%→51.0%→58.6%). ROADMAP #2 rests on TRACE's own measured
  effect and doesn't need this item. Keeping it is an open question nobody is going to
  close.
- **Capped / co-evolving verifiers — unchanged.** CapCode/CapReward (2606.07379) still
  eval/RL-side. New but not promoting: **Hack-Verifiable Terminal Bench** (2608.22103) —
  benchmark-tier, unverified; re-check whether it ships an adoptable detector the way
  EvilGenie shipped edit detection.
- **NEW — "verify-on-stop guards" is now a named pattern in the literature.** The
  11-system source-code study documents it "for the first time" alongside agent-maintained
  memory pipelines and lineage compaction. That is tether's done-gate, independently
  named. *Watch for:* anyone publishing an *evaluation* of the pattern — that's the
  external evidence #6 wanted.
- **NEW — speculative reward hacking.** A September 2026 Handshake audit (113 tasks)
  reports >80% of rollouts from most frontier models reasoning about a grader or hidden
  tests *nobody mentioned*, with 10–25% of those pulling work away from the actual ask.
  Industry audit, unverified primary. *Promote if replicated:* it would argue for cheap
  harness language stating what the real verifier is — squarely in tether's lane.
- **Agent-invoked rubric compaction as a platform primitive — still not shipped**
  (verified: `PostCompact` has no decision control and no `additionalContext`). The
  gauge(hook) + judgment(skill) split still holds.

**Rejected this sweep.** Runtime/inference-side, not scaffold-adoptable (same class as the
already-dropped CompactionRL / Latent Context Compilation): ReCAP / Persistent Context
Graphs (2609.40118 — attention-derived importance scores, KV-level); KVMem (2609.04852 —
GPU/KV virtualization); Compact-Memory via online clustering (2609.04915). Survey/taxonomy
tier, no adoptable mechanism: *Harness Engineering: ...Eleven Systems* (2609.00006) — kept
as corroboration, see below, and as a LANDSCAPE reference; Context Compaction Theory
(2608.01326) — theory-tier, no decision rule surfaced, unverified. Pre-watermark:
ESAA-Conversational (2606.23752 — converges on tether's own
`handoff.md`/`state.md`/`decisions.md` cold-start doc set; corroboration only, surfaced
late); HarnessBridge (2606.12882, training-side); DeepSWE (2607.07946); Harness Handbook
(2607.13285); Rate-Distortion memory compaction (2607.08032). Corroboration for
already-landed #1, not new items: ImpossibleBench (GPT-5 "passed" 54% of impossible tasks
by editing tests); GLM 5.2 at 57%/73% hack rates; METR's o3 at 39/128 runs with "telling
it not to cheat had a nearly negligible effect" — which is the cleanest possible
restatement of "deterministic gates over prose". No scaffold-technique frontier shift:
SWE-bench Pro and DeepSWE now hold the harness *fixed* (mini-swe-agent, standardized
tooling, 250-turn limit) specifically to stop vendors tuning scaffolds — so the venue for
"a scaffold technique moved the leaderboard" is closing by construction. Secondary/anecdote
tier: Agent Brief "The Harness Is the Product", Addy Osmani's harness-engineering post,
InfoQ/Medium coverage of the Anthropic three-agent harness (already incorporated via #4).

**Corroboration worth recording** from 2609.00006 (no action, but it's the strongest
independent support tether has received): across ~4M lines of eleven production harnesses
— Claude Code, Codex CLI, Gemini CLI, Mistral Vibe, OpenHands, Aider, mini-swe-agent,
Hermes, Pi, OpenCode, OpenClaw — "no agent runtime imports a general-purpose agentic
framework, and none retrieves code with vector embeddings; the field runs on hand-rolled
async loops and deterministic retrieval." That directly reinforces the standing
repo-map/vector-RAG rejection, and SKILL.md leading MCP in adoption (9/11 vs 8/11)
reinforces the skills layer. Submission date is ambiguous (ID says 2609, search reports
July 15 2026) — unverified.

**Proposed LANDSCAPE note (scope, not a new entry):** `LANDSCAPE.md` grades *methodology
frameworks layered on top of a harness* (superpowers, gstack, BMAD…). The eleven systems
above are *harnesses themselves* — a different category, and two of them (Codex CLI,
OpenCode) are tether's port targets, not competitors. Suggest one scope sentence plus
2609.00006 as a reference document, rather than eleven entries.

**Sources swept:** 6 searches / 2 doc fetches / 2 raw `curl` fetches / 5 blocked fetch
attempts. Load-bearing: `code.claude.com/docs/en/hooks.md` (full source, grepped — all 13
facts) · `raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` (7,973
lines; window = top → the pre-watermark Opus 5 line; Opus 5.5 and Sonnet 5.5 both 1M) ·
in-repo: `context-health.py`, `done-gate.py`, `pre-compact-guard.py`, `hooks.json` ·
arXiv 2608.29460, 2609.20804, 2609.00006, 2608.22103, 2608.01326, 2609.40118, 2609.04915,
2609.04852, 2606.23752 (all **abstract-level via search — none fetched**) ·
ImpossibleBench / GLM 5.2 / METR / Handshake figures via search summaries.

**Model-roster chore (standing, ROADMAP #11): clear this sweep.** Opus 5.5
(`claude-opus-5-5`, 1M) and Sonnet 5.5 (`claude-sonnet-5-5`, 1M) both launched in-window
and **both map correctly** — `startswith` catches them on the existing `claude-opus-5` /
`claude-sonnet-5` prefixes. Fable 5.1 likewise. Haiku 4.5 correctly falls through to the
200K default. No new entry needed — the prefix design absorbed this round of launches. The
real exposure is needle-mover #1, which is not about missing ids at all.

**Ops notes (for future cloud runs).**

- **BLOCKED DOMAINS — this one needs an environment change.** Every primary-source route
  is refused by the egress proxy: `arxiv.org`, `export.arxiv.org` (403 over HTTP),
  `www.alphaxiv.org`, `huggingface.co`, `www.semanticscholar.org`,
  `api.semanticscholar.org`, `ar5iv.org`. The skill's Step 2 requires "fetch the primary
  source (abstract at minimum); never grade from a headline" — that is currently
  impossible in cloud mode, which is why all three research items above are marked
  unverified-primary and why none should be promoted before a local read. **Allowlisting
  `arxiv.org` (and ideally `huggingface.co/papers`) would restore the research half.**
  `anthropic.com/engineering/*` was not retried this sweep; the prior 403 presumably
  stands. Reachable and working: `code.claude.com`, `raw.githubusercontent.com`,
  WebSearch.
- **Fetch the doc source, not the summary — make this the recipe.**
  `code.claude.com/docs/en/hooks.md` returns 249 KB of raw markdown over plain `curl`,
  greppable fact by fact. The summarizer misreported fact 4 as broken for the third sweep
  in a row, and also under-counted events. The "double-check any break a lone fetch
  reports" caution should be upgraded to "verify facts against the `.md` source; use the
  summarizer only for orientation." Suggest replacing step 1 of the PLATFORM-ASSUMPTIONS
  re-verify recipe accordingly. (**Done 2026-10-05.**)
- **Missing September entry.** No `2026-09-01` RADAR entry exists, so this sweep's window
  is two months. Check whether the routine fired and its report was never appended, or
  didn't fire at all. (**It fired; the report was never appended. Logged below.**)
- **Write tools were present despite the prompt stating otherwise.** I followed CLOUD mode
  as instructed: nothing in the repo was read-modified, no commit, no push, no PR.

---

## RADAR 2026-09-01 · monthly cloud sweep (window: 2026-08-01 → 2026-09-01)

> **Abridged record, logged late (2026-10-05).** The routine fired and succeeded, but its
> report was never appended, which is why the October sweep saw a two-month window. The
> text below is the part recoverable from the routine's run log, which truncates long
> messages; the rest (watchlist status, rejected list, ops notes) is in the session
> itself: <https://claude.ai/code/session_017EweaeJYAJBZqX2FiW6NEc>. Replace this entry
> with the full text if it is ever needed. Nothing in it was promoted.

**Verdict: NULL** — the harness is still current. No new roadmap-worthy research or
platform break in the window; everything surfaced clusters onto already-incorporated,
already-rejected, already-watchlisted, or pre-watermark material. The one in-window
platform change (model-switch hooks) is a low-value opportunity, not a proposal. The
budget-map chore is a **no-op this sweep** — no new 1M model launched (Opus 5, the only
current-gen flagship, shipped 2026-07-24 and is already mapped).

**Platform drift:** none (no breaks).

- **Facts 1–13 re-checked** against `code.claude.com/docs/en/hooks`. All hold. `Stop`
  blocks (exit 2 / `decision:block`); `UserPromptSubmit`
  `hookSpecificOutput.additionalContext` confirmed (also now offered on `SessionStart`
  and the new `PostModelSwitch`); `PostToolUse` exit 2 = non-blocking, stderr to Claude;
  `PreCompact` blockable with `manual`/`auto` matcher. Fact 3 (`stop_hook_active`)
  **still absent from the doc** — the same doc-vs-behavior gap flagged in the last two
  cloud sweeps, not a new break; exercised behaviorally by the local suite. Fact 12
  reconfirmed: **still no context-window/occupancy field** in hook inputs; model id only
  optionally on `SessionStart` (and now on the switch hooks — see below).
- **Opportunities (low value — noted, not proposed):** **NEW: `PreModelSwitch` /
  `PostModelSwitch` hook events** (changelog **2.1.251**), carrying `from_model` /
  `to_model` canonical ids (e.g. `claude-opus-5`); `PostModelSwitch` accepts
  `additionalContext`. This is the first hook input to surface a model id outside
  `SessionStart` — in principle it could let `context-health.py` re-detect the budget on
  a mid-session model switch. *(The recovered text ends here.)*

**Research half (from the run log, not the report's own wording).** The in-window papers
that surfaced were benchmarks only — SWE-Bench ProMax (arXiv 2608.09802) and SWE Refactor
Bench — evaluation instruments, not adoptable harness mechanisms. All reward-hacking and
compaction work that surfaced was pre-watermark or already classified.

**Sources swept (from the run log):** 6 searches / 3 fetches (the hooks doc once; the
changelog twice, because the first summarizing fetch returned nothing usable).

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
