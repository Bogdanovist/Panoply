# rpikit Fork Resolution: Claude Code Plugin/Skill Discovery Research

**Date**: 2026-04-14  
**Purpose**: Authoritative reference for safely forking rpikit into user-level dotfiles, covering discovery paths, precedence, namespacing, and uninstall mechanics.

---

## Q1. Skill Discovery Paths and Precedence

### Paths Scanned

Claude Code discovers skills from four tiers, in descending priority order:

| Priority | Tier | Path |
|----------|------|------|
| 1 (highest) | Enterprise/Managed | `/Library/Application Support/ClaudeCode/` (macOS), `/etc/claude-code/` (Linux) |
| 2 | Personal/User | `~/.claude/skills/<skill-name>/SKILL.md` |
| 3 | Project | `.claude/skills/<skill-name>/SKILL.md` |
| 4 (lowest) | Plugin | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/<skill-name>/SKILL.md` |

The legacy flat-file format also works: `.claude/commands/<skill-name>.md` (or `~/.claude/skills/<skill-name>/SKILL.md` with the old commands/ layout). Both formats are treated identically — if a skill and a command share the same name, the skill takes precedence.

**Additional discovery**: Monorepo support — when Claude is working on files in a subdirectory, `packages/frontend/.claude/skills/` is also scanned automatically.

**--add-dir exception**: The `--add-dir` flag grants file access, not configuration discovery, but `.claude/skills/` within an added directory *is* loaded as an exception.

### Precedence Rule

When skills share the same name across tiers: **enterprise > personal (user) > project**. Plugin skills are namespaced (see Q2) and therefore cannot conflict with the other three tiers.

**Source**: `https://code.claude.com/docs/en/skills` — "Where skills live" table and note: *"When skills share the same name across levels, higher-priority locations win: enterprise > personal > project."*

### Hot Reload

Claude Code watches skill directories for file changes. Adding, editing, or removing a skill under `~/.claude/skills/`, the project `.claude/skills/`, or a `.claude/skills/` inside an `--add-dir` directory **takes effect within the current session without restarting**.

Exception: Creating a *top-level* skills directory that did not exist when the session started requires a restart so the new directory can be watched.

**Source**: `https://code.claude.com/docs/en/skills` — "Live change detection" section.

---

## Q2. Namespacing: Plugin vs. Standalone Skills

### Plugin Skills

Plugin skills always carry a namespace prefix derived from the `name` field in `.claude-plugin/plugin.json`. A plugin named `rpikit` with a skill folder `brainstorming` is invoked as `/rpikit:brainstorming`. This is non-negotiable — the namespace is the `name` field value.

**Source**: `https://code.claude.com/docs/en/plugins` — *"Plugin skills are always namespaced (like `/my-first-plugin:hello`) to prevent conflicts when multiple plugins have skills with the same name."*

**Source**: `https://code.claude.com/docs/en/plugins-reference` — *"This name is used for namespacing components. For example, in the UI, the agent `agent-creator` for the plugin with name `plugin-dev` will appear as `plugin-dev:agent-creator`."*

### User-Level and Project-Level Skills

Skills placed in `~/.claude/skills/` or `.claude/skills/` are **plain-named** — no namespace prefix. A skill at `~/.claude/skills/brainstorming/SKILL.md` is invoked as `/brainstorming`, not `/rpikit:brainstorming`.

This is the fundamental difference: forking rpikit to user-level strips the namespace. Users would call `/brainstorming` instead of `/rpikit:brainstorming`.

### Collision/Ambiguity Rules

If `~/.claude/skills/brainstorming/` exists AND the rpikit plugin is still installed:
- `/brainstorming` → resolves to the user-level skill (higher priority)
- `/rpikit:brainstorming` → still resolves to the plugin skill (different namespace, no conflict)

The two can coexist without ambiguity because they occupy different namespaces.

---

## Q3. Agent Discovery: Paths, Precedence, Namespace

### Paths Scanned

| Tier | Path |
|------|------|
| User | `~/.claude/agents/<agent-name>.md` |
| Project | `.claude/agents/<agent-name>.md` |
| Plugin | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/agents/<agent-name>.md` |

Confirmed in the settings docs table: *"Subagents: User location `~/.claude/agents/`, Project location `.claude/agents/`"*.

**Source**: `https://code.claude.com/docs/en/settings` — "What uses scopes" table.

### Precedence

Same tier hierarchy as skills: enterprise > user > project. Plugin agents are namespaced by plugin name (e.g., `rpikit:code-reviewer`), same rule as skills.

