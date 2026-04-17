# Skills Audit (2026-04-17)

## Summary

- **wardley-mapping** has an empty directory on disk (`skills/wardley-mapping/` with no `SKILL.md`) and a live row in
  `README.md`. The skill is undiscoverable but the count and table claim it exists. Remove the ghost dir and the README
  row, or write the missing `SKILL.md`.
- **README skill count is off by one.** The header says "31 local skills" and the tree says "31 local skills", but
  only 30 skills have a `SKILL.md`. The `wardley-mapping` directory is empty and contributes nothing. The count should
  read 30 (or the skill should be written and the count kept at 31).
- **Five skills are missing the required `name:` frontmatter field.** `skill-creator` explicitly documents `name:` as
  required. The five affected skills (`complete-project`, `design-project`, `design-studio`, `refine-project`, `retro`)
  appear to work because Claude Code falls back to the directory name, but this is undocumented behaviour. Any tool
  or loader that consumes `name:` directly will silently misfire.
- **Phase A plan contradiction is real.** The required file-structure (bullet 7) instructs the implementer to write
  the strings `intent.md`, `design.md`, `architecture.md` into the file as named guardrails. The test-case list for
  the same step says the file must NOT contain those strings. The implementer made the right call (kept the guardrail
  prose), but the test case is wrong and should be fixed so the plan is not misleading to future readers.
- **`organise-repo` references `~/src/hubris/repos/$REPO/knowledge.md`** — a Hubris-era path. The `hubris` repo
  exists on disk so this does not error at runtime, but the reference is dead for most repos that never had a Hubris
  entry, and the concept is being phased out in favour of `.claude/rules/`. It's a LOW-severity cosmetic issue but
  worth noting.

---

## Issue Table

| Severity | Location | What's wrong | Recommended fix |
|---|---|---|---|
| HIGH | `skills/wardley-mapping/` (empty dir) + `README.md:174` | Directory has no `SKILL.md`; skill is undiscoverable. README row and count both claim it exists as a functional skill. | Either write `SKILL.md` for the skill or delete the empty directory **and** remove the `README.md` row at line 174. If deleting, the "31 local skills" count drops to 30 — update `README.md:75` and `README.md:140`. |
| HIGH | `README.md:75`, `README.md:140` | Skill count says "31 local skills" but only 30 skill directories contain a `SKILL.md`. The empty `wardley-mapping/` dir inflates the count. | Fix follows from wardley-mapping resolution above: remove the empty dir and update count to 30, or write the SKILL.md and keep 31. |
| MEDIUM | `skills/complete-project/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. `skill-creator` documents this as required. | Add `name: complete-project` as the first field in the frontmatter block. |
| MEDIUM | `skills/design-project/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: design-project`. |
| MEDIUM | `skills/design-studio/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: design-studio`. |
| MEDIUM | `skills/refine-project/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: refine-project`. |
| MEDIUM | `skills/retro/SKILL.md:1-5` | Missing `name:` field in YAML frontmatter. | Add `name: retro`. |
| MEDIUM | `skills/docs/plans/2026-04-17-consolidate-review-skills-plan.md:218` | Test-case line "File does NOT contain `intent.md`, `design.md`, or `architecture.md`" contradicts the required file-structure bullet 7 in the same step (line 205-207), which explicitly instructs those strings to be written as named guardrails. The implemented file correctly contains the strings. The test case is wrong. | Update the failing test-case line to: "File contains the scope-guardrail bullet explicitly naming `intent.md`, `design.md`, and `architecture.md` as files this skill does NOT read." (See Phase A contradiction section below.) |
| LOW | `skills/organise-repo/SKILL.md:29-33` | References `~/src/hubris/repos/$REPO/knowledge.md` — a Hubris-era path. The `hubris` repo exists on Matt's machine so it does not error, but the knowledge-file concept is deprecated in favour of `.claude/rules/`. Any user of this skill on a non-Hubris setup silently gets "No such file or directory" and moves on (gracefully handled by `2>/dev/null`), but the section describes a dead workflow for repos without Hubris entries. | Remove or reword the "Check for Knowledge to Migrate" section (lines 27-36 of organise-repo/SKILL.md). The migration that section contemplates happened during the initial Panoply setup and is complete. |
| LOW | `skills/pr-preflight/SKILL.md:163` | References `now-deleted /review` skill by name. This is accurate historical prose but will become confusing as time passes. | Cosmetic only. Leave as-is or change "now-deleted `/review` skill" to "the deleted `/review` skill (removed April 2026)". Not a broken link — no action required unless it causes confusion. |

---

## Phase A Plan Contradiction: Verdict

### Quoted Plan Text (Step A.2)

Required file-structure bullet 7 (plan line 202-207):

```
7. **Scope guardrails** (one short section near the end):
   - This skill does NOT replace the RPI `code-reviewer` / `security-reviewer` agents — those run during
     implementation. `pr-preflight` is the pre-push local mirror of the GitHub `@claude` bot.
   - This skill does NOT read project `intent.md`, `design.md`, or `architecture.md`. It is diff-focused, matching
     the bot's scope. (This is the deliberate difference from the deleted `/review`.)
