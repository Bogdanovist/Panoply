---
name: tracer-tdd
description: Implement a feature or fix using pragmatic test-driven development. Tracer-bullet approach — one test, one implementation, repeat. Tests verify behavior through public interfaces, not implementation details. Use when implementing a slice from /slicing-features or any work that needs tests.
user-invocable: true
argument-hint: "[slice description, issue number, or behavior to implement]"
---

# Pragmatic Test-Driven Development

Implement features using vertical tracer bullets: one test → one implementation → repeat. Tests describe WHAT the system does, not HOW it does it.

## Philosophy

**Good tests** exercise real code paths through public interfaces. They read like specifications: "visitor is bucketed consistently across sessions" tells you exactly what capability exists. These tests survive refactors because they don't care about internals.

**Bad tests** mock internal collaborators, test private methods, or verify implementation details. Warning sign: test breaks when you refactor, but behavior hasn't changed.

**Pragmatic mode** (default): test-first for core logic and boundary contracts. Implementation-first for UI and glue code, but still write tests for complex state management. Always write tests — the question is only whether they come before or after the code.

## Process

### 1. Discover project context

Read domain documentation relevant to the work:

1. `docs/contexts/<name>/CONTEXT.md` — invariants and contracts to verify
2. `docs/UBIQUITOUS_LANGUAGE.md` — use domain terms in test names

Also discover the project's test infrastructure:
- Find existing test files to understand patterns and conventions
- Identify the test runner and configuration (package.json scripts, vitest/jest config)
- Find test utilities, factories, or helpers already in use

### 2. Plan the tests

Before writing any code:

- **Identify behaviors to test** — not implementation steps. Frame as: "A [actor] can [action] resulting in [observable outcome]"
- **Classify each behavior:**
  - **Core logic / domain rules** → test-first (RED → GREEN)
  - **Context boundary contracts** → test-first (RED → GREEN)
  - **API endpoints with non-trivial logic** → test-first
  - **UI components / glue code** → implement first, test after if complex
  - **Trivial wiring** → skip tests
- **Identify what to mock** — ONLY at system boundaries:
  - External APIs (Stripe, OpenAI, etc.) → mock
  - Databases → prefer test database or in-memory substitute; mock only if no alternative
  - Time, randomness → mock
  - Your own modules → NEVER mock. Test through the real code.
- **List behaviors in priority order**

Present the plan to the user. Confirm which behaviors to test and the testing approach.

### 3. Tracer bullet

Write ONE test that confirms ONE thing about the system — the simplest possible end-to-end path:

```
RED:   Write test → test fails (confirms test infrastructure works)
GREEN: Write minimal code to pass → test passes
```

This proves the path works. Don't optimize, don't handle edge cases yet.

### 4. Incremental loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

**Rules:**
- One test at a time — don't write the next test until the current one passes
- Only enough code to pass the current test — don't anticipate future tests
- Keep tests focused on observable behavior through public interfaces
- Run all tests after each GREEN to catch regressions

### 5. Refactor

After a group of related tests pass, look for refactoring opportunities:

- Extract duplication (in code, not in tests — test duplication is OK)
- Deepen modules (move complexity behind simpler interfaces)
- Apply SOLID principles where they emerge naturally
- Consider what the new code reveals about existing code

**Never refactor while RED.** Get to GREEN first, then refactor.

Run all tests after each refactor step.

### 6. Update domain documentation

If the implementation revealed new invariants, clarified contracts, or surfaced terminology changes:

- Update `docs/contexts/<name>/CONTEXT.md`
- Update `docs/UBIQUITOUS_LANGUAGE.md`
- Consider an ADR if a hard-to-reverse, surprising trade-off was made

## Checklist per cycle

```
[ ] Test name describes behavior in domain language (not implementation)
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Test mocks only at system boundaries (external APIs, DB, time)
[ ] Code is minimal for this test — no speculative features
[ ] All existing tests still pass
```

## When to mock

| Dependency | Approach |
|-----------|----------|
| External API (Stripe, OpenAI) | Mock — you don't control it |
| Database | Prefer test DB or in-memory substitute. Mock as last resort. |
| Time / randomness | Mock — tests must be deterministic |
| File system | Usually mock. Use temp dirs if testing file I/O specifically. |
| Your own modules | NEVER mock. Test through the real code path. |
| Internal collaborators | NEVER mock. If you need to mock your own code, the interface needs redesigning. |

## Anti-patterns

- **Horizontal slicing**: writing all tests first, then all implementation. Produces tests that test imagined behavior, not actual behavior.
- **Testing implementation**: verifying internal state, mocking internal modules, testing private methods.
- **Over-testing**: testing every getter, every trivial function. Focus on behaviors that matter.
- **Test-after-forget**: writing code without tests and "planning to add them later." In pragmatic mode, UI can be implementation-first, but tests should follow immediately.

## Related skills

- `/slicing-features` — break work into slices before implementing with TDD
- `/writing-specs` — create the spec that defines what to build
- `/domain-modelling` — stress-test the design against the domain model
