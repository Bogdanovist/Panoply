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
  ├── Record base_ref = HEAD (captured BEFORE Phase 3 begins; used by
  │   the terminal security-gate to review the aggregated diff)
  │
  ├── Phase 3: Spawn ONE implementer per review_group
  │     │     (groups iterate in dependency order; parallel only where
  │     │      the plan marks review_groups as independent; each group's
  │     │      implementer invokes implement-review-gate.sh once per
  │     │      group — 2-pass code review with cap-hit → interactive
  │     │      drop-out; explicit human gates honoured where declared)
  │     └── Output: code changes, test results, sub-PR(s)
  │
  └── Terminal security-gate phase (runs ONCE, after all other groups)
        │     Spawns security-reviewer over `git diff $base_ref..HEAD`
        │     plus the plan path and phase-name list. PASS → invoke
        │     finishing-work. CHANGES → remediation loop via
        │     implement-review-gate.sh --group-id security (2-pass cap).
        │     Cap-hit → AskUserQuestion (remediate / override-logged /
        │     abort).
        └── Output: final PR on security PASS
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

Before spawning subagents, break the feature into independent research questions. Typically 2-4 questions covering:

- **Codebase context**: How does the relevant code work today?
- **External context**: What APIs, libraries, or patterns are involved?
- **Security/performance**: Are there concerns to investigate?
- **Observed behaviour**: What does the system actually do at runtime today — query outputs, log patterns, CLI output?

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
The research question is fully specified — skip Phase 1 questioning.

Invoke the Skill tool with skill: 'researching-codebase' and args:
'[feature area]'. Where the question concerns runtime behaviour,
gather runtime evidence per the skill's runtime-evidence subsection
and tag findings [OBSERVED] or [INFERRED]. Apply the skill's
'Surface Broken Windows' rule — pre-existing issues you uncover get
captured with a [FIX-INLINE] / [FIX-FOLLOWUP] / [FLAG-HUMAN]
disposition AND the evidence behind it. Tag conservatively: default
to [FLAG-HUMAN] when you can't independently verify both that the
thing is broken and that the correct behavior is unambiguous. The
planner will downgrade unsupported [FIX-*] tags, so honest
'don't-know' tags beat optimistic 'looks-broken' tags."

Write findings to docs/plans/YYYY-MM-DD-<topic>-codebase.md. Aim for
≤200 lines; include everything decision-critical, omit exploratory
notes and raw file listings. Not a hard cap."
```

**Web researcher (when external context needed):**

```text
Spawn a subagent with the Agent tool:
  name: "web-researcher"
  model: "sonnet"
  prompt: "Research [specific question about API, library, pattern, or best
practice].

