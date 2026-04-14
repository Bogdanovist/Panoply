# Research: rpikit Fork into Panoply (2026-04-14)

## Problem Statement

The rpikit Claude Code plugin (version 0.8.0, by Matthew Boston, MIT licence) provides 16 skills and 7 agents currently
installed from the marketplace (`bostonaholic/rpikit` on GitHub). The goal is to absorb those skills and agents into
the Panoply dotfiles repo (`~/src/Panoply/`) as source-of-truth, then cleanly uninstall the marketplace plugin.

After the fork:
- Skills are invoked as `/brainstorming`, `/researching-codebase`, etc. (no `rpikit:` prefix)
- Agents are available under the same names (no namespace)
- The plugin is gone from `~/.claude/plugins/`, `settings.json`, and all related config
- Panoply is the only source of truth — skills can be edited, versioned, and customised in-repo

Out of scope: `~/src/tend-to-do`. Do not plan for it.

---

## Requirements

1. All 16 rpikit skills land under `~/src/Panoply/skills/<skill-name>/SKILL.md` and are discovered via the existing
   `~/.claude/skills → ~/src/Panoply/skills/` symlink — no `setup.sh` change needed for skills.
2. All 7 rpikit agents land under `~/src/Panoply/agents/<agent-name>.md`. A new `agents` entry must be added to
   `SYMLINK_ITEMS` in `setup.sh` and a manual symlink created on this machine.
3. Eight `rpikit:` prefixed Skill invocations inside SKILL.md bodies must be rewritten to bare names — they will
   silently fail otherwise.
4. Plugin config must be fully removed from `settings.json` (tracked) and `.claude/settings.local.json` (also
   tracked), plus runtime files.
5. Per-repo testing convention overrides must use `.claude/rules/` with path-scoped frontmatter, not
   `.claude/skills/` (project skills lose to user skills — they do not override).

---

## Findings

### 1. Panoply Wiring and Landing Paths

#### How `~/.claude/` is structured

`~/.claude/` is a regular directory managed by Claude Code's runtime — NOT a wholesale symlink to Panoply. `setup.sh`
creates individual symlinks for exactly four items (`setup.sh:16`):

```bash
SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills)
```

Live state confirmed:

| `~/.claude/` entry         | Type    | Points to                                      |
|----------------------------|---------|------------------------------------------------|
| `CLAUDE.md`                | symlink | `~/src/Panoply/CLAUDE.md`                      |
| `settings.json`            | symlink | `~/src/Panoply/settings.json`                  |
| `settings.local.json`      | symlink | `~/src/Panoply/settings.local.json`            |
| `hooks`                    | symlink | `~/src/Panoply/hooks/`                         |
| `skills`                   | symlink | `~/src/Panoply/skills/`                        |

`settings.local.json` is handled separately (`setup.sh:37–57`): copies example template if absent, then symlinks
result into `~/.claude/settings.local.json`.

There is **no `agents/` symlink** in `setup.sh`. A new entry is required.

#### Skills landing path

`~/.claude/skills/` is already symlinked to `~/src/Panoply/skills/`. Each subdirectory with a `SKILL.md` is
auto-discovered. **No `setup.sh` change is needed** for skills.

Namespace rule: skills under `~/.claude/skills/` are invoked by bare folder name, with no prefix. The `rpikit:`
prefix is a plugin-only feature derived from `plugin.json → name`. After fork, `/rpikit:brainstorming` becomes
`/brainstorming`.

Name collision check: none of the 16 rpikit skill names collide with the 16 existing Panoply skill folders.

#### Agents landing path

No `agents/` directory currently exists anywhere in Panoply or under `~/.claude/` outside the plugin cache.

Target: `~/src/Panoply/agents/<agent-name>.md`

Required change to `setup.sh:16`:
```bash
SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills agents)
```

On the current machine, run manually after creating the directory:
```bash
ln -s ~/src/Panoply/agents ~/.claude/agents
```

### 2. Full Inventory

#### Skills (16 total) — each is one file only: `SKILL.md`

Source: `~/.claude/plugins/cache/rpikit/rpikit/0.8.0/skills/`

