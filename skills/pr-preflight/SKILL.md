---
name: pr-preflight
description: "Run the GitHub Claude review bot's prompt locally against the current branch before pushing. Prints findings to stdout with severity, a PASS/WARN/BLOCK verdict, and reusable lessons. Use at end-of-session when a PR will be raised."
user_invocable: true
---

# PR Preflight

Runs the same review prompt the GitHub `@claude` review bot uses on PRs (source: `~/src/analytics/.github/workflows/claude.yml`, lines 43–143), but against the local branch pre-push. The skill reads the diff between the current branch and `origin/main`, dispatches five parallel review agents, and prints a consolidated report to stdout with a PASS / WARN / BLOCK verdict so you can decide whether to push.

Invoke this manually at end-of-session, before raising a PR. It is the local-parity companion to the GitHub `@claude` review bot — **not** a replacement for the RPI `code-reviewer` / `security-reviewer` agents (those run during implementation; this runs pre-push).

---

## Code Review Instructions

REPO: current working directory (derive from `git remote get-url origin` if needed).

BRANCH: current git branch; base is `origin/main`.

Review this branch thoroughly.

### Phase 1: Gather local context

- Ultrathink
- Read the branch metadata first, before looking at code:
  - Current branch: `git rev-parse --abbrev-ref HEAD`
  - Merge base with main: `git merge-base HEAD origin/main`
  - Commit log against main (substitute for PR body): `git log $(git merge-base HEAD origin/main)..HEAD --oneline`
  - Individual commit messages if needed for intent: `git log $(git merge-base HEAD origin/main)..HEAD`
- CI status is not available pre-push. If a PR already exists on this branch, fall back to its checks:
  ```
  PR_NUM=$(gh pr view --json number --jq .number 2>/dev/null || true)
  if [ -n "$PR_NUM" ]; then gh pr checks "$PR_NUM"; else echo "No PR yet — CI status will be available after push."; fi
  ```
- Get the diff: `git diff $(git merge-base HEAD origin/main) HEAD`

### Phase 2: Launch FIVE review agents in parallel

Use the Agent tool to launch all five agents concurrently in a single message. Pass each agent the full diff AND the branch metadata (commit log substituting for PR title/body, plus any PR description if a PR already exists) so they have complete context.

**Verify before flagging (applies to every agent below).** Before an agent includes any finding in its output, it MUST use Grep or Read to confirm the issue exists in the actual diff. No speculation. No flagging from memory. If an agent cannot confirm an issue with the tools available, it must not include it — reclassify it as an assumption or drop it.

#### Agent 1: Code Correctness Review

Review the changes for bugs, logic errors, and edge cases. Read the commit messages / PR description to understand intent, then verify the code actually implements it correctly. Hints:

1. **Logic errors**: off-by-one mistakes, wrong comparison operators, inverted conditions, incorrect boolean logic, short-circuit evaluation that skips side effects
2. **Unhandled edge cases**: null/None/undefined inputs, empty collections, zero values, negative numbers, boundary conditions, single-element vs multi-element cases
3. **Error handling gaps**: exceptions that can be thrown but are not caught, swallowed errors that hide failures, missing error propagation to callers, catch blocks that are too broad or too narrow
4. **Race conditions and ordering**: concurrent access to shared state, assumptions about execution order in async code, TOCTOU (time-of-check-to-time-of-use) gaps
5. **Intent vs implementation**: does the code actually do what the commit messages / PR description say? Are there cases where the described behavior diverges from what the code will produce?
6. **Data integrity**: missing validation at system boundaries (user input, API responses, database results), assumptions about external data shape or presence that are not checked

#### Agent 2: Code Reuse Review

Your job is to identify wheel-reinvention and suggest existing solutions. Hints:

1. **Search for existing utilities and helpers** that could replace newly written code. Use Grep to find similar patterns elsewhere in the codebase — common locations are utility directories, shared modules, and files adjacent to the changed ones.
2. **Flag any new function that duplicates existing functionality.** Suggest the existing function to use instead.
3. **Flag any inline logic that could use an existing utility** — hand-rolled string manipulation, ad-hoc type guards, reimplemented patterns, and similar candidates.

#### Agent 3: Code Quality Review

Review the changes for hacky patterns. Hints:

1. **Redundant state**: state that duplicates existing state, cached values that could be derived, etc.
2. **Parameter sprawl**: adding new parameters to a function instead of generalizing or restructuring existing ones
3. **Copy-paste with slight variation**: near-duplicate code blocks that should be unified with a shared abstraction
4. **Leaky abstractions**: exposing internal details that should be encapsulated, or breaking existing abstraction boundaries
5. **Stringly-typed code**: using raw strings where constants, enums (string unions), or suitable types already exist in the codebase. Unnecessary or unsafe casts.
6. **Missing early returns**: nested conditionals or long if/else chains that could be flattened with guard clauses
7. **Unnamed complexity**: long inline expressions or deeply nested logic that would be clearer as a named function or variable
8. **Ephemeral comments**: explanations that only make sense in the context of the current change — these rot fast and confuse future readers

#### Agent 4: Efficiency Review

Review the changes for efficiency. Hints:

1. **Unnecessary work**: redundant computations, duplicate network/API calls, N+1 query patterns
2. **Missed concurrency**: independent operations run sequentially when they could run in parallel
3. **Hot-path bloat**: new blocking work added to startup or per-request/per-render hot paths
4. **Memory**: unbounded data structures, missing cleanup, event listener or subscription leaks
5. **Overly broad operations**: loading all items when filtering for one, missing pagination on potentially large result sets

#### Agent 5: Security Review

Run a fifth check across the diff for security issues. Hints:

1. **Hardcoded credentials**: API keys, passwords, tokens, connection strings, or other secrets committed to the diff — including values that look templated but resolve to real secrets.
2. **Missing auth / permission checks**: new endpoints, handlers, or actions that do not enforce authentication or authorization; checks that are present but bypassable.
3. **Data exposure at API boundaries**: PII, credentials, internal identifiers, or stack traces leaking in responses, logs, or error messages; overly broad serializers that return more than the caller needs.
4. **Conflicts with established architectural patterns in the repo**: new code that sidesteps existing security-critical patterns (parameterized queries, input validation helpers, auth middlewares, existing sanitizers). Use Grep to confirm the repo's existing pattern before flagging divergence.

### Phase 3: Synthesize findings

Wait for all five agents to complete. Aggregate their findings into the output structure below.

[IMPORTANT] Before including any finding, verify it:

- For EACH item before including it:
  - Use the Grep or Read tool to verify the issue definitely exists in the diff
  - Only include if verified

- For EACH question:
  - Questions should ONLY contain things you cannot answer with available tools
  - If you can use Grep/Read to answer it, do that instead and turn it into an Assumption or Feedback item

**Severity tagging (required).** Every finding must carry one of these severity labels:

- **CRITICAL** — blocks merge. Data loss, security hole, crash, broken core behaviour.
- **SIGNIFICANT** — should fix before merge. Correctness bug, missing test on risky path, significant reuse miss, likely regression.
- **MODERATE** — fix in follow-up is acceptable. Quality smell, moderate inefficiency, missing edge-case handling on a non-critical path.
- **MINOR** — style/nit. Naming, formatting, small readability wins.

**Test quality sub-section (required).** Classify the PR's tests and note data shape:

- Classification — pick one: **behavioral** (tests what should be true from a caller's perspective), **implementation** (mirrors the code; passes even if the code is wrong), **insufficient** (some tests present but key paths uncovered), or **none** (no tests added or modified on a change that warranted them).
- Data shape — note whether tests rely entirely on synthetic / mock data, or exercise real data paths (fixtures drawn from production-shaped samples, integration tests against a real service, etc.).

**Spec-soundness check (SPEC: prefix).** Agent 1 checks whether the code matches the commit messages / PR description. This check goes the other direction: is the *description itself* coherent? If the PR description or commit messages contain a design error, internal contradiction, or incoherent intent — not just a code/spec mismatch — flag it with a `SPEC:` prefix as a distinct concern category inside Findings.

### Output

Print the report to stdout in exactly this structure. Do not call `gh pr review`, `gh pr review --approve`, `gh pr review --request-changes`, or any inline-comment tool. Stdout only. Only a human may approve or reject a PR.

```
# PR Preflight Report

**Verdict**: PASS | WARN | BLOCK
**Confidence**: high | medium | low

## Overall assessment
(one short paragraph — what the diff does, and your overall read on whether it's safe to push)

## Assumptions
(bullet list — intent and context assumptions, and questions you answered yourself using Grep/Read)

## Findings
(grouped by severity: CRITICAL, SIGNIFICANT, MODERATE, MINOR. Each finding includes file:line reference, description, and suggested fix. SPEC: findings appear here too, prefixed with `SPEC:` — place them under the severity that matches their impact.)

## Test quality
(classification: behavioral / implementation / insufficient / none — plus a one-line note on whether tests rely entirely on synthetic/mock data or exercise real data paths)

## Reusable lessons
(0–3 bullets maximum — patterns worth carrying forward into future work in this codebase. Omit the section entirely if nothing rises to this bar.)
```

**Verdict rules:**

- **BLOCK** if any CRITICAL or SIGNIFICANT finding exists.
- **WARN** if only MODERATE or MINOR findings exist.
- **PASS** if no actionable concerns.
- If confidence is `low`, do not emit a confident verdict — ask Matt a single targeted question and wait for his answer before finalising the report.

**Reusable lessons** is capped at 3 bullets. If you have more than 3 candidate lessons, keep only the ones that generalise beyond this PR.

---

## Sentinel write on PASS (hook contract)

On a **PASS** verdict — and only on PASS — write a sentinel file at the repo root so the `pr-preflight-gate` `PreToolUse` hook allows the subsequent `gh pr create`:

```bash
touch "$(git rev-parse --show-toplevel)/.pr-preflight-passed"
```

Rules:

- **PASS only.** Do not write the sentinel on WARN or BLOCK. Surface findings and stop.
- **Repo root, not CWD.** Always resolve via `git rev-parse --show-toplevel` so the hook finds it regardless of which subdirectory Matt runs `gh pr create` from.
- **15-minute staleness.** The hook requires the sentinel's mtime to be within the last 900 seconds. If Matt delays raising the PR past that window, the hook will block and ask for a re-run — this is intentional, so the review reflects the current diff.
- **Do not pre-create or touch on retry.** If the first run produced WARN/BLOCK and a second run produces PASS, the second run writes the sentinel fresh at that moment. Never write the sentinel to "skip" the hook.

The hook source of truth lives at `~/.claude/hooks/pr-preflight-gate.sh` and is registered in `~/.claude/settings.json` under `hooks.PreToolUse`. Escape hatch for rare overrides: `PR_PREFLIGHT_SKIP=1 gh pr create ...` (logged to `~/.claude/logs/pr-preflight-skips.log`).

---

## Scope guardrails

- This skill does NOT replace the RPI `code-reviewer` / `security-reviewer` agents. Those run during implementation as soft/hard gates inside `implementing-plans` Step 8. `pr-preflight` is the pre-push local mirror of the GitHub `@claude` review bot. Different timing, different phase — both remain useful.
- This skill does NOT read project `intent.md`, `design.md`, or `architecture.md`. It is diff-focused, matching the GitHub bot's scope. If you want an intent-aware review, that is a different tool (and was the job of the now-deleted `/review` skill).
- This skill does NOT post anywhere — no `gh pr review`, no inline comments, no PR body edits. It prints a report to stdout for Matt to read and act on.
