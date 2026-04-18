---
name: writing-plans
description: Transform research findings into actionable implementation plans with granular steps, verification criteria, and stakes-based enforcement. Plans serve as contracts between human and AI.
argument-hint: feature or change to plan
---

# Planning Phase

Create an implementation plan for: **$ARGUMENTS**

## Purpose

Planning transforms research findings into actionable implementation strategy. A good plan enables disciplined
execution by breaking work into granular tasks with clear verification criteria. Plans serve as contracts between human
and AI, ensuring alignment before code is written.

## Process

### 1. Check for Research

Look for existing research at: `docs/plans/YYYY-MM-DD-<topic>-research.md`

(Search for files matching `*-<topic>-research.md` pattern)

If research exists:

- Read and reference the research findings
- Build the plan on documented context
- Link to research in plan document

If no research exists:

- Ask if research should be conducted first
- For high-stakes tasks, recommend research first
- For low-stakes tasks, use the **file-finder** agent to locate relevant files:

```text
Task tool with subagent_type: "file-finder"
Prompt: "Find files related to [task]. Goal: [what will be implemented]"
```

### 2. Define Success Criteria

Before planning tasks, establish what "done" looks like:

- Functional requirements (what it does)
- Non-functional requirements (performance, security)
- Acceptance criteria (how to verify)

Use AskUserQuestion to clarify requirements if needed.

**Verification beyond CI** — if the brainstorming design doc declared post-merge verification (or if brainstorming was
skipped, ask now): capture the scripts, access requirements, repos involved, and trigger point in the
`## Post-Merge Verification` section of the plan template below. Default answer "CI is enough" is valid and common;
state it explicitly rather than leaving the section unfilled.

### 3. Classify Stakes

Determine implementation risk level:

| Stakes     | Characteristics                              | Planning Rigor |
| ---------- | -------------------------------------------- | -------------- |
| **Low**    | Isolated change, easy rollback, low impact   | Brief plan     |
| **Medium** | Multiple files, moderate impact, testable    | Standard plan  |
| **High**   | Architectural, hard to rollback, wide impact | Detailed plan  |

Document the classification and rationale in the plan.

### 4. Break Down Tasks

Decompose work into granular, verifiable steps.

**Identify target files:**

Use file paths from research document, or if unavailable, use the **file-finder** agent to locate files for each task
area:

```text
Task tool with subagent_type: "file-finder"
Prompt: "Find files for [specific task]. Looking for [what to modify]"
```

**For each task include:**

- **Description**: Clear statement of what to do
- **Files**: Target files with line references when known
- **Action**: Specific changes to make
- **Verify**: How to confirm the step is complete
- **Complexity**: Small / Medium / Large

Prefer small tasks (2-5 minute verification time).

Group related tasks into phases with checkpoint verifications.

**Identify parallel step groups (when applicable):**

When a plan contains steps that are genuinely independent, mark them as a parallel group so the implementer can
execute them concurrently. Steps are independent when they:

- Create new files that don't import from each other
- Modify separate modules with no shared interfaces
- Add tests for different, unrelated functionality

Steps are NOT independent when:

- Step B imports or calls code created in Step A
- Both steps modify the same file
- Step B's tests exercise code from Step A

Only mark groups as parallel when independence is clear. When in doubt, keep steps sequential — incorrect
parallelization causes merge conflicts and integration failures. Plans with fewer than 4 steps rarely benefit from
parallelization.

**Research implementation approaches (when needed):**

