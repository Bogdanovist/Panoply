# rpikit Plugin Fork Audit (2026-04-14)

Source: `/Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/`
Repository: https://github.com/bostonaholic/rpikit
Version: 0.8.0 (Matthew Boston, MIT licence)

---

## 1. Complete Inventory

### Top-level Files

| Path | Type | Lines | Role |
|------|------|-------|------|
| `package.json` | JSON | 9 | npm manifest — only declares `husky` devDep and `prepare` script; no plugin config here |
| `.claude-plugin/plugin.json` | JSON | 10 | Claude Code plugin manifest: name, version, author, repo |
| `.claude-plugin/marketplace.json` | JSON | 20 | Marketplace listing: description and source pointer (`./`) |
| `AGENTS.md` | Markdown | 109 | Agent instructions for AI working on rpikit itself; also contains Beads integration block |
| `README.md` | Markdown | 214 | User-facing documentation |
| `CHANGELOG.md` | Markdown | 218 | User-facing change log |
| `CONTRIBUTING.md` | Markdown | 140 | Dev setup, git hooks, release workflow |
| `LICENSE` | Text | — | MIT |
| `.claude-code-version` | Text | — | Minimum Claude Code version constraint |
| `.markdownlint.json` | JSON | — | markdownlint configuration |
| `.gitignore` | Text | 35 | Node modules, OS files |
| `.gitattributes` | Text | — | Git attributes |
| `bin/start` | Bash | 31 | Dev helper: launches `claude --plugin-dir <plugin-dir>` locally |
| `docs/architecture.md` | Markdown | 167 | Component model, skill/agent tables, mermaid diagrams |
| `docs/decisions/` | Dir | — | ADR storage directory (empty, just a `.gitkeep`) |
| `docs/plans/` | Dir | — | 20+ research/plan/design docs from rpikit's own development |

### Skills Directory (16 skill subdirs, each containing only `SKILL.md`)

| Skill name (dir) | Lines | Role |
|------------------|-------|------|
| `research-plan-implement` | 341 | Orchestrator: spawns parallel subagents for full RPI pipeline |
| `researching-codebase` | 242 | Phase 1: collaborative codebase exploration |
| `writing-plans` | 417 | Phase 2: produce approved plan documents |
| `implementing-plans` | 440 | Phase 3: disciplined plan execution with verification |
| `synthesizing-research` | 130 | Consolidates parallel research docs into one file |
| `brainstorming` | 272 | Creative exploration before research |
| `documenting-decisions` | 252 | Write ADRs from design docs to `docs/decisions/` |
| `reviewing-code` | 265 | Code review with Conventional Comments |
| `security-review` | 254 | OWASP-focused vulnerability review |
| `test-driven-development` | 205 | RED-GREEN-REFACTOR cycle enforcement |
| `systematic-debugging` | 249 | Root cause investigation before fixes |
| `verification-before-completion` | 281 | Evidence-before-claims gate |
| `finishing-work` | 280 | Merge / PR / discard workflow after implementation |
| `receiving-code-review` | 270 | Verification-first response to review feedback |
| `git-worktrees` | 361 | Isolated workspace creation |
| `parallel-agents` | 295 | Concurrent agent dispatch |

Each skill directory contains **only `SKILL.md`** — confirmed by `tests/test-skills.sh` (which fails if extra files are present). No scripts, templates, or reference files to copy separately.

### Agents Directory (7 `.md` files)

See Section 7 for full agent table.

### `tests/` Directory

| File | Lines | Role |
|------|-------|------|
| `run-tests.sh` | 100 | Test runner: sources and runs all four suites |
| `test-skills.sh` | 87 | Validates each skill: SKILL.md exists, frontmatter valid, name matches dir |
| `test-agents.sh` | 84 | Validates each agent: frontmatter has name/description/model/color |
| `test-frontmatter.sh` | 55 | YAML syntax validation via `yq` or Python `yaml` |
| `test-plugin.sh` | ~20 | Runs `claude plugin validate $PROJECT_ROOT` |

---

## 2. Skill Anatomy

Every skill consists of **one file only**: `skills/<skill-name>/SKILL.md`. The frontmatter schema is:

```yaml
---
name: <skill-name>               # required; must match directory name
description: >                   # required; shown in skill picker
  ...
argument-hint: <string>          # optional; shown as arg placeholder
effort: high                     # optional; present on research-plan-implement
---
```

