# RPI Token Audit — Verbosity & Redundancy
**Date:** 2026-04-21  
**Scope:** 10 skill files + 2 agent files + implement-review-gate.sh

---

## Per-File Audits

### 1. `research-plan-implement/SKILL.md` — 537 lines ~8,055 tokens

**Keep (load-bearing):**
- Architecture diagram with base_ref, terminal security-gate, fan-out shapes
- All Phase 3 sub-section mechanics (Step 0–5): base_ref capture, review_group shapes table, exit-code table, gate honour logic
- EVERGREEN CODE RULE block in implementer prompt
- Quality Checklists (both the per-phase and pipeline checklists — they differ)
- Anti-Patterns table (encodes hard rules, not style)

**Cut candidates:**

| Section | Lines (approx) | Reason | Savings |
|---------|---------------|--------|---------|
| "Purpose" para (ll.14–18) | 5 | Repeats the frontmatter description verbatim | ~5 |
| "When to Use / Do NOT use" (ll.69–81) | 13 | Identical intent guidance exists in researching-codebase, writing-plans, implementing-plans | ~10 |
| Phase 1 Step 1 bullet explanation (ll.87–93) | 7 | "Typically 2-4 questions covering…" fully restated in the "Guidelines" block at ll.152–155 | ~5 |
| Web researcher code fence (ll.123–131) | 8 | One-liner to spawn with specific args; the prose above covers it completely | ~6 |
| Additional/security researcher code fence (ll.138–143) | 6 | Rarely used; prose already says "spawn with appropriate prompt" | ~5 |
| Step 3 synthesizer prompt (ll.162–175) | 14 | Self-evident from the synthesis skill; the list of input paths is the only novel info | ~10 |
| Step 4 "table + template" (ll.180–199) | 20 | The table format restates the prose above it; the template block is a 6-line restatement | ~15 |
| Phase 2 planner prompt interior (ll.218–242) | 25 | The "Size each phase…", Execution block spec, branch/PR strategy bullets are duplicated verbatim from writing-plans §6 template | ~18 |
| "Customizing the Pipeline" (ll.437–464) | 28 | "Skipping Phases" is one logical sentence each; complexity table is obvious from prose; brainstorming note is a 2-line aside | ~22 |
| Model Selection table (ll.480–488) | 9 | Obvious from model names; rationale column adds nothing not in the label | ~7 |

**Tighten candidates:**
- Orchestrator Rules Do/Do NOT (ll.470–477): convert to a single 2-column table; saves ~6 lines
- Phase 3 Step 2 review_group shapes table (ll.299–303): tight already, keep as-is
- Phase 3 implementer spawn prompt (ll.315–370): 55-line code fence is necessary but the NOTE about worktree can move to a ≤2-sentence aside; saves ~4

**Estimated gross savings:** ~93 lines (~1,400 tokens)

---

### 2. `researching-codebase/SKILL.md` — 275 lines ~4,125 tokens

**Keep (load-bearing):**
- Iron Law + Phase 1 "do not" list
- Gather Runtime Evidence subsection (with [OBSERVED]/[INFERRED] tagging)
- Phase 3 document template (file path, structure, tag conventions)
- WebFetch-vs-web-researcher decision

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| Phase 1 "Focus on understanding" 5-bullet list (ll.46–50) | 5 | Rephrases the "Purpose" / "What" / "Scope" questions; the one-sentence question types above cover it | ~4 |
| Phase 1 "When you believe you understand, confirm:" paragraph (ll.53–55) | 3 | Obvious from the Iron Law + AskUserQuestion usage | ~2 |
| "Questioning Techniques" section (ll.238–256) | 18 | These are examples of the Iron Law in action; the Anti-Patterns table below already covers the contrast | ~15 |
| Key Principles footer (ll.269–276) | 8 | All five points are restatements of the Iron Law or Phase 1 bullets | ~7 |
| file-finder task tool code fence (ll.64–68) | 5 | The Task tool call format is assumed known; a single sentence suffices | ~3 |
| web-researcher task tool code fence (ll.145–149) | 5 | Same: agent invocation pattern is standard | ~3 |