For quick lookups (checking a library's API, reading a specific doc page), use WebFetch directly. Reserve the
web-researcher agent for multi-source investigation.

If the plan involves unfamiliar libraries, APIs, or patterns, use the **web-researcher** agent to inform task design:

```text
Task tool with subagent_type: "web-researcher"
Prompt: "[specific question about implementation approach, library usage, or best practice]"
```

**Plan test cases for each task:**

Every task that changes code must enumerate its test cases upfront. This ensures implementation follows TDD
discipline — tests are written before production code, not as an afterthought.

For each code-changing task, list:

- **Automated tests** (unit, integration): Specific inputs, expected outputs, and edge cases. These become the RED step
  during implementation.
- **Manual verification** (UI, CLI, deploy): Steps a human performs to confirm behavior. Use when automated testing is
  impractical.

Structure task steps so the test is the first sub-step and production code follows. This maps directly to the
Red-Green-Refactor cycle enforced by the `test-driven-development` skill during implementation.

> **Boundary**: Plans enumerate *what* to test (cases, inputs, expected
> outputs). The TDD skill covers *how* to execute (Red-Green-Refactor cycle,
> test structure, assertion patterns).

Include edge cases and boundary conditions:

- Empty/null inputs
- Boundary values (0, max, off-by-one)
- Error paths (invalid input, network failure, permission denied)
- Concurrency or ordering concerns when relevant

#### Handling `[INFERRED]` findings from research

If the research document tags a finding `[INFERRED]` (read off source
code without runtime confirmation) and an implementation step depends
on that finding being true, insert a verification step immediately
before the dependent step. The verification step runs code, queries
data, or reads logs to confirm the inferred claim. Findings tagged
`[OBSERVED]` are already backed by runtime evidence and do not need a
verification step.

Concrete forms the verification step can take, by domain:

- **Data pipelines**: query the relevant table or asset, inspect
  schema, sample rows, compare actual shape against the inferred
  shape.
- **Production services**: hit the relevant endpoint or tail logs for
  a representative request; confirm the inferred behaviour appears in
  the output.
- **CLI / local tools**: run the binary with a representative input;
  capture stdout/stderr and the exit code; compare against the
  inferred behaviour.

If verification contradicts the inferred claim, stop and return to
research — do not patch over a broken assumption in the plan.

#### Good Task Examples

```markdown
#### Step 1.1: Test email validation (RED)

- **Files**: `src/utils/__tests__/validation.test.ts`
- **Action**: Write failing tests for validateEmail()
- **Test cases**:
  - `"user@example.com"` → valid
  - `"user@sub.example.com"` → valid
  - `""` → invalid (empty string)
  - `"no-at-sign"` → invalid (missing @)
  - `"user@"` → invalid (missing domain)
- **Verify**: Tests exist and fail (no implementation yet)
- **Complexity**: Small

#### Step 1.2: Implement email validation (GREEN)

- **Files**: `src/utils/validation.ts`
- **Action**: Create validateEmail() using regex pattern from validatePhone()
- **Verify**: All tests from Step 1.1 pass
- **Complexity**: Small
```

```markdown
#### Step 2.1: Test user creation endpoint (RED)

- **Files**: `src/routes/__tests__/users.test.ts`
- **Action**: Write failing integration tests for email in user creation
- **Test cases**:
  - POST /users with valid email → 201, email in response body
  - POST /users with invalid email → 400, error message
  - POST /users without email → 400 (if required) or 201 (if optional)
- **Verify**: Tests exist and fail
- **Complexity**: Small

#### Step 2.2: Update API endpoint (GREEN)

- **Files**: `src/routes/users.ts:45-60`
- **Action**: Add email field to user creation endpoint with validation
- **Verify**: All tests from Step 2.1 pass
- **Complexity**: Small
```

```markdown
#### Step 3.1: Verify dashboard renders new widget

- **Files**: N/A (manual verification)
- **Action**: Manual verification of dashboard widget
- **Manual test cases**:
  - Load dashboard → widget appears in correct position
  - Resize browser to mobile width → widget reflows correctly
  - Click widget action button → expected modal opens
- **Verify**: All manual checks pass in browser
- **Complexity**: Small
```

#### Bad Task Examples

```markdown
#### Step 1: Implement feature

- **Action**: Add the new feature
- **Complexity**: Large
```

**Problem**: Too vague, no verification, no file references

```markdown
#### Step 1: Refactor authentication system

- **Action**: Update all auth code to use new pattern
- **Complexity**: Large
```

**Problem**: Too large, should be broken into multiple phases

```markdown
#### Step 1: Add validation function

- **Files**: `src/utils/validation.ts`
- **Action**: Create validateEmail() with unit tests
- **Verify**: Tests pass
- **Complexity**: Small
```

**Problem**: No test cases enumerated, test and implementation combined into one step. Without explicit test cases, the
implementer writes tests after the code — losing TDD discipline

### 4a. Assign Review Groups

Every phase's Execution block MUST carry a `review_group: <id>` field. The planner (not the orchestrator or the
implementer) decides how phases cluster into review groups, because the clustering decision depends on context budget
and semantic coupling — information the planner has but runtime code flow does not.

