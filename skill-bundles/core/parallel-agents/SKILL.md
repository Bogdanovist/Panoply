---
name: parallel-agents
description: >
  Concurrent agent dispatch for independent problems. Use when facing multiple
  independent tasks that can be worked on simultaneously. Reduces total time
  by parallelizing work that has no shared state.
---

# Parallel Agents

Dispatch multiple agents concurrently for independent problems.

## When to Use

Use parallel agents when:

- 3+ test files failing with different root causes
- Multiple subsystems broken independently
- Independent tasks in a plan that don't share state
- Bulk operations across unrelated files

**Do NOT use when:**

- Failures might be related (fixing one might fix others)
- Tasks have sequential dependencies
- Changes could conflict with each other
- Shared state exists between tasks

## Decision Framework

Before parallelizing, ask:

```text
1. Are these problems truly independent?
   - Different files?
   - Different subsystems?
   - No shared data or state?

2. Could fixing one affect another?
   - Shared dependencies?
   - Common configuration?
   - Overlapping code paths?

3. Will changes conflict?
   - Same file modifications?
   - Related API changes?
   - Interconnected tests?
```

If any answer suggests dependency, work sequentially instead.

## The Parallel Process

- **Step 1 — Identify independent problems.** Group failures or tasks by subsystem; confirm no shared state.
- **Step 2 — Create focused agent prompts.** Each prompt covers one clear problem, all context needed, a specific deliverable, and explicit boundaries on which files the agent may touch.
- **Step 3 — Dispatch concurrently.** Make all Task-tool invocations in a single message so the agents run in parallel.
- **Step 4 — Review results.** For each agent, read the summary, verify the claimed fix, check for file overlap with other agents, and run the affected tests.
- **Step 5 — Integrate.** If no conflicts, accept changes and run the full test suite. If conflicts exist, resolve manually and re-test.

## Agent Prompt Requirements

### Must Have

- **Focused scope**: One problem domain only
- **Self-contained context**: All info agent needs
- **Clear deliverable**: What success looks like
- **Boundary constraints**: What NOT to touch

### Must Avoid

- **Overly broad scope**: "Fix all the tests"
- **Missing context**: Assuming agent knows background
- **Vague deliverable**: "Make it work"
- **No boundaries**: Free rein to change anything

## Integration with Implement Phase

Use during implementation when:

- Multiple plan steps are independent
- Test failures span unrelated subsystems
- Bulk changes across independent files

```text
Plan step identifies parallelizable work
→ Verify independence
→ Create focused agent prompts
→ Dispatch concurrently
→ Review and integrate
→ Continue with next plan step
```

## Anti-Patterns

### Parallelizing Related Problems

**Wrong**: Dispatch agents for potentially related failures
**Right**: Verify independence before parallelizing

### Overly Broad Agent Prompts

**Wrong**: "Fix all failing tests in this area"
**Right**: "Fix specific failure X with context Y"

### Ignoring Conflicts

**Wrong**: Accept all agent outputs without checking
**Right**: Review for conflicts before integrating

### Too Many Parallel Agents

**Wrong**: Dispatch 10+ agents simultaneously
**Right**: Keep to 3-5 agents for manageability

### No Boundary Constraints

**Wrong**: Let agents modify any file
**Right**: Constrain each agent to relevant files

## Checklist Before Dispatching

- [ ] Problems verified as independent
- [ ] No shared state between tasks
- [ ] Changes won't conflict
- [ ] Each agent prompt is focused
- [ ] Each agent prompt is self-contained
- [ ] Boundaries specified for each agent
- [ ] Expected output is clear

## Checklist After Completion

- [ ] All agent results reviewed
- [ ] Conflicts identified and resolved
- [ ] Full test suite passes
- [ ] No regressions introduced
- [ ] Changes integrated cleanly