| Skill folder name                | Lines | Role                                              |
|----------------------------------|-------|---------------------------------------------------|
| `brainstorming`                  | 272   | Creative exploration before research              |
| `documenting-decisions`          | 252   | Write ADRs to `docs/decisions/`                  |
| `finishing-work`                 | 280   | Merge / PR / discard after implementation         |
| `git-worktrees`                  | 361   | Isolated workspace creation                       |
| `implementing-plans`             | 440   | Disciplined plan execution with verification      |
| `parallel-agents`                | 295   | Concurrent agent dispatch                         |
| `receiving-code-review`          | 270   | Verification-first response to review feedback    |
| `research-plan-implement`        | 341   | Orchestrator: spawns subagents for full RPI cycle |
| `researching-codebase`           | 242   | Phase 1: collaborative codebase exploration       |
| `reviewing-code`                 | 265   | Code review with Conventional Comments            |
| `security-review`                | 254   | OWASP-focused vulnerability review                |
| `synthesizing-research`          | 130   | Consolidate parallel research docs                |
| `systematic-debugging`           | 249   | Root cause investigation before fixes             |
| `test-driven-development`        | 205   | RED-GREEN-REFACTOR cycle enforcement              |
| `verification-before-completion` | 281   | Evidence-before-claims gate                       |
| `writing-plans`                  | 417   | Phase 2: produce approved plan documents          |

Every skill directory contains **only `SKILL.md`** — no scripts, templates, or references subdirs. Confirmed by
`tests/test-skills.sh:81–85` which fails if extra files are present.

SKILL.md frontmatter uses `name:`, `description:`, optional `argument-hint:`. The `name:` field is informational
(matches folder name) and does not affect discovery. Panoply's own skills use the same format. Files drop in without
adjustment.

#### Agents (7 total) — flat `.md` files

Source: `~/.claude/plugins/cache/rpikit/rpikit/0.8.0/agents/`

| Agent file              | name               | model  | color   | Primary use                       |
|-------------------------|--------------------|--------|---------|-----------------------------------|
| `code-reviewer.md`      | code-reviewer      | sonnet | blue    | spawned by implementing-plans     |
| `debugger.md`           | debugger           | sonnet | yellow  | user-invoked directly             |
| `file-finder.md`        | file-finder        | haiku  | cyan    | supporting research/writing/impl  |
| `security-reviewer.md`  | security-reviewer  | sonnet | red     | spawned by implementing-plans     |
| `test-runner.md`        | test-runner        | haiku  | green   | user-invoked directly             |
| `verifier.md`           | verifier           | haiku  | yellow  | user-invoked directly             |
| `web-researcher.md`     | web-researcher     | sonnet | magenta | supporting research/writing/impl  |

Target paths after fork:
```
~/src/Panoply/agents/code-reviewer.md
~/src/Panoply/agents/debugger.md
~/src/Panoply/agents/file-finder.md
~/src/Panoply/agents/security-reviewer.md
~/src/Panoply/agents/test-runner.md
~/src/Panoply/agents/verifier.md
~/src/Panoply/agents/web-researcher.md
```

### 3. Cross-Reference Hit List — `rpikit:` Invocations That Must Be Rewritten

These are the operationally active Skill tool invocations that will **silently fail** at runtime if left unchanged
after the plugin is removed. Rewrite `rpikit:<name>` → `<name>` in each case.

**8 live Skill-tool invocations (these break at runtime):**

| File                                          | Line | Old reference                                | New reference           |
|-----------------------------------------------|------|----------------------------------------------|-------------------------|
| `skills/research-plan-implement/SKILL.md`     | 91   | `rpikit:researching-codebase`                | `researching-codebase`  |
| `skills/research-plan-implement/SKILL.md`     | 142  | `rpikit:synthesizing-research`               | `synthesizing-research` |
| `skills/research-plan-implement/SKILL.md`     | 189  | `rpikit:writing-plans`                       | `writing-plans`         |
| `skills/research-plan-implement/SKILL.md`     | 238  | `rpikit:implementing-plans`                  | `implementing-plans`    |
| `skills/research-plan-implement/SKILL.md`     | 294  | `rpikit:brainstorming`                       | `brainstorming`         |
| `skills/implementing-plans/SKILL.md`          | 55   | `rpikit:writing-plans`                       | `writing-plans`         |
| `skills/writing-plans/SKILL.md`               | 358  | `rpikit:implementing-plans`                  | `implementing-plans`    |
| *(see note below)*                             | —    | `rpikit:implement` (old alias)               | remove or update        |