Provide findings with source citations and confidence assessment.
Write your findings to docs/plans/YYYY-MM-DD-<topic>-external.md.
Aim for ≤200 lines; include everything decision-critical, omit
exploratory notes and raw file listings. Not a hard cap."
```

Note: state inspection is NOT a separate subagent — the codebase-researcher above handles it via the runtime-evidence subsection of researching-codebase.

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
   docs/plans/YYYY-MM-DD-<topic>-research.md.
   Aim for ≤200 lines; include everything decision-critical, omit
   exploratory notes and raw file listings. Not a hard cap."
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

Read the research document at docs/plans/YYYY-MM-DD-<topic>-research.md,
then invoke the Skill tool with skill: 'writing-plans' and args:
'<topic>'. Follow the skill's full methodology and write the plan to
docs/plans/YYYY-MM-DD-<topic>-plan.md.

The plan must be self-contained and reference the research document.
Do NOT ask the user questions — the research document is your source
of truth. Every phase must include an Execution block (scope,
depends-on, parallel-with, gate, review_group) per writing-plans §4a,
and the plan must state the overall branch/PR strategy and end with
a terminal security-gate phase."
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

## Phase 3: Implement (One Subagent Per review_group)

After plan approval, work through the plan **one review_group at a time**, spawning exactly ONE implementer per group.
Each implementer gets a fresh context window scoped to that group's work, so its context stays focused and uncluttered.

### Step 0: Record `base_ref` Before Implementation Starts

Immediately after plan approval and BEFORE spawning the first Phase 3 implementer, record the current HEAD as
`base_ref`. This value anchors the aggregated diff consumed by the terminal `security-gate` phase
(`git diff $base_ref..HEAD`). Capture it via a short bash call (e.g. `git rev-parse HEAD`) and hold it in orchestrator
state until the terminal phase runs. Do not re-capture it mid-run.

### Step 1: Read the Plan's Execution Structure

Read the plan file and extract, for each phase, the `Execution` block (scope, depends-on, parallel-with, gate,
`review_group`) plus the overall branch/PR strategy. The orchestrator only reads this structural metadata plus the
phase's own section — not the full content of other phases.

If the plan is missing per-phase `Execution` blocks, or any phase lacks a `review_group` field, or the plan does not end
with a terminal `security-gate` phase, stop and spawn a fresh planner to fix the plan — do not proceed without explicit
gating, dependency info, review-group assignments, and the terminal gate. See `writing-plans` section 4a for the
`review_group` shapes (Solo / Batched sequential / Fan-out + consolidator) and terminal-gate template.

### Step 2: Execute review_groups in Dependency Order

Walk the review_groups respecting `depends on`. **Sequential is the default.** Spawn multiple implementers concurrently
(in a single message with multiple Agent calls) ONLY when the plan explicitly marks groups as `parallel with` each other
AND their dependencies are satisfied.

For each review_group (or parallel group of groups), spawn exactly ONE implementer. See `writing-plans` §4a for the three shapes (Solo / Batched sequential / Fan-out + consolidator) and the implementer behaviour each implies. In all shapes the gate is invoked exactly ONCE over the aggregated diff — never per phase inside a group.

The gate script (`~/.claude/scripts/implement-review-gate.sh`) is the 2-pass implementer→code-reviewer loop. It writes
`.review-verdict[-<group_id>]` and returns:

- `0` (PASS) → group complete, orchestrator advances.
- `42` (EX_REVIEW_UNRESOLVED — CHANGES at cap) → drop to interactive. Surface both rounds of findings verbatim; do NOT
  advance; user decides remediation (fix manually, accept as out-of-scope, amend plan, or abort).
- Any other non-zero → implementer or reviewer crashed; surface the error and stop.

Spawn the implementer like this:

```text
Spawn a subagent with the Agent tool:
  name: "implementer-<group-id>"
  model: "opus"
  isolation: "worktree"
  prompt: "You are implementing ONE review_group: <group-id>.
Your phases within this group: <ordered list of this group's phase
names, interpolated by the orchestrator>.

Read only your group's phase sections plus each phase's Execution
block. Do not read phases assigned to other groups.

Invoke the Skill tool with skill: 'implementing-plans' and args:
'docs/plans/YYYY-MM-DD-<topic>-plan.md'. Execute your phases' steps
in order, running verification after each step. At group completion,
invoke ~/.claude/scripts/implement-review-gate.sh exactly ONCE with
--group-id <group-id>. Commit ALL changes before completing.

