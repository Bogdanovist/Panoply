# Research: skills-claude-audit (2026-04-17)

## Problem Statement

An audit of the Panoply skills directory (`~/src/Panoply/skills/`) and the global CLAUDE.md configuration files
was conducted to identify: (1) broken, inconsistent, or stale content in SKILL.md files and README.md; (2) a
specific plan-text contradiction flagged during the Phase A implementation; (3) missing frontmatter in skills;
(4) stale or conflicting references in CLAUDE.md files; and (5) opportunities to add skill-nudge guidance to
CLAUDE.md so high-value skills get suggested proactively at the right moment.

Two parallel research streams were synthesized:

- **Stream A (`-skills.md`)**: Skills directory audit — SKILL.md files, README.md drift, Phase A plan contradiction.
- **Stream B (`-claude-md.md`)**: CLAUDE.md audit — stale references, duplicate files, nudge opportunities.

---

## Unified Issue Table

| # | Severity | Location | What's wrong | Recommended fix |
|---|----------|----------|--------------|-----------------|
| 1 | HIGH | `skills/wardley-mapping/` (empty dir) + `README.md:174` | Directory has no `SKILL.md`. Skill is completely undiscoverable. README row and count both claim it exists as a functional skill. | Either write `SKILL.md` for wardley-mapping, OR delete the empty directory **and** remove the `README.md` row at line 174. If deleting, skill count drops to 30 — update `README.md:75` and `README.md:140`. |
| 2 | HIGH | `README.md:75`, `README.md:140` | Both locations say "31 local skills" but only 30 skill directories contain a `SKILL.md`. The empty `wardley-mapping/` dir inflates the count. | Follows from issue #1: remove empty dir + update count to 30, or write the SKILL.md and keep 31. |
| 3 | MEDIUM | `skills/complete-project/SKILL.md:1-5` | Missing required `name:` field in YAML frontmatter. `skill-creator` documents this as required. Works today via fallback to directory name, but any frontmatter-parsing tooling will silently misfire. | Add `name: complete-project` as the first field in the frontmatter block. |
| 4 | MEDIUM | `skills/design-project/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: design-project`. |
| 5 | MEDIUM | `skills/design-studio/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: design-studio`. |
| 6 | MEDIUM | `skills/refine-project/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: refine-project`. |
| 7 | MEDIUM | `skills/retro/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: retro`. |
| 8 | MEDIUM | `skills/docs/plans/2026-04-17-consolidate-review-skills-plan.md:218` | Test-case line contradicts the required file-structure bullet in the same plan step. See Phase A section below. | Update the test-case line — exact replacement text in Phase A section. |
| 9 | LOW | `~/.claude/CLAUDE.md` (entire file) and `~/src/Panoply/CLAUDE.md` (entire file) | Both files are byte-for-byte identical. Two live copies will diverge silently when one is edited. The canonical location for global instructions is `~/.claude/CLAUDE.md`; `~/src/Panoply/CLAUDE.md` appears to be an accidental duplicate rather than an intentional symlink. | Delete `~/src/Panoply/CLAUDE.md` and replace with a symlink to `~/.claude/CLAUDE.md`, OR add a single-line redirect comment in the Panoply copy deferring to the canonical. **Matt should verify first — see Sanity-Check section.** |
| 10 | LOW | `~/.claude/CLAUDE.md:25` (and identical `~/src/Panoply/CLAUDE.md:25`) | `"Use EnterPlanMode for multi-step tasks."` — `EnterPlanMode` is an internal tool identifier, not a user command. User-facing entry point is `/plan`. | Replace with `"Use /plan for multi-step tasks."` |
| 11 | LOW | `~/.claude/CLAUDE.md` — `Working preferences` section vs `Auto-commit workflow` section | `Working preferences` says "git push is the last thing you do before responding." `Auto-commit workflow` says "Changes are automatically committed and pushed by a Stop hook." Contradictory signals about who is responsible for pushing. | Update the `Working preferences` bullet. Verbatim replacement: **"Always push the code.** The Stop hook auto-commits and pushes after each response. If the hook fails or you're in a non-hook context, push manually — don't leave work unpushed and don't describe what you'll push without doing it." |
| 12 | LOW | `skills/organise-repo/SKILL.md:29-33` | References `~/src/hubris/repos/$REPO/knowledge.md` — a Hubris-era path. The `hubris` repo exists on disk so it doesn't error, but the knowledge-file concept is deprecated in favour of `.claude/rules/`. The section describes a migration workflow that is complete for all repos migrated to Panoply. | Remove or reword the "Check for Knowledge to Migrate" section (lines 27–36 of organise-repo/SKILL.md). The migration is done. |
| 13 | LOW | `~/src/hubris/CLAUDE.md:11` | References `~/.claude/MEMORY.md` as a "performance cache." No such file exists. Stale within the Hubris repo only. | Update `hubris/CLAUDE.md` to remove the MEMORY.md reference, or note it as deprecated. Internal to Hubris; does not affect global instructions. |
| 14 | INFO | `skills/pr-preflight/SKILL.md:163` | References "now-deleted `/review` skill" — accurate historical prose but will become confusing with time. | Leave as-is, or change to "the deleted `/review` skill (removed April 2026)". No functional impact. |