Note: `skills/writing-plans/SKILL.md:354` contains an old alias reference `rpikit:implement` — this is a transition
note, not an invocation, but should be cleaned up for accuracy.

**Additional descriptive mentions (not runtime failures, but should be updated for accuracy):**

| File                                          | Lines   | Content                                                |
|-----------------------------------------------|---------|--------------------------------------------------------|
| `skills/research-plan-implement/SKILL.md`     | 62–63   | Text: "skip to `rpikit:writing-plans`", "skip to `rpikit:implementing-plans`" |
| `skills/implementing-plans/SKILL.md`          | 52–53, 77 | Prerequisite notes referencing `rpikit:researching-codebase`, `rpikit:writing-plans` |
| `skills/writing-plans/SKILL.md`               | 134     | Reference note: `rpikit:test-driven-development`       |
| `skills/brainstorming/SKILL.md`               | 211–212 | "Start research → /rpikit:researching-codebase", "Create plan → /rpikit:writing-plans" |
| `skills/documenting-decisions/SKILL.md`       | 217     | Workflow diagram with `rpikit:brainstorming`, `rpikit:writing-plans`, `rpikit:documenting-decisions` |
| `skills/git-worktrees/SKILL.md`               | 24      | "User directly via /rpikit:git-worktrees"              |
| `AGENTS.md`                                   | 15–17   | Workflow overview with `rpikit:research-plan-implement`, etc. |

### 4. Claude Code Precedence Facts

#### Skill discovery tiers (highest to lowest)

| Priority | Tier              | Path                                                                               |
|----------|-------------------|------------------------------------------------------------------------------------|
| 1        | Enterprise/Managed | `/Library/Application Support/ClaudeCode/` (macOS)                               |
| 2        | Personal/User      | `~/.claude/skills/<skill-name>/SKILL.md`                                          |
| 3        | Project            | `.claude/skills/<skill-name>/SKILL.md` (per-repo)                                |
| 4        | Plugin             | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/<name>/SKILL.md` |

**Rule**: When skills share the same name, higher tier wins: enterprise > user > project.

**Critical implication**: Project-level skills do NOT shadow user-level skills. `.claude/skills/test-driven-development/SKILL.md` in a repo will be silently ignored in favour of `~/.claude/skills/test-driven-development/SKILL.md`. This is the opposite of what might be assumed.

Plugin skills are namespaced (e.g., `rpikit:brainstorming`) and cannot conflict with non-plugin tiers.

#### Agent discovery tiers

Same tier structure: user (`~/.claude/agents/`) > project (`.claude/agents/`) > plugin. Same namespacing rules.

#### Hot reload

Adding, editing, or removing a skill under `~/.claude/skills/` takes effect within the current session without
restarting. Exception: if the top-level `~/.claude/skills/` directory did not exist when the session started, a
restart is required. Since the directory already exists (current skills are there), adding new skill subdirs will be
picked up live.

#### Coexistence during transition

While both the plugin and the forked user-level skills exist simultaneously:
- `/brainstorming` → resolves to user-level skill (higher priority than plugin)
- `/rpikit:brainstorming` → still resolves to plugin skill (different namespace, no conflict)

This makes safe parallel testing possible.

### 5. `.claude/rules/` Pattern for Repo-Specific Overrides

#### The mechanism

`.claude/rules/` is an official, documented Claude Code convention (source: `code.claude.com/docs/en/memory`). Rules
files in a project's `.claude/rules/` directory load into context at session start, supplementing user-level context.
They do not replace user-level context — they add to it.

Folder structure:
```
your-repo/
├── .claude/
│   ├── CLAUDE.md
│   └── rules/
│       ├── testing.md          # loaded always — global testing conventions for this repo
│       └── security.md         # loaded always
```

Rules files with `paths:` frontmatter are **path-scoped** — they only load when Claude is working with files matching
the specified glob:

```markdown
---
paths:
  - "tests/**/*.py"
---
# Testing conventions specific to this repo

