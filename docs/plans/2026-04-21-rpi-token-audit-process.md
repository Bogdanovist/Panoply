# RPI Pipeline: Process-Level Token Waste Audit (2026-04-21)

## Token-Flow Map

A full RPI run through a moderate 3-phase plan:

```
ORCHESTRATOR (main context)
  reads: SKILL.md (~550 lines, loaded at invocation)
  holds: phase summaries, sentinel values, base_ref
  writes: nothing (deliberately thin)

Phase 1 — Research (2 parallel subagents + 1 synthesizer)
  codebase-researcher: researching-codebase SKILL.md (~276 lines) +
    full codebase exploration (large but bounded by work)
  web-researcher: free-form prompt only (no skill loaded)
  synthesizer: synthesizing-research SKILL.md (~144 lines) +
    reads all raw research files in full

Phase 2 — Planning (1 subagent)
  planner: writing-plans SKILL.md (~573 lines) +
    reads consolidated research file in full (can be 200-400 lines)
  model: opus (justified — architecture decisions)

Phase 3 — Implementation (N subagents, one per review_group)
  per-group implementer: implementing-plans SKILL.md (~535 lines) +
    reads FULL plan doc (can be 300-600 lines) +
    EVERGREEN CODE RULE embedded in spawn prompt (~130 words) +
    reads all files in its scope during execution
  model: opus (justified — code generation)

  reviewing-code subagent (invoked via gate script):
    reviewing-code SKILL.md (~266 lines) +
    reads full diff for its review pass
  model: sonnet (correct)

Terminal security-gate (1 subagent)
  security-reviewer: security-review SKILL.md (~254 lines) +
    reads full aggregated git diff
  model: (not specified — defaults uncontrolled)

finishing-work (invoked by orchestrator via Skill tool)
  finishing-work SKILL.md (~372 lines)
  model: (inherits orchestrator — may be opus)
```

**Key observation**: The orchestrator itself spawns each subagent with a
prompt block of ~250-400 words before the subagent even loads its skill.
The skill is then loaded on top, re-stating much of what the prompt already
said about methodology.

---

## Findings

### 1. EVERGREEN CODE RULE duplicated in every implementer prompt

**Category**: CLEAR WASTE

**Current cost**: The EVERGREEN CODE RULE block (lines 358-368 in
research-plan-implement/SKILL.md) is ~130 words embedded verbatim in
the spawn prompt for every implementer. If a plan has 4 review groups,
this block is emitted 4 times (plus once in implementing-plans SKILL.md).

