---
name: research-plan-implement
description: End-to-end Research-Plan-Implement pipeline using parallel subagents. Each phase (research, plan, implement) runs in its own context window with file artifacts as the communication channel between phases.
argument-hint: feature or change to build end-to-end
effort: high
---

# Research-Plan-Implement Pipeline

Orchestrate the full Research → Plan → Implement workflow in a single session using subagents. Each phase runs as a
separate subagent with its own context window, coordinated by the orchestrator that handles approval gates and phase
transitions.

## Purpose

Running RPI phases across separate sessions loses context and requires manual bridging. This skill collapses the three
phases into one orchestrated pipeline using subagents via the Agent tool. Each subagent gets maximum context for its
work, with file artifacts on disk as the communication channel between phases.

## Architecture

The orchestrator (you) stays thin. It spawns subagents for each phase via the Agent tool, reads their output artifacts,
presents summaries to the user, and handles approval gates. The orchestrator does NOT do research, planning, or
implementation itself.

```text
ORCHESTRATOR (main context — stays thin)
  │
  ├── Phase 1: Spawn research subagents (parallel)
  │     ├── Subagent: codebase exploration
  │     ├── Subagent: web research
  │     └── Subagent: synthesis → writes research file
  │     └── Output: docs/plans/YYYY-MM-DD-<topic>-research.md
  │
  ├── [APPROVAL GATE: User confirms research findings]
  │
  ├── Phase 2: Spawn planning subagent
  │     └── Subagent: reads research file, writes plan file
  │     └── Output: docs/plans/YYYY-MM-DD-<topic>-plan.md
  │
  ├── [APPROVAL GATE: User approves plan]
  │
  └── Phase 3: Spawn ONE implementer per plan phase
        │     (sequential by default; parallel only where the plan
        │      marks phases as independent; pause at any phase the
        │      plan marks as gated, honouring its chosen mechanism)
        └── Output: code changes, test results, PR(s)
```

**Key principle**: Subagents communicate through files, not conversation context. Each subagent reads the artifacts from
prior phases and writes its own artifacts for the next phase.

## When to Use

Use this pipeline when:

- A feature requires understanding unfamiliar code or APIs
- Multiple aspects need investigation before planning
- The full research → plan → implement cycle is needed
- You want to avoid manually bridging sessions between phases

Do NOT use when:

- Requirements are already clear (skip to `writing-plans`)
- A plan already exists (skip to `implementing-plans`)
- This is a simple bug fix (use `systematic-debugging`)
- Only research is needed without implementation

## Phase 1: Research (Parallel Subagents)

### Step 1: Define Research Questions

Before spawning subagents, break the feature into independent research questions. Typically 2-3 questions covering:

- **Codebase context**: How does the relevant code work today?
- **External context**: What APIs, libraries, or patterns are involved?
- **Security/performance**: Are there concerns to investigate?

### Step 2: Spawn Research Subagents

Spawn subagents for each research question using the Agent tool. Each subagent gets its own context window. Use
existing skills to ensure consistent methodology. Launch independent subagents in parallel by including multiple Agent
tool calls in a single message.

**Codebase researcher:**

```text
Spawn a subagent with the Agent tool:
  name: "codebase-researcher"
  model: "sonnet"
  prompt: "Research [feature area] for the goal: [what will be implemented].

1. Invoke the Skill tool with skill: 'researching-codebase'
   and args: '[feature area]'
2. Follow the skill's full methodology (interrogation, exploration,
   documentation)
3. Write your findings to docs/plans/YYYY-MM-DD-<topic>-codebase.md"
```

**Web researcher (when external context needed):**

```text
Spawn a subagent with the Agent tool:
  name: "web-researcher"
  model: "sonnet"
  prompt: "Research [specific question about API, library, pattern, or best
practice].

Provide findings with source citations and confidence assessment.
Write your findings to docs/plans/YYYY-MM-DD-<topic>-external.md"
```

**Additional subagents (when needed):**

```text
Spawn a subagent with the Agent tool:
  name: "security-researcher"
  model: "sonnet"
  prompt: "Investigate security and performance implications of [feature].
Write findings to docs/plans/YYYY-MM-DD-<topic>-security.md"
```

> **Note**: Research agents must NOT use `isolation: "worktree"` — they
> write shared artifacts to `docs/plans/` that other agents and the main
> session need to read.

Guidelines:

- Verify questions are truly independent before parallelizing
- Each subagent gets a focused scope with clear deliverable
- Keep to 2-4 subagents for manageability
- Each subagent writes its findings to a separate file

### Step 3: Synthesize Research

After research subagents complete, spawn a synthesis subagent that consolidates all findings using the synthesis skill.