Use pytest with this exact fixture structure...
Run: pytest -q --maxfail=1
```

This is the **preferred mechanism for per-repo testing convention overrides** and is consistent with the user's
existing `<repo>/.claude/rules/` practice.

#### Why `.claude/rules/` is correct; `.claude/skills/` is not

Skills at project level (`.claude/skills/`) lose to user-level skills of the same name. A project cannot override a
user-level `test-driven-development` skill by putting a different one in `.claude/skills/test-driven-development/`.

Rules, by contrast, are additive. Path-scoped rules inject repo-specific context only when relevant files are active.
This achieves selective loading without trying to shadow a skill.

#### Practical pattern for repos with different testing conventions

1. Keep `~/.claude/skills/test-driven-development/SKILL.md` as the global methodology skill (applies everywhere).
2. In each repo, create `.claude/rules/testing.md` with `paths: ["tests/**"]` frontmatter containing repo-specific
   conventions (test runner invocation, fixture structure, assertion style, etc.).
3. The global TDD skill provides the RED-GREEN-REFACTOR discipline; the rule provides the repo-specific mechanics.

This is additive, not override — but for divergent convention coverage it is sufficient.

If a repo needs a truly different invocable skill (not just different conventions), use a different skill name:
e.g., `~/.claude/skills/test-driven-development-datascience/SKILL.md`. Both coexist without conflict.

### 6. Uninstall Sequence

#### What to remove — tracked Panoply files

| File                              | Lines   | Action                                                                                    |
|-----------------------------------|---------|-------------------------------------------------------------------------------------------|
| `settings.json`                   | 29–33   | Remove `"rpikit@rpikit": true` from `enabledPlugins` block                               |
| `settings.json`                   | 34–41   | Remove entire `"rpikit"` key from `extraKnownMarketplaces` block                         |
| `.claude/settings.local.json`     | 19–20   | Remove `"Read(//Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/**)"` and `"Read(//Users/matthumanhealth/.claude/plugins/**)"` |
| `README.md`                       | 75, 139, 161–170, 180 | Remove "9 via plugin" references, plugin install instructions, plugin management commands |

Do NOT touch `"dbt-skills@data-engineering-skills"` or `"github@claude-plugins-official"` in `enabledPlugins`.

`~/src/Panoply/settings.local.json` is gitignored and machine-specific — it is separate from `.claude/settings.local.json` (which IS tracked). Both may contain plugin cache Read permissions — inspect both.

#### What to remove — runtime (untracked) files

These are not tracked in Panoply and are cleaned up by CLI + manual steps:

| File/Directory                              | Cleaned by                                       |
|---------------------------------------------|--------------------------------------------------|
| `~/.claude/plugins/installed_plugins.json`  | `claude plugin uninstall rpikit@rpikit` (CLI)    |
| `~/.claude/plugins/cache/rpikit/`           | Marked for deletion by CLI; 7-day grace period   |
| `~/.claude/plugins/marketplaces/rpikit/`    | `/plugin marketplace remove rpikit` (sometimes)  |

#### Known bugs — pre-empt these

1. **Issue #28554: `enabledPlugins: false` is ignored.** Setting `"rpikit@rpikit": false` does not reliably prevent
   loading. The auto-reinstall mechanism re-adds entries to `installed_plugins.json` on restart. **Mitigation**: do
   not rely on disable alone — fully remove the key from `settings.json`.

2. **Issue #9537: Marketplace removal doesn't clean settings.json.** After `/plugin marketplace remove rpikit`, the
   `extraKnownMarketplaces` and `enabledPlugins` entries remain in `settings.json`, causing reinstall on next
   startup. **Mitigation**: always manually remove these keys from `settings.json` after the CLI commands.

3. **Issue #38714: No reliable automated uninstall path.** The plugin.json validator runs at startup against all
   marketplace entries, even disabled ones. **Mitigation**: force-clean cache directories after uninstall.

#### Complete uninstall sequence

```bash
# Phase 1: Fork skills and agents into Panoply (before touching the plugin)
# [copy files, update SYMLINK_ITEMS, update rpikit: references]
# Test: /brainstorming and /rpikit:brainstorming both work

# Phase 2: Disable plugin (while forked skills coexist)
claude plugin disable rpikit@rpikit

# Phase 3: Run a few sessions to verify forked skills work correctly

# Phase 4: Uninstall
claude plugin uninstall rpikit@rpikit