---

## Phase A Plan Contradiction: Verdict

### Quoted Plan Text (verbatim, from `2026-04-17-consolidate-review-skills-plan.md`)

Required file-structure bullet 7 (plan lines 202–207):

```
7. **Scope guardrails** (one short section near the end):
   - This skill does NOT replace the RPI `code-reviewer` / `security-reviewer` agents — those run during
     implementation. `pr-preflight` is the pre-push local mirror of the GitHub `@claude` bot.
   - This skill does NOT read project `intent.md`, `design.md`, or `architecture.md`. It is diff-focused, matching
     the bot's scope. (This is the deliberate difference from the deleted `/review`.)
```

Test-case line (plan line 218):

```
- File does NOT contain `intent.md`, `design.md`, or `architecture.md` — these were dropped intentionally.
```

### Verdict: Real contradiction. The implementer's interpretation was correct.

The required file-structure is the primary specification. Bullet 7 explicitly instructs the implementer to write
the three strings as named anti-drift guardrails inside the skill file — calling them out by name is the mechanism
that prevents future editors from silently re-adding those reads. The test-case was intended to verify a different
intent: that the skill does not *functionally read* those project files (no `cat intent.md`, no `!`-includes).
The test author wrote a structural grep check that accidentally catches the guardrail prose too.

The implementer correctly kept the guardrail text. The test case is wrong and would produce a false positive
against a correctly implemented file.

### Recommended Fix (exact replacement)

Change plan line 218 from:

```
- File does NOT contain `intent.md`, `design.md`, or `architecture.md` — these were dropped intentionally.
```

To:

```
- File contains the literal string `intent.md` only inside the scope-guardrails section (confirms the guardrail
  names the file explicitly). File does NOT contain any `!`-include or `cat` shell command reading `intent.md`,
  `design.md`, or `architecture.md`.
```

---

## wardley-mapping Ghost Directory and README Count Drift

The directory `skills/wardley-mapping/` is completely empty (contains only `.` and `..`). It has been on disk
since at least 2026-03-31 (creation timestamp).

### README drift caused by this ghost

| README location | Claimed value | Actual state | Delta |
|---|---|---|---|
| Line 75 (tree comment) | `# 31 local skills` | 30 skills have SKILL.md; 1 dir (wardley-mapping) is empty | Off by 1 |
| Line 140 | `31 local skills + 9 via plugin (40 total):` | 30 functional local skills | Off by 1 |
| Line 174 | `wardley-mapping` row in Local Skills table | Directory exists but is completely empty | Ghost row |
| Lines 182–188 (Local agents table, 7 entries) | 7 agent `.md` files | 7 agent `.md` files on disk | Accurate |
| Lines 208–209 (Plugin table: dbt 6, snowflake 3) | 9 via plugin | Matches | Accurate |

The only README drift is the `wardley-mapping` ghost row and the off-by-one count. No other skills are missing
from or incorrectly included in the table.

### Resolution options

- **Option A (remove):** Delete `skills/wardley-mapping/`, remove README row at line 174, update counts at lines 75 and 140 from 31 to 30.
- **Option B (complete):** Write a `SKILL.md` for wardley-mapping. Keep the count at 31. Only worthwhile if Wardley mapping is an active workflow Matt wants.

---

## Missing `name:` Frontmatter in 5 Skills

`skill-creator` documents `name:` as a required frontmatter field. The following five skills are missing it:

1. `skills/complete-project/SKILL.md`
2. `skills/design-project/SKILL.md`
3. `skills/design-studio/SKILL.md`
4. `skills/refine-project/SKILL.md`
5. `skills/retro/SKILL.md`

All five appear to work today because Claude Code falls back to the directory name. However this is undocumented
behaviour and any tooling that parses frontmatter directly will silently misfire. The fix is a one-line addition
to each file (`name: <directory-name>` as the first frontmatter field).

---

## Stale References in CLAUDE.md Files

### The duplicate CLAUDE.md

`~/.claude/CLAUDE.md` and `~/src/Panoply/CLAUDE.md` are byte-for-byte identical. Both files are live and will
be independently discovered by agents running in their respective contexts. Since they are not symlinked, any edit
to one will silently diverge from the other.