```text
Spawn a subagent with the Agent tool:
  name: "synthesizer"
  model: "sonnet"
  prompt: "Synthesize all research findings for '<topic>'.

1. Invoke the Skill tool with skill: 'synthesizing-research'
   and args: '<topic>'
2. Follow the skill's full methodology to consolidate:
   - docs/plans/YYYY-MM-DD-<topic>-codebase.md
   - docs/plans/YYYY-MM-DD-<topic>-external.md
   - [any additional research files]
3. Write the consolidated document to:
   docs/plans/YYYY-MM-DD-<topic>-research.md"
```

### Step 4: Present Summary and Gate

Read the research document and present a brief summary to the user. Include the subagent results table:

| Agent | Task | Status | Key Findings |
| ----- | ---- | ------ | ------------ |

```text
Research complete for '<topic>'.

Key findings:
- [Finding 1]
- [Finding 2]
- [Finding 3]

Research document: docs/plans/YYYY-MM-DD-<topic>-research.md
```

Use AskUserQuestion:

- "Create plan" — proceed to Phase 2
- "More research needed" — spawn additional subagents
- "Stop here" — end with research document

## Phase 2: Plan (Dedicated Subagent)

Spawn a planning subagent that reads the research document and creates the implementation plan. The subagent gets a
fresh context window with only the research file as input.

```text
Spawn a subagent with the Agent tool:
  name: "planner"
  model: "opus"
  prompt: "You are creating an implementation plan.

1. Read the research document at
   docs/plans/YYYY-MM-DD-<topic>-research.md
2. Invoke the Skill tool with skill: 'writing-plans' and
   args: '<topic>'
3. Follow the skill's full methodology to create the plan
4. Write the plan to docs/plans/YYYY-MM-DD-<topic>-plan.md

Size each phase so it is one clear task a single implementer can
hold in context end-to-end — not a grab-bag of loosely related work.
If a phase is growing broad, split it.

For EACH phase, the plan must include an 'Execution' block with:
  - Scope: one-sentence description of the implementer's task
  - Depends on: list of prior phase names (or 'none')
  - Parallel with: list of phase names that can run concurrently
    (or 'none' — sequential is the default)
  - Gate: either 'autonomous' OR a described review gate. Pick the
    mechanism that fits the phase (examples: orchestrator pauses and
    asks the user to review before the next phase; implementer opens
    a sub-PR into a feature branch and stops until merged; etc.).
    There is no implicit default — every phase must state this
    explicitly.

The overall plan must also state the branch/PR strategy at the top
(e.g. single PR to main at the end, or feature branch with per-phase
sub-PRs, or other). Pick what fits; feature-branch-with-sub-PRs is
one common option when multiple phases need review.

The plan must reference the research document and be self-contained.
Do NOT ask the user questions — use the research document as your
source of truth for requirements and constraints."
```

### Present Plan and Gate

When the planning subagent completes, read the plan document and present a summary to the user:

```text
Plan created for '<topic>'.

Stakes: [level]
Phases: [count]
Steps: [count]

Plan document: docs/plans/YYYY-MM-DD-<topic>-plan.md
```

Use AskUserQuestion:

- "Approve and implement" — proceed to Phase 3
- "Request changes" — describe what to modify, spawn new planner
- "Stop here" — end with plan document

**Do not skip this approval gate.** The user must explicitly approve the plan before implementation begins.

## Phase 3: Implement (One Subagent Per Plan Phase)

After plan approval, work through the plan **one phase at a time**, spawning exactly ONE implementer per phase. Each
implementer gets a fresh context window scoped to a single clear task, so its context stays focused and uncluttered.

### Step 1: Read the Plan's Execution Structure

Read the plan file and extract, for each phase, the `Execution` block (scope, depends-on, parallel-with, gate) plus the
overall branch/PR strategy. The orchestrator only reads this structural metadata plus the phase's own section — not the
full content of other phases.

If the plan is missing per-phase `Execution` blocks, stop and spawn a fresh planner to add them — do not proceed without
explicit gating and dependency info.

### Step 2: Execute Phases in Dependency Order

Walk the phases respecting `depends on`. **Sequential is the default.** Spawn multiple implementers concurrently (in a
single message with multiple Agent calls) ONLY when the plan explicitly marks phases as `parallel with` each other AND
their dependencies are satisfied.

For each phase (or parallel group), spawn exactly one implementer per phase:

```text
Spawn a subagent with the Agent tool:
  name: "implementer-<phase-slug>"
  model: "opus"
  isolation: "worktree"
  prompt: "You are implementing ONE phase of an approved plan.

NOTE: You are running in an isolated worktree (isolation: worktree).
The implementing-plans skill will detect this via 'test -f .git' and
skip the worktree offer — this is expected behavior.

Plan: docs/plans/YYYY-MM-DD-<topic>-plan.md
Your phase: <phase name>
Your scope is limited to this phase only. Do NOT start work on any
other phase, even if steps look related. Other phases have their own
implementers.

1. Read the plan, focusing on your phase's section and its
   Execution block (scope, gate, branch strategy).
2. Invoke the Skill tool with skill: 'implementing-plans' and
   args: 'docs/plans/YYYY-MM-DD-<topic>-plan.md'
3. Follow the skill's methodology for YOUR phase only:
   - Execute your phase's steps in order
   - Run verification after each step
   - Run code review and security review at phase completion
4. Update the plan document status for YOUR phase's steps.
5. Respect the phase's Gate spec: if it says open a sub-PR and
   stop, do that; if it says autonomous, just commit and finish.
6. CRITICAL: git commit ALL changes before completing — uncommitted
   work in an isolated worktree is silently destroyed on cleanup.

Execute the phase as written. If you encounter issues requiring plan
changes, document them and return the issue — do NOT deviate silently
and do NOT bleed into adjacent phases."
```

