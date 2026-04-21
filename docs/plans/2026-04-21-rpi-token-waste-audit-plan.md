# Plan: rpi-token-waste-audit (2026-04-21)

**Branch strategy: direct-to-main (Panoply meta-repo)** — per user global CLAUDE.md, Panoply changes land on main via the Stop hook auto-commit/push. Per-phase review gates and terminal security-gate still run. Branch/PR scaffolding in `review_group` shapes is a no-op here: a "group" is one implementer's diff, reviewed in place, committed to main.

## Summary

Reduce token waste in the RPI pipeline by cutting redundant prose across 10 skill files, tightening orchestrator spawn prompts, adding a Haiku tier for verification tasks, investigating whether prompt caching is a user-level lever under Claude Code CLI, and baking cross-cutting style rules into a single canonical reference so future skill authors don't re-introduce the waste. Validation phase gates aggressive spawn-prompt trimming behind a live RPI test.

## Stakes Classification

**Level**: Medium
**Rationale**: Changes touch orchestration scaffolding (RPI SKILL.md) and 9 skill files that every future RPI run loads. Mechanical prose cuts are low-risk, but spawn-prompt trims could destabilise subagent behaviour if the Skill tool doesn't fire reliably — which is why the validation phase exists. No user-facing code or data paths affected; rollback is git revert.

## Context

**Research**: `/Users/matthumanhealth/src/Panoply/docs/plans/2026-04-21-rpi-token-waste-audit-research.md`
**Affected Areas**:
- `skills/research-plan-implement/SKILL.md` (orchestrator)
- `skills/implementing-plans/SKILL.md`
- `skills/writing-plans/SKILL.md`
- `skills/researching-codebase/SKILL.md`
- `skills/synthesizing-research/SKILL.md`
- `skills/reviewing-code/SKILL.md`
- `skills/security-review/SKILL.md`
- `skills/verification-before-completion/SKILL.md`
- `skills/finishing-work/SKILL.md`
- `skills/parallel-agents/SKILL.md`
- `skills/STYLE.md` (new — style rules for skill authors)

## Success Criteria

- [ ] Total token footprint of a 4-group RPI run reduced by ≥25% vs. current baseline (research doc §Current-State Token Map estimates ~72,000 tokens; target ≤54,000).
- [ ] EVERGREEN CODE RULE lives in exactly one place (implementing-plans Core Principles §3).
- [ ] Model Selection table in RPI SKILL.md documents a three-tier routing (opus/sonnet/haiku) with explicit `model:` specifiers in all spawn sites.
- [ ] `≤200-line guidance` appears in researching-codebase quality criteria, synthesizing-research quality criteria, and each RPI research subagent spawn-prompt deliverable line.
- [ ] Validation RPI cycle (Phase 3) confirms Skill tool fires reliably in subagent context OR plan falls back to ~150-word spawn prompts.
- [ ] Prompt-caching investigation (Phase 6) produces a decision doc stating whether cache_control is a user-level lever under Claude Code CLI.
- [ ] `skills/STYLE.md` exists and encodes the 8 cross-cutting rules from research §Cross-Cutting Style Rules.
- [ ] All surgical cuts preserve gate mechanics, EVERGREEN RULE (in its canonical home), review_group contract, and Iron Laws.
- [ ] Evergreen code discipline upheld: no commit message, comment, or code reference to "this plan", "the audit", or "RPI token waste" in any changed file.

## Implementation Steps

### Phase 1: Zero-risk prose cuts across skill files

**Execution**

- **Scope:** Apply surgical, mechanical cuts in 7 skill files (F5, F6, F7, F8, F9, F13, F18). Each cut is a delete-only operation validated against the research doc line ranges. No skill cross-file coupling; one implementer owns all cuts.
- **Depends on:** none
- **Parallel with:** none
- **review_group:** `phase1-prose-cuts` *(Batched sequential — 7 independent cuts, small each, shared concern = verbosity removal, well under 50% context)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 1.1: Cut Purpose opener paragraphs (F5)

