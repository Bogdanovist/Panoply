# Skills Audit: Hubris-Legacy Baggage (2026-04-17)

## Context

`/review` was just deprecated because it read `intent.md`, `design.md`, and `architecture.md` — Hubris-era
project-lifecycle files. This audit checks whether the same rot exists in the project-lifecycle and retro-style
skills, and flags downstream cleanup.

---

## Projects Directory: Live State

`~/src/Panoply/projects/` **exists and has two active projects:**

| Project | Repo | Created | Files present |
|---------|------|---------|---------------|
| `feature-launch-push` | `datascience` | 2026-03-25 | intent.md, backlog.md, design.md, mapping.yaml |
| `zd-symptom-decisions` | `analytics` | 2026-03-31 | intent.md, backlog.md, design.md, mapping.yaml |

`_completed/` is empty — no projects have ever been completed through `/complete-project`.

Both projects were committed together in a single `f78c073` commit (the Panoply bootstrap). There is **no git
evidence of a `/refine-project` or `/design-project` invocation producing those files** — they were likely
created manually or in a session without auto-commit. No subsequent commits reference these projects.

**Implication:** The project-lifecycle tooling has nominal users (two live projects exist) but zero evidence of
active workflow use through the skills themselves.

---

## Verdict Table

| Skill | Hubris-bound? | Still useful? | Active use? | Verdict | One-line rationale |
|-------|---------------|---------------|-------------|---------|-------------------|
| `refine-project` | YES — hard-coded paths to `~/src/Panoply/projects/$1/{intent,backlog,mapping}.yaml`; reads `refine-project/references/` strategic context | YES — intent refinement methodology is sound | Nominal (2 live projects; no invocation evidence) | SIMPLIFY | Methodology is good; strip the Hubris file layout, make it repo-local and context-agnostic |
| `design-project` | YES — reads `intent.md`, `design.md`, `backlog.md`, `mapping.yaml` from Hubris project paths; explicitly recommends checking `docs/architecture.md` and `docs/specs/` in target repo | YES — solution design process is useful | None (no invocation evidence) | SIMPLIFY | Strip the fixed project-dir path wiring; decouple from `refine-project` as a hard prerequisite |
| `complete-project` | YES — reads all four Hubris project files; mandates `docs/specs/`, `docs/specs/INDEX.md`, `docs/architecture.md` in target repo; moves project to `_completed/`; `_completed/` is currently empty | PARTIAL — retro/lesson extraction is useful; spec promotion to `docs/specs/` and `docs/architecture.md` is Hubris-specific process nobody uses | None (no completions ever) | DEPRECATE | The spec-promotion and archival mechanics are pure Hubris; no completions in history; the retro value is covered by `/retro` |
| `retro` | NO — no Hubris file path assumptions; works on any repo via `$1` argument; references `architecture.md` only generically in a "documentation drift" checklist item, not as a required read | YES — repo health, rules coverage, and code quality review is genuinely valuable | Referenced in CLAUDE.md nudge research; listed in system-feedback references | KEEP AS-IS | Clean Hubris-free skill; core methodology is exactly what it says on the tin |
| `documenting-decisions` | NO — no Hubris path assumptions; writes to `docs/decisions/` in the current repo (standard ADR location); reads relative paths only; path-validation explicitly rejects absolute paths | YES — ADR capture is useful regardless of project framework | Committed in `ef4a70e` (recent skill update) | KEEP AS-IS | ADR workflow is entirely decoupled from Hubris; standard engineering practice |
| `brainstorming` | NO — no Hubris path assumptions; writes design docs to `docs/plans/YYYY-MM-DD-<topic>-design.md` which is the current Panoply convention | YES — actively used as a pre-phase in RPI workflow | Committed in `ef4a70e` (recent skill update) | KEEP AS-IS | Pure methodology skill, no project-lifecycle coupling |
| `organise-repo` | PARTIAL — one section references `~/src/hubris/repos/$REPO/knowledge.md` for knowledge migration; the rest is clean | YES — `.claude/` setup audit is actively useful | Referenced in `083653d` (Panoply bootstrap) | SIMPLIFY | Strip the Hubris knowledge-migration section (lines 27–36 of SKILL.md); migration is complete |

---

## SIMPLIFY: What Survives

### `refine-project` — Stripped Structure

Keep: the intent refinement methodology (questioning, scope, success criteria, strategic context, backlog seeding).
Drop: the fixed `~/src/Panoply/projects/$1/` path structure; the `mapping.yaml` requirement; the "Other Active
Projects" dynamic context load.