No extra files (scripts, templates, references) exist in any skill directory. This is enforced by `tests/test-skills.sh` at line 81–85.

---

## 3. Namespace References (`rpikit:` occurrences)

These are all occurrences of `rpikit:` in files that will be part of the fork. Occurrences in `docs/plans/` are historical and not operationally active.

### Operationally Active References

| Source file:line | Full reference | Context |
|-----------------|----------------|---------|
| `skills/research-plan-implement/SKILL.md:62` | `rpikit:writing-plans` | "Requirements clear — skip to `rpikit:writing-plans`" |
| `skills/research-plan-implement/SKILL.md:63` | `rpikit:implementing-plans` | "Plan exists — skip to `rpikit:implementing-plans`" |
| `skills/research-plan-implement/SKILL.md:91` | `rpikit:researching-codebase` | `Invoke the Skill tool with skill: 'rpikit:researching-codebase'` |
| `skills/research-plan-implement/SKILL.md:142` | `rpikit:synthesizing-research` | `Invoke the Skill tool with skill: 'rpikit:synthesizing-research'` |
| `skills/research-plan-implement/SKILL.md:189` | `rpikit:writing-plans` | `Invoke the Skill tool with skill: 'rpikit:writing-plans'` |
| `skills/research-plan-implement/SKILL.md:238` | `rpikit:implementing-plans` | `Invoke the Skill tool with skill: 'rpikit:implementing-plans'` |
| `skills/research-plan-implement/SKILL.md:294` | `rpikit:brainstorming` | `Skill tool with skill: "rpikit:brainstorming"` |
| `skills/implementing-plans/SKILL.md:52` | `rpikit:researching-codebase` | prerequisite note |
| `skills/implementing-plans/SKILL.md:53` | `rpikit:writing-plans` | prerequisite note |
| `skills/implementing-plans/SKILL.md:55` | `rpikit:writing-plans` | `Invoke the Skill tool with skill "rpikit:writing-plans"` |
| `skills/implementing-plans/SKILL.md:77` | `rpikit:researching-codebase` | low-stakes note |
| `skills/writing-plans/SKILL.md:134` | `rpikit:test-driven-development` | reference note |
| `skills/writing-plans/SKILL.md:354` | `rpikit:implement` | (old alias — transition note) |
| `skills/writing-plans/SKILL.md:358` | `rpikit:implementing-plans` | `invoke the Skill tool with skill "rpikit:implementing-plans"` |
| `skills/brainstorming/SKILL.md:211` | `rpikit:researching-codebase` | "Start research → /rpikit:researching-codebase" |
| `skills/brainstorming/SKILL.md:212` | `rpikit:writing-plans` | "Create plan → /rpikit:writing-plans" |
| `skills/documenting-decisions/SKILL.md:217` | `rpikit:brainstorming`, `rpikit:writing-plans`, `rpikit:documenting-decisions` | workflow diagram |
| `skills/git-worktrees/SKILL.md:24` | `rpikit:git-worktrees` | "User directly via /rpikit:git-worktrees" |
| `AGENTS.md:15–17` | `rpikit:research-plan-implement`, `rpikit:researching-codebase`, `rpikit:writing-plans`, `rpikit:implementing-plans` | workflow overview |

**What happens after fork**: When skills live at user level (e.g., `~/.claude/skills/`) or in a repo `.claude/skills/`, Claude Code resolves them by bare name. The `rpikit:` prefix is only required when referencing a plugin-namespaced skill. After fork, all `rpikit:<skill>` references inside SKILL.md files must be changed to bare `<skill>` names (e.g., `rpikit:implementing-plans` → `implementing-plans`). Any literal `/rpikit:...` invocation strings in skill bodies will break.

---

## 4. Hardcoded Paths

### `docs/plans/` references (written by skills to the user's working directory)

All occurrences below are relative paths into the **user's repo** (not the plugin directory). They will continue to work after fork — they describe where artifacts are written to/read from in whatever repo the skill is used in.

