# Research: Consolidate Review Skills (2026-04-17)

## Problem Statement

Matt's Claude Code setup has accumulated multiple review-related skills, agents, and commands. A new skill is needed
that wraps the GitHub Actions Claude review bot prompt so it can be run locally before pushing. Before building that
skill, the landscape must be mapped to ensure:

1. The new skill is distinctly named from existing review skills.
2. Nothing in the active RPI pipeline is broken or replaced.
3. Stale material is identified for deprecation.
4. The exact bot prompt is captured verbatim as the source of truth for the implementer.

---

## Full Inventory of Review-Related Skills, Agents, and Commands

### Skills

| Skill name | Path | Purpose | Stale? | RPI-wired? | Referenced from |
|---|---|---|---|---|---|
| `review` | `~/src/Panoply/skills/review/SKILL.md` (symlinked to `~/.claude/skills/review/SKILL.md`) | User-invocable inline review of current branch or a PR URL. Reads `intent.md`, `design.md`, `architecture.md`, `.claude/rules/`, `review-checks.md` from the project/repo. Prints findings for collaborative resolution. | **YES** — see Stale Skill section below | No | Not invoked by any other skill, agent, hook, or rule. User-invocable only. |
| `reviewing-code` | `~/src/Panoply/skills/reviewing-code/SKILL.md` (symlinked to `~/.claude/skills/reviewing-code/SKILL.md`) | Code review methodology using Conventional Comments. Used as the methodology reference by the `code-reviewer` agent during the implement phase. | No | **Yes** — referenced by `code-reviewer` agent | `~/.claude/agents/code-reviewer.md`, `~/src/Panoply/agents/code-reviewer.md` |
| `security-review` | `~/src/Panoply/skills/security-review/SKILL.md` (symlinked to `~/.claude/skills/security-review/SKILL.md`) | Security review methodology. Used as a reference by the `security-reviewer` agent during the implement phase. | No | **Yes** — referenced by `security-reviewer` agent | `~/.claude/agents/security-reviewer.md`, `~/src/Panoply/agents/security-reviewer.md` |
| `receiving-code-review` | `~/src/Panoply/skills/receiving-code-review/SKILL.md` | Verification-first methodology for handling incoming code review feedback. | No | No | Not referenced from other skills or agents. |
| `research-plan-implement` | `~/src/Panoply/skills/research-plan-implement/SKILL.md` | Orchestrates the full RPI pipeline with subagents. Spawns `code-reviewer` and `security-reviewer` agents via `implementing-plans`. | No | IS the RPI skill | n/a |

### Agents

| Agent name | Path | Purpose | RPI-wired? | Referenced from |
|---|---|---|---|---|
| `code-reviewer` | `~/src/Panoply/agents/code-reviewer.md` (symlinked to `~/.claude/agents/code-reviewer.md`) | Subagent: reviews implementation changes using the `reviewing-code` skill. Soft-gates completion. | **Yes** — called from `implementing-plans` Step 8 via `Task tool with subagent_type: "code-reviewer"` | `implementing-plans/SKILL.md` |
| `security-reviewer` | `~/src/Panoply/agents/security-reviewer.md` (symlinked to `~/.claude/agents/security-reviewer.md`) | Subagent: security review of implementation changes using the `security-review` skill. Hard-gates on FAIL. | **Yes** — called from `implementing-plans` Step 8 via `Task tool with subagent_type: "security-reviewer"` | `implementing-plans/SKILL.md` |

### Commands directory

`~/.claude/commands/` does not exist. There are no slash commands as separate command files. All review-related
invocations (`/review`, `/reviewing-code`, `/security-review`) are skills invoked via the Skill tool, listed in the
system-reminder.

### Historical / origin material (not in active skill path)

| Path | Status |
|---|---|
| `~/src/hubris/.claude/skills/review/SKILL.md` | Hubris-era predecessor to the current `/review` skill. References `~/src/hubris/projects/` and `~/src/hubris/repos/` paths. Not in active skill path. |
| `~/src/hubris/prompts/review-agent.md` | Original Hubris autonomous review agent. Uses template variables (`{{projectIntent}}`, `{{diff}}`, etc.), outputs JSON. The current `/review` skill was adapted from this. |

---

## The RPI-Bundled Review Skills — Must NOT Be Touched

The RPI pipeline (`research-plan-implement`) chains through `implementing-plans`, which in Step 8 spawns two subagents:

- **`code-reviewer` agent** calls the `reviewing-code` skill for methodology.
- **`security-reviewer` agent** calls the `security-review` skill for methodology.

These four components — the two skills and the two agents — form an integrated unit. Any modification risks breaking
the automated review gates in every RPI implementation run. **None of these should be touched.**

---

## The Stale Review Skill — Candidate for Deprecation

**Skill:** `/review`
**File:** `~/src/Panoply/skills/review/SKILL.md`

### Evidence of staleness

1. References `docs/architecture.md` in the current repo — this file does not exist in any of Matt's active repos
   (analytics, datascience, cloud-infrastructure). It was a Hubris-era concept.