The review loop requires a **single author for the diff under review**. That constraint drives the three permitted
shapes:

| Shape | When to use | Who owns the review loop |
| ----- | ----------- | ------------------------ |
| **Solo** — 1 phase = 1 group | Phase is meaty (estimated implementer context 50–80%) | That phase's implementer |
| **Batched sequential** — N small phases, 1 group | Each phase trivial; combined estimated context <50% and phases share a concern | A single implementer does all N phases, then invokes the gate once |
| **Fan-out + consolidator** — parallel phases, 1 group | Two+ genuinely independent streams, each comfortably under budget | A consolidator implementer owns the aggregated diff and invokes the gate once |

**Sizing decision rules (apply per group):**

- Estimated implementer context <50% **and** phases share a concern → **Batched sequential**
- Estimated implementer context 50–80% → **Solo**
- Two+ independent streams, each comfortably under budget → **Fan-out + consolidator**
- If a single phase alone is already near or above 80% of context budget, it is a sign the phase itself is too large —
  split the phase before assigning a group.

**Anti-pattern:** do NOT split groups to "save reviewer compute". Reviewer cost is bounded by diff size, not phase
count. Splitting a coherent diff across multiple groups costs more review time, not less, because each reviewer run
re-reads shared context.

**When the shape choice is non-obvious** (e.g., two phases that look related but could go Solo+Solo or Batched), note
the decision and its rationale inline in the Execution block so reviewers of the plan can audit it.

#### Terminal `security-gate` phase (always append)

Every plan MUST end with a terminal `security-gate` phase. This phase replaces per-phase security review: one
reviewer run at end-of-plan over the aggregated diff. Its Execution block requires these fields:

- `depends_on: [<all prior review_group ids>]`
- `review_group: security`
- `security_review: automated | human | hybrid` — default `automated`; escalate to `hybrid` for high-stakes plans
  (auth, data, architectural change, anything touching production credentials or user-visible privacy surfaces).

The orchestrator runs the terminal gate by invoking `security-reviewer` first (inverting the usual order — reviewer
before implementer); only on CHANGES does it spawn a remediation implementer, subject to the same 2-pass cap as the
per-phase gate. Plan authors do not encode that control flow — it lives in `research-plan-implement` — but the
terminal phase's presence and fields are the planner's responsibility.

**Terminal-phase control-flow contract** (planner copies this verbatim into the terminal phase's Execution block so
readers of the plan understand what runs without needing to cross-reference the orchestrator):

1. Orchestrator records `base_ref = HEAD` at plan start, then runs prior groups in dependency order.
2. After the last prior group, orchestrator invokes `security-reviewer` once with inputs:
   `git diff $base_ref..HEAD`, the plan document path, and the ordered list of prior phase names.
   **Do NOT pipe per-phase reviewer summaries** — the aggregated diff is the source of truth.
3. Reviewer writes `.review-verdict-security` per the sentinel contract (`REVIEW_APPROVED` on PASS, bulleted findings
   on CHANGES).
4. **On PASS** → orchestrator proceeds to `finishing-work` (no implementer is spawned for this phase).
5. **On CHANGES** → orchestrator spawns a remediation implementer and re-enters the gate via
   `implement-review-gate.sh --group-id security` (reviewer-cmd = security-reviewer). The 2-pass cap applies.
