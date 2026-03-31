---
description: Complete and archive a project. Reviews what was built, gates on e2e tests, promotes specs, extracts retrospective lessons, and archives. Use when all backlog items are done.
argument-hint: "[project-name]"
user_invocable: true
---

# Project: $1

## Intent
!`cat ~/src/Panoply/projects/$1/intent.md 2>/dev/null || echo "No intent.md found for project '$1'."`

## Backlog
!`cat ~/src/Panoply/projects/$1/backlog.md 2>/dev/null || echo "No backlog found."`

## Mapping
!`cat ~/src/Panoply/projects/$1/mapping.yaml 2>/dev/null || echo "No mapping.yaml found."`

## Design
!`cat ~/src/Panoply/projects/$1/design.md 2>/dev/null || echo "No design doc."`

## Repo Knowledge
!`repo=$(grep '^repo:' ~/src/Panoply/projects/$1/mapping.yaml 2>/dev/null | sed 's/repo: *//'); [ -n "$repo" ] && cat ~/src/$repo/.claude/rules/*.md 2>/dev/null || echo "No rules found for repo"`

---

You are a project completion agent. A project is being finalised. Your job is to ensure all persistent context is in place, extract lessons, and prepare for archival.

## Process

### 1. Status Review

Present a clear summary:
- What was the project trying to do? (from intent)
- What was accomplished? (from backlog — checked items)
- What's still in Ready/Discovered that wasn't done? Is that OK or does it need addressing?

#### E2E Smoke Test Gate (BLOCKING)

Before proceeding past status review, check: **does this project have a passing e2e smoke test?**

If the project produced a runnable tool, pipeline, or CLI entry point, there MUST be a corresponding test in `tests/e2e/` that exercises the real end-to-end flow against real data. Check for its existence in the workspace repo.

- If the e2e test exists: report its location and confirm it was run successfully.
- If the e2e test does NOT exist: **stop here**. Tell the human this is a required deliverable and the project cannot be completed without it. Offer to help write the test in this session.

### 2. Spec Promotion

Ensure the target repo has persistent specifications for everything this project built. Check `docs/specs/` in the workspace repo:

- For each major component built by this project, there should be a component spec in `docs/specs/{component-name}.md`
- Each spec should capture: Purpose, Interface, Key Design Decisions, Schema (if applicable), Edge Cases
- `docs/specs/INDEX.md` should list all component specs with one-line descriptions
- `docs/architecture.md` should be updated to reflect any new components or data flows

Create or update these files as needed. **This is the most important step** — it embeds the "why" in the repo so future agents understand the system.

### 3. Retrospective

Extract generalizable lessons from this project. Consider:
- What technical discoveries apply beyond this project?
- What patterns worked well that future projects should adopt?
- What mistakes should future projects avoid?
- Were there data source quirks, library gotchas, or convention gaps?

For each lesson, identify where it should be persisted:
- Target repo rules: the target repo's `.claude/rules/` directory or CLAUDE.md
- Strategic context: `~/src/Panoply/skills/refine-project/references/`
- CLAUDE.md in the target repo

Write the lessons to these files directly.

### 4. Archival

After the human approves:
- Move the project directory to `~/src/Panoply/projects/_completed/$1`
- Verify the move succeeded

## Guidelines

- Present the status review first and let the human confirm before proceeding
- For spec promotion, show the human what you plan to create/update before writing
- For retro, propose lessons and get human input — they may have additional insights
- Don't archive until the human explicitly approves
- Be thorough on spec promotion — this is the lasting artefact of the project
- Keep specs concise (~50-100 lines each)
