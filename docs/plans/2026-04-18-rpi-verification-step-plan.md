# Plan: rpi-verification-step (2026-04-18)

## Summary

Add an **optional** post-merge verification mechanism to the RPI skill system. Brainstorming and
writing-plans explicitly prompt "what verification beyond CI is needed?" at authoring time; when
the answer is non-trivial (cross-repo, Terraform, live-infra e2e, manual validation beyond CI) the
plan captures it in a dedicated `## Post-Merge Verification` section; `finishing-work` reads that
section after creating the final PR, surfaces the steps to the user via `AskUserQuestion`, and
writes a `.post-merge-verification-pending` sentinel to survive session closure. The mechanism is
**opt-in per plan** — "CI is enough" remains the default and incurs zero friction. The
orchestrator surfaces the verification status in its final report. No new skill, no new hook,
no new bash script — this is pure skill-doc + template + `finishing-work` integration.

## Stakes Classification

**Level**: Medium
**Rationale**: Touches 4 skill docs and one template across the RPI pipeline. No code paths
execute at runtime (Panoply is a skill-prompt repo; the "implementation" is prose + markdown
templates). Rollback is trivial (revert commits). Risk surface is prompt-engineering drift —
ambiguous wording could either (a) force verification sections into CI-only plans (adding
friction) or (b) let cross-repo work slip through without capture. Mitigation is explicit
binary-default framing ("Required: no" is the default answer, and is a full valid answer).

## Context

**Research**: [2026-04-18-rpi-verification-step-codebase.md](./2026-04-18-rpi-verification-step-codebase.md)

**Affected skills / files**:

- `skills/brainstorming/SKILL.md` — add Phase 1 question + design-doc template section + checklist item.
- `skills/writing-plans/SKILL.md` — add `## Post-Merge Verification` template section + success-criteria prompt + quality-checklist item.
- `skills/research-plan-implement/SKILL.md` — add final-report line surfacing verification status.
- `skills/finishing-work/SKILL.md` — add Step 5 (pre-Clean-Up): read plan, invoke `AskUserQuestion`, write/delete sentinel.
- Plan template consumers: no code change; downstream behavior is prose-driven.

**Branch/PR strategy**: Single feature branch `feat/p7-post-merge-verification`, one PR per
review_group (mirrors the P1–P6 sequence already used in this repo — see commit log
`a862c0b … 6a9d793`). Phases 1–4 are loosely coupled (each edits a different skill file); a
sub-PR per phase keeps each review bounded and lets reviewers catch prompt-drift in isolation.
Phases are opened sequentially (not in parallel) because each builds on the previous phase's
vocabulary — Phase 2 references the section name introduced by Phase 1, Phase 3 references
the final-report surface introduced by Phase 2, Phase 4 references the sentinel name
established by Phase 3. Final terminal `security-gate` phase runs over the aggregated diff
at end-of-plan.

## Success Criteria

- [ ] Brainstorming Phase 1 asks an explicit verification-beyond-CI question; the
      design-doc template has a `## Verification Plan` section; the checklist enforces it.
- [ ] `writing-plans` plan template has a `## Post-Merge Verification` section with
      fields: `Required`, `Trigger point`, `Repos involved`, `Commands / steps`,
      `Verification owner`. Quality checklist gains a matching item.
- [ ] `research-plan-implement` final report surfaces `Verification: none | pending — see
      plan §Post-Merge Verification`.
- [ ] `finishing-work` reads the plan's `## Post-Merge Verification` section after PR
      creation; when `Required: yes`, prints steps, invokes `AskUserQuestion`, and on
      "deferred" writes `.post-merge-verification-pending` to repo root.
- [ ] The no-op case ("Required: no") adds zero steps: `finishing-work` exits after PR
      creation as today.
- [ ] All changes render cleanly as Markdown (no broken tables / lists).
- [ ] Existing plans (P1–P6) remain valid — no template field introduced is mandatory in
      a way that invalidates historical plans.

