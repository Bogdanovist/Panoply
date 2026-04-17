# Research: Consolidate Review Skills Landscape (2026-04-17)

## Problem Statement

Matt's Claude Code setup has accumulated multiple review-related skills, agents, and commands. Before creating a new
skill that wraps the GitHub review bot prompt (pre-push, local), the landscape needs to be mapped so the new skill is
distinctly named, nothing is broken, and stale material is identified for deprecation.

---

## Inventory

### Skills

| Path | Name | One-line purpose | Stale concepts? | RPI-wired? | Referenced from |
|---|---|---|---|---|---|
| `~/.claude/skills/review/SKILL.md` (symlink → `~/src/Panoply/skills/review/SKILL.md`) | `review` | User-invocable inline review of current branch or a PR URL. Reads project `intent.md`, `design.md`, `architecture.md`, `.claude/rules/`, `review-checks.md`. Prints findings for collaborative resolution. | YES — reads `~/src/Panoply/projects/{project}/intent.md`, `design.md`, and `docs/architecture.md` | No | Panoply CLAUDE.md does not reference it; no other skill invokes it; listed in system-reminder as user-invocable |
| `~/.claude/skills/reviewing-code/SKILL.md` (symlink → `~/src/Panoply/skills/reviewing-code/SKILL.md`) | `reviewing-code` | Code review methodology using Conventional Comments. Used as a methodology reference by the `code-reviewer` agent during the implement phase. | No — generic methodology, no project lifecycle references | Yes (indirectly via `code-reviewer` agent) | `~/.claude/agents/code-reviewer.md`, `~/src/Panoply/agents/code-reviewer.md` |
| `~/.claude/skills/security-review/SKILL.md` (symlink → `~/src/Panoply/skills/security-review/SKILL.md`) | `security-review` | Security review methodology. Used as a reference by `security-reviewer` agent during implement phase. | No | Yes (indirectly via `security-reviewer` agent) | `~/.claude/agents/security-reviewer.md`, `~/src/Panoply/agents/security-reviewer.md` |
| `~/.claude/skills/receiving-code-review/SKILL.md` (symlink → `~/src/Panoply/skills/receiving-code-review/SKILL.md`) | `receiving-code-review` | Verification-first methodology for handling incoming code review feedback. | No | No | Not referenced from other skills or agents |
| `~/.claude/skills/research-plan-implement/SKILL.md` (symlink → `~/src/Panoply/skills/research-plan-implement/SKILL.md`) | `research-plan-implement` | Orchestrates the full RPI pipeline with subagents. Spawns `code-reviewer` and `security-reviewer` agents via `implementing-plans`. | No | n/a (IS the RPI skill) | n/a |

### Agents

| Path | Name | One-line purpose | Stale concepts? | RPI-wired? | Referenced from |
|---|---|---|---|---|---|
| `~/.claude/agents/code-reviewer.md` (symlink → `~/src/Panoply/agents/code-reviewer.md`) | `code-reviewer` | Subagent: reviews implementation changes using `reviewing-code` skill. Soft-gates completion. | No | Yes — called from `implementing-plans` (Step 8: `Task tool with subagent_type: "code-reviewer"`) | `implementing-plans/SKILL.md` |
| `~/.claude/agents/security-reviewer.md` (symlink → `~/src/Panoply/agents/security-reviewer.md`) | `security-reviewer` | Subagent: security review of implementation changes using `security-review` skill. Hard-gates on FAIL. | No | Yes — called from `implementing-plans` (Step 8: `Task tool with subagent_type: "security-reviewer"`) | `implementing-plans/SKILL.md` |

### Historical / source material (not in active skill dirs)

| Path | Status | Notes |
|---|---|---|
| `~/src/hubris/.claude/skills/review/SKILL.md` | Origin repo — not in active skill path | The Hubris-era version of `/review`. References `~/src/hubris/projects/{project}/intent.md`, `~/src/hubris/repos/{repo}/knowledge.md`, `~/src/hubris/repos/{repo}/review-checks.md`. Predecessor to the current `review` skill. |
| `~/src/hubris/prompts/review-agent.md` | Origin repo — historical autonomous agent prompt | The original Hubris autonomous review agent prompt. Uses `{{projectIntent}}`, `{{taskSummary}}`, `{{diff}}`, `{{repoContext}}`, `{{mechanicalChecks}}` template variables. Outputs JSON. The current `review` skill was adapted from this. |

### No commands directory

`~/.claude/commands/` does not exist. There are no slash `/review` or `/security-review` commands as separate command
files. These are invoked as skills via the Skill tool (listed in system-reminder as user-invocable skills).

