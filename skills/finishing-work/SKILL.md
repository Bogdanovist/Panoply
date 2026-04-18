---
name: finishing-work
description: >
  Structured completion workflow for implementation work. Use when
  implementation is complete, all tests pass, and you need to decide how to
  integrate the work. Guides merge, PR creation, or cleanup decisions.
---

# Finishing Work

Verify tests, present options, execute chosen workflow, clean up.

## Purpose

Implementation without proper completion leaves work in limbo. This skill provides structured options for finishing
work: merge locally, create PR, defer for later, or discard. Each option has specific procedures and cleanup
requirements.

## Prerequisites

Before using this skill, verify:

1. All implementation steps completed
2. All verifications passed
3. Code review completed (if applicable)
4. Security review completed (if applicable)
5. Plan path identified: if invoked via `research-plan-implement`, the plan path arrives
   as the skill's `$ARGUMENTS` string (the orchestrator invokes `finishing-work` via the
   Skill tool with `args: '<plan path>'`); otherwise, search `docs/plans/` for a
   `*-plan.md` whose slug matches the current branch name (see Step 5 for the concrete
   heuristic). If no plan is found, Step 5 is a no-op.

**Do not proceed with failing tests.** Fix them first.

## The Completion Workflow

### Step 1: Verify Tests Pass

Run the full test suite:

```text
Run: [project test command]
Verify: Exit code 0, all tests pass
```

**If tests fail**: Stop. Do not proceed until tests pass.

### Step 2: Identify Base Branch

Determine the target branch for integration:

```text
Common targets:
- main (most common)
- master (legacy naming)
- develop (gitflow)
- [feature-branch] (nested features)
```

Check git configuration or ask if unclear.

### Step 3: Present Options

Present exactly four options without elaboration:

1. **Merge locally** - Merge to base branch on local machine
2. **Create pull request** - Push and open PR for review
3. **Keep for later** - Leave branch as-is to continue later
4. **Discard work** - Delete branch and changes

Use AskUserQuestion to get user's choice.

### Step 4: Execute Chosen Option

#### Option 1: Merge Locally

```text
1. Checkout base branch
   git checkout [base-branch]

2. Pull latest changes
   git pull origin [base-branch]

3. Merge feature branch
   git merge [feature-branch]

4. Run tests on merged result
   [project test command]

5. If tests pass, push
   git push origin [base-branch]

6. Delete feature branch
   git branch -d [feature-branch]
   git push origin --delete [feature-branch]
```

**Never merge without verifying tests pass on the result.**

#### Option 2: Create Pull Request

```text
1. Push feature branch
   git push -u origin [feature-branch]

2. Create PR using gh CLI
   gh pr create --title "[title]" --body "[description]"

3. Report PR URL to user

4. Keep branch active for PR review
```

Do NOT delete the branch after creating PR.

#### Option 3: Keep for Later

```text
1. Commit any uncommitted changes
   git add -A && git commit -m "WIP: [description]"

2. Push to remote (backup)
   git push -u origin [feature-branch]

3. Note current state for later
   - Branch name
   - What's done
   - What remains
```

Do NOT delete the branch.

#### Option 4: Discard Work

```text
1. Confirm with user (require typed confirmation)
   "Type 'DISCARD' to confirm deletion of all changes"

2. If confirmed:
   git checkout [base-branch]
   git branch -D [feature-branch]
   git push origin --delete [feature-branch] (if pushed)

3. Clean up any worktree if applicable
```

**Require explicit confirmation.** This is destructive.

### Step 5: Surface Post-Merge Verification (if any)

This step runs after the PR URL has been reported (Option 2) or the merge has completed
(Option 1). It is skipped entirely for Option 3 (keep for later) and Option 4 (discard).

**Step 5 early-exit (do this first, before any file reads):**

1. If `$ARGUMENTS` contains a plan path, use it directly as the plan for this step.
2. Else, if `docs/plans/` does not exist, skip Step 5 entirely (no-op; proceed to Step 6).
3. Else, search `docs/plans/` for a `*-plan.md` file whose slug (the portion between
   the `YYYY-MM-DD-` prefix and the `-plan.md` suffix) appears as a substring of the
   current branch name after stripping any leading `feat/`, `fix/`, or `chore/`
   prefix. If multiple files match, pick the one with the most recent `YYYY-MM-DD`
   prefix. If no file matches, skip Step 5 entirely (no-op; proceed to Step 6).

Only if a plan is identified by the steps above, continue:

1. Read the plan's `## Post-Merge Verification` section.
2. If the section is absent, or `Required: no`, or the `Required:` field value is literally
   `yes | no` (template placeholder left unfilled — treat as `no`): do nothing. Proceed to
   Step 6.
3. If `Required: yes`:
   a. Print the trigger point, repos involved, commands/steps, and verification owner to the
      user, prefixed with `POST-MERGE VERIFICATION REQUIRED:`.
   b. Invoke `AskUserQuestion` with three options:
      - **Verification complete** — the user has already run the steps and confirms they
        passed. Delete `.post-merge-verification-pending` if present; append a
        `## Post-Merge Verification: Completed YYYY-MM-DD` note to the plan.
      - **Deferred — leave pending marker** — write `.post-merge-verification-pending` at
        repo root. The plan doc is the source of truth for trigger and commands; the
        sentinel holds only quick-triage metadata:

        ```
        Plan: <plan path>
        Summary: <one-line free-text summary>
        Owner: <owner>
        ```

        If `.post-merge-verification-pending` already exists (another branch's work is
        still pending), read it first and append the new block with a `---` separator
        line rather than overwriting. Commit it via the normal auto-commit flow.
      - **N/A — CI covered it after all** — delete any existing
        `.post-merge-verification-pending`; append a `## Post-Merge Verification: Reclassified
        as CI-sufficient YYYY-MM-DD — <one-line reason>` note to the plan.

