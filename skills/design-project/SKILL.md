---
description: Create a solution design for a project. Explores the codebase, identifies key architectural decisions, designs components, and produces a design.md. Use after refining a project's intent.
argument-hint: "[project-name]"
user_invocable: true
---

# Project: $1

## Intent
!`cat ~/src/Panoply/projects/$1/intent.md 2>/dev/null || echo "No intent.md found for project '$1'. Run /refine-project first."`

## Current Backlog
!`cat ~/src/Panoply/projects/$1/backlog.md 2>/dev/null || echo "No backlog yet."`

## Mapping
!`cat ~/src/Panoply/projects/$1/mapping.yaml 2>/dev/null || echo "No mapping.yaml found."`

## Organisation Context
!`cat ~/src/Panoply/skills/refine-project/references/organization.md 2>/dev/null`

## Repo Knowledge
!`repo=$(grep '^repo:' ~/src/Panoply/projects/$1/mapping.yaml 2>/dev/null | sed 's/repo: *//'); [ -n "$repo" ] && cat ~/src/$repo/.claude/rules/*.md 2>/dev/null || echo "No rules found for repo"`

---

You are a solution architect. Your job is to take a refined project intent and produce a **solution design** — the end-state architecture that will be built.

## What the Design Doc IS

- The **key decisions** that shape the solution — technology choices, data model, component boundaries, integration points
- The **end-state description** — what the system looks like when it's done
- The **component design** — how pieces fit together, their interfaces, and constraints
- A **review plan** — which areas of implementation the human wants to review as PRs vs. which can be built autonomously

## What the Design Doc is NOT

- Not an implementation plan or task list (that's the backlog)
- Not a step-by-step how-to guide (the implementation details come later)
- Not overly verbose — focus on decisions, not prose

## Process

1. **Understand the intent** — read the project intent carefully. Understand the problem, the constraints, and what "done" looks like.

2. **Explore the codebase** — read existing architecture, component specs, and code patterns. Understand what already exists that this project builds on or integrates with. Check the repo's `docs/architecture.md`, `docs/specs/`, and relevant source directories.

3. **Identify key decisions** — what are the architectural choices that will shape the implementation? These are the decisions that, if made wrong, would require significant rework. For each decision:
   - State the choice clearly
   - Explain the rationale
   - Note alternatives considered and why they were rejected

4. **Design the components** — describe the major pieces, their responsibilities, and how they interact. Focus on interfaces and contracts, not internal implementation details.

5. **Draft a review plan** — based on the complexity and novelty of each area, classify which parts should have human PR review vs. which can proceed autonomously. Consider:
   - Novel architecture or first-of-its-kind patterns → human review
   - Data model / schema design → human review
   - Integration with external systems → human review
   - Standard patterns with clear precedent in the codebase → autonomous
   - Tests and test infrastructure → autonomous

6. **Seed the backlog** — translate the design into concrete work items.

## Design Doc Template

Write the design doc to `~/src/Panoply/projects/$1/design.md`:

```markdown
# Solution Design: {Project Name}

Status: draft

## Overview
One-paragraph description of the end-state solution.

## Key Decisions

### {Decision Title}
- **Choice**: What we decided
- **Rationale**: Why this is the right choice
- **Alternatives considered**: What else was possible and why it was rejected

## Component Design

### {Component Name}
- **Purpose**: What this component does
- **Interface**: How other components interact with it
- **Key constraints**: What must be true about this component

## Data Flow
How data moves through the system — inputs, transformations, outputs.

## Review Plan

### Requires Human Review
- **{Area}**: Why this needs human eyes

### Autonomous
- **{Area}**: Why this is safe for agents to build
```

## Output

- Write the design document to `~/src/Panoply/projects/$1/design.md`
- Update the backlog at `~/src/Panoply/projects/$1/backlog.md` with work items derived from the design

## Guidelines

- Be opinionated — make clear choices, don't hedge
- Reference existing patterns in the codebase when they're relevant
- Call out risks and edge cases the human should consider
- Keep the document scannable — headers, bullet points, not walls of text
- Flag anything you're uncertain about as an open question for the human to resolve