**Tighten candidates:**
- Anti-Patterns table (ll.260–267): remove "I understand, let me look" / "I'll add a new AuthService" rows — both covered by the Iron Law; table drops to 3 essential rows, saves ~4 lines
- Phase 3 document template (ll.178–227): "Runtime Observations" + "External Research" subsections in the template are fine; the surrounding prose (ll.168–177) restates the tagging rule stated in Phase 2 — cut the prose, keep the template inline note

**Estimated gross savings:** ~37 lines (~555 tokens)

---

### 3. `writing-plans/SKILL.md` — 572 lines ~8,580 tokens

**Keep (load-bearing):**
- Section 4a (review_group shapes + sizing decision rules + anti-pattern)
- Terminal security-gate phase template and 7-step control-flow contract block
- Good/Bad Task Examples (non-obvious TDD structure)
- [INFERRED] verification step guidance (domain-specific, not obvious)
- Quality Checklist (enumerates required plan fields)
- Plan document template (full — it's the canonical format)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.12–15) | 4 | Duplicates frontmatter description | ~3 |
| Section 1 "If no research exists" file-finder code fence (ll.35–40) | 6 | Boilerplate agent call; described in prose above | ~4 |
| Section 2 "Define Success Criteria" (ll.43–50) | 8 | Captured by the plan template's `## Success Criteria` section; the prose adds "Use AskUserQuestion" which is universal | ~5 |
| Section 3 stakes table (ll.61–66) | 6 | Tight, but "Planning Rigor" column adds nothing over the label; compress to 2-col | ~2 |
| Section 4 "Identify parallel step groups" (ll.96–113) | 18 | Mostly restates what's in the Execution block spec in 4a; keep the "when NOT independent" bullets, cut the "when independent" positive form | ~9 |
| Section 4 web-researcher code fence (ll.119–124) | 6 | Boilerplate call | ~4 |
| Section 5 "Document Risks" web-researcher code fence (ll.341–347) | 7 | Boilerplate call | ~5 |
| Section 7 "Request Approval" prose block + AskUserQuestion (ll.495–510) | 16 | Duplicated in research-plan-implement Phase 2 "Present Plan and Gate" | ~10 |
| "Plan Iteration" section (ll.514–528) | 15 | Edge case; collapse to 3 bullets | ~10 |
| Anti-Patterns to Avoid section (ll.530–555) | 26 | 5 of 6 examples are phrased as Wrong/Right pairs that duplicate the Quality Checklist; reduce to 2 most non-obvious | ~18 |
| Bad Task Examples (ll.234–263) | 30 | Two of three "bad" examples are trivial; keep only the "no test cases" example (the subtle one) | ~18 |

**Tighten candidates:**
- Good Task Examples: 3 examples covering RED/GREEN/manual — tight, keep all three
- 4a sizing decision rules: already concise, keep
- Terminal-phase control-flow contract: load-bearing verbatim copy, keep

**Estimated gross savings:** ~89 lines (~1,335 tokens)

---

### 4. `implementing-plans/SKILL.md` — 535 lines ~8,025 tokens

**Keep (load-bearing):**
- Step 3 (worktree detection + offer mechanics)
- Step 8 (review gate invocation, exit-code handling)
- Per-phase review gate section: sentinel contract, invocation skeleton, cap-hit handoff, shapes table
- EVERGREEN CODE RULE (Core Principles §3)
- No-security-per-phase notice (repeated deliberately — load-bearing reminder)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.11–14) | 4 | Duplicates frontmatter | ~3 |
| Step 1 "If no plan exists" / stakes enforcement (ll.43–81) | 39 | Already in writing-plans; implementing-plans is invoked AFTER plan approval; the enforcement block is dead code in the happy path and redundant elsewhere | ~30 |
| Step 4 "Initialize Progress Tracking" (ll.149–162) | 14 | TaskCreate/TaskUpdate mechanics are obvious from tool docs; 2 sentences suffice | ~10 |
| Step 6 "Checkpoint After Phases" code template + AskUserQuestion (ll.185–200) | 16 | The template restates the prose before it; phase checkpoints are already in the plan | ~10 |
| "Progress Documentation" section (ll.407–430) | 24 | The TaskCreate/Update example and Plan Document Updates example duplicate Step 4 and Step 5's inline guidance | ~20 |
| "Verification Techniques" section (ll.460–482) | 23 | Moved from here to verification-before-completion skill; this section is pure duplication | ~20 |
| Anti-Patterns to Avoid (ll.488–511) | 24 | 5 of 6 map directly onto the Quality Checklist items; keep only the checklist | ~18 |
| Step 5 "Execute Steps in Order" file-finder code fence (ll.169–174) | 6 | Boilerplate | ~4 |
| Step 7 "Handle Failures" web-researcher code fence (ll.209–213) | 5 | Boilerplate | ~4 |
| Step 8 Step 6 summary template (ll.280–291) | 12 | Implementation summary format; useful but 6-line template is enough; remove the extra prose | ~5 |

