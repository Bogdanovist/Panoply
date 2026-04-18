# Research: RPI Verification Step (2026-04-18)

## Problem Statement

The RPI pipeline produces code that reaches a PR, passes CI, and is merged — but for cross-repo work (code in repo A + Terraform in repo B + infrastructure deploys) or for features whose correctness can only be proved by running scripts against live infrastructure, there is no mechanism to capture "a verification opportunity exists here" during planning and no deterministic trigger to ensure that opportunity is actually exercised after the PR lands.

The gap is not about CI or code-review quality (both are well-served by existing gates). It is about a class of validation that:

1. Cannot run inside CI because it requires live infrastructure, specific environment access, or coordination across repos.
2. Is currently remembered only by LLM context — and therefore reliably forgotten between sessions.
3. Is high-value enough that missing it only surfaces as a post-merge incident.

---

## Requirements (from user brief)

1. Brainstorming and planning phases must explicitly prompt "what verification beyond CI/pre-commit is needed for this work?"
2. Where such verification exists, it must be **captured in the plan document** (not just in conversation context).
3. The verification must be **deterministically triggered** at the right point — likely after the final PR is raised — not left to LLM memory.
4. The mechanism must be **optional** — CI-only work does not need it.
5. Must survive session boundaries (the whole point is that it cannot live in LLM memory).
6. Must not require new infrastructure for every use case — the trigger should be lightweight.

---

## Relevant Files

| File | Purpose | Key Lines |
|------|---------|-----------|
| `skills/brainstorming/SKILL.md` | Pre-planning ideation skill | 39–65 (Phase 1 questions), 263–271 (checklist) |
| `skills/writing-plans/SKILL.md` | Plan authoring skill | 43–55 (success criteria), 291–329 (terminal security-gate), 443–455 (manual verification section in template), 540–555 (quality checklist) |
| `skills/research-plan-implement/SKILL.md` | RPI orchestrator skill | 27–62 (architecture), 379–415 (terminal security-gate flow), 398–415 (finishing-work handoff), 484–517 (quality checklists) |
| `skills/implementing-plans/SKILL.md` | Plan execution skill | 233–260 (complete implementation, gate invocation), 491–512 (quality checklist) |
| `skills/verification-before-completion/SKILL.md` | Evidence-before-claims gate | 1–281 (entire file) |
| `skills/finishing-work/SKILL.md` | Post-implementation completion | 1–280 (entire file) |
| `skills/pr-preflight/SKILL.md` | Pre-PR local review gate | 161–175 (sentinel write contract) |
| `skills/end-session/SKILL.md` | End-of-session wrap-up | 1–17 (entire file) |
| `scripts/implement-review-gate.sh` | Gate/sentinel bash mechanism | 1–158 (entire file — the canonical determinism pattern) |
| `hooks/pr-preflight-gate.sh` | PreToolUse hook blocking gh pr create | 1–93 (hook pattern reusable for verification gate) |
| `settings.json` | Hook registration | 28–40 (PreToolUse hook wiring) |
| `docs/plans/2026-04-18-deterministic-review-loop-plan.md` | Precedent plan for gate pattern | Phase 5 (PR-preflight hook) as design template |

---

## Current State Map

### brainstorming/SKILL.md

[OBSERVED] The skill asks five exploratory questions in Phase 1: problem, audience, success criteria, constraints, prior considerations (lines 43–65).

[OBSERVED] The "Checklist Before Proceeding" at lines 263–271 has seven items: problem statement, success criteria, constraints, approaches considered, trade-offs discussed, YAGNI applied, design documented, next phase.

[INFERRED] There is no question or checklist item that asks "what verification beyond automated tests is needed?" The skill never prompts the user or LLM to consider post-merge, cross-repo, or infrastructure validation. The success-criteria question (line 52: "How will you know it works?") is the closest approximation, but it is framed at the feature level and does not distinguish CI-runnable from infrastructure-only validation.

[OBSERVED] The design document template (lines 116–140) has sections: Problem Statement, Chosen Approach, Design Details, Trade-offs Accepted, Open Questions, Next Steps. No "Verification Plan" or "Post-merge Checks" section exists.

### writing-plans/SKILL.md

[OBSERVED] Section 3 "Classify Stakes" (lines 53–62) documents Low/Medium/High risk levels. No axis for "verification complexity" exists independently of stakes.

