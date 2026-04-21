# Research: RPI Token Waste Audit (2026-04-21)

## Goal

The RPI pipeline (research-plan-implement) runs ~8 parallel subagents across 3 phases, each loading
full SKILL.md files and receiving spawn prompts that restate the skill's own content. The result is
substantial token waste — duplicated rules, boilerplate agent-invocation fences, redundant elaboration
sections — that inflates cost without improving output quality. The guiding principle: **cut only
content that is redundant with content already visible to the agent in the same context**; never cut
content that is load-bearing only in a specific invocation path. The target is ~25–35% token reduction
with zero degradation to architecture decisions, gate mechanics, EVERGREEN CODE RULE, or review
group contract.

---

## Current-State Token Map

A full RPI run through a moderate 3-phase plan with 4 implementer groups:

```
Agent                        Skill loaded             Approx lines  Approx tokens
─────────────────────────────────────────────────────────────────────────────────
Orchestrator                 research-plan-implement  537 lines      ~8,055
  + orchestrator prompt block (estimated)             ~300 words     ~400
Phase 1: codebase-researcher researching-codebase     275 lines      ~4,125
Phase 1: web-researcher      (no skill)               —              —
Phase 1: synthesizer         synthesizing-research    143 lines      ~2,145
Phase 2: planner             writing-plans            572 lines      ~8,580
  + consolidated research doc (reads in full)         200-400 lines  ~400-600
Phase 3: implementer ×4      implementing-plans       535 lines      ~8,025 each
  + EVERGREEN CODE RULE in spawn prompt ×4            ~130 words     ~175 each
  + full plan doc read ×4 (moderate plan)             300-600 lines  ~550 each
Phase 3: code-reviewer ×4    reviewing-code           265 lines      ~3,975 each
Terminal: security-reviewer  security-review          254 lines      ~3,810
Post-gate: finishing-work    finishing-work           371 lines      ~5,565
─────────────────────────────────────────────────────────────────────────────────
Core skills alone (distinct bodies, no duplication):              ~44,280 tokens
Loaded multiple times across agents (implementing-plans ×4):      +~24,075 extra
Implementer spawn prompt overlap (×4):                            +~1,400 extra
Full plan re-read by each implementer (×4, 300-line plan):        +~2,200 extra
Estimated total context footprint (4-group plan):                 ~72,000+ tokens
```

Source: process audit (observed via file line counts); spawn prompt size estimated from
orchestrator code fences in research-plan-implement SKILL.md ll.315–370.

---

## Findings Catalog

Each finding is drawn from one or more source docs. Conflicts between sources are flagged inline.

---

### F1 — EVERGREEN CODE RULE double-loaded in every implementer
**Category:** CLEAR WASTE
**Description:** The EVERGREEN CODE RULE block (~130 words) is embedded verbatim in the
orchestrator's implementer spawn prompt (RPI SKILL.md ll.358–368), AND in implementing-plans SKILL.md
Core Principles §3. For a 4-group plan the spawn prompt emits it 4 times; each implementer also loads
it from the skill. Total: 8 copies in memory across 4 agents.
**Target files:** `research-plan-implement/SKILL.md` ll.358–368
**Estimated savings:** ~130 words × 4 spawn prompts = ~520 words ≈ 700 tokens per plan
**Risk to quality:** Near-zero. The skill carries the canonical rule.
**Confidence:** HIGH — [OBSERVED] from line-range match in both files.
**Source:** process-audit F1; verbosity-audit §implementing-plans "EVERGREEN CODE RULE" note

---

### F2 — Implementers read the full plan; only their group section is needed
**Category:** LIKELY WASTE
**Description:** The spawn prompt says "Read the plan, focusing on your group's phases" but
implementing-plans Step 1 says "Read the file at that path directly." No structural constraint limits
reading. For a 6-phase plan (~600 lines) with 3 groups, each implementer reads ~400 irrelevant lines.
**Target files:** `research-plan-implement/SKILL.md` implementer spawn prompt; `implementing-plans/SKILL.md` Step 1
**Estimated savings:** 3 groups × ~400 lines × ~1.3 tokens/line ≈ 1,560 tokens per plan
**Risk to quality:** Low. Group dependencies live in Execution blocks which are short; same info the
orchestrator uses to route is enough for the implementer.
**Confidence:** MEDIUM — [INFERRED] from file structure; actual implementer reading behaviour not directly observed.
**Source:** process-audit F2