The implementing-plans skill carries the EVERGREEN CODE RULE and the
NO BROKEN WINDOWS RULE — follow both. Plan artefacts are scaffolding;
do not cite them in code. For pre-existing issues you encounter
(failing tests on main, apparent dead code, what looks like a bug):
verify it's actually broken (reproduce, check call sites, check git
blame and tests for intent), then **bias toward escalating via
AskUserQuestion** unless the fix is verified, unambiguous, AND
localized to a file already in your planned scope. Two failure modes
both apply: 'noted as pre-existing and left' AND 'looked wrong to me,
swept it up' without verification. When in doubt, escalate — silent
uninvited fixes are worse than asking. Every sweep-up you do make
must appear loudly in the commit message (prefix `sweep:` with
evidence) and the checkpoint summary's 'Sweep-ups' section."
```

### Step 3: Honour Gates Between review_groups

After each group's implementer completes, consult that group's `Gate` field (set per-phase by the planner):

- **Autonomous (review-gate PASS)** — the implementer's in-worktree gate invocation already returned exit 0. Proceed
  directly to the next group (or parallel group set) with no user prompt.
- **Review-gate cap-hit (exit 42)** — the implementer surfaced both rounds of reviewer findings and halted. The
  orchestrator pauses and uses AskUserQuestion with options to remediate (spawn a new implementer for the group with
  the findings piped in), accept as out-of-scope, amend the plan, or abort.
- **Explicit human gate declared by the plan** — pause regardless of gate exit code. Summarize what the group produced
  (files changed, commits, sub-PR link if applicable), then use AskUserQuestion with options to continue, request
  changes (spawn a new implementer for that group), or stop. Follow the specific mechanism the plan chose (e.g. wait
  for a sub-PR to merge, wait for user review-and-approve, etc.).

Never skip a gate the plan declared, and never silently invent one the plan didn't declare.

### Step 4: Terminal `security-gate` Phase (runs ONCE)

After ALL other review_groups complete (including their gates), execute the terminal `security-gate` phase. This is the
only security review in the plan — no group runs security-reviewer on its own.

1. Spawn the `security-reviewer` agent with three inputs: the aggregated diff from `git diff $base_ref..HEAD` (using
   the `base_ref` captured in Step 0), the plan document path, and the ordered list of phase names for scope
   orientation. Do NOT pipe per-phase reviewer summaries — the reviewer works off the unified diff. Spawn with
   explicit `model: "sonnet"` so the agent does not inherit the orchestrator's opus model:

   ```text
   Spawn a subagent with the Agent tool:
     name: "security-reviewer"
     model: "sonnet"
     prompt: "Review the aggregated diff at git diff $base_ref..HEAD for
   security issues. Plan: docs/plans/YYYY-MM-DD-<topic>-plan.md.
   Phases: <ordered phase-name list>. Write the verdict sentinel to
   $REVIEW_SENTINEL per the security-review skill's sentinel contract."
   ```
2. The reviewer writes `.review-verdict-security` per the sentinel contract.
3. Read the sentinel:
   - **`REVIEW_APPROVED`** → security PASS. Proceed to `finishing-work`. The orchestrator
     invokes `finishing-work` via the Skill tool and passes the plan path as the `args`
     string (e.g. `args: 'docs/plans/2026-04-18-<topic>-plan.md'`) — this is the concrete
     mechanism the `finishing-work` skill's Step 5 reads to locate the plan doc.
   - **Findings list (CHANGES)** → spawn a remediation implementer under `implement-review-gate.sh --group-id security
     --reviewer-cmd <spawn security-reviewer>`. The gate owns the 2-pass cap.
4. Gate outcomes for the remediation loop:
   - Exit 0 (PASS) → proceed to `finishing-work`.
   - Exit 42 (cap-hit) → AskUserQuestion with options: "remediate further" / "override (logged)" / "abort".
   - Any other non-zero → surface error and stop.
5. If the plan declares `security_review: human` or `hybrid`, honour the extra human gate per the plan's terminal-phase
   control-flow block (see `writing-plans` terminal `security-gate` template).

### Step 5: Final Report

After the terminal security-gate PASSes and `finishing-work` completes (including any final PR raised per the plan's
branch strategy), present the rollup:

```text
Implementation complete for '<topic>'.

review_groups completed: [N/M]
Branch strategy: [single PR to main | feature branch with sub-PRs | ...]
Final PR: [url or "none raised — see plan"]
Files changed: [list]
Tests: [pass/fail]
Reviews: [per-group code-review verdicts, terminal security-gate verdict]
Verification: none | pending | completed — see plan §Post-Merge Verification
```

Verification handoff lives in `finishing-work`; the orchestrator does not itself gate on
`## Post-Merge Verification`. The `Verification:` value is sourced from `finishing-work`'s
Status Reporting output (see the `finishing-work` skill's Status Reporting section for the
derivation rule: `none` / `pending` / `completed`). The orchestrator's only responsibility
is to transcribe that value into the final report.

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

