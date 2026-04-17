# Research: RPI Research Phase — Evidence Sources and State Inspection Gap (2026-04-17)

## Problem Statement

The Research phase of the `research-plan-implement` pipeline currently produces findings grounded
exclusively in static source-code analysis. The goal of this investigation is to understand _why_
that is — whether state inspection is explicitly excluded or simply never mentioned — so that
concrete changes can be proposed in a follow-on planning phase.

---

## Where "Code Researcher" Framing Lives

### `research-plan-implement/SKILL.md`

**Lines 72–77 — "Define Research Questions" defaults:**

```
- **Codebase context**: How does the relevant code work today?
- **External context**: What APIs, libraries, or patterns are involved?
- **Security/performance**: Are there concerns to investigate?
```

All three bullet categories are framing around code artifacts or external documentation. Runtime
state (logs, query results, data samples, execution traces) is absent from the enumerated question
types. There is no "observed behavior" or "runtime evidence" category.

**Lines 85–97 — Codebase researcher prompt template:**

```
prompt: "Research [feature area] for the goal: [what will be implemented].

1. Invoke the Skill tool with skill: 'researching-codebase'
   and args: '[feature area]'
2. Follow the skill's full methodology (interrogation, exploration,
   documentation)
3. Write your findings to docs/plans/YYYY-MM-DD-<topic>-codebase.md"
```

The subagent is told to invoke `researching-codebase`, whose methodology (see below) is entirely
static. The prompt contains no instruction to run code, inspect data, or read logs.

**Lines 108–111 — Web researcher prompt template:**

```
prompt: "Research [specific question about API, library, pattern, or best
practice].

Provide findings with source citations and confidence assessment.
```

"Confidence assessment" appears here but only in the context of web research citations — it is
not applied to code findings, and there is no equivalent instruction for the codebase researcher.

### `researching-codebase/SKILL.md`

**Lines 1–6 — skill description:**

```
description: Thorough codebase exploration that builds understanding through
collaborative dialogue. Investigates architecture, patterns, and implementation
details before planning or making changes.
```

The scope is declared as "architecture, patterns, and implementation details" — all static.

**Lines 12–13 — "The Iron Law":**

```
**Ask questions BEFORE exploring code.**

Do not touch the codebase until the problem is understood.
```

The framing treats the codebase as the primary evidence source. The law is about interrogation
order, not evidence type, but it reinforces the code-first mental model with no mention of runtime
evidence as an alternative or complement.

**Lines 59–115 — Phase 2: Exploration (entire section):**

All exploration tools listed are static: file-finder agent, Read, Glob, Grep, LSP (goToDefinition,
findReferences, documentSymbol, incomingCalls, outgoingCalls). No Bash execution, no log reading,
no data queries. The only non-static step is the web-researcher sub-path (lines 119–139), which
retrieves external documentation — not runtime state.

**Lines 148–194 — Phase 3: Document Findings template:**

```markdown
### Relevant Files
| File | Purpose | Key Lines |
...
### Existing Patterns
...
### Dependencies
...
### External Research
...
### Technical Constraints
```

Every section heading maps to a static artifact. There is no "Runtime Observations," "Log
Analysis," "Data Samples," or "Execution Evidence" section in the output template.

### `synthesizing-research/SKILL.md`

**Lines 43–52 — "Organize by Theme" canonical themes:**

```
- Architecture and design patterns
- Data flow and state management
- External dependencies and APIs
- Security and performance considerations
- Testing patterns and coverage
- Gaps and open questions
```

All themes are code/documentation-derived. "Data flow and state management" sounds close but refers
to code-level data flow (tracing variables through source files), not observed runtime data.

**Lines 59–101 — Consolidated document template:**

Sections: Problem Statement, Requirements, Findings, External Research, Technical Constraints,
Open Questions, Recommendations, Sources. No section for runtime evidence, log excerpts, query
output, or execution traces.

---

## Why State Inspection Is Absent

State inspection is **not explicitly excluded** — there is no rule saying "do not run code" or
"do not read logs." The absence is structural: every methodology step, every tool enumerated,
every output template section, and every subagent prompt in the pipeline points exclusively at
source files or external documentation. The gap is one of omission, not prohibition.

The one place that hints at runtime evidence is the web-researcher confidence assessment (RPI
SKILL.md line 110: "confidence assessment") but that convention is scoped to external web
research only and is never carried into codebase findings.

---

## Contrast with `systematic-debugging`

`systematic-debugging/SKILL.md` differs from `researching-codebase` in two structural ways:

**1. It mandates runtime evidence gathering (Phase 1, lines 29–56):**

- "Reproduce consistently" (lines 39–42) — requires triggering the failure, not just reading code
- "Gather diagnostic evidence" (lines 44–47):
  ```
  - Add logging at key points
  - Check system state (memory, disk, network)
  - Inspect input data
  ```
- "Trace backwards" from the error through the call stack (lines 49–52)

