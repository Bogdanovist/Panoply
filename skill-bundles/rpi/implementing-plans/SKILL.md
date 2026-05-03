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

> **Skip this step entirely when invoked from the RPI orchestrator.** RPI runs
> implementers in the orchestrator's CWD on a single feature branch (set up by
> Phase 0 preflight) and does not use `isolation: "worktree"`. The
> branch-per-implementer worktree pattern caused base_ref drift and orphaned
> worktrees and has been removed from the RPI flow. The rest of this section
> applies only to direct human invocations of `implementing-plans`.

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
unrelated to your change), apply the "No Broken Windows" rule below:
*verify it's actually broken*, then escalate via `AskUserQuestion`
unless the fix is unambiguous and bounded (auto-fix tier requires all
three gates — verified, unambiguous, localized to a file already in
scope). "Note as pre-existing and proceed" is a failure mode; so is
"swept it up because it looked wrong" without verification. When in
doubt, escalate.

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

6. **Update the plan's `## Implementation State` section** *(when the plan has
   one — i.e. RPI-driven runs)*. Edit the entry for this group's `<group-id>`
   so the Phase 3 state survives a context clear:

   - On gate PASS (exit 0): set status to `complete` and append the head
     commit SHA at the time of completion, e.g.

     ```markdown
     - `phase-1-schema`: complete (commit `abc1234`)
     ```

   - On cap-hit (exit 42): set status to `cap-hit`, e.g.

     ```markdown
     - `phase-1-schema`: cap-hit (sentinel `.review-verdict-phase-1-schema`)
     ```

   The orchestrator reads this section on resume to determine which group to
   run next. If the plan has no `## Implementation State` section, this step
   is a no-op (direct human invocation, not an RPI run).

7. Summarize results

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

If you find a pre-existing problem while doing the planned work, the
default response is **verify it's actually broken, then escalate
unless the fix is unambiguous and bounded**. Two failure modes apply
symmetrically: silently leaving brokenness ("noted as pre-existing")
AND silently fixing things that weren't actually broken ("looked wrong
to me, swept it up"). The second is more dangerous because it adds
uninvited regressions under the banner of cleanup.

**Step 1: Verify it's actually broken.**

Before treating anything as a broken window, do the diligence:

- **Reproduce the failure.** Run the test. Trigger the code path. Read
  the actual output. "Looks wrong" is not evidence.
- **Read the call sites.** Code that looks dead may be reached via
  dynamic dispatch, reflection, a config file, or a test harness.
- **Check git blame and nearby comments** for "intentional" markers
  (TODO with rationale, deliberate `xfail`, `// known issue tracked at
  X`, a recent commit explaining the choice). Old code (blame > a few
  weeks) is more likely load-bearing than recently-broken.
- **Look for tests that pin the current behavior.** If callers depend
  on the "wrong" behavior, your fix is a regression, not a fix.

If you can't quickly establish *both* that the thing is broken AND
that the correct behavior is unambiguous, **it is not a broken window
— escalate, do not fix.**

**Step 2: Bound the action by what verification proved.**

- **Auto-fix** (no approval needed) requires ALL of: (a) verified
  broken by reproduction, (b) correct behavior is unambiguous (one
  reasonable reading, no contradictory tests or callers), AND (c) the
  fix is one localized change inside a file you're already editing
  for the planned work. Anything failing any of these gates is NOT
  auto-fix.
- **Escalate via `AskUserQuestion`** when ANY of: ambiguity about
  correct behavior, fix touches a file outside your planned scope,
  the broken thing has been that way for a while (suggests something
  may depend on it), you're unsure why the original author wrote it
  that way, or the fix would materially expand the diff. Default to
  this tier when in doubt — the cost of asking is low; the cost of a
  silent regression is high.

**Step 3: Be loud about every sweep-up.**

Every change you made that wasn't in the plan — even auto-fix tier —
must appear in:

- The **commit message** as a separate bullet, prefixed `sweep:`,
  citing the verification evidence in one line. Do not bundle invisibly.
- The **checkpoint summary** as its own line under a "Sweep-ups"
  heading, not buried inside step verification output.

Silent uninvited fixes are a failure mode. The user must be able to
audit every change you made that they didn't approve.

**Counter-failures to watch for:**

- "This test was already broken so I left it as pre-existing." — Did
  you verify it's broken? If yes, did you escalate or auto-fix? If
  neither: failure mode.
- "I noticed this looked wrong and cleaned it up while I was there."
  — Did you reproduce the brokenness? Did you check call sites? Is it
  in the commit message? If any "no": failure mode.

The sweep-ups are part of the work, not a deviation from it — the
"Deviation Handling" gate below covers changes to the plan's *intended
outcome*, not properly-verified adjacent fixes.

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