| Source file:line | Path pattern | Context |
|-----------------|--------------|---------|
| `skills/implementing-plans/SKILL.md:29` | `docs/plans/YYYY-MM-DD-<topic>-plan.md` | locate plan |
| `skills/implementing-plans/SKILL.md:278` | `docs/plans/YYYY-MM-DD-<topic>-plan.md` | update plan |
| `skills/synthesizing-research/SKILL.md:24` | `docs/plans/*-<topic>-*.md` | glob pattern |
| `skills/synthesizing-research/SKILL.md:55` | `docs/plans/YYYY-MM-DD-<topic>-research.md` | write output |
| `skills/researching-codebase/SKILL.md:148` | `docs/plans/YYYY-MM-DD-<topic>-research.md` | write output |
| `skills/brainstorming/SKILL.md:114` | `docs/plans/YYYY-MM-DD-<topic>-design.md` | write output |
| `skills/writing-plans/SKILL.md:21,256,344,363,417` | `docs/plans/…` | read/write plan |
| `skills/research-plan-implement/SKILL.md:33,39,95,108,118,145,149,167,192,210,237,333,340` | `docs/plans/…` | all phases |
| `skills/documenting-decisions/SKILL.md:59` | `docs/plans/*-design.md` | glob for input |

**Flag**: These paths assume `docs/plans/` exists in the user's repo. Panoply already has this structure, so no change needed. If a fork targets a repo with a different plans directory, these hardcoded paths will need updating.

### `docs/decisions/` references (written by documenting-decisions skill)

| Source file:line | Path | Context |
|-----------------|------|---------|
| `skills/documenting-decisions/SKILL.md:7,105,110,113,120,125,130,141,217` | `docs/decisions/` | ADR output directory |

**Flag**: Skill creates `docs/decisions/` via `mkdir -p` if missing (line 125). Safe, but directory name is hardcoded.

### `.claude/` and plugin paths

No occurrences of `.claude/` or `plugins/` in any skill or agent body. These paths do not appear as hardcoded references in operative content.

### Absolute paths

No absolute paths (`/Users/`, `/home/`, `~/<path>`) found in any skill or agent body. The `git-worktrees` skill mentions `~/worktrees/…` only as an **example path** in user-visible text (lines 77, 281), not as a value the skill reads or writes.

### `bin/start`

References `--plugin-dir "$PLUGIN_DIR"` where `$PLUGIN_DIR` is computed from the script's own location. Safe for local dev only — not relevant to forked skill usage.

---

## 5. package.json and Manifest

### `package.json`

```json
{
  "private": true,
  "scripts": { "prepare": "husky" },
  "devDependencies": { "husky": "^9" }
}
```

No Claude Code plugin manifest fields. No `commands`, `agents`, `hooks`, or `skills` registration here. The plugin manifest lives in `.claude-plugin/`.

### `.claude-plugin/plugin.json`

```json
{
  "name": "rpikit",
  "version": "0.8.0",
  "author": { "name": "Matthew Boston" },
  "repository": "https://github.com/bostonaholic/rpikit",
  "license": "MIT",
  "keywords": [...]
}
```

No skill or agent registration fields. Claude Code auto-discovers skills from `skills/*/SKILL.md` and agents from `agents/*.md` by convention.

### `.claude-plugin/marketplace.json`

Marketplace listing only. No functional registration.

---

## 6. Commands — How Slash Commands Are Registered

There is **no `commands/` directory** in this plugin. Claude Code registers slash commands automatically from `skills/*/SKILL.md` files:

- The plugin namespace comes from `plugin.json → name` → `rpikit`
- The command name comes from the skill's `name` frontmatter field
- Result: `/rpikit:<skill-name>` for each skill

So `/rpikit:implementing-plans` is served by `skills/implementing-plans/SKILL.md`, and so on. There is no separate command manifest to update.

**After fork**: If skills are installed at user level (`~/.claude/skills/`) or in a repo's `.claude/skills/`, they become invokable as `/<skill-name>` (bare, no namespace). The `rpikit:` prefix is dropped entirely. No command registration files need to be created — discovery is automatic.

---

## 7. Agent Inventory