**2. It names concrete runtime investigation techniques (lines 175–211 — "Evidence Gathering
Techniques"):**

- **Logging**: Add temporary logging at entry/exit, variable values, timestamps, request/response
  payloads
- **Bisection**: `git bisect` to find breaking commit; binary search through changes
- **Isolation**: Minimal test case; remove unrelated code; eliminate variables
- **Comparison**: Working vs broken environment, input, or configuration

These are Bash-executable techniques — running the code and observing output — not reading source
files. The pattern to borrow is: enumerate evidence-gathering techniques as named subsections with
concrete tool actions (add logging → run → observe output).

**Key structural difference**: `systematic-debugging` treats code reading as one input among
several; `researching-codebase` treats code reading as the only input.

---

## Existing Conventions to Extend

**Confidence assessment (partial):** RPI SKILL.md lines 109–110 and `synthesizing-research`
SKILL.md line 23 ("Confidence levels stated by each researcher") already introduce the idea of
confidence levels in research outputs. However, this is applied only to web research. There is no
convention for marking a code finding as "inferred from source" vs "confirmed by execution."

**Assumption surfacing (partial):** `researching-codebase/SKILL.md` lines 214–217 define an
"Assumption surfacing" questioning technique:
```
> I'm assuming this needs to work with the existing auth system. Is that correct?
```
This is a dialogue technique, not a document marker — assumptions surface in conversation but are
not tagged in the output document. No assumption-tagging schema exists in the output templates.

**Open Questions section:** Both `researching-codebase` (line 186) and `synthesizing-research`
(line 88) include an "Open Questions" section. This is the closest existing hook to flagging
unverified findings, but it is narrative, not structured, and does not distinguish between
"we haven't read this code yet" and "we don't know what this code does at runtime."

**Sources table:** `synthesizing-research` lines 96–100 include a Sources table with columns
Document / Researcher / Focus Area. This could be extended to include an Evidence Type column
without inventing new structure.

---

## Concrete Change Surface

The following files and sections would need editing to add state-inspection guidance and
assumption/evidence marking. No rewrites proposed here — locations only.

| File | Section / Heading | Nature of gap |
|------|-------------------|---------------|
| `skills/research-plan-implement/SKILL.md` | **Phase 1 › Step 1: Define Research Questions** (lines 72–77) | Add a third question category for observed/runtime behavior alongside "Codebase context" and "External context" |
| `skills/research-plan-implement/SKILL.md` | **Step 2: Spawn Research Subagents — Codebase researcher prompt** (lines 85–97) | Prompt contains no instruction to run code or inspect state; needs state-inspection option |
| `skills/research-plan-implement/SKILL.md` | **Step 2 — "Additional subagents"** block (lines 116–122) | Natural place to add a named "state-researcher" or "runtime-researcher" subagent template |
| `skills/researching-codebase/SKILL.md` | **Phase 2: Exploration** (lines 59–115) | No Bash execution, log reading, or data query steps; needs a "Runtime Evidence" subsection alongside LSP |
| `skills/researching-codebase/SKILL.md` | **Phase 3: Document Findings — output template** (lines 148–194) | Template has no section for runtime observations; needs one alongside "Existing Patterns" |
| `skills/synthesizing-research/SKILL.md` | **Step 3: Organize by Theme — canonical themes** (lines 43–52) | All themes are static; needs a "Runtime Evidence" or "Observed Behavior" theme |
| `skills/synthesizing-research/SKILL.md` | **Step 4: Consolidated document template** (lines 59–101) | No section for runtime evidence; Sources table (lines 96–100) lacks an Evidence Type column |
| `skills/synthesizing-research/SKILL.md` | **Step 2: Read All Source Files — "Note:" checklist** (lines 22–25) | Lists confidence levels but only for external research; no instruction to tag evidence by type |

---

## Open Questions

1. **Scope of "runtime" in different project types.** In a data-science repo, "state inspection"
   means running a query and sampling results. In a web API repo it means reading server logs. In
   a CLI tool it may mean running the binary. Does the change need to be domain-aware, or should
   it enumerate examples from multiple domains?

2. **Who triggers state inspection?** The orchestrator in RPI spawns a named "codebase-researcher"
   subagent. Should state inspection live in that same subagent (conditional path) or as a
   separate "state-researcher" subagent spawned in parallel? The answer affects how the prompt
   template changes.

3. **Confidence/assumption tagging format.** The existing convention is prose ("I'm assuming...").
   Should the plan propose a lightweight inline marker (e.g. `[INFERRED]` / `[OBSERVED]`) or a
   structured metadata block in the output template? This is a design decision for the planner.

4. **Interaction with the planner's assumption of research completeness.** `writing-plans/SKILL.md`
   line 217 instructs the planner: "Do NOT ask the user questions — use the research document as
   your source of truth." If research contains unverified inferences, the planner has no signal to
   treat them differently. The planner's instructions may also need a small addition — but that
   scope should be confirmed before the edit is proposed.

5. **Backward compatibility.** All existing research documents in `docs/plans/` use the current
   template without evidence-type sections. Changes to the template should not break the
   synthesizer's ability to consume legacy documents.
