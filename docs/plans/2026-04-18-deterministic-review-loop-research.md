# Deterministic Review Loop — Design Synthesis

**Date:** 2026-04-18
**Status:** Design synthesised from conversational exploration; basis for planning phase.

This document captures the design decisions reached during an exploratory session about making the RPI implement-phase review workflow deterministic and context-safe. It stands in for a formal research document — the work was design-driven, not investigation-driven.

## Problem Context

The current Panoply RPI pipeline has three historical pressures in tension:

1. **Auto-compact hazard on long runs.** Earlier, one implementer executed an entire plan. Large plans hit the context-compact boundary mid-implementation, corrupting reasoning.
2. **Per-phase implementer mandate.** To solve (1), a rule was introduced that each plan phase spawns its own implementer subagent. This fixed compaction but introduced waste: trivially small phases now pay full spawn + review cost.
3. **Non-deterministic review enforcement.** The implementer is *instructed* by the `implementing-plans` skill to run code-reviewer and security-reviewer at completion, but this is advisory — model drift can skip it. The PR-preflight step is triggered purely by LLM judgment and fires roughly two-thirds of the time.

Security review in particular runs per-phase today, which multiplies reviewer cost across phases even when most phases have no security surface.

## Core Design Decisions

### D1. Determinism lives in bash, not in skills

Skills are advisory; they cannot enforce control flow. A deterministic review gate requires the looping logic to sit outside the model. Implementation is a bash script invoked via the built-in `Bash` tool, paired with a thin skill that documents when/how to call it. No custom tool or MCP integration is needed.

### D2. Single-layer review gate (not nested)

The bash gate wraps exactly one implementer attempt plus exactly one reviewer attempt per pass. It does not orchestrate multiple phases. The RPI orchestrator remains responsible for phase sequencing. This avoids nested-bash brittleness.

### D3. Loop semantics: auto-remediation, capped at 2 passes

```
pass 1: implement → review
  PASS    → exit 0, proceed
  CHANGES → feed findings back to implementer

pass 2: implement (remediation) → review
  PASS    → exit 0, proceed
  CHANGES → exit with distinct non-zero code, drop to interactive
            with both rounds of findings visible
```

1 initial attempt + 1 remediation attempt = 2 review passes maximum. On cap-hit, control returns to the interactive session so the user and agent can reason about whether/how to address the remaining findings.

### D4. Verdict contract via sentinel file

The reviewer subagent writes `.review-verdict[-<group_id>]` containing either:
- The literal string `REVIEW_APPROVED` (and nothing else) on pass, OR
- A bulleted list of blocking issues on fail.

Sentinel file is preferred over stdout-token grepping: robust to output noise, trivially debuggable (`cat .review-verdict`), and supports group-scoping for parallel runs via the optional group id suffix.

### D5. Review groups decided at plan time

The planner (not the orchestrator) decides how phases cluster into review groups via a `review_group: <id>` field on each phase's Execution block. Three shapes are permitted:

| Shape | When | Who owns review loop |
|---|---|---|
| **Solo** — 1 phase = 1 group | Phase is meaty (est. context 50–80%) | That phase's implementer |
| **Batched sequential** — N small phases, 1 group | Each phase trivial; combined context <50% | A single implementer does all N, reviews once |
| **Fan-out + consolidator** — parallel phases, 1 group | Genuinely independent streams, each within budget | A consolidator implementer owns the aggregated diff |

Key insight: the review loop requires a single author for the diff under review. Parallel phases sharing a reviewer must funnel into a consolidator.

**Decision rules for the planner:**
- Estimated implementer context <50% and phases share concern → Batched sequential
- Estimated context 50–80% → Solo
- Two+ independent streams, each comfortably under budget → Fan-out + consolidator
- Reviewer cost is bounded by diff size, not phase count — do not split groups to "save reviewer compute"

### D6. Plan-level security gate as terminal phase

Security review lifts from per-phase to once-per-plan. Mechanism: the planner always appends a terminal `security-gate` phase with `depends_on: [all prior groups]`. The orchestrator runs it like any other phase — no new top-level control flow.

