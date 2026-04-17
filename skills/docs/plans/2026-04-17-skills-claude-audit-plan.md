# Plan: skills-claude-audit (2026-04-17)

## Summary

Clean up the Panoply skills directory and global CLAUDE.md based on the audit findings. Deprecate three unused
project-lifecycle skills (`complete-project`, `refine-project`, `design-project`) that are superseded by the RPI
pipeline; delete the ghost `wardley-mapping/` directory; trim Hubris-era baggage from `organise-repo`; add
missing `name:` frontmatter to `design-studio` and `retro`; fix a test-case contradiction in a historical plan
doc; and update the README count. In CLAUDE.md: remove the Project lifecycle section, reconcile the "always push"
rule with the Stop-hook auto-push, fix the `EnterPlanMode` reference, and add two targeted skill nudges
(`pr-preflight` before PR push, `research-plan-implement` for non-trivial work). Relocate the strategic-context
`references/` directory out of the deprecated `refine-project/` so its content survives.

## Branch / PR Strategy

- **Branch**: `skills-claude-audit-cleanup` (created off `main`).
- **PR**: single PR against `main` covering both phases. Rationale: changes are small, tightly related, and easier
  to review as one coherent cleanup than as two PRs.
- **Merge**: squash-merge after CI passes and Matt approves.
- **Final step**: `git push` on the branch, then `gh pr create`. Auto-push Stop hook is the safety net; the
  implementer pushes explicitly as the last in-session action.

## Stakes Classification

**Level**: Medium

**Rationale**: File deletions and CLAUDE.md edits affect the global session behaviour for every future Claude Code
run. No code-execution logic is changing — it is configuration, documentation, and skill directory hygiene. The
deletions are fully reversible via git. The CLAUDE.md changes are user-facing nudges and policy text: wrong
wording causes friction, not data loss. Blast radius is "all future sessions" which warrants care, but
individual changes are small and verifiable by inspection.

## Context

**Research**:
- Consolidated audit: `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-skills-claude-audit-research.md`
- Hubris-legacy verdicts: `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-skills-claude-audit-hubris-legacy.md`

**User decisions already fixed** (do not re-litigate):
1. Deprecate all three project-lifecycle skills (`complete-project`, `refine-project`, `design-project`).
2. Delete the empty `wardley-mapping/` directory.
3. Remove the entire `Project lifecycle` section from CLAUDE.md.
4. Add exactly two CLAUDE.md nudges: `pr-preflight` and `research-plan-implement`. No retro or system-feedback
   nudges.
5. `organise-repo` cleanup is narrow: just delete the 10-line "Check for Knowledge to Migrate" section.
6. Keep `retro`, `brainstorming`, `documenting-decisions`, and all other audited-clean skills as-is.

**Affected areas**:
- `/Users/matthumanhealth/src/Panoply/skills/` (deletions, frontmatter edits, SKILL.md trims)
- `/Users/matthumanhealth/src/Panoply/README.md` (count + table)
- `/Users/matthumanhealth/src/Panoply/CLAUDE.md` (section removal, nudges, rule reconciliation)
- `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-plan.md`
  (historical plan-doc contradiction fix)
- `/Users/matthumanhealth/src/Panoply/skills/system-feedback/SKILL.md` (one reference update)

## Pre-Plan Verifications (already done)

Three facts from the audit required verification before planning concrete actions:

### 1. CLAUDE.md duplication — symlink verification

Command run: `ls -la ~/.claude/CLAUDE.md ~/src/Panoply/CLAUDE.md`

Result:
```
lrwxr-xr-x  .../.claude/CLAUDE.md -> /Users/matthumanhealth/src/Panoply/CLAUDE.md
-rw-r--r--  .../src/Panoply/CLAUDE.md   (5374 bytes)
```

Verdict: `~/.claude/CLAUDE.md` is **already a symlink** to `~/src/Panoply/CLAUDE.md`. The audit's "byte-identical
duplication" observation is benign — they are literally the same file. **No action needed for issue #9 in the
research table.** All edits go to the canonical `/Users/matthumanhealth/src/Panoply/CLAUDE.md`.