6. **On cap-hit (exit 42)** → orchestrator surfaces both rounds of findings and triggers `AskUserQuestion` with
   options: **remediate** (interactive human-in-the-loop), **override** (logged and proceeds to `finishing-work`),
   **abort** (stop; no `finishing-work`).
7. `security_review: human` plans skip the automated reviewer entirely and go straight to the `AskUserQuestion`
   handoff with the aggregated diff. `security_review: hybrid` runs the automated reviewer first, then ALWAYS
   triggers the `AskUserQuestion` handoff regardless of PASS/CHANGES outcome.

Planner default is `automated`; escalate to `hybrid` for any plan touching auth, session, data access, cryptographic
material, production credentials, or user-visible privacy surfaces. Reserve `human` for changes where the diff is
inherently non-reviewable by a language model (e.g. large binary asset updates).

### 5. Document Risks

Identify what could go wrong:

- Breaking changes to existing functionality
- Performance implications
- Security considerations
- Dependencies that might fail

For external dependencies or security concerns, use the **web-researcher** agent to investigate known issues:

```text
Task tool with subagent_type: "web-researcher"
Prompt: "Known issues, security vulnerabilities, or breaking changes in [library/API version]"
```

Include rollback strategy for high-stakes changes.

### 6. Write Plan Document

Create plan at: `docs/plans/YYYY-MM-DD-<topic>-plan.md`