- **Files**: all 10 skill files listed in research F5
- **Action**: Remove the opening "Purpose" / "Overview" paragraph in each skill that restates the frontmatter `description`. Keep frontmatter as-is.
- **Verify**: `grep -n "^## Purpose" skills/*/SKILL.md` returns zero results where the Purpose block only restated frontmatter; frontmatter `description` fields unchanged.
- **Complexity**: Small

#### Step 1.2: Replace agent-invocation code fences with prose (F6)

- **Files**: `skills/writing-plans/SKILL.md` ll.35–40, 119–124, 341–347; `skills/implementing-plans/SKILL.md` ll.169–174, 209–213; `skills/researching-codebase/SKILL.md` ll.64–68, 145–149
- **Action**: Replace each ~5-line Task-tool code fence with a one-sentence prose invocation ("Spawn a `file-finder` agent with the goal and topic.").
- **Verify**: The 8 enumerated line ranges now contain a single prose sentence; `grep -c "subagent_type" skills/*/SKILL.md` count dropped by ~8.
- **Complexity**: Small

#### Step 1.3: Delete verification-before-completion dead sections (F7)

- **Files**: `skills/verification-before-completion/SKILL.md` ll.96–135 (Common Failure Modes), ll.176–244 (Verification Commands by Language + Before Commits/PRs/Fixed)
- **Action**: Delete the three sections. Preserve the Iron Law and 5-step gate intact.
- **Verify**: `wc -l skills/verification-before-completion/SKILL.md` decreased by ~109 lines; Iron Law block and 5-step gate headers still present.
- **Complexity**: Small

#### Step 1.4: Delete implementing-plans dead/duplicate sections (F8)

- **Files**: `skills/implementing-plans/SKILL.md` ll.43–81 (stakes enforcement / "If no plan exists"), ll.407–430 (Progress Documentation), ll.460–482 (Verification Techniques)
- **Action**: Compress Progress Documentation and Verification Techniques (both are duplicates). **Do NOT delete** the Stakes-Based Enforcement section — it is a load-bearing gate for standalone invocations of `implementing-plans`. Compress it to ~10 lines (High: hard stop, invoke writing-plans; Medium: AskUserQuestion; Low: inline). Preserve gate mechanics, EVERGREEN CODE RULE in Core Principles §3, worktree detection, and Step 1–5 core flow. *(Amended 2026-04-21 after Phase 1 review-gate flagged the original full deletion as removing a load-bearing gate.)*
- **Verify**: `wc -l` dropped by ~92; EVERGREEN CODE RULE still present once in Core Principles §3; `grep -c "EVERGREEN" skills/implementing-plans/SKILL.md` returns 1.
- **Complexity**: Small

#### Step 1.5: Delete parallel-agents example + Conflict Resolution + step code fences (F9)

- **Files**: `skills/parallel-agents/SKILL.md` ll.63–148 (Steps 1–5 code fences), ll.166–252 ("Multiple Test Failures" example + Conflict Resolution)
- **Action**: Replace Step 1–5 code fences with prose bullets. Delete the narrative example and Conflict Resolution section. Preserve Decision Framework and Agent Prompt Requirements.
- **Verify**: `wc -l` dropped by ~97; Decision Framework header and Agent Prompt Requirements header still present.
- **Complexity**: Small

#### Step 1.6: Delete writing-plans Anti-Patterns + trivial bad examples + Request Approval block (F13)

- **Files**: `skills/writing-plans/SKILL.md` ll.234–263 (two trivial bad-task examples), ll.495–510 (Request Approval), ll.530–555 (Anti-Patterns)
- **Action**: Keep only the "no test cases" bad example. Compress Request Approval to ~8 lines (summary + AskUserQuestion with three options + one-line note about RPI orchestrator substitution) — **do NOT delete it**; it is the standalone-invocation approval gate. Delete Anti-Patterns. Preserve Quality Checklist. *(Amended 2026-04-21 after Phase 1 review-gate flagged the original full deletion.)*
- **Verify**: `wc -l` dropped by ~62; Quality Checklist header still present; "No test cases enumerated" bad example retained.
- **Complexity**: Small

#### Step 1.7: Delete security-review Language-Specific + Gather Context template + Integration section (F18)

