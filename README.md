# Claude Code Configuration

An opinionated [Claude Code](https://docs.anthropic.com/en/docs/claude-code) setup optimised for **deep reasoning**, **maximum output length**, and **minimal interruption**. Extended thinking is always on, output tokens are set to 64k, agent teams run in parallel across tmux panes, and every response is auto-committed and pushed — no manual version control.

## What This Optimises For

| Priority | How |
|---|---|
| **Output quality** | Extended thinking (chain-of-thought) enabled on every response |
| **No truncation** | 64k output tokens — Claude never cuts off mid-function |
| **Long sessions** | Auto-compaction at 80% context prevents abrupt context loss |
| **Parallel work** | Agent teams with tmux split panes for real-time visibility |
| **Zero friction** | Auto-commit + push on every response, broad tool permissions |
| **Data science** | dbt + Snowflake skills via plugin, SQL/notebook conventions in CLAUDE.md |
| **Safety** | Pre-commit hook blocks secrets, deny rules protect sensitive files |

## Quick Start

### Fork and customise (recommended)

```bash
# 1. Fork this repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/dotfiles-claude.git ~/dotfiles-claude
cd ~/dotfiles-claude
git remote add upstream https://github.com/haberlah/dotfiles-claude.git

# 2. Run setup (symlinks config into ~/.claude/, copies permission template)
~/dotfiles-claude/setup.sh
```

### Or clone directly (if you don't plan to track upstream updates)

```bash
git clone https://github.com/haberlah/dotfiles-claude.git ~/dotfiles-claude
~/dotfiles-claude/setup.sh
```

The setup script:
- Symlinks `CLAUDE.md`, `settings.json`, `hooks/`, and `agents/` into `~/.claude/`
- Populates `~/.claude/skills/` from the active skill **bundle** (see [Skill bundles](#skill-bundles))
- Copies `settings.local.example.json` to `settings.local.json` (your machine-specific permissions — gitignored, never pushed)
- Installs a pre-commit hook that blocks secrets
- Backs up any existing config before overwriting

## Subscribe to Updates

Pull new skills, hook improvements, and settings changes from upstream:

```bash
cd ~/dotfiles-claude && git fetch upstream && git merge upstream/main
```

Changes take effect on the next `claude` session.

**Auto-pull daily** — add to `~/.zshrc`:

```sh
if [ -d "$HOME/dotfiles-claude/.git" ] && [[ ! -f /tmp/.dotfiles-claude-pulled-$(date +%Y%m%d) ]]; then
  (cd "$HOME/dotfiles-claude" && git pull --ff-only upstream main 2>/dev/null || git pull --ff-only origin main &>/dev/null &)
  touch /tmp/.dotfiles-claude-pulled-$(date +%Y%m%d)
fi
```

Runs silently in the background on first terminal open each day. `--ff-only` ensures it never overwrites local customisations.

## Repo Structure

```
dotfiles-claude/
├── CLAUDE.md                       # Global instructions for every session
├── settings.json                   # Core settings, env vars, hooks
├── settings.local.example.json     # Permission template (copied on setup)
├── hooks/
│   ├── auto-commit-push.sh         # Stop hook: auto-commit + push
│   └── pre-commit-secrets-check.sh # Git hook: blocks secrets from commits
├── skill-bundles/                  # Swappable skill sets (see Skill bundles)
│   ├── ACTIVE                      # one-line file: name of default bundle
│   ├── core/                       # always-on infra skills (21)
│   ├── rpi/                        # research-plan-implement methodology (6)
│   └── agentivestack/              # DDD-style methodology, fork-by-copy (7)
├── agents/                         # 7 local agents
├── scripts/
│   ├── panoply-skills              # bundle switcher
│   └── claude-skills               # per-session bundle override wrapper
├── setup.sh                        # One-command installer
└── LICENSE                         # MIT
```

> `settings.local.json` is gitignored — your machine-specific permissions stay local and are never pushed.

## Settings Reference

### Core settings (`settings.json`)

| Setting | Value | Effect |
|---|---|---|
| `alwaysThinkingEnabled` | `true` | Extended thinking on every response. Better architecture decisions, debugging, and multi-step refactors. |
| `showTurnDuration` | `true` | Shows per-turn timing. Helps spot slow MCP tools or overly broad searches. |
| `teammateMode` | `"tmux"` | Agent teams in tmux split panes. Watch each agent work in real time. |

### Environment variables

| Variable | Value | Effect |
|---|---|---|
| `CLAUDE_CODE_MAX_OUTPUT_TOKENS` | `64000` | Double the default (32k). Increase to `128000` if responses are still truncating, at the cost of more frequent auto-compaction. |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | `80` | Auto-compacts at 80% context usage (default 90%). Larger buffer before context limits. |
| `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `1` | Enables parallel agent teams. Ask Claude to "use a team" for multi-file tasks. |
| `MCP_TIMEOUT` | `30000` | 30s MCP server connection timeout (up from default 10s). |
| `MCP_TOOL_TIMEOUT` | `60000` | 60s per-tool timeout. Needed for browser automation and file uploads. |

### Permissions (`settings.local.example.json`)

Three-tier permission model: **deny > ask > allow**.

| Tier | What it covers |
|---|---|
| **deny** | Reading `.env` files, SSH keys, AWS credentials, `.pem`/`.key` files — always blocked |
| **ask** | Destructive ops: `rm -rf`, `sudo rm`, `git push --force`, `git reset --hard`, `git checkout --`, `git clean`, `git branch -D`, `chmod 777` — requires confirmation |
| **allow** | Everything else: file ops, Bash, web access, Playwright, Brave Search — runs without prompting |

> **Note:** `Bash(*)` auto-allows all shell commands. This is for power users who trust Claude to operate autonomously. For tighter control, remove it from the allow list — Claude will then prompt before each command.

## Auto-Commit Workflow

The Stop hook runs after every Claude response and handles two repos:

**Your project** — stages, commits (`auto: <files>`), and pushes. Uses `--no-verify` for speed.

**This config repo** (`~/dotfiles-claude/`) — detects changes to settings, skills, or hooks and auto-commits. Runs the pre-commit secrets hook before pushing. If secrets are detected, the push is blocked.

This means installing a skill, tweaking a setting, or adding a hook is automatically synced to GitHub.

## Security

**Pre-commit hook** scans every dotfiles commit for:
- API keys (Anthropic, GitHub, AWS, Stripe, Slack, SendGrid, Vercel, npm, PyPI)
- JWTs and session cookies
- Google Cloud service account keys
- Private keys and certificate files
- Credential files (`.env`, `credentials.json`, `.npmrc`, `.pypirc`)

**Gitignore** provides defence in depth — sensitive file types are blocked at both the git and hook level.

**Deny rules** in permissions prevent Claude from reading `.env` files, SSH keys, and cloud credentials during sessions.

## Skill bundles

Skills are organised into **bundles** so you can swap between competing methodologies (e.g. RPI vs Agentive/DDD) without contaminating each other. `~/.claude/skills/` is populated from `core/` + one methodology bundle. Only one methodology is active at a time.

```
skill-bundles/
├── ACTIVE              ← one-line file holding the default bundle name (rpi)
├── core/               always-on infra; survives every swap
├── rpi/                research-plan-implement methodology
└── agentivestack/      DDD/spec/slice methodology (fork-by-copy)
```

**Default (set once)** — edit `skill-bundles/ACTIVE` (or run `scripts/panoply-skills use <bundle>`). Every new Claude session picks up that bundle silently. The choice is version-controlled, so it's reproducible across machines.

**Per-session override (occasional)** — launch with `scripts/claude-skills <bundle>`. This re-links symlinks, runs `claude`, and restores the default on exit. `ACTIVE` is never touched.

```bash
scripts/panoply-skills which               # show active bundle
scripts/panoply-skills list                # list available bundles
scripts/panoply-skills use agentivestack   # change default
scripts/claude-skills agentivestack        # one-shot override (default restored on exit)
```

> **Caveat — parallel sessions share `~/.claude/skills/`.** Two top-level `claude` invocations in different terminals can't run on different bundles at once: the one started later overwrites the symlink farm for both. Fine for serial overrides, not safe for parallel sessions on different methodologies. Sub-agents spawned within a single session inherit that session's bundle, so agent teams stay consistent.

### Adding a new bundle

Create a new directory under `skill-bundles/<name>/`, drop skill subdirectories with `SKILL.md` files in each, then `scripts/panoply-skills use <name>`. The switcher refuses to link if any skill name collides with `core/`.

## Skills

27 local skills + 9 via plugin (36 total). Active set depends on the chosen bundle.

### Core bundle — always linked (21)

| Skill | Purpose |
|---|---|
| `article-extractor` | Extract clean content from URLs |
| `brainstorming` | Collaborative design dialogue before research/planning |
| `design-studio` | Interactive Streamlit design studio with hot-reload |
| `documenting-decisions` | Record ADRs in `docs/decisions/` |
| `end-session` | CI checks + push + PR on session exit |
| `finishing-work` | Structured completion workflow for implementations |
| `git-worktrees` | Isolated worktree setup for parallel development |
| `organise-repo` | Audit/set up a repo's `.claude/` configuration |
| `parallel-agents` | Concurrent agent dispatch for independent problems |
| `pdf` | Extract, merge, split, fill PDF forms |
| `pr-preflight` | Local mirror of the GitHub Claude review bot — runs the five-axis review prompt against the current branch and prints a PASS/WARN/BLOCK verdict to stdout |
| `react-best-practices` | Vercel's React/Next.js performance patterns |
| `receiving-code-review` | Verification-first response to review feedback |
| `retro` | Retrospective on code quality, context, and conventions |
| `reviewing-code` | Code review methodology with Conventional Comments |
| `security-review` | Security review methodology for implementation changes |
| `skill-creator` | Create new Claude Code skills |
| `system-feedback` | Feedback loop on the Panoply config system itself |
| `systematic-debugging` | Root-cause investigation for failures and bugs |
| `verification-before-completion` | Evidence-before-claims for implementation completion |
| `xlsx` | Create/analyse spreadsheets |

### `rpi` bundle — research-plan-implement methodology (6)

| Skill | Purpose |
|---|---|
| `implementing-plans` | Execute an approved plan with checkpoint verification |
| `research-plan-implement` | End-to-end RPI pipeline via parallel subagents |
| `researching-codebase` | Thorough codebase exploration through dialogue |
| `synthesizing-research` | Consolidate multiple research docs into a unified report |
| `test-driven-development` | Rigorous RED-GREEN-REFACTOR discipline |
| `writing-plans` | Transform research into actionable implementation plans |

### `agentivestack` bundle — DDD/spec/slice methodology (7)

Forked from [AgentiveStack/skills](https://github.com/AgentiveStack/skills) at commit `69375219`. Copy-not-submodule — upstream changes don't auto-flow. See `skill-bundles/agentivestack/ORIGIN.md` for the rename map and rationale.

| Skill (slash command) | Purpose |
|---|---|
| `writing-specs` | Interview-driven feature spec grounded in domain language |
| `domain-modelling` | Stress-test a plan against the domain model |
| `slicing-features` | Break a spec into vertical tracer-bullet slices |
| `tracer-tdd` | Implement a slice with pragmatic, slice-flavoured TDD |
| `mapping-system` | Zoom out — map code into bounded contexts and data flow |
| `architecting` | Surface architectural friction; design deep module interfaces |
| `filing-bugs` | Conversational QA → durable GitHub issues in domain language |

### Local agents (in `agents/`)

| Agent | Purpose |
|---|---|
| `code-reviewer` | Quality-focused code review with soft-gating verdict |
| `debugger` | Root-cause debugging agent |
| `file-finder` | Locate files and symbols across the repo |
| `security-reviewer` | Security-focused review, hard-blocking verdict |
| `test-runner` | Run and interpret project tests |
| `verifier` | Evidence-based verification of claims |
| `web-researcher` | Web research with WebSearch/WebFetch |

### Plugin skills ([AltimateAI/data-engineering-skills](https://github.com/AltimateAI/data-engineering-skills))

Installed via `claude plugin`, not stored in this repo. Run after setup:

1. Add the marketplace:
   ```bash
   claude plugin marketplace add AltimateAI/data-engineering-skills
   ```
2. Install both skill packs:
   ```bash
   claude plugin install dbt-skills@data-engineering-skills
   claude plugin install snowflake-skills@data-engineering-skills
   ```

Skills are available immediately in your next Claude Code session.

| Plugin | Skills |
|---|---|
| `dbt-skills` | creating-dbt-models, debugging-dbt-errors, testing-dbt-models, documenting-dbt-models, migrating-sql-to-dbt, refactoring-dbt-models |
| `snowflake-skills` | finding-expensive-queries, optimizing-query-by-id, optimizing-query-text |

All skills are automatically available in Claude Code sessions. To invoke a skill, use `/<skill-name>` (e.g., `/pdf`, `/xlsx`). To remove a local skill, delete its directory from the relevant bundle under `skill-bundles/`. Plugin skills are managed via `claude plugin list` / `claude plugin uninstall`.

## Per-Repo Convention Overrides

User-level skills in `~/src/Panoply/skills/` are globally authoritative — project-level skills in a repo's `.claude/skills/` do NOT shadow them. This is architectural: Claude Code's skill resolution treats user-tier as the single source of truth for workflow methodology.

Per-repo conventions go in `.claude/rules/<name>.md` instead, with optional `paths:` frontmatter so rules load only when editing matching files. Rules are **additive, not override** — they supply repo-specific mechanics on top of the global methodology.

**Example**: a repo wants a different testing fixture style. Create `.claude/rules/testing.md`:

```markdown
---
paths:
  - "tests/**"
  - "**/*_test.py"
description: Test conventions for this repo
---

# Testing conventions

- Use pytest fixtures in `tests/conftest.py`, not module-level setup
- Mock external APIs with `responses`, not `unittest.mock`
- Factory pattern via `factory-boy`; no manual model construction
- Run locally with `pytest -q --maxfail=1`
```

The global `test-driven-development` skill continues to supply the RED-GREEN-REFACTOR methodology; the rule supplies the repo-specific runner invocation and fixture conventions.

See [Claude Code memory docs](https://code.claude.com/docs/en/memory) for how rules are loaded and scoped.

## Customising After Forking

| File | What to change |
|---|---|
| `CLAUDE.md` | Language preference, workflow conventions |
| `settings.local.json` | Your MCP server permissions, Bash permission level (gitignored — edit locally) |
| `settings.json` | Token limits, auto-commit behaviour, MCP timeouts |
| `skill-bundles/ACTIVE` | Default skill bundle (`rpi`, `agentivestack`, or your own) |
| `skill-bundles/<bundle>/` | Add/remove skills within a bundle, or create new bundles |

Shared settings (`settings.json`, `CLAUDE.md`, hooks, skills) sync via git. Machine-specific permissions (`settings.local.json`) stay local.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code): `npm install -g @anthropic-ai/claude-code`
- Anthropic API key or Max subscription (Claude Code prompts on first run)
- Git and [GitHub CLI](https://cli.github.com/) (`gh auth login` — needed for auto-push)
- tmux: `brew install tmux` (macOS) or `apt install tmux` (Linux) — used by agent teams for split-pane visibility
- Node.js 18+

Tested on macOS. Should work on Linux with no changes.