**Inputs to the plan-level reviewer:**
1. `git diff $base_ref..HEAD` (the plan's full aggregated diff)
2. Path to the plan document
3. List of phase names for scope orientation

Do NOT pipe per-phase reviewer summaries — the diff is the source of truth and keeps the reviewer's context clean.

**Special-casing:** the orchestrator runs the reviewer first; only on FAIL does it spawn a remediation implementer (subject to the same 2-pass cap). On cap-hit the orchestrator drops to interactive with `AskUserQuestion` offering remediate / override (logged) / abort.

**Mode toggle:** planner sets `security_review: automated | human | hybrid`. Default automated; escalate to hybrid for high-stakes plans (auth, data, architectural).

**Correlated change:** remove the per-phase security review step from `implementing-plans` (section 5 of "Complete Implementation"). Per-phase code review remains.

### D7. PR preflight via deterministic hook (independent)

Current LLM-judgment triggering of `pr-preflight` fires ~66%. Replace with a `PreToolUse` hook matching `gh pr create` in the Bash command:

```
gh pr create intercepted → check for fresh .pr-preflight-passed sentinel
  sentinel present & fresh → allow PR
  sentinel missing/stale   → block, instruct Claude to run pr-preflight first
```

On `pr-preflight` PASS, sentinel is written. On CHANGES, findings surface in conversation; no auto-remediation (this is the intended pause point — PRs are where humans take the wheel).

**Decoupled from the rest:** different mechanism (hooks, not subagents), different artifact (settings.json, not plan format). Independent phase, can ship before or after the review-loop work.

**Caveats flagged during design:**
- Matcher needs to handle quoted variants and `gh` via absolute path
- Sentinel staleness rule: "passed within last N minutes" is simpler than tying to HEAD
- Escape hatch (env var or flag) for rare overrides, with a log line

### D8. Interactive drop-out preserves human judgment

Across both mechanisms, CHANGES that exceed automated handling (2-pass cap on review-loop, any CHANGES on PR-preflight) return control to the interactive session rather than failing silently or hitting an arbitrary limit. This preserves the user's ability to reason about edge cases while keeping the happy path deterministic.

## Orchestrator Control Flow (End State)

```
base_ref = HEAD at plan start   # orchestrator records this

for group in plan.groups (dependency order):
    spawn implementer for group (one per shape: Solo/Batched/Consolidator)
    implementer internally invokes implement-review-gate.sh (max 2 passes)
    if gate exits non-zero: drop to interactive with findings
    honour group.human_gate if set

# terminal security gate — one phase, one run
spawn security-reviewer with scope "$base_ref..HEAD" + plan path
read .review-verdict-security
if APPROVED:
    run finishing-work
else:
    present findings; AskUserQuestion [remediate / override / abort]
```

PR preflight is enforced by the PreToolUse hook whenever `gh pr create` fires, regardless of which phase triggered it.

## Scope of Work — Phase List

| # | Phase | Depends on | Notes |
|---|---|---|---|
| 1 | `implement-review-gate.sh` + reviewer contract (2-pass loop, sentinel) | — | Foundation script and verdict convention |
| 2 | Plan-format updates: `review_group` field, planner sizing rules | P1 | Edits `writing-plans`; no runtime behavior change yet |
| 3 | Per-phase wiring in `implementing-plans` (remove per-phase security review; use new gate) | P1, P2 | Flips existing skill to the new mechanism |
| 4 | Terminal security-gate phase (planner always appends; orchestrator runs once at end) | P2, P3 | Plan-level security review |
| 5 | PR-preflight PreToolUse hook (sentinel + settings.json + escape hatch) | — | **Decoupled**, independent of P1–P4, P6 |
| 6 | RPI orchestrator skill updates to consume P2–P4 | P2, P3, P4 | Documentation/control-flow updates |

**Branch strategy:** feature branch with sub-PRs per phase. Each phase touches different skills/agents/settings and is independently reviewable. P5 is genuinely independent and may merge ahead of the rest.

**Gate defaults:** every phase uses the new review-gate with 2-pass cap; CHANGES-at-cap drops to interactive. No additional human gates needed — the interactive drop-out already ensures the user engages when something is non-trivial. **Exception:** P5 (settings.json hook) warrants an explicit human gate because hook misconfiguration affects every future session.

## Design Anti-Patterns Explicitly Rejected

| Rejected | Why |
|---|---|
| Nested bash scripts (plan-level loop wrapping phase-level loops) | Brittle; orchestrator already sequences phases deterministically |
| Parsing implementer prose for "we've raised PR" | Fragile; PreToolUse hook intercepts the actual tool call |
| Per-phase security review retained | Multiplies reviewer cost without proportional benefit; plan-level diff is the natural review unit |
| Stdout-token grepping as sole signal | Noisier than a sentinel file; harder to debug |
| Orchestrator deciding review groups at runtime | Judgment belongs at plan time, where diff shape is knowable |
| Uniform gating ("all-autonomous" or "all-human") | Planner specifies per phase; orchestrator refuses to run otherwise |

## Open Questions for the Planner

1. **Loop-cap arithmetic:** the design says "2 passes max." The user may have meant "2 retries = 3 attempts." The plan should pick one and state it explicitly in the script and the skill. Current default: 2 passes total (1 initial + 1 remediation).
2. **Sentinel staleness rule for PR-preflight:** time-based (e.g., 15 minutes) vs. commit-based (mtime newer than HEAD). Time-based is simpler; recommend that unless the planner sees a reason otherwise.
3. **Script naming:** `implement-review-gate.sh` vs. `implement-review-loop.sh`. Gate is more accurate given 2-pass cap and drop-to-interactive; planner should pick and use consistently.

## Inputs for Implementers

- This research document
- Current state of `~/.claude/skills/{implementing-plans,writing-plans,research-plan-implement,pr-preflight}/SKILL.md`
- Current state of `~/.claude/agents/{code-reviewer,security-reviewer}.md`
- Current `.claude/settings.json` structure in Panoply repo (for hook wiring reference)
