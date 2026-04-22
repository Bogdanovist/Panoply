---
name: researching-codebase
description: Thorough codebase exploration that builds understanding through collaborative dialogue. Investigates architecture, patterns, and implementation details before planning or making changes.
argument-hint: topic or question to research
---

# Research Methodology

Research topic: **$ARGUMENTS**

## The Iron Law

**Ask questions BEFORE exploring code.**

Do not touch the codebase until the problem is understood. Resist the urge to immediately search for files or read
code.

## Phase 1: Understanding the Request

**Your first action must be asking a clarifying question.**

Do NOT:

- Read any files
- Search the codebase
- Use Glob or Grep
- Explore anything
- Make assumptions about what the user wants

**Ask questions one at a time using AskUserQuestion:**

- Prefer multiple choice questions when possible, but open-ended is fine too
- Only one question per message
- If a topic needs more exploration, break it into multiple questions

**Focus on understanding:**

- **Purpose**: What are they trying to accomplish? (build, change, fix, learn)
- **Specifics**: What exactly should happen or change?
- **Scope**: How big is this? (one file, multiple files, architectural)
- **Constraints**: Any requirements around performance, compatibility, security?
- **Context**: Have they already looked at anything or have hunches?

**When you believe you understand, confirm:**

Summarize your understanding and ask if it's accurate before proceeding.
If anything needs clarification, ask follow-up questions.

## Phase 2: Exploration

**Only proceed after confirming understanding with the user.**

### Locate Relevant Files

Spawn a `file-finder` agent with the research topic and the user's stated purpose.

The file-finder will return a structured report with:

- Core files to examine first
- Supporting files and utilities
- Test files
- Configuration files
- Suggested reading order

### Explore the Discovered Files

Use TaskCreate to track exploration based on the file-finder report. Create one task per file category (core,
supporting, test, config) and update via TaskUpdate as you examine each.

**Examine core files first:**

- Read files in the suggested order
- Understand the main flow and architecture
- Note patterns and conventions

**Trace relevant data flow:**

- Follow data through the identified files
- Identify inputs, transformations, outputs
- Document state changes and side effects

**Review supporting files:**

- Examine utilities and helpers
- Note reusable patterns
- Document conventions for testing and error handling

**Identify technical constraints:**

- External dependencies
- Performance considerations
- Security implications

### Deepen Understanding with LSP

After identifying relevant files, use the LSP tool for deeper structural understanding:

- `goToDefinition` — trace how functions and types connect across files
- `findReferences` — understand where symbols are used throughout the codebase
- `documentSymbol` — get a structured overview of a file's exports and structure
- `incomingCalls` / `outgoingCalls` — map call hierarchies to understand data flow

> If LSP is unavailable (no configured language server), skip this step
> and rely on Grep-based content search.

### Gather Runtime Evidence (When Applicable)

Code reading alone cannot answer questions about what the system *currently does at runtime* — the shape of real
data, the volume and content of recent logs, the actual stdout of a CLI. For those questions, runtime evidence
complements static analysis.

Concrete domain examples:

- **Data pipelines**: query data assets directly (e.g. `bq query`, `duckdb`, a notebook cell), inspect table
  schemas, sample a handful of rows, check row counts and null distributions.
- **Production services**: tail or grep recent logs, inspect a running endpoint's response, check a health or
  metrics endpoint, look at structured log output for a representative request.
- **CLI / local tools**: run the binary with a representative input, capture stdout and stderr, check the exit
  code and any files the tool produces.

Runtime evidence gathering is opt-in, scoped tightly to the question at hand, and must not mutate shared state —
use read-only queries and avoid destructive commands.

Findings confirmed by runtime evidence are tagged `[OBSERVED]` in Phase 3; findings inferred from static analysis
only are tagged `[INFERRED]`.

### Surface Broken Windows

Exploration often turns up problems incidental to the research
question — a failing test in the area, a stale TODO that's now wrong,
dead code, an obvious bug in a function you're reading. These are not
distractions; they are part of the deliverable. Capture each in the
findings doc with a proposed disposition:

- **`[FIX-INLINE]`** — small enough that the implementation phase
  should sweep it up alongside the planned change.
- **`[FIX-FOLLOWUP]`** — too large or off-topic to fold in transparently;
  the plan should add a discrete remediation step so it gets fixed in
  the same RPI session, not deferred into the void.