# Phase 5: Manual settings.json cleanup (REQUIRED — CLI does not do this reliably)
# Edit ~/src/Panoply/settings.json:
#   - Remove "rpikit@rpikit": true from enabledPlugins (lines 29-33)
#   - Remove entire "rpikit" block from extraKnownMarketplaces (lines 34-41)

# Phase 6: settings.local.json cleanup
# Edit ~/src/Panoply/.claude/settings.local.json:
#   - Remove lines 19-20 (plugin cache Read permissions)

# Phase 7: Optional marketplace removal
/plugin marketplace remove rpikit
# Then verify settings.json still clean (bug #9537 may re-dirty it)

# Phase 8: Force-clean cache (don't wait 7 days)
rm -rf ~/.claude/plugins/cache/rpikit
rm -rf ~/.claude/plugins/marketplaces/rpikit

# Phase 9: Restart Claude Code, verify /brainstorming etc. work correctly
```

### 7. Files to Include vs. Exclude from Fork

#### Include (copy to Panoply)

- `skills/*/SKILL.md` — all 16 skills
- `agents/*.md` — all 7 agents (with AGENTS.md Beads block removed, see below)

#### Exclude or rewrite

| File/Dir             | Action                                                                                   |
|----------------------|------------------------------------------------------------------------------------------|
| `AGENTS.md`          | Rewrite entirely — contains rpikit-specific git workflow + Beads `bd` integration block that will inject irrelevant `bd prime`/`bd close` instructions into any Panoply session |
| `package.json`       | Exclude — husky dev dependency, irrelevant to skill operation                            |
| `.husky/`            | Exclude — rpikit's own CI hooks                                                          |
| `bin/start`          | Exclude — local plugin dev tool only                                                     |
| `.claude-plugin/`    | Exclude — plugin manifest, inert outside plugin context                                  |
| `docs/plans/`        | Exclude — rpikit's own internal development docs, no operational role in skill execution |
| `docs/decisions/`    | Exclude — rpikit's own ADRs                                                              |
| `tests/`             | Optional keep for `test-skills.sh`, `test-agents.sh`, `test-frontmatter.sh` as CI gates; drop `test-plugin.sh` (claude plugin validate doesn't apply to user-level skills) |

#### rpikit's own `docs/plans/` path assumptions

All `docs/plans/` references in skill bodies refer to the **user's working repo** (relative paths), not the plugin
directory. Since Panoply already has `docs/plans/`, no changes needed. The same applies to `docs/decisions/`.

### 8. Pre-existing Bug to Fix During Fork

The `code-reviewer` agent (`agents/code-reviewer.md:18, 44, 59, 80`) declares it uses a skill named `code-review`.
No such skill exists — the skill is named `reviewing-code` (renamed per `CHANGELOG.md:161`). This is a descriptive
reference only (the agent doesn't programmatically invoke the skill), so it doesn't break at runtime. However it is
inaccurate and should be corrected in the fork: change `code-review` → `reviewing-code` in the agent's `## Skills
Used` section.

---

## Technical Constraints

1. **No namespace preservation.** There is no way to retain the `rpikit:` prefix for user-level skills. The prefix is
   a plugin-only feature. All internal cross-references and any user muscle-memory on `/rpikit:<skill>` must adapt.

2. **Project skills do not override user skills.** This is architectural — the Claude Code docs are explicit.
   Per-repo behavioural variation must go through `.claude/rules/` (context injection) rather than `.claude/skills/`
   (invocable skill override). Attempting to use `.claude/skills/` for overrides will silently fail.

3. **`~/.claude/skills/` directory must pre-exist before session start** for hot reload to work without restart.
   This directory already exists via the `setup.sh` symlink, so this constraint is satisfied.

4. **`setup.sh:16` must gain `agents`** for the agents symlink to be created on new machines. The current machine
   requires a one-off manual symlink command.

5. **Both `~/src/Panoply/settings.json` and `~/src/Panoply/.claude/settings.local.json` are tracked** in git and
   both require cleanup edits. The untracked `~/src/Panoply/settings.local.json` (machine-specific permissions)
   may also contain plugin cache Read permissions — inspect it during cleanup.

6. **`pluginConfigs` key**: rpikit does not appear to use `userConfig` in its manifest, but verify that no
   `pluginConfigs.rpikit` key exists in `settings.json` before cleanup is considered complete:
   ```bash
   python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/src/Panoply/settings.json'))); print(d.get('pluginConfigs', 'NOT PRESENT'))"
   ```

---

## Open Questions / Unresolved Items

1. **`AGENTS.md` content for Panoply.** The file needs to be entirely rewritten — the rpikit-specific content
   (git workflow, changelog rules, Beads integration block at lines 61–109) does not apply to Panoply. Decision
   needed: should Panoply have its own `AGENTS.md` with equivalent instructions for its own development, or should
   the file be omitted?

2. **`.claude-code-version` minimum version constraint.** The plugin ships a `.claude-code-version` file specifying a
   minimum Claude Code version. This constraint was not read during research. It may be irrelevant for user-level
   skills (the version constraint is likely a plugin-manifest feature), but confirm whether any skill body references
   minimum version requirements.

3. **`enabledPlugins: false` bug status.** Issue #28554 is from early 2026 — it may have been patched since.
   The recommended mitigation (remove the key entirely) is safe regardless of whether the bug is fixed.

4. **`web-researcher` agent tool permissions.** The `web-researcher` agent has `WebSearch`/`WebFetch` tool access.
   After fork, verify that `settings.local.json` grants those tools under the user-level agent path (not just the
   plugin cache path). The existing plugin cache `Read` permissions in `.claude/settings.local.json:19–20` cover
   the plugin's agent files; after uninstall those lines are removed and the user-level agents are in a different
   path. If tool permissions are path-scoped to the plugin cache, agent tool access may break.

5. **Whether `~/src/Panoply/skills/` being a top-level symlink target counts as the watched directory.** Hot
   reload watches `~/.claude/skills/` — which is itself a symlink to `~/src/Panoply/skills/`. Confirm that file
   watching follows symlinks correctly on macOS. This is almost certainly fine (inotify/FSEvents follow symlinks
   for directory watches) but worth a quick test on first skill addition.

---

## Recommendations

1. **Fork before uninstall.** Copy all 16 skills and 7 agents to Panoply, update `setup.sh`, create the manual
   agents symlink. Test that the forked user-level skills work (`/brainstorming`, etc.) while the plugin still
   runs (`/rpikit:brainstorming`). Only proceed to uninstall once forked versions are confirmed working.

2. **Fix the 8 Skill invocations atomically with the fork.** All eight `rpikit:<name>` Skill-tool invocations in
   `research-plan-implement/SKILL.md`, `implementing-plans/SKILL.md`, and `writing-plans/SKILL.md` must be rewritten
   before the plugin is uninstalled, or those skills will break silently mid-pipeline.

3. **Rewrite `AGENTS.md` at fork time.** Do not copy the original — it will inject `bd prime`/`bd close`
   instructions into Panoply sessions. Write a minimal Panoply-appropriate replacement or omit the file.

4. **Fix `code-reviewer.md:18,44,59,80`** to reference `reviewing-code` not `code-review` when copying the agent.

5. **Use `.claude/rules/testing.md` with `paths:` frontmatter** for per-repo testing conventions (e.g., analytics
   repo uses pandas/pytest, datascience repo uses polars/pytest with different fixtures). Do not attempt
   `.claude/skills/test-driven-development/` overrides — project skills lose to user skills.

6. **Manual settings.json cleanup is mandatory.** Do not rely on the CLI uninstall to clean `enabledPlugins` or
   `extraKnownMarketplaces`. Both bugs (#9537, #28554) are documented and the workaround is manual key deletion.

7. **Force-clean the plugin cache** (`rm -rf ~/.claude/plugins/cache/rpikit`) after uninstall to avoid stale
   content and to free the permission references in `.claude/settings.local.json`.

---

## Sources

| Document | Focus Area |
|----------|------------|
| `docs/plans/2026-04-14-rpikit-fork-panoply.md` | Panoply wiring, landing paths, symlink structure, settings.json inventory, gitignore, skill naming conventions |
| `docs/plans/2026-04-14-rpikit-fork-plugin.md` | Plugin internals, complete skill/agent inventory, namespace cross-references (file:line), hardcoded paths, external dependencies, testing infrastructure, impact assessment |
| `docs/plans/2026-04-14-rpikit-fork-resolution.md` | Claude Code docs-verified precedence rules, namespacing mechanics, `.claude/rules/` convention, plugin uninstall mechanics, known bugs with issue numbers |