The orchestrator MUST stay thin. Its job is delegation, artifact reading, and gate decisions — nothing more.

- **Do**: Spawn subagents, read artifacts (research doc, plan doc, `.review-verdict[-<group_id>]` sentinels), present
  summaries, gate approvals, record `base_ref` at plan start, drive the terminal security-gate phase, hand off to
  `finishing-work` on security PASS.
- **Do NOT**: Research code, write plans, implement changes, invoke `code-reviewer` or `security-reviewer` directly
  outside the documented terminal-gate flow, run `implement-review-gate.sh` itself (the per-group implementer does
  that), or read source files beyond the phase artifacts and sentinel files.

This ensures the orchestrator's context remains small, leaving maximum context for each subagent.

## Model Selection

Use explicit `model` parameters when spawning subagents:

| Model    | Use For                                                                   | Rationale             |
| -------- | ------------------------------------------------------------------------- | --------------------- |
| `haiku`  | simple verification (exit-code reads, file-existence checks, pass/fail)   | Fast, cost-effective  |
| `sonnet` | research agents, synthesis, code-reviewers, security-reviewer             | Balanced capability   |
| `opus`   | planner, implementers (code generation, architectural decisions)          | Deep reasoning needed |

Never route architectural decisions to haiku.

## Anti-Patterns

| Do Not | Instead |
| ------ | ------- |
| Do research/planning/implementation as orchestrator | Delegate each phase to a subagent |
| Pass findings through conversation context | Write to files, read from files |
| Spawn 5+ research subagents | Keep to 2-4 focused subagents |
| Skip approval gates between phases | Always get explicit user approval |
| Combine dependent research questions | Only parallelize independent questions |
| Spawn one implementer for the whole plan | One implementer per review_group, scoped to that group's task(s) |
| Spawn multiple implementers for the same review_group | Exactly one implementer per group, always |
| Parallelize groups by default | Sequential by default; parallel only when the plan marks groups as independent |
| Assume a default gating mode (all-autonomous or all-gated) | Planner specifies gate explicitly per phase; orchestrator refuses to run plans missing `review_group` or the terminal `security-gate` phase |
| Invoke `security-reviewer` at the end of each group | Terminal `security-gate` phase runs exactly once over the aggregated `$base_ref..HEAD` diff |
| Invoke `implement-review-gate.sh` from the orchestrator | Per-group implementer invokes the gate; orchestrator only reads the sentinel / gate exit code |

## Quality Checklist

Before each phase transition:

- [ ] All subagents for current phase completed
- [ ] Phase artifact written to `docs/plans/`
- [ ] Subagent results summary table presented
- [ ] User approved before proceeding to next phase
- [ ] Orchestrator context remains thin (no research/planning content)

Before entering Phase 3:

- [ ] Plan contains an `Execution` block per phase (scope, depends-on, parallel-with, gate, `review_group`)
- [ ] Every phase has a `review_group` ID; orchestrator refuses to run otherwise
- [ ] Plan ends with a terminal `security-gate` phase (`review_group: security`)
- [ ] Plan states overall branch/PR strategy
- [ ] Each plan phase is sized for a single implementer's focused context
- [ ] `base_ref = HEAD` recorded BEFORE first implementer spawn

During Phase 3:

- [ ] Exactly one implementer spawned per review_group — never multiple for the same group
- [ ] review_groups run sequentially unless the plan explicitly marks them parallel
- [ ] Every declared gate honoured; no invented gates, no skipped gates
- [ ] Per-group implementer invokes `implement-review-gate.sh` exactly once; orchestrator does not invoke it
- [ ] No security review runs per group — security-reviewer is reserved for the terminal phase

At pipeline completion:

- [ ] Terminal `security-gate` ran exactly once over `$base_ref..HEAD`
- [ ] `finishing-work` invoked only on security PASS (or explicit user override on cap-hit)
- [ ] All artifacts saved to `docs/plans/`
- [ ] Final results presented to user