---

### F3 — Terminal security-reviewer model unspecified — may inherit opus
**Category:** CLEAR WASTE
**Description:** Implementer spawn explicitly sets `model: "opus"`. The terminal security-gate Step 4
in RPI SKILL.md does not specify a model for the security-reviewer spawn. The security reviewer may
inherit the orchestrator's opus model. Security review is structured checklist pattern-matching —
squarely sonnet-capable.
**Target files:** `research-plan-implement/SKILL.md` Phase 3 Step 4 (terminal gate invocation)
**Estimated savings:** ~3–4× price reduction per security review invocation (sonnet vs. opus on 500–1,500 token diff)
**Risk to quality:** Low. The CHANGES path is the conservative direction regardless of model.
**Confidence:** HIGH — [INFERRED] from absence of model specifier in gate block; pattern confirmed by
external best practices on model routing.
**Source:** process-audit F4; external-audit §Model Routing

---

### F4 — Spawn prompts restate skill methodology (double-load)
**Category:** LIKELY WASTE (with TRADEOFF caveat)
**Description:** Each spawn prompt gives ~350 words of inline instructions that substantially overlap
with sections 1–3 and 8 of implementing-plans SKILL.md. The skill is then loaded on top, re-stating
purpose, output format, and methodology. Net effect: agent context contains the instructions twice.
Spawn prompts should be identity + deliverable + gate invocation (~100 words), with methodology
delegated to the loaded skill.
**Target files:** `research-plan-implement/SKILL.md` implementer spawn prompt ll.315–370
**Estimated savings:** ~250 words × 4 groups ≈ 1,000 words ≈ 1,300 tokens per plan
**Risk to quality:** TRADEOFF — some redundancy acts as a forcing function if the agent fails to
invoke the Skill tool. Validate Skill tool reliability in subagent contexts before trimming.
**Confidence:** MEDIUM — [INFERRED]; spawn prompt size estimated from code fence in RPI SKILL.md.
**Source:** process-audit F6

---

### F5 — Purpose paragraphs in all 10 skill files restate frontmatter
**Category:** CLEAR WASTE
**Description:** Every skill file opens with a "Purpose" or "Overview" paragraph (4–5 lines each)
that restates the frontmatter `description` field verbatim. The frontmatter is already read by the
Skill tool before the body is processed. 10 files × ~4 lines = ~40 lines of pure duplication.
**Target files:** All 10 skill files (research-plan-implement, researching-codebase, writing-plans,
implementing-plans, synthesizing-research, reviewing-code, security-review,
verification-before-completion, finishing-work, parallel-agents)
**Estimated savings:** ~40 lines ≈ 600 tokens total across the skill corpus
**Risk to quality:** Zero.
**Confidence:** HIGH — [OBSERVED] direct line-range matches in each per-file audit.
**Source:** verbosity-audit, every per-file section

---

### F6 — Agent-invocation code fences are boilerplate repeated 8+ times
**Category:** CLEAR WASTE
**Description:** Task tool code fences for `file-finder` and `web-researcher` subagents appear ~8
times across 3 files (writing-plans ×3, implementing-plans ×2, researching-codebase ×2). Each fence
is ~5–6 lines of format already known to the agent. Replace each with a prose sentence.
**Target files:** `writing-plans/SKILL.md` ll.35–40, ll.119–124, ll.341–347; `implementing-plans/SKILL.md`
ll.169–174, ll.209–213; `researching-codebase/SKILL.md` ll.64–68, ll.145–149
**Estimated savings:** ~8 fences × ~5 lines ≈ 40 lines ≈ 600 tokens
**Risk to quality:** Zero.
**Confidence:** HIGH — [OBSERVED] from per-file audits with line ranges.
**Source:** verbosity-audit cross-file duplication map

---