[OBSERVED] Section 4 "Break Down Tasks" (lines 67–146) enumerates per-step verification via "Verify:" fields. These are CI-runnable checks (tests pass, lint clean, etc.).

[OBSERVED] The "Manual Verification" sub-section (lines 128–133) acknowledges manual steps where automated testing is impractical: "Steps a human performs to confirm behavior. Use when automated testing is impractical." This appears in the task template but has no plan-level equivalent.

[OBSERVED] The plan template (lines 352–472) includes: Summary, Stakes, Context, Success Criteria, Implementation Steps (phases with Execution blocks), Test Strategy (Automated + Manual Verification table), Risks, Rollback, Status. The "Manual Verification" section (lines 452–455) is a checklist of manual steps but is positioned inside the test strategy block as a peer of automated tests — it is not a distinct plan-level verification gate.

[OBSERVED] The terminal `security-gate` phase (lines 291–329, section 4a) is a dedicated plan-level gate phase that runs after all implementation groups. It has its own phase slot in the plan, its own `review_group: security` ID, explicit `depends_on` linking to all prior groups, and a well-defined sentinel contract. [INFERRED] This is the closest existing structural analogue to what the user wants for a post-PR verification gate, but it runs before the PR is raised (during implementation), not after merge.

[OBSERVED] The quality checklist (lines 540–555) has no item requiring "post-merge verification plan" or "e2e verification steps identified."

[INFERRED] The plan template has nowhere to declare "after this PR merges, run X script on infra." A planner today would either put this in the Manual Verification checklist (where it would be forgotten post-session) or document it in a note that has no enforcement mechanism.

### research-plan-implement/SKILL.md

[OBSERVED] The pipeline architecture (lines 27–62) is: Research → Plan → Implement (groups in dependency order) → Terminal security-gate → finishing-work → Final report. The last user-visible step after the security gate is `finishing-work` (lines 379–415, Step 4 and Step 5).

[OBSERVED] The final report template (lines 399–415) summarises: `review_groups completed`, `Branch strategy`, `Final PR`, `Files changed`, `Tests`, `Reviews`. There is no field for "Post-PR verification required" or "Verification tasks outstanding."

[OBSERVED] The orchestrator's "Do" list (lines 451–455) includes: Spawn subagents, read artifacts, present summaries, gate approvals, record `base_ref`, drive terminal security-gate, hand off to `finishing-work`. There is no step for "check if a verification gate was declared and trigger it."

[INFERRED] The orchestrator currently terminates after `finishing-work` completes. Any post-PR action would require either: (a) a new step appended to the orchestrator flow after `finishing-work`, or (b) a new mechanism outside the orchestrator (e.g. a hook or a new skill invoked by `finishing-work`).

### implementing-plans/SKILL.md

[OBSERVED] Step 8 "Complete Implementation" (lines 233–260) runs: mark all tasks complete, update plan status, run final verification (full test suite), run code review via `implement-review-gate.sh`. Per-step verification uses the "Verify:" field from the plan.

[OBSERVED] "Verification Techniques" (lines 438–462) covers: syntax check, type check, lint check, unit tests, manual test, integration test, API test, UI check, regression verification. These are all CI-runnable or local-environment checks.

[INFERRED] There is no category for "infrastructure validation" or "cross-repo validation." The skill has no concept of a verification step that must run after a PR lands on a remote environment.

[INFERRED] Per-step `Verify:` fields in plans today cover things like "tests pass" or "sentinel file written." They do not carry a flag distinguishing "can verify locally before commit" from "can only verify on live infrastructure post-merge."

### verification-before-completion/SKILL.md

[OBSERVED] This skill is focused entirely on **evidence-before-claims discipline** during the implementation phase (lines 1–281). Its Iron Law: "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE."

[OBSERVED] Its five-step gate is: Identify the command that proves a claim → Run it → Read output → Verify exit code → Make the claim. Every claim in the gate is about running a command **locally** (tests, lint, build, bug reproduction steps).

[OBSERVED] The skill's "Before PRs" section (lines 178–189) lists: all tests pass, lint clean, build succeeds, types pass, branch up to date, no merge conflicts, CI would pass (simulate locally if possible). No mention of post-merge or infrastructure checks.

[INFERRED] This skill answers a different question than what the user is asking. It is about not lying about local CI state. It does not address: "after the PR merges and deploys, did the end-to-end flow work?" These are orthogonal concerns.

