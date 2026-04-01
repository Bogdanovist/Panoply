---
name: end-session
description: "End an interactive session. Verifies work is committed, creates a branch if on main, pushes, raises a PR, and confirms safe to exit."
user_invocable: true
---

# End Session

1. **Check for uncommitted changes**: Run `git status`. If there are uncommitted changes, ask the user if they want to commit them.

2. **Ensure work is on a branch**: If the current branch is `main` or `master` and there are unpushed commits, create a feature branch from the current state before pushing. Derive the branch name from the work done (e.g. `feat/symptom-decisions-pipeline`). Use `git checkout -b <branch>` — this moves the unpushed commits onto the new branch.

3. **Push and create PR**: Push the branch with `-u` to set upstream. Then create a PR via `gh pr create`. Always create a PR — do not ask, this is the default workflow.

4. **Confirm exit**: "All done — safe to `/exit`." Include the PR URL.
