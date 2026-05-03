# CLAUDE.md Audit — 2026-04-17

## Summary

- **Both `~/.claude/CLAUDE.md` and `~/src/Panoply/CLAUDE.md` are byte-for-byte identical** — one is redundant and risks diverging silently. The Panoply copy should either be deleted or replaced with a `!include` / note that defers to the global one.
- **`EnterPlanMode` is a tool name, not a user command.** The correct user-facing entry point is `/plan`. Referencing an internal tool name in user-facing instructions adds confusion.
- **`simplify` is listed in the available skills** (it was added as a bundled slash command per changelog) but there is no `~/src/Panoply/skills/simplify/` directory. It exists as a CLI built-in, not a Panoply skill — the CLAUDE.md "nudge" section (when we add one) should treat it as `/simplify`, not a skill reference.
- **`organise-repo` skill still references Hubris knowledge migration** (`~/src/hubris/repos/$REPO/knowledge.md`) — this is valid as long as Hubris still runs alongside Panoply, but warrants a review as repos migrate away.
- **No auto-memory violation found.** No rogue `MEMORY.md` files exist. The rule is clean.

---

## Stale-Reference Findings

| Severity | File : Line | What's wrong | Recommended fix |
|----------|-------------|--------------|-----------------|
| LOW | `~/.claude/CLAUDE.md:25` and `~/src/Panoply/CLAUDE.md:25` | `"Use EnterPlanMode for multi-step tasks."` — `EnterPlanMode` is an internal tool identifier exposed in the model's tool list, not a user command. The user-facing entry point is `/plan`. | Replace `"Use EnterPlanMode for multi-step tasks."` with `"Use /plan for multi-step tasks."` |
| LOW | `~/.claude/CLAUDE.md` (entire file) and `~/src/Panoply/CLAUDE.md` (entire file) | Both files are identical. Having two copies means edits to one won't propagate to the other, and they will diverge. The Panoply repo's CLAUDE.md is meant to be "the source" per `system-feedback` skill (which lists `~/src/Panoply/CLAUDE.md` as the canonical location) — but the actual global instructions location is `~/.claude/CLAUDE.md`. | Delete `~/src/Panoply/CLAUDE.md` and symlink it to `~/.claude/CLAUDE.md`, OR add a single-line note in the Panoply copy: `"For current version see ~/.claude/CLAUDE.md (canonical)."` Either way, eliminate the silent-divergence risk. |
| LOW | `~/src/analytics/CLAUDE.md:17` and `~/src/datascience/CLAUDE.md:6` | `"See [AGENTS.md](AGENTS.md) for available Claude Code skills."` — both AGENTS.md files exist on disk and are up to date, so this is not broken. However, they describe project-specific CLI skills that now overlap with Panoply skills. Not a staleness issue, but worth noting for completeness. | No action needed unless AGENTS.md content conflicts with Panoply skill list. |
| LOW | `~/src/Panoply/skills/organise-repo/SKILL.md:29-34` | References `~/src/hubris/repos/$REPO/knowledge.md` for legacy Hubris knowledge migration. `hubris/repos/` exists with content, so the reference is live, but Hubris is being superseded by Panoply. | No immediate action needed. Flag for cleanup when a repo has been fully migrated off Hubris. |
| INFO | `~/src/hubris/CLAUDE.md:11` | References `~/.claude/MEMORY.md` as a "performance cache." No such file exists. This is internal to Hubris and doesn't affect global instructions, but is stale within that repo. | Update hubris CLAUDE.md to remove the MEMORY.md reference, or note it as deprecated. |

---

## Nudge-Opportunity Recommendations

These are the 4 nudges worth encoding. The bar: the trigger is clean enough that false positives will be rare, and the gain from the nudge is real.

### 1. `pr-preflight` — before or after raising a PR

**Trigger:** The agent is about to push a branch and raise a PR, OR has just finished implementation work and the user is discussing next steps toward a PR.

**Why it's worth it:** `pr-preflight` runs five parallel review agents that catch bugs, reuse gaps, and security issues before the GitHub bot sees them. Without a nudge, it's easily forgotten. The trigger (imminent PR creation) is unambiguous — very low false-positive rate.

**Suggested phrasing:**
> "Before I push — want me to run `/pr-preflight` first? It runs the same checks as the GitHub review bot locally, so we catch anything before it hits the PR."

**Where in CLAUDE.md:** Add to the `Auto-commit workflow` section, since that's where push/PR behavior is described.

---

### 2. `research-plan-implement` — at the start of non-trivial feature work

**Trigger:** The user describes a feature or change that requires understanding unfamiliar code or multiple systems, or where the agent would otherwise jump straight into implementation without a plan.

**Why it's worth it:** For non-trivial work, skipping the research phase leads to plans that miss key constraints, and skipping the plan phase leads to implementation that needs rework. The trigger (user describes a new feature, not a bug fix or small task) is clean.

**Suggested phrasing:**
> "This sounds non-trivial enough to warrant a full research → plan → implement pass. Want me to kick off `/research-plan-implement`? It runs research in parallel subagents, presents a plan for your approval, then implements phase by phase — so you stay in control at each gate."