- **Files**: `skills/security-review/SKILL.md` ll.130–165 (Language-Specific Concerns + Gather Context), ll.249–254 (Integration with Implementation)
- **Action**: Delete the three sections. Preserve OWASP section and Security Checklist verbatim.
- **Verify**: `wc -l` dropped by ~38; OWASP section header and Security Checklist header still present.
- **Complexity**: Small

---

### Phase 2: RPI orchestrator spawn-prompt structural edits

**Execution**

- **Scope:** All structural edits to `skills/research-plan-implement/SKILL.md`: remove EVERGREEN from implementer spawn (F1), specify `model: "sonnet"` for security-reviewer spawn (F3), add `model: "haiku"` tier to Model Selection table (F17), scope implementer reads to their group section (F2), add ≤200-line guidance to research subagent spawns (F10).
- **Depends on:** `phase1-prose-cuts`
- **Parallel with:** none
- **review_group:** `phase2-orchestrator` *(Solo — all edits touch one file and are semantically coupled around spawn-prompt structure)*
- **Gate:** automated review-gate

#### Step 2.1: Remove EVERGREEN CODE RULE from implementer spawn prompt (F1)

- **Files**: `skills/research-plan-implement/SKILL.md` ll.358–368
- **Action**: Delete the ~130-word EVERGREEN CODE RULE block from the implementer spawn prompt. Replace with one sentence: "The implementing-plans skill carries the EVERGREEN CODE RULE — follow it." Add a one-line note at the top of the implementer spawn prompt reminding implementers that plan artefacts are scaffolding, not code to cite.
- **Verify**: `grep -c "EVERGREEN" skills/research-plan-implement/SKILL.md` returns 0 or 1 (only the pointer sentence); implementing-plans Core Principles §3 still holds the canonical rule.
- **Complexity**: Small

#### Step 2.2: Specify `model: "sonnet"` for security-reviewer spawn (F3)

- **Files**: `skills/research-plan-implement/SKILL.md` Phase 3 Step 4 / terminal security-gate invocation block
- **Action**: Add explicit `model: "sonnet"` specifier to the security-reviewer Task-tool invocation so it does not inherit orchestrator opus.
- **Verify**: `grep -A 5 "security-reviewer" skills/research-plan-implement/SKILL.md` shows `model: "sonnet"` in the spawn block.
- **Complexity**: Small

#### Step 2.3: Add Haiku tier to Model Selection table (F17)

- **Files**: `skills/research-plan-implement/SKILL.md` Model Selection section
- **Action**: Extend the Model Selection table from two tiers (opus/sonnet) to three (opus/sonnet/haiku). Rows: opus = implementers (code generation, architectural decisions); sonnet = code-reviewers, security-reviewer, synthesizer, planner; haiku = simple verification tasks (exit-code reads, file-existence checks, pass/fail confirmations). Add a one-line rule: "Never route architectural decisions to haiku."
- **Verify**: `grep -c "haiku" skills/research-plan-implement/SKILL.md` ≥ 2 (table row + rule); Model Selection table renders 3 rows.
- **Complexity**: Small

#### Step 2.4: Scope implementer reads to their group section (F2)

- **Files**: `skills/research-plan-implement/SKILL.md` implementer spawn prompt
- **Action**: Replace "Read the plan, focusing on your group's phases" with explicit instruction: "Read only your group's phase sections plus each phase's Execution block. Do not read phases assigned to other groups." List the implementer's own phase names explicitly in the spawn prompt (orchestrator-interpolated).
- **Verify**: Spawn-prompt template contains the explicit scoping instruction; placeholder exists for orchestrator to interpolate the group's phase list.
- **Complexity**: Small

#### Step 2.5: Add ≤200-line guidance to research subagent spawns (F10, spawn-side)

- **Files**: `skills/research-plan-implement/SKILL.md` codebase-researcher spawn prompt; web-researcher spawn prompt; synthesizer spawn prompt
- **Action**: Add to each research-phase spawn prompt's deliverable line: "Aim for ≤200 lines; include everything decision-critical, omit exploratory notes and raw file listings. Not a hard cap."
- **Verify**: `grep -c "≤200 lines" skills/research-plan-implement/SKILL.md` ≥ 3.
- **Complexity**: Small

---

### Phase 3: Spawn-prompt trim validation [HUMAN GATE]