**Tighten candidates:**
- Core Principles §1 "Follow the Plan" (ll.358–363): 4 bullets, tight; keep
- Core Principles §3 EVERGREEN CODE RULE: 15 lines, all load-bearing; keep
- "Test-Driven Execution" (ll.433–440): 7 lines, fine

**Estimated gross savings:** ~124 lines (~1,860 tokens)

---

### 5. `synthesizing-research/SKILL.md` — 143 lines ~2,145 tokens

**Keep (load-bearing):**
- [OBSERVED]/[INFERRED] preservation note (ll.40–41)
- Quality Criteria (ll.127–134) — concise, non-redundant
- Output template (ll.62–115)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.12–15) | 4 | Duplicates frontmatter | ~3 |
| Step 1 "If no files are found, ask" (ll.26–27) | 2 | Obvious default behaviour | ~1 |
| Step 3 "Themes to look for" list (ll.51–57) | 7 | Partially duplicates the template structure below; the template sections are the canonical list | ~5 |
| Anti-Patterns table (ll.135–143) | 8 | 4 of 5 rows restate Quality Criteria above; keep only "Copy-paste sequentially" (non-obvious) | ~5 |

**Tighten candidates:**
- Step 2 "Read All Source Files" note list (ll.37–41): tight; keep

**Estimated gross savings:** ~14 lines (~210 tokens)

---

### 6. `reviewing-code/SKILL.md` — 265 lines ~3,975 tokens

**Keep (load-bearing):**
- Conventional Comments label/decoration tables + examples
- 9-step review workflow order
- SOLID/Pattern Recognition tables
- Verdict Criteria (with security integration note)
- Report Format
- Change Size Guidelines

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.15–19) | 5 | Duplicates frontmatter | ~4 |
| "Principle-Based Review" section (ll.169–196) | 28 | Useful but almost entirely duplicated in code-reviewer.md "Output Requirements"; canonical home should be here, not both | ~0 (keep here, cut from agent) |
| 3 Conventional Comments examples (ll.146–167) | 22 | Three examples; the first two are adequate; the third (Go performance question) is lower value | ~6 |
| "Integration with Implementation" (ll.257–265) | 9 | Restates the gate mechanics already in implementing-plans; adds no new information | ~7 |

**Tighten candidates:**
- Steps 3–8 workflow: each step is 3–6 lines; tight; keep
- Verdict Criteria (ll.237–254): dense, accurate; keep

**Estimated gross savings:** ~17 lines (~255 tokens)

---

### 7. `security-review/SKILL.md` — 254 lines ~3,810 tokens

**Keep (load-bearing):**
- Full Security Checklist (ll.57–110)
- OWASP Top 10 patterns
- Findings classification (Critical/High/Medium/Low)
- Report format and verdict criteria

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.15–18) | 4 | Duplicates frontmatter | ~3 |
| "Review Scope" / Determine Changed Files (ll.22–28) | 7 | Obvious git commands; security-reviewer agent already has this in Step 1 | ~5 |
| Language-Specific Concerns (ll.130–155) | 26 | Four languages × 4 bullets each; these are at best a partial list. The OWASP section already flags the categories. Move to a reference appendix or cut; OWASP guidance captures them. | ~20 |
| "Integration with Implementation" (ll.249–254) | 6 | Duplicates the terminal gate mechanics from research-plan-implement | ~5 |
| "Review Process §1 Gather Context" template (ll.160–165) | 6 | Restates Step 1 prose in code-fence format | ~4 |