**Where in CLAUDE.md:** Add to the `Planning workflow` section, after the existing 3-step planning rule.

---

### 3. `retro` — after completing a project or when reviewing recent accumulated work

**Trigger:** The user explicitly finishes a project (`/complete-project` just ran), OR the user makes comments like "we've shipped a lot lately", "things feel messy", "I want to clean up", or "let's review what we've built."

**Why it's worth it:** Retros are the mechanism that keeps rules, conventions, and skills up to date. Without a nudge they're skipped indefinitely. The trigger is distinct enough (retrospective language, post-project wrap-up) that false positives are rare.

**Suggested phrasing:**
> "Sounds like a good moment for a `/retro` — quick pass over recent code quality, rules, and conventions to make sure everything we've learned is captured. Worth running?"

**Where in CLAUDE.md:** Add to the `Project lifecycle` section, after the `/complete-project` bullet.

---

### 4. `system-feedback` — when frustration or a process gap surfaces

**Trigger:** The user expresses frustration about how Claude Code or Panoply is working (e.g., "this keeps happening", "why does it always...", "this workflow is broken"), or explicitly suggests an improvement to the tooling.

**Why it's worth it:** Frustration is a signal that the system has a gap. Capturing it immediately (before the session ends) is far more useful than hoping it gets remembered. The trigger (frustration language directed at the tooling) is distinctive and low false-positive.

**Suggested phrasing:**
> "Sounds like a process gap worth capturing. Want to run `/system-feedback`? It's a structured session to turn this into an actual improvement — whether that's a new rule, skill tweak, or hook change."

**Where in CLAUDE.md:** New section at the bottom — see below.

---

### Verbatim CLAUDE.md additions

Paste these into the file exactly. Three targeted additions:

**Addition 1 — to `Planning workflow` section (after step 3):**

```markdown
For non-trivial features where you'd need to understand unfamiliar code before planning, suggest `/research-plan-implement` — it runs research, plan, and implementation as separate gated phases with approval gates between each.
```

**Addition 2 — to `Project lifecycle` section (after `/complete-project` bullet, before the "Projects are in..." line):**

```markdown
After completing a project or when several weeks of work have accumulated, suggest `/retro [repo-name]` — it reviews recent code quality, audits rules coverage, and ensures learnings are captured.
```

**Addition 3 — new section at the end of both CLAUDE.md files:**

```markdown
## Skill nudges

Suggest these skills proactively at the right moment — not constantly, only when the trigger is clean:

- **Before pushing a PR**: "Want me to run `/pr-preflight` first? Catches the same issues as the GitHub review bot, locally."
- **At the start of non-trivial feature work**: "This warrants a full research → plan → implement pass — want to use `/research-plan-implement`?"
- **After wrapping a project or when things feel messy**: "Good moment for a `/retro [repo-name]` — quick pass to capture what we've learned."
- **When you express frustration about how the tooling works**: "Want to capture that as a system improvement? `/system-feedback` is the right tool."
```

---

## Other Cleanup Observations

### Structural

1. **Duplicate file risk is the biggest issue.** `~/.claude/CLAUDE.md` and `~/src/Panoply/CLAUDE.md` being identical is an accident waiting to happen. One change gets made to one but not the other, and a future agent gets conflicting instructions. Fix: symlink or delete the Panoply copy, with a one-line redirect comment.

2. **`EnterPlanMode` vs `/plan`.** Small but meaningful. The tool name is internal and could confuse an agent that looks for a command to run. `/plan` is the correct, user-invocable form.

### Redundancy

3. **"Always push the code" conflicts with "Auto-commit workflow."** The `Working preferences` bullet says "After making changes that are ready for review, `git push` is the last thing you do." The `Auto-commit workflow` section says "Changes are automatically committed and pushed by a Stop hook." These give contradictory signals about who is responsible for pushing. The `Working preferences` bullet should be updated to defer to the hook, or explicitly call out that the Stop hook handles it so manual push is rarely needed.

   Suggested replacement for the `Working preferences` bullet:
   > **Always push the code.** The Stop hook auto-commits and pushes after each response. If the hook fails or you're in a non-hook context, push manually — don't leave work unpushed and don't describe what you'll push without doing it.

4. **"Decision visibility" principle is vague.** "Make decisions visible for async review rather than asking permission for every choice" — it's unclear what "visible" means in practice (a comment? a log entry? a PR description?). This could be sharpened: "Make decisions visible in commit messages, PR descriptions, or inline comments — don't block on permission for every implementation choice."

### Structure

5. **`Data Science Projects` section is the longest section by far** and very specific to one class of repo. It would work better as a separate rule file in the relevant repos (`analytics/.claude/rules/data-science.md`, `datascience/.claude/rules/data-science.md`) rather than inflating the global CLAUDE.md. The global file should stay lightweight. This is a non-trivial refactor but the right long-term direction.

6. **`Agent teams` section is thin.** Four bullet points listing when to use agents, but no pointer to `/parallel-agents` or `/research-plan-implement`. If the nudge section is added (above), this section could be collapsed into a single line: "Use agent teams via `/parallel-agents` or `/research-plan-implement` for tasks with independent workstreams."