- **`[FLAG-HUMAN]`** — risky, controversial, or ambiguous; needs a
  human decision before anything is touched.

"Note as pre-existing and ignore" is not a disposition. The default is
that broken things found during research get fixed during this session,
because we have the context now. Surfacing them in research is what
gives the planner the chance to schedule the sweep-up.

### Research External Context (When Needed)

For single-page lookups (e.g., checking a library's API docs or a specific GitHub issue), use WebFetch directly instead
of spawning a web-researcher agent. Reserve the web-researcher for multi-source research requiring synthesis.

If codebase exploration reveals external factors that need broader investigation, spawn a `web-researcher` agent with the specific research question.

Use web research for:

- Understanding external libraries or APIs the code depends on
- Comparing implementation approaches or best practices
- Investigating third-party service documentation
- Researching security implications or known issues

The web-researcher returns findings with source citations and confidence assessments.

**Present findings incrementally:**

- Share what you find in digestible sections
- Ask if findings align with expectations or if you should look elsewhere
- Be ready to redirect based on feedback

## Phase 3: Document Findings

Create research document at: `docs/plans/YYYY-MM-DD-<topic>-research.md`

(Use today's date in YYYY-MM-DD format)

Tag each finding inline with its evidence type. Use `[OBSERVED]` when the claim is backed by runtime evidence
captured during Phase 2 (query output, log excerpt, CLI stdout); use `[INFERRED]` when the claim is read off
source code without runtime confirmation. Place the tag at the start of the bullet or sentence making the claim,
e.g. `[INFERRED] The retry logic appears to use exponential backoff based on src/api/retry.ts:42-57.`

```markdown
# Research: <Topic> (YYYY-MM-DD)

## Problem Statement

[What the user wants to accomplish]

## Requirements

[Key requirements gathered during interrogation]

## Findings

### Relevant Files

| File            | Purpose     | Key Lines |
| --------------- | ----------- | --------- |
| path/to/file.ts | Description | 42-87     |

### Existing Patterns

[Patterns discovered that inform implementation]

### Runtime Observations

[Evidence captured by running code, querying data, or reading logs
during exploration. Each entry records the command or query run,
the raw (trimmed) output, and the conclusion drawn. Tag each
conclusion [OBSERVED].]

### Dependencies

[External and internal dependencies]

### External Research

[Findings from web research, if conducted - include sources]

### Technical Constraints

[Limitations discovered during exploration]

### Pre-Existing Issues Discovered

[Problems uncovered incidental to the research question. Tag each
[FIX-INLINE], [FIX-FOLLOWUP], or [FLAG-HUMAN] per the disposition rule
in Phase 2 §"Surface Broken Windows". Default is FIX-INLINE/FOLLOWUP —
"note and ignore" is not a valid disposition.]

## Open Questions

[Questions that remain unanswered]

## Recommendations

[Initial thoughts on approach]
```

## Phase 4: Transition

Ask what the user wants to do next:

- Create an implementation plan
- Continue researching
- End for now

## Questioning Techniques

**Funnel questions** - Start broad, narrow based on answers:

1. "What are you trying to accomplish?" (broad)
2. "Which part is most important?" (narrowing)
3. "What would success look like?" (specific)

**Assumption surfacing** - Make assumptions explicit:

> I'm assuming this needs to work with the existing auth system. Is that
> correct?

**Trade-off questions** - When multiple approaches exist:

> There's a trade-off: Option A is faster to build but less flexible.
> Option B is more flexible but more complex. Which matters more here?

**Clarification through examples** - When requirements are vague:

> Can you give me an example of what you'd expect to happen?

## Anti-Patterns

| Wrong                                          | Right                                                 |
| ---------------------------------------------- | ----------------------------------------------------- |
| Reading files immediately                      | Ask questions first                                   |
| Multiple questions in one message              | One question, wait, then next                         |
| "I understand, let me look"                    | "Let me confirm: [summary]. Accurate?"                |
| "How should we handle this?"                   | "Should we A) do X, B) do Y, or C) something else?"   |
| "I'll add a new AuthService"                   | "The codebase uses repository pattern. Auth is here." |

## Key Principles

- **One question at a time** - Don't overwhelm with multiple questions
- **Multiple choice preferred** - Easier to answer than open-ended
- **Confirm before exploring** - Validate understanding first
- **Incremental findings** - Present discoveries in sections, validate each
- **Be flexible** - Go back and clarify when something doesn't fit