**Execution**

- **Scope:** Validate Skill-tool reliability in subagent contexts before Phase 4 trims spawn prompts aggressively. Trim ONE spawn prompt (synthesizer) to ~100 words, run a throwaway RPI cycle on a trivial topic, confirm the Skill tool fires and synthesized output quality holds. Output: a decision note committed to `docs/plans/`.
- **Depends on:** `phase2-orchestrator`
- **Parallel with:** none
- **review_group:** `phase3-validation` *(Solo — single validation experiment, output is a decision note, gate is human judgment not automated review)*
- **Gate:** **explicit human gate** — user must confirm validation results before Phase 4 proceeds. Automated review-gate still runs on the diff (the tentatively-trimmed synthesizer spawn prompt + decision note), but Phase 4 does not start until the user reads the note and says "proceed full trim" or "fall back to measured trim".

#### Step 3.1: Create throwaway test topic

- **Files**: N/A (scratch)
- **Action**: Pick a trivial RPI-suitable topic (e.g. "reduce the Panoply root README by one line" or a similarly-tiny synthetic task). Document the topic in the decision note.
- **Verify**: Topic documented; scope genuinely trivial (≤1 line of code change).
- **Complexity**: Small

#### Step 3.2: Trim synthesizer spawn prompt to ~100 words (experimental)

- **Files**: `skills/research-plan-implement/SKILL.md` synthesizer spawn prompt block
- **Action**: Reduce synthesizer spawn prompt to ~100 words: identity + deliverable + skill-pointer + gate invocation. Remove restated methodology. Keep the ≤200-line guidance from Step 2.5.
- **Verify**: Word count of trimmed spawn prompt ≤110 words (buffer for ~100).
- **Complexity**: Small

#### Step 3.3: Run throwaway RPI cycle and capture telemetry

- **Files**: N/A (runtime)
- **Action**: Execute `/rpi <throwaway topic>` end-to-end. Observe: (a) does synthesizer subagent invoke the Skill tool to load synthesizing-research? (b) does synthesized output meet synthesizing-research quality criteria? (c) any visible regression vs. prior behaviour?
- **Manual test cases**:
  - Synthesizer subagent logs show `Skill` tool invocation with `skill: "synthesizing-research"` → PASS signal.
  - Synthesized output is self-contained, well-structured, covers the research inputs → PASS signal.
  - Synthesizer hallucinates methodology / produces degraded output / skips Skill tool → FAIL signal.
- **Verify**: All three observations recorded in the decision note.
- **Complexity**: Medium

#### Step 3.4: Write decision note

- **Files**: `docs/plans/2026-04-21-rpi-token-waste-audit-validation.md` (new, short)
- **Action**: Record topic, observations, verdict (PASS / FAIL), and recommended Phase 4 path. Keep ≤50 lines.
- **Verify**: File exists at the path; verdict is one of {PASS, FAIL}; recommended path is one of {full trim, measured trim}.
- **Complexity**: Small

#### Step 3.5: HUMAN GATE — present decision note to user

- **Files**: N/A
- **Action**: Surface the decision note to the user via `AskUserQuestion` with options: "Proceed with full spawn-prompt trim (Phase 4 path A)" / "Fall back to measured ~150-word trim (Phase 4 path B)" / "Abort — revert synthesizer trim".
- **Verify**: User decision recorded in the decision note.
- **Complexity**: Small

---

### Phase 4: Apply spawn-prompt trim decision

**Execution**

- **Scope:** Act on Phase 3 user decision. Path A (PASS): trim planner, implementer, codebase-researcher, web-researcher, code-reviewer, security-reviewer spawn prompts to ~100 words each. Path B (FAIL): trim same spawn prompts to ~150 words with methodology pointer but no full re-statement. Path C (ABORT): revert synthesizer trim from Phase 3 and close this phase as a no-op.
- **Depends on:** `phase3-validation`
- **Parallel with:** none
- **review_group:** `phase4-trim-apply` *(Solo — single-file edit cluster, semantically coupled, modest diff size)*
- **Gate:** automated review-gate

#### Step 4.1: Apply trim to planner spawn prompt