## Design Decisions (resolutions of research-doc Open Questions)

Recorded inline so reviewers can audit the reasoning without re-reading the research doc.

1. **Q1 — where does confirmation live?** Inside `finishing-work` as a final step before
   cleanup. Simpler than an orchestrator-level step; `finishing-work` already holds the PR
   URL and plan path simultaneously.
2. **Q2 — verification-gate phase or plan section?** Plan **section**, not a phase. The
   `review_group` model is for code-review loops; verification is a human-action checklist
   with no reviewer agent. Using `review_group: verification` would be semantic pollution.
3. **Q3 — how specific should "trigger point" be?** Free-text field; template carries 3–4
   worked examples ("after PR merges to main", "after `terraform apply` completes in
   staging", "after downstream CI passes in repo X"). Don't over-prescribe.
4. **Q4 — sentinel name / location.** `.post-merge-verification-pending` at repo root.
   Contains plan path + checklist contents. Plan document remains the authoritative record;
   sentinel is a session-crossing breadcrumb. Deleted on user confirmation of completion.
5. **Q5 — how does the user confirm?** `AskUserQuestion` in `finishing-work` with three
   options: `Verification complete` (delete sentinel, append completion note to plan) /
   `Deferred — leave pending marker` (write sentinel, keep plan open) / `N/A — CI covered it`
   (delete sentinel, note the re-classification in the plan). No new skill required.
6. **Q6 — brainstorming + writing-plans, or just one?** Both. Brainstorming catches
   cross-repo designs early; writing-plans is the safety net when brainstorming was skipped.
   The cost is one extra question in each skill — cheap compared to missing the concern.
7. **Q7 — multi-sub-PR plans.** Verification fires once, at the end of
   `finishing-work` for the whole plan. `finishing-work` runs at plan-level completion
   regardless of how many intermediate sub-PRs were raised.
8. **Q8 — cross-repo scope.** Plan section has explicit `Repos involved` and `Commands`
   fields. Planner pre-fills concrete commands from research; human executes. Claude never
   runs the commands (by definition they require infra it can't access).
9. **Q9 — PostToolUse hook on `gh pr create`?** **Deferred.** Start with plan-section +
   `finishing-work` step. A hook can be layered on later if the in-session `AskUserQuestion`
   proves insufficient. Avoid building enforcement infrastructure before proving the need.
10. **Q10 — new skill?** No. Plan template + `finishing-work` step is sufficient. A new
    skill would warrant its own methodology doc; this is a three-field section and an
    AskUserQuestion gate — not worth a catalog entry.

## Implementation Steps

### Phase 1: brainstorming — prompt + design-doc section + checklist

**Execution**

- **Scope:** Add the verification prompt to brainstorming Phase 1 questions, add a
  `## Verification Plan` section to the design-doc template, and add a checklist item.
- **Depends on:** none
- **Parallel with:** none (sequential to establish vocabulary for Phase 2)
- **review_group:** `brainstorming-verification` *(Solo — single skill doc, single concern)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 1.1: Add verification question to brainstorming Phase 1

- **Files**: `skills/brainstorming/SKILL.md` (lines 43–65 area)
- **Action**: Append a new numbered question after the existing "constraints" question:
  > "**What verification beyond automated CI is needed?** Consider cross-repo coordination,
  > Terraform applies against live infra, post-deploy smoke checks, manual functional
  > checks that require data/access unavailable locally. A perfectly valid answer is
  > 'nothing — CI covers it'; the purpose of this question is to make the answer
  > explicit rather than implicit."
- **Verify**: Read file, confirm question appears in Phase 1 list, renders as Markdown.
- **Complexity**: Small

#### Step 1.2: Add `## Verification Plan` section to design-doc template

- **Files**: `skills/brainstorming/SKILL.md` (lines 116–140 area — design document template)
- **Action**: Insert after `## Trade-offs Accepted`:
  ```markdown
  ## Verification Plan

  **CI sufficient**: yes | no
  **If no — what needs to run, where, and when**:
  - [step with access requirement / repo / trigger point]
  ```
- **Verify**: Template renders; section sits between Trade-offs and Open Questions.
- **Complexity**: Small

#### Step 1.3: Add checklist item to "Checklist Before Proceeding"

- **Files**: `skills/brainstorming/SKILL.md` (lines 263–271 area)
- **Action**: Add bullet: `- [ ] Verification plan captured (CI-sufficient, or post-merge
  verification required + steps identified).`
- **Verify**: Checklist still parses as a list; item visible.
- **Complexity**: Small

#### Step 1.4: Manual render check

- **Files**: N/A
- **Action**: Open `skills/brainstorming/SKILL.md` in a Markdown previewer (VS Code preview
  or `glow`); confirm Phase 1 question list, design-doc template, and checklist all render
  correctly.
- **Verify**: No broken lists, no stray backticks, no formatting regressions.
- **Complexity**: Small

### Phase 2: writing-plans — template section + success-criteria prompt + checklist

**Execution**

- **Scope:** Add `## Post-Merge Verification` to the plan template, add a success-criteria
  prompt pointing to it, and add a quality-checklist item.
- **Depends on:** `brainstorming-verification` (vocabulary: "post-merge verification"
  established in Phase 1 must match Phase 2 wording)
- **Parallel with:** none
- **review_group:** `writing-plans-verification` *(Solo)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 2.1: Add prompt in "Define Success Criteria" section

- **Files**: `skills/writing-plans/SKILL.md` (lines 43–55 area)
- **Action**: Append to Section 2:
  > "**Verification beyond CI** — if the brainstorming design doc declared post-merge
  > verification (or if brainstorming was skipped, ask now): capture the scripts, access
  > requirements, repos involved, and trigger point in the `## Post-Merge Verification`
  > section of the plan template below. Default answer 'CI is enough' is valid and common;
  > state it explicitly rather than leaving the section unfilled."
- **Verify**: Prompt reads as part of success-criteria guidance; points to template section.
- **Complexity**: Small

#### Step 2.2: Add `## Post-Merge Verification` section to plan template

- **Files**: `skills/writing-plans/SKILL.md` (template area, currently lines 352–472 —
  insert between `## Manual Verification` (line 452–455) and `## Risks and Mitigations`)
- **Action**: Insert:
  ```markdown
  ## Post-Merge Verification

  **Required**: yes | no   *(if no, leave remaining fields blank or delete)*
  **Trigger point**: [e.g. "after PR merges to main", "after `terraform apply` completes
  in staging", "after downstream repo's CI passes on the consuming change"]
  **Repos involved**: [list any repos beyond this one; use `none` for same-repo work]
  **Commands / steps**:
  - [ ] [concrete command or action, with access requirement noted]
  - [ ] [concrete command or action]
  **Verification owner**: [who runs this — Matt manually / Claude in a new session with
  access to repo X / downstream repo CI]
  ```
- **Verify**: Template block renders; "Required: no" short form is unambiguous (CI-only
  plans leave the section with a single `Required: no` line).
- **Complexity**: Small

#### Step 2.3: Add quality-checklist item

- **Files**: `skills/writing-plans/SKILL.md` (lines 540–555 area — Quality Checklist)
- **Action**: Add bullet: `- [ ] Post-Merge Verification section filled in (either
  \`Required: no\`, or \`Required: yes\` with trigger point, commands, and owner).`
- **Verify**: Checklist renders; list parses.
- **Complexity**: Small

#### Step 2.4: Manual render + backward-compat check

- **Files**: N/A
- **Action**: Preview `skills/writing-plans/SKILL.md`. Spot-check existing plans in
  `docs/plans/` — confirm absence of `## Post-Merge Verification` does not break anything
  (the section is additive; old plans remain valid).
- **Verify**: Template renders; no breakage for historical plans.
- **Complexity**: Small

### Phase 3: research-plan-implement — final-report surfacing

**Execution**

- **Scope:** Add one line to the RPI final-report template surfacing verification status;
  document that the orchestrator does not itself gate on verification (delegated to
  `finishing-work`).
- **Depends on:** `writing-plans-verification` (references the section name)
- **Parallel with:** none
- **review_group:** `rpi-orchestrator-verification` *(Solo)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 3.1: Add verification line to final report template

- **Files**: `skills/research-plan-implement/SKILL.md` (lines 399–415 area)
- **Action**: Add to the final-report template, under `Reviews`:
  ```
  Verification: none | pending — see plan §Post-Merge Verification
  ```
- **Verify**: Report template renders; line is optional-value (`none` for CI-only plans).
- **Complexity**: Small

#### Step 3.2: Document orchestrator handoff to finishing-work

- **Files**: `skills/research-plan-implement/SKILL.md` (lines 379–415 area — finishing-work handoff)
- **Action**: Add a sentence: "Verification handoff lives in `finishing-work`; the
  orchestrator does not itself gate on `## Post-Merge Verification`. The orchestrator's
  only responsibility is to include the `Verification:` line in the final report based
  on whether `finishing-work` reported a pending marker."
- **Verify**: Handoff section reads coherently; no conflict with finishing-work doc.
- **Complexity**: Small

#### Step 3.3: Manual render check

- **Files**: N/A
- **Action**: Preview file; confirm final-report template still parses as a code block.
- **Verify**: No formatting breakage.
- **Complexity**: Small

### Phase 4: finishing-work — verification-surface step + sentinel

**Execution**

- **Scope:** Add a new step to `finishing-work` that (after PR creation, before cleanup)
  reads the plan's `## Post-Merge Verification` section, invokes `AskUserQuestion` when
  `Required: yes`, and manages the `.post-merge-verification-pending` sentinel.
- **Depends on:** `rpi-orchestrator-verification` (the sentinel name and final-report field
  must align with what the orchestrator surfaces)
- **Parallel with:** none
- **review_group:** `finishing-work-verification` *(Solo — meatier than Phases 1–3 because
  it introduces the only runtime-ish behavior, i.e. the `AskUserQuestion` + file I/O)*
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 4.1: Add Step 5 "Post-Merge Verification Surface" to finishing-work

- **Files**: `skills/finishing-work/SKILL.md` (insert after Option 2 "Create Pull Request"
  around line 108, before the existing "Clean Up" step)
- **Action**: Add section:
  ```markdown
  ### Step 5: Surface Post-Merge Verification (if any)

  After the PR URL has been reported, if a plan document exists for this work (the
  `research-plan-implement` orchestrator passes the plan path; otherwise search
  `docs/plans/` for the most recent `*-plan.md` that matches the feature branch):

  1. Read the plan's `## Post-Merge Verification` section.
  2. If `Required: no` (or the section is absent): do nothing. Proceed to cleanup.
  3. If `Required: yes`:
     a. Print the trigger point, repos involved, commands/steps, and verification owner
        to the user, prefixed with `POST-MERGE VERIFICATION REQUIRED:`.
     b. Invoke `AskUserQuestion` with options:
        - **Verification complete** — the user has already run the steps and confirms
          they passed. Delete `.post-merge-verification-pending` if present; append a
          `## Post-Merge Verification: Completed YYYY-MM-DD` note to the plan.
        - **Deferred — leave pending marker** — write
          `.post-merge-verification-pending` at repo root with contents:
          ```
          Plan: <plan path>
          Trigger: <trigger point>
          Commands:
          - <command 1>
          - <command 2>
          Owner: <owner>
          ```
          Commit it via the normal auto-commit flow.
        - **N/A — CI covered it after all** — delete any existing
          `.post-merge-verification-pending`; append a `## Post-Merge Verification:
          Reclassified as CI-sufficient YYYY-MM-DD — <one-line reason>` note to the plan.

  The sentinel file is a session-crossing breadcrumb, not an enforcement gate. A future
  phase may add a `PostToolUse` hook to surface the sentinel contents on new sessions; that
  is deliberately out of scope for this plan.
  ```
- **Verify**: Section renders; new step is numbered consistently with existing steps.
- **Complexity**: Medium

#### Step 4.2: Update finishing-work Prerequisites and Checklist

- **Files**: `skills/finishing-work/SKILL.md` (Prerequisites block near line 20–28;
  Checklist near line 271–280)
- **Action**:
  - Add to Prerequisites: "Plan path identified (if invoked via RPI); otherwise search
    `docs/plans/` for the matching plan before running Step 5."
  - Add to Checklist: `- [ ] Post-Merge Verification surfaced (or confirmed N/A) per Step 5.`
- **Verify**: Both sections parse; checklist covers new behavior.
- **Complexity**: Small

#### Step 4.3: Document sentinel file in project conventions

- **Files**: `skills/finishing-work/SKILL.md` (end of file, new "Artifacts" section if not
  present, else extend existing)
- **Action**: Document:
  - `.post-merge-verification-pending` — plain-text, repo-root, auto-committed by Stop
    hook, deleted by `finishing-work` on user confirmation of completion.
  - Rationale: survives session closure so a future session can `cat` it to pick up the
    outstanding verification obligation.
- **Verify**: Artifact described; naming matches Step 4.1.
- **Complexity**: Small

#### Step 4.4: Manual rehearsal — Required: no path

- **Files**: N/A
- **Action**: Read the full `finishing-work/SKILL.md`. Trace through a hypothetical
  CI-only plan (`Required: no`): confirm Step 5 is a no-op with zero extra user-visible
  friction.
- **Verify**: No-op path adds zero questions / prints / files.
- **Complexity**: Small

#### Step 4.5: Manual rehearsal — Required: yes path

- **Files**: N/A
- **Action**: Trace through a hypothetical cross-repo plan (`Required: yes`, two commands,
  Terraform trigger): confirm Step 5 prints the banner, asks the question, handles all
  three answer options correctly, and the sentinel format is unambiguous.
- **Verify**: All three answer branches are covered and consistent.
- **Complexity**: Small

### Phase 5 (terminal): security-gate

**Execution**

- **Scope:** Plan-level security review over the aggregated diff (`git diff $base_ref..HEAD`).
- **Depends on:** [`brainstorming-verification`, `writing-plans-verification`,
  `rpi-orchestrator-verification`, `finishing-work-verification`]
- **Parallel with:** none (terminal)
- **review_group:** `security`
- **security_review:** `automated` *(low sensitivity — prompt/doc changes only, no auth,
  no data access, no credentials, no production surface)*
- **Gate:** automated review-gate (reviewer runs first; remediation implementer spawns
  only on CHANGES; 2-pass cap with interactive drop-out)

**Reviewer inputs** (orchestrator-supplied; do NOT pipe per-phase reviewer summaries):

1. `git diff $base_ref..HEAD` — aggregated diff; `$base_ref` = HEAD recorded at plan start.
2. Plan document path (this file).
3. Ordered list of prior phase names: `brainstorming-verification`,
   `writing-plans-verification`, `rpi-orchestrator-verification`, `finishing-work-verification`.

**Control flow:**

- Reviewer writes `.review-verdict-security` per the sentinel contract.
- **PASS** → proceed to `finishing-work`.
- **CHANGES** → spawn remediation implementer; re-enter via `implement-review-gate.sh --group-id security`.
- **Cap-hit (exit 42)** → `AskUserQuestion`: remediate / override (logged) / abort.

## Test Strategy

This is a skill-prompt repo — no runtime code paths to exercise. Verification is
doc-rendering + rehearsal-based.

### Automated Tests

| Test Case | Type | Input | Expected Output |
|-----------|------|-------|-----------------|
| Markdown parses for each edited SKILL.md | Lint | `markdownlint skills/**/SKILL.md` (if configured) or a plain Markdown preview | No parse errors, no broken tables/lists |
| Plan template renders | Lint | Fenced template block in `writing-plans/SKILL.md` | Fenced block is well-formed, closes correctly |
| Historical plans still validate | Regression | `docs/plans/2026-04-*-plan.md` | No plan becomes invalid due to new optional section |

### Manual Verification

- [ ] Open each edited SKILL.md in a Markdown previewer; confirm clean render.
- [ ] Rehearse `finishing-work` Step 5 with `Required: no` — confirm zero friction.
- [ ] Rehearse `finishing-work` Step 5 with `Required: yes` and all three
      `AskUserQuestion` answer options — confirm each branch is coherent.
- [ ] Confirm `.post-merge-verification-pending` file format is unambiguous (a human
      reading it in a cold session should know what to run).
- [ ] Start a fresh Claude session, open the repo, confirm the Stop hook auto-commits
      any pending sentinel file.
- [ ] Confirm the brainstorming checklist and writing-plans quality-checklist items are
      internally consistent in wording (both say "Post-Merge Verification", same casing).

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Prompt drift — the added question creates friction on CI-only plans | Users start ignoring the question or filling `N/A` reflexively | Frame the default answer ("CI is enough") as **valid and common** in both brainstorming and writing-plans. Make `Required: no` a one-line section, not a multi-field template. |
| Wording mismatch across skills — "post-merge verification" in one, "verification plan" in another | Confusion; automation (e.g. a grep-based sentinel check) breaks | Standardise on exact phrase "Post-Merge Verification" (title case) for the section heading across all four skills; "verification plan" reserved for the brainstorming design-doc section (which is upstream). |
| Sentinel orphaned — `.post-merge-verification-pending` commits to main, never cleaned up | Repo accumulates stale sentinels | `finishing-work` Step 5 always runs at plan end; the three `AskUserQuestion` options all either delete the sentinel or explicitly leave it. Add a follow-up housekeeping item to `retro` skill if accumulation becomes a problem (out of scope here). |
| `finishing-work` invoked outside RPI (ad-hoc) can't find a plan | Step 5 silently skipped on work that needed verification | Step 5 falls back to searching `docs/plans/*-plan.md` by branch name; if no match, print a brief info line ("no plan found — skipping post-merge verification surface") rather than silently skipping. |
| Backward-compat break for P1–P6 plans | Existing plans flagged as non-compliant | Section is **additive and optional**. Quality-checklist item is soft (a checkbox in guidance, not an enforced gate). Historical plans remain valid. |

## Rollback Strategy

Revert the feature branch or individual phase PRs. No runtime state exists; no migrations;
no consumers outside this repo depend on the added template fields. The only sticky
artifact is any `.post-merge-verification-pending` files that may have been written — these
are plain text at repo root and can be deleted manually.

## Post-Merge Verification

**Required**: no
**Rationale**: This plan edits skill-prompt documents in the meta-repo. Verification is
fully covered by (a) CI (Markdown lint / repo tests, such as they are), (b) the terminal
`security-gate` reviewer reading the aggregated diff, and (c) the Manual Verification
checklist above being exercised in-session before `finishing-work`. There is no live
infrastructure, no cross-repo coordination, and no deployed surface whose behaviour
could only be validated post-merge. Eating our own dogfood: the correct answer here is
"CI is enough", stated explicitly.

## Status

- [x] Plan approved
- [x] Implementation started
- [ ] Implementation complete

### Phase progress

- [x] Phase 1: brainstorming-verification
- [x] Phase 2: writing-plans-verification
- [x] Phase 3: rpi-orchestrator-verification
- [x] Phase 4: finishing-work-verification
- [ ] Phase 5: terminal security-gate
