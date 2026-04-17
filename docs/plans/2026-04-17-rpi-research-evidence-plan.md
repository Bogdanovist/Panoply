# Plan: rpi-research-evidence (2026-04-17)

## Summary

Extend the Research phase of the `research-plan-implement` (RPI) pipeline so that research subagents can (and, where
appropriate, do) gather *runtime evidence* — query results, log excerpts, CLI output — alongside static source-code
analysis, and so that downstream consumers (the synthesiser and the planner) can distinguish unverified inferences
from confirmed observations. The change is delivered as targeted edits to four skill files in `~/.claude/skills/`
using a lightweight inline tagging convention (`[INFERRED]` / `[OBSERVED]`) and leaves the pipeline's subagent
topology unchanged — no new subagent is introduced. The `codebase-researcher` prompt and the `researching-codebase`
skill absorb the new state-inspection guidance; the `synthesizing-research` template surfaces evidence type; and
`writing-plans` gains a small rule that tells the planner to insert a verification step before any implementation
step that depends on an `[INFERRED]` research finding.

## Stakes Classification

**Level**: Low

**Rationale**: All edits are to guidance documents under `~/.claude/skills/`. No production code, no tests, no
user-facing behaviour. The changes influence how *future* RPI runs behave, so clarity and cross-file consistency
matter — but any mistake is correctable by a follow-up edit with zero blast radius. The Stop hook's auto-commit/push
provides rollback-via-revert if needed.

## Branch / PR Strategy

**Single commits to `main`.** This is the user's `.claude/` configuration directory; an auto-commit/push hook fires
after each response. There is no feature branch, no sub-PR, and no review gate between phases. Each phase produces
its own commit(s) through the normal Stop-hook flow. If any phase introduces an inconsistency that a later phase
exposes, fix forward in that later phase — do not rewrite history.

## Context

**Research**: [`docs/plans/2026-04-17-rpi-research-evidence-research.md`](./2026-04-17-rpi-research-evidence-research.md)

**Affected files** (no others):

- `/Users/matthumanhealth/.claude/skills/researching-codebase/SKILL.md` — Phase 2 Exploration, Phase 3 output
  template
- `/Users/matthumanhealth/.claude/skills/synthesizing-research/SKILL.md` — Step 2 checklist, Step 3 canonical themes,
  Step 4 consolidated-document template and Sources table
- `/Users/matthumanhealth/.claude/skills/research-plan-implement/SKILL.md` — Phase 1 Step 1 question defaults, Step 2
  `codebase-researcher` prompt extension
- `/Users/matthumanhealth/.claude/skills/writing-plans/SKILL.md` — one small subsection on `[INFERRED]` handling

**Hard constraints carried through from the user's request:**

1. Tagging is lightweight inline prose markers `[INFERRED]` / `[OBSERVED]`. No structured metadata block.
2. NO new subagent. The existing `codebase-researcher` absorbs the new optional state-inspection guidance.
3. `writing-plans` gets a *single* focused addition — a subsection or bullet list — not a rewrite.
4. Where state inspection is described, use concrete examples from three domains — **data pipelines**, **production
   services**, and **CLI / local tools** — as a short bullet list.
5. All existing technical names (skill names, section headings, prompt strings, template fields) are preserved. No
   inventing.

## Success Criteria

- [ ] `researching-codebase` Phase 2 exposes a clearly-titled "Runtime Evidence" capability alongside the existing
  static exploration steps, enumerating the three domains (data pipelines, production services, CLI / local tools)
  as concrete examples.
- [ ] `researching-codebase` Phase 3 output template includes a section for runtime observations and instructs the
  researcher to tag findings inline as `[INFERRED]` or `[OBSERVED]`.
- [ ] `synthesizing-research` themes, checklist, consolidated-document template, and Sources table all preserve
  evidence type through synthesis — the `[INFERRED]` / `[OBSERVED]` distinction is not erased when multiple research
  files are merged.
- [ ] `research-plan-implement` Step 1 question defaults include a runtime/observed-behaviour category; the
  `codebase-researcher` prompt tells the subagent that state inspection is an option when appropriate and points to
  the new `researching-codebase` guidance.
