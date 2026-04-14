# Panoply wiring map: forking rpikit into the dotfiles repo

**Date:** 2026-04-14  
**Purpose:** Determine exactly where forked rpikit skills and agents must land inside ~/src/Panoply/ so that Claude Code discovers them after the plugin is uninstalled.

---

## 1. ~/.claude wiring

**Method: selective symlinks, not a wholesale directory symlink.**

`~/.claude/` is NOT a symlink to `~/src/Panoply/`. It is a regular directory managed by Claude Code's runtime. `setup.sh` creates individual symlinks for four items:

```
# setup.sh:16
SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills)
```

Verified live state (`ls -la ~/.claude/`):

| `~/.claude/` entry | Type | Points to |
|--------------------|------|-----------|
| `CLAUDE.md` | symlink | `/Users/matthumanhealth/src/Panoply/CLAUDE.md` |
| `settings.json` | symlink | `/Users/matthumanhealth/src/Panoply/settings.json` |
| `settings.local.json` | symlink | `/Users/matthumanhealth/src/Panoply/settings.local.json` |
| `hooks` | symlink | `/Users/matthumanhealth/src/Panoply/hooks` |
| `skills` | symlink | `/Users/matthumanhealth/src/Panoply/skills` |

`setup.sh` also handles `settings.local.json` separately (lines 37–57): it copies the example template if no local file exists, then symlinks the result from `~/src/Panoply/settings.local.json` into `~/.claude/settings.local.json`.

There is **no `agents/` symlink** created by `setup.sh` (`setup.sh:16`). This means a `~/src/Panoply/agents/` directory exists only in the repo — it would need a matching symlink entry added to `SYMLINK_ITEMS` to be discovered.

**Key source files:**
- `setup.sh:1–75` — full wiring logic
- `setup.sh:16` — the four items that become symlinks

---

## 2. Existing skills discovery

`~/.claude/skills` is a direct symlink to `~/src/Panoply/skills/` (`setup.sh:16`, confirmed by `ls -la ~/.claude/` output).

Claude Code reads `~/.claude/skills/` at startup; because it is a symlink, it is reading `~/src/Panoply/skills/` transparently. Each subdirectory in that tree that contains a `SKILL.md` file is registered as an invocable skill.

**Namespace rule:** skills discovered from `~/.claude/skills/` are invoked by their folder name only — no prefix. Skills loaded via a plugin appear in the system-reminder with the format `<marketplace>:<skill-name>` (e.g., `rpikit:researching-codebase`). Once rpikit is uninstalled and its skills are copied directly into `~/src/Panoply/skills/`, they will be invoked as `/researching-codebase`, `/writing-plans`, etc. — no namespace prefix.

**Evidence:**
- Current system-reminder lists Panoply skills without prefix: `refine-project`, `review`, `retro`, etc.
- Current system-reminder lists rpikit skills with prefix: `rpikit:test-driven-development`, `rpikit:brainstorming`, etc.
- The namespace is derived from the installed plugin's registry key (`"rpikit@rpikit"` in `~/.claude/plugins/installed_plugins.json:7`), not from anything inside `SKILL.md`.
- Panoply `SKILL.md` files use the same frontmatter format as rpikit ones (both use `description:`, `argument-hint:`, optional `name:` field) — no structural difference.

---

## 3. Agents location

**No `agents/` directory exists anywhere in Panoply or under `~/.claude/` outside the plugin cache.**

`find ~/.claude -name "agents" -type d` returned only:
- `/Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/agents` — active plugin
- `/Users/matthumanhealth/.claude/plugins/marketplaces/...` — marketplace listing copies
- No user-level `~/.claude/agents/` directory

`find ~/src/Panoply -name "agents" -type d` returned nothing.

The rpikit plugin ships 7 agent `.md` files in its `agents/` directory:
```
code-reviewer.md  debugger.md  file-finder.md  security-reviewer.md
test-runner.md    verifier.md  web-researcher.md
```

Each agent `.md` uses YAML frontmatter with `name:`, `description:`, `model:`, `color:` fields (confirmed in `agents/file-finder.md:1–8`).

**For forked agents to be discovered**, Claude Code must be able to find an `agents/` directory. Based on the parallel pattern with skills, the path would be `~/.claude/agents/` — which means `~/src/Panoply/agents/` would need to be created and a symlink added to `setup.sh`. This is unresolved from filesystem evidence alone (see Section 7 for what needs removal from `settings.json`). The safest landing path by analogy is `~/src/Panoply/agents/` + a new symlink entry in `setup.sh`.

---

## 4. Hooks and settings

### Hooks

`~/.claude/hooks` is a symlink to `~/src/Panoply/hooks/` (`setup.sh:16`).

Three hook scripts live in `~/src/Panoply/hooks/`:

| File | Purpose |
|------|---------|
| `auto-commit-push.sh` | Stop hook — auto-commits and pushes both current project and Panoply itself after each Claude response |
| `gws-write-guard.sh` | PreToolUse hook — blocks gws CLI write operations without explicit user approval |
| `pre-commit-secrets-check.sh` | Git pre-commit hook — scans staged files for secrets before Panoply commits to its (public) remote |

**Hook wiring in settings.json:**

Only `auto-commit-push.sh` is wired into `settings.json` (`settings.json:16–28`):
```json
"hooks": {
  "Stop": [{
    "hooks": [{
      "type": "command",
      "command": "bash ~/.claude/hooks/auto-commit-push.sh",
      "timeout": 30
    }]
  }]
}
```

`gws-write-guard.sh` has no corresponding entry in `settings.json` or `settings.local.json` — it is a script present in the repo but **not currently wired up as a PreToolUse hook**. (`gws-write-guard.sh:2` names it a PreToolUse hook in a comment, but grep found no settings registration.)

`pre-commit-secrets-check.sh` is installed as a git pre-commit hook by `setup.sh:66`:
```bash
ln -sf "$REPO_DIR/hooks/pre-commit-secrets-check.sh" "$GIT_HOOKS_DIR/pre-commit"
```

### settings.json

`~/.claude/settings.json` → `~/src/Panoply/settings.json` (symlink).