### F7 — verification-before-completion: "Common Failure Modes" + "Verification Commands" sections
**Category:** CLEAR WASTE
**Description:** Three sections (Common Failure Modes ~40 lines, Verification Commands by Language
~43 lines, Before Commits/PRs/Fixed ~26 lines) restate the Iron Law + 5-step gate with domain labels.
The 5-step gate already covers the pattern. "Verification Commands by Language" is additionally
perishable data. Combined: ~109 lines = ~1,635 tokens that add nothing over the gate.
**Target files:** `verification-before-completion/SKILL.md` ll.96–135, ll.176–244
**Estimated savings:** ~109 lines ≈ 1,635 tokens
**Risk to quality:** Zero — Iron Law + 5-step gate remain intact.
**Confidence:** HIGH — [OBSERVED].
**Source:** verbosity-audit §verification-before-completion

---

### F8 — implementing-plans: stakes enforcement block + Progress Documentation + Verification Techniques
**Category:** CLEAR WASTE
**Description:** Three sections add ~92 lines of dead/duplicate content:
- Step 1 "If no plan exists" / stakes enforcement (ll.43–81, ~39 lines): dead code in RPI happy path;
  covered by writing-plans.
- "Progress Documentation" (ll.407–430, ~24 lines): duplicates Step 4 and Step 5 inline guidance.
- "Verification Techniques" (ll.460–482, ~23 lines): fully re-stated in verification-before-completion skill.
**Target files:** `implementing-plans/SKILL.md` ll.43–81, ll.407–430, ll.460–482
**Estimated savings:** ~92 lines ≈ 1,380 tokens
**Risk to quality:** Zero — gate mechanics, EVERGREEN RULE, worktree detection all preserved.
**Confidence:** HIGH — [OBSERVED].
**Source:** verbosity-audit §implementing-plans; process-audit F7

---

### F9 — parallel-agents: "Multiple Test Failures" example + Conflict Resolution + code fences in Steps 1–5
**Category:** CLEAR WASTE
**Description:**
- Full narrative example "Multiple Test Failures" (ll.166–206, ~41 lines): restates the 5-step process.
- "Conflict Resolution" section (ll.228–252, ~25 lines): restates Step 5 in expanded form.
- Steps 1–5 code fences (ll.63–148, ~85 lines): prose bullets suffice; fences add only visual weight.
Combined: ~97 lines ≈ 1,455 tokens.
**Target files:** `parallel-agents/SKILL.md` ll.63–148, ll.166–252
**Estimated savings:** ~97 lines ≈ 1,455 tokens
**Risk to quality:** Zero — Decision Framework + Agent Prompt Requirements remain.
**Confidence:** HIGH — [OBSERVED].
**Source:** verbosity-audit §parallel-agents

---