[OBSERVED] The "Delegated Work" entry (lines 140–145) covers verifying agent claims, not infrastructure claims.

**Gap confirmed:** `verification-before-completion` covers CI-runnable evidence before claiming "done." It has no hook for deferred, post-merge, infrastructure-dependent verification. It is not the missing piece — it is a complementary but different concern.

### finishing-work/SKILL.md

[OBSERVED] The skill's step sequence (lines 18–170) is: verify tests pass → identify base branch → present options (merge locally / create PR / keep / discard) → execute → clean up.

[OBSERVED] The "Prerequisites" (lines 20–28) require: implementation steps done, verifications passed, code review completed, security review completed. These are all pre-PR conditions.

[OBSERVED] Option 2 "Create Pull Request" (lines 93–110) does: push branch, `gh pr create`, report URL, keep branch. After reporting the PR URL the skill terminates. There is no step asking "is there a post-PR verification requirement?"

[OBSERVED] The checklist (lines 271–280) has no item for "post-merge verification plan recorded" or "verification tasks handed off."

[INFERRED] `finishing-work` is the natural insertion point for a post-PR verification hook. It is the last skill executed in the RPI pipeline (invoked by the orchestrator after security PASS), and it produces the PR. After creating the PR it could check the plan for a declared verification gate and either: (a) print a reminder/instructions for what to run post-merge, or (b) write a sentinel or task that persists beyond the session.

### pr-preflight/SKILL.md

[OBSERVED] This skill runs **before** the PR is raised. It produces a PASS/WARN/BLOCK verdict. On PASS it writes `.pr-preflight-passed` sentinel (lines 161–175).

[OBSERVED] It is enforced by a `PreToolUse` hook (`hooks/pr-preflight-gate.sh`) that intercepts `gh pr create` and requires the sentinel to be fresh (within 900 seconds, lines 8, 88–89 of the hook).

[INFERRED] The `pr-preflight` pattern (sentinel → hook → gate) is exactly the determinism pattern that the user is asking to apply to post-PR verification. The mechanism is already proven and the code is readable. A verification gate could use the same sentinel+hook approach but at a different lifecycle point (e.g. intercepting some "mark as merged" or "deploy" action, or fired by a different hook event type).

**Key constraint:** pr-preflight is necessarily pre-PR. It cannot handle post-merge validation because CI is not available until after push. The user wants something that runs *after* merge, not before.

### end-session/SKILL.md

[OBSERVED] This skill (5 steps, lines 1–17) does: check uncommitted changes → run CI → ensure on branch → push and create PR → confirm exit. It is a shortcut for end-of-session wrap-up, not specific to RPI.

[INFERRED] `end-session` does not interact with verification plans, does not check for outstanding post-merge tasks, and has no hook for "did we declare any post-merge verification in the plan?"

### scripts/implement-review-gate.sh

[OBSERVED] The script (lines 1–158) is a deterministic 2-pass implementer→reviewer loop. Key contract elements:
- Sentinel file: `.review-verdict[-<group_id>]` written by the reviewer agent.
- Exit codes: 0 (PASS), 42 (EX_REVIEW_UNRESOLVED — cap hit), other non-zero (crash).
- Script accepts `--group-id`, `--implementer-cmd`, `--reviewer-cmd` via CLI args.
- Pass 1 findings piped via stdin to pass 2 implementer.
- Sentinel deleted before each reviewer run to prevent stale-state contamination (lines 73–74, 101).

[OBSERVED] This is the canonical "determinism lives in bash, not in skills" pattern (per the design decision D1 in `docs/plans/2026-04-18-deterministic-review-loop-research.md`). The LLM does not own the control flow — the bash script does.

[INFERRED] The same pattern could be applied to a verification gate: a bash script checks for a verification sentinel (`.verification-gate-passed` or similar), and the appropriate lifecycle hook (e.g. a PostToolUse hook or an instruction in `finishing-work`) triggers the human to run the verification scripts and write the sentinel on completion.

### hooks/pr-preflight-gate.sh

[OBSERVED] The hook (lines 1–93) intercepts `gh pr create` via `PreToolUse`. It reads JSON payload from stdin, extracts the Bash command, pattern-matches for `gh pr create`, checks sentinel mtime, blocks with a JSON `{"decision":"block","reason":...}` response on missing/stale sentinel, and allows on fresh sentinel. Escape hatch via `PR_PREFLIGHT_SKIP=1` env var (logged).