### 2. `EnterPlanMode` vs `/plan` vs `Plan Mode (Shift+Tab)`

Evidence gathered:
- `EnterPlanMode` is the **internal tool identifier** (appears in the model's tool list), not a user-facing command.
- There is no evidence of a `/plan` slash command in the Claude Code skill list or documentation surveyed.
- The same CLAUDE.md file **already uses** the phrase "Plan Mode (Shift+Tab)" at line 66 (in the Data Science
  Projects section): *"For exploratory work, use Plan Mode (Shift+Tab) before writing queries"*.

Verdict: the correct replacement for line 25 is **"Use Plan Mode (Shift+Tab) for multi-step tasks."** — this
matches the already-established phrasing in the same file and names the actual user-facing entry mechanism. The
research doc's `/plan` suggestion is **rejected** because no such slash command is known to exist.

### 3. `refine-project/references/` strategic-context survival

The deprecation of `refine-project` would delete five strategic-context files that are:
- Referenced by CLAUDE.md line 49: *"Strategic/domain context → ~/src/Panoply/skills/refine-project/references/"*.
- Referenced by `system-feedback/SKILL.md` line 39.

Files present:
```
refine-project/references/cs-automation.md
refine-project/references/experimentation.md
refine-project/references/infrastructure.md
refine-project/references/organization.md
refine-project/references/product-and-growth.md
```

Verdict: these are **real, used, strategic context**. They must be **relocated, not deleted**, when
`refine-project/` is removed. Target: `~/src/Panoply/strategic-context/`. Both referencing files must be updated.

## Success Criteria

- [ ] All three deprecated skill directories removed: `complete-project/`, `refine-project/`, `design-project/`.
- [ ] `wardley-mapping/` ghost directory removed.
- [ ] Strategic-context `references/` files preserved at new location `~/src/Panoply/strategic-context/`.
- [ ] `organise-repo/SKILL.md` has the Hubris knowledge-migration section removed.
- [ ] `design-studio/SKILL.md` and `retro/SKILL.md` have `name:` frontmatter added.
- [ ] Historical plan doc `2026-04-17-consolidate-review-skills-plan.md:218` has the test-case line replaced.
- [ ] `README.md` count updated from "31 local skills" → "27 local skills" (31 − 4) in both locations; four
  table rows removed.
- [ ] CLAUDE.md `Project lifecycle` section removed entirely.
- [ ] CLAUDE.md `EnterPlanMode` reference replaced with `Plan Mode (Shift+Tab)`.
- [ ] CLAUDE.md "Always push" bullet reconciled with Stop-hook reality.
- [ ] CLAUDE.md contains nudges for `pr-preflight` (Auto-commit workflow section) and `research-plan-implement`
  (Planning workflow section).
- [ ] CLAUDE.md `Context management` section updated: strategic-context path now points to
  `~/src/Panoply/strategic-context/`.
- [ ] `system-feedback/SKILL.md` strategic-context reference updated to new path.
- [ ] PR raised against `main`, CI passes, branch pushed.

## Implementation Steps

### Phase A: Skills directory cleanup

**Execution block**

- **Scope**: All changes under `/Users/matthumanhealth/src/Panoply/skills/` and `/Users/matthumanhealth/src/Panoply/README.md`.
  Also creates the new `/Users/matthumanhealth/src/Panoply/strategic-context/` directory.
- **Depends on**: None (first phase).
- **Parallel with**: Nothing (Phase B depends on the relocated strategic-context path existing).
- **Gate**: Autonomous. Matt's working style: "Decision visibility over permission gates" and "Bias to action."
  No step requires permission; deviations or unexpected state pauses for review. Verification after each step
  catches mistakes before they propagate.

#### Step A.1: Relocate strategic-context references before deleting refine-project

- **Status**: Complete
- **Files**:
  - Source: `/Users/matthumanhealth/src/Panoply/skills/refine-project/references/` (5 files).
  - Target: `/Users/matthumanhealth/src/Panoply/strategic-context/` (new directory).
- **Action**:
  - Create `/Users/matthumanhealth/src/Panoply/strategic-context/` via `mkdir -p`.
  - `git mv` each of the five `.md` files from `skills/refine-project/references/` to `strategic-context/`.
  - Verify the source directory is now empty (ready for full skill-dir removal in step A.3).
- **Verify**:
  - `ls /Users/matthumanhealth/src/Panoply/strategic-context/` shows exactly 5 files:
    `cs-automation.md`, `experimentation.md`, `infrastructure.md`, `organization.md`, `product-and-growth.md`.
  - `ls /Users/matthumanhealth/src/Panoply/skills/refine-project/references/` returns empty (or directory absent).
  - `git status` shows 5 renames (R) with no content changes.
- **Complexity**: Small.

#### Step A.2: Delete `wardley-mapping/` ghost directory

- **Status**: Complete
- **Files**: `/Users/matthumanhealth/src/Panoply/skills/wardley-mapping/` (empty directory).
- **Action**: `rmdir /Users/matthumanhealth/src/Panoply/skills/wardley-mapping` (empty dir, no git tracking).
- **Verify**:
  - `ls /Users/matthumanhealth/src/Panoply/skills/wardley-mapping` returns "No such file or directory".
  - No git change recorded (directory was empty and untracked).
- **Complexity**: Small.

#### Step A.3: Delete deprecated skill directories

- **Status**: Complete
- **Files**:
  - `/Users/matthumanhealth/src/Panoply/skills/complete-project/`
  - `/Users/matthumanhealth/src/Panoply/skills/refine-project/`
  - `/Users/matthumanhealth/src/Panoply/skills/design-project/`
- **Action**: `git rm -r` each directory. Must run **after** Step A.1 has relocated the strategic context files,
  so no content is lost.
- **Verify**:
  - `ls /Users/matthumanhealth/src/Panoply/skills/` does not list any of the three directories.
  - `git status` shows deletions for each SKILL.md and any sub-files.
  - None of the 5 strategic-context files appear in the deletion list (they were already relocated).
- **Complexity**: Small.

#### Step A.4: Trim `organise-repo/SKILL.md` Hubris section

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/organise-repo/SKILL.md` (lines 27-36 as identified by
  audit; current file shows lines 27-36 as the "Check for Knowledge to Migrate" section + the blank line after).
- **Action**: Remove lines 27-36 inclusive (the `### 2. Check for Knowledge to Migrate` heading, its prose, the
  bash block, and the offer-to-migrate sentence). Renumber the subsequent numbered steps: what was `### 3. Review
  CLAUDE.md` becomes `### 2.`, `### 4. Rules Assessment` → `### 3.`, `### 5. Recommend Improvements` → `### 4.`,
  `### 6. Implement` → `### 5.`.