- **Files**: `skills/research-plan-implement/SKILL.md` planner spawn prompt
- **Action**: Trim to the word budget from Phase 3 verdict (100 or 150). Keep identity + deliverable + Skill-tool invocation + gate invocation. Preserve any load-bearing orchestrator handoff (research doc path, plan doc path, EVERGREEN rule pointer).
- **Verify**: Word count within target; skill-tool invocation sentence present; plan-doc path placeholder present.
- **Complexity**: Small

#### Step 4.2: Apply trim to implementer spawn prompt

- **Files**: `skills/research-plan-implement/SKILL.md` implementer spawn prompt
- **Action**: Same pattern as Step 4.1. Preserve: group-phase-list placeholder (from Step 2.4), scoped-read instruction, EVERGREEN pointer (from Step 2.1), review_group id placeholder.
- **Verify**: Word count within target; all four load-bearing placeholders/instructions preserved.
- **Complexity**: Small

#### Step 4.3: Apply trim to codebase-researcher and web-researcher spawn prompts

- **Files**: `skills/research-plan-implement/SKILL.md` research subagent spawn prompts
- **Action**: Same pattern. Preserve: ≤200-line deliverable guidance (from Step 2.5), research question placeholder, output path placeholder. For codebase-researcher, also add the "skip Phase 1 questioning — research question fully specified" override (F11).
- **Verify**: Word count within target; ≤200-line guidance preserved; F11 override present in codebase-researcher spawn.
- **Complexity**: Small

#### Step 4.4: Apply trim to code-reviewer and security-reviewer spawn prompts

- **Files**: `skills/research-plan-implement/SKILL.md` reviewer spawn prompts
- **Action**: Same pattern. Preserve: `model: "sonnet"` specifier for both (from Step 2.2 for security-reviewer; confirm present for code-reviewer), diff input path, verdict file path, sentinel contract pointer.
- **Verify**: Word count within target; model specifier present on both; sentinel-contract pointer present.
- **Complexity**: Small

---

### Phase 5: Cross-file duplication resolution

**Execution**

- **Scope:** Single canonical home for the review_group shapes table in `writing-plans/SKILL.md` §4a (F12). Remove duplicate tables from `implementing-plans/SKILL.md` per-phase review gate and `research-plan-implement/SKILL.md` Phase 3 Step 2; replace each with an explicit cross-reference sentence.
- **Depends on:** `phase4-trim-apply`
- **Parallel with:** none
- **review_group:** `phase5-dedup` *(Solo — small coupled edit across 2 files, trivial diff)*
- **Gate:** automated review-gate

#### Step 5.1: Confirm canonical table in writing-plans §4a

- **Files**: `skills/writing-plans/SKILL.md` §4a
- **Action**: Verify the Solo / Batched sequential / Fan-out + consolidator shapes table is present, correct, and appropriately authoritative. No changes if already sufficient; otherwise light polish only.
- **Verify**: Table renders with 3 rows and columns matching the canonical shape (Shape / When to use / Who owns the review loop).
- **Complexity**: Small

#### Step 5.2: Remove duplicate table from implementing-plans

- **Files**: `skills/implementing-plans/SKILL.md` per-phase review gate section
- **Action**: Delete the duplicate shapes table. Replace with: "See `writing-plans` §4a for review_group shapes."
- **Verify**: `grep -c "Batched sequential" skills/implementing-plans/SKILL.md` drops; cross-reference sentence present.
- **Complexity**: Small

#### Step 5.3: Remove duplicate table from research-plan-implement

- **Files**: `skills/research-plan-implement/SKILL.md` Phase 3 Step 2
- **Action**: Delete the duplicate shapes table. Replace with: "See `writing-plans` §4a for review_group shapes."
- **Verify**: `grep -c "Batched sequential" skills/research-plan-implement/SKILL.md` drops; cross-reference sentence present.
- **Complexity**: Small

---

### Phase 6: Prompt-caching investigation [HUMAN GATE]

**Execution**