[OBSERVED] The hook uses exit code 0 after printing the JSON block — this is the Claude Code hook protocol for blocking tool calls.

[INFERRED] The same hook pattern could intercept a different command — e.g. a script the user runs to "close" a feature or "mark verified." Or it could be triggered by a PostToolUse hook after `gh pr create` succeeds, to prompt "a verification step is required: here are the steps."

### settings.json

[OBSERVED] Currently registers two hook types (lines 16–40):
- `Stop` hook: `auto-commit-push.sh` — runs after every Claude response.
- `PreToolUse` hook on `Bash`: `pr-preflight-gate.sh` — intercepts `gh pr create`.

[INFERRED] A third hook could be added. The available hook types in Claude Code are `Stop`, `PreToolUse`, `PostToolUse`. A `PostToolUse` hook on `Bash` matching `gh pr create` could fire after the PR is successfully created and instruct Claude to display the verification checklist from the plan. This differs from `pr-preflight-gate.sh` (which is `PreToolUse` and blocks) — a `PostToolUse` hook would be advisory/display rather than blocking.

---

## Examination of Past Plans

### How verification has been handled historically

**`docs/plans/2026-04-14-rpikit-fork-plan.md`:**
[OBSERVED] Uses "manual verification" steps at the end of each phase (e.g. "Step 1.6: Phase 1 verification checkpoint" at the documented line, Step 2.7 "end-to-end verification"). These are human-performed checks inside the session that directly follow implementation steps. They are documented as plan steps with `- **Files**: N/A (manual verification)`.

[OBSERVED] None of these steps are post-merge or post-deploy. They are all performed during the session before the PR is raised.

**`docs/plans/2026-04-17-rpi-research-evidence-plan.md`:**
[OBSERVED] Manual verification section (line 436) lists: read each file, run grep checks, render Markdown preview. All local, all pre-PR, all can be done by the implementer in-session.

[OBSERVED] No post-merge verification declared — appropriate for this plan since it only edits guidance documents with no infrastructure dependency.

**`docs/plans/2026-04-18-deterministic-review-loop-plan.md`:**
[OBSERVED] Contains the most thorough verification section (lines 368–397). Automated test table covers 13 unit cases. Manual Verification section (lines 390–397) has 8 items including: "Panoply session: `gh pr create` blocked without sentinel; allowed within 15 min of PR-preflight PASS; blocked again after 16 min."

[OBSERVED] Even here, all manual verification steps are pre-PR or in-session. There is no verification that fires after the feature branch merges to main (e.g. "confirm that a cold-start of a new Claude session correctly enforces the gate on a real subsequent RPI run across an arbitrary repo"). This is a gap the user's feature would address.

**`skills/docs/plans/2026-04-17-consolidate-review-skills-plan.md`:**
[OBSERVED] Has an "End-to-end acceptance" manual verification item (line 395): "after both phases are pushed, start a fresh session, run `/pr-preflight` on a real branch that Matt is about to push, and confirm the output is useful enough to drive a go/no-go push decision." This is documented as post-push but is still in-session — it requires the user to remember to do it.

[INFERRED] This is the most concrete historical example of a "post-merge" style verification step — but it relied entirely on the planner writing it into a checklist that the user must remember to revisit. There was no mechanism to enforce it. This is exactly the failure mode the user is describing.

**Conclusion from plan history:**
[OBSERVED] Every existing plan uses manual verification as a checklist inside the plan document. None have a mechanism to: (a) survive session closure, (b) be triggered deterministically, or (c) block further action until confirmed.

---

## The Gap: What the User Wants That Does Not Exist Today

| What exists | What is missing |
|-------------|-----------------|
| Per-step `Verify:` field in plan steps (CI-runnable) | A plan-level declaration that a verification opportunity EXISTS that cannot be run locally |
| Manual Verification checklist in plan template | A field/section specifically for post-merge or cross-repo verification (not just "manual" but "deferred and infrastructure-dependent") |
| `security-gate` terminal phase with sentinel + gate script | An analogous `verification-gate` terminal phase or post-phase that carries the script/steps to run post-merge |
| `pr-preflight` sentinel enforced by `PreToolUse` hook | A post-PR sentinel or trigger that ensures the user knows verification is outstanding after merge |
| `verification-before-completion` for local CI evidence | Nothing for infrastructure-level, post-deploy, cross-repo verification |
| Brainstorming checklist: problem, constraints, YAGNI | No prompt asking "what validation beyond CI will be needed?" |
| `finishing-work` creates the PR and terminates | No step after PR creation that checks plan for outstanding verification obligations |