- **Test cases** (grep-level structural checks):
  - File does NOT contain `~/src/hubris/repos`.
  - File does NOT contain `Check for Knowledge to Migrate`.
  - File does NOT contain `knowledge.md`.
  - File DOES contain `### 1. Audit Current State`.
  - File DOES contain `### 2. Review CLAUDE.md` (renumbered from `### 3`).
  - File DOES contain `### 5. Implement` (renumbered from `### 6`).
- **Verify**: Run the six grep checks listed above. All pass.
- **Complexity**: Small.

#### Step A.5: Add `name:` frontmatter to `design-studio` and `retro`

- **Files**:
  - `/Users/matthumanhealth/src/Panoply/skills/design-studio/SKILL.md:1-4`
  - `/Users/matthumanhealth/src/Panoply/skills/retro/SKILL.md:1-5`
- **Action**: Insert `name: design-studio` as the first frontmatter line (between opening `---` and `description:`)
  in the first file. Insert `name: retro` as the first frontmatter line in the second.
- **Test cases**:
  - `head -n 2 design-studio/SKILL.md | tail -n 1` equals exactly `name: design-studio`.
  - `head -n 2 retro/SKILL.md | tail -n 1` equals exactly `name: retro`.
  - Both files still parse as valid YAML frontmatter (opening `---`, block of key: value pairs, closing `---`).
- **Verify**: Two grep/head checks pass.
- **Complexity**: Small.

