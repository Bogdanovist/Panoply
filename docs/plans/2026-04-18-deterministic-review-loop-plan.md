# Plan: deterministic-review-loop (2026-04-18)

## Summary

Make the RPI implement-phase review workflow deterministic by moving control flow out of skill prose and into bash. Introduces `implement-review-gate.sh` (a 2-pass implementer→reviewer loop with a sentinel-file verdict contract), reshapes per-phase review in `implementing-plans`, lifts security review from per-phase to a single terminal plan-level gate, teaches the planner to assign `review_group` IDs, updates the RPI orchestrator to consume the new contract, and deterministically enforces pr-preflight via a `PreToolUse` hook on `gh pr create`.

## Stakes Classification

**Level**: High
**Rationale**: Changes the default execution path of every future RPI run and installs a `PreToolUse` hook that intercepts real tool calls across every session. Misconfiguration silently breaks PR creation or corrupts review enforcement. Multiple skills and agent files change in concert; the review contract (sentinel file + verdict format) must stay consistent across producers and consumers.

## Context

**Research**: [2026-04-18 Deterministic Review Loop — Design Synthesis](./2026-04-18-deterministic-review-loop-research.md)

**Affected Areas**:

- `~/.claude/skills/implementing-plans/SKILL.md` — per-phase review wiring
- `~/.claude/skills/writing-plans/SKILL.md` — `review_group` field, sizing rules, terminal security-gate injection
- `~/.claude/skills/research-plan-implement/SKILL.md` — orchestrator control flow
- `~/.claude/skills/pr-preflight/SKILL.md` — sentinel write on PASS
- `~/.claude/agents/code-reviewer.md` — sentinel write contract
- `~/.claude/agents/security-reviewer.md` — sentinel write contract, plan-level mode
- New: `~/.claude/scripts/implement-review-gate.sh` (or equivalent stable location)
- New hook + settings: `~/src/Panoply/.claude/settings.json`
- New: `~/.claude/hooks/pr-preflight-gate.sh`

## Branch & PR Strategy

**Overall branch strategy:** feature branch `feat/deterministic-review-loop` off `main`, with **one sub-PR per phase** (6 sub-PRs merging into the feature branch; feature branch merged to main at the end). Per the research document, P5 is genuinely decoupled and MAY merge ahead of the rest directly to main if it lands first.

Each phase is independently reviewable because it touches different skills/agents/settings. Sub-PRs must stay small enough for human review even though most phase gates are automated.

## Resolved Open Questions

The research document left three choices open. This plan fixes them:

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Loop cap arithmetic | **2 passes total** (1 initial attempt + 1 remediation). Exit code on cap-hit: `EX_REVIEW_UNRESOLVED=42`. | Matches the research doc's stated default and the "gate" framing. Keeps reviewer cost bounded; interactive drop-out handles the tail. |
| 2 | PR-preflight sentinel staleness | **Time-based, 15 minutes.** Sentinel `.pr-preflight-passed` mtime must be within the last 900s of wall-clock time. | Simpler than comparing against HEAD sha; robust to rebases and amends; research doc recommended time-based. |
| 3 | Script name | **`implement-review-gate.sh`** | "Gate" is accurate: 2-pass cap + drop-to-interactive, not an unbounded loop. |

These choices MUST be used consistently across the script, skills, and agent files — any drift is a review-blocker.

## Success Criteria

- [ ] `implement-review-gate.sh` exists, is executable, and enforces the 2-pass contract end-to-end without model intervention.
- [ ] Reviewer agents (`code-reviewer`, `security-reviewer`) always write `.review-verdict[-<group_id>]` with the documented format.
- [ ] `writing-plans` emits plans that include a `review_group` field per phase and a terminal `security-gate` phase.
- [ ] `implementing-plans` no longer instructs per-phase security review; per-phase code review goes through the gate.
- [ ] `research-plan-implement` orchestrator consumes `review_group` deterministically and runs the terminal security gate once.
- [ ] `gh pr create` is blocked by the `PreToolUse` hook unless a fresh pr-preflight sentinel exists; escape hatch env var works and is logged.
- [ ] A dry-run of RPI on a representative fixture plan succeeds and exhibits: deterministic review at each group, one terminal security gate, and pr-preflight enforcement at PR creation time.