**Tighten candidates:**
- Risk categories table → reframe as inline bullets; saves ~4 lines
- Findings classification (§3): Critical/High/Medium/Low with 3–4 sub-bullets each; tight; keep

**Estimated gross savings:** ~37 lines (~555 tokens)

---

### 8. `verification-before-completion/SKILL.md` — 281 lines ~4,215 tokens

**Keep (load-bearing):**
- Iron Law + Five-Step Gate (Steps 1–5 with command examples)
- Rationalization Red Flags table
- Integration with Implement Phase (the 3-tier claim chain)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.12–16) | 5 | Duplicates frontmatter and Iron Law | ~4 |
| "Common Failure Modes" section (ll.96–135) | 40 | Tests/Lint/Builds/Bug Fixes/Delegated Work — each restates Step 3–4 with domain labels; the five-step gate already covers the pattern | ~30 |
| "Verification Commands by Project Type" (ll.202–244) | 43 | 5 languages × ~4 commands each; highly perishable data; not load-bearing for the gate logic | ~38 |
| "Before Commits / Before PRs / Before Claiming Fixed" (ll.176–201) | 26 | Repeats Five-Step Gate applied to 3 contexts; the integration diagram (ll.165–168) already makes this point | ~20 |
| Anti-Patterns section (ll.248–272) | 25 | 5 of 6 rows match Rationalization Red Flags; remove Anti-Patterns, keep Red Flags | ~20 |

**Tighten candidates:**
- Five-Step Gate prose (Steps 1–5): appropriately concise; keep
- Red Flags table: 8 rows, tight; keep

**Estimated gross savings:** ~112 lines (~1,680 tokens)

---

### 9. `finishing-work/SKILL.md` — 371 lines ~5,565 tokens

**Keep (load-bearing):**
- Step 5 (Post-Merge Verification) complete mechanics including early-exit algorithm
- Artifacts section (`.post-merge-verification-pending` trust boundary)
- Status Reporting (Verification: none/pending/completed derivation rule)
- Option 4 DISCARD confirmation mechanic (exact-string requirement)
- Safety Guardrails (never force push to shared, never merge with failing tests)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.12–16) | 5 | Duplicates frontmatter | ~4 |
| Option 1 "Merge Locally" command list (ll.77–98) | 22 | Standard git workflow; not novel; prose in Step 4 intro ("Checkout, pull, merge, test, push, delete") is sufficient | ~15 |
| Option 2 "Create Pull Request" command list (ll.100–113) | 14 | `gh pr create` usage is standard; "Do NOT delete" is the only novel rule | ~10 |
| Option 3 "Keep for Later" command list (ll.115–128) | 14 | Three trivial git commands | ~10 |
| "Integration with Implement Phase" flow diagram (ll.225–234) | 10 | Arrow chain restates the Prerequisites list above | ~8 |
| Anti-Patterns section (ll.315–339) | 25 | 5 items; 4 restate Checklist or Safety Guardrails | ~18 |
| "Step 6: Clean Up" worktree cleanup code block (ll.207–221) | 15 | Standard git worktree remove; inline 2 sentences | ~10 |
| Cleanup table (ll.201–205) | 5 | 4 rows of obvious branch/worktree fate; restate Step 4 option descriptions | ~3 |

**Tighten candidates:**
- Checklist Before Finishing: 10 items, tight; keep
- Status Reporting templates per option: retain — the Verification trailing line is load-bearing

**Estimated gross savings:** ~78 lines (~1,170 tokens)

---

### 10. `parallel-agents/SKILL.md` — 295 lines ~4,425 tokens