2. Was ported directly from `~/src/hubris/.claude/skills/review/SKILL.md` during the Panoply migration (documented in
   `~/.claude/plans/sequential-baking-pearl.md` lines 139–149). The migration noted "Remove JSON output format" but
   preserved the `intent.md`/`design.md` lookup pattern from the old harness.
3. Its origin was `hubris/prompts/review-agent.md`, a JSON-output autonomous agent running against Hubris worker agent
   PRs. That system is gone.
4. The `intent.md`/`design.md` lookup is only useful when working on a project that has those files. For ad-hoc repo
   work it silently no-ops.

### Key difference from the GitHub bot

The `/review` skill performs **intent-aware** review (reads project `intent.md`, `design.md`, checks alignment). The
GitHub bot is **diff-focused only** (correctness, reuse, quality, efficiency — no project intent lookup). These are
complementary, not identical.

### Is `/review` referenced anywhere?

Searched across `~/.claude/` and `~/src/Panoply/`. Every reference found is non-programmatic:

| Location | Reference type |
|---|---|
| `~/.claude/cache/changelog.md:89` | Claude Code changelog entry — not Matt's config |
| `~/.claude/plans/sequential-baking-pearl.md:24,139–149` | Historical migration plan — not live |
| `~/.claude/plans/hashed-napping-frost.md` | Hubris-era historical plan — not live |
| `~/src/Panoply/docs/plans/2026-04-14-rpikit-fork-panoply.md:48,164` | Inventory/research doc — not an invocation |
| `~/src/Panoply/skills/retro/SKILL.md:28` | Generic prose reference ("same quality checks the PR review agent uses") — not a Skill tool call |

**Conclusion:** `/review` is NOT programmatically invoked by any skill, agent, hook, or rule. Deprecating or replacing
it breaks nothing automated.

---

## The GitHub Review Bot — Verbatim Prompt

**Source file:** `/Users/matthumanhealth/src/analytics/.github/workflows/claude.yml` (lines 43–143)

The prompt is inline in the workflow YAML under the `prompt:` key. No separate prompt file exists.

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

## GitHub Workflow Configuration

| Setting | Value |
|---|---|
| **Source file** | `/Users/matthumanhealth/src/analytics/.github/workflows/claude.yml` |
| **Trigger events** | `issue_comment` (created), `pull_request_review_comment` (created), `pull_request_review` (submitted) |
| **Activation guard** | Comment/review body must contain `@claude` — opt-in, not automatic |
| **Action** | `anthropics/claude-code-action@v1` |
| **Model** | `claude-opus-4-6` (passed via `--model` in `claude_args`) |
| **Max turns** | Not set (action default) |
| **allowed_tools** | `mcp__github_inline_comment__create_inline_comment`, `Bash(gh pr review:*)`, `Bash(gh pr diff:*)`, `Bash(gh pr view:*)`, `Bash(gh pr checks:*)` |
| **track_progress** | `true` |
| **additional_permissions** | `actions: read` |
| **Pre-review steps** | `actions/checkout@v4` with `fetch-depth: 1` only |

The bot fires only when a GitHub comment or review explicitly mentions `@claude`. It never fires automatically on PR
open or push.

---

## What Needs to Change for a Local Pre-Push Skill

### 1. Replace GitHub Actions context variables

| Bot uses | Local replacement |
|---|---|
| `${{ github.repository }}` | `git remote get-url origin` (parse owner/repo) or read from `.git/config` |
| `${{ github.event.pull_request.number }}` | Not available pre-push. Replace with `git diff $(git merge-base HEAD origin/main) HEAD` |

### 2. Phase 1 replacements (no live PR exists yet)

The bot's Phase 1 calls `gh pr view`, `gh pr diff`, and `gh pr checks` — all require a live PR. Pre-push replacements:

```bash
# Diff against merge-base with main
git diff $(git merge-base HEAD origin/main) HEAD

# Commit messages as substitute for PR body
git log $(git merge-base HEAD origin/main)..HEAD --oneline

# CI status: not available pre-push — skip or note as unavailable
```

### 3. Output mechanism

The bot posts via `gh pr review --comment` and `mcp__github_inline_comment__create_inline_comment`. Pre-push there is
no PR. The local skill should:

- Print findings to stdout (the developer's terminal).
- Optionally write a structured markdown report to a temp file.
- Use a pass/warn/block structure so the developer can decide whether to push.

### 4. `Ultrathink` directive

The prompt includes bare `Ultrathink` as a Phase 1 step (extended thinking hint). The local skill should preserve this
exactly, or use `think harder` as an equivalent.

### 5. Tool allowlist

The GitHub Action restricts tools tightly. The local skill has no such restriction by default. For fidelity, the skill
can explicitly grant: `Bash(git diff:*)`, `Bash(git log:*)`, `Bash(git show:*)`, `Grep`, `Read`.

### 6. Model

The bot uses `claude-opus-4-6`. The local skill should default to the same model for parity.

### 7. Opt-in trigger

The bot requires `@claude` in a comment. The local skill is invoked explicitly by the developer, so no trigger logic
is needed.

---

## Candidate Names for the New Skill

The new skill must be distinctly different from all three existing review skills (`review`, `reviewing-code`,
`security-review`).

Naming patterns in the existing skill set:
- **Verb-noun (present participle):** `reviewing-code`, `receiving-code-review`, `implementing-plans`, `synthesizing-research` — the dominant pattern for methodology skills.
- **Noun phrase:** `security-review`, `research-plan-implement`, `git-worktrees` — used for pipelines and tools.
- **Single noun:** `review`, `retro`, `simplify` — used for short, user-facing top-level invocables.

### Candidate 1: `pr-preflight` (top recommendation)

**Rationale:** "Preflight" is the engineering/aviation term for checks before departure. No overlap with any existing
skill name — does not contain "review" at all. Clearly pre-push. Follows the noun-phrase pattern
(`security-review`, `research-plan-implement`). Invoked as `/pr-preflight` — intent is unambiguous.

**Tradeoff:** Slightly verbose for a frequently-used skill. "Preflight" is a borrowed metaphor, though well understood
in engineering contexts.

### Candidate 2: `preview-pr` (runner-up)

**Rationale:** "Preview" captures "see what the bot will say before you push." Short, follows the single-noun style of
`review` and `retro`. Avoids "review" in the name entirely — zero name collision. Different verb from `/review`,
different mental model.

**Tradeoff:** "Preview" is slightly ambiguous — could be read as "preview the PR description" rather than "preview the
bot's findings." Mitigated by a clear skill description.

### Candidate 3: `bot-review` (alternative)

**Rationale:** Explicit about what it does — runs the GitHub bot's review logic locally. Follows the noun-phrase
pattern. "Bot" prefix marks it as the faithful reproduction of the GitHub bot.

**Tradeoff:** Contains "review" — risks confusion with `/reviewing-code` and `/review`. No other skill references the
tool it wraps in its name; "bot" breaks naming convention.

### Summary

| Candidate | Style match | Distinctness | Clarity | Risk |
|---|---|---|---|---|
| `pr-preflight` | Noun-phrase | Very high — no "review" in name | Very clear | Slightly verbose |
| `preview-pr` | Single-noun | High — no "review" in name | Good | Minor ambiguity in "preview" |
| `bot-review` | Noun-phrase | Medium — contains "review" | Good | Potential confusion with `/review` |

---

## Technical Constraints

- The new skill must not conflict with the RPI agents' tool allowlist or agent definitions.
- The bot uses `claude-opus-4-6`; the local skill should default to the same.
- `~/src/analytics/.claude/rules/review-lessons.md` contains hard-won code review lessons. The existing `/review`
  skill picks this up via `.claude/rules/` scanning. The new skill may want to incorporate the same mechanism.
- No commands directory exists — the new skill will be a SKILL.md entry, not a command file.

---

## Open Questions

1. **Replace or coexist?** Should `/review` be updated to mirror the GitHub bot's structure (four parallel agents, no
   intent-file lookup) and replace the bot entirely? Or should it remain as the "intent-aware" review for local work,
   with the new skill as the "bot-parity" variant? Research indicates these are complementary (different inputs,
   different purpose) — coexistence is the lower-risk path.

2. **Deprecation timing for `/review`:** Since `/review` is not wired into any pipeline, deprecating it is safe at any
   time. The question is whether it should be deprecated at the same time the new skill is created, or left as-is
   until the new skill proves its value.

3. **`review-lessons.md` integration:** Should the new pre-push skill incorporate
   `~/src/analytics/.claude/rules/review-lessons.md` the way `/review` does? Including it would improve findings
   quality for the analytics repo; excluding it keeps the skill repo-agnostic and faithful to the bot.

---

## Recommendations

- **Leave completely unchanged:** `reviewing-code`, `security-review`, `code-reviewer` agent, `security-reviewer`
  agent — all RPI-wired. Any change risks breaking automated review gates in every RPI run.
- **Candidate for deprecation:** `/review` — not wired into any pipeline, references the Hubris-era `architecture.md`
  pattern, overlaps with the new skill's domain. Safe to deprecate at any time; nothing breaks.
- **New skill name:** `pr-preflight` (top pick — most distinctive, clearest intent, no overlap risk) or `preview-pr`
  (shorter, follows single-noun style of existing top-level skills).
- **Verbatim prompt:** Use the fenced code block above exactly — do not paraphrase or restructure it. The implementer
  should paste it directly into the new SKILL.md and replace the two GitHub Actions variables with the local `git`
  equivalents described in the "What Needs to Change" section.
- **Output:** Replace all `gh pr review --comment` and `mcp__github_inline_comment__create_inline_comment` calls with
  stdout output organized as pass/warn/block.

---

## Sources

| Document | Researcher | Focus Area |
|---|---|---|
| `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-codebase.md` | Codebase research agent | Full inventory of existing skills/agents/commands; stale skill identification; naming conventions and candidate names |
| `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-external.md` | External/workflow research agent | Verbatim bot prompt extraction; GitHub workflow config; local adaptation requirements |
| `/Users/matthumanhealth/src/analytics/.github/workflows/claude.yml` | Primary source | Authoritative prompt source (lines 43–143) |
