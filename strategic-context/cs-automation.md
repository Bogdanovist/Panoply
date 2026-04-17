# Strategic Context: Customer Support Automation

## Theme

Augmenting the Human Health support workflow with tooling that reduces manual effort and improves consistency. The dedicated support person has left, and support duty now rotates across the technical team — making automation both more urgent and more feasible (technical operators can use CLI tools and approve AI-drafted responses).

The goal is not full automation but **human-in-the-loop AI assistance**: draft responses for operator approval, automate triage steps, reduce the manual research burden. If successful, support can remain a shared team responsibility rather than requiring a dedicated hire.

## Current State

**Symptom request deduper** (shipped) — LLM-based semantic matching against the full symptom (~2,500) and condition databases. Classifies requests as duplicate symptom, existing condition, untracked condition, or genuinely new. Deployed as a Cloud Run job with Vertex AI (Gemini Flash) for HIPAA-compliant LLM processing.

**Zendesk triage pipeline** (shipped) — Searches Zendesk for open symptom request tickets, runs each through the deduper, writes results as internal notes, and tags processed tickets. Runs via Cloud Run job. Code in `athena/athena/tools/symptom_deduper/triage.py`.

**Zendesk API client** (shipped) — REST API v2 wrapper for ticket read, search, internal notes, and tag management. Code in `athena/athena/tools/zendesk/client.py`.

**Symptom decision analytics** (in progress, project `zd-symptom-decisions`) — Historical analysis of all symptom request decisions. Mining ~3 years of Zendesk ticket history to build a PHI-free BigQuery mart table capturing resolution type (duplicate/condition/new symptom), timestamps, and user account IDs. Goal: measure the retention and engagement impact of symptom decisions for the first time.

## The Symptom Request Workflow

The highest-volume ticket type (~60–70% of support time). Current manual flow:

1. **Triage** — Duplicate symptom? Operator checks the database.
2. **Duplicate** → Macro response explaining the existing symptom covers their request.
3. **Condition, not symptom** → User is describing a condition already in the conditions database. Different handling needed.
4. **Genuinely new** → Reply to user (sent to clinical review). Raise Linear ticket for clinical team.
5. **Clinical review** — Part-time team, can take days. Either identifies as duplicate or adds with clinically validated terminology.
6. **Close the loop** → Macro response confirming symptom added.

### Automation opportunities in this chain

| Step | Automation | Status |
|------|-----------|--------|
| Duplicate detection | LLM semantic matching against symptom DB | Built (deduper spike), improving semantic matching |
| Condition detection | Check conditions DB, similar matching | In progress (deduper production phase) |
| Draft triage response | Auto-draft based on deduper result | Needs Zendesk connector |
| Raise Linear ticket | Auto-create when genuinely new | Future |
| Clinical review feedback | Clinical team maintains deduplication criteria doc, aligns with AI | Future |
| Close-the-loop response | Auto-draft confirmation reply | Needs Zendesk connector |

## Direction

1. **Done**: Deduper + Zendesk triage pipeline (auto-triage symptom requests, post internal notes)
2. **Now**: Symptom decision analytics — historical dataset for measuring impact of decisions on retention/engagement
3. **Next**: Auto-raise Linear tickets for clinical review, broader ticket type automation
4. **Eventually**: Clinical team feedback loop on matching criteria, closed-loop optimization

Each step is a small project. The connector is foundational — everything else builds on it.

## Constraints

- **No Zendesk sandbox** — all development against production. Use tagged test tickets (`hubris-test`), never auto-send.
- Small team, rotating support duty — tools must be CLI-friendly and self-contained
- Clinical decisions stay with humans — automation assists triage, doesn't replace clinical judgment
- Human-in-the-loop: AI drafts, humans approve. No autonomous ticket actions.
- Cost sensitivity — leveraging existing Claude subscriptions rather than dedicated API spend