- **Scope:** Determine whether `cache_control` is a user-level lever under the Claude Code CLI or whether prompt caching is Anthropic-managed and opaque. Probe: CLI documentation, any `cache_control` config surface, behaviour of the orchestrator's spawn prompts in practice. Output: a decision doc that declares either (a) actionable levers exist → follow-up phase created; or (b) SDK-only → documented as future work and closed.
- **Depends on:** `phase5-dedup`
- **Parallel with:** none
- **review_group:** `phase6-caching` *(Solo — investigation + decision doc, no code changes expected beyond the doc itself)*
- **Gate:** **explicit human gate** — user decides scope of follow-on work based on findings. Automated review-gate still runs on the decision doc diff.

#### Step 6.1: Probe Claude Code CLI for cache_control surfaces

- **Files**: N/A (investigation)
- **Action**: Read Claude Code docs / `--help` output. Search for `cache_control`, `cache-control`, `cache_ttl`, `prompt-cache` in Claude Code configuration. Check `settings.json` schema for cache-related fields. Check whether Task-tool invocations expose a `cache_control` param.
- **Verify**: All three surfaces probed; findings captured as bullet notes in the decision doc.
- **Complexity**: Medium

#### Step 6.2: Probe subagent spawn path for observable cache behaviour

- **Files**: N/A (investigation)
- **Action**: Run a small RPI cycle (can reuse Phase 3 throwaway if still available) with verbose logging. Inspect any API response metadata surfaced (`cache_creation_input_tokens`, `cache_read_input_tokens`). If CLI hides this metadata, note it.
- **Verify**: Attempt logged; outcome (metadata visible / hidden) captured in the decision doc.
- **Complexity**: Medium

#### Step 6.3: Write decision doc

- **Files**: `docs/plans/2026-04-21-rpi-prompt-caching-decision.md` (new, short)
- **Action**: State verdict: "user-level levers exist" / "Anthropic-managed, opaque" / "partially observable". If levers exist, enumerate them and propose a follow-up phase (cache_control placement, ordering rules from research F14/F15). If opaque, document F14/F15 as SDK-only future work and close.
- **Verify**: Doc exists at path; verdict is one of the three; ≤80 lines.
- **Complexity**: Small

#### Step 6.4: HUMAN GATE — present findings to user

- **Files**: N/A
- **Action**: Surface decision doc via `AskUserQuestion` with options: "Create follow-up phase to implement caching levers" / "Close as SDK-only future work" / "Investigate further".
- **Verify**: User decision recorded in the decision doc; if "create follow-up phase", user also indicates whether it joins this plan or ships as a separate plan.
- **Complexity**: Small

---

### Phase 7: finishing-work prerequisite short-circuit

**Execution**

- **Scope:** Add an early-exit note to `finishing-work/SKILL.md` prerequisites section covering the RPI terminal-gate PASS invocation path (F16). Code review + security review are pipeline-guaranteed when finishing-work is invoked from RPI PASS; the 5-item checklist can short-circuit.
- **Depends on:** `phase6-caching`
- **Parallel with:** none
- **review_group:** `phase7-finishing` *(Solo — one-file edit, ~5-line addition)*
- **Gate:** automated review-gate

#### Step 7.1: Add early-exit note to finishing-work prerequisites

- **Files**: `skills/finishing-work/SKILL.md` prerequisites section
- **Action**: Insert a one-sentence note at the top of the prerequisites checklist: "When invoked from the RPI terminal security-gate PASS path, items 1–4 (code review completed, security review completed, tests passing, verification complete) are pipeline-guaranteed — proceed to item 5 (merge/PR/cleanup decision)."
- **Verify**: `grep -n "RPI terminal" skills/finishing-work/SKILL.md` returns the new line; 5-item checklist otherwise intact.
- **Complexity**: Small

---

### Phase 8: Add cross-cutting style rules

**Execution**

- **Scope:** Create `skills/STYLE.md` encoding the 8 cross-cutting style rules from research §Cross-Cutting Style Rules (lines 395–428). This is the canonical reference that future skill authors follow so the waste does not return. Short file (≤100 lines).
- **Depends on:** `phase7-finishing`
- **Parallel with:** none
- **review_group:** `phase8-style` *(Solo — single new file, small diff)*
- **Gate:** automated review-gate

#### Step 8.1: Write `skills/STYLE.md`

