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
  ├── Phase 0: Git preflight (rpi-preflight.sh)
  │     └── Ensures clean tree, syncs base, lands on feat/<slug>.
  │         Records resolved branch name for the rest of the run.
  │
  ├── Phase 1: Spawn research subagents (parallel within Phase 1)
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
  │           (must include `## Implementation State` section)
  │
  ├── [APPROVAL GATE: User approves plan]
  │
  ├── Phase 3: Iterate review_groups SEQUENTIALLY in dependency order
  │     │     (one implementer per group, in the orchestrator's CWD on
  │     │      the Phase 0 branch — no `isolation: "worktree"`. base_ref
  │     │      and per-group status persist in the plan's Implementation
  │     │      State section so a context clear can resume cleanly. Each
  │     │      group's implementer invokes implement-review-gate.sh once
  │     │      per group — 2-pass code review with cap-hit → interactive
  │     │      drop-out; explicit human gates honoured where declared.)
  │     └── Output: commits on the feature branch, test results
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
prior phases and writes its own artifacts for the next phase. Durable Phase 3 state (branch, base_ref, per-group
status) lives in the plan document's `## Implementation State` section so the orchestrator's context can be cleared
between groups.

**Across-group parallelism is disabled by design.** review_groups iterate sequentially regardless of `parallel-with`
annotations. The orchestrator does not spawn implementers concurrently, and implementers do not run in worktrees. This
trade is deliberate: each group's commits land directly on the feature branch, so `git diff $base_ref..HEAD` is always
correct, no orphaned worktrees accumulate, and resumption after a context clear needs only `(branch, base_ref, group
statuses)` — all of which live in the plan doc.

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

## Phase 0: Git Preflight

Before Phase 1 spawns any subagent, the orchestrator runs `~/.claude/scripts/rpi-preflight.sh` to land on a clean
feature branch off an up-to-date base. **The user is not expected to manage branches by hand.** The script never asks
questions itself; the orchestrator interprets its exit codes and AskUserQuestion-prompts the user only when the
situation is genuinely ambiguous.

Run the preflight from the orchestrator's CWD:

```bash
~/.claude/scripts/rpi-preflight.sh --topic '<topic string>'
```

Capture stdout and the exit code. Dispatch on the exit code:

| Exit | Meaning | Orchestrator action |
| ---- | ------- | ------------------- |
| `0`  | Ready. Stdout = resolved branch name. | Record this branch (used in Phase 3 Step 0 and written to the plan's Implementation State). Proceed to Phase 1. |
| `10` | Working tree dirty. | AskUserQuestion: **stash and continue** (`git stash push -u -m "rpi-preflight"`) / **commit changes first** (pause; user finishes; re-run preflight) / **abort**. |
| `11` | Base branch diverged from origin (cannot fast-forward). | AskUserQuestion: **rebase onto origin** (`git fetch origin && git rebase origin/<base>`) / **hard-reset to origin** (`git reset --hard origin/<base>` — destructive, warn) / **abort**. After remediation, re-run preflight. |
| `12` | On a non-base branch. Stdout = current branch name. | AskUserQuestion: **continue on `<current>`** (use this branch as-is — record it as the working branch and proceed to Phase 1) / **switch to base and create fresh `feat/<slug>`** (`git checkout <base>` then re-run preflight) / **abort**. |
| `13` | Fatal (not in a git repo, missing argument, fetch failed, etc.). Stderr explains. | Surface stderr to the user and stop — this is not the orchestrator's to fix silently. |

> **Panoply mode is automatic.** When the orchestrator's CWD is `~/src/Panoply/`, the preflight stays on `main`, skips
> branch creation, and returns `main` as the working branch (per Panoply convention — direct-to-main commits, no PRs).
> No code path in RPI needs to special-case Panoply beyond what the script already does.

After the preflight returns 0, hold the resolved branch name in working notes. It will be written to the plan's
`## Implementation State` section once the plan exists (Phase 3 Step 0b). If the user later context-clears mid-run,
the plan doc is the canonical record of which branch the run lives on.

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
- "More research needed" — spawn additional subagents (refinement-mode; see below)
- "Stop here" — end with research document

### Refinement-mode research spawn (when the user requests changes)

When the user picks "More research needed" with feedback about the existing research document, do **not** regenerate
the document from scratch — that wastes tokens and risks losing already-validated content. Spawn a subagent that reads
the existing research file and produces a targeted edit instead:

```text
Spawn a subagent with the Agent tool:
  name: "research-refiner"
  model: "sonnet"
  prompt: "Refine the existing research document at
docs/plans/YYYY-MM-DD-<topic>-research.md.

User feedback: <verbatim user feedback>

Read the existing document and apply the smallest set of targeted edits
that address the feedback. Do NOT rewrite untouched sections. Do NOT
re-do exploration that the document already covers. Use the Edit tool
to make in-place changes. If the feedback requires investigating new
ground, scope the new exploration narrowly to what the feedback asks
for, then merge the findings into the existing structure rather than
appending a new section unless the feedback warrants one.

Aim to keep the document under 200 lines unless the feedback requires
expansion. Preserve [OBSERVED] / [INFERRED] tags and pre-existing-issues
dispositions on findings you don't touch."
```

After the refiner completes, re-present the summary table and re-gate. If the user instead asks for net-new research
ground (e.g. "we missed the security angle entirely"), spawn an additional research subagent for that question and
then re-run the synthesizer over the updated set of source files (the synthesizer's job is exactly this kind of
incremental consolidation).

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
- "Request changes" — describe what to modify, spawn refiner (see below)
- "Stop here" — end with plan document

**Do not skip this approval gate.** The user must explicitly approve the plan before implementation begins.

### Refinement-mode plan spawn (when the user requests changes)

When the user picks "Request changes", spawn a planner subagent that **edits the existing plan in place** rather than
regenerating it. Minor feedback ("add a note to Phase 2 about X") must not trigger a full rewrite — that wastes
tokens and risks unintended drift in already-validated sections.

```text
Spawn a subagent with the Agent tool:
  name: "plan-refiner"
  model: "opus"
  prompt: "Refine the existing plan at docs/plans/YYYY-MM-DD-<topic>-plan.md.

User feedback: <verbatim user feedback>

Read the existing plan and apply the smallest set of targeted edits that
address the feedback. Use the Edit tool to make in-place changes. Do
NOT regenerate sections the feedback does not touch. Do NOT change
review_group assignments or the terminal security-gate phase unless
the feedback explicitly asks for it. Do NOT alter the
`## Implementation State` section (it is machine-managed by the
orchestrator and implementers).

If the feedback requires structural changes (new phases, changed group
shapes), make them surgically and call them out at the top of your
response so the orchestrator can flag them at re-gate. Otherwise just
apply the edits and finish."
```

After the refiner completes, re-present the summary and re-gate. Treat the refined plan as a fresh document for
approval purposes — the user must approve again before Phase 3 begins.

## Phase 3: Implement (One Subagent Per review_group, Sequentially)

After plan approval, work through the plan **one review_group at a time, in dependency order**, spawning exactly ONE
implementer per group. Each implementer gets a fresh context window scoped to that group's work, runs in the
orchestrator's CWD on the Phase 0 branch, and commits its work before completing. Across-group parallelism is
disabled — the orchestrator does not spawn implementers concurrently.

### Step 0a: Detect Resume vs. Fresh Run

Before doing anything else in Phase 3, read the plan's `## Implementation State` section. Two cases:

1. **Fresh run** — `branch` and `base_ref` are placeholders, all groups are `pending`. Continue to Step 0b.
2. **Resume** — `base_ref` is a real SHA and at least one group is `complete` (or `cap-hit`). The orchestrator's
   context was cleared mid-Phase-3 and we are picking up where the prior orchestrator left off. Use AskUserQuestion:

   - **"Resume from group `<first-non-complete-id>`"** — verify the orchestrator's CWD is on the recorded `branch`
     (if not, `git checkout <branch>`; error out if the branch doesn't exist). Skip Step 0b. Jump to Step 2 with the
     remaining groups.
   - **"Start Phase 3 fresh"** — reset `## Implementation State` (all groups → `pending`, clear `base_ref`). Continue
     to Step 0b. The orchestrator does NOT roll back commits — those belong to the user's branch. Starting fresh just
     means re-running groups; the implementer will see the existing commits as part of the prior diff.
   - **"View state and decide"** — read out the section, then re-prompt.

   If the recorded group is in `cap-hit`, the only safe options are **"Surface cap-hit findings"** (read
   `.review-verdict-<group-id>` and present them; AskUserQuestion: remediate / accept / abort) or **"Start Phase 3
   fresh"**. Do NOT silently re-invoke `implement-review-gate.sh` for a `cap-hit` group — the gate script deletes the
   sentinel before pass 1, which would lose the round-2 findings the user needs to make a decision.

### Step 0b: Record `base_ref` and Initialize State (fresh runs only)

Capture the current HEAD as `base_ref` and write it, along with the Phase 0 branch name, into the plan's
`## Implementation State` section. This single section is now the durable record of Phase 3 progress; do not hold
`base_ref` in orchestrator memory.

```bash
BASE_REF="$(git rev-parse HEAD)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
```

Edit the plan to set:

```markdown
- **branch**: `<BRANCH>`
- **base_ref**: `<BASE_REF>`
- **groups**:
  - `<group-id-1>`: pending
  - `<group-id-2>`: pending
  - …
  - `security`: pending
```

`base_ref` anchors the aggregated diff consumed by the terminal `security-gate` phase (`git diff $base_ref..HEAD`). Do
not re-capture it mid-run. The terminal phase reads it back from this section.

### Step 1: Read the Plan's Execution Structure

Read the plan file and extract, for each phase, the `Execution` block (scope, depends-on, parallel-with, gate,
`review_group`) plus the overall branch/PR strategy and the `## Implementation State` section. The orchestrator only
reads this structural metadata plus the phase's own section — not the full content of other phases.

If the plan is missing per-phase `Execution` blocks, or any phase lacks a `review_group` field, or the plan does not
end with a terminal `security-gate` phase, or the plan has no `## Implementation State` section, stop and spawn a
plan-refiner (see Phase 2 refinement template) to fix the plan — do not proceed without explicit gating, dependency
info, review-group assignments, the terminal gate, and the state section. See `writing-plans` section 4a for the
`review_group` shapes (Solo / Batched sequential / Fan-out + consolidator) and terminal-gate template.

### Step 2: Execute review_groups in Dependency Order

Walk the review_groups respecting `depends on`, **strictly sequentially**. Even when the plan annotates groups as
`parallel-with` each other, the orchestrator runs them one at a time. The annotation is documentation for human
reviewers; execution does not honour it. (Within a single group, the planner's Solo / Batched sequential / Fan-out +
consolidator shape choice still applies — that is shape-of-one-implementer's-work, not cross-group parallelism.)

For each review_group, spawn exactly ONE implementer. See `writing-plans` §4a for the three shapes and the implementer
behaviour each implies. In all shapes the gate is invoked exactly ONCE over the aggregated diff — never per phase
inside a group.

The gate script (`~/.claude/scripts/implement-review-gate.sh`) is the 2-pass implementer→code-reviewer loop. It writes
`.review-verdict[-<group_id>]` and returns:

- `0` (PASS) → group complete, orchestrator advances.
- `42` (EX_REVIEW_UNRESOLVED — CHANGES at cap) → drop to interactive. Surface both rounds of findings verbatim; do NOT
  advance; user decides remediation (fix manually, accept as out-of-scope, amend plan, or abort).
- Any other non-zero → implementer or reviewer crashed; surface the error and stop.

Spawn the implementer like this — **without** `isolation: "worktree"`:

```text
Spawn a subagent with the Agent tool:
  name: "implementer-<group-id>"
  model: "opus"
  prompt: "You are implementing ONE review_group: <group-id>.
Your phases within this group: <ordered list of this group's phase
names, interpolated by the orchestrator>.

You run in the orchestrator's CWD on the feature branch already
prepared by Phase 0 — do NOT create a worktree, do NOT switch
branches. All commits land on the current branch.

Read only your group's phase sections plus each phase's Execution
block. Do not read phases assigned to other groups.

Invoke the Skill tool with skill: 'implementing-plans' and args:
'docs/plans/YYYY-MM-DD-<topic>-plan.md'. The implementing-plans
skill is RPI-aware: it skips its own worktree-isolation prompt
and updates the plan's ## Implementation State section after the
gate completes (mark this group `complete <commit-sha>` on PASS,
`cap-hit` on exit 42).

Execute your phases' steps in order, running verification after each
step. At group completion, invoke
~/.claude/scripts/implement-review-gate.sh exactly ONCE with
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

After the implementer returns, read the plan's `## Implementation State` section back to confirm the group's status
was updated (the implementer is responsible for the update; the orchestrator verifies). If the implementer crashed
without updating, mark the group `cap-hit` (or surface the crash) and pause — do not advance.

### Step 3: Honour Gates Between review_groups

After each group's implementer completes, consult that group's `Gate` field (set per-phase by the planner):

- **Autonomous (review-gate PASS)** — the implementer's gate invocation already returned exit 0 and the plan's
  Implementation State entry for this group reads `complete (commit <sha>)`. Proceed directly to the next group with
  no user prompt.
- **Review-gate cap-hit (exit 42)** — the implementer surfaced both rounds of reviewer findings, marked the group
  `cap-hit` in Implementation State, and halted. The orchestrator pauses and uses AskUserQuestion with options to
  remediate (spawn a new implementer for the group with the findings piped in — the new implementer will reset the
  group's status to `in-progress` before re-invoking the gate), accept as out-of-scope, amend the plan, or abort.
- **Explicit human gate declared by the plan** — pause regardless of gate exit code. Summarize what the group produced
  (files changed, commits), then use AskUserQuestion with options to continue, request changes (spawn a new
  implementer for that group), or stop. Follow the specific mechanism the plan chose.

Never skip a gate the plan declared, and never silently invent one the plan didn't declare.

### Step 4: Terminal `security-gate` Phase (runs ONCE)

After ALL other review_groups complete (including their gates), execute the terminal `security-gate` phase. This is the
only security review in the plan — no group runs security-reviewer on its own.

1. Read `base_ref` from the plan's `## Implementation State` section (it was written in Step 0b and persists across
   context clears). Spawn the `security-reviewer` agent with three inputs: the aggregated diff from
   `git diff $base_ref..HEAD`, the plan document path, and the ordered list of phase names for scope orientation. Do
   NOT pipe per-phase reviewer summaries — the reviewer works off the unified diff. Spawn with explicit
   `model: "sonnet"` so the agent does not inherit the orchestrator's opus model:

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
Branch strategy: [single PR to main | feature branch | direct commits to main (Panoply mode)]
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
- **Plan exists** (no Phase 3 progress): Read the file, run Phase 0 preflight if not already on the recorded branch,
  then enter Phase 3 at Step 0a (which detects fresh vs. resume from `## Implementation State`)
- **Plan exists with partial Phase 3 progress** (some groups marked `complete` or `cap-hit`): Phase 0 preflight is
  skipped (the run already established its branch); enter Phase 3 at Step 0a — the resume branch handles it
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

- **Do**: Run `rpi-preflight.sh` at Phase 0 and dispatch its exit codes; spawn subagents; read artifacts (research doc,
  plan doc, `.review-verdict[-<group_id>]` sentinels, the plan's `## Implementation State` section); present
  summaries; gate approvals; write `branch` and `base_ref` to Implementation State at Phase 3 Step 0b; drive the
  terminal security-gate phase; hand off to `finishing-work` on security PASS.
- **Do NOT**: Research code, write plans, implement changes, run git commands beyond the preflight-dispatch path and
  reading `git rev-parse HEAD` for `base_ref`, invoke `code-reviewer` or `security-reviewer` directly outside the
  documented terminal-gate flow, run `implement-review-gate.sh` itself (the per-group implementer does that), or read
  source files beyond the phase artifacts and sentinel files. **Never** use `isolation: "worktree"` when spawning an
  implementer — that pattern was removed because it caused base_ref drift and orphaned worktrees.

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
| Spawn implementers in parallel across groups | Always sequential — `parallel-with` annotations in plans are documentation only |
| Use `isolation: "worktree"` when spawning implementers | Spawn in the orchestrator's CWD on the Phase 0 branch; commits flow on a single linear branch |
| Hold `base_ref` in orchestrator memory | Write `base_ref` to the plan's `## Implementation State` section at Phase 3 Step 0b; read it back from there at the terminal gate |
| Re-invoke `implement-review-gate.sh` for a group already marked `cap-hit` | Read the existing `.review-verdict-<group-id>` sentinel and AskUserQuestion; the gate would delete the sentinel and lose the findings |
| Skip git hygiene because the user "knows what they're doing" | Always run `rpi-preflight.sh` at Phase 0; the user explicitly should NOT be relied on for branch management |
| Assume a default gating mode (all-autonomous or all-gated) | Planner specifies gate explicitly per phase; orchestrator refuses to run plans missing `review_group` or the terminal `security-gate` phase |
| Invoke `security-reviewer` at the end of each group | Terminal `security-gate` phase runs exactly once over the aggregated `$base_ref..HEAD` diff |
| Invoke `implement-review-gate.sh` from the orchestrator | Per-group implementer invokes the gate; orchestrator only reads the sentinel / gate exit code |

## Quality Checklist

Before Phase 1:

- [ ] Phase 0 preflight (`rpi-preflight.sh`) ran and the orchestrator dispatched its exit code; the resolved branch
  name is held in working notes for Step 0b
- [ ] No `isolation: "worktree"` arguments anywhere in the orchestrator's spawn templates

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
- [ ] Plan contains a `## Implementation State` section with one entry per `review_group` (plus `security`)
- [ ] Each plan phase is sized for a single implementer's focused context

At Phase 3 entry (Step 0a):

- [ ] Implementation State read; resume-vs-fresh decision made (with AskUserQuestion if there is prior progress)
- [ ] On fresh: `branch` and `base_ref = HEAD` written to Implementation State BEFORE first implementer spawn
- [ ] On resume: orchestrator's CWD verified to be on the recorded `branch`

During Phase 3:

- [ ] Exactly one implementer spawned per review_group — never multiple for the same group
- [ ] review_groups run **strictly sequentially**; `parallel-with` annotations are documentation only
- [ ] Every declared gate honoured; no invented gates, no skipped gates
- [ ] Per-group implementer invokes `implement-review-gate.sh` exactly once; orchestrator does not invoke it
- [ ] After each group's PASS, the plan's Implementation State entry reads `complete (commit <sha>)` (orchestrator
  verifies; the implementer is responsible for writing it)
- [ ] No security review runs per group — security-reviewer is reserved for the terminal phase
- [ ] Cap-hit groups are NOT re-invoked through the gate; orchestrator surfaces the existing sentinel

At pipeline completion:

- [ ] Terminal `security-gate` ran exactly once over `$base_ref..HEAD` (with `base_ref` read from Implementation State)
- [ ] `finishing-work` invoked only on security PASS (or explicit user override on cap-hit)
- [ ] All artifacts saved to `docs/plans/`
- [ ] Final results presented to user
