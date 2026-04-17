# Plan: consolidate-review-skills (2026-04-17)

## Execution mode

**Autonomous, single PR.** Matt's global preferences say "decision visibility over permission gates" and "always push
the code." Both phases below are low-risk, local-only changes to his personal Panoply skills repo. The implementer
should run Phase A then Phase B back-to-back, commit with clear messages at each phase boundary, and push once at the
end. No gating questions; surface decisions in commit messages and the final summary.

## Summary

Matt has a new requirement: run the GitHub Actions Claude review bot prompt (from
`~/src/analytics/.github/workflows/claude.yml`) locally at end-of-session, before pushing. This plan introduces a new
skill `pr-preflight` that mirrors the bot prompt with local adaptations (git/gh diff gathering, stdout output) and
merges in the durable general-purpose concepts from the stale `/review` skill (severity levels, pass/warn/block verdict
with confidence, test-quality classification, security as explicit 5th review axis, verify-before-flag rule at agent
level, spec-soundness check, reusable lessons section). The stale `/review` skill is then deleted — research confirmed
no skill, agent, hook, or rule programmatically invokes it, so removal breaks nothing.

The four RPI-wired review components (`reviewing-code`, `security-review`, `code-reviewer` agent, `security-reviewer`
agent) are explicitly out of scope and MUST NOT be touched.

## Stakes Classification

**Level**: Low.

**Rationale**:
- `pr-preflight` is a brand-new additive skill — creation cannot break anything that doesn't already exist.
- `/review` is not programmatically referenced anywhere (research doc lines 86–98 lists every reference found — all
  are prose/historical). Deleting it affects only Matt's own muscle memory as a user.
- No automation, hooks, agents, or other skills depend on either change.
- Rollback is trivial: `git revert` or restore the `review/` directory from git history.
- All changes live in Matt's personal `~/src/Panoply/` dotfiles repo — no production systems, no shared infrastructure.

## Context

**Research**:
- `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-research.md` — full
  inventory, staleness evidence, verbatim bot prompt, local-adaptation requirements, naming analysis.
- `/Users/matthumanhealth/src/Panoply/skills/docs/plans/2026-04-17-consolidate-review-skills-salvage.md` — the seven
  salvage items from `/review` with suggested phrasing for each.

**User-fixed constraints** (do not revisit):
- New skill name is `pr-preflight`. Slug confirmed available — `/Users/matthumanhealth/src/Panoply/skills/pr-preflight`
  does not exist at plan time.
- `/review` will be deprecated (directory removed from `~/src/Panoply/skills/`).
- Matt invokes `pr-preflight` manually at end-of-session. No automation, no hooks, no triggers.
- RPI-bundled skills and agents (`reviewing-code`, `security-review`, `code-reviewer`, `security-reviewer`) are OUT OF
  SCOPE. Do not touch, reference, or import from them.

**Affected Areas**:
- `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/` (new directory with `SKILL.md`)
- `/Users/matthumanhealth/src/Panoply/skills/review/` (delete entire directory)
- `/Users/matthumanhealth/src/Panoply/README.md` (two edits: skill count in intro + row in the Local Skills table)

**Loader / discovery mechanism** (verified during planning, not assumed):
- `~/.claude/skills` is a single symlink to `~/src/Panoply/skills` (confirmed via `readlink`).
- Individual skills are plain subdirectories each containing a `SKILL.md`. They are NOT individually symlinked; they're
  discovered via the top-level symlink.
- Therefore creating `~/src/Panoply/skills/pr-preflight/SKILL.md` makes `/pr-preflight` discoverable with zero loader
  changes, matching exactly how `retro/`, `end-session/`, and every other sibling is registered.
- Deletion is likewise just `rm -rf ~/src/Panoply/skills/review`. No index/manifest to update beyond the README table.

## Success Criteria