#### Step A.6: Fix Phase A plan-doc contradiction

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-plan.md`
  line 218.
- **Action**: Replace the single test-case line:

  From:
  ```
    - File does NOT contain `intent.md`, `design.md`, or `architecture.md` — these were dropped intentionally.
  ```

  To:
  ```
    - File contains the literal string `intent.md` only inside the scope-guardrails section (confirms the
      guardrail names the file explicitly). File does NOT contain any `!`-include or `cat` shell command reading
      `intent.md`, `design.md`, or `architecture.md`.
  ```

- **Test cases**:
  - File contains the new string `only inside the scope-guardrails section`.
  - File does NOT contain the old string `these were dropped intentionally`.
- **Verify**: Two grep checks pass.
- **Complexity**: Small.

#### Step A.7: Update `README.md` skill count and table

- **Files**: `/Users/matthumanhealth/src/Panoply/README.md`.
  - Line 75: `│   ├── skills/                         # 31 local skills`
  - Line 140: `31 local skills + 9 via plugin (40 total):`
  - Line 148: `complete-project` table row.
  - Line 149: `design-project` table row.
  - Line 162: `refine-project` table row.
  - Line 174: `wardley-mapping` table row.
- **Action**:
  - Update line 75: `# 31 local skills` → `# 27 local skills`.
  - Update line 140: `31 local skills + 9 via plugin (40 total):` → `27 local skills + 9 via plugin (36 total):`.
    Arithmetic check: 31 − 4 = 27; 27 + 9 = 36. Confirmed.
  - Delete the four table rows (`complete-project`, `design-project`, `refine-project`, `wardley-mapping`).
- **Test cases**:
  - `grep -c "31 local skills" README.md` returns `0`.
  - `grep -c "27 local skills" README.md` returns `2` (lines 75 and 140).
  - `grep -c "40 total" README.md` returns `0`.
  - `grep -c "36 total" README.md` returns `1`.
  - `grep -c "| \`complete-project\`" README.md` returns `0`.
  - `grep -c "| \`design-project\`" README.md` returns `0`.
  - `grep -c "| \`refine-project\`" README.md` returns `0`.
  - `grep -c "| \`wardley-mapping\`" README.md` returns `0`.
  - `grep -c "| \`retro\`" README.md` still returns `1` (kept).
  - `grep -c "| \`design-studio\`" README.md` still returns `1` (kept).
- **Verify**: All nine grep counts match.
- **Complexity**: Small.

#### Phase A checkpoint

Before moving to Phase B, confirm:

- [ ] `git status` shows the expected deletions/renames/modifications and nothing unexpected.
- [ ] `git diff --stat` shows only the files enumerated in steps A.1–A.7.
- [ ] Every grep-level check in steps A.4, A.5, A.6, A.7 has been run and passed.
- [ ] `/Users/matthumanhealth/src/Panoply/strategic-context/` exists with the 5 relocated files.

---

### Phase B: CLAUDE.md cleanup

**Execution block**

- **Scope**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` and `/Users/matthumanhealth/src/Panoply/skills/system-feedback/SKILL.md`.
- **Depends on**: Phase A (specifically step A.1, because Phase B updates two references to point at the new
  `~/src/Panoply/strategic-context/` path that step A.1 creates).
- **Parallel with**: Nothing. Sequential after Phase A.
- **Gate**: Autonomous. Inspection-only verifications; no test suite to run. Matt reviews in the PR.

#### Step B.1: Remove Project lifecycle section from CLAUDE.md

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` lines 27-35 (the `## Project lifecycle` heading
  through the "Projects are in..." line and the trailing blank line).
- **Action**: Delete the entire section — heading, 3-bullet list of slash commands, and the "Projects are in
  ~/src/Panoply/projects/..." sentence. Preserve exactly one blank line between the preceding `## Planning
  workflow` section and the following `## Agent teams` section.
- **Test cases**:
  - `grep -c "## Project lifecycle" CLAUDE.md` returns `0`.
  - `grep -c "/refine-project" CLAUDE.md` returns `0`.
  - `grep -c "/design-project" CLAUDE.md` returns `0`.
  - `grep -c "/complete-project" CLAUDE.md` returns `0`.
  - `grep -c "## Planning workflow" CLAUDE.md` returns `1`.
  - `grep -c "## Agent teams" CLAUDE.md` returns `1`.
