# RPI Token Audit: External Research Findings
**Date:** 2026-04-21 | **Scope:** Claude Code multi-agent/RPI token optimization

---

## Anthropic-Documented Best Practices [ESTABLISHED]

### 1. Prompt Caching — Structure and TTLs
Source: [Anthropic Prompt Caching Docs](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching)

- Two TTL tiers: **5-minute** (default, no extra cost beyond write premium) and **1-hour** (2× base write cost). Use 1h TTL when pipeline steps exceed 5 minutes — exactly the RPI research→plan→implement gap.
- Cache hierarchy: `tools` → `system` → `messages`. Any change at a level invalidates that level and all downstream. Changing tool definitions nukes the entire cache.
- **Critical ordering rule**: `cache_control` must go on the **last block that stays identical across requests**. Static content before dynamic content. System prompt → document → then per-turn user message. Placing the breakpoint on a timestamp or turn-specific content causes 100% miss rate.
- Up to **4 cache breakpoints** per request; use them to cache tools, static system instructions, and large documents independently.
- **Concurrent request hazard**: a cache entry only becomes available after the first response *begins*. Parallel subagents firing simultaneously into a cold cache all miss. Serialize the first call, then fan out.
- Minimum cacheable size varies by model: Opus 4.x = 4,096 tokens; Sonnet 4.6 = 2,048 tokens. Below threshold, caching is silently skipped — verify via `cache_creation_input_tokens`.
- Cache reads cost ~10% of normal input token price; writes cost ~125% (5-min TTL). High-hit workloads see up to 90% cost reduction.