**The rule is already in implementing-plans SKILL.md** (section "Keep
Code and Comments Evergreen", ~120 words). Subagents load that skill,
so they receive the rule twice per spawn.

**Proposed change**: Remove the EVERGREEN CODE RULE block from the
orchestrator's implementer spawn prompt. Retain it in implementing-plans
SKILL.md (the authoritative location). Add a single sentence to the spawn
prompt: "The evergreen-code rule applies — see implementing-plans."

**Estimated savings**: ~130 words × N implementers. For a 4-group plan:
~520 words (~700 tokens) eliminated from spawn prompts, plus the skill
double-load eliminated.

**Risk**: Near-zero. The skill carries the rule; spawn prompts referencing
it won't lose the behaviour.

---

### 2. Implementers read the FULL plan; only their group section is needed

**Category**: LIKELY WASTE

**Current state**: The spawn prompt says "Read the plan, focusing on your
group's phase sections" — but implementing-plans SKILL.md step 1 says
"Read the file at that path directly." There is no structural constraint
preventing an implementer from reading and attending to all phases. For a
large 6-phase plan (~600 lines), each implementer loads the full document.

**Proposed change**: The spawn prompt already supplies the list of phase
names for the group. Add an explicit instruction: "Read ONLY your group's
phase sections and the Execution block summary at the top. Do not read
sections for other review_groups." This is compatible with the existing
"Your scope is limited to this group only" directive.

**Estimated savings**: For a 6-phase plan with 3 groups, each implementer
skips ~400 lines of irrelevant plan content. Rough saving: 3 × 400 lines
× ~1.3 tokens/line ≈ 1,560 tokens.

**Risk**: Low. Group dependencies are declared in Execution blocks, which
are short and can be skimmed without reading full step detail. The plan
must already contain enough info in the Execution block for the
orchestrator to route — same info is enough for the implementer.

---

### 3. synthesizing-research re-reads raw research files in full

**Category**: LIKELY WASTE

**Current state**: The synthesizer reads every raw research file (codebase,
web, security) — potentially 3 × 200-400 lines = 600-1,200 lines — then
writes a consolidated document. The orchestrator then reads the synthesized
output to present to the user. No compaction happens between the raw files
and the synthesis.

**Proposed change**: The synthesis output is the right artifact; the raw
files are transient. After synthesis completes, the orchestrator could
advise deleting or truncating the raw research files (or gitignore them by
default). This has no effect on token cost of the synthesizer itself, but
reduces the chance that a planner or implementer accidentally pulls in raw
files instead of the synthesis.

More impactful: the synthesizer prompt in the orchestrator currently just
says "consolidate [file list]". A one-sentence instruction to keep the
synthesis ≤200 lines would reduce the planner's input for Phase 2. Current
synthesis files have no length guidance and can expand to match the raw
input size.

**Estimated savings**: 100-200 lines per synthesis → planner reads a
tighter document (saves ~200 tokens in Phase 2 input).

**Risk**: Low if a brevity cap is expressed as a guidance, not a hard limit
("aim for ≤200 lines; include everything decision-critical"). Quality loss
risk is minimal as synthesis should already distil.

---

### 4. Terminal security-gate model not specified — may default to opus

**Category**: CLEAR WASTE

**Current state**: The implementer spawn prompt explicitly specifies
`model: "opus"`. The security-gate invocation block in
research-plan-implement/SKILL.md (Step 4) does not specify a model
for the security-reviewer spawn. The reviewing-code subagent is
correctly assigned sonnet in the gate script comments, but the actual
gate invocation is LLM-driven prose — the security-reviewer may
inherit the orchestrator's opus model.

**Proposed change**: Add `model: "sonnet"` to the security-reviewer
spawn in the terminal-gate step. Security review is a structured
checklist against a known diff — this is squarely in sonnet's
capability range. Opus is not needed here.

**Estimated savings**: Sonnet vs opus cost differential on a
typical security review (500-1,500 token diff): ~3-4x price reduction
per security review invocation.

**Risk**: Low. Security checklists are pattern-matching tasks. If a
finding is ambiguous, the reviewer writing `CHANGES` (not `REVIEW_APPROVED`)
is already the conservative path; model degradation doesn't change
the safety direction.

---

### 5. researching-codebase SKILL.md has a large "ask questions first" ceremony that is wrong for subagent use

**Category**: TRADEOFF

**Current state**: researching-codebase is designed for interactive use
— its Phase 1 ("The Iron Law") instructs the agent to stop and ask
clarifying questions before reading any files. When spawned as a subagent
within RPI Phase 1, the research question has already been scoped by the
orchestrator prompt. The subagent wastes a round-trip (or ignores the rule
and violates its own skill).

**Proposed change**: Add a header note to researching-codebase:
"If invoked as a subagent with a fully specified research question in
`$ARGUMENTS`, skip Phase 1 entirely and begin exploration directly."
Alternatively, the orchestrator spawn prompt could include: "Skip Phase 1
(questioning) — the research question is fully specified above."

The latter is cheaper to implement (one line in the spawn prompt).

**Estimated savings**: Eliminates 0-1 unnecessary interactive round-trips
and removes cognitive overhead from the subagent parsing the Iron Law when
it doesn't apply. Hard to quantify in tokens; mainly saves wall-clock time.

**Risk**: TRADEOFF — the questioning phase adds value in direct invocations.
Any change must preserve Phase 1 for interactive use. The spawn-prompt
override is safer than modifying the skill.

---

### 6. Skill tool + embedded methodology = double-load of content

**Category**: LIKELY WASTE

**Current state**: Each spawn prompt says "Invoke the Skill tool with
skill: 'X'" AND gives inline methodology instructions (e.g. "Follow the
skill's full methodology", "Write findings to..."). The Skill tool then
loads the SKILL.md, which re-states the methodology. In practice the
agent's context contains: (a) the spawn prompt's inline instructions and
(b) the skill's full content. The inline instructions duplicate the skill's
opening purpose statement and sometimes its output format.

For implementing-plans, the spawn prompt for an implementer is ~350 words
of instructions that overlap substantially with implementing-plans SKILL.md
sections 1-3 and 8.

**Proposed change**: Reduce inline instructions in spawn prompts to
identity + deliverable only (what group to work on, what file to write,
what gate to invoke). Rely on the loaded skill for methodology. The spawn
prompt for implementing should be ~100 words, not ~350.

**Estimated savings**: ~250 words per implementer spawn × N groups. For a
4-group plan: ~1,000 words ≈ 1,300 tokens eliminated from spawn prompts.

**Risk**: TRADEOFF — some redundancy is intentional as a forcing function
(skills load lazily; if the agent forgets to invoke the skill, the inline
instructions keep it on track). Before trimming, validate that the Skill
tool invocation is reliable in subagent contexts.

---

### 7. verification-before-completion is not invoked in the RPI pipeline — good; but implementing-plans describes it redundantly

**Category**: CLEAR WASTE (documentation clutter, not token cost)

**Current state**: verification-before-completion SKILL.md is a standalone
skill (~280 lines) whose methodology is fully re-stated inline in
implementing-plans (section "5. Execute Steps in Order", step 5-6 and
section "Verify Before Claiming Done"). The verification skill is never
explicitly invoked in the RPI flow. It is redundant with implementing-plans
content.

**Proposed change**: In implementing-plans, replace the inline
verification section with: "Follow verification-before-completion skill
discipline — run each verify criterion freshly before marking a step
done." Save the full methodology for the skill itself. Saves ~60 lines
from implementing-plans without losing behaviour.

**Risk**: Near-zero. The skill is still available if invoked directly.

---

### 8. finishing-work SKILL.md is invoked by the orchestrator via Skill tool but has a long prerequisites section not relevant to RPI use

**Category**: LIKELY WASTE

**Current state**: finishing-work has a 5-item prerequisite checklist
including "Code review completed (if applicable)" and "Security review
completed (if applicable)". When invoked from RPI's terminal security-gate
PASS path, both conditions are guaranteed true by the pipeline. The
subagent still reads and processes these. The skill also has a 372-line
body with branch-strategy options (merge locally, create PR, keep,
discard) that the subagent must parse in full.

**Proposed change**: No structural change needed. But add an early-exit
note: "If invoked via `research-plan-implement` with a plan path, assume
prerequisites 1-4 are satisfied. Proceed directly to Step 3 (present
options)." This is a ~1-sentence addition that short-circuits prerequisite
verification in the most common RPI invocation path.

**Estimated savings**: Eliminates prerequisite check overhead (~50 tokens
of subagent reasoning, not skill content).

**Risk**: Low.

---

### 9. No succinctness directive in subagent spawn prompts

**Category**: LIKELY WASTE

**Current state**: Neither the orchestrator SKILL.md nor any child skill
spawn prompt contains a directive like "Be concise. Report only what the
next phase needs." The global CLAUDE.md has "Simplicity first" as a user
preference but this is not explicitly projected into subagent contexts.

Research subagents in particular have no length budget — a codebase
researcher can produce 500+ lines of findings when 150 lines covering
decision-critical paths would serve the planner equally well.

**Proposed change**: Add to each spawn prompt's deliverable line: "Keep
your output document ≤200 lines; include everything decision-critical,
omit exploratory notes and file-listing detail." Add the same guidance
to researching-codebase and synthesizing-research SKILL.md quality
criteria.

**Estimated savings**: If research docs shrink from ~400 to ~200 lines,
the planner's Phase 2 context drops by ~200 lines × ~1.3 tokens/line
≈ 260 tokens in input. Compound over multi-agent runs.

**Risk**: Low if phrased as guidance ("aim for ≤200 lines") not as a hard
cap. Quality reviewers should still write comprehensive findings; this
nudge targets exploratory padding.

---

### 10. `.review-verdict` sentinel carries full findings text — orchestrator reads it but only needs PASS/CHANGES verdict

**Category**: TRADEOFF

**Current state**: The gate contract says the sentinel holds either
`REVIEW_APPROVED` or "a bulleted list of blocking issues" (CHANGES path).
The orchestrator reads the sentinel to determine next action. For cap-hit
(exit 42), the gate script itself prints both rounds of findings to stdout
— the orchestrator consumes stdout. The sentinel in this case contains only
pass-2 findings.

**Current cost**: Minimal — sentinel files are small (typically 200-800
tokens of findings). The orchestrator reads them once.

**Assessment**: This is already lean. The sentinel design correctly puts
full findings in the artifact. No change recommended.

---

## Top 5 Highest-Value Changes

Ranked by (tokens saved × implementation safety):

| Rank | Finding | Category | Est. Token Savings | Safety |
|------|---------|----------|-------------------|--------|
| 1 | #6 — Trim implementer spawn prompts (remove methodology overlap with skills) | TRADEOFF | 1,300/plan | High if validated |
| 2 | #1 — Remove EVERGREEN CODE RULE from spawn prompt; keep in skill only | CLEAR | 700/plan | Very high |
| 3 | #4 — Specify `model: "sonnet"` for security-reviewer spawn | CLEAR | 3-4× cost/security review | Very high |
| 4 | #2 — Instruct implementers to read only their group's plan sections | LIKELY | 1,560/plan | High |
| 5 | #9 — Add brevity nudge to research spawn prompts and synthesis skill | LIKELY | 260+ per run | High |

---

## Anti-Patterns to Add to Orchestrator Rules

```text
| Do Not | Instead |
| ------ | ------- |
| Embed EVERGREEN CODE RULE in every implementer spawn prompt | Rule lives in implementing-plans SKILL.md; reference it with one sentence |
| Leave security-reviewer model unspecified | Always specify model: "sonnet" for reviewer subagents |
| Write implementer spawn prompts that restate skill methodology | Spawn prompt = identity + deliverable + gate invocation; methodology is the skill's job |
| Allow research docs to grow without a length budget | Include "≤200 lines, decision-critical only" in each research subagent's deliverable spec |
| Spawn codebase-researcher with Phase 1 questioning enabled | In subagent context, add "skip Phase 1 — research question fully specified" to spawn prompt |
```
