# Code Quality Standards

These are the quality criteria your code will be reviewed against. Apply them as you write — catching issues now is 10x cheaper than a review round-trip.

## 1. Code Correctness

Watch for these as you write:

- **Logic errors**: off-by-one mistakes, wrong comparison operators, inverted conditions, incorrect boolean logic, short-circuit evaluation that skips side effects
- **Unhandled edge cases**: null/None/undefined inputs, empty collections, zero values, negative numbers, boundary conditions, single-element vs multi-element cases
- **Error handling gaps**: exceptions that can be thrown but are not caught, swallowed errors that hide failures, missing error propagation to callers, catch blocks that are too broad or too narrow
- **Race conditions and ordering**: concurrent access to shared state, assumptions about execution order in async code, TOCTOU (time-of-check-to-time-of-use) gaps
- **Intent vs implementation**: does the code actually do what the task says it should? Are there cases where the described behavior diverges from what the code will produce?
- **Data integrity**: missing validation at system boundaries (user input, API responses, database results), assumptions about external data shape or presence that are not checked, silent data corruption risks (wrong joins, dropped rows, type coercions)

## 2. Code Quality

Avoid these anti-patterns:

- **Redundant state**: state that duplicates existing state, cached values that could be derived
- **Parameter sprawl**: adding new parameters to a function instead of generalizing or restructuring
- **Copy-paste with slight variation**: near-duplicate code blocks that should be unified with a shared abstraction
- **Leaky abstractions**: exposing internal details that should be encapsulated, or breaking existing abstraction boundaries
- **Stringly-typed code**: using raw strings where constants, enums, or suitable types already exist in the codebase. Unnecessary or unsafe casts.
- **Missing early returns**: nested conditionals or long if/else chains that could be flattened with guard clauses
- **Unnamed complexity**: long inline expressions or deeply nested logic that would be clearer as a named function or variable
- **Ephemeral comments**: explanations that only make sense in the context of the current change — these rot fast and confuse future readers

## 3. Code Reuse

Before writing new code:

- **Search for existing utilities and helpers** that could replace what you're about to write. Check utility directories, shared modules, and files adjacent to the ones you're modifying.
- **Do not duplicate existing functionality.** If a utility exists, use it — don't write a second version.
- **Do not inline logic that an existing utility handles** — hand-rolled string manipulation, ad-hoc type guards, reimplemented patterns.

## 4. Efficiency

- **Unnecessary work**: redundant computations, duplicate network/API calls, N+1 query patterns
- **Missed concurrency**: independent operations run sequentially when they could run in parallel
- **Hot-path bloat**: new blocking work added to startup or per-request/per-render hot paths
- **Memory**: unbounded data structures, missing cleanup, event listener or subscription leaks
- **Overly broad operations**: loading all items when filtering for one, missing pagination on potentially large result sets

## 5. Architecture & Safety

- **Architectural conflicts**: decisions that conflict with architecture.md, established patterns, or trap-warning ADRs
- **Security issues**: hardcoded credentials, missing auth checks, data exposure
- **Protected file modifications**: never modify or delete existing files in `docs/decisions/` or `tests/acceptance/`