The canonical location for global instructions is `~/.claude/CLAUDE.md`. The `system-feedback` skill lists
`~/src/Panoply/CLAUDE.md` as canonical but the actual global instructions hook reads from `~/.claude/`.

**This requires a sanity check before fixing — see Recommendations section.**

### `EnterPlanMode` vs `/plan`

Line 25 of both CLAUDE.md files: `"Use EnterPlanMode for multi-step tasks."` — `EnterPlanMode` is the internal
tool name exposed in the model's tool list. The user-facing command is `/plan`. Using the internal name can
confuse an agent looking for a command to invoke.

### `Working preferences` push instruction contradicts `Auto-commit workflow`

- `Working preferences`: "After making changes that are ready for review, `git push` is the last thing you do before responding."
- `Auto-commit workflow`: "Changes are automatically committed and pushed to GitHub by a Stop hook after each response."

These give contradictory signals. The Stop hook is authoritative. The `Working preferences` bullet should be
updated to defer to it.

### Other stale references (lower severity)

- `~/src/analytics/CLAUDE.md:17` and `~/src/datascience/CLAUDE.md:6`: reference `AGENTS.md` files for available skills. Files exist and are current — not broken, but overlap with Panoply skill list is worth monitoring.
- `~/src/Panoply/skills/organise-repo/SKILL.md:29–34`: Hubris knowledge migration path — covered in issue table above.
- `~/src/hubris/CLAUDE.md:11`: References non-existent `~/.claude/MEMORY.md` — internal to Hubris only.

---

## Proposed CLAUDE.md Nudges

These are the four nudges worth encoding in CLAUDE.md. Each has a clear, low-false-positive trigger and real gain.

---

### Nudge 1: `pr-preflight` — before pushing a PR

**Trigger:** Agent is about to push a branch and raise a PR, OR implementation work is complete and next steps toward a PR are being discussed.

**Placement:** Add to the `Auto-commit workflow` section (where push/PR behavior is described).

**Verbatim paste-in markdown:**

```markdown
Before I push — want me to run `/pr-preflight` first? It runs the same checks as the GitHub review bot locally, so we catch anything before it hits the PR.
```