### Step 3: Honour Review Gates Between Phases

After each phase's implementer completes, consult that phase's `Gate` field:

- **Autonomous** — proceed directly to the next phase (or parallel group) with no user prompt.
- **Any review gate** — pause. Summarize what the phase produced (files changed, commits, sub-PR link if applicable),
  then use AskUserQuestion with options to continue, request changes (spawn a new implementer for that phase), or stop.
  Follow the specific mechanism the plan chose (e.g. wait for a sub-PR to merge, wait for user review-and-approve, etc.).

Never skip a gate the plan declared, and never silently invent one the plan didn't declare.

### Step 4: Final Report

After the last phase completes (and, if applicable, the final PR is raised per the plan's branch strategy), present the
rollup:

```text
Implementation complete for '<topic>'.

Phases completed: [N/M]
Branch strategy: [single PR to main | feature branch with sub-PRs | ...]
Final PR: [url or "none raised — see plan"]
Files changed: [list]
Tests: [pass/fail]
Reviews: [code review status, security review status per phase]
```

If any implementer reported deviations or blockers, present them and ask the user how to proceed.

## Customizing the Pipeline

### Skipping Phases

If partial context already exists:

- **Research exists**: Read the file, skip to Phase 2 (plan)
- **Plan exists**: Read the file, skip to Phase 3 (implement)
- **Only research needed**: Stop after Phase 1

### Adjusting Research Depth

Match research depth to complexity:

| Complexity | Research Subagents | Expected Duration |
| ---------- | ------------------ | ----------------- |
| Simple     | 1 (codebase)       | Quick             |
| Moderate   | 2 (code + web)     | Medium            |
| Complex    | 3-4 (multiple)     | Thorough          |

### Adding Brainstorming

If requirements are unclear, prepend brainstorming:

```text
Skill tool with skill: "brainstorming"
```

Then resume the pipeline at Phase 1 with clarified requirements.

## Orchestrator Rules

The orchestrator MUST stay thin:

- **Do**: Spawn subagents, read artifacts, present summaries, gate approvals
- **Do NOT**: Research code, write plans, implement changes, or read source files beyond the phase artifacts

This ensures the orchestrator's context remains small, leaving maximum context for each subagent.

## Model Selection

Use explicit `model` parameters when spawning subagents:

| Model    | Use For                                | Rationale             |
| -------- | -------------------------------------- | --------------------- |
| `haiku`  | file-finder, quick lookups             | Fast, cost-effective  |
| `sonnet` | research agents, synthesis, code review | Balanced capability  |
| `opus`   | planning, implementation, architecture | Deep reasoning needed |

## Anti-Patterns

| Do Not | Instead |
| ------ | ------- |
| Do research/planning/implementation as orchestrator | Delegate each phase to a subagent |
| Pass findings through conversation context | Write to files, read from files |
| Spawn 5+ research subagents | Keep to 2-4 focused subagents |
| Skip approval gates between phases | Always get explicit user approval |
| Combine dependent research questions | Only parallelize independent questions |
| Spawn one implementer for the whole plan | One implementer per plan phase, scoped to a single clear task |
| Spawn multiple implementers for the same phase | Exactly one implementer per phase, always |
| Parallelize phases by default | Sequential by default; parallel only when the plan marks phases as independent |
| Assume a default gating mode (all-autonomous or all-gated) | Planner specifies gate explicitly per phase; orchestrator refuses to run otherwise |

## Quality Checklist

Before each phase transition:

- [ ] All subagents for current phase completed
- [ ] Phase artifact written to `docs/plans/`
- [ ] Subagent results summary table presented
- [ ] User approved before proceeding to next phase
- [ ] Orchestrator context remains thin (no research/planning content)

Before entering Phase 3:

- [ ] Plan contains an `Execution` block per phase (scope, depends-on, parallel-with, gate)
- [ ] Plan states overall branch/PR strategy
- [ ] Each plan phase is sized for a single implementer's focused context

During Phase 3:

- [ ] Exactly one implementer spawned per phase — never multiple for the same phase
- [ ] Phases run sequentially unless the plan explicitly marks them parallel
- [ ] Every declared gate honoured; no invented gates, no skipped gates

At pipeline completion:

- [ ] All artifacts saved to `docs/plans/`
- [ ] Final results presented to user
