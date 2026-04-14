# Plan: rpikit-fork (2026-04-14)

## Summary

Fork the rpikit Claude Code plugin (16 skills, 7 agents) from
`~/.claude/plugins/cache/rpikit/rpikit/0.8.0/` into `~/src/Panoply/` as the
sole source of truth, rewrite all 8 runtime-breaking `rpikit:`-prefixed Skill
invocations (plus descriptive mentions) to bare names, fix the pre-existing
`code-reviewer.md` skill-name bug, document the `.claude/rules/` pattern as
the standard for repo-specific convention overrides, and cleanly uninstall
the plugin along with all of its tracked and runtime configuration. The
fork happens in-session so the user can verify `/brainstorming` (user-tier)
and `/rpikit:brainstorming` (plugin-tier) coexist before the plugin is pulled.

## Stakes Classification

**Level**: Medium.

**Rationale**: Touches the user's global skill/agent ecosystem — every Claude
Code session in every repo runs against the output of this plan. A broken
skill body or a missed `rpikit:` reference breaks the RPI pipeline silently
mid-run. The change is, however, bounded: the skill files already exist and
work in the plugin, the precedence rules are documented, and every step has a
filesystem-level check. Rollback is straightforward until Phase 5 (manual
config cleanup); after that, reinstalling the plugin is one `claude plugin
install` away. Phased verification contains blast radius.

## Context

**Research**: `/Users/matthumanhealth/src/Panoply/docs/plans/2026-04-14-rpikit-fork-research.md`
(single source of truth — do not re-research).

**Affected Areas**:

- `/Users/matthumanhealth/src/Panoply/skills/` — 16 new skill folders
- `/Users/matthumanhealth/src/Panoply/agents/` — new directory, 7 files
- `/Users/matthumanhealth/src/Panoply/setup.sh:16` — `SYMLINK_ITEMS` gains `agents`
- `/Users/matthumanhealth/src/Panoply/settings.json:29-41` — remove plugin + marketplace entries
- `/Users/matthumanhealth/src/Panoply/.claude/settings.local.json:19-20` — remove plugin cache Read perms
- `/Users/matthumanhealth/src/Panoply/README.md:75,139,161-170,180` — remove plugin install copy; add `.claude/rules/` note
- `/Users/matthumanhealth/.claude/agents/` — new symlink on this machine
- `~/.claude/plugins/cache/rpikit/`, `~/.claude/plugins/marketplaces/rpikit/` — force-removed

**Repo state confirmed at plan time**:

- `~/src/Panoply/skills/` has 16 existing skills, none collide with the 16 rpikit skill names.
- `~/src/Panoply/agents/` does NOT exist (confirmed clean).
- `~/.claude/agents` symlink does NOT exist (confirmed clean).
- Panoply has its own root `CLAUDE.md` (no `AGENTS.md`). rpikit's `AGENTS.md` and the `CLAUDE.md → AGENTS.md` symlink pattern is plugin-specific and will NOT be copied. Panoply's existing `CLAUDE.md` stays authoritative, and no `AGENTS.md` will be created (decision below in §Assumptions).

## Success Criteria