*(This is the suggested phrasing for the agent to speak. The CLAUDE.md instruction that triggers it is in Nudge 4's section block below.)*

---

### Nudge 2: `research-plan-implement` — start of non-trivial feature work

**Trigger:** User describes a feature or change requiring understanding of unfamiliar code or multiple systems — i.e., cases where jumping straight to implementation would skip necessary research.

**Placement:** Add to the `Planning workflow` section, after step 3 (the existing 3-step planning rule).

**Verbatim paste-in markdown (the CLAUDE.md instruction text):**

```markdown
For non-trivial features where you'd need to understand unfamiliar code before planning, suggest `/research-plan-implement` — it runs research, plan, and implementation as separate gated phases with approval gates between each.
```

**Verbatim agent phrasing (what the agent says to the user):**

```
This sounds non-trivial enough to warrant a full research → plan → implement pass. Want me to kick off `/research-plan-implement`? It runs research in parallel subagents, presents a plan for your approval, then implements phase by phase — so you stay in control at each gate.
```

---

### Nudge 3: `retro` — after completing a project or when work has accumulated

**Trigger:** `/complete-project` just ran, OR user says something like "we've shipped a lot lately", "things feel messy", "I want to clean up", "let's review what we've built."

**Placement:** Add to the `Project lifecycle` section, after the `/complete-project` bullet and before the "Projects are in..." line.

**Verbatim paste-in markdown (the CLAUDE.md instruction text):**

```markdown
After completing a project or when several weeks of work have accumulated, suggest `/retro [repo-name]` — it reviews recent code quality, audits rules coverage, and ensures learnings are captured.
```

**Verbatim agent phrasing (what the agent says to the user):**

```
Sounds like a good moment for a `/retro` — quick pass over recent code quality, rules, and conventions to make sure everything we've learned is captured. Worth running?
```

---

### Nudge 4: `system-feedback` — when frustration or a process gap surfaces

**Trigger:** User expresses frustration about how Claude Code or Panoply is working ("this keeps happening", "why does it always...", "this workflow is broken"), or explicitly suggests an improvement to the tooling.

**Placement:** New section at the bottom of CLAUDE.md (after `Data Science Projects`).

**Verbatim agent phrasing (what the agent says to the user):**

```
Sounds like a process gap worth capturing. Want to run `/system-feedback`? It's a structured session to turn this into an actual improvement — whether that's a new rule, skill tweak, or hook change.
```

---

### Full verbatim CLAUDE.md additions (paste-ready)

**Addition 1 — to `Planning workflow` section (after step 3, before `## Agent teams`):**

```markdown
For non-trivial features where you'd need to understand unfamiliar code before planning, suggest `/research-plan-implement` — it runs research, plan, and implementation as separate gated phases with approval gates between each.
```

**Addition 2 — to `Project lifecycle` section (after the `/complete-project` bullet, before the "Projects are in..." line):**

```markdown
After completing a project or when several weeks of work have accumulated, suggest `/retro [repo-name]` — it reviews recent code quality, audits rules coverage, and ensures learnings are captured.
```

**Addition 3 — new section at the end of CLAUDE.md (after `Data Science Projects`):**

```markdown
## Skill nudges

Suggest these skills proactively at the right moment — not constantly, only when the trigger is clean:

- **Before pushing a PR**: "Want me to run `/pr-preflight` first? Catches the same issues as the GitHub review bot, locally."
- **At the start of non-trivial feature work**: "This warrants a full research → plan → implement pass — want to use `/research-plan-implement`?"
- **After wrapping a project or when things feel messy**: "Good moment for a `/retro [repo-name]` — quick pass to capture what we've learned."
- **When you express frustration about how the tooling works**: "Want to capture that as a system improvement? `/system-feedback` is the right tool."
```

**Addition 4 — update to `Working preferences` bullet (replace existing "Always push the code." bullet):**

```markdown
- **Always push the code.** The Stop hook auto-commits and pushes after each response. If the hook fails or you're in a non-hook context, push manually — don't leave work unpushed and don't describe what you'll push without doing it.
```

**Addition 5 — update to `Planning workflow` section (replace "Use EnterPlanMode for multi-step tasks."):**

```markdown
Use /plan for multi-step tasks.
```

---

## Recommendations Matt Should Sanity-Check Before Implementation

### 1. CLAUDE.md duplication — symlink or intentional divergence point?

The two CLAUDE.md files (`~/.claude/CLAUDE.md` and `~/src/Panoply/CLAUDE.md`) are currently identical. Before
acting:

- **Check whether `~/src/Panoply/CLAUDE.md` is already a symlink.** Run `ls -la ~/src/Panoply/CLAUDE.md`. If it
  IS a symlink, the "duplicate" finding is benign — the auditor observed identical content because they are the
  same file. No action needed.
- **If it is a real file (not a symlink):** Decide which is canonical. The global instructions hook reads
  `~/.claude/CLAUDE.md`. The `system-feedback` skill references `~/src/Panoply/CLAUDE.md`. Recommend: delete
  the Panoply copy and replace with a symlink to `~/.claude/CLAUDE.md`, so edits in either location are safe.

### 2. wardley-mapping — delete or complete?

The empty `skills/wardley-mapping/` directory has been sitting there since at least 2026-03-31. Options:

- **Delete it** if Wardley mapping is not an active workflow. Clean up the README row and count.
- **Complete it** by writing a `SKILL.md` if Wardley mapping is something you want as a first-class skill.

The auditor found no evidence this was under active development — it appears to be an abandoned stub. Recommend
delete unless Matt has a specific use case in mind.

### 3. `Data Science Projects` section in global CLAUDE.md

The audit noted that this section is the longest by far and is specific to two repos (`analytics`, `datascience`).
The recommendation is to move it to per-repo `.claude/rules/data-science.md` files to keep the global CLAUDE.md
lightweight. This is a non-trivial refactor — Matt should decide if the time investment is worthwhile, or whether
the current approach (everything in global CLAUDE.md) is acceptable.

### 4. `organise-repo` Hubris migration section

The Hubris knowledge migration (`~/src/hubris/repos/$REPO/knowledge.md`) section in `organise-repo/SKILL.md`
is currently live (the `hubris` repo exists). Removing it is safe if the initial Panoply migration is complete
for all repos Matt cares about. Matt should confirm no repos still have pending Hubris knowledge to migrate
before removing this section.

---

## Open Questions

1. Is `~/src/Panoply/CLAUDE.md` a symlink or a real file? (Determines severity of the duplication issue.)
2. Is `wardley-mapping` a skill under active development, or an abandoned stub?
3. Is the Hubris-to-Panoply migration complete for all repos, making the `organise-repo` migration section fully dead?
4. Should the `Data Science Projects` global config be refactored to per-repo rules? (Non-trivial; needs prioritisation decision.)

---

## Sources

| Document | Research stream | Focus area |
|----------|----------------|------------|
| `docs/plans/2026-04-17-skills-claude-audit-skills.md` | Skills audit agent | SKILL.md files, README drift, Phase A plan contradiction, wardley-mapping ghost |
| `docs/plans/2026-04-17-skills-claude-audit-claude-md.md` | CLAUDE.md audit agent | CLAUDE.md stale references, duplicate files, nudge opportunities, structural redundancy |