The sentinel file is a session-crossing breadcrumb, not an enforcement gate.

### Step 6: Clean Up

Cleanup depends on the chosen option:

| Option | Cleanup Action |
|--------|----------------|
| Merge locally | Delete feature branch, remove worktree if used |
| Create PR | Keep branch, keep worktree if used |
| Keep for later | Keep branch, keep worktree if used |
| Discard work | Delete branch, remove worktree if used |

#### Worktree Cleanup (if applicable)

If work was done in a git worktree:

```text
1. Exit the worktree directory
   cd [main-repository]

2. Remove the worktree
   git worktree remove [worktree-path]

3. Verify removal
   git worktree list
```

Only remove worktree for merge (Option 1) and discard (Option 4).

## Integration with Implement Phase

This skill is the natural endpoint of the implement phase:

```text
Implementation complete
→ Code review passed
→ Security review passed
→ Use finishing-work skill
→ Choose completion option
→ Execute and clean up
```

## Safety Guardrails

### Never Merge with Failing Tests

```text
If tests fail after merge:
1. Do NOT push
2. Reset the merge: git merge --abort
3. Investigate failures
4. Fix before attempting merge again
```

### Never Force Push to Shared Branches

```text
Avoid: git push --force origin main
This rewrites history and breaks collaborators.

If needed, use: git push --force-with-lease
This fails if remote has new commits.
```

### Confirm Before Discarding

```text
Discard is permanent. Require typed confirmation:
"Type 'DISCARD' to confirm"

Do not accept:
- "yes"
- "y"
- "confirm"

Only exact match: "DISCARD"
```

## Status Reporting

After completing the chosen option, report:

```text
Option 1 (Merge):
"Merged [feature-branch] to [base-branch].
Branch deleted. [N] commits integrated."

Option 2 (PR):
"Pull request created: [PR-URL]
Branch [feature-branch] pushed to origin."

Option 3 (Keep):
"Branch [feature-branch] saved for later.
Pushed to origin as backup."

Option 4 (Discard):
"Branch [feature-branch] deleted.
All changes discarded."
```

In addition, report post-merge verification status as a trailing line:

```text
Verification: none | pending | completed
```

Derivation rule (from Step 5's outcome):

- `none` — Step 5 was skipped (no plan, no `## Post-Merge Verification` section,
  `Required: no`, or placeholder `yes | no`), OR the user selected "N/A — CI covered it
  after all".
- `pending` — the user selected "Deferred — leave pending marker" and
  `.post-merge-verification-pending` was written (or an existing one was appended to).
- `completed` — the user selected "Verification complete" and any existing sentinel was
  cleared.

This line is the canonical channel that `research-plan-implement` reads to populate its
final-report `Verification:` value.

## Anti-Patterns

### Merging Without Tests

**Wrong**: Merge and hope tests pass
**Right**: Run tests, then merge only if passing

### Leaving Branches Dangling

**Wrong**: Finish work, forget to clean up branches
**Right**: Execute appropriate cleanup for chosen option

### Skipping Confirmation for Discard

**Wrong**: Delete branch immediately when user says "discard"
**Right**: Require explicit "DISCARD" confirmation

### Merging Unreviewed Code

**Wrong**: Merge without code review
**Right**: Complete review process before finishing

### Force Pushing to Shared Branches

**Wrong**: Force push to fix mistakes
**Right**: Use safe alternatives or coordinate with team

## Checklist Before Finishing

- [ ] All implementation steps complete
- [ ] All tests pass
- [ ] Code review completed (if required)
- [ ] Security review completed (if required)
- [ ] Base branch identified
- [ ] Option chosen by user
- [ ] Tests pass after merge (if merging)
- [ ] Post-Merge Verification surfaced (or confirmed N/A) per Step 5 *(if Option 1 merge or Option 2 PR; skip for Option 3 keep / Option 4 discard)*
- [ ] Appropriate cleanup performed
- [ ] Status reported to user

## Artifacts

This skill may read or write the following artifact files at the repository root:

- **`.post-merge-verification-pending`** — plain-text session-crossing breadcrumb that records
  an outstanding post-merge verification obligation. Written by Step 5 when the user selects
  "Deferred — leave pending marker"; auto-committed to the repository by the Stop hook so the
  marker survives session closure. Deleted by Step 5 when the user selects "Verification
  complete" or "N/A — CI covered it after all". The sentinel holds only quick-triage
  metadata (`Plan:`, `Summary:`, `Owner:`); the plan document referenced by the `Plan:`
  field is the authoritative source for trigger point and commands, so the sentinel cannot
  drift from the plan. If a prior sentinel already exists at write-time, Step 5 appends a
  new block with a `---` separator rather than overwriting. The naming matches Step 5
  exactly; keep them in sync if the filename is ever changed.

  **Trust boundary**: content of the sentinel is user-authored; any future hook reading this
  file MUST treat it as untrusted text and must not shell-evaluate it or inject it verbatim
  into LLM prompts.