## Phase Overview

| # | Phase | Depends on | Parallel with | Gate |
|---|---|---|---|---|
| 1 | Gate script + reviewer sentinel contract | — | P5 | Automated review-gate (2-pass) |
| 2 | Plan-format updates in `writing-plans` | P1 | P5 | Automated review-gate |
| 3 | Per-phase wiring in `implementing-plans` | P1, P2 | P5 | Automated review-gate |
| 4 | Terminal security-gate phase | P2, P3 | P5 | Automated review-gate |
| 5 | PR-preflight `PreToolUse` hook | — | P1–P4, P6 | **Explicit human gate** |
| 6 | RPI orchestrator updates | P2, P3, P4 | P5 | Automated review-gate |

**Gate semantics (shared by all automated phases):** the phase's implementer invokes `implement-review-gate.sh`, which runs implementer→code-reviewer up to 2 passes. PASS → merge sub-PR. CHANGES-at-cap → drop to interactive; user and agent co-decide remediation path before merging the sub-PR. **P5 exception:** explicit human gate is mandatory — the user must read the diff of `settings.json` and the hook script before merging, because hook misconfiguration affects every future session (silent block of `gh pr create`, for example).

## Implementation Steps

### Phase 1: Gate script + reviewer sentinel contract

**Status: Complete** — script, tests, fixtures, and reviewer contract updates landed on `feat/deterministic-review-loop`. Script lives at `~/src/Panoply/scripts/implement-review-gate.sh` with `~/.claude/scripts` symlinked to `~/src/Panoply/scripts` (matches existing `agents`/`skills`/`hooks` symlink pattern). Pure-bash test harness used in place of bats (not installed; plan permits lightweight harness).

**Execution**

- **Scope:** Build the bash gate that owns the 2-pass implementer→reviewer loop and update the two reviewer agents to write the sentinel verdict file.
- **Depends on:** none
- **Parallel with:** P5
- **Gate:** automated review-gate (2-pass cap, interactive drop-out on cap-hit)

#### Step 1.1: Author `implement-review-gate.sh` with contract tests (RED) — Complete

- **Files**: `~/.claude/scripts/tests/implement-review-gate.bats` (new) — using `bats-core` or a lightweight pure-bash test harness if bats is unavailable.
- **Action**: Write failing tests asserting the gate's externally-observable behaviour.
- **Test cases**:
  - Reviewer writes `REVIEW_APPROVED` on pass 1 → exit 0, no second implementer call.
  - Reviewer writes findings on pass 1, `REVIEW_APPROVED` on pass 2 → exit 0, implementer called twice with findings piped in on the 2nd call.
  - Reviewer writes findings on both passes → exit code `42` (`EX_REVIEW_UNRESOLVED`), both rounds of findings printed to stdout.
  - `--group-id foo` flag → sentinel path is `.review-verdict-foo`; default (no flag) → `.review-verdict`.
  - Sentinel file pre-existing from prior run → deleted before pass 1 (no stale-state contamination).
  - Implementer command fails (non-zero exit) → gate exits non-zero with a distinct message, does NOT invoke reviewer.
  - Reviewer command fails → gate exits non-zero with a distinct message (do not silently treat reviewer crash as PASS).
- **Verify**: Tests exist and fail (no script yet).
- **Complexity**: Medium

#### Step 1.2: Implement `implement-review-gate.sh` (GREEN) — Complete

