# Decision: Prompt caching under Claude Code CLI (2026-04-21)

## Probe results

**CLI surfaces found:**
- `--exclude-dynamic-system-prompt-sections` (documented in `claude --help`): moves per-machine dynamic content (cwd, env info, memory paths, git status) from the system prompt into the first user message. Improves cross-user and cross-invocation prompt-cache reuse. Only applies with the default system prompt.

**CLI surfaces NOT found:**
- No `--cache-control`, `--cache-ttl`, or equivalent flag.
- No `cache_*` keys in `settings.json` / `settings.local.json` schema.
- No way to set 1h TTL vs 5min TTL from user-space.
- Task-tool / Agent-tool invocations do not expose a `cache_control` parameter.

## Interpretation

Prompt-cache breakpoint placement, TTL, and `cache_control` directive semantics are **Anthropic-managed** inside Claude Code. The user-facing lever is limited to the one flag above, which optimises cache-key stability (not cache-breakpoint placement).

## Decision

**Close F14/F15 as "SDK-only future work" for now.** The research finding ("up to 60–80% savings from 1h TTL caching on static skill content") is real but only actionable if RPI is re-implemented on top of the Anthropic SDK directly (not the Claude Code CLI). For in-CLI runs, caching is opaque.

**One actionable tweak**: consider adding `--exclude-dynamic-system-prompt-sections` to any scripted Claude Code invocations (hooks, `/loop`, `schedule`). Not required for interactive sessions.

## What this means for the RPI plan

- F14 (prompt caching) and F15 (parallel-call cache warming) are parked. No skill-level changes required.
- Future work: if Panoply moves toward direct-SDK orchestration of RPI phases, revisit with cache_control placement and static-before-dynamic ordering rules (see research doc §Prompt Caching for the full checklist).