- [ ] `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/SKILL.md` exists, follows the skill-creator frontmatter
      conventions used by sibling skills, contains the adapted bot prompt verbatim (with the GitHub-specific pieces
      replaced by local equivalents), and incorporates the salvage items the planner judged worth merging (see the
      salvage decision table below).
- [ ] `/pr-preflight` appears in the available-skills list in a fresh Claude Code session and can be invoked via the
      Skill tool.
- [ ] Running `/pr-preflight` on a branch with uncommitted-or-committed changes against `origin/main` produces
      stdout review output with a top-level verdict (PASS / WARN / BLOCK), confidence, and severity-tagged findings.
- [ ] `/Users/matthumanhealth/src/Panoply/skills/review/` directory no longer exists.
- [ ] `/review` no longer appears in the available-skills list in a fresh Claude Code session.
- [ ] `README.md` skill count ("31 local skills" → still "31 local skills"; net is +1 new, -1 deleted, so unchanged)
      and the Local Skills table reflect the swap (`review` row removed, `pr-preflight` row added, alphabetical order
      preserved).
- [ ] No RPI pipeline component is modified — `reviewing-code/`, `security-review/`, `code-reviewer.md`,
      `security-reviewer.md` are all byte-identical to their pre-change state.
- [ ] No other file in `~/src/Panoply/` or `~/.claude/` references `/review` in a way that would now fail (the existing
      references are all prose/historical per research, but re-verify after deletion).

## Salvage decision table

For each of the seven items in the salvage memo, the planner judges whether to merge or drop. Implementer follows this
table exactly; do not re-litigate.

| # | Salvage item | Decision | One-line justification |
|---|---|---|---|
| 1 | Severity levels (CRITICAL/SIGNIFICANT/MODERATE/MINOR) | **MERGE** | Bot has no severity vocabulary — without triage every finding reads as equally urgent. Core to pr-preflight's value. |
| 2 | Test-quality classification (behavioral/implementation/insufficient/none + real vs. mock data) | **MERGE** | Bot's four agents genuinely do not evaluate tests. Highest-leverage gap to close. |
| 3 | Verdict + confidence header (PASS/WARN/BLOCK + high/medium/low) | **MERGE** | Pre-push check exists specifically to answer "should I push?" — without a verdict the output is advisory noise. |
| 4 | Security as explicit 5th review axis | **MERGE, as a fifth parallel agent** | Bot has no security axis. Structurally correct to add it as Agent 5 alongside the existing four, keeping the parallel-dispatch pattern. |
| 5 | Verify-before-flagging rule at agent level | **MERGE** | Bot mentions this only in Phase 3 synthesis — too late. Hoisting it into each agent's brief cuts false positives at source. |
| 6 | Spec-soundness check (SPEC: prefix) | **MERGE** | Bot checks code-matches-description in one direction only. Catching an incoherent spec before code ships is cheap; after is expensive. |
| 7 | Reusable lessons section (0–3 bullets) | **MERGE** | Cross-PR learning has no other home in Matt's setup. Bounded at 3 items so it can't bloat the output. |

All seven merge. None were duplicative enough to drop. The salvage memo's analysis held up on planner review.

## Implementation Steps

### Phase A: Create `pr-preflight` skill

**Execution block**
- **Scope**: Everything under `~/src/Panoply/skills/pr-preflight/`. No other files touched.
- **Depends on**: Nothing. Research and salvage docs are already in place.
- **Parallel with**: Nothing. Phase B depends on A being complete (A is the replacement; B removes the thing being
  replaced).
- **Gate**: Phase B does not start until Phase A's Step A.4 verification passes.

#### Step A.1: Verify working tree and target slug

- **Files**: N/A (verification only)
- **Action**: Run `git -C /Users/matthumanhealth/src/Panoply status --short` (expect clean or only this plan doc
  staged). Run `ls /Users/matthumanhealth/src/Panoply/skills/pr-preflight 2>&1 | head -1` — expect
  `No such file or directory`. If the directory already exists, STOP and escalate; the plan assumes a clean slate.
