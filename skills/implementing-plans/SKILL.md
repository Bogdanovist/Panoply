---
name: implementing-plans
description: Disciplined plan execution with checkpoint validation, progress tracking, and verification at each step. Follows an approved plan strictly, running verification criteria before proceeding.
argument-hint: plan file path or feature name
---

# Implementation Phase

Execute the implementation plan for: **$ARGUMENTS**

## Process

### 1. Locate the Plan

**If `$ARGUMENTS` is a file path** (starts with `/` or `docs/` or ends with `.md`):

- Read the file at that path directly
- Check if plan is marked approved
- Proceed based on stakes level

**Otherwise, search for plan by topic:**

Look for plan at: `docs/plans/YYYY-MM-DD-<topic>-plan.md`

(Search for files matching `*-<topic>-plan.md` pattern using `$ARGUMENTS` as the topic)

**If plan exists:**

- Read the plan document
- Check if plan is marked approved
- Proceed based on stakes level

**If no plan exists:**

- Check stakes level of the requested work
- Apply enforcement per §2 below

### 2. Apply Stakes-Based Enforcement

**High Stakes** (architectural, security-sensitive, hard to rollback): **Cannot proceed without an approved plan.** Invoke the `writing-plans` skill first. Stop — do not proceed.

**Medium Stakes** (multiple files, moderate impact): Use `AskUserQuestion` with options "Create a plan first (recommended)" / "Proceed with caution" / "Cancel".

**Low Stakes** (isolated, easy rollback): Proceed with inline planning; mention `writing-plans` and `researching-codebase` as optional improvements.

### 3. Offer Worktree Isolation

Before making changes, offer to create an isolated worktree.

**First, check if already in a worktree:**

```bash
# Check if .git is a file (indicates additional worktree, not main repo)
test -f .git
```

Run this command via the Bash tool:

- Exit code 0 (success): `.git` is a file → already in a worktree → skip
  the prompt and proceed to progress tracking
- Exit code 1 (failure): `.git` is a directory → main repository →
  continue with the worktree offer below

**If not in a worktree, offer based on stakes level:**

**High Stakes:**

Use AskUserQuestion with options:

- "Use worktree (Recommended)" - Create isolated workspace for safer
  changes
- "Continue in current directory" - Proceed without isolation

**Medium Stakes:**

Use AskUserQuestion with options:

- "Use worktree" - Create isolated workspace
- "Continue in current directory" - Proceed without isolation

**Low Stakes:**

Brief mention only:

```text
Tip: For isolation, use EnterWorktree.
Proceeding in current directory...
```

Skip the prompt and continue.

**If user chooses worktree:**

Use EnterWorktree to create the isolated workspace. Implementation
continues in the new worktree directory.

When implementation is complete, use ExitWorktree with action: "keep" to
preserve the branch and return to the main working directory.

If implementation is aborted (user cancels at a checkpoint or
verification fails beyond recovery), use ExitWorktree with
action: "discard" to clean up the worktree without preserving changes.

