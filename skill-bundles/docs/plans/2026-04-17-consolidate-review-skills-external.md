# Research: Claude GitHub Review Bot Prompt

**Date:** 2026-04-17
**Goal:** Extract the full prompt used by the GitHub-hosted Claude review bot so we can build a local pre-push review skill that mirrors its behaviour.

---

## Source

**Local path:** `/Users/matthumanhealth/src/analytics/.github/workflows/claude.yml`
**GitHub URL:** `https://github.com/Human-App/analytics/blob/main/.github/workflows/claude.yml`

No separate prompt file was found. The entire prompt is inline in the workflow YAML under the `prompt:` key (lines 43–143).

---

## Full Verbatim Prompt

```
First, determine if the user is asking you to review the PR. Look for phrases like
"review", "code review", "review this PR", "take a look", "check this", or similar.

If the user IS asking for a review, follow the review instructions below.
If the user is NOT asking for a review, ignore the review instructions and follow
the user's comment instructions directly.

---

## Code Review Instructions

REPO: ${{ github.repository }}
PR NUMBER: ${{ github.event.pull_request.number }}

Review this PR thoroughly.

### Phase 1: Gather PR Context

- Ultrathink
- Read the PR metadata first, before looking at code:
  ```
  gh pr view ${{ github.event.pull_request.number }} --json title,body,comments,reviews,labels,baseRefName
  ```
- Check CI status: `gh pr checks ${{ github.event.pull_request.number }}`
- Get the diff: `gh pr diff ${{ github.event.pull_request.number }}`

### Phase 2: Launch Four Review Agents in Parallel

Use the Agent tool to launch all four agents concurrently in a single message. Pass each agent the full diff AND the PR metadata (title, body, comments) so they have complete context.

#### Agent 1: Code Correctness Review

Review the changes for bugs, logic errors, and edge cases. Read the PR description to understand intent, then verify the code actually implements it correctly. Hints:

1. **Logic errors**: off-by-one mistakes, wrong comparison operators, inverted conditions, incorrect boolean logic, short-circuit evaluation that skips side effects
2. **Unhandled edge cases**: null/None/undefined inputs, empty collections, zero values, negative numbers, boundary conditions, single-element vs multi-element cases
3. **Error handling gaps**: exceptions that can be thrown but are not caught, swallowed errors that hide failures, missing error propagation to callers, catch blocks that are too broad or too narrow
4. **Race conditions and ordering**: concurrent access to shared state, assumptions about execution order in async code, TOCTOU (time-of-check-to-time-of-use) gaps
5. **Intent vs implementation**: does the code actually do what the PR title/description says? Are there cases where the described behavior diverges from what the code will produce?
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

### Phase 3: Synthesize Findings

Wait for all four agents to complete. Aggregate their findings into the output structure below.

[IMPORTANT] Before including any finding, verify it:

- For EACH item before including it:
  - Use the Grep or Read tool to verify the issue definitely exists in the PR code
  - Only include if verified

- For EACH question:
  - Questions should ONLY contain things you cannot answer with available tools
  - If you can use Grep/Read to answer it, do that instead and turn it into an Assumption or Feedback item

### Output

Deliver the review as follows:

[IMPORTANT] NEVER use `--approve` or `--request-changes`. ALWAYS use `gh pr review --comment`. Only a human may approve or reject a PR.

1. **A concise top-level PR review** (using `gh pr review --comment`): Submit a single review comment containing:
   - A short overall assessment (looks good / needs changes / etc.)
   - **Assumptions** — your assumptions about intent and context, findings & questions you think you have answered.

2. **Inline comments on specific files** (using `mcp__github_inline_comment__create_inline_comment`): For each question or feedback item, leave it as an inline comment on the relevant file and line. Include code snippets where helpful. Suggest changes where sensible.
   - **Questions** that need clarification go as inline comments on the most relevant line
   - **Feedback items** go as inline comments on the lines they refer to
```

---

## Template Variables

