---
name: review
description: "Run an inline code review of the current branch or a specific PR. Evaluates against project intent, code standards, and repo conventions. Prints findings for collaborative resolution."
argument-hint: "[pr-url]"
user_invocable: true
---

# Review

Run the review process inline. Results are printed into this conversation so you and the human can discuss and resolve findings together.

## Target Resolution

Determine what to review based on the argument:

- **PR URL provided** (`$1` looks like a GitHub PR URL): use that PR.
- **No argument**: review the current working branch against its base.

## Steps

### 1. Gather Context

Determine the repo name, project, and branch:

```
# Repo: extract from git remote
REPO=$(basename -s .git $(git remote get-url origin 2>/dev/null))

# Branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Project: find which Panoply project maps to this repo
for d in ~/src/Panoply/projects/*/; do
  grep -l "^repo: $REPO" "$d/mapping.yaml" 2>/dev/null && break
done
# Extract the project name from the matching directory path
```

Read the context files. For each, read the file if it exists — skip silently if not:

- **Project intent**: `~/src/Panoply/projects/{project}/intent.md`
- **Project design**: `~/src/Panoply/projects/{project}/design.md`
- **Repo knowledge**: read from the current repo's `.claude/rules/*.md` files
- **Code standards**: [code-standards.md](references/code-standards.md)
- **Repo review checks**: read from current repo's `.claude/rules/review-checks.md`
- **Architecture doc**: `docs/architecture.md` (in the current repo working directory)

### 2. Get the Diff

**If a PR URL was provided:**
```bash
gh pr diff "$PR_URL"
```
Also fetch the PR title to use as the task summary:
```bash
gh pr view "$PR_URL" --json title --jq .title
```

**If reviewing the current branch:**
```bash
git diff origin/main...HEAD
```
Use the most recent commit message as the task summary. If there are uncommitted changes, include them too:
```bash
git diff HEAD
```

If the diff is empty, tell the user there's nothing to review and stop.

### 3. Perform the Review

You ARE the review agent now. Adopt its adversarial stance. Evaluate the diff against the gathered context using the exact criteria below. Use Read, Glob, and Grep liberally to verify claims — do not speculate.

**Agent code is low quality by default.** Be the quality gate. When you see something that could be better, that is a real problem that must be fixed NOW.

#### 3a. Intent Alignment
Does the code implement what was asked for? Compare against the project intent and task summary. Flag gaps, misinterpretations, or scope creep.

If required assertions are listed, verify every one has a corresponding test. Missing required assertions = automatic request_changes.

#### 3b. Test Quality
Classify tests as:
- **behavioral**: Tests encode "what should be true" from a user/caller perspective
- **implementation**: Tests mirror the code — pass even if the code is wrong
- **insufficient**: Some tests but gaps in coverage
- **none**: No meaningful tests

Check whether tests use real data paths or only synthetic/mock data.

#### 3c. Concerns

**Before including ANY concern, verify it** — use Grep/Read to confirm the issue actually exists. Only include verified findings.

For each concern, prefix with severity: **CRITICAL**, **SIGNIFICANT**, **MODERATE**, or **MINOR**.

Evaluate across these dimensions:

1. **Code Correctness**: Logic errors, unhandled edge cases, error handling gaps, race conditions, intent vs implementation mismatches, data integrity
2. **Code Quality**: Redundant state, parameter sprawl, copy-paste duplication, leaky abstractions, stringly-typed code, missing early returns, unnamed complexity, ephemeral comments
3. **Code Reuse**: Search (Grep) for existing utilities that could replace newly written code. Flag duplicated functionality.
4. **Efficiency**: Unnecessary work, missed concurrency, hot-path bloat, memory issues, overly broad operations
5. **Architecture & Security**: Conflicts with architecture.md or established patterns, hardcoded credentials, missing auth checks, protected file modifications

Apply any repo-specific mechanical checks from `review-checks.md`.

#### 3d. Spec Soundness
Don't just check if code matches the spec — ask if the spec itself makes sense. Flag design errors with prefix "SPEC:".

#### 3e. Reusable Lessons
Identify 0-3 patterns that future work should know about. Only genuinely reusable insights.

### 4. Present Results

Format the review as a structured report printed directly into the conversation:

```
## Review: {branch or PR title}

**Verdict**: approve | request_changes | escalate
**Confidence**: high | medium | low
**Test quality**: behavioral | implementation | insufficient | none

### Summary
{One paragraph on what the changes do}

### Intent Alignment
{Assessment of whether the code meets the stated goal}

### Concerns
{Numbered list, each prefixed with severity tag}
{If no concerns: "No concerns found."}

### Reusable Lessons
{Bulleted list, or "None." if nothing generalizable}

### Recommendation
{What should happen next — specific actions if request_changes}
```

### 5. Collaborate

After presenting the review, you and the human are in the same session. Help them:
- Fix any concerns directly (you have full edit access)
- Discuss whether concerns are valid or should be dismissed
- Re-review after changes if asked

Do not auto-merge or take any external actions. This is a conversation-local review.

## Verdict Standards

- **approve**: Zero actionable concerns at any severity. The code is genuinely clean. This is a high bar.
- **request_changes**: Any fixable issue found, at any severity. Every concern is a required change — no "address later", no "minor enough to ignore".
- **escalate**: Needs human judgment — architectural decisions, unclear intent, or you're not confident.

When in doubt between approve and request_changes, **request changes**.
When in doubt between request_changes and escalate, **escalate**.

## Guidelines

- You are adversarial — find problems, not confirm correctness
- Every concern you list is a required fix, not an observation
- Verify before flagging — use your tools, don't speculate
- The quality bar does not change based on the target branch
- Be specific: file paths, line numbers, what's wrong, what to do instead