> **Caution**: EnterWorktree has known active bugs — `bypassPermissions`
> may be ineffective
> ([#29110](https://github.com/anthropics/claude-code/issues/29110)) and
> background agents may not have `pwd` set correctly
> ([#27749](https://github.com/anthropics/claude-code/issues/27749)).
> Always verify the working directory after entering a worktree.

### 4. Initialize Progress Tracking

Create tasks from plan steps using TaskCreate:

Read each step from the plan and create a corresponding task:

- Use step descriptions as the task subject (imperative form)
- Include the step's action and verify criteria in the task description
- Set `activeForm` to a present-continuous description (e.g., "Implementing
  auth middleware")
- All tasks start as pending
- Use `addBlockedBy` via TaskUpdate when plan steps have sequential
  requirements (e.g., Step 1.2 depends on Step 1.1)

### 5. Execute Steps in Order

For each step in the plan:

1. **Mark in_progress** - Update task via TaskUpdate
2. **Locate target files** - If file path is unclear or missing, spawn a `file-finder` agent with the step description and planned action.
3. **Read target files** - Always read before modifying
4. **Make the change** - Follow plan specification exactly
5. **Run verification** - Execute the verify criteria
6. **Confirm success** - Only proceed if verification passes
7. **Mark completed** - Update task via TaskUpdate immediately
8. **Update plan** - Mark step complete in plan document

### 6. Checkpoint After Phases

After completing each phase:

Summarize progress:

```text
Phase [N] complete:
- Step N.1: [description]
- Step N.2: [description]
- Step N.3: [description]

Verifications: All passed
```

Use AskUserQuestion:

- "Continue to Phase [N+1]"
- "Review changes so far"
- "Pause implementation"

### 7. Handle Failures

When verification fails:

1. **Stop** - Do not proceed to next step
2. **Report** - Explain what failed and why
3. **Diagnose** - Investigate the cause. If the error involves external libraries or unfamiliar issues, spawn a `web-researcher` agent with the error message and library/context.
4. **Propose fix** - Suggest correction based on diagnosis

If diagnosis reveals the failure is **pre-existing** (broken on `main`,
unrelated to your change), the default response is *fix it* per the
"No Broken Windows" rule below — not "note as pre-existing and
proceed". Only escalate via `AskUserQuestion` when the fix's blast
radius would materially expand the diff or touches unfamiliar
subsystems.

If fix requires plan changes:

```text
Verification failed for Step [X.Y]: [description]

The planned approach doesn't work because: [reason]

Proposed adjustment: [new approach]
```

Use AskUserQuestion:

- "Approve adjustment and continue"
- "Return to planning"
- "Cancel implementation"

### 8. Complete Implementation

When all steps are done:

1. Mark all tasks completed via TaskUpdate
2. Update plan document status section
3. Run final verification (full test suite if applicable)
4. Run code review through the deterministic review gate (see **Per-phase review gate**
   below for full mechanics). In short:

   ```bash
   ~/.claude/scripts/implement-review-gate.sh \
     --group-id "<review_group from plan>" \
     --implementer-cmd "<remediation command>" \
     --reviewer-cmd  "<code-reviewer spawn command>"
   ```

   Exit-code handling:

   - `0` (PASS) → proceed.
   - `42` (EX_REVIEW_UNRESOLVED — cap-hit after 2 passes) → drop to
     interactive. Surface both rounds of reviewer findings in the
     conversation verbatim. Do NOT proceed to the next phase and do NOT
     loop further. The user decides the next step.
   - Any other non-zero → implementer or reviewer crashed; surface the
     error and stop.

   On PASS the gate is a soft gate at the skill level: if the review_group's
   verdict is `REVIEW_APPROVED` the skill proceeds. If you are running
   outside the gate (manual invocation of `code-reviewer`) and the verdict
   is REQUEST CHANGES, use AskUserQuestion:

   - "Address findings first" (recommended)
   - "Proceed anyway"
   - "Cancel implementation"

5. **Security review is NOT run per phase.** Plan-level security review
   runs exactly once as the terminal `security-gate` phase — see
   `writing-plans` (section 4a, "Terminal `security-gate` phase") and the
   `research-plan-implement` orchestrator. Per-phase security-reviewer
   invocation is deliberately removed from this skill: the reviewer cost
   tracks diff size, not phase count, so one review over the aggregated
   diff is both cheaper and more accurate than N per-phase reviews.

6. Summarize results

```text
Implementation complete for '$ARGUMENTS'.

Summary:
- Steps completed: [N]
- Phases completed: [M]
- Files changed: [list]
- Tests: [pass/fail status]

Plan updated: docs/plans/YYYY-MM-DD-<topic>-plan.md

All success criteria met.
```

## Per-phase review gate

Per-phase review is deterministic: it runs through
`~/.claude/scripts/implement-review-gate.sh`, a 2-pass
implementer→reviewer loop. The skill does not call `code-reviewer`
directly in free-form prose — it invokes the gate, which owns the
control flow, writes the `.review-verdict[-<group_id>]` sentinel, and
returns a well-defined exit code.

### Contract recap

- **Sentinel:** `.review-verdict[-<group_id>]`. Reviewer writes exactly
  `REVIEW_APPROVED` on PASS, or a bulleted list of blocking issues on
  CHANGES. The gate deletes stale sentinels before pass 1.
- **Exit codes:** `0` PASS, `42` EX_REVIEW_UNRESOLVED (both passes
  CHANGES), anything else = implementer/reviewer crash.
- **Group id:** read from the plan's `review_group` field on the phase
  (or group of phases). Pass via `--group-id <id>`.

### Invocation skeleton

```bash
~/.claude/scripts/implement-review-gate.sh \
  --group-id   "<review_group>" \
  --implementer-cmd "<remediation command — re-run the relevant
                     implementer with findings piped on stdin>" \
  --reviewer-cmd    "<spawn code-reviewer against the current diff,
                     writing sentinel at \$REVIEW_SENTINEL>"
```

### Cap-hit handoff (exit 42)

On cap-hit the skill MUST:

1. Print both rounds of reviewer findings verbatim to the conversation.
2. Stop. Do NOT advance to the next phase. Do NOT invoke the gate a
   third time.
3. Hand control to the user, who decides the remediation path (fix
   manually, accept the finding as out-of-scope, amend the plan, or
   abort).

### Interaction with `review_group` shapes

The planner (via `writing-plans`) assigns every phase a `review_group` id and picks one of three shapes (Solo / Batched sequential / Fan-out + consolidator). See `writing-plans` §4a for shape definitions. Regardless of shape, the implementer invokes the gate **once** per group over the aggregated diff — never per phase inside a group.

**Per-phase security review is deliberately absent.** Security review
runs exactly once at plan level via the terminal `security-gate` phase
— do not insert a per-phase security-reviewer invocation anywhere in
this skill's flow.

## Core Principles

### Follow the Plan

The plan is the contract. Deviations require explicit approval:

- Execute steps in order
- Use specified files and approaches
- Meet verification criteria before proceeding
- Document any necessary deviations

### Verify Before Claiming Done

Never claim completion without evidence:

- Run the verification for each step
- Confirm tests pass
- Check that changes match expectations
- Document verification results

### No Broken Windows

If you find a pre-existing problem while doing the planned work — a
failing test, a stale comment, dead code, an obvious bug in a function
you're touching — **fix it as part of the current change**. You have
the context now; "later" never comes back with the same context.

Bound the rule by blast radius:

- **Trivial / adjacent** (broken assertion, wrong path, unused import,
  one-line bug in a function you're already editing): just fix it. No
  approval needed. Mention the sweep-up in the step's verification
  output so it appears in the diff review.
- **Small but unrelated** (separate file, obviously broken, fix is
  contained): fix it and call it out in the next checkpoint summary.
- **Large, risky, or controversial** (materially expands the diff,
  unfamiliar subsystem, ambiguous correct behavior): stop and use
  `AskUserQuestion` — fold it in, route it elsewhere, or skip with a
  recorded reason. Do not silently leave it.

Phrases like "this test was already broken so I left it as
pre-existing" are a failure mode, not an acceptable outcome. The
sweep-ups are part of the work, not a deviation from it — the
"Deviation Handling" gate below covers changes to the plan's *intended
outcome*, not adjacent fixes.

### Keep Code and Comments Evergreen

The plan document, research document, and anything under `docs/plans/`
are transient scaffolding — gitignored or deleted after merge. Code,
comments, docstrings, and commit messages MUST NOT narrate the
planning process or reference those artifacts.

Do NOT write:

- `# see the plan for rationale`
- `# added in Phase 2`
- `"""Implements the <topic> feature as described in docs/plans/..."""`
- `# per research doc`
- `# handles the case from the <topic> implementation`

If a rationale is worth capturing, inline it in the comment itself in
self-contained terms a future reader can act on without any external
context. The reader a year from now will have no plan, no research,
and no memory of the RPI session — the code must stand alone.

Same applies to commit messages and PR descriptions: describe what the
code does and why, not which phase of which plan produced it.

### Track Progress Visibly

Use TaskCreate / TaskUpdate / TaskList for real-time progress:

- Create tasks from plan steps via TaskCreate
- Mark in_progress via TaskUpdate when starting
- Mark completed via TaskUpdate only after verification
- Use TaskList to review overall progress
- Update plan document with status

## Test-Driven Execution

When plan includes test steps, follow TDD:

1. **Red** - Write failing test first
2. **Green** - Write minimal code to pass
3. **Refactor** - Improve without breaking

Mark test steps complete only when tests pass.

## Deviation Handling

If implementation reveals the plan needs changes:

1. Stop current step
2. Document the issue
3. If additional files are needed, spawn a `file-finder` agent with the discovered issue and proposed change.
4. Propose plan modification with updated file references
5. Get approval before continuing

Never deviate silently from the approved plan.

## Anti-Patterns to Avoid

### Skipping Verification

**Wrong**: Marking done without running verification
**Right**: Always run verification, document results

### Proceeding After Failure

**Wrong**: Moving to next step when current step failed
**Right**: Stop, diagnose, fix, re-verify

### Deviating Silently

**Wrong**: Changing approach without updating plan
**Right**: Request approval for plan changes

### Batch Completion

**Wrong**: Marking multiple steps done at once
**Right**: Mark complete immediately after each verification

### Ignoring Stakes

**Wrong**: Rushing high-stakes changes
**Right**: Respect enforcement based on stakes level

## Quality Checklist

During implementation:

- [ ] Always read files before modifying
- [ ] Run verification after each step
- [ ] Mark tasks completed immediately (no batching)
- [ ] Update plan document with status
- [ ] Get approval at phase checkpoints
- [ ] Document any deviations

At completion:

- [ ] All plan steps marked done
- [ ] All verifications passed
- [ ] Per-phase code review completed via `implement-review-gate.sh`
  (exit 0 or interactive override after cap-hit)
- [ ] **Per-phase security review NOT run** — it happens once at plan
  end as the terminal `security-gate` phase, orchestrated by
  `research-plan-implement`, not here
- [ ] Plan document updated with completion status
- [ ] Final summary provided