**Source**: `https://code.claude.com/docs/en/plugins-reference` — *"Plugin agents support `name`, `description`, `model`... Plugin agents work alongside built-in Claude agents"* and the same namespacing rule applies.

### Namespacing

Plugin agents appear as `plugin-name:agent-name` in the `/agents` interface. User-level agents appear without namespace. Same fork implications as skills — namespacing is dropped when moved to user-level.

Current rpikit agents observed in cache:
```
~/.claude/plugins/cache/rpikit/rpikit/0.8.0/agents/
  code-reviewer.md, debugger.md, file-finder.md, security-reviewer.md, test-runner.md, verifier.md, web-researcher.md
```

---

## Q4. Commands Discovery and Registration

### How Commands Work

Commands (`.md` files in `commands/`) and skills (subdirectories with `SKILL.md`) are treated identically. Both become `/slash-commands`. The `commands/` format is considered legacy; the `skills/` directory format is preferred for new plugins but both load the same way.

**Source**: `https://code.claude.com/docs/en/skills` — *"A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way."*

### Plugin Commands (e.g., `/rpikit:research-plan-implement`)

Commands inside a plugin are namespaced the same as skills: `plugin-name:command-name`. The `research-plan-implement` skill in rpikit is at:
```
~/.claude/plugins/cache/rpikit/rpikit/0.8.0/skills/research-plan-implement/SKILL.md
```
It is invoked as `/rpikit:research-plan-implement` because the plugin name is `rpikit`.

### Registration Mechanism

Commands/skills are **not registered in settings.json** — they are auto-discovered by scanning directories at startup (and live-watched thereafter). The `enabledPlugins` key in settings.json controls whether a plugin is loaded at all, but the individual skills/commands within it are not listed anywhere — discovery is entirely filesystem-based.

**Source**: `https://code.claude.com/docs/en/plugins-reference` — "Auto-Discovery Mechanism" section: *"Skills: Scans `skills/` for subdirectories containing `SKILL.md`"*.

### Forked Command Name

If `research-plan-implement` is moved to `~/.claude/skills/research-plan-implement/SKILL.md`, it becomes `/research-plan-implement` (no namespace). There is no way to keep the `/rpikit:` prefix for a user-level skill — the namespace is a plugin-only feature.

---

## Q5. Repo-Level Rules: `.claude/rules/` Convention

### Is It a Real Claude Code Convention?

Yes. `.claude/rules/` is an **official, documented Claude Code convention**, not a user-invented one.

**Source**: `https://code.claude.com/docs/en/memory` — "Organize rules with `.claude/rules/`" section:

> *"For larger projects, you can organize instructions into multiple files using the `.claude/rules/` directory. This keeps instructions modular and easier for teams to maintain."*

Structure example from docs:
```
your-project/
├── .claude/
│   ├── CLAUDE.md           # Main project instructions
│   └── rules/
│       ├── code-style.md
│       ├── testing.md
│       └── security.md
```

### How It Surfaces Into Context

- Rules files without `paths` frontmatter are loaded at session launch alongside `.claude/CLAUDE.md`
- Rules files with `paths` frontmatter are **path-scoped** — they only load when Claude is working with files matching the specified glob patterns
- All `.md` files are discovered recursively, so subdirectories like `rules/frontend/` work
- User-level rules at `~/.claude/rules/` also work and are loaded before project rules (giving project rules higher priority per the standard scope hierarchy)

**Source**: `https://code.claude.com/docs/en/memory` — *"Rules without a `paths` field are loaded unconditionally and apply to all files. Path-scoped rules trigger when Claude reads files matching the pattern."*

### How It Relates to Skills

Rules and skills serve different purposes:
- **Rules** (`.claude/rules/`) load into context every session or when matching files are opened. Always available to Claude.
- **Skills** load only when invoked or when Claude determines they're relevant. Better for task-specific procedures.

The user's CLAUDE.md convention of `<repo>/.claude/rules/` is fully supported by Claude Code. It is *not* something that only works if skills look there manually.

---

## Q6. Plugin Uninstall Mechanics

### Config Files Affected

Three files are modified on install, and all three need cleanup on uninstall:

| File | What it contains | Modified on install? | Cleaned on uninstall? |
|------|-----------------|---------------------|----------------------|
| `~/.claude/settings.json` | `enabledPlugins: {"rpikit@rpikit": true}`, `extraKnownMarketplaces: {rpikit: ...}` | Yes | **Partially — known bugs** |
| `~/.claude/plugins/installed_plugins.json` | Plugin record with `installPath`, `version`, `gitCommitSha` | Yes | Yes (CLI) / sometimes re-adds |
| `~/.claude/plugins/cache/rpikit/rpikit/0.8.0/` | Cached plugin files | Yes | Orphaned; deleted after 7-day grace period |
| `~/.claude/plugins/marketplaces/rpikit/` | Local clone of marketplace | Yes (on `marketplace add`) | **Not always cleaned** |

**Source**: Local file inspection of `~/.claude/plugins/installed_plugins.json` and `~/.claude/settings.json`.

### Does Uninstall Remove Cache?

**Partially.** From official docs: *"When you update or uninstall a plugin, the previous version directory is marked as orphaned and removed automatically 7 days later."* The grace period exists for concurrent sessions.

**Source**: `https://code.claude.com/docs/en/plugins-reference` — "Plugin caching and file resolution" section.

### Known Bugs Affecting Uninstall