- [ ] `writing-plans` instructs the planner that when research contains `[INFERRED]` findings on which an
  implementation step depends, the planner must insert a verification step (run code / query data / read logs)
  *before* the dependent implementation step.
- [ ] No existing technical name (skill name, prompt text that is structurally referenced elsewhere, template
  heading referenced cross-file) is renamed or removed.
- [ ] Every edited file remains valid Markdown and renders coherently top-to-bottom.

## Implementation Steps

---

### Phase 1: Extend `researching-codebase/SKILL.md` with state-inspection methodology

**Execution**

- **Scope**: Add runtime-evidence guidance to Phase 2 (Exploration) and an evidence-type tagging convention plus a
  runtime-observations section to Phase 3 (Document Findings) of `researching-codebase/SKILL.md`.
- **Depends on**: none
- **Parallel with**: none (sequential — all four phases touch skill files whose consistency must be preserved;
  parallel edits risk contradicting each other)
- **Gate**: autonomous. Rationale: pure documentation edit to a low-stakes guidance file; the user's Stop hook
  auto-commits; any issue surfaces in later phases that cross-reference this file and is fixed forward there.

#### Step 1.1: Add "Gather Runtime Evidence" subsection to Phase 2 Exploration

- **File**: `/Users/matthumanhealth/.claude/skills/researching-codebase/SKILL.md`
- **Location**: Insert a new subsection inside Phase 2 (currently lines 59–145), positioned *after* "Deepen
  Understanding with LSP" (ends ~line 117) and *before* "Research External Context (When Needed)" (starts ~line
  119). This keeps static exploration (file-finder → read → LSP) grouped, then runtime, then external web.
- **Action**: Add a new `### Gather Runtime Evidence (When Applicable)` subsection containing:
  1. One short framing sentence stating that code reading alone cannot answer questions about *what the system
     currently does at runtime* — data shape, log volume, CLI output — and that runtime evidence complements static
     analysis for those questions.
  2. A short bullet list of concrete domain examples (this is the user-mandated domain enumeration):
     - **Data pipelines**: query data assets directly (e.g. `bq query`, `duckdb`, a notebook cell), inspect table
       schemas, sample a handful of rows, check row counts and null distributions.
     - **Production services**: tail or grep recent logs, inspect a running endpoint's response, check a health or
       metrics endpoint, look at structured log output for a representative request.
     - **CLI / local tools**: run the binary with a representative input, capture stdout and stderr, check the exit
       code and any files the tool produces.
  3. One sentence on restraint: runtime evidence gathering is opt-in, scoped to the question at hand, and must not
     mutate shared state (read-only queries, no destructive commands).
  4. One sentence linking forward to Phase 3's tagging convention: findings confirmed by runtime evidence are tagged
     `[OBSERVED]`; findings inferred from static analysis only are tagged `[INFERRED]`.
- **Verify**:
  - The new subsection heading is `### Gather Runtime Evidence (When Applicable)` (exact heading — cross-referenced
    from Step 3.2 of Phase 3).
  - The three domain bullets appear as a single bullet list, in the order above.
  - No existing subsection is renamed or reordered (LSP and web-research subsections remain intact).
  - File still parses as Markdown (headings hierarchy `## Phase 2: Exploration` → `### Gather Runtime Evidence (When
    Applicable)` is consistent with neighbours).
- **Complexity**: Small

#### Step 1.2: Add `[INFERRED]` / `[OBSERVED]` tagging guidance and "Runtime Observations" section to Phase 3 template

- **File**: `/Users/matthumanhealth/.claude/skills/researching-codebase/SKILL.md`
- **Location**: Phase 3 Document Findings (lines 146–194). Two edits:
  1. A short prose paragraph **before** the fenced code block at line 152 explaining the inline tagging convention.
  2. A new `### Runtime Observations` section **inside** the fenced template, placed between `### Existing Patterns`
     and `### Dependencies` (so static discussion → observed behaviour → dependencies → external → constraints is
     the reading order).