- **Files**: `skills/STYLE.md` (new)
- **Action**: Create the file with the 8 rules verbatim from research §Cross-Cutting Style Rules: (1) Cut Purpose openers; (2) No code fences for agent invocations; (3) Single canonical home per rule; (4) Anti-Patterns sections are non-obvious reversals only; (5) No prose+fence duplication; (6) review_group shapes table lives in writing-plans §4a only; (7) Verbosity budget on research deliverables (≤200 lines); (8) Process steps as checklists, not numbered paragraphs. Each rule gets a one-line "why" and one-line "how to check". No Purpose opener (rule 1 applies to this file too).
- **Verify**: File exists; contains all 8 rules; ≤100 lines; does not itself violate any of the 8 rules.
- **Complexity**: Small

#### Step 8.2: Add pointer from `skills/README.md` (if present) or top-level skills index

- **Files**: `skills/README.md` (check existence first via Glob)
- **Action**: If `skills/README.md` exists, add one line: "See `STYLE.md` for cross-cutting style rules all skills follow." If no README exists, skip — STYLE.md is self-discoverable.
- **Verify**: If README existed, cross-reference present; if not, step documented as skipped.
- **Complexity**: Small

---

### Phase 9 (terminal): security-gate

**Execution**

- **Scope:** Plan-level security review over the aggregated diff (`git diff $base_ref..HEAD`). For a Panoply meta-repo change touching only skill prose, orchestrator spawn prompts, and a new STYLE.md, risk surface is minimal — no auth, no data paths, no credentials. `automated` mode is appropriate.
- **Depends on:** `phase1-prose-cuts`, `phase2-orchestrator`, `phase3-validation`, `phase4-trim-apply`, `phase5-dedup`, `phase6-caching`, `phase7-finishing`, `phase8-style`
- **Parallel with:** none (terminal)
- **review_group:** `security`
- **security_review:** `automated`
- **Gate:** automated review-gate (reviewer runs first; remediation implementer spawns only on CHANGES; 2-pass cap with interactive drop-out)

**Reviewer inputs** (orchestrator-supplied; do NOT pipe per-phase reviewer summaries):

1. `git diff $base_ref..HEAD` — aggregated diff; `$base_ref` = HEAD recorded at plan start.
2. Plan document path: `docs/plans/2026-04-21-rpi-token-waste-audit-plan.md`.
3. Ordered list of prior phase names: phase1-prose-cuts, phase2-orchestrator, phase3-validation, phase4-trim-apply, phase5-dedup, phase6-caching, phase7-finishing, phase8-style.

**Control flow:**

- Reviewer writes `.review-verdict-security` per the sentinel contract.
- **PASS** → proceed to `finishing-work`.
- **CHANGES** → spawn remediation implementer; re-enter via `implement-review-gate.sh --group-id security`.
- **Cap-hit (exit 42)** → `AskUserQuestion`: remediate / override (logged) / abort.

## Test Strategy

### Automated Tests

No runtime code under test — all changes are to markdown skill files, documentation, and a new STYLE.md. Verification is via greps, line-count checks, and (for Phase 3) a live RPI cycle on a throwaway topic.

| Test Case | Type | Input | Expected Output |
|-----------|------|-------|-----------------|
| EVERGREEN CODE RULE single canonical home | Grep | `grep -rc "EVERGREEN CODE RULE" skills/` | Exactly 1 match (in implementing-plans Core Principles §3); 0 or 1 pointer sentence in research-plan-implement |
| Purpose openers removed | Grep | `grep -c "^## Purpose" skills/*/SKILL.md \| awk -F: '{s+=$NF} END {print s}'` | Decreased by ≥10 from baseline |
| Agent-invocation fences replaced | Grep | Count of `subagent_type` occurrences in target 3 files | Decreased by ≥8 |
| Haiku tier present | Grep | `grep -c "haiku" skills/research-plan-implement/SKILL.md` | ≥ 2 |
| ≤200-line research guidance present | Grep | `grep -l "≤200 lines" skills/research-plan-implement/SKILL.md skills/researching-codebase/SKILL.md skills/synthesizing-research/SKILL.md` | All 3 files match |
| Security-reviewer model specified | Grep | `grep -B 2 -A 5 "security-reviewer" skills/research-plan-implement/SKILL.md` | Block contains `model: "sonnet"` |
| review_group shapes table deduplicated | Grep | `grep -c "Fan-out + consolidator" skills/implementing-plans/SKILL.md skills/research-plan-implement/SKILL.md` | 0 in each (table only in writing-plans) |
| STYLE.md exists and covers 8 rules | File check + grep | `wc -l skills/STYLE.md` and grep for 8 rule markers | File ≤100 lines; 8 rule markers present |
| No evergreen violations in changes | Grep | `git diff --name-only $base_ref..HEAD \| xargs grep -l "token waste audit\|this plan\|RPI plan"` | Empty (only the plan/decision docs themselves may reference these terms) |