### 2. Subagent Delegation and Context Isolation
Source: [Claude Code Sub-Agents Docs](https://code.claude.com/docs/en/sub-agents) | [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)

- Each subagent gets its own fresh context window. Verbose output (logs, grep results, docs fetches) stays in the subagent's window; only the summary returns to the orchestrator.
- **Decision heuristic (Anthropic's own wording):** "Will I need this tool output again, or just the conclusion?" If just the conclusion, use a subagent.
- MCP tool definitions are **deferred by default** — only tool names enter context until Claude actually invokes a tool. Avoids bloating every request with hundreds of schema tokens.
- CLI tools (`gh`, `aws`, `gcloud`) are more context-efficient than MCP servers because they add zero per-tool listing.

### 3. Model Routing
Source: [Claude Code Costs Docs](https://code.claude.com/docs/en/costs) | [Anthropic Multi-Agent Research](https://www.anthropic.com/engineering/multi-agent-research-system)

- Official guidance: Sonnet for most coding tasks; Opus for complex architectural decisions or multi-step reasoning; specify `model: haiku` in subagent config for simple lookup/verification tasks.
- Anthropic's internal research system: Opus 4 orchestrator + Sonnet 4 subagents outperformed single-agent Opus 4 by 90.2%. "Upgrading to Claude Sonnet 4 is a larger performance gain than doubling the token budget on Claude Sonnet 3.7."
- Advisor tool (public beta): pairs a faster executor with a high-intelligence advisor model mid-generation. Near-advisor-solo quality at executor-model token rates.

### 4. Context Management Commands
Source: [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | [Claude Code Costs Docs](https://code.claude.com/docs/en/costs)

- `/compact <instructions>`: summarize and continue. Compaction quality degrades the longer it's deferred — model is at its "least intelligent point" when at 95% context. Compact proactively with explicit focus instructions.
- `/clear`: full reset. Best practice: before clearing, write a structured recap (decisions, file list, TODOs, what failed) to a file. Reload that file in the next session instead of re-explaining.
- `/btw`: side question that never enters conversation history. Zero context cost for one-off lookups.
- Custom compaction instructions in CLAUDE.md: `"When compacting, always preserve the full list of modified files and any test commands"` — survives the summarization pass.
- Auto-compaction triggers at ~95% fill. `/compact` mid-session is always better than waiting for it.

### 5. CLAUDE.md and Skills Token Economy
Source: [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | [Claude Code Costs Docs](https://code.claude.com/docs/en/costs)

- CLAUDE.md loads into *every* session context. Keep it under **200 lines**. For each line ask: "Would removing this cause Claude to make mistakes?" If not, cut it.
- Skills (`SKILL.md` files) load **on-demand only**. Specialized workflow instructions (PR reviews, DB migrations, RPI phases) belong in skills, not CLAUDE.md.
- Bloated CLAUDE.md causes Claude to ignore instructions — the file is counterproductive above a certain size.
- CLAUDE.md supports `@path/to/file` imports; reference files rather than embedding their content.

### 6. Token Profiling — Native Tools
Source: [Claude Code Costs Docs](https://code.claude.com/docs/en/costs)

- `/cost` command: shows total session token counts and estimated dollar cost. Not authoritative for billing (local estimate only). Subscription users use `/stats`.
- `/context` command: shows what's currently consuming context space.
- Configure status line to show context window usage continuously.
- Agent SDK: `result.modelUsage` returns per-model token counts — useful when routing across Haiku/Sonnet/Opus. No per-subagent breakdown is natively exposed in the Claude Code CLI itself.
- Third-party tools: `claudetop` (real-time burn rate, alerts above $15/hr for runaway subagents); `phuryn/claude-usage` (local dashboard with session history); `cc-budget` (Holt-Winters forecasting with burn-rate alerts).

### 7. Agent Team Cost Scaling
Source: [Claude Code Costs Docs](https://code.claude.com/docs/en/costs) | [Anthropic Multi-Agent Research](https://www.anthropic.com/engineering/multi-agent-research-system)

- Agent teams use ~7× more tokens than standard sessions when teammates run in plan mode (separate context windows per teammate).
- Multi-agent systems use ~15× more tokens than chat interactions overall.
- Single agents use ~4× more tokens than chat.
- **Three factors explain 95% of performance variance**: token usage (80%), tool calls, model choice. Token budget is the primary lever.
- Agent teams are disabled by default; each teammate loads CLAUDE.md, MCP servers, and skills automatically — spawn prompts should be minimal.

---

## Community Consensus [COMMON PRACTICE]

### Succinctness Prompting
Sources: [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | [claude-token-efficient repo](https://github.com/drona23/claude-token-efficient) | [MindStudio 18 Hacks](https://www.mindstudio.ai/blog/claude-code-token-management-hacks-3)

- "Be concise" instructions in CLAUDE.md reduce output verbosity. Reported savings range 40–70% on focused tasks. No Anthropic-controlled study; community measurement.
- Terse instruction phrasing works: `"Use strict TypeScript types. Avoid any."` (7 tokens) vs. a paragraph explanation (35+ tokens) — same enforcement.
- Known anti-pattern: over-specifying CLAUDE.md. If the file is too long, Claude starts ignoring rules. Conciseness rules get lost in verbose CLAUDE.md — the instruction defeats itself.
- Vague prompts ("improve this codebase") trigger broad file scanning. Specific prompts ("add input validation to login function in auth.ts") minimize unnecessary file reads. Each unnecessary file read is hundreds to thousands of tokens.

### Common Token Waste Patterns
Sources: [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | [MindStudio Token Budget](https://www.mindstudio.ai/blog/ai-agent-token-budget-management-claude-code)

- **Kitchen-sink sessions**: mixing unrelated tasks accumulates irrelevant context that persists across all subsequent turns.
- **Repeated corrections**: two or more corrections for the same issue means context is polluted with failed approaches. Clear and re-prompt beats iterating.
- **Infinite exploration**: unscopedinvestigations ("look into how auth works") cause Claude to read hundreds of files into the main context. Always scope or delegate to a subagent.
- **Verbose progress narration**: agents narrating each step at length — the narration itself consumes tokens and gets re-processed on every subsequent turn.
- **Re-synthesizing already-synthesized content**: orchestrators that ask subagents to summarize, then re-summarize the summaries. One synthesis layer is sufficient.
- **Waiting for auto-compaction**: compacting at 5–10% context remaining instead of 50–60%.

### Artifact-File Handoffs vs. Content Passing
Sources: [Claude Code Sub-Agents Docs](https://code.claude.com/docs/en/sub-agents) | [Anthropic Multi-Agent Research](https://www.anthropic.com/engineering/multi-agent-research-system)

- Passing large artifacts through conversation is the primary source of token bloat in multi-agent pipelines. Write outputs to files, pass the path.
- Anthropic's own research system: "Implement artifact systems where specialized agents can create outputs that persist independently." Subagents return references, not content.
- This is the mechanism RPI already uses (research.md → plan.md → implement phase reads files).

---

## Disputed or Uncertain [SPECULATIVE]

- **Exact savings from succinctness prompting**: community claims 40–70%; no controlled Anthropic study cited. Likely varies significantly by task type and model version. SPECULATIVE.
- **Whether "be concise" degrades output quality**: some practitioners report that aggressive brevity instructions cause Claude to skip important reasoning steps. No consensus on safe phrasing. SPECULATIVE.
- **Parallel subagents reducing total tokens**: only true if tasks are genuinely independent and subagent summaries are shorter than the work would have been in-context. If subagents each load the same large CLAUDE.md and MCP definitions, parallelism may increase total token spend vs. sequential. Highly task-dependent. SPECULATIVE.
- **Optimal compact timing (% fill)**: community recommends 50–60% but this is anecdotal. Anthropic only says "compact proactively" without a specific threshold. SPECULATIVE.

---

## Applicability to RPI

| Practice | RPI Phase | Applies? | Expected Impact |
|---|---|---|---|
| 1h prompt cache TTL | All phases — system prompt + skills loaded per phase | **High** — each phase is a fresh context window; shared static content (CLAUDE.md, skill bodies) should use 1h TTL between phase invocations | 60–80% cost reduction on repeated static content |
| Static-before-dynamic cache ordering | Skill SKILL.md content (static) before phase-specific args (dynamic) | **High** — currently args probably prepend to skill body | Prevents 100% miss rate on system content |
| Subagent for research reads | Research phase spawns subagents for file/web reads | **High** — research phase fills context fastest; subagents keep findings out of orchestrator context | Prevents research context bleed into plan phase |
| File-based artifact handoffs | research.md → plan.md → implement | **Already done** — this is RPI's core mechanism | Baseline; ensure summaries are tight |
| Model routing | Research: Sonnet; Planning: Sonnet/Opus; Verification: Haiku | **Medium** — plan phase warrants Sonnet minimum; verification subagents can use Haiku | 10–30% cost reduction on verification cycles |
| Skills for phase instructions | Each RPI phase (research, plan, implement) as a skill | **Already done** — but audit skill body length; trim prose | Keeps CLAUDE.md lean |
| Proactive /compact between phases | Between research→plan and plan→implement | **Medium** — already clearing context via new subagent spawn; compact at research end preserves key findings | Reduces summary payload size |
| Concurrent subagent cache warmup | Serialize first subagent call before fanning out | **Medium** — research phase parallelism currently fires simultaneously | Prevents cold-cache miss on all parallel calls |
| Thin spawn prompts for teammates | Agent team spawn prompts for RPI teammates | **High** — teammates auto-load CLAUDE.md/skills; spawn prompt should be task only | Avoids double-loading instructions |
| CLAUDE.md under 200 lines | Global CLAUDE.md loaded in every RPI subagent | **High** — every subagent pays this cost | Audit current line count; prune or move to skills |

**Highest-leverage actions for RPI specifically:**
1. Use 1h TTL cache on system prompt / skill content for within-session phase transitions.
2. Ensure spawn prompts for subagents contain only task description, not instructions already in CLAUDE.md.
3. Audit global CLAUDE.md size — every RPI subagent loads it from scratch.
4. Scope research-phase subagent queries tightly to prevent infinite exploration.
5. Serialize the first parallel subagent call to warm the cache before fanning out.

---

*Sources: [Anthropic Prompt Caching](https://platform.claude.com/docs/en/docs/build-with-claude/prompt-caching) | [Claude Code Costs](https://code.claude.com/docs/en/costs) | [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices) | [Claude Code Sub-Agents](https://code.claude.com/docs/en/sub-agents) | [Anthropic Multi-Agent Research](https://www.anthropic.com/engineering/multi-agent-research-system) | [MindStudio Token Hacks](https://www.mindstudio.ai/blog/claude-code-token-management-hacks-3) | [claudetop](https://agent-wars.com/news/2026-03-14-claudetop-real-time-token-cost-monitor-for-claude-code-sessions) | [phuryn/claude-usage](https://github.com/phuryn/claude-usage)*
