# Global Claude Code Instructions

## Who I am

Matt — Head of Customer at Human Health, a direct-to-consumer health app for chronic illness management. I work across data science, marketing analytics, and product personalisation. My repos: analytics (safe, fast iteration), datascience (user-facing, careful), cloud-infrastructure (shared Terraform).

## Working preferences

- **Simplicity first. Always.** Prefer solutions that remove code and reduce complexity. Reuse existing components. If a fix introduces a new mechanism (timer, flag, wrapper, polling loop), that's a smell — the system probably already has something that should handle the case.
- **Don't over-prescribe.** Give agents flexibility to reason about the best approach.
- **Bias to action, but ask when in doubt.** Have initiative like a good engineer — but the judgment of when to act vs. when to ask should improve over time.
- **Quality is non-negotiable but shouldn't slow velocity.** Ship fast, but ship solid, maintainable, functional code.
- **Decision visibility over permission gates.** Make decisions visible for async review rather than asking permission for every choice.

## Planning workflow

Before implementing any non-trivial task:
1. Plan the approach first — outline what files will be changed and why
2. Present the plan for my review
3. Only proceed with implementation after I approve

Use EnterPlanMode for multi-step tasks. Always think through the full approach before writing code.

## Project lifecycle

Use these skills to manage structured projects:
- `/refine-project [name]` — Refine an intent document through interactive discussion
- `/design-project [name]` — Create a solution design from a refined intent
- `/complete-project [name]` — Review, promote specs, run retro, and archive

Projects are in `~/src/Panoply/projects/`. Each has intent.md, backlog.md, mapping.yaml, and optionally design.md.

## Agent teams

Use agent teams for tasks that benefit from parallel work:
- Research + implementation in parallel
- Frontend + backend changes
- Multi-file refactors
- Testing while implementing

## Auto-commit workflow

Changes are automatically committed and pushed to GitHub by a Stop hook after each response. Do NOT ask about version control — it is handled automatically.

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
