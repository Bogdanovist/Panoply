---
name: slicing-features
description: Break a spec, plan, or feature into independently-implementable vertical slices (tracer bullets). Each slice cuts through all layers end-to-end. Outputs a task list or GitHub issues. Use after /writing-specs to plan implementation order.
user-invocable: true
argument-hint: "[spec file path, GitHub issue number, or describe the feature]"
---

# Vertical Slicing

Break a plan into thin, vertical slices that each deliver a complete path through all layers (schema, API/backend, UI, tests). Each slice is independently demoable and verifiable.

## Process

### 1. Gather context

Work from whatever is already available:

- If the user passes a file path → read the spec
- If the user passes a GitHub issue number → fetch with `gh issue view <number>`
- If neither → work from conversation context

Also read relevant domain documentation:
- `docs/CONTEXT_MAP.md` for cross-context awareness
- `docs/contexts/<name>/CONTEXT.md` for the relevant context's invariants and contracts

### 2. Explore the codebase (if not already done)

Understand the current state of the areas this work will touch. Focus on:

- Existing interfaces and patterns to follow
- Test infrastructure and conventions
- Which parts of the feature already exist (partial implementations, related code)

### 3. Draft vertical slices

Break the plan into **tracer bullet** slices. Each slice is a thin vertical cut through ALL layers.

**Rules:**

- Each slice delivers a narrow but COMPLETE path through every layer (schema → backend → API → UI → tests)
- A completed slice is demoable or verifiable on its own
- Prefer many thin slices over few thick ones
- First slice should be the simplest possible end-to-end path (the tracer bullet)
- Subsequent slices add breadth, edge cases, polish

**Slice types:**

- **AFK** — can be implemented by an AI agent without human input. Prefer these.
- **HITL** — requires human decision, design review, or external action (API keys, env setup, etc.)

**Pragmatic TDD integration:**

For each slice, note which parts need tests:
- Core logic and domain rules → always test
- Context boundary contracts → always test
- API endpoints → test when non-trivial
- UI/glue code → skip tests unless complex state management

### 4. Present and quiz the user

Present the proposed breakdown as a numbered list:

```
1. [Title] (AFK)
   Blocked by: None — can start immediately
   Tests: [what to test in this slice]

2. [Title] (AFK)
   Blocked by: #1
   Tests: [what to test]

3. [Title] (HITL — needs design decision on X)
   Blocked by: #1
   Tests: none (UI only)
```

Ask the user:

- Does the granularity feel right? (too coarse / too fine)
- Are the dependency relationships correct?
- Should any slices be merged or split?
- Are the correct slices marked AFK vs HITL?
- Which slices should have tests?

**Iterate until the user approves.**

### 5. Output the slices

Based on user preference, either:

**Option A: Local task list** (default)
Save to `docs/contexts/<name>/specs/<feature>-slices.md`

**Option B: GitHub issues**
Create with `gh issue create` in dependency order (blockers first).

Use this template per slice:

```markdown
## What to build

A concise description of this vertical slice. Describe the end-to-end behavior, not layer-by-layer implementation.

## Acceptance criteria

- [ ] Criterion 1 (behavioral — what the user/system can do after this)
- [ ] Criterion 2
- [ ] Tests pass for [specific behaviors]

## Testing scope

- [What to test in this slice — domain logic, boundary contracts, etc.]
- [What NOT to test — UI glue, trivial wiring]

## Blocked by

- #<issue-number> or "None — can start immediately"
```

## Anti-patterns to avoid

- **Horizontal slices**: "First do all the schema, then all the API, then all the UI" — NO. Each slice goes through all layers.
- **Too-thick slices**: If a slice takes more than a day, it's probably too thick. Split it.
- **Testing as a separate slice**: Tests are part of each slice, not a separate task.
- **"Setup" slices**: Avoid slices that are just "set up the infrastructure." The first slice should include the minimal infrastructure needed to make one thing work end-to-end.

## Related skills

- `/writing-specs` — create the spec that this skill breaks down
- `/tracer-tdd` — implement each slice with tracer-bullet TDD
- `/domain-modelling` — stress-test the slices against the domain model
