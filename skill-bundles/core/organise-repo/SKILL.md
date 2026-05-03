---
name: organise-repo
description: "Audit and set up a repository's .claude/ configuration following best practices. Creates rules, CLAUDE.md, and settings for a target repo. Use when starting work in a new repo or improving an existing repo's Claude Code setup."
user_invocable: true
---

# Organise Repo

Audit and configure a repository's `.claude/` setup for effective Claude Code usage.

## Steps

### 1. Audit Current State

Check what exists in the repo's `.claude/` directory:

```bash
# Check for .claude directory structure
ls -la .claude/ 2>/dev/null
ls -la .claude/rules/ 2>/dev/null
cat .claude/settings.json 2>/dev/null
cat CLAUDE.md 2>/dev/null
```

Report what exists and what's missing.

### 2. Review CLAUDE.md

Check if the repo has a `CLAUDE.md`. If not, offer to create one with repo-specific conventions based on what you learn from reading the codebase (language, framework, test runner, build system, key directories).

### 3. Rules Assessment

Check `.claude/rules/` for:
- Domain-specific gotchas that should have rule files but don't
- Existing rules that are stale, too broad, or redundant with what Claude already knows
- Opportunities for path-scoped rules (e.g., API conventions only loaded when editing API files)

### 4. Recommend Improvements

Based on the audit, suggest specific additions, updates, or removals. Present each recommendation with rationale.

### 5. Implement

After the user approves recommendations, make the changes. Ask before each modification.

## Best Practices

- **Read the repo first** — understand its domain, technology stack, and conventions before suggesting rules
- **Don't add rules for things Claude already knows** — only add context Claude doesn't have (project-specific patterns, known pitfalls, non-obvious conventions)
- **Keep rules concise and specific** — a rule should be immediately actionable
- **One concern per rule file** — cleaner than a monolithic rules document
- **Use path-scoped rules** — rules files support `paths:` frontmatter for conditional loading, so they're only loaded when working on matching file paths:
  ```yaml
  ---
  paths:
    - "src/api/**"
  ---
  # API Conventions
  ...
  ```
- **Ask before making changes** — present the plan, get approval, then implement
