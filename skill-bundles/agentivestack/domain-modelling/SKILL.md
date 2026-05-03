---
name: domain-modelling
description: Cook a plan against the project's domain model. Stress-tests terminology, surfaces contradictions with code, and updates CONTEXT.md, UBIQUITOUS_LANGUAGE.md, and ADRs inline as decisions crystallize. Use when planning a feature, refactoring, or any work that touches domain boundaries.
user-invocable: true
argument-hint: "[plan or topic to stress-test]"
---

# Domain Model Cooking Session

Interview relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask questions **one at a time**, waiting for feedback before continuing.

If a question can be answered by exploring the codebase, **explore the codebase instead of asking**.

## Discover project context

Before starting, find and read existing domain documentation. Check these locations (in order):

1. `docs/CONTEXT_MAP.md` — if it exists, this is a multi-context project. Read it to understand bounded contexts and their relationships.
2. `docs/UBIQUITOUS_LANGUAGE.md` — the shared glossary. Read it to understand canonical terms.
3. `docs/contexts/*/CONTEXT.md` — per-context documentation. Read the ones relevant to the current plan.
4. `CLAUDE.md` — project-level context.

If none of these exist, that's fine — create them lazily as decisions are made (see below).

## During the session

### Identify which context(s) this plan touches

If a context map exists, determine which bounded context(s) the plan falls within. If the plan spans multiple contexts, call that out explicitly — cross-context work needs extra care around contracts and shared kernels.

### Challenge against the glossary

When the user uses a term that conflicts with the ubiquitous language, call it out immediately:

> "Your glossary defines 'change' as a persisted set of DOM mutations (ChangeSpec). You're using 'change' to mean something different here — which meaning do you intend?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term:

> "You're saying 'user data' — do you mean the Visitor (anonymous deviceId), the Profile (identified via identify()), or the Member (org membership)? Those are three different concepts."

### Discuss concrete scenarios

When domain relationships are discussed, stress-test them with specific scenarios. Invent edge cases that probe boundaries:

> "What happens when an experiment is running on `/pricing` and someone deploys a change spec to the same page? Do they conflict? Which takes priority?"

### Cross-reference with code

When the user states how something works, verify against the code. If you find a contradiction, surface it:

> "You said goals are hard-deleted, but the code sets `isActive = false` — which is the intended behavior?"

### Update documentation inline

When a term is resolved or a decision is made, update the relevant file immediately. Don't batch these up.

**For terminology changes:**
- Update `docs/UBIQUITOUS_LANGUAGE.md` with the new or refined term
- Update the relevant `docs/contexts/<name>/CONTEXT.md` if the term is context-specific

**For domain model changes:**
- Update the relevant `CONTEXT.md` with new invariants, contracts, or ownership changes
- Update `docs/CONTEXT_MAP.md` if relationships between contexts changed

**For decisions:**
- Only create an ADR when ALL THREE conditions are met:
  1. **Hard to reverse** — the cost of changing your mind later is meaningful
  2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
  3. **Result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons
- ADRs go in `docs/contexts/<name>/adrs/` (context-specific) or `docs/adrs/` (cross-context)
- Use sequential numbering: `001-slug.md`
- Keep ADRs minimal: title + 1-3 sentences (context, decision, why). Optional sections (considered options, consequences) only when they add genuine value.

### Lazy file creation

If documentation files don't exist yet, create them only when you have something to write:
- First term resolved → create `UBIQUITOUS_LANGUAGE.md`
- First context-specific decision → create that context's `CONTEXT.md`
- First cross-context relationship → create `CONTEXT_MAP.md`
- First ADR-worthy decision → create the `adrs/` directory and first ADR

## Related skills

- `/writing-specs` — after cooking, formalize the plan into a spec
- `/mapping-system` — zoom out to understand how this plan fits the bigger picture
- `/architecting` — surface architectural friction and design deep module interfaces
