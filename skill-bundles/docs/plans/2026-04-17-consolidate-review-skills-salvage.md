# Salvage Memo: /review vs. Bot Prompt (2026-04-17)

## Question

What general-purpose review concepts live in the old `/review` skill that the bot prompt does NOT cover?

Stale-plumbing exclusions applied: intent.md, design.md, architecture.md, project backlog,
mapping.yaml, spec promotion, Hubris harness references.

---

## Findings

### 1. Explicit severity levels (CRITICAL / SIGNIFICANT / MODERATE / MINOR)

**What it is:** The `/review` skill prefixes every concern with a four-level severity tag.  
**Why valuable:** Without severity, reviewers cannot triage — a nit and a data-corruption bug look equally urgent. The bot aggregates findings but has no severity vocabulary.  
**Suggested phrasing:** "For each finding, prefix with a severity label — CRITICAL (blocks merge), SIGNIFICANT (should fix before merge), MODERATE (fix in follow-up is acceptable), MINOR (style/nit)."

---

### 2. Test quality classification

**What it is:** Classifying tests as behavioral / implementation / insufficient / none, and checking whether tests use real data paths or only synthetic/mock data.  
**Why valuable:** The bot's four agents do not evaluate test quality at all — a PR could add zero tests and the bot would not flag it. This axis surfaces the most common long-term quality debt.  
**Suggested phrasing:** "Classify the test suite added or modified by this PR as: behavioral (tests what should be true from a caller's perspective), implementation (mirrors the code — passes even if the code is wrong), insufficient, or none; note if tests rely entirely on synthetic/mock data."

---

### 3. Verdict + confidence header (approve / request_changes / escalate)

**What it is:** A required top-level verdict with an explicit confidence level (high / medium / low), and a defined "when in doubt, escalate" tiebreaker rule.  
**Why valuable:** The bot deliberately avoids approve/request_changes (`NEVER use --approve or --request-changes`). For a local pre-push check, a clear pass/warn/block decision is the entire point — without a verdict structure the output is advisory noise.  
**Suggested phrasing:** "Output a top-level verdict: PASS (no actionable concerns), WARN (concerns present but not blocking), or BLOCK (at least one CRITICAL or SIGNIFICANT finding); include confidence (high / medium / low) and, when confidence is low, escalate rather than guess."

---

### 4. Architecture & security as a named review axis

**What it is:** A dedicated evaluation dimension covering hardcoded credentials, missing auth checks, data exposure, and conflicts with established patterns — separate from the four agents the bot uses.  
**Why valuable:** The bot's four agents (correctness, reuse, quality, efficiency) have no explicit security axis. Security issues are the highest-consequence gap to miss in a pre-push check.  
**Suggested phrasing:** "Run a fifth check across the diff for security issues: hardcoded credentials, missing auth or permission checks, data exposure at API boundaries, and decisions that conflict with established architectural patterns in the repo."

---

### 5. "Verify before flagging" discipline (explicit tools mandate)

**What it is:** The `/review` skill requires using Grep/Read to confirm every concern exists before listing it — speculation is explicitly prohibited.  
**Why valuable:** The bot mentions this in Phase 3 ("verify it") but buries it after the four agents have already drafted findings. Making it a first-class rule at the agent level, not just synthesis, reduces false positives.  
**Suggested phrasing:** "Before including any finding in the output, use Grep or Read to confirm the issue exists in the actual diff — do not speculate or flag from memory."

---

### 6. "Spec soundness" check (SPEC: prefix)

**What it is:** Separately flagging design errors in the PR description itself — cases where the spec is wrong, not just the code. Tagged `SPEC:` to distinguish from implementation concerns.  
**Why valuable:** The bot checks intent vs implementation (Agent 1, item 5) but only in one direction: does the code match the description? It does not ask whether the description itself is wrong or incoherent. Catching spec errors before the code ships is cheaper than refactoring after.  
**Suggested phrasing:** "If the PR description itself contains a design error or incoherent intent — not just a code/spec mismatch — flag it with a SPEC: prefix as a distinct concern category."

---

### 7. Reusable lessons section

**What it is:** A dedicated section (0–3 items) for patterns that future work in this codebase should know about — generalizable insights extracted from this specific review.  
**Why valuable:** The bot produces a single review comment with findings. It has no mechanism to surface cross-PR learning. For a local skill running in the developer's session, capturing lessons closes the feedback loop and improves subsequent PRs.  
**Suggested phrasing:** "After findings, include a 'Reusable Lessons' section (0–3 bullets max) identifying patterns from this PR that are worth carrying forward into future work in this codebase."

---

## Summary

Seven distinct general-purpose concepts in `/review` are absent from or materially weaker in the bot prompt. None depend on the Hubris harness. All are worth incorporating into `pr-preflight`.