- **Verify**: All six grep counts match.
- **Complexity**: Small.

#### Step B.2: Replace `EnterPlanMode` with `Plan Mode (Shift+Tab)`

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` line 25.
- **Action**: Replace the line

  From:
  ```
  Use EnterPlanMode for multi-step tasks. Always think through the full approach before writing code.
  ```

  To:
  ```
  Use Plan Mode (Shift+Tab) for multi-step tasks. Always think through the full approach before writing code.
  ```

- **Decision rationale**: Verified above (Pre-Plan Verifications #2). `EnterPlanMode` is the internal tool name;
  `Plan Mode (Shift+Tab)` is the user-facing entry point and already in use elsewhere in the file.
- **Test cases**:
  - `grep -c "EnterPlanMode" CLAUDE.md` returns `0`.
  - `grep -c "Plan Mode (Shift+Tab)" CLAUDE.md` returns `2` (line 25 and the existing line in Data Science Projects).
- **Verify**: Both grep counts match.
- **Complexity**: Small.

#### Step B.3: Reconcile "Always push the code" with Stop-hook auto-push

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` line 16 (the "Always push the code" bullet in the
  `Working preferences` section).
- **Action**: Replace the bullet:

  From:
  ```
  - **Always push the code.** Don't describe what you'll push, don't wait for a hook, don't assume auto-commit will pick it up. After making changes that are ready for review, `git push` is the last thing you do before responding. If the push fails (e.g. divergent branches), resolve and push — don't leave it for me to chase.
  ```

  To:
  ```
  - **Always push the code.** The Stop hook auto-commits and pushes after every response as a safety net — don't rely on it. When you're in-session and have changes ready for review, `git push` is the last thing you do before responding. If the push fails (e.g. divergent branches), resolve and push — don't leave it for me to chase.
  ```

  Rationale: preserves the in-session "push before responding" discipline while acknowledging the Stop hook as a
  safety net rather than the primary mechanism. Removes the contradictory "don't wait for a hook" phrasing which
  clashes with the `Auto-commit workflow` section.
- **Test cases**:
  - `grep -c "don't wait for a hook" CLAUDE.md` returns `0`.
  - `grep -c "safety net" CLAUDE.md` returns `1`.
  - `grep -c "Always push the code" CLAUDE.md` returns `1`.
  - `grep -c "Auto-commit workflow" CLAUDE.md` returns `1` (section still exists).
- **Verify**: All four grep counts match.
- **Complexity**: Small.

#### Step B.4: Update strategic-context path in CLAUDE.md

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` line 49 (the `Context management` section).
- **Action**: Replace

  From:
  ```
  - **Strategic/domain context** → `~/src/Panoply/skills/refine-project/references/`
  ```

  To:
  ```
  - **Strategic/domain context** → `~/src/Panoply/strategic-context/`
  ```

- **Test cases**:
  - `grep -c "refine-project/references" CLAUDE.md` returns `0`.
  - `grep -c "strategic-context" CLAUDE.md` returns `1`.
- **Verify**: Both grep counts match.
- **Complexity**: Small.

#### Step B.5: Update strategic-context path in `system-feedback/SKILL.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/system-feedback/SKILL.md` line 39.
- **Action**: Replace

  From:
  ```
  | Context references | `~/src/Panoply/skills/refine-project/references/` |
  ```

  To:
  ```
  | Context references | `~/src/Panoply/strategic-context/` |
  ```

- **Test cases**:
  - `grep -c "refine-project/references" system-feedback/SKILL.md` returns `0`.
  - `grep -c "strategic-context" system-feedback/SKILL.md` returns `1`.
- **Verify**: Both grep counts match.
- **Complexity**: Small.

#### Step B.6: Add `research-plan-implement` nudge to Planning workflow

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` — after the 3-step planning list in the `## Planning
  workflow` section, before the `Use Plan Mode (Shift+Tab) for multi-step tasks.` line.