- **Action**:
  1. Insert a short paragraph (2–3 sentences) before the template fence that instructs the researcher to tag each
     finding inline: `[OBSERVED]` when the claim is backed by runtime evidence captured during Phase 2 (query
     output, log excerpt, CLI stdout); `[INFERRED]` when the claim is read off source code without runtime
     confirmation. Tags go at the start of the bullet or sentence making the claim, e.g.
     `[INFERRED] The retry logic appears to use exponential backoff based on src/api/retry.ts:42-57.` Examples
     belong in prose, not in the template fence.
  2. Inside the fenced template, add a new section:
     ```markdown
     ### Runtime Observations

     [Evidence captured by running code, querying data, or reading logs
     during exploration. Each entry records the command or query run,
     the raw (trimmed) output, and the conclusion drawn. Tag each
     conclusion [OBSERVED].]
     ```
     Place this block between the existing `### Existing Patterns` and `### Dependencies` blocks.
- **Verify**:
  - The new prose paragraph mentions both `[INFERRED]` and `[OBSERVED]` exactly once (as the canonical tag
    introduction).
  - The template fence contains a `### Runtime Observations` section positioned between `### Existing Patterns` and
    `### Dependencies`.
  - No other template section heading (`### Relevant Files`, `### Existing Patterns`, `### Dependencies`,
    `### External Research`, `### Technical Constraints`) is renamed or removed.
  - The surrounding fence (` ```markdown` open / ` ``` ` close) still balances.
- **Complexity**: Small

**Phase 1 checkpoint verification**

- [ ] Re-read `researching-codebase/SKILL.md` top to bottom. Heading outline is unchanged except for the two
  additions.
- [ ] Search the file for `[INFERRED]` and `[OBSERVED]` — each appears at least once, in Phase 3 tagging prose.
- [ ] Search the file for the three domain keywords (`data pipelines`, `production services`, `CLI`) — all three
  appear in the Phase 2 runtime-evidence subsection.