```

Test-case list (plan line 218):

```
- File does NOT contain `intent.md`, `design.md`, or `architecture.md` — these were dropped intentionally.
```

### Verdict: Real contradiction in the plan text. The implementer's interpretation was correct.

The required file-structure is the primary specification. Bullet 7 explicitly instructs the implementer to write
the three strings as named anti-drift guardrails inside the skill file — calling them out by name is the mechanism
that prevents future editors from silently re-adding those reads. The test-case list was meant to verify a different
intent: that the skill does not *functionally read* those project files (i.e., no `cat intent.md` or `!` include
directives). The test author wrote a structural grep check that accidentally catches the guardrail prose too.

The implementer's decision was correct: keep the guardrail text (the stronger semantic requirement) and flag the
test case as wrong. The test case as written would produce a false positive — it would flag a correct file as
failing.

### Recommended Fix

Update plan line 218 from:

```
- File does NOT contain `intent.md`, `design.md`, or `architecture.md` — these were dropped intentionally.
```

to:

```
- File contains the literal string `intent.md` only inside the scope-guardrails section (confirms the guardrail
  names the file explicitly). File does NOT contain any `!`-include or `cat` shell command reading `intent.md`,
  `design.md`, or `architecture.md`.
```

This makes the test check the right thing: presence of the named guardrail + absence of functional reads.

---

## README Drift Details

| README claim | Actual state | Delta |
|---|---|---|
| Line 75: `# 31 local skills` (tree comment) | 30 skills have SKILL.md; 1 dir (wardley-mapping) is empty | Off by 1 |
| Line 140: `31 local skills + 9 via plugin (40 total):` | 30 functional local skills | Off by 1 |
| Line 174: `wardley-mapping` row in Local Skills table | Directory exists but is completely empty (`ls -la` shows only `.` and `..`) | Ghost row — skill is undiscoverable |
| Lines 182-188: Local agents table (7 entries) | 7 agent `.md` files on disk | Accurate |
| Lines 208-209: Plugin table (dbt: 6 skills, snowflake: 3) | Matches "9 via plugin" count | Accurate |

The only drift is the `wardley-mapping` row and the resulting count being 31 vs 30 functional skills.

**No other skills are missing from the table.** Every directory with a valid `SKILL.md` has a corresponding README
row and vice versa (excluding `wardley-mapping`).

---

## Cleanup and Consolidation Opportunities

These are not bugs — nothing is broken — but they are worth noting for a future tidy-up pass.

1. **Five skills without `name:` field** (flagged above as MEDIUM) are functionally fine today because Claude Code
   appears to fall back to the directory name. However, consolidating them to match the majority convention is a
   one-line-per-file change and eliminates ambiguity for any future tooling that parses frontmatter directly.

2. **`organise-repo` Hubris migration section** is dead for all repos without a Hubris history (the vast majority
   of targets). Since the migration from Hubris to Panoply is complete, this section has served its purpose and can
   be removed, making the skill shorter and less confusing.

3. **`wardley-mapping` empty dir** has been on disk since at least 2026-03-31 (creation timestamp). Decision:
   either write a minimal SKILL.md to activate it (if Wardley mapping is a workflow Matt wants), or delete the
   directory and remove the README row. Leaving an empty directory in the skill tree causes confusion for any future
   audit — it looks like an incomplete implementation.

4. **Plan doc test-case quality.** The Phase A contradiction is a symptom of a general pattern: test cases that do
   string-level grep checks against prose-heavy skill files need to distinguish "file mentions X as a concept" from
   "file functionally does X". Future plan authors should write test cases at the intent level ("skill does not
   issue `cat intent.md`") not at the string level ("file does not contain the string `intent.md`") when the skill
   may legitimately reference the concept in guardrail prose.