- **Action**: Insert a new paragraph. Tuned per the user's emphasis that RPI is the **happy path** for non-trivial
  work — agents should recognise "meaningful chunk of work" signals early.

  Exact text to insert:
  ```
  **RPI is the happy path for non-trivial work.** If a task shows any of these signals — touches multiple files,
  spans unfamiliar code, has ambiguous requirements, or is feature-shaped rather than one-liner-shaped — suggest
  `/research-plan-implement` upfront. It runs research, planning, and implementation as separate gated phases
  (each in its own context window), so you stay in control at every handoff. Defaulting to RPI beats realising
  mid-implementation that we needed research first.
  ```

- **Placement**: Immediately after step 3 of the numbered list, as its own paragraph, with a blank line above
  and below. The existing `Use Plan Mode (Shift+Tab) for multi-step tasks...` sentence remains below.
- **Test cases**:
  - `grep -c "RPI is the happy path" CLAUDE.md` returns `1`.
  - `grep -c "/research-plan-implement" CLAUDE.md` returns `1`.
  - `grep -c "meaningful chunk" CLAUDE.md` — not required (phrasing is "touches multiple files" etc.).
- **Verify**: Both grep counts match.
- **Complexity**: Small.

#### Step B.7: Add `pr-preflight` nudge to Auto-commit workflow

- **Files**: `/Users/matthumanhealth/src/Panoply/CLAUDE.md` — the `## Auto-commit workflow` section (currently
  a single sentence).
- **Action**: Append a second paragraph to the section. Exact text:

  ```
  **Before raising a PR, suggest `/pr-preflight`.** It runs the GitHub Claude review bot's prompt locally against
  the current branch and prints a PASS/WARN/BLOCK verdict to stdout — catching issues before they hit the PR. Ask
  the user once per session when a PR is about to be raised; don't nag.
  ```

- **Test cases**:
  - `grep -c "/pr-preflight" CLAUDE.md` returns `1`.
  - `grep -c "PASS/WARN/BLOCK" CLAUDE.md` returns `1`.
  - `grep -c "don't nag" CLAUDE.md` returns `1`.
- **Verify**: All three grep counts match.
- **Complexity**: Small.

#### Phase B checkpoint

Before raising the PR:

- [ ] `git diff CLAUDE.md` is read end-to-end and makes sense as a single reviewable change.
- [ ] All grep-level checks in steps B.1-B.7 have been run and passed.
- [ ] `grep -c "refine-project\|design-project\|complete-project\|wardley-mapping" CLAUDE.md` returns `0`.
- [ ] `grep -c "refine-project\|design-project\|complete-project\|wardley-mapping" system-feedback/SKILL.md`
  returns `0`.
- [ ] No other files in the repo reference the deleted skills as active commands (other than historical plan/research
  docs, which are allowed to remain as historical record).

### Phase C: Push and raise PR

**Execution block**

- **Scope**: Git operations only.
- **Depends on**: Phase A and Phase B complete.
- **Parallel with**: Nothing.
- **Gate**: Autonomous through `gh pr create`. Matt reviews the PR.

#### Step C.1: Commit and push

- **Files**: None (git operations).
- **Action**:
  - Confirm branch: `git branch --show-current` should be `skills-claude-audit-cleanup` (or create and switch if
    on `main`).
  - `git add -A` is **not** used — stage explicitly by path:
    - All deletions from Phase A (three skill dirs, ghost dir).
    - The relocated strategic-context files.
    - Modified files: `README.md`, `CLAUDE.md`, `organise-repo/SKILL.md`, `design-studio/SKILL.md`,
      `retro/SKILL.md`, `system-feedback/SKILL.md`,
      `docs/plans/2026-04-17-consolidate-review-skills-plan.md`.
  - Commit with message:
    ```
    cleanup: skills/CLAUDE.md audit pass

    - Deprecate project-lifecycle skills superseded by RPI (complete-project, refine-project, design-project)
    - Remove wardley-mapping ghost dir
    - Relocate strategic-context references out of refine-project
    - Trim Hubris knowledge-migration section from organise-repo
    - Add missing name: frontmatter to design-studio and retro
    - Remove Project lifecycle section from CLAUDE.md
    - Reconcile always-push rule with Stop-hook auto-push
    - Replace EnterPlanMode ref with Plan Mode (Shift+Tab)
    - Add pr-preflight and research-plan-implement nudges
    - Fix test-case contradiction in consolidate-review-skills plan doc
    - Update README local-skill count 31→27
    ```
  - `git push -u origin skills-claude-audit-cleanup`.