| Agent file | name | model | color | Skills Used (per agent body) | Invoked by skills |
|-----------|------|-------|-------|------------------------------|-------------------|
| `agents/file-finder.md` | file-finder | haiku | cyan | (none declared) | researching-codebase, writing-plans, implementing-plans |
| `agents/web-researcher.md` | web-researcher | sonnet | magenta | (none declared) | researching-codebase, writing-plans, implementing-plans, research-plan-implement |
| `agents/code-reviewer.md` | code-reviewer | sonnet | blue | `code-review` (bare name — see note) | implementing-plans |
| `agents/security-reviewer.md` | security-reviewer | sonnet | red | `security-review` (bare name) | implementing-plans |
| `agents/debugger.md` | debugger | sonnet | yellow | `systematic-debugging` (bare name) | none (user invokes directly) |
| `agents/test-runner.md` | test-runner | haiku | green | `test-driven-development` (bare name) | none (user invokes directly) |
| `agents/verifier.md` | verifier | haiku | yellow | `verification-before-completion` (bare name) | none (user invokes directly) |

**Critical note on agent–skill coupling**: Four agents declare `## Skills Used` sections that reference skills by bare name, not `rpikit:`-prefixed name:

| Agent | Declares skill | Actual skill `name` field | Discrepancy? |
|-------|---------------|---------------------------|--------------|
| `code-reviewer.md:18,44,59,80` | `code-review` | `reviewing-code` | **YES — mismatch** |
| `security-reviewer.md:19,41,51,70,80` | `security-review` | `security-review` | No mismatch |
| `debugger.md:16` | `systematic-debugging` | `systematic-debugging` | No mismatch |
| `test-runner.md:15` | `test-driven-development` | `test-driven-development` | No mismatch |
| `verifier.md:16` | `verification-before-completion` | `verification-before-completion` | No mismatch |

The `code-reviewer` agent references a skill named `code-review` which does not exist (the skill is named `reviewing-code`). This appears to be a documentation-only reference (the agent describes its methodology verbally rather than invoking the skill programmatically), so it does not cause a runtime failure — but it is inaccurate and would remain inaccurate after fork.

**After fork**: `## Skills Used` sections are descriptive text, not programmatic invocations. The agent bodies do not use `Skill tool` calls. No changes required to agent skill references for functionality, but the `code-review`/`reviewing-code` discrepancy should be corrected.

---

## 8. External Dependencies

### Beads (`bd`) integration

The AGENTS.md file contains a `<!-- BEGIN BEADS INTEGRATION … -->` block (lines 61–109) that injects `bd` issue-tracker instructions. This block:

- Is part of rpikit's **own development workflow** — it tells AI agents working on rpikit to use `bd` for issue tracking
- Is **not injected into user projects** automatically — it only applies when Claude Code reads rpikit's own `AGENTS.md`
- Will be irrelevant to the fork unless the user also uses `bd`

If the fork is dropped into Panoply without modification, any session where Claude Code reads the plugin's `AGENTS.md` will receive `bd` instructions that do not apply to Panoply's workflow. The block should be **removed from the forked AGENTS.md**.

### `husky` (git hooks)

`package.json` declares `husky ^9` as a devDependency with a `prepare` script. The `.husky/` directory exists. These hooks are for rpikit's own development (e.g., running `tests/run-tests.sh` pre-commit). After fork, `npm install` would install husky but it is not needed for skill operation.

### `bin/start`

Uses `claude --dangerously-skip-permissions --plugin-dir "$PLUGIN_DIR"`. Development tool only.

### No external API calls or services

No skills or agents make calls to external services. `web-researcher` is a Claude agent with `WebSearch`/`WebFetch` tool access — the web access comes from Claude Code's tool permission system, not from any rpikit-defined external dependency.

---

## 9. Testing Infrastructure

### What the tests do

| Test suite | Validates |
|-----------|-----------|
| `test-skills.sh` | Each skill dir has SKILL.md; frontmatter has `name` (matching dir), `description`; H1 heading present; no extra files |
| `test-agents.sh` | Each agent has frontmatter with `name`, `description`, `model` (haiku/sonnet/opus), `color`; H1 heading present |
| `test-frontmatter.sh` | YAML syntax in all frontmatter (requires `yq` or Python `yaml`) |
| `test-plugin.sh` | Runs `claude plugin validate $PROJECT_ROOT` — requires Claude Code CLI |

### Keep or drop on fork?

- **Keep for development**: The structural tests (`test-skills.sh`, `test-agents.sh`, `test-frontmatter.sh`) are useful CI gates for any fork. They ensure you don't accidentally break frontmatter.
- **Drop or adapt `test-plugin.sh`**: After fork, the skills live at user level or in a repo, not as a plugin — `claude plugin validate` would not apply.
- **Drop `bin/start`**: Only needed for local plugin development.
- **Drop `package.json` / `.husky/`**: Only needed if you want the same git-hook CI setup.