| Variable | Source | Meaning |
|---|---|---|
| `${{ github.repository }}` | GitHub Actions context | Full repo name, e.g. `Human-App/analytics` |
| `${{ github.event.pull_request.number }}` | GitHub Actions context | PR number passed to `gh pr view`, `gh pr diff`, `gh pr checks` |

Both variables appear in Phase 1 shell commands. They are used to identify which PR to fetch metadata and diffs for.

---

## Relevant Workflow Config

| Setting | Value |
|---|---|
| **Trigger** | `issue_comment` (created), `pull_request_review_comment` (created), `pull_request_review` (submitted) |
| **Activation guard** | Comment/review body must contain `@claude` |
| **Action** | `anthropics/claude-code-action@v1` |
| **Model** | `claude-opus-4-6` (via `--model` in `claude_args`) |
| **Max turns** | Not set (action default) |
| **allowed_tools** | `mcp__github_inline_comment__create_inline_comment`, `Bash(gh pr review:*)`, `Bash(gh pr diff:*)`, `Bash(gh pr view:*)`, `Bash(gh pr checks:*)` |
| **track_progress** | `true` |
| **additional_permissions** | `actions: read` |
| **Pre-review steps** | `actions/checkout@v4` with `fetch-depth: 1` only |

The bot is opt-in: it only fires when a comment/review explicitly mentions `@claude`. There is no automatic trigger on PR open or push.

---

## Character Summary

The bot is **thorough, structured, and non-blocking**. It runs four parallel specialist agents (correctness, reuse, quality, efficiency), requires each finding to be verified via Grep/Read before inclusion, and outputs an overall assessment plus granular inline comments. Crucially it never approves or requests changes — it comments only, leaving final gate decisions to humans. Tone is technical and direct; no softening language or emoji. It distinguishes unresolvable questions from resolvable ones (answering the latter itself before surfacing them).

---

## What Needs to Change for a Local Pre-Push Skill

### 1. Replacing GitHub Actions context variables

| Bot uses | Local equivalent |
|---|---|
| `${{ github.repository }}` | `git remote get-url origin` (parse owner/repo) or hardcode from `.git/config` |
| `${{ github.event.pull_request.number }}` | Not available pre-push. Replace with `git diff $(git merge-base HEAD origin/main) HEAD` to get the diff |

The Phase 1 `gh pr view / gh pr diff / gh pr checks` commands all require a live PR to exist. Pre-push, the PR may not exist yet.

### 2. Phase 1 replacements (no live PR)

```
# Get diff against merge-base with main
git diff $(git merge-base HEAD origin/main) HEAD

# Get commit messages as "PR body" substitute
git log $(git merge-base HEAD origin/main)..HEAD --oneline

# CI status: not available pre-push; skip or note as unavailable
```

### 3. Output mechanism

The bot posts GitHub PR comments via `gh pr review --comment` and `mcp__github_inline_comment__create_inline_comment`. Pre-push, there is no PR. The local skill should instead:
- Print findings to stdout (the terminal where the developer is working)
- Optionally write a structured markdown report to a temp file
- Use a simple pass/warn/block structure so the developer can decide whether to push

### 4. `Ultrathink` directive

The prompt includes the bare word `Ultrathink` as a Phase 1 step — this is an extended thinking hint. The local skill should preserve this or use `think harder` equivalently to ensure deep analysis.

### 5. Tool allowlist

The GitHub Action restricts tools tightly. The local skill has no such restriction by default, which is fine. However, for fidelity the skill could explicitly grant: `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`, `Grep`, `Read`.

### 6. Model

The bot uses `claude-opus-4-6`. The local skill should default to the same model for parity, but can be overridden by the user.

### 7. Opt-in trigger

The bot fires only when `@claude` is mentioned. Locally, the skill is invoked explicitly by the developer (e.g. `/review` before `git push`), so no trigger logic is needed.

### 8. Existing local `/review` skill

A `/review` skill already exists at `/Users/matthumanhealth/src/Panoply/skills/review/`. Before building a new skill, check how much overlap exists with this bot's prompt — consolidation is likely more appropriate than creating a second review skill.
