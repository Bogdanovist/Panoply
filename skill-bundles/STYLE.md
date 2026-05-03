# Skill Authoring Style Rules

Every SKILL.md is loaded into a fresh subagent context on invocation. Prose that restates the frontmatter, ceremonial code fences, or content duplicated in another skill all pay token cost every single run. These eight rules keep the corpus lean without sacrificing the guidance that actually drives behaviour.

## 1. No "Purpose" opener paragraphs

The frontmatter `description` is read by the Skill tool before the body is processed. A paragraph that restates it is pure duplication.

- **Why**: The description is already in context.
- **How to check**: The first non-frontmatter line should be meaningful — a `##` heading or a sentence that adds information the description doesn't.

## 2. No code fences for agent invocations

Task-tool / Agent-tool invocations for `file-finder`, `web-researcher`, etc. are known patterns. A 5-line code fence per invocation adds visual weight without information.

- **Why**: Any agent can spawn a subagent from a prose sentence; the fence teaches nothing.
- **How to check**: Replace each fence with a sentence like "Spawn a `file-finder` agent with the goal and topic."

## 3. Single canonical home per rule

If a rule, table, or contract appears in two skills, pick one as canonical and have the other cite it by name. Duplicated rules drift.

- **Why**: Maintenance burden + inconsistency risk + token cost.
- **How to check**: Before writing a rule, grep the skill corpus for its title. If it exists, cite it.

## 4. Anti-Patterns sections: non-obvious reversals only

Wrong/Right pairs earn their tokens when the correct behaviour is counterintuitive. Pairs that restate a nearby checklist item are waste.

- **Why**: Reader already saw the positive form above.
- **How to check**: For each anti-pattern, ask "would a reader who just read the checklist actually do this wrong?" If no, cut it.

## 5. No prose + fence duplication

If a step is explained in prose then wrapped in a `text` code fence showing the same content, the fence is waste.

- **Why**: Same content, twice, for one idea.
- **How to check**: If the fence body is a paraphrase of the surrounding prose, delete the fence.

## 6. `review_group` shapes table lives in `writing-plans` §4a only

Other skills that reference the Solo / Batched-sequential / Fan-out+consolidator shapes cite `writing-plans §4a` — they do not reproduce the table.

- **Why**: Canonical home per rule 3; the table is non-trivial and drifts when duplicated.
- **How to check**: `grep -r "Batched sequential" skills/ | grep -v writing-plans` should return zero matches of the full table — only cross-references.

## 7. Verbosity budget on research deliverables

Research docs feed into planner context. Capping them at ≤200 lines (guidance, not hard cap) compounds to meaningful savings across multi-researcher runs. "Include everything decision-critical, omit exploratory notes and raw file listings."

- **Why**: Unbounded research docs inflate planner context for no quality gain.
- **How to check**: `researching-codebase` and `synthesizing-research` quality criteria and every research-subagent spawn prompt should include the ≤200-line guidance.

## 8. Process steps as checklists, not numbered paragraphs

"Step N: [verb]" with paragraph breaks adds ~20 lines of whitespace-heavy structure. Checklist bullets suffice for sequential-but-not-branching logic.

- **Why**: Step-numbered prose inflates line count without aiding comprehension.
- **How to check**: If your step headings are followed by single-paragraph bodies, merge them into a checklist.