```markdown
---
name: refine-project
description: Refine a project intent document through discussion. Use when starting
  a project or when scope/requirements need clarification.
argument-hint: "[project-name or topic]"
user_invocable: true
---

## Organisation Context
!`cat ~/src/Panoply/skills/refine-project/references/organization.md 2>/dev/null`

## Strategic Context
!`for f in ~/src/Panoply/skills/refine-project/references/*.md; do ...`

---

You are a project refinement agent. Refine a project intent through discussion.

## Process
1. Ask about scope, data sources, requirements, success criteria, dependencies.
2. Probe for strategic context. Check references above; propose additions if
   new themes emerge.
3. Draft the refined intent and present for review.
4. Seed an initial backlog if clear work items surfaced.

## Output
Write the agreed intent to wherever the human specifies — no fixed path assumed.
Update ~/src/Panoply/skills/refine-project/references/ for new strategic context.

## Quality Bar
Intent must be detailed enough for an agent to decide tasks, understand "done",
and know what needs human input. Not a technical design — that comes later.
```

**Concrete changes:** Remove the `!cat ~/src/Panoply/projects/$1/...` blocks from the preamble; remove the
`~/src/Panoply/projects/` write step from Output; let the human say where the intent lives.

---

### `design-project` — Stripped Structure

Keep: the solution design methodology (key decisions, component design, review plan).
Drop: the fixed `~/src/Panoply/projects/$1/` read/write paths; the hard dependency on `intent.md` being in that
directory; explicit reads of `docs/architecture.md` and `docs/specs/` as first steps.

```markdown
---
name: design-project
description: Create a solution design. Use after intent is clear. Produces a
  design document capturing key decisions, components, and a review plan.
argument-hint: "[topic or path-to-intent]"
user_invocable: true
---

You are a solution architect. Take a refined intent and produce a solution design.

## What the Design Doc IS
Key decisions, end-state description, component design, review plan.

## Process
1. Read the intent (from argument or ask the human where it is).
2. Explore the relevant repo to understand existing patterns.
3. Identify key decisions (choices, rationale, alternatives considered).
4. Design components (interfaces and constraints, not internal details).
5. Draft review plan — human review vs autonomous per area.
6. Seed the backlog with concrete work items from the design.

## Output
Write design to a path the human specifies (suggest docs/plans/YYYY-MM-DD-<topic>-design.md
or wherever the project's docs live).
```

**Concrete changes:** Remove all `~/src/Panoply/projects/$1/...` read/write blocks; remove the forced
`docs/architecture.md` and `docs/specs/` check as prerequisites; use argument or explicit ask for input/output paths.

---

### `organise-repo` — Minimal Strip

Keep everything. Remove only lines 27–36 (the "Check for Knowledge to Migrate" section referencing
`~/src/hubris/repos/$REPO/knowledge.md`). The migration is complete; the section is dead code.

---

## `complete-project`: DEPRECATE — Full Reasoning

This skill is Hubris to the core:

1. **Spec promotion** (`docs/specs/`, `docs/specs/INDEX.md`, `docs/architecture.md`) — this pattern was the
   Hubris way of embedding "why" in repos for autonomous agents to read. The current Panoply approach uses
   `.claude/rules/` for this. Nobody has ever completed a project through this skill (`_completed/` is empty,
   no git evidence of invocation).

2. **E2E gate mechanic** — checking for `tests/e2e/` is project-type-specific and assumes a pattern that
   may not exist in all repos (analytics notebooks, data pipelines, etc. may not have e2e test directories).

3. **Archival** — moving directories to `_completed/` is a Hubris management pattern. Under the current workflow
   projects are in Panoply for reference while active; there is no compelling need to archive them.

4. **The retro value it provides is already in `/retro`.** The lesson-extraction step in `complete-project`
   duplicates what `/retro` does better (full repo audit vs. a single project's lessons).

**Downstream impact of deprecating:** Remove the `/complete-project` bullet from `CLAUDE.md` Project lifecycle
section (line ~68 in `~/.claude/CLAUDE.md`). The "retro nudge" in `CLAUDE.md` research should stand on its own
(`/retro [repo-name]`) rather than being tied to project completion. Update `README.md` skill count accordingly.

---

## Downstream Impact Map

| Action | What else needs updating |
|--------|--------------------------|
| Deprecate `complete-project` | Remove bullet from `~/.claude/CLAUDE.md` Project lifecycle section; update `skills/README.md` count (31→30, or 30→29 if wardley-mapping ghost also deleted) |
| Simplify `refine-project` | Update `~/.claude/CLAUDE.md` Project lifecycle description — currently says "intent.md, backlog.md, mapping.yaml"; reword to describe intent/backlog without implying fixed file paths |
| Simplify `design-project` | Update `CLAUDE.md` — currently the description implies it follows `refine-project` as a chained step with shared file paths; decouple the description |
| Simplify `organise-repo` | Nothing external; self-contained change |
| No action on `retro` | CLAUDE.md already has a nudge for it in the skills audit recommendations |
| No action on `brainstorming` | Clean; used in RPI workflow |
| No action on `documenting-decisions` | Clean; standard ADR practice |

---

## Quick-Win vs Bigger-Effort

| Work item | Effort | What to do |
|-----------|--------|-----------|
| Strip Hubris knowledge-migration from `organise-repo` | 5 min | Delete lines 27–36 from SKILL.md |
| Deprecate `complete-project` | 10 min | Move SKILL.md to `_deprecated/`, remove CLAUDE.md bullet |
| Update `CLAUDE.md` project lifecycle description | 5 min | Remove mention of `intent.md, backlog.md, mapping.yaml` as fixed files |
| Rewrite `refine-project` | 30 min | Strip fixed-path preamble; keep methodology + references dir |
| Rewrite `design-project` | 20 min | Strip fixed-path preamble and `docs/specs/` prereq; keep methodology |

The organise-repo strip and complete-project deprecation are the fastest wins and have zero risk.
The refine-project and design-project rewrites require care to preserve the methodology while making them
path-agnostic.

---

## Notes on Active Projects

The two live projects (`feature-launch-push`, `zd-symptom-decisions`) have `design.md` and `mapping.yaml`
on disk. If `/refine-project` and `/design-project` are rewritten to be path-agnostic, those files are
still usable — the skills would just accept an explicit path rather than assuming the Panoply project
directory layout. No migration of existing project files is required.