- **Files**: `~/.claude/scripts/implement-review-gate.sh` (new, chmod +x)
- **Action**: Minimal bash that:
  1. Parses `--group-id`, `--implementer-cmd`, `--reviewer-cmd` args (commands passed as strings executed via `bash -c` — the subagent-spawning glue lives in the caller, not this script).
  2. Computes `SENTINEL=".review-verdict${GROUP_ID:+-$GROUP_ID}"` and `rm -f "$SENTINEL"`.
  3. Pass 1: run implementer-cmd → run reviewer-cmd → read sentinel.
  4. If contents equal `REVIEW_APPROVED` exactly → exit 0.
  5. Else pass 2: re-run implementer-cmd with pass-1 findings piped via stdin → re-run reviewer-cmd → read sentinel.
  6. If PASS → exit 0; else print both rounds of findings to stdout and exit 42.
  7. Set `set -euo pipefail`; trap non-zero from implementer/reviewer and surface with distinct messages.
- **Verify**: All tests from 1.1 pass.
- **Complexity**: Medium

#### Step 1.3: Update `code-reviewer.md` to write the sentinel (RED → GREEN) — Complete

- **Files**: `~/.claude/agents/code-reviewer.md`
- **Action**:
  - Add an explicit "Verdict output contract" section: the agent MUST, as its final action, write `.review-verdict[-<group_id>]` containing either exactly `REVIEW_APPROVED` (nothing else, no trailing newline is tolerated — specify behaviour) OR a bulleted list of blocking issues.
  - The sentinel path is provided to the agent via the invoking prompt (`--group-id` flag of the gate translates into the agent's input).
  - Document that emitting anything else constitutes a reviewer protocol violation.
- **Test cases (manual)**:
  - Invoke `code-reviewer` against a known-clean diff → sentinel contains exactly `REVIEW_APPROVED`.
  - Invoke against a diff with a known defect → sentinel contains a bulleted findings list; no `REVIEW_APPROVED` string.
  - Invoke with a non-default group id → correct suffixed file written.
- **Verify**: Manual invocations produce sentinel in all three shapes.
- **Complexity**: Small

#### Step 1.4: Update `security-reviewer.md` to write the sentinel (same contract) — Complete

- **Files**: `~/.claude/agents/security-reviewer.md`
- **Action**: Identical verdict contract section as 1.3. Default group id for the terminal gate is `security` (sentinel path `.review-verdict-security`). Add a pointer that P4 will drive plan-level invocation.
- **Verify**: Manual invocation on a diff produces the sentinel in the expected shape.
- **Complexity**: Small

#### Step 1.5: End-to-end smoke of the gate against a fixture — Complete

- **Files**: `~/.claude/scripts/tests/fixtures/` (new minimal fixture — a tiny repo with a 1-line bug)
- **Action**: Run the gate with real `code-reviewer` against the fixture (1-pass PASS case) and a fixture with an intentional blocker (CHANGES-then-PASS case). Confirm sentinel lifecycle and exit codes match the contract.
- **Verify**: Both scenarios end as expected; `cat .review-verdict` shows the documented strings.
- **Complexity**: Small

---

### Phase 2: Plan-format updates in `writing-plans`

**Status: Complete** — `skills/writing-plans/SKILL.md` now includes a "Review groups" section (section 4a) with the three shapes table, sizing decision rules (<50% batched, 50–80% solo, independent streams → consolidator), the "reviewer cost tracks diff size, not phase count" anti-pattern, and a mandated terminal `security-gate` phase subsection. The plan template in section 6 now shows an Execution block with `review_group`, `depends_on`, and `Gate` fields, plus an example terminal `security-gate` phase with `security_review` mode. Quality Checklist extended with three new items covering `review_group` presence, terminal security-gate, and shape-choice documentation.

**Execution**

- **Scope:** Teach the planner to emit `review_group` IDs on each phase (Solo / Batched sequential / Fan-out + consolidator shapes) and to always append a terminal `security-gate` phase.
- **Depends on:** P1 (reviewer contract exists so the plan can reference it)
- **Parallel with:** P5
- **Gate:** automated review-gate

#### Step 2.1: Update `writing-plans/SKILL.md` planner rules — Complete

- **Files**: `~/.claude/skills/writing-plans/SKILL.md`
- **Action**:
  - Add a "Review groups" section mirroring the research doc's D5 table (Solo / Batched / Fan-out + consolidator).
  - Document the decision rules verbatim: <50% estimated context + shared concern → batched; 50–80% → solo; independent streams → consolidator.
  - Require each phase's Execution block to include `review_group: <id>`.
  - Require plans to always end with a `security-gate` phase (D6): `depends_on: [all prior groups]`, `review_group: security`, `security_review: automated | human | hybrid` (default `automated`).
  - Add anti-pattern: "do not split groups to save reviewer compute — reviewer cost tracks diff size, not phase count."
- **Verify**: Re-read section; emit a sample plan skeleton showing one of each shape + the terminal gate.
- **Complexity**: Small

#### Step 2.2: Add a planner self-check to the SKILL quality checklist — Complete

- **Files**: `~/.claude/skills/writing-plans/SKILL.md` (Quality Checklist)
- **Action**: Append items: "every phase has a `review_group` ID"; "plan ends with a `security-gate` phase"; "Solo/Batched/Consolidator decision documented per group if non-obvious."
- **Verify**: Checklist renders; items unambiguous.
- **Complexity**: Small

#### Step 2.3: Fixture-verify the updated planner — Complete (manual re-read)

Manual walk-through against a hypothetical 4-phase research doc (one heavy ~70%-context phase, two trivial shared-concern phases, two independent parallel streams, plus the mandated terminal gate) shows the updated skill produces: Solo group for phase 1, Batched-sequential group for phases 2+3, Fan-out+consolidator for phases 4a/4b, and the appended terminal `security-gate` phase with `depends_on: [all prior groups]` and `security_review: automated`. All required fields are covered by the template; no missing fields.


- **Files**: N/A (manual)
- **Action**: Run the skill against a toy research doc with 4 phases of mixed size; confirm the output plan assigns correct group shapes and appends the terminal security-gate phase.
- **Verify**: Plan compiles against the new rules; no missing fields.
- **Complexity**: Small

---

### Phase 3: Per-phase wiring in `implementing-plans`

**Execution**

- **Scope:** Flip `implementing-plans` from advisory review prose to deterministic invocation of `implement-review-gate.sh`, and remove the per-phase security review step.
- **Depends on:** P1 (script and contract), P2 (plan schema so the skill knows how to read `review_group`)
- **Parallel with:** P5
- **Gate:** automated review-gate

#### Step 3.1: Remove per-phase security review step

- **Files**: `~/.claude/skills/implementing-plans/SKILL.md` (section 5 "Complete Implementation" per research doc D6)
- **Action**: Delete the per-phase security-reviewer invocation. Leave a one-line pointer: "Plan-level security review runs as the terminal `security-gate` phase — see `writing-plans`."
- **Verify**: Grep the skill for "security-reviewer" → only the pointer remains.
- **Complexity**: Small

#### Step 3.2: Replace advisory code-review prose with gate invocation

- **Files**: `~/.claude/skills/implementing-plans/SKILL.md`
- **Action**: Replace the existing "run code-reviewer" language with concrete instructions to invoke `implement-review-gate.sh --group-id <review_group> --implementer-cmd "<cmd>" --reviewer-cmd "<cmd>"`. Document:
  - How the implementer determines the `review_group` from the plan.
  - Exit-code handling: 0 → proceed; 42 → drop to interactive with both rounds of findings; any other non-zero → surface error.
  - Batched-sequential shape: the implementer does all N phases in one go before invoking the gate once.
  - Consolidator shape: consolidator reads outputs of fan-out implementers, produces the unified diff, then invokes the gate once.
- **Verify**: Dry-run a 1-phase solo fixture end-to-end; sentinel lifecycle visible; gate returns 0.
- **Complexity**: Medium

#### Step 3.3: Cap-hit UX — interactive drop-out handoff

- **Files**: `~/.claude/skills/implementing-plans/SKILL.md`
- **Action**: Document that on exit 42, the skill must surface both rounds of reviewer findings in the conversation and stop. It MUST NOT proceed to the next phase and MUST NOT loop further. The user decides next step.
- **Verify**: Dry-run a fixture that fails twice → skill halts with findings visible.
- **Complexity**: Small

---

### Phase 4: Terminal security-gate phase

**Execution**

- **Scope:** Implement the plan-level security review: one reviewer run at end-of-plan over the aggregated diff, with a 2-pass remediation cap and interactive drop-out.
- **Depends on:** P2 (plan schema emits the terminal phase), P3 (per-phase skill no longer duplicates security review)
- **Parallel with:** P5
- **Gate:** automated review-gate

#### Step 4.1: Document plan-level security-review inputs and invocation

- **Files**: `~/.claude/agents/security-reviewer.md`
- **Action**: Add a "Plan-level mode" section specifying the three inputs per research doc D6:
  1. `git diff $base_ref..HEAD` (orchestrator supplies `$base_ref` = HEAD-at-plan-start).
  2. Path to the plan document.
  3. List of phase names for scope orientation.
  4. Explicitly: do NOT pipe per-phase reviewer summaries.
- **Verify**: Manual run with the three inputs against a fixture plan produces sensible output + sentinel `.review-verdict-security`.
- **Complexity**: Small

#### Step 4.2: Encode terminal-gate control flow

- **Files**: `~/.claude/skills/writing-plans/SKILL.md` (terminal-phase template)
- **Action**: The terminal `security-gate` phase's Execution block must specify:
  - Implementer (the security-reviewer agent runs first — this phase inverts the order).
  - On PASS → proceed to `finishing-work`.
  - On CHANGES → spawn a remediation implementer subject to the 2-pass cap (reuse `implement-review-gate.sh` with `--group-id security`, reviewer-cmd = security-reviewer).
  - On cap-hit → `AskUserQuestion` with options: remediate / override (logged) / abort.
  - `security_review: automated | human | hybrid`; default `automated`, hybrid for auth/data/architectural plans.
- **Verify**: Template renders; a hand-run of the flow against a fixture with a known security issue walks all three branches correctly.
- **Complexity**: Medium

#### Step 4.3: Remove stale per-phase security-review references

- **Files**: Search `~/.claude/skills/` and `~/.claude/agents/` for "security-reviewer" and "security review."
- **Action**: Remove or update any remaining "run security-reviewer after each phase" language. Ensure only the plan-level invocation remains.
- **Verify**: `grep -r security-reviewer ~/.claude/skills ~/.claude/agents` returns only the plan-level references.
- **Complexity**: Small

---

### Phase 5: PR-preflight `PreToolUse` hook

**Execution**

- **Scope:** Deterministically enforce pr-preflight by intercepting `gh pr create` via a `PreToolUse` hook that checks for a fresh sentinel file.
- **Depends on:** none
- **Parallel with:** P1, P2, P3, P4, P6
- **Gate:** **Explicit human gate.** After the sub-PR passes the automated review-gate, the user MUST read the diff of `settings.json` and the hook script and approve merge. Hook misconfiguration affects every future session — silent block of `gh pr create`, or worse, silent pass-through.

#### Step 5.1: Author the hook script

- **Files**: `~/.claude/hooks/pr-preflight-gate.sh` (new, chmod +x)
- **Action**: Bash script that reads the hook's JSON payload from stdin, extracts the Bash command, and:
  1. Detects `gh pr create` — MUST handle: leading whitespace, quoted variants (`"gh" pr create`), absolute path (`/opt/homebrew/bin/gh pr create`), and `gh` aliased via env. Use a regex like `(^|[[:space:]/"'])gh([[:space:]"'])+pr([[:space:]]+)create\b`.
  2. If not matched → exit 0 (allow).
  3. If matched → check `.pr-preflight-passed` in CWD (or repo root via `git rev-parse --show-toplevel`): must exist and mtime within 900 seconds. Use `stat` with a portable fallback (macOS `stat -f %m` vs Linux `stat -c %Y`).
  4. Escape hatch: if env var `PR_PREFLIGHT_SKIP=1` is set → log line to `~/.claude/logs/pr-preflight-skips.log` (with timestamp, CWD, command) and exit 0.
  5. Otherwise → exit 2 with a message on stderr telling Claude to run `pr-preflight` first.
- **Test cases** (bats or pure-bash harness):
  - Payload with `gh pr create --fill` + fresh sentinel → exit 0.
  - Payload with `gh pr create` + stale sentinel (mtime > 900s old) → exit 2 with guidance message.
  - Payload with `gh pr create` + missing sentinel → exit 2.
  - Payload with `gh pr view` → exit 0 (not intercepted).
  - Payload with `/opt/homebrew/bin/gh pr create` → intercepted.
  - Payload with `"gh" pr create` (quoted) → intercepted.
  - Payload with `gh pr createsomething` → NOT intercepted (word boundary).
  - `PR_PREFLIGHT_SKIP=1` + intercepted command + missing sentinel → exit 0 + log line written.
- **Verify**: All test cases pass.
- **Complexity**: Medium

#### Step 5.2: Update `pr-preflight` skill to write the sentinel on PASS

- **Files**: `~/.claude/skills/pr-preflight/SKILL.md`
- **Action**: Add an instruction: on PASS verdict, write `.pr-preflight-passed` at the repo root (not CWD — resolve via `git rev-parse --show-toplevel`). On WARN or BLOCK → do not write; surface findings. Document the 15-minute staleness rule so the user understands the UX.
- **Verify**: Manual run of pr-preflight on a clean branch writes the sentinel; a dirty branch does not.
- **Complexity**: Small

#### Step 5.3: Wire the hook into Panoply `settings.json`

- **Files**: `~/src/Panoply/.claude/settings.json` (new — settings.local.json already exists, but hook belongs in version-controlled settings.json so other Panoply contributors inherit it)
- **Action**: Add a `PreToolUse` hook entry matching `Bash` with command `~/.claude/hooks/pr-preflight-gate.sh`. Use the matcher format documented by the `update-config` skill.
- **Verify**: From a fresh session in Panoply, attempt `gh pr create` without a sentinel → blocked with the expected stderr message. Run `pr-preflight` → PASS → sentinel written → `gh pr create` allowed. Wait 16 minutes → sentinel stale → blocked again. Set `PR_PREFLIGHT_SKIP=1` and attempt again → allowed, log line written.
- **Complexity**: Medium

#### Step 5.4: Manual human-gate verification before merge

- **Files**: N/A (manual)
- **Action**: User reads the diff of `settings.json` and `pr-preflight-gate.sh` end-to-end and confirms:
  - Matcher regex does not over-match (e.g. `gh pr createrelease` is NOT a real subcommand, but `gh pr create-note` could be added in future — confirm intent).
  - Escape hatch works and is logged.
  - Stale-sentinel message is actionable.
- **Verify**: User signs off.
- **Complexity**: Small

---

### Phase 6: RPI orchestrator updates

**Execution**

- **Scope:** Update `research-plan-implement/SKILL.md` so the orchestrator reads `review_group` from plans, spawns one implementer per group (using the Solo/Batched/Consolidator shape), records `base_ref` at plan start, and runs the terminal security-gate phase once.
- **Depends on:** P2, P3, P4
- **Parallel with:** P5
- **Gate:** automated review-gate

#### Step 6.1: Encode orchestrator control flow per research §Orchestrator Control Flow

- **Files**: `~/.claude/skills/research-plan-implement/SKILL.md`
- **Action**: Document the end-state pseudocode from the research doc:
  - Record `base_ref = HEAD` at plan start.
  - Iterate plan groups in dependency order.
  - For each group, spawn one implementer per shape (Solo/Batched/Consolidator).
  - Implementer internally invokes `implement-review-gate.sh` (per P3).
  - On non-zero gate exit → drop to interactive with findings.
  - Honour `group.human_gate` if set.
  - Terminal: spawn `security-reviewer` with `$base_ref..HEAD` + plan path + phase names; read `.review-verdict-security`; branch per PASS / CHANGES / cap-hit.
  - On security PASS → invoke `finishing-work`.
- **Verify**: Re-read; confirm mapping to research §Orchestrator Control Flow is 1:1.
- **Complexity**: Medium

#### Step 6.2: Remove uniform-gate language

- **Files**: `~/.claude/skills/research-plan-implement/SKILL.md`
- **Action**: Remove any "all-autonomous" or "all-human" gate language. Per research anti-patterns: the planner specifies gates per phase; orchestrator refuses to run a plan missing `review_group` on any phase.
- **Verify**: Grep skill → no blanket-gate prose remains.
- **Complexity**: Small

#### Step 6.3: End-to-end dry-run against a fixture plan

- **Files**: N/A (manual)
- **Action**: Run RPI against a 3-phase fixture plan (one Solo, one Batched-sequential of 2 tiny phases, one terminal security-gate). Confirm:
  - `base_ref` is recorded.
  - Each group's gate runs exactly once.
  - Terminal security gate runs exactly once over the aggregated diff.
  - Only one final `finishing-work` call on PASS.
  - A deliberate security issue seeded into the fixture triggers the remediation flow and the 2-pass cap correctly surfaces `AskUserQuestion`.
- **Verify**: All observations match expectations; reviewer is not invoked per-phase for security.
- **Complexity**: Medium

---

## Test Strategy

### Automated Tests

| Test Case | Type | Input | Expected Output |
|---|---|---|---|
| Gate PASS on pass 1 | Unit (bats) | reviewer writes `REVIEW_APPROVED` | exit 0, 1 implementer call |
| Gate PASS on pass 2 | Unit (bats) | pass 1 CHANGES → pass 2 APPROVED | exit 0, 2 implementer calls |
| Gate cap-hit | Unit (bats) | CHANGES both passes | exit 42, both findings on stdout |
| Gate group-id suffix | Unit (bats) | `--group-id foo` | sentinel path `.review-verdict-foo` |
| Gate stale sentinel cleanup | Unit (bats) | pre-existing `.review-verdict` | removed before pass 1 |
| Gate implementer failure | Unit (bats) | implementer exits 1 | gate exits non-zero, reviewer NOT called |
| Gate reviewer failure | Unit (bats) | reviewer crashes | gate exits non-zero (not a silent PASS) |
| PR-hook fresh sentinel | Unit (bats) | sentinel mtime 10s old | exit 0 |
| PR-hook stale sentinel | Unit (bats) | sentinel mtime 901s old | exit 2 |
| PR-hook missing sentinel | Unit (bats) | no sentinel | exit 2 |
| PR-hook non-create command | Unit (bats) | `gh pr view` | exit 0 |
| PR-hook absolute path | Unit (bats) | `/opt/homebrew/bin/gh pr create` | exit 2 (no sentinel) |
| PR-hook word boundary | Unit (bats) | `gh pr createsomething` | exit 0 (not intercepted) |
| PR-hook escape hatch | Unit (bats) | `PR_PREFLIGHT_SKIP=1` + no sentinel | exit 0 + log line |

### Manual Verification

- [ ] Run code-reviewer against clean diff → sentinel = `REVIEW_APPROVED`.
- [ ] Run code-reviewer against defective diff → sentinel contains bulleted findings.
- [ ] Run security-reviewer plan-level against fixture plan → sentinel at `.review-verdict-security`.
- [ ] `writing-plans` against a toy research doc produces correct `review_group` assignments + terminal security-gate phase.
- [ ] `implementing-plans` dry-run on solo/batched/consolidator fixtures each invoke the gate exactly once per group.
- [ ] Panoply session: `gh pr create` blocked without sentinel; allowed within 15 min of PR-preflight PASS; blocked again after 16 min.
- [ ] `PR_PREFLIGHT_SKIP=1 gh pr create` in Panoply → allowed, log line present in `~/.claude/logs/pr-preflight-skips.log`.
- [ ] RPI full dry-run against 3-phase fixture plan → exactly one terminal security review, one `finishing-work` invocation on PASS.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Hook matcher over-matches (blocks valid commands) | Every session broken | Extensive unit tests (Step 5.1) covering quoted, absolute-path, word-boundary cases; P5 has explicit human gate. |
| Hook matcher under-matches (`gh pr create` slips through) | pr-preflight not enforced | Same unit tests; manual verification in fresh Panoply session (Step 5.3). |
| Sentinel race between runs | False PASS or false block | Gate deletes sentinel before each pass 1 (Step 1.2); pr-preflight sentinel is time-bounded and rewritten only on PASS. |
| Reviewer agent drifts off the verdict contract | Silent false PASS | Explicit contract in agent prose; gate treats anything other than exact `REVIEW_APPROVED` as CHANGES; reviewer crash → non-zero gate exit (Step 1.2). |
| Planner forgets `review_group` on a phase | Orchestrator can't run | Orchestrator refuses to run (Step 6.2); planner quality checklist (Step 2.2). |
| Batched-sequential group exceeds context mid-run | Implementer fails partway | Planner sizing rule (<50%); if observed in practice, refine budget heuristics — not a day-1 hard-code. |
| Terminal security-gate cost blows up on giant diffs | Long review cycles | Accepted trade-off per D6 — diff is the natural review unit; hybrid mode available for high-stakes plans. |
| Removing per-phase security review misses a class of defect only visible incrementally | Security bug lands | Plan-level diff review still catches it; hybrid-mode escalation for high-stakes plans. |
| PR-preflight escape hatch becomes a habit | Determinism defeated | Log every skip to `~/.claude/logs/pr-preflight-skips.log`; user reviews periodically. |

## Rollback Strategy

Each phase ships as its own sub-PR, so rollback is per-phase:

- **P1 rollback:** revert script + agent changes; no downstream consumers until P3 merges, so P1 can be reverted cleanly while P2 is in flight.
- **P2 rollback:** revert `writing-plans` changes — existing plans still runnable under old orchestrator.
- **P3 rollback:** revert `implementing-plans` to advisory prose; per-phase security review language returns.
- **P4 rollback:** remove terminal phase from planner template; re-enable per-phase security review in `implementing-plans`.
- **P5 rollback:** remove the `PreToolUse` entry from `settings.json` (single-line revert); hook script can remain in place as dead code. Lowest-risk rollback of the set.
- **P6 rollback:** revert orchestrator skill; still-merged P2–P4 remain functional but orchestrator falls back to prior control flow.

Full rollback = revert the feature branch merge commit on main; sub-PR granularity means partial rollback is always an option.

## Completion Checklist

- [ ] All tasks have clear verification criteria
- [ ] Test cases enumerated for each code change (automated and manual)
- [ ] Test steps precede implementation steps (RED before GREEN) where applicable
- [ ] Stakes level documented with rationale
- [ ] Tasks granular (prefer small complexity)
- [ ] Risks identified with mitigations
- [ ] Rollback strategy documented (high stakes)
- [ ] Plan document created at `docs/plans/2026-04-18-deterministic-review-loop-plan.md`
- [ ] Branch & PR strategy stated
- [ ] Three open questions resolved explicitly
- [ ] Each phase has Scope / Depends on / Parallel with / Gate block
- [ ] P5 explicit human gate called out

## Status

- [x] Plan approved
- [x] Implementation started
- [ ] Implementation complete

### Phase 5 — Complete (pending human review gate)

- 5.1 — Hook script authored at `~/src/Panoply/hooks/pr-preflight-gate.sh` (chmod +x). All 9 enumerated test cases verified manually with a temp git repo fixture (missing / fresh / stale sentinel; `gh pr view` ignored; `gh pr createsomething` word-boundary ignored; absolute path intercepted; quoted `"gh"` intercepted; `PR_PREFLIGHT_SKIP=1` allows + logs).
- 5.2 — `~/src/Panoply/skills/pr-preflight/SKILL.md` updated with a "Sentinel write on PASS (hook contract)" section specifying repo-root write, PASS-only, 15-minute staleness.
- 5.3 — `~/src/Panoply/settings.json` now registers the hook under `hooks.PreToolUse` with matcher `Bash`.
- 5.4 — **Pending explicit human review gate** (plan requirement). User must read the diff of `settings.json` and the hook script before merge.