---

## Candidate Insertion Points

### 1. brainstorming/SKILL.md

**Where:** Phase 1 question list (lines 43–65) and the "Checklist Before Proceeding" (lines 263–271).

**What to add:**
- A new Phase 1 question: "What verification beyond automated CI is needed? (cross-repo, infrastructure, post-deploy scripts, manual functional checks that require live data or access unavailable locally)" — positioned after the "constraints" question, since verification scope is a constraint on the feature.
- A checklist item: "Verification plan captured (CI-only, or post-merge verification required + steps identified)."

**Reasoning:** [INFERRED] Brainstorming is the earliest phase where a human and agent co-design the approach. Injecting the question here means the answer flows naturally into the design document and subsequently into the research and planning phases. If the answer is "CI is enough," nothing changes. If the answer is "we need to run X against infra," that becomes a first-class concern that feeds into the plan.

**Risk:** The question adds a small amount of cognitive overhead to every brainstorm, even for CI-only work. Mitigate by framing it as a single question with a binary answer ("CI only" = skip the rest; "post-merge verification exists" = capture it).

### 2. writing-plans/SKILL.md

**Where:** Two locations:
- Section 2 "Define Success Criteria" (lines 43–55): add a sub-question about post-merge verification.
- Plan template (lines 352–472): add a `## Post-Merge Verification` section adjacent to `## Manual Verification`.

**What to add in Success Criteria section:**
- A prompt: "Is there verification that cannot run in CI or locally? If so, document the scripts, access requirements, and trigger point (e.g. 'after Terraform apply completes in staging', 'after deploying to prod') here."

**What to add to the plan template:**

```markdown
## Post-Merge Verification

**Required**: yes | no
**Trigger point**: [e.g. after PR merges to main, after Terraform apply, after deployment to staging]
**Scripts / steps**:
- [ ] [command or action with access requirements noted]
- [ ] [command or action]
**Repos involved**: [list any repos beyond this one]
**Verification owner**: [who runs this — Claude in a new session, Matt manually, CI in a downstream repo]
```

**Where in the template:** After `## Manual Verification` (line 452) and before `## Risks and Mitigations`, since post-merge verification is a distinct concern from in-session manual verification.

**Quality checklist addition:** "Post-merge verification declared as required or explicitly noted as not applicable."

**Reasoning:** [INFERRED] Making this a named template section gives it the same status as the `security-gate` phase — it must be filled in (even if "no"), preventing it from being silently omitted. The planner is the agent with the most context about what the feature touches; they are the right agent to make this determination.

### 3. research-plan-implement/SKILL.md

**Where:** Two locations:
- Phase 1 Step 1 "Define Research Questions" (lines 87–97): add a research question category.
- Step 5 "Final Report" (lines 399–415): add a field.

**What to add to research questions:**
- A fifth question category: "Post-merge verification: are there validation steps that require live infrastructure, cross-repo coordination, or access unavailable in CI? Identify them during research so the planner can capture them."

**What to add to the Final Report:**
```
Verification gate: [none | pending — see plan §Post-Merge Verification]
```

**Orchestrator flow addition:**
After `finishing-work` completes (after Step 4 of the terminal security-gate, "On PASS → proceed to `finishing-work`"), add: "If the plan's `## Post-Merge Verification` section is marked `Required: yes`, surface the steps and trigger point to the user. Do not block — this is advisory at the orchestrator level; enforcement lives in the plan and optionally in a hook."

**Reasoning:** [INFERRED] The orchestrator is thin by design — it delegates and reads artifacts. It should not run verification scripts itself. But it can read the plan artifact and surface the outstanding verification obligation to the user at the right moment (after the PR is created), keeping LLM behavior consistent without requiring new infrastructure.

### 4. implementing-plans/SKILL.md

**Where:** "Complete Implementation" section Step 8 (lines 233–260) and Quality Checklist (lines 491–512).

**What to add:**
- After the gate invocation and before "Summarize results": "Check the plan for a `## Post-Merge Verification` section. If `Required: yes`, note the pending verification steps in the completion summary — they are NOT part of this implementer's scope but must not be silently dropped."
- Quality checklist: "Post-merge verification steps carried forward to completion summary (if declared in plan)."