**Keep (load-bearing):**
- When to Use / Do NOT use
- Decision Framework 3-question block
- Agent Prompt Requirements (Must Have / Must Avoid)

**Cut candidates:**

| Section | Lines | Reason | Savings |
|---------|-------|--------|---------|
| "Purpose" para (ll.11–14) | 4 | Duplicates frontmatter | ~3 |
| Full example "Multiple Test Failures" (ll.166–206) | 41 | Long narrative restates the 5-step process already illustrated in Step 1–5; the "example prompts" in Step 2 already anchor the pattern | ~30 |
| "Conflict Resolution" section (ll.228–252) | 25 | Useful, but restates "If conflicts exist" in Step 5 (ll.142–148); condense to 3 bullets | ~18 |
| Steps 1–5 "The Parallel Process" code fences (ll.63–148) | 85 | 5 process steps each with a `text` code fence; the code fences add formatting weight without adding information beyond the prose; prose bullets suffice | ~40 |
| Checklist Before Dispatching (ll.279–286) | 8 | Mirrors Must Have / Must Avoid; redundant | ~6 |

**Tighten candidates:**
- Steps 4–5 "Review Results / Integrate Changes": 2 × 10-line blocks → 2 × 3-bullet blocks
- Anti-Patterns table: 5 rows, tight; keep

**Estimated gross savings:** ~97 lines (~1,455 tokens)

---

## Cross-File Duplication Map

| Duplicated Content | Locations | Canonical Home | Action |
|-------------------|-----------|----------------|--------|
| "Purpose" opening para restating frontmatter | All 10 skill files | Frontmatter `description` | Cut from body in all 10 |
| No-security-per-phase reminder | implementing-plans (x3), code-reviewer.md (x2), research-plan-implement | implementing-plans quality checklist + RPI anti-patterns | Single authoritative note in implementing-plans §8; pointer only elsewhere |
| review_group shapes table (Solo/Batched/Fan-out) | writing-plans §4a, implementing-plans per-phase review gate, research-plan-implement Phase 3 Step 2 | writing-plans §4a | Single table in writing-plans; other files cite it |
| Terminal gate control-flow contract (7-step) | writing-plans §4a, research-plan-implement Phase 3 Step 4 | writing-plans §4a | Verbatim copy in plan template is load-bearing; RPI Step 4 can become a cross-reference + exit-code table only |
| Implementer exit-code table (0/42/other) | implementing-plans §8, research-plan-implement Phase 3 Step 2 | implementing-plans §8 (Per-phase review gate) | RPI cites implementing-plans; does not duplicate the table |
| EVERGREEN CODE RULE | implementing-plans Core Principles §3, research-plan-implement implementer spawn prompt | implementing-plans | RPI spawn prompt copy is intentional (fresh context) — keep both |
| File-finder / web-researcher agent invocation code fences | writing-plans (3×), implementing-plans (2×), researching-codebase (2×) | None — all boilerplate | Replace all fences with prose: "Spawn a `file-finder` agent with the goal and topic." Saves ~6 fences × ~6 lines = ~36 lines |
| Verification commands by language | verification-before-completion, implementing-plans "Verification Techniques" | verification-before-completion | Cut implementing-plans §Verification Techniques (already flagged above) |
| Worktree cleanup git commands | finishing-work Step 6, implementing-plans Step 3 | implementing-plans (owns worktree offer) | finishing-work cites implementing-plans; no repeated commands |

---

## Top 10 Highest-Impact Cuts (Ranked by Tokens Saved × Risk-Free-ness)