- [ ] All 16 skill folders exist at `~/src/Panoply/skills/<name>/SKILL.md` with content byte-identical to plugin source (no trailing diffs).
- [ ] All 7 agent files exist at `~/src/Panoply/agents/<name>.md`.
- [ ] `setup.sh:16` includes `agents` in `SYMLINK_ITEMS`; `~/.claude/agents` symlink exists on this machine and resolves to `~/src/Panoply/agents`.
- [ ] All 8 runtime `rpikit:<name>` Skill-tool invocations in `research-plan-implement/SKILL.md`, `implementing-plans/SKILL.md`, and `writing-plans/SKILL.md` are rewritten to bare names.
- [ ] All descriptive `rpikit:` mentions listed in research §3 table 2 are updated to bare-name references.
- [ ] `code-reviewer.md` lines 18, 44, 59, 80 reference `reviewing-code` (not `code-review`).
- [ ] `/brainstorming` (user-tier) works while `/rpikit:brainstorming` (plugin-tier) is still installed — both coexist.
- [ ] End-to-end RPI pipeline runs via user-tier skills (research → plan → implement chain invocation succeeds) with plugin still installed.
- [ ] `.claude/rules/*.md` with `paths:` frontmatter pattern is documented in `README.md` (or `docs/`).
- [ ] Plugin is disabled via CLI, then uninstalled; `settings.json` no longer contains `rpikit@rpikit` or `extraKnownMarketplaces.rpikit`; `.claude/settings.local.json` no longer contains plugin cache Read permissions; `README.md` plugin-install copy is removed.
- [ ] `~/.claude/plugins/cache/rpikit/` and `~/.claude/plugins/marketplaces/rpikit/` directories no longer exist.
- [ ] After Claude Code restart, `/brainstorming` still works, `/rpikit:brainstorming` is gone, and no rpikit grep hits in `settings.json`, `.claude/settings.local.json`, or `README.md`.
- [ ] Each phase pushed to `main` via auto-commit hook (per user's "always push the code" rule).

## Assumptions

1. **AGENTS.md omitted on fork.** Research §Open Questions Q1 asked whether Panoply should have its own `AGENTS.md` with rewritten content. Decision: **omit it entirely**. Panoply already has a root `CLAUDE.md` (the authoritative instructions file for this repo). Copying rpikit's `AGENTS.md` would inject the Beads `bd prime`/`bd close` block into every Panoply session — that is the bug the user flagged. Writing a bespoke Panoply `AGENTS.md` duplicates `CLAUDE.md`. Simplest-thing-that-works: skip the file.
2. **`.claude-code-version` omitted.** Research §Open Questions Q2 flagged this file for confirmation. Decision: **skip it**. The version constraint is plugin-manifest metadata; user-level skill folders have no equivalent mechanism and the file has no runtime role outside a plugin context. Skip without investigation — if a skill body ever references a minimum version, that reference survives the copy untouched.
3. **`web-researcher` tool access.** Research §Open Questions Q4 flagged that the agent has `WebSearch`/`WebFetch` declared. `.claude/settings.local.json` already contains broad `WebFetch`/`WebSearch` allow entries (lines 23-24 of the current file), so tool access is not path-scoped to the plugin cache and does not need rewiring. Confirm during Phase 1 verification by running `/web-researcher` (or spawning the agent) after the fork.
4. **`pluginConfigs.rpikit` is absent.** Research §Technical Constraint 6 asks to verify. Plan verifies with a `python3 -c` one-liner in Phase 5 before declaring cleanup done. If present, remove it in the same edit.
5. **Hot reload works via symlinked skills dir.** Research §Open Questions Q5. macOS FSEvents follow symlinks for directory watches; the existing Panoply skills already demonstrate this works. Verification in Phase 1 confirms empirically.
6. **`enabledPlugins: false` bug still present.** Research §6 Known Bugs lists three CLI-side issues. Plan assumes all three are still live and relies on manual file editing to close the loop, regardless of fix status.
7. **Auto-commit hook handles pushes.** User's CLAUDE.md states changes are auto-committed and pushed by the Stop hook. Plan does NOT explicitly run `git add`/`git push` between steps but DOES verify the hook ran (via `git log --oneline -3` showing expected commits) at each phase checkpoint.

## Implementation Steps

### Phase 1: Fork skills + agents, wire up symlinks, verify discoverability

**Goal**: User-tier skills/agents coexist with the still-installed plugin. No user-facing behaviour change yet.

**Rollback for whole phase**: Delete copied files (`rm -rf ~/src/Panoply/agents` and delete the 16 copied skill dirs — none collide with Panoply's existing 16 skills, so deletion by name is safe), revert `setup.sh`, remove the `~/.claude/agents` symlink. No config has been edited yet; state returns to pre-fork.

#### Step 1.1: Create agents directory and copy all 7 agent files

- **Files**: `/Users/matthumanhealth/src/Panoply/agents/` (new)
- **Action**:
  ```bash
  mkdir -p /Users/matthumanhealth/src/Panoply/agents
  cp /Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/agents/*.md \
     /Users/matthumanhealth/src/Panoply/agents/
  ```
- **Verify**:
  ```bash
  ls /Users/matthumanhealth/src/Panoply/agents/ | sort
  ```
  Expected output (exactly):
  ```
  code-reviewer.md
  debugger.md
  file-finder.md
  security-reviewer.md
  test-runner.md
  verifier.md
  web-researcher.md
  ```
- **Complexity**: Small

#### Step 1.2: Copy all 16 skill folders

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/<name>/SKILL.md` (16 new)
- **Action**:
  ```bash
  for d in /Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/skills/*/; do
    name=$(basename "$d")
    mkdir -p "/Users/matthumanhealth/src/Panoply/skills/$name"
    cp "$d/SKILL.md" "/Users/matthumanhealth/src/Panoply/skills/$name/SKILL.md"
  done
  ```
- **Verify**:
  ```bash
  ls /Users/matthumanhealth/src/Panoply/skills/ | wc -l
  ```
  Expected: `32` (16 existing Panoply skills + 16 rpikit skills).
  ```bash
  for s in brainstorming documenting-decisions finishing-work git-worktrees implementing-plans parallel-agents receiving-code-review research-plan-implement researching-codebase reviewing-code security-review synthesizing-research systematic-debugging test-driven-development verification-before-completion writing-plans; do
    test -f "/Users/matthumanhealth/src/Panoply/skills/$s/SKILL.md" || echo "MISSING: $s"
  done
  ```
  Expected: no output (all present).
- **Complexity**: Small

#### Step 1.3: Confirm no unintended extra files were copied

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/<name>/` (all 16 forked)
- **Action**: Research §2 notes `tests/test-skills.sh:81-85` fails if extras are present. Verify only `SKILL.md` exists in each folder (plugin source is already clean, but confirm the copy didn't pick up anything rogue).
- **Verify**:
  ```bash
  for s in brainstorming documenting-decisions finishing-work git-worktrees implementing-plans parallel-agents receiving-code-review research-plan-implement researching-codebase reviewing-code security-review synthesizing-research systematic-debugging test-driven-development verification-before-completion writing-plans; do
    contents=$(ls "/Users/matthumanhealth/src/Panoply/skills/$s/")
    if [ "$contents" != "SKILL.md" ]; then echo "UNEXPECTED in $s: $contents"; fi
  done
  ```
  Expected: no output.
- **Complexity**: Small

#### Step 1.4: Update `setup.sh:16` to include `agents` in `SYMLINK_ITEMS`

- **Files**: `/Users/matthumanhealth/src/Panoply/setup.sh:16`
- **Action**: Change line 16 from
  ```bash
  SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills)
  ```
  to
  ```bash
  SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills agents)
  ```
- **Verify**:
  ```bash
  grep "^SYMLINK_ITEMS=" /Users/matthumanhealth/src/Panoply/setup.sh
  ```
  Expected: `SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills agents)`
- **Complexity**: Small

#### Step 1.5: Create the `~/.claude/agents` symlink manually on this machine

- **Files**: `/Users/matthumanhealth/.claude/agents` (new symlink)
- **Action**:
  ```bash
  ln -s /Users/matthumanhealth/src/Panoply/agents /Users/matthumanhealth/.claude/agents
  ```
  (setup.sh only runs on new-machine setup; this machine needs the one-off.)
- **Verify**:
  ```bash
  readlink /Users/matthumanhealth/.claude/agents
  ```
  Expected: `/Users/matthumanhealth/src/Panoply/agents`
  ```bash
  ls /Users/matthumanhealth/.claude/agents/ | wc -l
  ```
  Expected: `7`
- **Complexity**: Small
- **Rollback**: `rm /Users/matthumanhealth/.claude/agents` (deletes the symlink, not the target).

#### Step 1.6: Phase 1 verification checkpoint — discoverability and coexistence

- **Files**: N/A (manual verification inside Claude Code)
- **Action**: Manual checks in the current Claude Code session (or fresh one — hot reload should pick up the new `SKILL.md` files since the `~/.claude/skills/` directory already exists per research §4).
- **Manual test cases**:
  1. List available skills: user should see the 16 rpikit-named skills appear without the `rpikit:` prefix in the current session's skill catalogue (check via skill auto-discovery output or attempt to invoke one).
  2. Invoke `/brainstorming` (bare name) — should launch the user-tier skill (now sourced from `~/src/Panoply/skills/brainstorming/SKILL.md`). Precedence rule per research §4 means user-tier wins over plugin.
  3. Invoke `/rpikit:brainstorming` (plugin-tier namespace) — should still launch the plugin version. Both coexist because the namespaces are distinct.
  4. Spawn the `web-researcher` agent (or `/web-researcher`-equivalent invocation) and confirm `WebSearch`/`WebFetch` tools are available — validates Assumption 3.
  5. Spawn the `file-finder` agent on a simple query — validates the new agents symlink resolves.
- **Verify**: All 5 manual checks pass. If (1) or (2) fail, the skills dir hot-reload assumption is wrong and a Claude Code restart is needed before proceeding.
- **Complexity**: Medium
- **Rollback if fails**: No restart? Exit and restart Claude Code, retest. Still failing? Revert Steps 1.1-1.5 and investigate the symlink/watcher interaction before proceeding.

#### Step 1.7: Confirm auto-commit pushed Phase 1

- **Files**: N/A
- **Action**: `cd /Users/matthumanhealth/src/Panoply && git log --oneline -5`
- **Verify**: Recent commit(s) show the skill/agent/setup.sh additions pushed to origin. If not pushed, `git push` manually.
- **Complexity**: Small

---

### Phase 2: Rewrite `rpikit:` references; fix code-reviewer bug

**Goal**: Forked skills run standalone without the `rpikit:` prefix. Silent-failure landmines removed before Phase 4 plugin disable.

**Rollback for whole phase**: `git revert` the Phase 2 commits. Forked skills retain old `rpikit:` references (still work because plugin is still installed) — state returns to end of Phase 1.

#### Step 2.1: Rewrite the 5 `rpikit:` Skill-tool invocations in `research-plan-implement/SKILL.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/research-plan-implement/SKILL.md`
- **Action**: Edit each of these lines (per research §3 table 1):
  - Line 91: `rpikit:researching-codebase` → `researching-codebase`
  - Line 142: `rpikit:synthesizing-research` → `synthesizing-research`
  - Line 189: `rpikit:writing-plans` → `writing-plans`
  - Line 238: `rpikit:implementing-plans` → `implementing-plans`
  - Line 294: `rpikit:brainstorming` → `brainstorming`
- **Verify**:
  ```bash
  grep -n "rpikit:" /Users/matthumanhealth/src/Panoply/skills/research-plan-implement/SKILL.md
  ```
  Expected: matches only on descriptive lines 62-63 (handled in Step 2.4); no matches on lines 91, 142, 189, 238, 294.
- **Complexity**: Small

#### Step 2.2: Rewrite `rpikit:writing-plans` invocation in `implementing-plans/SKILL.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/implementing-plans/SKILL.md:55`
- **Action**: Change `rpikit:writing-plans` to `writing-plans` on line 55.
- **Verify**:
  ```bash
  sed -n '55p' /Users/matthumanhealth/src/Panoply/skills/implementing-plans/SKILL.md
  ```
  Expected: line does NOT contain `rpikit:`.
- **Complexity**: Small

#### Step 2.3: Rewrite `rpikit:implementing-plans` + old `rpikit:implement` alias in `writing-plans/SKILL.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/writing-plans/SKILL.md:354,358`
- **Action**:
  - Line 358: `rpikit:implementing-plans` → `implementing-plans`
  - Line 354: the old alias `rpikit:implement` is a transition note per research §3 note — remove the `rpikit:` prefix (leaving `implement`) OR rewrite the sentence to reference `implementing-plans` if the surrounding text makes more sense that way. Judgement call at edit time; priority is no dangling `rpikit:` reference remains on this line.
- **Verify**:
  ```bash
  grep -n "rpikit:" /Users/matthumanhealth/src/Panoply/skills/writing-plans/SKILL.md
  ```
  Expected: only match (if any) is on descriptive line 134 (handled in Step 2.4).
- **Complexity**: Small

#### Step 2.4: Update descriptive `rpikit:` mentions across six files

Per research §3 table 2 these are not runtime-breaking but should be fixed (user's "Fix it while you're here" rule).

- **Files**:
  - `/Users/matthumanhealth/src/Panoply/skills/research-plan-implement/SKILL.md:62-63` — text refs to `rpikit:writing-plans`, `rpikit:implementing-plans`
  - `/Users/matthumanhealth/src/Panoply/skills/implementing-plans/SKILL.md:52-53,77` — prereq notes for `rpikit:researching-codebase`, `rpikit:writing-plans`
  - `/Users/matthumanhealth/src/Panoply/skills/writing-plans/SKILL.md:134` — ref to `rpikit:test-driven-development`
  - `/Users/matthumanhealth/src/Panoply/skills/brainstorming/SKILL.md:211-212` — workflow pointers `/rpikit:researching-codebase`, `/rpikit:writing-plans`
  - `/Users/matthumanhealth/src/Panoply/skills/documenting-decisions/SKILL.md:217` — workflow diagram with three `rpikit:` refs
  - `/Users/matthumanhealth/src/Panoply/skills/git-worktrees/SKILL.md:24` — "/rpikit:git-worktrees" user-invocation example
- **Action**: In each file, strip the `rpikit:` prefix from every matched reference at those lines. Preserve surrounding formatting (slashes, code ticks, descriptive wording).
- **Verify**:
  ```bash
  grep -rn "rpikit:" /Users/matthumanhealth/src/Panoply/skills/
  ```
  Expected: no output. Every `rpikit:` reference across the 16 forked skill files is now gone.
- **Complexity**: Small

#### Step 2.5: Fix the `code-reviewer.md` pre-existing skill-name bug

- **Files**: `/Users/matthumanhealth/src/Panoply/agents/code-reviewer.md:18,44,59,80`
- **Action**: Change `code-review` → `reviewing-code` at each of the four listed lines. Per research §8, the skill `code-review` does not exist — the correct skill is `reviewing-code` (renamed per the plugin's `CHANGELOG.md:161`). Agent references are descriptive, not programmatic, but the inaccuracy compounds as new sessions reference it.
- **Verify**:
  ```bash
  grep -n "code-review" /Users/matthumanhealth/src/Panoply/agents/code-reviewer.md
  ```
  Expected: zero matches for bare `code-review` (i.e. only `reviewing-code` and the file's own `code-reviewer` name appear; no stale `code-review` token).
  Stricter form (recommended):
  ```bash
  grep -nE "(^|[^-])code-review([^-r]|$)" /Users/matthumanhealth/src/Panoply/agents/code-reviewer.md
  ```
  Expected: no matches.
- **Complexity**: Small

#### Step 2.6: Cross-check for `rpikit:` references anywhere under agents/ and skills/

- **Files**: N/A
- **Action**:
  ```bash
  grep -rn "rpikit:" /Users/matthumanhealth/src/Panoply/skills/ /Users/matthumanhealth/src/Panoply/agents/
  ```
- **Verify**: No matches. If any surface, fix them inline before proceeding.
- **Complexity**: Small

#### Step 2.7: Phase 2 end-to-end verification — run the RPI pipeline via user-tier skills

- **Files**: N/A (manual verification inside Claude Code)
- **Action**: User invokes the forked pipeline while the plugin is still installed (plugin-tier is shadowed by user-tier per research §4). Trigger the chained RPI pipeline on a trivial target topic so each hop — research-plan-implement → researching-codebase → synthesizing-research → writing-plans → implementing-plans — actually executes a Skill-tool invocation of the bare name.
- **Manual test cases**:
  1. User invokes `/research-plan-implement` with a trivial task (e.g. "rename a doc file"). The orchestrator skill should spawn subagents targeting `researching-codebase`, `synthesizing-research`, `writing-plans`, `implementing-plans` by bare name. If any fail to resolve, a `rpikit:` reference was missed in Step 2.1.
  2. Independently, user invokes `/writing-plans trivial-test` (even without prior research) and confirms the skill body doesn't crash with a missing-skill error when it references `implementing-plans`.
  3. User invokes `/implementing-plans` on a trivial approved plan and confirms it references `writing-plans` by bare name in any prereq checks.
- **Verify**: All three runs complete without "skill not found" errors on any `rpikit:`-flavoured invocation. If any fail, audit the offending SKILL.md with `grep -n rpikit` and fix.
- **Complexity**: Medium
- **Rollback if fails**: Re-grep the failing file; fix in place. Do NOT proceed to Phase 4 until Phase 2.7 is green.

#### Step 2.8: Confirm auto-commit pushed Phase 2

- **Files**: N/A
- **Action**: `cd /Users/matthumanhealth/src/Panoply && git log --oneline -5`
- **Verify**: Recent commits include the skill/agent edits. If not pushed, `git push`.
- **Complexity**: Small

---

### Phase 3: Document the `.claude/rules/` pattern

**Goal**: Standard for repo-specific override conventions is captured in Panoply so future repos adopt the same pattern rather than reinventing it per repo.

**Rollback for whole phase**: `git revert` — the change is documentation-only.

#### Step 3.1: Add a short `.claude/rules/` section to `README.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/README.md` (insert after the "Skills" section, before "Customising After Forking" — roughly around line 181)
- **Action**: Add a new H2 section `## Per-Repo Convention Overrides` explaining:
  - Skills at project level (`.claude/skills/`) do NOT shadow user-level skills (architectural — see research §4 and §5).
  - Per-repo convention overrides go in `.claude/rules/<name>.md` with optional `paths:` frontmatter for path-scoped loading.
  - Worked example: a repo that wants a different testing fixture style creates `.claude/rules/testing.md` with `paths: ["tests/**"]` frontmatter, containing repo-specific runner invocation + fixture conventions. The global `test-driven-development` skill continues to supply the RED-GREEN-REFACTOR methodology; the rule supplies the repo-specific mechanics. Additive, not override.
  - Include the 10-line sample frontmatter block from research §5.
  - One-line link to the Claude Code memory docs (`code.claude.com/docs/en/memory`).
- **Verify**:
  ```bash
  grep -n "Per-Repo Convention Overrides" /Users/matthumanhealth/src/Panoply/README.md
  ```
  Expected: one match. Open the file and eyeball the new section for readability and that the sample frontmatter block is correct YAML.
- **Complexity**: Small

#### Step 3.2: Confirm Phase 3 pushed

- **Action**: `cd /Users/matthumanhealth/src/Panoply && git log --oneline -3`
- **Verify**: README.md edit shows in the log and on origin.
- **Complexity**: Small

---

### Phase 4: Disable plugin (non-destructive transitional state)

**Goal**: Plugin stops loading. User-tier skills are now the only path. This is still reversible — `claude plugin enable rpikit@rpikit` restores it.

**Rollback for whole phase**: `claude plugin enable rpikit@rpikit`. User-tier skills still work (they're independent); plugin resumes with `/rpikit:<name>` again.

#### Step 4.1: Disable the plugin via CLI

- **Files**: N/A (CLI command mutates runtime state)
- **Action**: Run (outside Claude Code, in user's shell):
  ```bash
  claude plugin disable rpikit@rpikit
  ```
- **Verify**: CLI prints success. Then:
  ```bash
  claude plugin list
  ```
  Expected: `rpikit@rpikit` listed as disabled (or absent from active set). If the command does not report expected status, check `~/.claude/plugins/installed_plugins.json` for the plugin's `enabled: false` flag.
- **Complexity**: Small

#### Step 4.2: Phase 4 verification — user-tier still works; plugin-tier is gone

- **Files**: N/A (manual verification)
- **Action**: In a fresh Claude Code session:
- **Manual test cases**:
  1. Invoke `/brainstorming` — should launch user-tier skill (sourced from `~/src/Panoply/skills/brainstorming/SKILL.md`).
  2. Invoke `/rpikit:brainstorming` — should NOT resolve (plugin is disabled). Expected: "skill not found" or similar error.
  3. Trigger an agent the pipeline spawns (e.g. `file-finder`) and confirm it resolves to the user-tier agent at `~/src/Panoply/agents/file-finder.md`.
  4. Run any one of the skills that had `rpikit:` cross-references fixed in Phase 2 (e.g. `/writing-plans`) and confirm no "skill not found" errors when it Skill-tool-invokes `implementing-plans`.
- **Verify**: All four checks pass. If (2) still resolves, the plugin didn't disable — investigate `installed_plugins.json`.
- **Complexity**: Medium
- **Rollback if fails**: `claude plugin enable rpikit@rpikit`, investigate why the user-tier fallback broke, fix, retry.

---

### Phase 5: Uninstall plugin + manual config cleanup

**Goal**: All rpikit entries removed from tracked files and runtime plugin registry. Plugin can no longer auto-reinstall.

**Rollback for whole phase**: Reinstalling the plugin requires `claude plugin marketplace add bostonaholic/rpikit` then `claude plugin install rpikit@rpikit` AND restoring the two removed tracked-config blocks (via `git revert` on the Phase 5 config commits). Fully recoverable but friction is real — do not enter Phase 5 until Phase 4 is clean.

#### Step 5.1: Uninstall the plugin via CLI

- **Files**: N/A (CLI-only; mutates `~/.claude/plugins/installed_plugins.json` and marks cache for deletion)
- **Action**:
  ```bash
  claude plugin uninstall rpikit@rpikit
  ```
- **Verify**:
  ```bash
  claude plugin list
  ```
  Expected: `rpikit@rpikit` is gone from the list.
- **Complexity**: Small

#### Step 5.2: Remove `rpikit@rpikit` and `extraKnownMarketplaces.rpikit` from `settings.json`

- **Files**: `/Users/matthumanhealth/src/Panoply/settings.json`
- **Action**: Edit the file to remove two things:
  1. Lines 29-33: remove the `"rpikit@rpikit": true,` entry inside `enabledPlugins`. Preserve the `"dbt-skills@data-engineering-skills": true` and `"github@claude-plugins-official": true` entries. Fix trailing comma on the final remaining entry.
  2. Lines 34-41: remove the entire `"extraKnownMarketplaces": { "rpikit": { ... } }` block. If `extraKnownMarketplaces` has no other entries after removal, remove the empty key entirely.
- **Verify**:
  ```bash
  grep -n "rpikit" /Users/matthumanhealth/src/Panoply/settings.json
  ```
  Expected: no output.
  ```bash
  python3 -m json.tool /Users/matthumanhealth/src/Panoply/settings.json > /dev/null
  ```
  Expected: exit 0 (file is valid JSON).
- **Complexity**: Small

#### Step 5.3: Verify no `pluginConfigs.rpikit` key exists

Research §Technical Constraint 6.

- **Files**: `/Users/matthumanhealth/src/Panoply/settings.json`
- **Action**:
  ```bash
  python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/src/Panoply/settings.json'))); print(d.get('pluginConfigs', 'NOT PRESENT'))"
  ```
- **Verify**: Output is `NOT PRESENT` OR a dict that does NOT contain `rpikit` as a key. If `rpikit` is in the dict, remove it.
- **Complexity**: Small

#### Step 5.4: Remove plugin cache Read permissions from `.claude/settings.local.json`

- **Files**: `/Users/matthumanhealth/src/Panoply/.claude/settings.local.json:19-20`
- **Action**: Delete the two lines:
  ```
  "Read(//Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/**)",
  "Read(//Users/matthumanhealth/.claude/plugins/**)",
  ```
  Fix any trailing-comma issue on the surviving entries.
- **Verify**:
  ```bash
  grep -n "rpikit\|plugins/cache\|plugins/\*\*" /Users/matthumanhealth/src/Panoply/.claude/settings.local.json
  ```
  Expected: no output.
  ```bash
  python3 -m json.tool /Users/matthumanhealth/src/Panoply/.claude/settings.local.json > /dev/null
  ```
  Expected: exit 0.
- **Complexity**: Small

#### Step 5.5: Inspect (and if needed clean) the gitignored `~/src/Panoply/settings.local.json`

Research §Technical Constraint 5 flags that this file is machine-specific and may also hold plugin cache Read perms.

- **Files**: `/Users/matthumanhealth/src/Panoply/settings.local.json`
- **Action**:
  ```bash
  grep -n "rpikit\|plugins/cache" /Users/matthumanhealth/src/Panoply/settings.local.json
  ```
  If any matches, remove those lines (same pattern as Step 5.4) and re-validate JSON. If no matches, skip the edit.
- **Verify**: Final grep for `rpikit` against that file returns no output.
- **Complexity**: Small

#### Step 5.6: Remove plugin install/management copy from `README.md`

- **Files**: `/Users/matthumanhealth/src/Panoply/README.md:75,139,161-170,180`
- **Action**:
  - Line 75: Update "13 local skills (+ 9 via plugin)" to accurate total count after fork. Given Panoply had 16 skills + 16 forked = 32 skills in `skills/`, update the text accordingly. (Note: the "13 local skills" count in the live README.md is itself pre-rpikit and outdated — verify count on the day against `ls skills/ | wc -l` and set it to the true number. User's "leave it better than you found it" rule applies.)
  - Line 139: Update "13 local skills + 9 via plugin (22 total):" similarly.
  - Lines 161-170: Remove the entire "Installed via `claude plugin`, not stored in this repo." section covering the `claude plugin marketplace add`, `claude plugin install dbt-skills@...` and `snowflake-skills@...` commands. Note that the dbt/snowflake plugin install copy is also stale context and can be removed — user still has `dbt-skills@data-engineering-skills` in `enabledPlugins`, so that plugin is active, but the README section that documents installing it from scratch is separately cleanable. Decision: keep the dbt/snowflake plugin install copy since that plugin is still in use; remove ONLY the rpikit-specific references if any exist in this block. Re-read the block at edit time — if it's entirely about dbt/snowflake plugin (no rpikit mention), leave intact.
  - Line 180: Remove the phrase "Plugin skills are managed via `claude plugin list` / `claude plugin uninstall`." if it reads as general guidance that no longer applies, OR leave it (it's still accurate — dbt-skills is still a plugin). Judgement call on the day.
- **Verify**:
  ```bash
  grep -n "rpikit" /Users/matthumanhealth/src/Panoply/README.md
  ```
  Expected: no output.
  Skill count text (line ~75, ~139) matches `ls /Users/matthumanhealth/src/Panoply/skills/ | wc -l`.
- **Complexity**: Small

#### Step 5.7: Phase 5 verification checkpoint — no rpikit entries anywhere tracked

- **Files**: N/A
- **Action**:
  ```bash
  grep -rn "rpikit" /Users/matthumanhealth/src/Panoply/ --include="*.json" --include="*.md" --include="*.sh"
  ```
- **Verify**: Expected output contains ONLY references inside `docs/plans/2026-04-14-rpikit-fork-*.md` (the research doc and this plan — historical, intentional). Any match outside `docs/plans/` is a miss and must be fixed.
- **Complexity**: Small

#### Step 5.8: Confirm Phase 5 pushed

- **Action**: `cd /Users/matthumanhealth/src/Panoply && git log --oneline -5`
- **Verify**: Recent commits include the Phase 5 config cleanup and the commits are visible on origin.
- **Complexity**: Small

---

### Phase 6: Force-clean runtime cache, restart, final verification

**Goal**: No plugin residue on disk. Fresh Claude Code start confirms the end state.

**Rollback for whole phase**: Reinstall the plugin via marketplace + `claude plugin install` to regenerate the cache. But at this point the fork should be verified and there should be no reason to roll back.

#### Step 6.1: Force-remove plugin cache directory

- **Files**: `/Users/matthumanhealth/.claude/plugins/cache/rpikit/` (delete), `/Users/matthumanhealth/.claude/plugins/marketplaces/rpikit/` (delete)
- **Action**:
  ```bash
  rm -rf /Users/matthumanhealth/.claude/plugins/cache/rpikit
  rm -rf /Users/matthumanhealth/.claude/plugins/marketplaces/rpikit
  ```
  (Research §6 notes the CLI uninstall marks cache for deletion after a 7-day grace period; force-cleaning avoids stale content and frees the Read permission reference that was removed in Step 5.4.)
- **Verify**:
  ```bash
  ls /Users/matthumanhealth/.claude/plugins/cache/ 2>&1 | grep -c rpikit
  ls /Users/matthumanhealth/.claude/plugins/marketplaces/ 2>&1 | grep -c rpikit
  ```
  Expected: both output `0`.
- **Complexity**: Small

#### Step 6.2: Inspect `installed_plugins.json` and `known_marketplaces.json` for any lingering rpikit refs

- **Files**: `/Users/matthumanhealth/.claude/plugins/installed_plugins.json`, `/Users/matthumanhealth/.claude/plugins/known_marketplaces.json`
- **Action**:
  ```bash
  grep -l "rpikit" /Users/matthumanhealth/.claude/plugins/installed_plugins.json /Users/matthumanhealth/.claude/plugins/known_marketplaces.json 2>/dev/null
  ```
- **Verify**: No files output. If any match, open the file, remove the rpikit entry, re-validate JSON.
- **Complexity**: Small

#### Step 6.3: Restart Claude Code

- **Files**: N/A
- **Action**: Exit the current Claude Code session. Start a new one: `claude`.
- **Verify**: Session starts without warnings about missing plugins or broken references.
- **Complexity**: Small

#### Step 6.4: Final manual verification

- **Files**: N/A (manual verification in fresh session)
- **Manual test cases**:
  1. Invoke `/brainstorming` — resolves to user-tier skill, skill loads correctly.
  2. Invoke `/rpikit:brainstorming` — errors as "skill not found" (namespace gone with plugin).
  3. Invoke `/research-plan-implement` on a trivial target and observe it chains through `researching-codebase`, `synthesizing-research`, `writing-plans`, `implementing-plans` without any "skill not found" failures on chained calls.
  4. Spawn `code-reviewer` agent on any minor code diff. Confirm it runs. Confirm the agent's output references `reviewing-code` (not `code-review`) if the skill comes up in dialogue.
  5. Inspect `~/.claude/agents/` is still a live symlink to `~/src/Panoply/agents/` and contains all 7 files.
  6. Re-run the sweeping grep:
     ```bash
     grep -rn "rpikit" /Users/matthumanhealth/src/Panoply/ --include="*.json" --include="*.md" --include="*.sh" | grep -v "docs/plans/2026-04-14-rpikit-fork-"
     ```
     Expected: no output.
- **Verify**: All 6 checks pass.
- **Complexity**: Medium
- **Rollback if fails**: Target the specific failure. For (1) or (3): re-audit Phase 2 grep. For (2) still resolving: CLI plugin state is inconsistent — re-run `claude plugin uninstall rpikit@rpikit` and Phase 6 cleanup. For (4): check `code-reviewer.md` for remaining `code-review` strings.

#### Step 6.5: Close out — confirm auto-commit pushed final state

- **Action**: `cd /Users/matthumanhealth/src/Panoply && git log --oneline -5`
- **Verify**: Main branch is ahead of the pre-fork commit, all phase commits present, nothing uncommitted in working tree.
- **Complexity**: Small

---

## Test Strategy

### Automated Tests

This plan is configuration + documentation work. There is no production code being written, so the "test suite" is grep/jq/JSON-validation one-liners that gate each phase. The explicit tests are enumerated inside each step's **Verify** block rather than in an up-front table.

Summary of critical gating commands:

| Test                                                                    | Phase | Expected                                                           |
|-------------------------------------------------------------------------|-------|--------------------------------------------------------------------|
| `ls ~/src/Panoply/agents/` shows 7 files                                | 1     | Exact set matching research §2 agents table                        |
| All 16 skill dirs contain exactly `SKILL.md`                            | 1     | No output from the "extras" sweep                                  |
| `grep -rn "rpikit:" ~/src/Panoply/skills/ ~/src/Panoply/agents/`        | 2     | Empty                                                              |
| `grep -n "code-review" ~/src/Panoply/agents/code-reviewer.md` (stricter regex variant)| 2     | Empty (only `reviewing-code` / `code-reviewer` appear) |
| `python3 -m json.tool settings.json` + `.claude/settings.local.json`    | 5     | Exit 0 on both                                                     |
| `grep -rn "rpikit" ~/src/Panoply/ --include="*.json" --include="*.md" --include="*.sh"` minus `docs/plans/2026-04-14-rpikit-fork-`  | 5, 6  | Empty                                                              |
| `ls ~/.claude/plugins/cache/rpikit; ls ~/.claude/plugins/marketplaces/rpikit` | 6     | Both absent (non-zero exit)                                        |

### Manual Verification

Each phase ends with a checkpoint step (1.6, 2.7, 4.2, 6.4) that exercises end-to-end skill invocation inside Claude Code. These cannot be automated because skill discovery + invocation is an interactive runtime concern.

- [ ] **Phase 1.6**: Both `/brainstorming` (user) and `/rpikit:brainstorming` (plugin) work in the same session.
- [ ] **Phase 2.7**: `/research-plan-implement` with a trivial input completes the chain (all bare-name Skill invocations resolve).
- [ ] **Phase 4.2**: After `claude plugin disable`, `/brainstorming` works, `/rpikit:brainstorming` does not.
- [ ] **Phase 6.4**: After full uninstall + cache purge + restart, `/brainstorming` works, all 6 final checks pass.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hot reload does not pick up the 16 new skill folders in the current session (FSEvents through a symlink) | Phase 1.6 verification fails; user confused about discovery | Restart Claude Code once; research §4 confirms only the *top-level* `~/.claude/skills/` needs to pre-exist at session start, and it does. If still failing, escalate to Assumption 5 investigation. |
| A `rpikit:` reference is missed during Phase 2 edits | Silent skill-not-found failure mid RPI pipeline once plugin is uninstalled | Step 2.6 runs a sweeping grep; Step 2.7 runs the pipeline end-to-end BEFORE disable. Any miss surfaces before it can hurt. |
| `enabledPlugins` auto-reinstall bug (#28554) reintroduces the plugin on Claude Code restart | User believes plugin uninstalled; it silently reappears | Step 5.2 removes the key entirely rather than setting `false`; Step 6.1 force-cleans the cache and marketplaces; Step 6.4 explicitly verifies `/rpikit:brainstorming` does NOT resolve. |
| Marketplace entry in `settings.json` bugs re-dirty after marketplace-remove (#9537) | Settings gets stale entries added back | Manual edit in Step 5.2 is the authoritative cleanup. Step 5.7 and 6.4 re-grep to catch any re-dirtying. |
| Moving `~/src/Panoply/agents/` disrupts tool permissions for `web-researcher` (WebFetch/WebSearch) | Agent cannot make web calls after fork | `.claude/settings.local.json` already has broad `WebFetch` + `WebSearch` allow entries, not path-scoped to the plugin cache. Verify in Step 1.6 check 4. |
| JSON edits to `settings.json` or `settings.local.json` introduce a syntax error | Claude Code silently falls back to defaults, or fails to start | Steps 5.2, 5.4, 5.5 each include `python3 -m json.tool` validation immediately after the edit. |
| README.md skill count goes stale again post-edit | Minor inaccuracy, not runtime-breaking | Step 5.6 instructs the implementer to `ls skills/ | wc -l` and set the live count rather than guessing. |
| User loses muscle memory: types `/rpikit:brainstorming` from habit after Phase 4 | Failed invocations, mild friction | Temporary by design. User explicitly requested coexistence verification before uninstall. Once Phase 6 is done, "/rpikit:" is unambiguously an error and the muscle memory retrains. |

## Rollback Strategy

**Per-phase rollback** is documented in each phase header. Meta-strategy:

- **Up to end of Phase 3**: Plugin still installed and functional. Any fork-side issue can be fixed in place (delete bad file, re-copy from plugin cache). No destructive changes made to tracked config or runtime state.
- **After Phase 4 (disable)**: `claude plugin enable rpikit@rpikit` restores plugin. User-tier skills remain.
- **After Phase 5 (uninstall + config cleanup)**: Full restore requires `claude plugin marketplace add bostonaholic/rpikit` + `claude plugin install rpikit@rpikit` + `git revert` on the Phase 5 config-cleanup commits. ~5 minutes to recover.
- **After Phase 6 (cache purge + restart)**: Same as after Phase 5 — the CLI reinstall regenerates the cache. The purge is not irreversible; it's just faster than waiting 7 days.

**Nuclear rollback**: `git revert` every fork-related commit on main back to the commit before Phase 1.1. User-tier skills disappear, plugin still disabled/uninstalled — user re-enables and is back to the pre-fork state. (The auto-commit hook pushes each response, so the git history is granular enough to cherry-pick a safe revert target.)

## Status

- [ ] Plan approved
- [ ] Implementation started
- [ ] Implementation complete
