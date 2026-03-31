---
name: end-session
description: "End an interactive session. Verifies work is committed and pushed, offers to create a PR, and confirms safe to exit."
user_invocable: true
---

# End Session

1. **Check for uncommitted changes**: Run `git status`. If there are uncommitted changes, ask the user if they want to commit them.

2. **Check for unpushed commits**: Run `git log origin/$(git rev-parse --abbrev-ref HEAD)..HEAD 2>/dev/null`. If there are unpushed commits, push them.

3. **Check for PR**: Run `gh pr view --json url 2>/dev/null`. If no PR exists for the current branch AND it's not the main branch, ask if the user wants to create one.

4. **Confirm exit**: "All done — safe to `/exit`."