| Rank | Cut | Files | Lines Saved | Risk |
|------|-----|-------|-------------|------|
| 1 | `verification-before-completion`: delete "Common Failure Modes" + "Verification Commands by Language" + "Before Commits/PRs/Fixed" sections | verification-before-completion | ~98 | Zero — pure repetition of 5-step gate |
| 2 | `implementing-plans`: delete stakes enforcement block (Step 2) + Progress Documentation section + Verification Techniques section + Anti-Patterns | implementing-plans | ~92 | Zero — dead in RPI happy path; covered elsewhere |
| 3 | `parallel-agents`: delete full "Multiple Test Failures" example + Conflict Resolution section + code fences in Steps 1–5 | parallel-agents | ~88 | Zero — prose covers it |
| 4 | `research-plan-implement`: delete Customizing the Pipeline section + Model Selection table + planner prompt body that duplicates writing-plans | research-plan-implement | ~52 | Low — model selection is advisory only |
| 5 | `writing-plans`: delete Anti-Patterns section + two of three bad-task examples + Request Approval block (Phase 2 gate owns it) | writing-plans | ~46 | Zero |
| 6 | All 10 files: delete "Purpose" opening paragraphs (frontmatter is enough) | all | ~40 | Zero |
| 7 | All files with agent invocation code fences: replace with prose | writing-plans, implementing-plans, researching-codebase | ~36 | Zero |
| 8 | `finishing-work`: delete git command lists for Options 1–3 + Anti-Patterns + cleanup table | finishing-work | ~46 | Low — keep DISCARD mechanic; git commands are obvious |
| 9 | `security-review`: delete Language-Specific Concerns + Gather Context template + Integration section | security-review | ~34 | Low — OWASP section covers categories |
| 10 | `researching-codebase`: delete Questioning Techniques + Key Principles footer + redundant clarification bullets | researching-codebase | ~32 | Zero |

**Total gross savings: ~564 lines (~8,460 tokens) across the pipeline**

---

## Rewrite Priorities

**Ground-up rewrites (highest ROI):**

1. **`verification-before-completion`** — the Iron Law + 5-step gate are excellent; everything else (100+ lines) is elaboration of those two concepts. A rewrite keeping only the gate, Red Flags table, and integration diagram would halve the file to ~130 lines with no information loss.

2. **`implementing-plans`** — 535 lines but the live surface is the gate mechanics (§Per-phase review gate) + EVERGREEN RULE + worktree detection. The surrounding process prose (Steps 1–8) is elaborate scaffolding that could be a 40-line checklist driving into the load-bearing sections. Rewrite to ~280 lines.

3. **`parallel-agents`** — the decision framework + prompt requirements are tight; everything else is examples and process repetition. Rewrite to ~130 lines by keeping When to Use, Decision Framework, Agent Prompt Requirements, and the Anti-Patterns table.

**Surgical edits only (structure is sound):**
- `synthesizing-research` — 143 lines, few cuts needed
- `reviewing-code` — well-structured; remove Purpose para + one example + Integration section
- `research-plan-implement` — architecture + Phase 3 mechanics are load-bearing throughout; only peripheral sections are cuttable

---

## Style Inflation Patterns

1. **"Purpose" opener paragraphs** — every file has one; every one restates the frontmatter `description`. Cut all 10.

2. **Boilerplate agent-invocation code fences** — `Task tool with subagent_type: "file-finder"\nPrompt: "..."` repeated 8+ times across 3 files. Replace each with a prose sentence. Each fence costs ~6 lines.

3. **Wrong/Right anti-pattern pairs** — used in 7 of 10 files. When the paired items restate a nearby checklist, they're waste. Reserve Wrong/Right only for non-obvious reversals.

4. **Multi-level nesting of the same rule** — e.g., the no-security-per-phase rule appears in the prose, the checklist, AND the gate mechanics of implementing-plans. One location per rule.

5. **Process step prose + code fence duplicate** — Steps that explain an action in prose and then wrap the same content in a `text` code fence (e.g., parallel-agents Steps 1–5, implementing-plans Step 6 checkpoint). The fence adds visual weight without information.

6. **Verbose step-numbering** — "Step 1: Identify → Step 2: Create → Step 3: Dispatch → Step 4: Review → Step 5: Integrate" with paragraph breaks between each adds ~20 lines of whitespace-heavy structure for flows that could be expressed as a 5-item checklist.

7. **Restated quality criteria in both checklist and anti-patterns** — pattern in finishing-work, implementing-plans, writing-plans. The checklist is sufficient; the anti-patterns section should contain only non-obvious rules not captured elsewhere.