- [ ] No broken intra-file link (the only internal anchor-style reference is heading-name-based — confirm the
  section names referenced in Phase 3's tagging paragraph match the Phase 2 subsection title exactly).

---

### Phase 2: Thread evidence-type awareness through `synthesizing-research/SKILL.md`

**Execution**

- **Scope**: Teach the synthesiser to (a) notice evidence-type tags in source research files, (b) preserve them
  through theme-based reorganisation, (c) surface an `Evidence Type` column in the Sources table, and (d) expose a
  "Runtime Evidence" theme when warranted.
- **Depends on**: Phase 1 (the tagging convention `[INFERRED]` / `[OBSERVED]` is defined in
  `researching-codebase/SKILL.md` — the synthesiser must point at the same vocabulary).
- **Parallel with**: none (sequential with Phases 1, 3, 4).
- **Gate**: autonomous. Rationale: pure documentation edit; consistency with Phase 1 verified by cross-reading, not
  by a test harness.

#### Step 2.1: Add evidence-type note to Step 2 "Read All Source Files" checklist

- **File**: `/Users/matthumanhealth/.claude/skills/synthesizing-research/SKILL.md`
- **Location**: Step 2 (currently lines 30–37, with the bulleted "Note:" list at lines 32–37).
- **Action**: Add one bullet to the existing list (immediately after "Confidence levels stated by each researcher"):
  `- Evidence type markers ([OBSERVED] backed by runtime evidence; [INFERRED] read off source only)`
  Then add a short sentence below the list (one line) stating that the synthesis must preserve these tags — it must
  not silently upgrade `[INFERRED]` claims to unqualified statements just because multiple researchers repeat them.
- **Verify**:
  - The bullet `Evidence type markers ([OBSERVED] backed by runtime evidence; [INFERRED] read off source only)`
    appears in the Step 2 bullet list.
  - The preservation sentence appears immediately after the list and before Step 3.
  - No existing bullet is removed or reordered.
- **Complexity**: Small

#### Step 2.2: Add "Runtime Evidence" theme to Step 3 canonical theme list

- **File**: `/Users/matthumanhealth/.claude/skills/synthesizing-research/SKILL.md`
- **Location**: Step 3 "Organize by Theme", canonical themes list (currently lines 46–51).
- **Action**: Add one bullet to the themes list, positioned after "Data flow and state management":
  `- Runtime evidence and observed behaviour (query outputs, log excerpts, CLI output)`
  The existing "Data flow and state management" bullet remains — it is *code-level* state, the new bullet is
  *observed* state; keeping both makes the distinction explicit.
- **Verify**:
  - The new theme bullet appears in the list exactly as worded above.
  - The original six themes remain present and in their original relative order.
  - The paragraph above the list ("Restructure findings by theme, NOT by source…") is unchanged.
- **Complexity**: Small

#### Step 2.3: Add runtime-evidence section and evidence-type column to Step 4 consolidated-document template

- **File**: `/Users/matthumanhealth/.claude/skills/synthesizing-research/SKILL.md`
- **Location**: Step 4 consolidated-document template (lines 59–102). Two edits to the fenced template:
  1. Add a `## Runtime Evidence` top-level section placed between `## Findings` and `## External Research`.
  2. Extend the Sources table (currently `| Document | Researcher | Focus Area |`, lines 97–101) to add an
     `Evidence Type` column.
- **Action**:
  1. Insert the following block between the `## Findings` block and the `## External Research` block:
     ```markdown
     ## Runtime Evidence

     [Observations captured by running code, querying data, or reading
     logs during research. Each entry names the command or query, the
     trimmed raw output, and the conclusion drawn. Claims elsewhere in
     this document that are backed by an entry here are tagged
     [OBSERVED]; claims not backed by runtime evidence are tagged
     [INFERRED].]
     ```
  2. Replace the Sources table header and example row with:
     ```markdown
     | Document | Researcher | Focus Area | Evidence Type |
     | -------- | ---------- | ---------- | ------------- |
     | [path]   | [agent]    | [scope]    | [static | runtime | mixed] |
     ```
     Use the three values `static`, `runtime`, `mixed` (lowercase) — `static` for a research file containing only
     `[INFERRED]` findings, `runtime` for only `[OBSERVED]`, `mixed` for both.
- **Verify**:
  - The template fence now contains, in order: Problem Statement, Requirements, Findings, **Runtime Evidence**,
    External Research, Technical Constraints, Open Questions, Recommendations, Sources.
  - The Sources table has exactly four columns: Document, Researcher, Focus Area, Evidence Type.
  - The example row uses the `[static | runtime | mixed]` placeholder syntax (square-bracketed, pipe-separated) to
    signal these are the only accepted values.
  - The fence opens with ` ```markdown` and closes with ` ``` ` — balance is preserved.
  - No other section is renamed or removed.
- **Complexity**: Small

**Phase 2 checkpoint verification**

- [ ] Re-read `synthesizing-research/SKILL.md` top to bottom. The three edits are the only changes.
- [ ] `[INFERRED]` and `[OBSERVED]` appear in at least one of Step 2, Step 3, Step 4 — vocabulary matches Phase 1.
- [ ] The Sources-table column count is consistent between the header row, the separator row, and the example row
  (4 columns each).
- [ ] No technical name referenced elsewhere is changed. In particular, the *skill name* `synthesizing-research` and
  the *section names* `## Findings`, `## External Research`, `## Sources` are untouched (only added-to).

---

### Phase 3: Extend `research-plan-implement/SKILL.md` question defaults and codebase-researcher prompt

**Execution**

- **Scope**: Add a runtime/observed-behaviour category to Phase 1 Step 1's question defaults, and extend the
  `codebase-researcher` prompt in Step 2 so the subagent knows state inspection is an option governed by the new
  guidance in `researching-codebase`. Explicitly do NOT add a new subagent to the Additional subagents block.
- **Depends on**: Phase 1 (the `researching-codebase` skill contains the methodology the prompt extension points
  to) and Phase 2 (the synthesiser understands the tags the codebase-researcher will emit).
- **Parallel with**: none.
- **Gate**: autonomous. Rationale: pure documentation edit; changes affect future pipeline runs only; fix-forward
  is cheap.

#### Step 3.1: Add runtime/observed-behaviour category to Step 1 question defaults

- **File**: `/Users/matthumanhealth/.claude/skills/research-plan-implement/SKILL.md`
- **Location**: Phase 1 Step 1 "Define Research Questions" defaults (lines 72–77).
- **Action**: Add a fourth bullet after the existing three:
  `- **Observed behaviour**: What does the system actually do at runtime today — query outputs, log patterns, CLI output?`
  The lead-in sentence ("Typically 2-3 questions…") is updated to "Typically 2-4 questions…" to accommodate the
  added category without forcing inclusion.
- **Verify**:
  - The four question categories — Codebase context, External context, Security/performance, Observed behaviour —
    appear in that order.
  - The lead-in sentence count range is "2-4".
  - No other content in Step 1 is changed.
- **Complexity**: Small

#### Step 3.2: Extend the codebase-researcher prompt with optional state-inspection guidance

- **File**: `/Users/matthumanhealth/.claude/skills/research-plan-implement/SKILL.md`
- **Location**: Phase 1 Step 2 "Codebase researcher" prompt block (lines 85–98, i.e. the fenced `text` block that
  opens with `Spawn a subagent with the Agent tool:` and contains the `prompt: "Research …"` string).
- **Action**: Extend the existing numbered list inside the `prompt:` string to include a new item between the
  current item 2 ("Follow the skill's full methodology…") and the current item 3 ("Write your findings to…"). The
  new item reads:
  ```
  3. Where the research question concerns current runtime behaviour
     (data shape, log patterns, CLI output), gather runtime evidence
     per the 'Gather Runtime Evidence (When Applicable)' subsection
     of the researching-codebase skill. Tag findings inline
     [OBSERVED] (backed by runtime evidence) or [INFERRED] (read
     off source only).
  ```
  The existing item 3 (write-to-file) becomes item 4. Keep the prompt string's outer quoting and indentation
  consistent with the current block.
- **Verify**:
  - The prompt now has 4 numbered items, in the order: invoke skill → follow methodology → (new) gather runtime
    evidence when applicable → write findings.
  - The reference to the `researching-codebase` subsection heading (`Gather Runtime Evidence (When Applicable)`)
    matches the exact heading added in Phase 1 Step 1.1.
  - The surrounding fenced code block still closes cleanly.
  - The web-researcher prompt block (lines 100–111) and the Additional subagents block (lines 113–122) are
    unchanged — in particular, no `state-researcher` is added.
- **Complexity**: Small

#### Step 3.3: Verify the Additional subagents block is untouched and add a one-line orientation note

- **File**: `/Users/matthumanhealth/.claude/skills/research-plan-implement/SKILL.md`
- **Location**: Step 2 "Additional subagents" fenced block and its surrounding prose (lines 113–126, including the
  `> Note` callout about `isolation: "worktree"`).
- **Action**: Do **not** add a new subagent. Add a single-sentence orientation note immediately before the
  Additional subagents fenced block (after the web-researcher block's closing fence, before the `Additional
  subagents (when needed):` heading line). The sentence:
  `Note: state inspection is NOT a separate subagent — the codebase-researcher above handles it via the runtime-evidence subsection of researching-codebase.`
  This prevents a future edit from "naturally" adding a `state-researcher` and closes the topology question the
  research document flagged as Open Question 2.
- **Verify**:
  - The Additional subagents fenced block itself is byte-for-byte identical to the original (still shows
    `security-researcher` as the sole example).
  - The one-sentence orientation note appears immediately before the "Additional subagents (when needed):" line.
  - No new subagent name (e.g. `state-researcher`, `runtime-researcher`) appears anywhere in the file.
- **Complexity**: Small

**Phase 3 checkpoint verification**

- [ ] Re-read `research-plan-implement/SKILL.md` top to bottom focusing on Phase 1. The three edits are the only
  changes.
- [ ] Grep the file for `state-researcher` and `runtime-researcher` — zero matches.
- [ ] Grep the file for `Gather Runtime Evidence` — matches exist, and the referenced subsection exists with
  identical wording in `researching-codebase/SKILL.md` (confirm by opening both files side-by-side).
- [ ] Fenced code blocks still balance (open/close pairs).

---

### Phase 4: Add `[INFERRED]` handling to `writing-plans/SKILL.md`

**Execution**

- **Scope**: Add one focused subsection to `writing-plans/SKILL.md` instructing the planner that when a research
  document contains `[INFERRED]` findings on which an implementation step depends, the planner must insert a
  verification step (run code / query data / read logs) *before* the dependent implementation step.
- **Depends on**: Phase 1 (tagging convention exists), Phase 2 (synthesis preserves tags into the research doc the
  planner reads).
- **Parallel with**: none.
- **Gate**: autonomous. Rationale: single-paragraph documentation edit to a guidance file with no code dependents
  and no tests. The user's request explicitly states Phase 4 is also autonomous — calling that out here so the
  orchestrator does not invent a gate.

#### Step 4.1: Add "Handling `[INFERRED]` findings from research" subsection

- **File**: `/Users/matthumanhealth/.claude/skills/writing-plans/SKILL.md`
- **Location**: Insert a new subsection inside Section 4 "Break Down Tasks", positioned *after* "Plan test cases for
  each task" (ends around line 145, just before the `#### Good Task Examples` heading at line 147). This keeps
  test-planning guidance adjacent to verification-step guidance — both are about proving a step worked before moving
  on.
- **Action**: Add this block (heading plus one paragraph plus a short bullet list):
  ```markdown
  #### Handling `[INFERRED]` findings from research

  If the research document tags a finding `[INFERRED]` (read off source
  code without runtime confirmation) and an implementation step depends
  on that finding being true, insert a verification step immediately
  before the dependent step. The verification step runs code, queries
  data, or reads logs to confirm the inferred claim. Findings tagged
  `[OBSERVED]` are already backed by runtime evidence and do not need a
  verification step.

  Concrete forms the verification step can take, by domain:

  - **Data pipelines**: query the relevant table or asset, inspect
    schema, sample rows, compare actual shape against the inferred
    shape.
  - **Production services**: hit the relevant endpoint or tail logs for
    a representative request; confirm the inferred behaviour appears in
    the output.
  - **CLI / local tools**: run the binary with a representative input;
    capture stdout/stderr and the exit code; compare against the
    inferred behaviour.

  If verification contradicts the inferred claim, stop and return to
  research — do not patch over a broken assumption in the plan.
  ```
- **Verify**:
  - The new subsection appears exactly once, inside Section 4, between "Plan test cases for each task" and "Good
    Task Examples".
  - The heading is level `####` (matching neighbouring subsection levels in Section 4 — `#### Good Task Examples`,
    `#### Bad Task Examples`).
  - Both `[INFERRED]` and `[OBSERVED]` appear in the paragraph.
  - The three-domain bullet list (data pipelines, production services, CLI / local tools) is present, in that
    order, matching the vocabulary used in `researching-codebase/SKILL.md` (Phase 1 of this plan).
  - The closing "If verification contradicts…" sentence is present — this is the no-silent-patching rule the
    research document's Open Question 4 called out.
  - No existing section in `writing-plans/SKILL.md` is modified beyond the insertion.
- **Complexity**: Small

**Phase 4 checkpoint verification**

- [ ] Re-read `writing-plans/SKILL.md` top to bottom. The one insertion is the only change.
- [ ] Grep the file for `[INFERRED]` — exactly one match (the new subsection); before this edit, there were zero.
- [ ] The three domain names match verbatim across `researching-codebase/SKILL.md` and `writing-plans/SKILL.md`
  (Phase 1 Step 1.1 and Phase 4 Step 4.1 must use the same three strings: "Data pipelines", "Production services",
  "CLI / local tools" — with any difference flagged and reconciled).

---

## Cross-Phase Consistency Checks

After Phase 4 completes, before declaring the plan done, run these read-throughs:

- [ ] **Vocabulary check.** Open all four edited files. Confirm `[INFERRED]` / `[OBSERVED]` are the only two
  evidence-type tag strings used, and that they appear verbatim in all four files.
- [ ] **Domain-list check.** Confirm "data pipelines", "production services", and "CLI / local tools" appear as the
  three-domain enumeration in both `researching-codebase/SKILL.md` (Phase 1) and `writing-plans/SKILL.md`
  (Phase 4). Minor wording variation is allowed between the two files but the three *domains* must be the same.
- [ ] **Name-preservation check.** No renamed skill, no renamed section heading referenced cross-file, no
  introduced subagent name. Specifically `codebase-researcher`, `web-researcher`, `synthesizer`, `planner`, and
  `implementer-<phase-slug>` are unchanged; no `state-researcher` or `runtime-researcher` exists anywhere.
- [ ] **Markdown parse check.** Each edited file opens cleanly when viewed as Markdown — no stray fences, no
  unbalanced code blocks, heading hierarchy sensible.

## Test Strategy

### Automated Tests

No automated tests. All changes are to Markdown skill-guidance files; there is no test harness for
`~/.claude/skills/`.

### Manual Verification

- [ ] Read each of the four edited files end-to-end and confirm the edits appear as specified above.
- [ ] Run a `grep -n "state-researcher\|runtime-researcher" ~/.claude/skills/` check to confirm no new subagent name
  was introduced anywhere.
- [ ] Run a `grep -n "\[INFERRED\]\|\[OBSERVED\]" ~/.claude/skills/` check to confirm the tag vocabulary appears in
  all four edited files.
- [ ] Render each file in a Markdown viewer (or `glow` / editor preview) and confirm no broken formatting.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| ---- | ------ | ---------- |
| Heading added in Phase 1 is referenced by Phase 3 prompt with a typo mismatch | Phase 3 prompt points at a non-existent subsection | Phase 3 checkpoint verifies the cross-file heading match before completion |
| Sources-table column count goes out of sync (header / separator / example row) | Table renders broken in synthesis output | Phase 2 Step 2.3 "Verify" explicitly checks column-count consistency |
| Future edit naturally adds a `state-researcher` subagent, undoing the topology decision | Pipeline bloat; prompt divergence | Phase 3 Step 3.3 adds an explicit one-sentence orientation note pre-empting this |
| `writing-plans` addition grows into a rewrite | Violates scope constraint; planner behaviour changes unpredictably | Phase 4 hard-caps the edit at one subsection with bullet list; checkpoint verifies no other section is touched |
| Vocabulary drift between files (e.g. "runtime-observed" vs "observed" vs `[OBSERVED]`) | Synthesiser and planner use different matchers; tags get stripped silently | Cross-Phase Consistency Check "Vocabulary check" catches this before done |
| Tagging format confuses consumers of legacy research docs (pre-existing docs have no tags) | Synthesiser treats untagged findings ambiguously | No mitigation needed at file level — the tag convention is additive; untagged findings remain untagged and are treated as they were before. The research document's Open Question 5 (backward compatibility) is therefore preserved by design. |

## Rollback Strategy

Each phase's edits are a self-contained set of commits on `main` (via the Stop hook's auto-commit). If any phase
produces a bad outcome:

- **Immediate fix**: edit forward — the same file, same section, apply a corrective edit in a new commit. This is
  almost always preferable.
- **Full revert**: `git revert <commit-sha>` for the phase's commit(s). Clean, no history rewrite, preserves the
  audit trail.
- **Nuclear** (only if edits cross-contaminate): `git revert` each phase's commits in reverse order
  (Phase 4 → Phase 3 → Phase 2 → Phase 1). The four phases are designed to revert cleanly in reverse order because
  later phases reference earlier phases' additions but do not modify them in place.

No destructive git operations (`reset --hard`, `push --force`) are warranted or permitted by this plan.

## Open Issues

None. The user's request and the research document together define the full scope; no genuine contradiction
surfaced during planning.

A noteworthy non-issue: the research document's Open Question 2 ("Who triggers state inspection? Same subagent or
separate?") was resolved *by the user's hard constraint* that no new subagent is introduced. Phase 3 Step 3.3
records that decision explicitly in the skill file so it does not have to be rediscovered later.

## Status

- [x] Plan approved
- [x] Phase 1 complete (researching-codebase Phase 2 + Phase 3 template)
- [x] Phase 2 complete (synthesizing-research checklist + themes + template + Sources table)
- [x] Phase 3 complete (research-plan-implement question defaults + codebase-researcher prompt + orientation note)
- [x] Phase 4 complete (writing-plans `[INFERRED]` handling subsection)
- [x] Cross-phase consistency checks pass
- [x] Implementation complete