---

## Key Identifications

### The RPI-Bundled Review Skills (DO NOT TOUCH)

The RPI pipeline (`research-plan-implement/SKILL.md`) chains through `implementing-plans`, which calls two agents:

- **`code-reviewer` agent** — spawned as `Task tool with subagent_type: "code-reviewer"` in `implementing-plans/SKILL.md` step 8. Uses `reviewing-code` skill for methodology.
- **`security-reviewer` agent** — spawned as `Task tool with subagent_type: "security-reviewer"` in `implementing-plans/SKILL.md` step 8. Uses `security-review` skill for methodology.

The skills `reviewing-code` and `security-review` are the RPI-wired ones (used as methodology references by the agents
above). The agents themselves (`code-reviewer.md`, `security-reviewer.md`) are the runtime entry points.

**None of these should be touched.**

### The Stale Review Skill (Candidate for Deprecation)

**`~/src/Panoply/skills/review/SKILL.md`** (exposed as `/review`).

This skill is the primary candidate for cleanup. Evidence of staleness:

1. **Reads `~/src/Panoply/projects/{project}/intent.md`** — the Panoply project lifecycle (intent.md, design.md) is an
   active concept, so this is debatable. However:
2. **Reads `~/src/Panoply/projects/{project}/design.md`** — same.
3. **Reads `docs/architecture.md`** (in the current repo) — this file does not exist in any of Matt's active repos
   (analytics, datascience, cloud-infrastructure). It was a Hubris-era concept.
4. **Origin**: Ported directly from `~/src/hubris/.claude/skills/review/SKILL.md` during the Panoply migration (see
   `~/.claude/plans/sequential-baking-pearl.md` line 139-149). That migration plan explicitly noted "Remove JSON output
   format (that was for autonomous review agent)". The skill was adapted for interactive use but still references the
   Hubris project structure (`~/src/hubris/projects/`) in its origin — the Panoply version updated the paths to
   `~/src/Panoply/projects/` but preserved the `intent.md`/`design.md` lookup pattern.
5. **The review agent this was adapted from** (`hubris/prompts/review-agent.md`) was a JSON-output autonomous agent
   that ran against Hubris worker agent PRs. That system is gone.

The skill is functional for Matt's current setup (Panoply project lifecycle still uses intent.md/design.md), but it
**overlaps significantly with the GitHub review bot prompt** that a new skill will wrap. The substantive question is
whether `/review` should be updated to mirror the bot or replaced by the new skill.

**Key difference from the GitHub bot**: The `/review` skill reads project intent files and compares against them
("intent alignment" section). The GitHub bot is purely diff-focused (correctness, reuse, quality, efficiency — no
project intent lookup).

---

## Usage Check: Is the stale `/review` skill referenced anywhere?

Searched across `~/.claude/` and `~/src/Panoply/` for references to the skill name `review` as an invocable skill:

| Location | Reference type | Content |
|---|---|---|
| `~/.claude/cache/changelog.md:89` | Changelog note | "The model can now discover and invoke built-in slash commands like `/init`, `/review`, and `/security-review` via the Skill tool" — this is a Claude Code changelog entry, not a reference in Matt's config |
| `~/.claude/plans/sequential-baking-pearl.md:24` | Historical plan | `prompts/review-agent.md` replaced by interactive `/review` skill — migration plan, not a live reference |
| `~/.claude/plans/sequential-baking-pearl.md:139-149` | Historical plan | Documents the migration of `skills/review/` from hubris |
| `~/.claude/plans/hashed-napping-frost.md` | Historical plan | References `prompts/review-agent.md` and `repos/analytics/review-checks.md` — hubris-era plan, not live |
| `~/src/Panoply/docs/plans/2026-04-14-rpikit-fork-panoply.md:48,164` | Research doc | Lists `review` as one of the Panoply skills (inventory, not invocation) |
| `~/src/Panoply/skills/retro/SKILL.md:28` | Retro skill | "Run the same quality checks the PR review agent uses" — generic prose reference, not a Skill tool invocation |

**Conclusion**: The `/review` skill is NOT programmatically invoked by any other skill, agent, hook, or rule. It is
user-invocable only. Deprecating or replacing it will not break any automated pipeline.

The `/reviewing-code` and `/security-review` skills ARE referenced by the `code-reviewer` and `security-reviewer`
agents respectively — those must not be touched.

---

## Existing Skill Naming Conventions

From the full skill list, naming patterns are:

- **Verb-noun** (present participle): `reviewing-code`, `receiving-code-review`, `implementing-plans`, `researching-codebase`, `writing-plans`, `synthesizing-research`, `documenting-decisions`, `finishing-work`, `verification-before-completion`
- **Noun phrase**: `research-plan-implement`, `security-review`, `git-worktrees`, `parallel-agents`, `react-best-practices`, `system-feedback`, `skill-creator`, `design-studio`
- **Single noun**: `review`, `retro`, `simplify`

The dominant pattern for methodology skills is **verb-noun (present participle)**. Short single-noun names (`review`,
`retro`) appear only for user-facing, top-level entry points.

---

## Naming Recommendations for the New Skill

The new skill wraps the GitHub Actions Claude review bot prompt for local pre-push use. It must be:
1. Distinctly different from `/review` (the Panoply inline review skill)
2. Distinctly different from `/reviewing-code` (the RPI pipeline methodology skill)
3. Clearly conveying "mirrors the GitHub bot, run it before pushing"

### Candidate 1: `preview-pr` (recommended)

**Rationale**: Short, follows single-noun style of `review` and `retro`. "Preview" captures "see what the bot will say
before you push." Avoids "review" in the name entirely — zero confusion with existing review skills. Unambiguous: you
`/preview-pr` before pushing, you `/review` to do a local review. Different verbs, different mental models.

**Risk**: "preview" is slightly ambiguous — could mean "preview the PR description" not "preview the bot's findings."
Mitigated by a clear description in the frontmatter.

### Candidate 2: `pr-preflight` (recommended)

**Rationale**: "Preflight" is aviation/engineering for "checks before departure." No overlap with any existing skill
name. Clearly pre-push. Avoids "review" entirely. Follows the noun-phrase pattern (`security-review`,
`research-plan-implement`). Matt would invoke it as `/pr-preflight` — unambiguous intent.

**Risk**: Slightly longer than ideal for a frequently-used skill. "Preflight" is a slightly borrowed metaphor.

### Candidate 3: `bot-review` (alternative)

**Rationale**: Explicit about what it does — runs the bot's review logic. Follows the noun-phrase pattern. Clear
distinction from `/review` (the existing skill) because "bot" marks it as the GitHub-bot-faithful version.

**Risk**: Still contains "review" — might confuse less-familiar users into thinking it overlaps with `/reviewing-code`
or `/review`. The "bot" prefix is not consistent with the rest of the naming convention (no other skills reference the
tool they wrap in their name).

### Summary table

| Candidate | Style match | Distinctness | Clarity | Risk |
|---|---|---|---|---|
| `preview-pr` | Single-noun (matches `review`, `retro`) | High — no "review" in name | Good | Minor ambiguity in "preview" |
| `pr-preflight` | Noun-phrase (matches `security-review`) | Very high | Very clear | Slightly verbose |
| `bot-review` | Noun-phrase | Medium — contains "review" | Good | Potential confusion with `/review` |

**Top pick: `pr-preflight`** — most distinctive, clearest intent, no overlap risk whatsoever.
**Runner-up: `preview-pr`** — shorter, follows the single-noun style of the user's other top-level invocable skills.

---

## Open Questions

1. Should `/review` be updated to mirror the GitHub bot's structure (four parallel agents, no intent-file lookup) and
   replace the bot entirely? Or should it remain as the "intent-aware" review for local work, with `pr-preflight` as
   the "bot-parity" variant? The external research doc notes the bots are complementary, not identical.

2. The `/review` skill currently reads `~/src/Panoply/projects/{project}/intent.md` — this is only useful when Matt is
   working on a project that has an intent file. For repos without a linked project (ad-hoc work), the intent lookup is
   a no-op (silently skipped). This is acceptable behavior but worth noting in any update.

3. `~/src/analytics/.claude/rules/review-lessons.md` exists — it stores "hard-won lessons from code review." The
   `/review` skill reads from `.claude/rules/` for repo knowledge. This file will be picked up by `/review` when run in
   the analytics repo. It does not reference any specific skill name.

---

## Recommendations (Summary)

- **Leave unchanged**: `reviewing-code`, `security-review`, `code-reviewer` agent, `security-reviewer` agent — all RPI-wired.
- **Candidate for deprecation/update**: `/review` — not wired into any pipeline, references intent.md/design.md/architecture.md, closely overlaps with what the new skill will do.
- **New skill name**: `pr-preflight` (top recommendation) or `preview-pr` (shorter alternative).
- **No commands directory exists** — `/review` and `/security-review` are skills, not separate command files.