- **Verify**: `pr-preflight/` does not exist. Working tree is in an expected state.
- **Complexity**: Small
- **Status**: Complete. `git status --short` showed only untracked `skills/docs/` (the plan doc itself, expected). `pr-preflight/` did not exist.

#### Step A.2: Create `pr-preflight/SKILL.md` with adapted bot prompt + merged salvage items

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/SKILL.md` (new)
- **Action**: Write the file with the structure below. Source of truth for the prompt body is
  `/Users/matthumanhealth/src/analytics/.github/workflows/claude.yml` lines 43–143 AND the verbatim block in the
  research doc (lines 108–208). Use the research doc's "What Needs to Change for a Local Pre-Push Skill" section (lines
  232–282) for every local adaptation.

  **Required file structure** (implementer must produce all sections; do not paraphrase the prompt body — paste verbatim
  with only the enumerated substitutions):

  1. **YAML frontmatter** matching sibling skills (`retro/SKILL.md`, `end-session/SKILL.md` are the closest
     structural references). Fields:
     - `name: pr-preflight`
     - `description:` one sentence starting with "Run the GitHub Claude review bot's prompt locally against the
       current branch before pushing. Prints findings to stdout with severity, a PASS/WARN/BLOCK verdict, and
       reusable lessons. Use at end-of-session when a PR will be raised."
     - Any other frontmatter fields that sibling skills use (copy the shape from `retro/SKILL.md`).

  2. **Intro paragraph** (2–3 sentences): what this skill does, when Matt invokes it (manually, end-of-session,
     pre-push), and one sentence clarifying it is the local-parity companion to the GitHub `@claude` review bot, not a
     replacement for the RPI code-reviewer/security-reviewer agents.

  3. **Phase 1: Gather local context** — the bot's Phase 1, with substitutions per research doc lines 232–253:
     - Replace `gh pr view <num>` with: read the current branch name (`git rev-parse --abbrev-ref HEAD`), the merge
       base with `origin/main` (`git merge-base HEAD origin/main`), and the commit log
       (`git log $(git merge-base HEAD origin/main)..HEAD --oneline`) as the PR-body substitute.
     - Replace `gh pr diff <num>` with: `git diff $(git merge-base HEAD origin/main) HEAD`.
     - Replace `gh pr checks <num>` with: a note that CI status is unavailable pre-push; if a PR already exists on
       this branch (`gh pr view --json number --jq .number 2>/dev/null`), fall back to `gh pr checks` on that PR.
     - Preserve the bare `Ultrathink` directive verbatim (research doc line 264–267).

  4. **Phase 2: Launch FIVE review agents in parallel** — bot's four agents (Correctness, Reuse, Quality, Efficiency)
     verbatim, PLUS a fifth Security agent from salvage item 4. Keep every hint list exactly as written in the bot
     prompt. For Agent 5 (Security), use the phrasing from salvage item 4: hardcoded credentials, missing auth /
     permission checks, data exposure at API boundaries, and conflicts with established architectural patterns in the
     repo. At the top of Phase 2, add the verify-before-flagging rule (salvage item 5) as a first-class instruction
     applied to each agent, not deferred to synthesis: "Before an agent includes any finding in its output, it MUST use
     Grep or Read to confirm the issue exists in the actual diff. No speculation. No flagging from memory."

  5. **Phase 3: Synthesize findings** — bot's Phase 3 verbatim, plus:
     - Require every finding to carry a severity tag: `CRITICAL` (blocks merge), `SIGNIFICANT` (should fix before
       merge), `MODERATE` (follow-up acceptable), `MINOR` (style/nit). (Salvage item 1.)
     - Require a dedicated test-quality sub-section classifying the PR's tests as behavioral / implementation /
       insufficient / none, and noting whether tests rely entirely on synthetic/mock data. (Salvage item 2.)
     - If the PR description / commit messages themselves contain a design error or incoherent intent, flag it with a
       `SPEC:` prefix as a distinct concern category. (Salvage item 6.)

  6. **Output** — replace the bot's `gh pr review --comment` and
     `mcp__github_inline_comment__create_inline_comment` instructions with stdout output. Structure (mandatory):
     ```
     # PR Preflight Report

     **Verdict**: PASS | WARN | BLOCK
     **Confidence**: high | medium | low

     ## Overall assessment
     (one short paragraph)

     ## Assumptions
     (bullet list — intent and context assumptions, and questions you answered yourself)

     ## Findings
     (grouped by severity: CRITICAL, SIGNIFICANT, MODERATE, MINOR. Each finding includes file:line reference,
     description, and suggested fix. SPEC: findings appear here too, prefixed.)

     ## Test quality
     (behavioral / implementation / insufficient / none, plus mock-vs-real-data note)

     ## Reusable lessons
     (0–3 bullets — patterns worth carrying forward into future work in this codebase. Omit section entirely if none.)
     ```
     - Verdict rules: BLOCK if any CRITICAL or SIGNIFICANT finding exists. WARN if only MODERATE/MINOR findings.
       PASS if no actionable concerns. If confidence is `low`, escalate (ask Matt a targeted question) rather than
       emit a confident verdict. (Salvage item 3.)
     - Reusable lessons section capped at 3 bullets (salvage item 7).
     - Explicitly DO NOT call `gh pr review`, `gh pr review --approve`, `gh pr review --request-changes`, or any
       inline-comment MCP tool. Stdout only. (Preserves the bot's "only a human may approve" rule and matches the
       local-skill paradigm.)

  7. **Scope guardrails** (one short section near the end):
     - This skill does NOT replace the RPI `code-reviewer` / `security-reviewer` agents — those run during
       implementation. `pr-preflight` is the pre-push local mirror of the GitHub `@claude` bot.
     - This skill does NOT read project `intent.md`, `design.md`, or `architecture.md`. It is diff-focused, matching
       the bot's scope. (This is the deliberate difference from the deleted `/review`.)

- **Test cases** (manual — skill prompts are not unit-testable, but the file content is structurally checkable):
  - File exists at `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/SKILL.md`.
  - File starts with YAML frontmatter containing `name: pr-preflight`.
  - File contains the literal string `Ultrathink` (preserved verbatim from bot prompt).
  - File contains all five agent headings: Correctness, Reuse, Quality, Efficiency, Security.
  - File contains all four severity labels: `CRITICAL`, `SIGNIFICANT`, `MODERATE`, `MINOR`.
  - File contains the literal strings `PASS`, `WARN`, `BLOCK`, and `Reusable lessons`.
  - File contains the literal string `SPEC:`.
  - File does NOT contain `gh pr review --comment` or `mcp__github_inline_comment` — these must be removed in
    favour of stdout output.
  - File contains the literal string `intent.md` only inside the scope-guardrails section (confirms the
    guardrail names the file explicitly). File does NOT contain any `!`-include or `cat` shell command reading
    `intent.md`, `design.md`, or `architecture.md`.
- **Verify**: Each of the above grep-level checks passes (implementer can run a single `grep -l` sweep).
- **Complexity**: Medium (mostly transcription + careful substitution; the salvage-merge integration is the only real
  judgement call, and the merge points are specified above)
- **Status**: Complete. File written at `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/SKILL.md`.
  Structural sweep: name-frontmatter=1, `Ultrathink`=1, all 5 agent headings present, all 4 severity labels present
  (3 occurrences each — definition, verdict rules, Findings description), verdict literals `PASS`/`WARN`/`BLOCK`
  each ≥4, `Reusable lessons`=2, `SPEC:`=2, forbidden `gh pr review --comment`=0, `mcp__github_inline_comment`=0.
- **Deviation note (implementer)**: The plan's required file-structure bullet 7 ("Scope guardrails") instructs to
  include a bullet stating "This skill does NOT read project `intent.md`, `design.md`, or `architecture.md`." —
  explicitly naming the three files as an anti-drift guardrail. The plan's Test Cases list (same step) says the file
  must NOT contain those three strings. The two directives contradict each other. I kept the scope-guardrails bullet
  as the required structure dictates (stronger semantic — names the exact files to prevent future drift) and am
  flagging the contradiction here for Matt's review. Adjust the test-cases list to match if desired.

#### Step A.3: Live smoke test on a real branch

- **Files**: N/A (runtime verification)
- **Action**: In a fresh Claude Code session (or `/compact` to drop loaded context), start Claude in a repo with a
  branch that has a non-empty diff against `origin/main` (the Panoply repo itself is a fine target — the pr-preflight
  creation IS such a diff). Invoke `/pr-preflight`. Confirm:
  1. The skill appears in the available-skills list.
  2. The skill runs end-to-end without erroring.
  3. Output contains the required report structure (Verdict, Confidence, Findings grouped by severity, Test quality,
     optional Reusable lessons).
  4. The five agents actually run (visible in the trace) — Correctness, Reuse, Quality, Efficiency, Security.
  5. No `gh pr review` or inline-comment call is attempted.
- **Verify**: All five sub-checks pass. If any fail, fix the SKILL.md and re-test.
- **Complexity**: Small
- **Status**: Partially complete. Sub-check 1 (skill appears in available-skills list) passed in-session — the system-reminder list refreshed within this same session to include `pr-preflight: Run the GitHub Claude review bot's prompt locally...`. Sub-checks 2–5 require a fresh session and invoking `/pr-preflight`; deferred to Matt (or Phase B's Step B.4 equivalent session) since a subagent cannot spawn a fresh Claude Code session. Structural sweep in Step A.2 stands in for checks 3 & 5 at the file-content level (verdict structure is present; no `gh pr review --comment` / `mcp__github_inline_comment` literals).