**Reasoning:** [INFERRED] Implementers work group-by-group and don't own the full plan lifecycle. Their job is to surface, not to forget. A checklist item ensures they explicitly include any post-merge verification in the summary they hand back to the orchestrator.

### 5. finishing-work/SKILL.md

**Where:** After "Option 2: Create Pull Request" (lines 93–110), before "Step 5: Clean Up."

**What to add:** "After the PR URL is created, check the plan for a `## Post-Merge Verification` section. If `Required: yes`: print the trigger point and steps prominently. Write a plain-text summary to `.post-merge-verification-required` in the repo root (so it survives session closure and can be acted on in a new session)."

**Reasoning:** [INFERRED] `finishing-work` is the last skill in the RPI pipeline and the only place where both the PR URL and the plan contents are simultaneously available. It is the natural place to: (a) remind the user that post-merge verification is outstanding, and (b) write a persistent artifact.

**Alternative:** Skip the file write in `finishing-work` and instead rely on the plan document itself (which is committed to the repo). The plan's `## Post-Merge Verification` section is already in version control. A `PostToolUse` hook could detect the `gh pr create` success and check if the plan has a non-empty post-merge verification section.

### 6. brainstorming/SKILL.md — Design Document Template

**Where:** Lines 116–140 (design document structure).

**What to add:** A `## Verification Plan` section in the design doc template:

```markdown
## Verification Plan

**CI sufficient**: yes | no
**Post-merge verification**: [if no — describe what needs to run, where, and when]
```

**Reasoning:** [INFERRED] If the design document captures this early, the planner (who reads the design doc) inherits it automatically.

---

## How the Existing Gate/Sentinel Pattern Could Be Reused

### What the pattern provides (from implement-review-gate.sh)

[OBSERVED] The sentinel pattern in its current form:
1. A bash script owns control flow (not the LLM).
2. A sentinel file (`.review-verdict[-<group_id>]`) is written by an agent on a specific verdict.
3. Exit codes (0, 42, other) communicate outcomes to the caller.
4. A `PreToolUse` hook blocks a specific tool call until the sentinel is fresh.

### Applying it to post-merge verification

The pattern has three variants of applicability:

**Option A: Advisory only (no sentinel, no hook)**
The plan template captures the verification steps. The orchestrator surfaces them in the final report. The user runs them manually post-merge. This is the lightest-weight option: zero new mechanism, relies on the plan being a living document. The downside is that it restores LLM-memory-dependence for the trigger.

**Option B: Persistent artifact + reminder (sentinel file only)**
`finishing-work` writes a `.post-merge-verification-required` file (or appends to a `VERIFICATION_TODO.md`). This survives session closure. In a new session, the user can `cat VERIFICATION_TODO.md` to recall what to run. No hook needed. Limitation: requires the user to remember to check the file.

**Option C: PostToolUse hook on a downstream action**
A `PostToolUse` hook fires after `gh pr create` (or `gh pr merge`, if that becomes a tool call) and, if a `.post-merge-verification-required` file exists, prints the contents. This means every time Claude creates a PR, it will remind the user about outstanding verification. Limitation: `gh pr create` fires once and `PostToolUse` fires synchronously — the user may be mid-flow. Also, the user could be creating PRs for things unrelated to the plan that declared the verification.

**Option D: A `verification-gate` terminal phase (analogous to `security-gate`)**
Add a new terminal phase type to the plan template: `verification-gate`. The orchestrator, after `finishing-work`, checks if the plan has a `verification-gate` phase. If so, it pauses and presents the verification instructions to the user as an explicit human gate (not automated — verification requires live infra that the LLM cannot run). The user confirms when verification passes. The orchestrator writes a sentinel and proceeds to mark the plan complete.

[INFERRED] Option D is the most structurally consistent with the existing system. It reuses the `depends_on` / `review_group` pattern from the security-gate. It does not require a new hook mechanism. Its weakness: it requires the user to be in an active Claude session when performing the verification (since the confirmation step is an `AskUserQuestion`). For truly async verification (where deployment takes hours or the user runs the script days later), this is awkward.

**Option E: A persistent task via TaskCreate**
The orchestrator writes a task (via `TaskCreate`) describing the post-merge verification steps. Tasks persist across sessions (they are stored by the Claude Code runtime). When the user starts a new session, they can `TaskList` to see outstanding items. Limitation: TaskCreate tasks are not version-controlled and may not be visible outside Claude Code UI.