- **Verify**: `git log -1 --stat` shows the commit with all expected files; `git status` clean.
- **Complexity**: Small.

#### Step C.2: Open PR

- **Files**: None (gh operation).
- **Action**:
  ```bash
  gh pr create --base main --title "Skills + CLAUDE.md audit cleanup" --body "$(cat <<'EOF'
  ## Summary

  Post-audit cleanup pass on Panoply skills and global CLAUDE.md. See
  `docs/plans/2026-04-17-skills-claude-audit-research.md` for the full audit and
  `docs/plans/2026-04-17-skills-claude-audit-plan.md` for the implementation plan.

  **Skills**
  - Deprecate three project-lifecycle skills (`complete-project`, `refine-project`, `design-project`) — superseded by `/research-plan-implement`.
  - Delete empty `wardley-mapping/` directory.
  - Relocate strategic-context `references/` out of `refine-project/` into `strategic-context/` (preserved, not deleted).
  - Trim Hubris knowledge-migration section from `organise-repo/SKILL.md`.
  - Add missing `name:` frontmatter to `design-studio` and `retro`.

  **CLAUDE.md**
  - Remove `Project lifecycle` section (three slash-command references no longer exist).
  - Reconcile "Always push the code" rule with Stop-hook auto-push (no longer contradicts itself).
  - Replace `EnterPlanMode` with `Plan Mode (Shift+Tab)` (user-facing entry point).
  - Add two skill nudges: `/research-plan-implement` (for non-trivial work, happy path) and `/pr-preflight` (before PR push).

  **Docs**
  - Update `README.md` local skill count 31→27.
  - Fix test-case contradiction in `2026-04-17-consolidate-review-skills-plan.md:218`.

  ## Test plan

  - [ ] Start a fresh Claude Code session; confirm no startup warnings about missing skills.
  - [ ] Run `claude /research-plan-implement` — confirm it resolves (sanity check on RPI availability).
  - [ ] Verify `ls ~/src/Panoply/strategic-context/` shows the 5 relocated files.
  - [ ] Verify `ls ~/src/Panoply/skills/` does not list the four deleted directories.
  - [ ] Read the updated CLAUDE.md top-to-bottom; confirm no dangling references to deleted skills.

  Generated with Claude Code
  EOF
  )"
  ```
- **Verify**: `gh pr view` shows the PR with correct title, body, and base branch.
- **Complexity**: Small.

## Test Strategy

### Automated Tests

No existing test suite covers skill directory layout or CLAUDE.md content. All verification is structural
(grep-level checks against files) and manual (read-through inspection).

| Test Case                                              | Type     | Input                               | Expected Output        |
| ------------------------------------------------------ | -------- | ----------------------------------- | ---------------------- |
| No reference to deprecated skills in CLAUDE.md         | grep     | `refine-project\|design-project\|complete-project\|wardley-mapping` in CLAUDE.md | 0 matches |
| No reference to deprecated skills in system-feedback   | grep     | same pattern in `system-feedback/SKILL.md` | 0 matches |
| README count line uses `27 local skills`               | grep     | `27 local skills` in README.md      | 2 matches              |
| README has no deprecated-skill table rows              | grep     | deprecated skill names as table rows in README.md | 0 each |
| organise-repo Hubris section removed                   | grep     | `~/src/hubris/repos` in organise-repo/SKILL.md | 0 matches |
| design-studio has `name:` frontmatter                  | grep     | `^name: design-studio$` line 2      | 1 match                |
| retro has `name:` frontmatter                          | grep     | `^name: retro$` line 2              | 1 match                |
| Plan Mode phrasing replaces EnterPlanMode              | grep     | `EnterPlanMode` in CLAUDE.md        | 0 matches              |
| Plan Mode phrasing present                             | grep     | `Plan Mode (Shift+Tab)` in CLAUDE.md | 2 matches             |
| RPI nudge present                                      | grep     | `RPI is the happy path` in CLAUDE.md | 1 match               |
| pr-preflight nudge present                             | grep     | `/pr-preflight` in CLAUDE.md         | 1 match               |
| strategic-context files relocated                      | ls       | `~/src/Panoply/strategic-context/`  | 5 .md files present    |
| Phase A plan-doc fix applied                           | grep     | `only inside the scope-guardrails section` in the historical plan doc | 1 match |
| Phase A plan-doc old text gone                         | grep     | `these were dropped intentionally` in the historical plan doc | 0 matches |