---

## 10. Impact Assessment for Fork

### What changes namespace

All `rpikit:` prefixed invocations inside SKILL.md files become bare names after fork. The following files contain live `Invoke the Skill tool with skill: 'rpikit:...'` strings that **will fail** if left unchanged:

| File | Lines to update | Old → New |
|------|----------------|-----------|
| `skills/research-plan-implement/SKILL.md` | 91, 142, 189, 238, 294 | `rpikit:<name>` → `<name>` |
| `skills/implementing-plans/SKILL.md` | 55 | `rpikit:writing-plans` → `writing-plans` |
| `skills/writing-plans/SKILL.md` | 358 | `rpikit:implementing-plans` → `implementing-plans` |

Descriptive mentions of `/rpikit:<name>` in text (brainstorming, documenting-decisions, AGENTS.md) are not runtime failures but should be updated for accuracy.

### What changes agent resolution

Agents are resolved by name matching `agents/*.md → name:` frontmatter. After fork the agent files keep their same names — no changes needed for agent resolution, provided all agent files are copied.

### `docs/plans/` path assumption

Skills write artifacts to `docs/plans/` in the **user's working directory** (not the plugin). Panoply already has `docs/plans/` — no change needed. Any repo that does not have this directory will have it created by the skill (Write tool), but it is an implicit structural contract.

### AGENTS.md Beads block

Must be removed or replaced. If left as-is, any AI working on Panoply in a session that loads the skills will receive `bd prime` and `bd close` instructions that don't apply.

### `code-reviewer` skill name mismatch

The `code-reviewer` agent refers to a `code-review` skill (lines 18, 44, 59, 80) but the actual skill is named `reviewing-code`. This is a pre-existing inaccuracy that carries over to the fork. It is descriptive-only and does not break functionality.

### Plugin manifest files

`.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` are only meaningful when installed as a plugin. After fork to user-level skills, these files are inert. They can be kept (harmless) or removed.

### `docs/plans/` in plugin directory

The plugin's own `docs/plans/` contains 20+ research and plan documents from rpikit's internal development. These are safe to exclude from the fork — they have no operational role in skill execution.

### Coupling map for modifying `implementing-plans`

If the user modifies how `implementing-plans` runs verification:

| Component | Why it may need touching | Coupling type |
|-----------|--------------------------|---------------|
| `skills/implementing-plans/SKILL.md` | Primary change target | Direct |
| `skills/writing-plans/SKILL.md:358` | Invokes implementing-plans after approval | Cross-skill invocation |
| `skills/research-plan-implement/SKILL.md:238` | Invokes implementing-plans as subagent | Cross-skill invocation |
| `agents/code-reviewer.md` | Spawned by implementing-plans for code review gate | Agent dependency |
| `agents/security-reviewer.md` | Spawned by implementing-plans for security gate | Agent dependency |
| `agents/verifier.md` | Provides the verification check pattern | Agent dependency (indirect) |
| `skills/verification-before-completion/SKILL.md` | Methodology referenced in implementation verification steps | Skill dependency |
| `skills/finishing-work/SKILL.md` | Follows implementing-plans; expects tests to pass | Post-condition dependency |

---

## Unresolved

1. **`code-reviewer` / `code-review` mismatch**: The `code-reviewer` agent's `## Skills Used` section references `code-review` (line 18) but no skill has `name: code-review`. The skill is `reviewing-code`. This may be a leftover from a historical rename (CHANGELOG.md:161 documents renaming `code-review` internal skill to `reviewing-code`). After fork, if the agent is ever updated to programmatically load the skill, it will need `reviewing-code` not `code-review`.

2. **`AGENTS.md` ownership after fork**: The file contains both rpikit project instructions (git workflow, changelog rules) and a Beads integration block. The appropriate content for the forked AGENTS.md depends on Panoply's conventions — this file should be entirely rewritten for the target repo.

3. **Claude Code skill resolution precedence**: Whether bare skill names (after fork) at user level resolve correctly when there is also a system skill with the same name is not confirmed by this audit. A separate audit of Claude Code resolution mechanics is in progress (task #3).

4. **`.claude-code-version` minimum version**: The file exists but was not read. Unresolved whether the constraint affects skill operation at user level vs. plugin level.