### F10 — research docs have no length budget; synthesizer has no brevity cap
**Category:** LIKELY WASTE
**Description:** No spawn prompt or skill quality criteria includes a length budget. A codebase
researcher can produce 500+ lines when 150 decision-critical lines would serve the planner. The
synthesizer has no "≤200 lines" guidance; synthesis output size tracks raw input size. A brevity
nudge in spawn prompts and skill quality criteria would tighten Phase 2 input.
**Target files:** `research-plan-implement/SKILL.md` spawn prompts; `researching-codebase/SKILL.md`
quality criteria; `synthesizing-research/SKILL.md` quality criteria
**Estimated savings:** If research docs shrink from ~400 to ~200 lines: ~260 tokens in planner input;
compounds across multi-researcher runs.
**Risk to quality:** Low if phrased as guidance ("aim for ≤200 lines; include everything
decision-critical") not as a hard cap.
**Confidence:** MEDIUM — [INFERRED]; actual researcher output size not directly measured.
**Source:** process-audit F3, F9

---

### F11 — researching-codebase Phase 1 questioning applies only to interactive use; subagent use triggers dead ceremony
**Category:** TRADEOFF
**Description:** The Iron Law instructs the agent to stop and ask clarifying questions before reading
files. When spawned as an RPI subagent, the research question is already fully scoped by the
orchestrator. The subagent either wastes a round-trip or ignores its own skill. The fix is a
spawn-prompt override ("skip Phase 1 — research question fully specified"), not a skill change.
**Target files:** `research-plan-implement/SKILL.md` codebase-researcher spawn prompt
**Estimated savings:** Eliminates 0–1 round-trips; mainly saves wall-clock time.
**Risk to quality:** TRADEOFF — the questioning phase has value in direct interactive invocations;
spawn-prompt override preserves both uses.
**Confidence:** MEDIUM — [INFERRED] from skill structure + subagent invocation pattern.
**Source:** process-audit F5

---

### F12 — review_group shapes table duplicated across 3 files
**Category:** CLEAR WASTE
**Description:** The Solo/Batched/Fan-out shapes table appears in writing-plans §4a,
implementing-plans per-phase review gate, and research-plan-implement Phase 3 Step 2. The canonical
home is writing-plans §4a. The other two files should cite it rather than duplicate it.
**Target files:** `implementing-plans/SKILL.md` per-phase review gate; `research-plan-implement/SKILL.md` Phase 3 Step 2
**Estimated savings:** ~20 lines ≈ 300 tokens (two duplicate tables removed)
**Risk to quality:** Low — must ensure cross-reference is explicit.
**Confidence:** HIGH — [OBSERVED] from cross-file duplication map in verbosity audit.
**Source:** verbosity-audit cross-file duplication map

---

### F13 — writing-plans: Anti-Patterns + two trivial bad-task examples + Request Approval block
**Category:** CLEAR WASTE
**Description:**
- Anti-Patterns section (ll.530–555, ~26 lines): 5 of 6 examples duplicate the Quality Checklist.
- Two of three "bad" task examples (ll.234–263, ~20 lines): trivial cases; only the "no test cases" example is non-obvious.
- "Request Approval" prose block (ll.495–510, ~16 lines): duplicated in RPI Phase 2 gate.
Combined: ~62 lines ≈ 930 tokens.
**Target files:** `writing-plans/SKILL.md` ll.234–263, ll.495–510, ll.530–555
**Estimated savings:** ~62 lines ≈ 930 tokens
**Risk to quality:** Zero — Quality Checklist + load-bearing sections preserved.
**Confidence:** HIGH — [OBSERVED].
**Source:** verbosity-audit §writing-plans

---

### F14 — No prompt caching on static skill content between phase transitions
**Category:** STRUCTURAL
**Description:** Each RPI phase spawns a fresh context window. Static content (CLAUDE.md, skill
bodies, tool definitions) could be cached with 1-hour TTL between phase invocations. The
research→plan and plan→implement gaps commonly exceed 5 minutes. Currently no cache breakpoints are
placed. The critical ordering rule: static content (CLAUDE.md, skill body) must precede dynamic
content (phase-specific args) or cache hits are 0%.
**Target files:** Orchestrator spawn prompt construction in `research-plan-implement/SKILL.md`;
API layer if using SDK.
**Estimated savings:** Up to 60–80% cost reduction on repeated static content (ESTABLISHED per
Anthropic docs). Cache reads cost ~10% of normal input price.
**Risk to quality:** Zero — prompt caching is transparent to the model.
**Confidence:** HIGH — [ESTABLISHED] per Anthropic prompt caching docs.
**Source:** external-audit §Prompt Caching

---

### F15 — Parallel research subagents fire simultaneously into a cold cache (concurrent hazard)
**Category:** STRUCTURAL
**Description:** The research phase dispatches codebase-researcher and web-researcher in parallel.
Per Anthropic docs, a cache entry is unavailable until the first response *begins*. Parallel subagents
firing simultaneously into a cold cache all miss. Serializing the first call before fanning out warms
the cache for subsequent calls on shared static content (CLAUDE.md, tool definitions).
**Target files:** `research-plan-implement/SKILL.md` Phase 1 dispatch
**Estimated savings:** Dependent on cache hit rate; prevents 100% cold-miss on all parallel calls.
**Risk to quality:** Zero — adds one serial step before fan-out.
**Confidence:** HIGH — [ESTABLISHED] per Anthropic prompt caching docs.
**Source:** external-audit §Prompt Caching

---

### F16 — finishing-work prerequisites check redundant when invoked from RPI terminal-gate PASS path
**Category:** LIKELY WASTE
**Description:** finishing-work has a 5-item prerequisite checklist including "Code review completed"
and "Security review completed". When invoked from RPI's terminal security-gate PASS path, both are
guaranteed true by the pipeline. Add a one-sentence early-exit note for this invocation path.
**Target files:** `finishing-work/SKILL.md` prerequisites section
**Estimated savings:** ~50 tokens of subagent reasoning overhead (not skill content)
**Risk to quality:** Low.
**Confidence:** MEDIUM — [INFERRED].
**Source:** process-audit F8

---

### F17 — Model routing: verification/haiku not used; security-reviewer defaulting uncontrolled
**Category:** STRUCTURAL
**Description:** Anthropic's own research (Opus orchestrator + Sonnet subagents) shows 90.2%
performance gain over single-agent Opus. RPI currently routes: implementers → opus (justified),
code-reviewers → sonnet (correct), security-reviewer → unspecified (F3 above). Verification tasks
(exit-code checking, file existence, test-pass confirmation) could route to Haiku at further cost
reduction. No Haiku routing exists in the current pipeline.
**Target files:** `research-plan-implement/SKILL.md` Phase 3 gate and terminal gate invocations
**Estimated savings:** 10–30% on verification cycle cost (ESTABLISHED guidance range).
**Risk to quality:** Low for verification tasks; Haiku should not be used for architectural decisions.
**Confidence:** MEDIUM — [ESTABLISHED] for general routing principle; [INFERRED] for RPI-specific application.
**Source:** external-audit §Model Routing; process-audit F4

---

### F18 — security-review: Language-Specific Concerns + Gather Context template + Integration section
**Category:** LIKELY WASTE
**Description:**
- Language-Specific Concerns (ll.130–155, ~26 lines): partial list; OWASP section already flags categories.
- Gather Context template (ll.160–165, ~6 lines): restates Step 1 prose in code-fence format.
- "Integration with Implementation" (ll.249–254, ~6 lines): duplicates terminal gate mechanics from RPI.
Combined: ~38 lines ≈ 570 tokens.
**Target files:** `security-review/SKILL.md` ll.130–165, ll.249–254
**Estimated savings:** ~38 lines ≈ 570 tokens
**Risk to quality:** Low — OWASP section and full Security Checklist remain.
**Confidence:** HIGH — [OBSERVED].
**Source:** verbosity-audit §security-review

---

### F19 — CLAUDE.md size: loads into every RPI subagent context
**Category:** STRUCTURAL
**Description:** CLAUDE.md loads into every session context including every subagent. Per Anthropic
docs, above ~200 lines Claude starts ignoring instructions — the file becomes counterproductive.
Every RPI subagent pays the full CLAUDE.md load. Content that belongs in skills (workflow
instructions, RPI mechanics) should move out of CLAUDE.md.
**Target files:** `~/.claude/CLAUDE.md` (global); any project-level CLAUDE.md files
**Estimated savings:** Depends on current size; Anthropic states CLAUDE.md should be ≤200 lines.
**Risk to quality:** Low with careful migration to skills.
**Confidence:** HIGH — [ESTABLISHED] per Anthropic Claude Code Best Practices.
**Source:** external-audit §CLAUDE.md and Skills Token Economy

---

## Prioritized Action List (Top 10 by Impact × Safety)

| Rank | ID | Summary | Est. Tokens Saved | Safety |
|------|----|---------|------------------|--------|
| 1 | F7 | Delete 3 redundant sections in verification-before-completion (Common Failure Modes + Commands by Language + Before Commits/PRs) | ~1,635 | Zero risk |
| 2 | F8 | Delete 3 dead/duplicate sections in implementing-plans (stakes enforcement + Progress Documentation + Verification Techniques) | ~1,380 | Zero risk |
| 3 | F9 | Delete example + Conflict Resolution + code fences in parallel-agents | ~1,455 | Zero risk |
| 4 | F4 | Trim implementer spawn prompts to identity + deliverable + gate (~100 words); delegate methodology to the skill | ~1,300/plan | TRADEOFF — validate Skill tool reliability first |
| 5 | F2 | Add explicit "read only your group sections + Execution block" instruction to implementer spawn | ~1,560/plan | High |
| 6 | F1 | Remove EVERGREEN CODE RULE from spawn prompt; add one-sentence reference to skill | ~700/plan | Very high |
| 7 | F13 | Delete Anti-Patterns + 2 trivial bad-task examples + Request Approval block from writing-plans | ~930 | Zero risk |
| 8 | F5 + F6 | Cut all 10 Purpose paragraphs + replace 8 agent-invocation code fences with prose | ~1,200 total | Zero risk |
| 9 | F3 + F17 | Specify `model: "sonnet"` for security-reviewer; evaluate Haiku for verification tasks | 3–4× per security review | Very high |
| 10 | F14 | Add 1-hour TTL prompt caching on static skill content at phase transitions | 60–80% on static content | Zero risk |

---

## Structural Recommendations

### Prompt Caching
- Use `cache_control` with **1-hour TTL** on system prompt + skill bodies for within-session phase
  transitions (research→plan gap and plan→implement gap both commonly exceed 5 min).
- **Ordering is critical**: static content (CLAUDE.md, SKILL.md body) must precede dynamic content
  (phase-specific args). Placing cache breakpoint after any dynamic content causes 100% miss rate.
- Up to 4 breakpoints per request: cache tools, static system instructions, large static documents
  independently. Minimum size: Opus 4.x = 4,096 tokens; Sonnet 4.6 = 2,048 tokens.
- Verify via `cache_creation_input_tokens` in API response — below threshold, caching is silently skipped.

### Model Routing
- Implementers: **opus** (current — justified for code generation)
- Code-reviewers: **sonnet** (current — correct)
- Security-reviewer: **sonnet** (missing — add explicit specifier; see F3)
- Verification/exit-code tasks: **haiku** (not yet used — evaluate for simple pass/fail checks)
- Rule: never use opus for pattern-matching tasks (security checklists, lint checks, exit-code reads).

### Checkpoint / Restart Affordances
- finishing-work invoked from RPI PASS path should short-circuit the 5-item prerequisite check with
  a one-sentence early-exit note (F16). Prerequisites 1–4 are pipeline-guaranteed.
- Between phases, instruct synthesizer to write output ≤200 lines so the planner's Phase 2 context
  is bounded. Cap is guidance, not hard limit.

### CLAUDE.md Directives
- Add to CLAUDE.md: `"When compacting, always preserve the full list of modified files and any test commands"`
  — survives auto-compaction pass.
- Keep CLAUDE.md ≤200 lines. Move RPI workflow instructions that belong in skills out of CLAUDE.md.
- Use `@path/to/file` imports in CLAUDE.md to reference rather than embed large static content.

### Sentinel Patterns
- Current `.review-verdict` sentinel design (REVIEW_APPROVED vs. bulleted CHANGES) is already lean.
  No change needed (process-audit F10 assessment: this is correct).
- The exit-code table (0/42/other) is load-bearing; keep verbatim in implementing-plans §8. RPI
  should cite implementing-plans rather than duplicate the table (F12 variant).

### Parallel-Agent Cache Warming
- Serialize the first parallel research subagent call before fanning out (F15). This warms shared
  static content (CLAUDE.md, tool definitions) for subsequent parallel calls. Add a one-line note
  to Phase 1 dispatch: "Dispatch codebase-researcher first; after it acknowledges, dispatch web-researcher."

---

## Cross-Cutting Style Rules to Apply

The following rules apply uniformly across all skill files based on patterns identified in the verbosity audit:

1. **Cut "Purpose" opener paragraphs.** Every skill file's opening paragraph restates the frontmatter
   `description`. The frontmatter is sufficient. Cut all 10.

2. **No code fences for agent invocations.** Task tool calls for `file-finder` and `web-researcher`
   are not novel — replace every fence with a prose sentence: "Spawn a `file-finder` agent with the
   goal and topic." Saves ~5 lines per occurrence.

3. **Single canonical home per rule.** No rule should appear in both the checklist AND the anti-patterns
   section of the same file. If it's in the checklist, the anti-patterns entry is redundant.

4. **Anti-Patterns sections: non-obvious reversals only.** Reserve Wrong/Right pairs for cases where
   the correct behavior is counterintuitive. Pairs that restate nearby checklist items should be cut.

5. **No prose+fence duplication.** Steps that explain an action in prose then wrap the same content
   in a `text` code fence (e.g., parallel-agents Steps 1–5, implementing-plans Step 6 checkpoint)
   should use prose alone. The fence adds visual weight, not information.

6. **review_group shapes table lives in writing-plans §4a only.** Other files cite it; they do not
   reproduce it. (Applies to implementing-plans and research-plan-implement.)

7. **Verbosity budget in research deliverables.** Add "aim for ≤200 lines; include everything
   decision-critical, omit exploratory notes and file-listing detail" to:
   - researching-codebase quality criteria
   - synthesizing-research quality criteria
   - each research subagent's spawn prompt deliverable line

8. **Process steps as checklists, not numbered paragraphs.** "Step N: [verb]" with paragraph breaks
   between each step adds ~20 lines of whitespace-heavy structure. Replace step-numbered prose with
   checklist bullets where the logic is sequential but not branching.

---

## Conflicts Between Sources

| Conflict | Verbosity Audit Says | Process/External Audit Says | Resolution |
|----------|---------------------|-----------------------------|------------|
| EVERGREEN CODE RULE in spawn prompt | Keep both (RPI copy "intentional — fresh context") | Remove from spawn prompt; rule in skill is sufficient | **Conflict.** Verbosity audit's rationale ("fresh context") is valid if subagents don't reliably invoke their skills. Process audit's removal requires validating Skill tool reliability. **User call needed.** |
| Spawn prompt methodology overlap (F4) | Surgical edits only for RPI SKILL.md | Trim spawn prompts to ~100 words | **Partial conflict.** Both agree trimming is appropriate; disagree on how far. External audit confirms spawn prompts for teammates should be task-only. Process audit adds TRADEOFF caveat about Skill tool reliability. Validate before cutting aggressively. |
| "Customizing the Pipeline" section (RPI) | Cut (~28 lines, advisory only) | Not addressed | **No conflict.** Verbosity audit's cut is safe; process audit doesn't contradict it. |

---

## Open Questions / User Judgment Calls

1. **EVERGREEN CODE RULE in spawn prompt (F1 / conflict above):** Verbosity audit says the spawn
   prompt copy is intentional because subagents get fresh contexts. Process audit says the skill
   already carries it. Which protection matters more — belt-and-suspenders redundancy, or lean spawn
   prompts? If Skill tool invocation in subagent contexts is confirmed reliable, the spawn copy is
   waste. If not, it's insurance.

2. **Spawn prompt methodology depth (F4):** How much of the spawn prompt should remain after trimming?
   The TRADEOFF finding is that the Skill tool may not always fire first. Matt's call: validate
   Skill tool reliability in a test subagent run before reducing spawn prompts below ~150 words.

3. **Haiku for verification tasks (F17):** Is there appetite to add a third model tier (Haiku) to
   the pipeline for exit-code checks and simple pass/fail verification? Requires explicit model
   specifier additions to 2–3 spawn sites. Low risk, meaningful cost reduction for high-frequency
   runs.

4. **Prompt caching implementation (F14, F15):** Caching requires API-level `cache_control`
   placement. Is RPI running via SDK code, or is this orchestrated through the Claude Code CLI?
   If CLI only, cache breakpoints may not be configurable at the application level — Anthropic
   manages them. Confirm the invocation path before treating caching as an actionable item.

5. **Brevity caps on research output (F10):** A ≤200-line guidance is a nudge, not a hard cap.
   What's the acceptable floor? Some codebases warrant longer research; the guidance should not
   silently truncate architecture-critical findings. Matt to set the cap wording.

6. **review_group shapes table canonical home (F12):** If the table moves to writing-plans §4a only,
   the implementing-plans and RPI cross-references must be explicit and resilient to future writing-plans
   edits. Is the cross-reference pattern (citing another skill's section) established enough in the
   skill corpus to be reliable?

---

## Sources

| Document | Focus Area | Evidence Type |
|----------|------------|---------------|
| `docs/plans/2026-04-21-rpi-token-audit-verbosity.md` | Per-file SKILL.md verbosity audit; line ranges; cut candidates | Static (file read) |
| `docs/plans/2026-04-21-rpi-token-audit-process.md` | Pipeline process-level waste; spawn prompt analysis; token flow map | Static (file read) + [INFERRED] estimates |
| `docs/plans/2026-04-21-rpi-token-audit-external.md` | Anthropic-documented best practices; community consensus; model routing | [ESTABLISHED] (Anthropic docs) + [SPECULATIVE] (community claims) |