Full contents at `settings.json:1–47`:
- `env` block: sets `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `CLAUDE_CODE_MAX_OUTPUT_TOKENS=64000`, `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=80`
- `permissions.allow`: git, gh commands
- `hooks.Stop`: auto-commit-push.sh
- `enabledPlugins`: `dbt-skills@data-engineering-skills`, `github@claude-plugins-official`, `rpikit@rpikit` — **lines 29–33 must be removed when plugin is uninstalled**
- `extraKnownMarketplaces`: `rpikit` marketplace pointing to `bostonaholic/rpikit` — **lines 34–41 must be removed when plugin is uninstalled**
- Feature flags: `alwaysThinkingEnabled`, `effortLevel`, `skipDangerousModePermissionPrompt`, `showTurnDuration`, `teammateMode`

### settings.local.json

Two files with this name:
- `~/src/Panoply/settings.local.json` — tracked (but gitignored — see Section 5), permissions: `Bash(*)`, `Read`, `Edit`, `Write`, `Glob`, `Grep`, `WebSearch`
- `~/src/Panoply/.claude/settings.local.json` — repo-scoped settings, contains hardcoded `Read` permissions for the rpikit plugin cache path (`settings.local.json:19–20`): **these two lines must be removed when plugin is uninstalled**

---

## 5. Gitignore and tracked files

`~/src/Panoply/.gitignore:2`:
```
settings.local.json
```

This means `~/src/Panoply/settings.local.json` (the machine-specific permissions file) is **not tracked by git** — correct and intentional. The example template `settings.local.example.json` is tracked.

`~/src/Panoply/.claude/settings.local.json` is inside `.claude/` — this IS tracked in git (no gitignore pattern covers it).

An `agents/` directory at `~/src/Panoply/agents/` would be tracked cleanly — no gitignore pattern covers it. Similarly, adding rpikit skills to `~/src/Panoply/skills/` puts them in a fully tracked path.

**No forked rpikit content will collide with any gitignore exclusion.**

Runtime/state exclusions in `.gitignore` (`**/data/browser_state/`, `**/auth_info.json`, `**/library.json`, `**/state.json`) apply to skill runtime artifacts, not to `SKILL.md` or agent `.md` files.

---

## 6. Directory-naming conventions for skills

A Panoply skill is a directory under `~/src/Panoply/skills/<skill-name>/` containing at minimum a `SKILL.md` file. Optional subdirs:

| Subdir | Used in | Purpose |
|--------|---------|---------|
| `references/` | `refine-project/`, `review/` | Context docs injected by `SKILL.md` via `!cat` commands |
| `scripts/` | `skill-creator/` | Python helper scripts invoked from skill |

Confirmed by inspecting:
- `skills/refine-project/`: `SKILL.md` + `references/` (`skills/refine-project/SKILL.md:1`, `ls` output)
- `skills/review/`: `SKILL.md` + `references/` (same pattern)
- `skills/skill-creator/`: `SKILL.md` + `references/` + `scripts/` + `LICENSE.txt`

**rpikit skill structure is simpler** — every one of the 16 rpikit skills contains only `SKILL.md` (confirmed by iterating all 16 dirs). No `references/` or `scripts/` subdirs.

**SKILL.md frontmatter comparison:**

Panoply (`refine-project/SKILL.md:1–5`):
```yaml
---
description: Refine a project intent document...
argument-hint: "[project-name]"
user_invocable: true
---
```

rpikit (`researching-codebase/SKILL.md:1–5`):
```yaml
---
name: researching-codebase
description: Thorough codebase exploration...
argument-hint: topic or question to research
---
```

Both formats are valid. The `name:` field in rpikit skills is informational (matches the folder name) and does not affect discovery. Forked rpikit `SKILL.md` files **drop in without any adjustment required**.

---

## 7. Plugin installation footprint — what to remove

All references to rpikit in tracked Panoply files:

| File | Lines | Content to remove |
|------|-------|-------------------|
| `settings.json` | 29–33 | `"enabledPlugins"` block entries: `"rpikit@rpikit": true` (and `"dbt-skills@data-engineering-skills": true` if that plugin is also being uninstalled) |
| `settings.json` | 34–41 | Entire `"extraKnownMarketplaces"` block (or just the `"rpikit"` key if dbt-skills marketplace is still needed) |
| `.claude/settings.local.json` | 19–20 | `"Read(//Users/matthumanhealth/.claude/plugins/cache/rpikit/rpikit/0.8.0/**)"` and `"Read(//Users/matthumanhealth/.claude/plugins/**)"` |
| `README.md` | 75, 139, 161–170, 180 | References to "9 via plugin", plugin install instructions, plugin management commands |

The runtime plugin registry files (`~/.claude/plugins/installed_plugins.json`, `~/.claude/plugins/known_marketplaces.json`) are **not tracked in Panoply** — they will be cleaned up by Claude Code's plugin uninstall command.

---

## Recommended landing paths for forked rpikit skills and agents

### Skills (16 total)

**Target:** `~/src/Panoply/skills/<skill-name>/SKILL.md`

Each of the 16 rpikit skill directories is copied verbatim:
```
~/src/Panoply/skills/brainstorming/SKILL.md
~/src/Panoply/skills/documenting-decisions/SKILL.md
~/src/Panoply/skills/finishing-work/SKILL.md
~/src/Panoply/skills/git-worktrees/SKILL.md
~/src/Panoply/skills/implementing-plans/SKILL.md
~/src/Panoply/skills/parallel-agents/SKILL.md
~/src/Panoply/skills/receiving-code-review/SKILL.md
~/src/Panoply/skills/research-plan-implement/SKILL.md
~/src/Panoply/skills/researching-codebase/SKILL.md
~/src/Panoply/skills/reviewing-code/SKILL.md
~/src/Panoply/skills/security-review/SKILL.md
~/src/Panoply/skills/synthesizing-research/SKILL.md
~/src/Panoply/skills/systematic-debugging/SKILL.md
~/src/Panoply/skills/test-driven-development/SKILL.md
~/src/Panoply/skills/verification-before-completion/SKILL.md
~/src/Panoply/skills/writing-plans/SKILL.md
```

No setup.sh change needed — `~/.claude/skills` is already symlinked to `~/src/Panoply/skills/`.

Invocation changes after fork: `rpikit:researching-codebase` becomes `/researching-codebase`, `rpikit:writing-plans` becomes `/writing-plans`, etc.

**Name collision check:** None of the 16 rpikit skill names collide with the 16 existing Panoply skill folder names. (Panoply has: `article-extractor`, `complete-project`, `design-project`, `design-studio`, `end-session`, `organise-repo`, `pdf`, `react-best-practices`, `refine-project`, `retro`, `review`, `skill-creator`, `system-feedback`, `wardley-mapping`, `xlsx`, and an unlisted `loop`/`keybindings-help`/`simplify`/`update-config` from the system-reminder that do not appear as folders in `skills/` — likely shipped via a different plugin.)

### Agents (7 total)

**Target:** `~/src/Panoply/agents/<agent-name>.md`

```
~/src/Panoply/agents/code-reviewer.md
~/src/Panoply/agents/debugger.md
~/src/Panoply/agents/file-finder.md
~/src/Panoply/agents/security-reviewer.md
~/src/Panoply/agents/test-runner.md
~/src/Panoply/agents/verifier.md
~/src/Panoply/agents/web-researcher.md
```

**Required setup.sh change:** Add `agents` to the `SYMLINK_ITEMS` array at `setup.sh:16`:
```bash
SYMLINK_ITEMS=(CLAUDE.md settings.json hooks skills agents)
```

This will create `~/.claude/agents/ -> ~/src/Panoply/agents/` on the next `setup.sh` run. For the current machine, run the symlink command manually:
```bash
ln -s ~/src/Panoply/agents ~/.claude/agents
```

### Summary table

| Asset type | Count | Destination in Panoply | setup.sh change needed |
|------------|-------|------------------------|------------------------|
| Skills | 16 | `skills/<name>/SKILL.md` | None |
| Agents | 7 | `agents/<name>.md` | Add `agents` to `SYMLINK_ITEMS` |
| settings.json cleanup | — | Remove `enabledPlugins.rpikit@rpikit` + `extraKnownMarketplaces.rpikit` | — |
| .claude/settings.local.json cleanup | — | Remove plugin cache Read permissions (lines 19–20) | — |
| README.md cleanup | — | Remove plugin install instructions | — |