(Use today's date in YYYY-MM-DD format)

Use this structure:

```markdown
# Plan: $ARGUMENTS (YYYY-MM-DD)

## Summary

[One paragraph describing what will be implemented]

## Stakes Classification

**Level**: Low | Medium | High
**Rationale**: [Why this classification]

## Context

**Research**: [Link to research document if exists]
**Affected Areas**: [Components, services, files]

## Success Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Implementation Steps

### Phase 1: [Phase Name]

**Execution**

- **Scope:** [One-line summary of what this phase accomplishes]
- **Depends on:** [prior review_group ids, or `none`]
- **Parallel with:** [other review_group ids, or `none`]
- **review_group:** `<id>` *(Solo / Batched sequential / Fan-out + consolidator — note shape if non-obvious)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 1.1: [Task Description]

- **Files**: `path/to/file.ts:lines`
- **Action**: [What to do]
- **Verify**: [How to confirm done]
- **Complexity**: Small

#### Step 1.2: [Task Description]

- **Files**: `path/to/file.ts:lines`
- **Action**: [What to do]
- **Verify**: [How to confirm done]
- **Complexity**: Small

### Phase 2: [Phase Name] *(parallel with Phase 3)*

**Execution**

- **Scope:** [One-line summary]
- **Depends on:** [prior review_group ids]
- **Parallel with:** Phase 3
- **review_group:** `<id>`
- **Gate:** automated review-gate

[When phases or steps are independent, mark them with *(parallel with Phase N)* so the implementer can execute them
concurrently. Omit this annotation for sequential phases.]

[Continue pattern...]

### Phase N (terminal): security-gate

**Execution**

- **Scope:** Plan-level security review over the aggregated diff (`git diff $base_ref..HEAD`)
- **Depends on:** [all prior review_group ids]
- **Parallel with:** none (terminal)
- **review_group:** `security`
- **security_review:** `automated` *(or `human` / `hybrid` for high-stakes plans — auth / data / architectural)*
- **Gate:** automated review-gate (reviewer runs first; remediation implementer spawns only on CHANGES; 2-pass cap
  with interactive drop-out)

**Reviewer inputs** (orchestrator-supplied; do NOT pipe per-phase reviewer summaries):

1. `git diff $base_ref..HEAD` — aggregated diff; `$base_ref` = HEAD recorded at plan start.
2. Plan document path (this file).
3. Ordered list of prior phase names for scope orientation.

**Control flow:**

- Reviewer writes `.review-verdict-security` per the sentinel contract.
- **PASS** → proceed to `finishing-work`.
- **CHANGES** → spawn remediation implementer; re-enter via `implement-review-gate.sh --group-id security`.
- **Cap-hit (exit 42)** → `AskUserQuestion`: remediate / override (logged) / abort.

## Test Strategy

### Automated Tests

| Test Case                    | Type        | Input       | Expected Output |
| ---------------------------- | ----------- | ----------- | --------------- |
| [Descriptive test name]      | Unit        | [Input]     | [Output]        |
| [Descriptive test name]      | Integration | [Input]     | [Output]        |

### Manual Verification

- [ ] [Manual check description and steps]
- [ ] [Manual check description and steps]

## Post-Merge Verification

**Required**: yes | no   *(if no, leave remaining fields blank or delete)*
**Trigger point**: [e.g. "after PR merges to main", "after `terraform apply` completes in staging", "after downstream
repo's CI passes on the consuming change"]
**Repos involved**: [list any repos beyond this one; use `none` for same-repo work]
**Commands / steps**:
- [ ] [concrete command or action, with access requirement noted]
- [ ] [concrete command or action]
**Verification owner**: [who runs this — Matt manually / Claude in a new session with access to repo X / downstream
repo CI]

## Risks and Mitigations

| Risk   | Impact   | Mitigation       |
| ------ | -------- | ---------------- |
| [Risk] | [Impact] | [How to address] |

## Rollback Strategy

[How to undo changes if needed]

## Status

- [ ] Plan approved
- [ ] Implementation started
- [ ] Implementation complete
```

### 7. Request Approval

Present plan summary and request explicit approval:

"Plan created for '$ARGUMENTS' at `docs/plans/YYYY-MM-DD-<topic>-plan.md`.

**Summary**: [brief description]
**Stakes**: [level]
**Steps**: [count] steps in [count] phases

Ready to approve and begin implementation?"

Use AskUserQuestion with options:

- "Approve and implement" - Mark approved, proceed to implementing-plans
- "Request changes" - Specify what to modify
- "Return to research" - Gather more context first

If approved, invoke the Skill tool with skill "implementing-plans"
to begin implementation.

## Plan Iteration

If a plan already exists at `docs/plans/YYYY-MM-DD-<topic>-plan.md`:

(Search for files matching `*-<topic>-plan.md` pattern)

1. Read the existing plan
2. Ask user's intent:
   - "Refine this plan" - Update existing plan
   - "Start fresh" - Create new plan
   - "View plan" - Display current plan

When refining:

- Preserve approved status if already approved
- Document changes made
- Re-request approval for significant changes

## Anti-Patterns to Avoid

### Vague Tasks

**Wrong**: "Update the code"
**Right**: "Add error handling to fetchUser() in src/api/users.ts:23-45"

### Missing Verification

**Wrong**: Tasks without success criteria
**Right**: Every task has "Verify:" with specific check

### Skipping Approval

**Wrong**: Proceeding to implementation without confirmation
**Right**: Explicit AskUserQuestion approval gate

### Over-Planning

**Wrong**: Spending hours planning a 10-minute fix
**Right**: Match planning rigor to stakes level

### Under-Planning

**Wrong**: "We'll figure it out as we go"
**Right**: Sufficient detail to enable disciplined execution

## Quality Checklist

Before requesting approval:

- [ ] All tasks have clear verification criteria
- [ ] Test cases enumerated for each code change (automated and manual)
- [ ] Test steps precede implementation steps (RED before GREEN)
- [ ] Stakes level is documented with rationale
- [ ] Tasks are granular (prefer small complexity)
- [ ] Risks are identified with mitigations
- [ ] Rollback strategy documented for high stakes
- [ ] Plan document created at docs/plans/
- [ ] Every phase's Execution block includes a `review_group: <id>` field
- [ ] Plan ends with a terminal `security-gate` phase (`depends_on: [all prior groups]`, `review_group: security`, `security_review` mode set)
- [ ] For each group, the Solo / Batched-sequential / Fan-out+consolidator shape choice is recorded inline when non-obvious
- [ ] Post-Merge Verification section filled in (either `Required: no`, or `Required: yes` with trigger point, commands, and owner)