### Manual Verification

- [ ] Phase 3: throwaway RPI cycle executes end-to-end; synthesizer subagent Skill-tool invocation visible in logs; output meets synthesizing-research quality criteria.
- [ ] Phase 3: decision note written; user confirms verdict before Phase 4 starts.
- [ ] Phase 6: prompt-caching investigation decision doc written; user chooses follow-on scope.
- [ ] Post-Phase 8: manual read-through of `skills/STYLE.md` to confirm it does not itself violate any of the 8 rules.
- [ ] Post-Phase 9 (before final merge): spot-check 2 skill files to confirm Iron Laws, gate mechanics, and EVERGREEN rule (in its canonical home) are preserved verbatim.

## Post-Merge Verification

**Required**: yes
**Trigger point**: After all phases commit to main via the Stop hook auto-push, and at least one subsequent real RPI cycle has been kicked off in a downstream repo (analytics / datascience / cloud-infrastructure).
**Repos involved**: One of `analytics`, `datascience`, `cloud-infrastructure` — whichever has the next RPI-suitable task. No Panoply-side verification beyond greps from Test Strategy.
**Commands / steps**:
- [ ] Kick off next real RPI task in a downstream repo; observe subagent behaviour.
- [ ] Confirm synthesizer / planner / implementer subagents invoke the Skill tool on first turn (log inspection).
- [ ] Confirm research docs land ≤200 lines (or are close; guidance is a nudge).
- [ ] Confirm terminal security-reviewer runs on sonnet (`model: "sonnet"` visible in spawn-trace / telemetry).
- [ ] Confirm no regression in RPI output quality vs. last pre-audit cycle.
**Verification owner**: Matt, during next real RPI invocation — no dedicated test run required.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Aggressive spawn-prompt trim breaks Skill-tool invocation in subagents | RPI pipeline produces degraded output | Phase 3 validation gate with explicit human approval before Phase 4; fallback to ~150-word trim |
| Line-range cuts from research doc are stale (files drifted since audit) | Cuts remove wrong content | Each step's Verify grep catches content preservation (Iron Law headers, gate mechanics, canonical rules) |
| EVERGREEN CODE RULE accidentally removed from canonical home | Implementers lose the rule | Explicit verify in Step 1.4 and Step 2.1 that implementing-plans Core Principles §3 retains the rule |
| Prompt-caching investigation inconclusive | Phase 6 closes with no action, but no harm | Decision doc explicitly permits "close as SDK-only future work" outcome |
| Downstream repo RPI cycles reveal regression post-merge | Rollback needed | Git revert per phase is trivial (Panoply is meta-repo, main-only, small diffs); post-merge verification happens in-flight on next real RPI |
| Implementer references this plan in commits/comments (evergreen violation) | Future code reads awkwardly; plan becomes load-bearing | Reminded in Success Criteria; grep in Test Strategy catches it pre-gate |

## Rollback Strategy

Every phase is one coherent diff on main. Rollback per phase via `git revert <commit>` — no feature branches, no merge-commit complexity. Phases are ordered so that rollback of a later phase does not require rolling back an earlier one (Phase 5 cross-references assume Phase 1–4 edits exist but do not depend on them structurally; worst case, a revert leaves a dangling cross-reference that is itself a 1-line fix).

If Phase 3 validation fails and the user aborts, revert the synthesizer trim commit and close the plan with Phases 1–2 landed (still a net win).

## Status

- [ ] Plan approved
- [ ] Implementation started
- [ ] Implementation complete