#### Step A.4: Commit Phase A

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/pr-preflight/SKILL.md` and any Panoply-repo auto-commits from
  the auto-commit hook.
- **Action**: The auto-commit hook handles staging/commit/push. If for any reason it does not fire, manually
  `git add skills/pr-preflight/SKILL.md && git commit -m "feat(skills): add pr-preflight — local mirror of GitHub @claude review bot with salvaged concepts from /review"`
  and push.
- **Verify**: `git log -1` shows the commit on `main`. `git -C /Users/matthumanhealth/src/Panoply status` is clean.
- **Complexity**: Small
- **Status**: Complete (commit only; push deferred per caller instruction to Phase B's final step). RPI-bundled
  file guardrail verified: `git diff HEAD -- agents/ skills/reviewing-code/ skills/security-review/` returned
  empty output. Committing `skills/pr-preflight/SKILL.md` + plan doc updates + the two existing planning memos
  (`-research.md`, `-salvage.md`) that have been untracked. NOT pushing — Phase B adds to same branch; later step
  raises the PR.

### Phase B: Deprecate stale `/review` skill

**Execution block**
- **Scope**: Delete `/Users/matthumanhealth/src/Panoply/skills/review/` and update
  `/Users/matthumanhealth/src/Panoply/README.md`.
- **Depends on**: Phase A complete and committed. (Matt needs the replacement live before the original goes away.)
- **Parallel with**: Nothing.
- **Gate**: Only start after Step A.4 verification passes. If Step B.2 finds an unexpected live reference, STOP and
  escalate before deleting.

#### Step B.1: Re-verify no runtime references to `/review`

- **Files**: N/A (verification only)
- **Action**: Re-run the research doc's reference sweep to catch anything added between research and now. Specifically
  grep across `~/.claude/` and `~/src/Panoply/` for the patterns that would indicate a programmatic invocation:
  - `Skill tool.*review` (Skill-tool invocations naming `review`)
  - `skill: ["']?review["']?` (frontmatter refs)
  - `/review` as a literal slash-command string in hooks, agents, or other skills
  - `skills/review/` as a file path reference
  Research doc already catalogued the five existing non-programmatic references (changelog, two historical plans, the
  inventory doc, and one generic prose mention in `retro/SKILL.md` line 28). Confirm those are still the only hits and
  that each is still non-programmatic prose.
- **Verify**: No NEW references beyond the five catalogued in the research doc. All five remain non-programmatic
  (changelog entry, historical plans, inventory doc, prose mention in `retro/SKILL.md`).
- **Complexity**: Small
- **Status**: Complete. Fresh sweep across `~/src/Panoply/` and `~/.claude/` (settings*.json, hooks/, agents/, CLAUDE.md,
  plugins/cache) turned up zero programmatic hits. All matches were either (a) inside this plan's own docs/plans
  artifacts, (b) `review/SKILL.md` itself (about to be deleted), (c) historical session jsonl transcripts / file-history
  backups (data, not code), (d) `~/.claude/plugins/marketplaces/claude-plugins-official/**` which are external third-party
  plugin-dev docs referencing a generic `/review` example unrelated to Matt's skill, or (e) an intentional forward-looking
  prose reference inside `pr-preflight/SKILL.md` line 163 ("now-deleted `/review`"). Also noted: the system-reminder
  skills list contains a Claude Code built-in `/review` ("Review a pull request") which is distinct from Matt's local
  skill and will remain after deletion.

#### Step B.2: Delete the `review/` skill directory

- **Files**: `/Users/matthumanhealth/src/Panoply/skills/review/` (entire directory, including `SKILL.md` and
  `references/`)
- **Action**: `rm -rf /Users/matthumanhealth/src/Panoply/skills/review`. Because `~/.claude/skills` is a symlink to
  `~/src/Panoply/skills`, the deletion propagates automatically — no second `rm` needed on the `~/.claude/` side.
- **Verify**: `ls /Users/matthumanhealth/src/Panoply/skills/review 2>&1` returns "No such file or directory".
  `ls /Users/matthumanhealth/.claude/skills/review 2>&1` also returns "No such file or directory" (proves the symlink
  propagation).
- **Complexity**: Small
- **Status**: Complete. Pre-delete snapshot captured (`SKILL.md` 6450 bytes + `references/code-standards.md` 3733 bytes).
  Post-delete: both `~/src/Panoply/skills/review` and `~/.claude/skills/review` return "No such file or directory" —
  symlink propagation confirmed. The refreshed system-reminder skills list in this same session also dropped Matt's
  local `/review` entry, leaving only the distinct Claude Code built-in `/review` ("Review a pull request").

#### Step B.3: Update `README.md` skill inventory

- **Files**: `/Users/matthumanhealth/src/Panoply/README.md`
- **Action**:
  1. Line 140: update "31 local skills + 9 via plugin (40 total)" — net change is zero (removed `review`, added
     `pr-preflight`), so count stays at 31. Confirm the line is accurate; no edit needed if so.
  2. In the Local Skills table (lines ~146–176), remove the `review` row and add a new `pr-preflight` row. Preserve
     alphabetical ordering: `pr-preflight` sits between `parallel-agents` and `pdf` (p-r-e... sorts after p-a-r... and
     before p-d-f). `pr-preflight` row description: "Local mirror of the GitHub Claude review bot — runs the
     five-axis review prompt against the current branch and prints a PASS/WARN/BLOCK verdict to stdout."
- **Verify**:
  - `grep -c "| \`review\` |" README.md` returns 0 (row removed).
  - `grep -c "| \`pr-preflight\` |" README.md` returns 1 (row added exactly once).
  - Visually inspect the table: row ordering is alphabetical, column alignment is preserved.
- **Complexity**: Small
- **Status**: Complete. Row-count greps: `review` row = 0, `pr-preflight` row = 1. Alphabetical slot corrected — plan
  text said "between parallel-agents and pdf" but `pr-preflight` (p-r) actually sorts AFTER `pdf` (p-d) and before
  `react-best-practices` (r-e), so placed between lines 158/160. Plan text had a minor alphabetising error; final table
  order is correct. Count line "31 local skills" still accurate (net-zero change). Pre-existing drift noted but NOT
  fixed (out of scope): README lists `wardley-mapping` but there is no corresponding `skills/wardley-mapping/` directory
  on disk; conversely `skills/system-feedback/` exists and IS listed. Net list-vs-filesystem match for this plan stays
  accurate post-edit.

#### Step B.4: Post-delete breakage sweep

- **Files**: N/A (verification only)
- **Action**: In a fresh Claude Code session (or `/compact`), confirm:
  1. `/review` no longer appears in the available-skills list.
  2. `/pr-preflight` appears in the available-skills list.
  3. RPI-wired skills still appear and load correctly: `/reviewing-code`, `/security-review`.
  4. RPI agents still load: `code-reviewer`, `security-reviewer` (check `~/.claude/agents/code-reviewer.md` and
     `~/.claude/agents/security-reviewer.md` resolve to the Panoply source and are byte-unchanged via
     `git -C /Users/matthumanhealth/src/Panoply diff HEAD -- agents/` showing no changes to either file).
  5. No runtime errors during session startup from the deletion.
- **Verify**: All five checks pass.
- **Complexity**: Small
- **Status**: Complete. (1) Refreshed system-reminder skills list (same session) no longer shows Matt's local `/review`;
  only the Claude Code built-in `/review` ("Review a pull request") remains — distinct product, unaffected. (2)
  `/pr-preflight` still present in skills list. (3) `/reviewing-code` and `/security-review` still present in skills
  list. (4) RPI guardrail verified: `git diff HEAD -- agents/ skills/reviewing-code/ skills/security-review/` = empty,
  and `git diff HEAD~1 -- agents/ skills/reviewing-code/ skills/security-review/` (relative to the pre-Phase-A tip
  5d8fdd9) also = empty — both RPI bundles byte-unchanged across both Phase A and Phase B. Directories `agents/`,
  `skills/reviewing-code/`, `skills/security-review/` confirmed to still exist on disk. (5) No runtime errors during
  session; the skills-list refresh was clean.

#### Step B.5: Commit Phase B and push

- **Files**: The directory deletion + `README.md` edit.
- **Action**: Auto-commit hook handles it. If it doesn't fire,
  `git add -A skills/review README.md && git commit -m "chore(skills): deprecate /review — superseded by /pr-preflight; salvaged concepts merged"`
  and push. Confirm push succeeded — do not leave it for Matt to chase (global CLAUDE.md rule: "Always push the code.").
- **Verify**: `git log --oneline origin/main | head -3` shows both Phase A and Phase B commits pushed. `git status` is
  clean.
- **Complexity**: Small

## Test Strategy

### Automated Tests

Skills are prompts, not executable code — there are no unit tests to write. Verification is entirely structural
(file-content greps) and behavioural (live skill invocation in a Claude Code session). All structural checks are
enumerated inline in Steps A.2 and B.3.

| Test Case | Type | Input | Expected Output |
|---|---|---|---|
| `SKILL.md` frontmatter has `name: pr-preflight` | Structural | `grep "^name: pr-preflight" pr-preflight/SKILL.md` | 1 match |
| `SKILL.md` contains all 5 agent names | Structural | grep for Correctness/Reuse/Quality/Efficiency/Security | 5+ matches |
| `SKILL.md` contains all 4 severity labels | Structural | grep for CRITICAL/SIGNIFICANT/MODERATE/MINOR | 4+ matches |
| `SKILL.md` has no `gh pr review --comment` | Structural | `grep -c "gh pr review --comment"` | 0 |
| `SKILL.md` has no `intent.md` reference | Structural | `grep -c "intent\.md"` | 0 |
| `review/` directory is gone | Structural | `test -d skills/review` | exit 1 (false) |
| `README.md` has pr-preflight row, no review row | Structural | two grep calls | 1 and 0 |

### Manual Verification

- [ ] **Step A.3 live smoke test**: in a fresh Claude Code session, start in a repo with a non-empty diff vs
      `origin/main`, invoke `/pr-preflight`, confirm the report structure renders correctly and all five agents run.
- [ ] **Step B.4 post-delete breakage sweep**: in a fresh Claude Code session, confirm `/review` is gone, `/pr-preflight`
      is present, and the RPI-wired skills (`/reviewing-code`, `/security-review`) and agents (`code-reviewer`,
      `security-reviewer`) are unchanged and still load.
- [ ] **End-to-end acceptance**: after both phases are pushed, start a fresh session, run `/pr-preflight` on a real
      branch that Matt is about to push, and confirm the output is useful enough to drive a go/no-go push decision.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Accidentally touching an RPI-wired file (`reviewing-code/`, `security-review/`, `code-reviewer.md`, `security-reviewer.md`) | Breaks automated RPI review gates in every subsequent RPI run | Plan explicitly enumerates these as OUT OF SCOPE. Step B.4 verifies they're byte-unchanged via `git diff HEAD -- agents/` and equivalent. |
| Undiscovered programmatic reference to `/review` that research missed | `/review` invocations break silently after deletion | Step B.1 re-runs the reference sweep just before deletion. If any new programmatic reference surfaces, STOP and escalate before Step B.2. |
| `pr-preflight` prompt drifts from the bot prompt over time, causing local vs. GitHub output divergence | Matt gets different advice locally than the bot will give on the PR | SKILL.md explicitly cites its source (`analytics/.github/workflows/claude.yml` lines 43–143). Future drift is a retro item, not a plan item. Out of scope here. |
| The five-agent parallel dispatch is slow or expensive | Matt stops using the skill | Matches the bot's existing pattern exactly (four agents + security-as-fifth). If performance becomes an issue, it's a tuning item for a future retro. Not a blocker for first cut. |
| The Security agent (new fifth axis) overlaps with the RPI `security-reviewer` agent in Matt's mental model | Confusion about which to run when | SKILL.md's "Scope guardrails" section explicitly states: RPI `security-reviewer` runs during implementation; `pr-preflight`'s Security agent runs pre-push as part of the bot-mirror check. Different timing, different phase. |
| README.md alphabetical ordering error | Cosmetic | Verification check in Step B.3 includes visual inspection. |
| `/review` deletion creates a broken backreference in `retro/SKILL.md` line 28 (the one prose mention research found) | None — it's prose ("same quality checks the PR review agent uses"), not an invocation | No mitigation needed, but Step B.1 re-confirms this is still only a prose mention. If the line is updated elsewhere to a programmatic reference, treat as a new programmatic reference per the row above. |

## Rollback Strategy

Low-stakes change; full rollback is a single `git revert` of the Phase A + Phase B commits (or two reverts if split).
The deleted `review/` directory is fully recoverable from git history (`git show HEAD~N:skills/review/SKILL.md`, etc.).
The new `pr-preflight/` directory is removable via `rm -rf skills/pr-preflight` plus a revert of the README edit. No
external systems, databases, or services are affected.

If only one half needs to revert (e.g. `pr-preflight` ships fine but README got mangled), a targeted `git checkout HEAD~1 -- README.md` from before the bad edit restores it without touching the skill.

## Status

- [x] Plan approved
- [x] Implementation started (Phase A complete 2026-04-17)
- [x] Implementation complete (Phase A commit a1d6dea + Phase B 2026-04-17)