### Manual Verification

- [ ] Open a fresh Claude Code session. Confirm no warnings/errors about missing skill directories.
- [ ] Read through the updated CLAUDE.md from top to bottom; the two nudges read naturally and the "always push"
  bullet no longer contradicts the Stop-hook paragraph.
- [ ] Verify that `/retro`, `/brainstorming`, `/documenting-decisions` still invoke normally (they were not touched).
- [ ] Attempt `/refine-project` — confirm it no longer resolves. This is the **desired** state.
- [ ] Confirm the relocated strategic-context files render the same content as before by opening one
  (e.g. `organization.md`).

## Risks and Mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Strategic-context `references/` content lost during skill deletion | HIGH (loses Matt's real context) | Step A.1 explicitly relocates before A.3 deletes. Git tracks the moves as renames. |
| Other files reference deprecated skills that we missed | MEDIUM (dangling references) | Phase B checkpoint runs a repo-wide grep for all four deprecated skill names; investigate any hit before merging. |
| Auto-push Stop hook triggers mid-phase and creates noisy intermediate commits | LOW | Expected and acceptable — auto-commits on a feature branch are fine; they get squashed on PR merge. |
| README arithmetic wrong | LOW | Arithmetic re-verified in step A.7 (31 − 4 = 27, 27 + 9 = 36). Grep check catches any typo. |
| `Plan Mode (Shift+Tab)` is wrong entry point | LOW | Verified (Pre-Plan Verifications #2) against existing in-file usage at line 66. |
| New `strategic-context/` path conflicts with existing files | LOW | Checked directory does not currently exist; `mkdir -p` creates idempotently; `git mv` into fresh directory. |
| Historical plan-doc fix (Phase A, step A.6) causes confusion in the old plan's approval trail | VERY LOW | Plan doc is dated and represents a historical record. The fix corrects a known contradiction and improves future re-reads. |

## Rollback Strategy

All changes are on a feature branch. Rollback options:

- **Per-step rollback**: `git restore --staged <file>` + `git checkout -- <file>` for any file that goes wrong
  mid-implementation.
- **Phase rollback**: `git reset --hard <phase-start-commit>` on the branch.
- **Full rollback**: close the PR unmerged and delete the branch. No merge → no impact on `main` or other sessions.

No production deployment is involved. No state is mutated outside of the repo's working tree.

## Follow-Ups (Not In Scope)

Flagged during planning; **not** actioned in this PR:

1. `~/src/Panoply/projects/` contains two live projects (`feature-launch-push`, `zd-symptom-decisions`). The user
   explicitly said not to delete these. They remain as-is. Worth a future decision: archive, delete, or keep
   indefinitely as historical artifacts.
2. `~/src/hubris/CLAUDE.md:11` references a non-existent `~/.claude/MEMORY.md`. Internal to the `hubris` repo;
   does not affect Panoply. Fix if Matt still uses hubris.
3. The `Data Science Projects` section in CLAUDE.md is long and repo-specific (`analytics`, `datascience`). The
   audit recommended moving it to per-repo `.claude/rules/data-science.md`. Non-trivial refactor; deferred
   pending explicit decision.
4. `pr-preflight/SKILL.md:163` mentions "now-deleted `/review` skill" — accurate today, will read oddly once the
   `/review` removal fades from memory. Low-priority cosmetic.

## Status

- [ ] Plan approved
- [ ] Implementation started
- [ ] Phase A complete
- [ ] Phase B complete
- [ ] Phase C complete (PR raised)
- [ ] PR merged