1. **`enabledPlugins: false` ignored** (Issue #28554): Setting `"rpikit@rpikit": false` in settings.json does not reliably prevent loading. The auto-reinstall mechanism re-adds entries to `installed_plugins.json` with a new `gitCommitSha` on restart.

2. **Marketplace removal doesn't clean settings.json** (Issue #9537): After `/plugin marketplace remove`, the `extraKnownMarketplaces` and `enabledPlugins` entries remain in `~/.claude/settings.json`, causing the marketplace to reinstall on next startup.

3. **Manual surgery required** (Issue #38714): There is no fully reliable automated uninstall path. The plugin.json validator runs at startup against all marketplace entries, even disabled ones.

### Reliable Manual Uninstall Sequence

```bash
# 1. Disable in current session
/plugin disable rpikit@rpikit

# 2. Uninstall via CLI (removes installed_plugins.json entry and marks cache for deletion)
claude plugin uninstall rpikit@rpikit

# 3. Remove enabledPlugins entry from ~/.claude/settings.json manually:
#    Delete: "rpikit@rpikit": true from enabledPlugins object

# 4. Remove extraKnownMarketplaces entry from ~/.claude/settings.json manually:
#    Delete: "rpikit": { "source": { "source": "github", "repo": "bostonaholic/rpikit" } }

# 5. Optionally remove marketplace (only if you don't want future installs):
/plugin marketplace remove rpikit

# 6. Force-clean cache immediately (don't wait 7 days):
rm -rf ~/.claude/plugins/cache/rpikit
rm -rf ~/.claude/plugins/marketplaces/rpikit
```

**Source**: Issues #28554, #9537, #38714 on `github.com/anthropics/claude-code`; local file inspection.

---

## Q7. Enabled/Disabled State: Disable vs. Uninstall

### Official Mechanism

The official way to disable without uninstalling:
```bash
/plugin disable rpikit@rpikit
# or
claude plugin disable rpikit@rpikit
```

This sets `"rpikit@rpikit": false` in `enabledPlugins` in `~/.claude/settings.json`.

To re-enable:
```bash
/plugin enable rpikit@rpikit
```

**Source**: `https://code.claude.com/docs/en/discover-plugins` — "Manage installed plugins" section.

### Is Disable a Safe Transitional Step?

**Unresolved — best guess is: partially reliable, not fully safe.** Issue #28554 shows that `enabledPlugins: false` is ignored in at least some versions, with the plugin MCP server still loading. This may have been fixed in later versions — the issue is from early 2026.

**Practical recommendation**: For the transitional phase (forked skills exist at user-level, rpikit plugin still installed), disable is safer than leaving enabled, but the user-level skills will already take precedence for same-named skills regardless of plugin state (due to user > plugin priority). The main risk of not fully disabling is duplicate behavior for skills with *different* names (plugin has more skills than the fork initially includes).

---

## Q8. Hot Reload

**Confirmed: Yes, hot reload works for skill file changes.**

From official docs:

> *"Claude Code watches skill directories for file changes. Adding, editing, or removing a skill under `~/.claude/skills/`, the project `.claude/skills/`, or a `.claude/skills/` inside an `--add-dir` directory takes effect within the current session without restarting."*

**Exception**: Creating a top-level skills directory (`~/.claude/skills/`) that did not exist when the session started requires a restart.

**Implication for fork testing**: As long as `~/.claude/skills/` exists before starting Claude Code, adding new skill subdirectories and editing `SKILL.md` files is picked up live. No restart needed for iteration.

**Additional reload mechanism**: `/reload-plugins` reloads all active plugins (not standalone user skills, which use file watching). For plugin changes loaded via `--plugin-dir`, `/reload-plugins` is required.

**Source**: `https://code.claude.com/docs/en/skills` — "Live change detection" section.

---

## Q9. Repo-Level Skill Override of User-Level Skill

### Is Project-Level Shadowing Real?

**Yes, confirmed.** Project-level skills (`.claude/skills/testing/SKILL.md`) shadow user-level skills (`~/.claude/skills/testing/SKILL.md`) when they share the same name. This is because the skill precedence order is **enterprise > user > project** — but note this means user wins over project, not the other way around.

**Wait — re-reading carefully**: The docs state *"higher-priority locations win: enterprise > personal > project"*. This means **user-level (personal) BEATS project-level**. A `.claude/skills/testing.md` in a repo does NOT shadow `~/.claude/skills/testing.md`. The user-level version wins.

**Source**: `https://code.claude.com/docs/en/skills` — *"When skills share the same name across levels, higher-priority locations win: enterprise > personal > project."*

### Implication for "Testing Conventions Differ Per Repo"

The precedence order means the pattern works the **opposite** of what might be assumed:

- **If you want a repo-specific testing skill to WIN**: it must be at user-level or higher. A project `.claude/skills/testing.md` will be shadowed by `~/.claude/skills/testing.md`.
- **If you want the user-level testing.md to be the default but a repo to use something different**: the repo cannot override it with a project-level skill.

**However**, there is a workaround using the `paths` frontmatter in `.claude/rules/`:

```markdown
---
paths:
  - "tests/**/*.py"
---
# Repo-specific testing conventions for this project
```

Rules do NOT have the same precedence as skills — project rules supplement user rules (they don't override). But path-scoped rules only activate for matching files, which achieves selective loading.

**For repo-specific skill overrides that truly shadow user-level**: the only mechanism is using different skill names per repo (e.g., `testing-datascience` vs `testing-analytics`) or using `disable-model-invocation: true` on the user-level skill and having a project-level one that Claude is instructed to prefer for that repo via CLAUDE.md.

**Unresolved — best guess**: The user's CLAUDE.md references "repo-specific conventions/rules → `.claude/rules/`" which suggests rules (not skills) are the intended mechanism for per-repo overrides. This is consistent with the docs. Rules load into context always (unlike skills which load on demand), which means a project-level `testing.md` rule will add testing conventions to context even though the user-level `testing` skill still wins for invocation purposes.

---

## Q10. settings.json Impact: Plugin Keys and Cleanup

### Keys in `~/.claude/settings.json` for rpikit

Current state (from local file inspection):
```json
{
  "enabledPlugins": {
    "dbt-skills@data-engineering-skills": true,
    "github@claude-plugins-official": true,
    "rpikit@rpikit": true
  },
  "extraKnownMarketplaces": {
    "rpikit": {
      "source": {
        "source": "github",
        "repo": "bostonaholic/rpikit"
      }
    }
  }
}
```

### Keys That Need Cleanup After Fork

To fully sever the rpikit plugin after forking skills to user-level:

1. **Remove from `enabledPlugins`**: Delete `"rpikit@rpikit": true`
2. **Remove from `extraKnownMarketplaces`**: Delete the entire `rpikit` block
3. **Do NOT touch**: `github@claude-plugins-official` — unrelated
4. **Do NOT touch**: `dbt-skills@data-engineering-skills` — unrelated

### Additional Plugin Config Location

Per the docs, plugin-specific user config (prompts at install time) is stored under `pluginConfigs` in settings.json. rpikit does not appear to use `userConfig` in its manifest, so this key likely does not exist. Verify with:
```bash
python3 -c "import json; d=json.load(open(expanduser('~/.claude/settings.json'))); print(d.get('pluginConfigs', 'NOT PRESENT'))"
```

**Source**: `https://code.claude.com/docs/en/settings` — "Plugin configuration" and "Plugin settings" sections; `https://code.claude.com/docs/en/plugins-reference` — "User configuration" section.

---

## Implications for the Fork

### Where to Place Forked Skills/Agents for Clean Discovery

**Skills**: `~/.claude/skills/<skill-name>/SKILL.md`  
Each rpikit skill directory maps 1:1 — copy `skills/brainstorming/` → `~/.claude/skills/brainstorming/`.

**Agents**: `~/.claude/agents/<agent-name>.md`  
Each `.md` file from `agents/` → `~/.claude/agents/<agent-name>.md`.

**Do not place in Panoply repo's `.claude/`** unless the intent is project-scoped only. User-level placement makes them available in all repos, which matches the intent of forking a cross-project plugin.

### Whether Namespacing Needs to Be Preserved or Dropped

Namespacing **must be dropped**. There is no way to invoke user-level skills with a namespace prefix — that is a plugin-only feature. The forked skills become `/brainstorming`, `/research-plan-implement`, etc.

If any skill content internally references `${CLAUDE_SKILL_DIR}` or other plugin-specific variables, those still work in user-level skills. The `$ARGUMENTS` substitution and other frontmatter features are fully available outside plugins.

**Transition note**: While both the plugin and the forked skills coexist, there will be two invocation paths:
- `/rpikit:brainstorming` → plugin version  
- `/brainstorming` → user-level version (wins for auto-invocation if descriptions match)

Once the plugin is removed, only `/brainstorming` exists.

### Recommended Uninstall Sequence

1. **Fork first**: Copy all skills to `~/.claude/skills/`, all agents to `~/.claude/agents/`
2. **Test in parallel**: Both `/skill-name` and `/rpikit:skill-name` will work; verify user-level versions behave as expected
3. **Disable plugin**: `claude plugin disable rpikit@rpikit` (sets `enabledPlugins: false`)
4. **Run a few sessions** to verify nothing breaks with plugin disabled
5. **Uninstall plugin**: `claude plugin uninstall rpikit@rpikit`
6. **Manual settings.json cleanup** (required due to known bugs):
   - Remove `"rpikit@rpikit"` from `enabledPlugins`
   - Remove `rpikit` block from `extraKnownMarketplaces`
7. **Remove marketplace**: `/plugin marketplace remove rpikit`
8. **Force-clean cache**: `rm -rf ~/.claude/plugins/cache/rpikit && rm -rf ~/.claude/plugins/marketplaces/rpikit`
9. **Restart Claude Code** and verify skills work as `/skill-name`

### Whether Repo-Level Rules/Skills Shadowing Is a Real Mechanism

**Partially real, but direction is opposite for skills.** 

For **rules** (`.claude/rules/`): Yes, fully real. Project rules load alongside user rules — they don't replace, they supplement. Path-scoped rules (`paths:` frontmatter) are the right mechanism for per-repo behavioral conventions that should only apply to specific file types.

For **skills**: Project-level skills do NOT shadow user-level skills. User-level wins. So `.claude/skills/testing/SKILL.md` in a repo will be ignored in favor of `~/.claude/skills/testing/SKILL.md`.

**Practical recommendation for testing-convention overrides**:
- Use `.claude/rules/testing.md` with `paths: ["tests/**"]` frontmatter for per-repo testing conventions that load as context
- Use different skill names per repo type if you need different invocable behaviors (e.g., `~/.claude/skills/testing-datascience/` vs `~/.claude/skills/testing-analytics/`)
- Use CLAUDE.md imports (`@.claude/rules/testing.md`) to pull in repo-specific rules explicitly

The user's existing practice of `<repo>/.claude/rules/` is the correct, documented mechanism for repo-specific conventions.

---

## Sources

- Official docs (redirected from docs.anthropic.com): `https://code.claude.com/docs/en/skills`, `/plugins`, `/settings`, `/memory`, `/discover-plugins`, `/plugins-reference`
- Issue #16165: `https://github.com/anthropics/claude-code/issues/16165` — skill creation location, precedence confirmation
- Issue #19212: `https://github.com/anthropics/claude-code/issues/19212` — Skill tool recognition of local skills (closed as not planned)
- Issue #29360: `https://github.com/anthropics/claude-code/issues/29360` — `--plugin-dir` namespacing / allowed-tools bug
- Issue #28554: `https://github.com/anthropics/claude-code/issues/28554` — `enabledPlugins: false` ignored bug
- Issue #9537: `https://github.com/anthropics/claude-code/issues/9537` — marketplace removal not cleaning settings.json
- Issue #38714: `https://github.com/anthropics/claude-code/issues/38714` — no reliable uninstall path
- Local files inspected: `~/.claude/settings.json`, `~/.claude/plugins/installed_plugins.json`, `~/.claude/plugins/known_marketplaces.json`, `~/.claude/plugins/cache/rpikit/rpikit/0.8.0/` directory tree, `~/.claude/skills/` listing