**Recommended approach from this research:** A combination of Option A + Option D, with Option B as a fallback persistence mechanism:
- Planner declares `## Post-Merge Verification` in the plan (Option A — plan as living document).
- Orchestrator treats it as an optional terminal phase that is always a **human gate** (Option D — explicit user confirmation).
- `finishing-work` writes `.post-merge-verification-required` (Option B — survives session, readable in next session).
- No new hook needed initially — the pattern can be validated without a hook and one can be added later if the human-gate confirmation step proves insufficient.

---

## Constraints and Non-Goals

1. **Must remain optional.** "CI is enough" plans must not be burdened with extra steps. The `## Post-Merge Verification` section defaults to `Required: no`; the orchestrator skips it entirely in that case.

2. **Not LLM-memory-dependent.** The trigger must not rely on the orchestrator or implementer "remembering" across session boundaries. The plan document (in version control) + optionally a sentinel file in the repo root are the memory layer.

3. **Verification steps are not run by Claude.** By definition these require live infrastructure the LLM cannot access. Claude's role is: capture the steps in the plan, surface them at the right moment, and record user confirmation. It does not execute the scripts.

4. **Not a new CI system.** The goal is not to create a new pipeline or integrate with GitHub Actions. It is to ensure that when a plan declares verification steps, those steps are surfaced to the human at the moment they become relevant (post-merge), and confirmed.

5. **Scope is RPI-level, not per-commit.** This is a plan-level concern, not a per-step or per-commit concern. A single plan may produce multiple PRs (sub-PRs in a feature branch strategy); the verification gate fires once, after the final PR merges.

6. **Does not replace pr-preflight.** `pr-preflight` runs before the PR is raised to catch code quality issues. Post-merge verification runs after merge to validate functional correctness on infrastructure. These are orthogonal gates.

7. **Does not replace the security-gate.** The terminal `security-gate` is a code/security review of the diff. Post-merge verification is a functional test of the deployed system. Same timing confusion risk as above — keep them distinct.

---

## Open Questions for the Planner

1. **Where exactly does the verification-gate human confirmation live in the orchestrator flow?**
   Options: (a) immediately after `finishing-work` in the RPI orchestrator; (b) as a final step inside `finishing-work` itself; (c) as a post-PR hook that fires in a new session when the user starts work on the merged branch. The planner must pick one.

2. **Should the plan declare a verification-gate phase with `review_group: verification` (parallel to the security-gate pattern), or should it be a separate section outside the Execution block system?**
   The `review_group` system is designed for code review loops. Verification is not a review loop — it is a human action checklist. Using the same mechanism risks confusion. A separate `## Post-Merge Verification` section (outside the phase list) may be cleaner.

3. **How does the plan identify *when* verification should run?**
   The "trigger point" field in the proposed template needs concrete examples. For Terraform work it might be "after `terraform apply` completes in staging." For cross-repo work it might be "after the downstream repo's CI passes." The planner needs guidance on how specific to be.

4. **What is the sentinel file name and location for post-merge verification?**
   If using a sentinel: `.post-merge-verification-required` at repo root (analogous to `.pr-preflight-passed`)? Or a section in the plan document itself (the plan is already in version control)? The planner must decide whether to introduce a new sentinel or lean on the plan document as the authoritative record.

5. **How does the user "confirm" verification passed?**
   Options: (a) `AskUserQuestion` gate in the orchestrator (requires active session); (b) the user manually edits the plan to check off items; (c) a skill invocation (e.g. `/verify-done`) that writes the sentinel. The planner must choose.

6. **Does the brainstorming skill need to be updated, or is writing-plans sufficient?**
   Adding a verification prompt to both risks duplication. If the planner can reliably identify verification requirements from the research document (which comes from a rigorous codebase + runtime investigation), brainstorming may not need it. On the other hand, for novel cross-repo designs that start in brainstorming, the question may be valuable there first.

7. **How does this interact with the single-PR vs. feature-branch-with-sub-PRs branch strategy?**
   If there are multiple sub-PRs (one per review_group), the verification gate fires after the feature branch merge to main — not after each sub-PR. The orchestrator needs to know when the final merge occurs to trigger the gate at the right time.

8. **What is the scope of "cross-repo" for verification?**
   The Terraform case (cloud-infrastructure repo) and the downstream CI case both imply the user needs to switch to a different repo and run commands there. Does the verification-gate step document those repo paths + commands? Should Claude pre-fill the commands from the plan, or is this always a "human reads and runs" step?

