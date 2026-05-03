# Global Claude Code Instructions

## Who I am

Matt — Head of Customer at Human Health, a direct-to-consumer health app for chronic illness management. I work across data science, marketing analytics, and product personalisation. My repos: analytics (safe, fast iteration), datascience (user-facing, careful), cloud-infrastructure (shared Terraform).

## Working preferences

- **Simplicity first. Always.** Prefer solutions that remove code and reduce complexity. Reuse existing components. If a fix introduces a new mechanism (timer, flag, wrapper, polling loop), that's a smell — the system probably already has something that should handle the case.
- **Don't over-prescribe.** Give agents flexibility to reason about the best approach.
- **Bias to action, but ask when in doubt.** Have initiative like a good engineer — but the judgment of when to act vs. when to ask should improve over time.
- **Quality is non-negotiable but shouldn't slow velocity.** Ship fast, but ship solid, maintainable, functional code.
- **Decision visibility over permission gates.** Make decisions visible for async review rather than asking permission for every choice.
- **Never skip tests.** If a test is failing or unrunnable, fix the underlying cause — fix the code, install the missing dependency, repair the environment configuration. Do NOT use `@pytest.mark.skip`, `@pytest.mark.skipif`, `pytest.skip()`, `xfail`, or any equivalent silencing mechanism to make a problem go away. Skipping is acceptable only when running the test is genuinely impossible in any environment (e.g., requires hardware that doesn't exist). If the environment is the problem, **the environment is what needs fixing, not the test**.
- **Fix it while you're here. Never defer.** "Later" never happens — there is no backlog to store deferred cleanup in. When you spot something unrelated but broken, stale, or worse than it should be, fix it as part of the current change. Don't write out-of-scope sections that document "follow-up tickets." Always leave the codebase better than you found it. Exceptions: (1) things that are genuinely protected (e.g. `docs/decisions/`), (2) things whose scope would blow past the current task by a factor that makes review impossible. Default hard toward fixing.
- **Always push the code.** The Stop hook auto-commits and pushes after every response as a safety net — don't rely on it. When you're in-session and have changes ready for review, `git push` is the last thing you do before responding. If the push fails (e.g. divergent branches), resolve and push — don't leave it for me to chase.
- **Delegate noisy commands to a subagent.** For commands whose output is mostly noise and you only care about pass/fail plus any errors (test suites, linters, type checkers, heavy builds), invoke the `test-runner` subagent instead of running via Bash yourself. Haiku reads the wall of output; you get a summary and a log path you can read if you need detail. Running the full log through Opus/Sonnet context is wasteful.

## Planning workflow

Before implementing any non-trivial task:
1. Plan the approach first — outline what files will be changed and why
2. Present the plan for my review
3. Only proceed with implementation after I approve

**RPI is the happy path for non-trivial work** — *when the `rpi` bundle is active*. If a task shows any of these
signals — touches multiple files, spans unfamiliar code, has ambiguous requirements, or is feature-shaped rather
than one-liner-shaped — suggest `/research-plan-implement` upfront. It runs research, planning, and implementation
as separate gated phases (each in its own context window), so you stay in control at every handoff. Defaulting
to RPI beats realising mid-implementation that we needed research first.

**Skill bundles.** The active methodology bundle is determined by `~/src/Panoply/skill-bundles/ACTIVE`. The two
bundles currently shipped are `rpi` (research-plan-implement) and `agentivestack` (DDD/spec/slice). Only the
methodology skills swap; cross-cutting infra skills (review, security-review, debugging, verification, ADRs,
PR preflight, etc.) live in `core/` and are always available. If `rpi` skills are missing in a session, you're
on a different bundle — propose using whatever methodology IS available instead of `/research-plan-implement`.
Bundle membership is documented in `README.md` under "Skill bundles".

Use Plan Mode (Shift+Tab) for multi-step tasks. Always think through the full approach before writing code.

## Agent teams

Use agent teams for tasks that benefit from parallel work:
- Research + implementation in parallel
- Frontend + backend changes
- Multi-file refactors
- Testing while implementing

## Context management — do NOT use auto memory

Do not save context to Claude Code's auto memory system. All persistent context goes into version-controlled locations:

- **Repo-specific conventions/rules** → that repo's `.claude/rules/` directory
- **Strategic/domain context** → `~/src/Panoply/strategic-context/`
- **Project-specific context** → `~/src/Panoply/projects/{name}/`
- **General working preferences** → this file (CLAUDE.md)

If the user asks to "remember" something, save it to the appropriate location above instead of creating a memory file.

## Auto-commit workflow

Changes are automatically committed and pushed to GitHub by a Stop hook after each response. Do NOT ask about version control — it is handled automatically.

**Before raising a PR, suggest `/pr-preflight`.** It runs the GitHub Claude review bot's prompt locally against
the current branch and prints a PASS/WARN/BLOCK verdict to stdout — catching issues before they hit the PR. Ask
the user once per session when a PR is about to be raised; don't nag.

## Working in Panoply itself (vs. RPI-driven work)

**Panoply is the meta-repo for Claude configuration; changes here ship straight to `main`.** No feature branches,
no PRs, no `pr-preflight`. The Stop hook auto-commits and pushes to main — that is the intended flow for this
repo. Just edit, commit, push.

RPI (`/research-plan-implement`) and related skills prescribe feature branches + per-group PRs because they
target the *downstream* repos those skills will eventually be used in (analytics, datascience, cloud-infrastructure).
When you're using RPI to change Panoply itself, skip the branch/PR phases — work on main directly, and treat the
plan's "branch strategy" and "sub-PR" prescriptions as no-ops. The per-group review-gate and terminal
security-gate still add value and should run; the branch/PR scaffolding does not.

Signal that you're in this mode: the working directory is `~/src/Panoply/` and the change touches
`skill-bundles/`, `hooks/`, `scripts/`, `agents/`, `settings.json`, `CLAUDE.md`, or the root of this repo.

## Data Science Projects

These are default preferences for new projects — override in project-level CLAUDE.md files as needed.

When working in projects with notebooks, SQL, or data pipelines:
- Check for a project-level CLAUDE.md with schema documentation first
- Never guess column names — inspect schemas first
- For exploratory work, use Plan Mode (Shift+Tab) before writing queries
- Prefer marimo notebooks (.py) over Jupyter (.ipynb) for new projects — they're plain Python, git-friendly, and reproducible
- When writing .ipynb: generate the ENTIRE notebook in one shot, don't build cell-by-cell
- Separate data processing from visualisation into different files
- Keep reusable logic in `src/` modules that notebooks import
- Prefer polars over pandas for new projects (lazy evaluation, better performance)
- Use DuckDB for local analytical queries on parquet/CSV files
- Use CTEs in SQL, never nested subqueries. Qualify all column names with table aliases.
- Run `pytest -q --maxfail=1` after creating data transformation code