9. **Could a `PostToolUse` hook on `gh pr create` handle the surfacing automatically?**
   This would fire synchronously after PR creation. The hook could check for `.post-merge-verification-required` and print the checklist. This requires writing the file in `finishing-work` (or earlier). Worth the planner evaluating whether this is simpler than an orchestrator step.

10. **Is a verification-gate skill needed, or can this be handled purely by plan template + orchestrator prose?**
    Creating a new skill (`verification-gate` or `post-merge-verification`) adds to the skill catalog. The simpler alternative is: planner adds the section, orchestrator reads it and gates. A skill would be warranted if the surface of behavior is complex enough to need its own methodology document. The planner should assess.

---

## Findings Summary

### [OBSERVED] Key facts

- The `implement-review-gate.sh` sentinel+hook pattern is the canonical determinism mechanism in Panoply. It is well-tested (13 unit cases), understood, and reusable.
- The terminal `security-gate` phase is the only existing plan-level gate. It runs before the PR (during implementation) and is code-review-focused.
- `pr-preflight` is the only post-implementation but pre-PR gate. It is enforced by a `PreToolUse` hook.
- `finishing-work` is the last skill in the RPI pipeline. After creating the PR it terminates — no post-PR lifecycle exists.
- All past plans use manual verification as in-session checklists. None have a mechanism that survives session closure.
- `verification-before-completion` is an evidence-before-claims gate for local CI — different concern, not the missing piece.
- `brainstorming` and `writing-plans` have no prompt asking "what validation beyond CI is needed?"
- The `writing-plans` plan template has a `## Manual Verification` section but no `## Post-Merge Verification` section.
- The RPI final report has no field for outstanding verification obligations.

### [INFERRED] Key conclusions

- The user is right: there is no mechanism today that captures "post-merge verification exists" as a plan-level artifact and enforces it deterministically. The gap spans brainstorming (no prompt), writing-plans (no template section), orchestrator (no post-PR step), and finishing-work (terminates without checking for deferred verification).
- The lightest implementation that meets requirements: (1) add `## Post-Merge Verification` section to the plan template in `writing-plans`, (2) add a prompt in brainstorming, (3) have the orchestrator read the section and surface it as a human gate after `finishing-work`, (4) optionally have `finishing-work` write a `.post-merge-verification-required` file for session-crossing persistence.
- The sentinel+hook pattern can be reused but is likely overkill for a first implementation — the hook approach works best when there is a specific tool call to intercept (like `gh pr create`). For post-merge verification there is no such canonical tool call to intercept.
- The `security-gate` phase pattern (a named terminal phase in the plan) is a strong model for the `verification-gate` concept, but the mechanics differ: security-gate is automated (LLM runs the reviewer), verification-gate is always human (Claude cannot run the infra scripts).

---

## Recommendations (for Planner Subagent)

1. **Start with the plan template.** The lowest-risk, highest-value change is adding `## Post-Merge Verification` to the `writing-plans` template. This makes the concept visible in every plan and requires no new mechanism to be immediately useful. The planner must decide the exact field names and whether `Required: yes | no` or an optional section is cleaner.

2. **Add a brainstorming prompt.** One question in Phase 1 of brainstorming: "What verification beyond CI is needed?" This catches the concern early. Keep it a single question with a binary first answer to minimize overhead.

3. **Add an orchestrator step.** After `finishing-work` completes in the RPI orchestrator, add: "If the plan's `## Post-Merge Verification` section is `Required: yes`, present the steps to the user as a final human gate and record confirmation." This is an `AskUserQuestion` gate — not automated, always human.

4. **Add `finishing-work` persistence.** When `finishing-work` creates a PR and the plan has a post-merge verification section marked required, write `.post-merge-verification-required` to the repo root with the checklist contents. This file is committed (via the auto-commit hook) and visible in the next session.

5. **Skip a new hook for now.** A `PostToolUse` hook on `gh pr create` is the natural next step if the in-session human-gate proves insufficient — but it should come after validating that the plan template + orchestrator step meets the core need.

6. **Decide: verification-gate as a named terminal phase, or as a plan section?** The planner must resolve Open Question 2. Recommendation from this research: a plan section (outside the Execution block system) rather than a phase, because verification is not a code-review loop and does not fit the `review_group` model.
