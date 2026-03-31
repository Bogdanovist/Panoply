# Intent: zd-symptom-decisions

## Problem

We have ~3 years of symptom request history in Zendesk (~1–10K tickets) but no
analytical dataset capturing what decisions were made, when, and for whom. We
can't measure the retention or engagement impact of symptom decisions — whether
adding a requested symptom retains a user, whether a "duplicate" resolution
causes churn, or whether time-to-resolution matters.

## Context

Symptom requests are the highest-volume support ticket type (~60–70% of support
time). Each ticket results in one of three decisions:

1. **Duplicate** — the symptom already exists under a different name; single
   response, ticket resolved immediately.
2. **Condition** — the user described a medical condition, not a trackable
   symptom; single response, ticket resolved immediately.
3. **New symptom** — sent to clinical review, ticket goes on hold, follow-up
   sent days later when the symptom is added. The clinical team often rewords
   the symptom using accepted medical terminology.

There is also an **Other** category for edge cases that don't fit any of the
above.

The support team uses adapted Zendesk macros for all responses. The wording is
customized per ticket but the structure is consistent, making LLM classification
reliable with a cheap model. Macro templates are documented in
[zendesk_macros.md](zendesk_macros.md).

## Approach

Build a daily incremental pipeline in `athena/athena/tools/symptom_decisions/`
that:

1. **Extracts** symptom request tickets from Zendesk via the existing API client
   (`athena.tools.zendesk.client.ZendeskClient`).
2. **Classifies** each ticket's resolution by sending the comment history to a
   cheap LLM (e.g. Gemini Flash) with the macro templates as reference. The
   classifier determines:
   - Which resolution category applies: `duplicate` / `condition` /
     `new_symptom` / `other`
   - For `new_symptom` resolutions: whether the symptom that was added was
     substantively reworded from the user's original request (not just
     spelling/stemming differences — a genuinely different set of words).
3. **Extracts** timestamps and metadata from the ticket lifecycle (created,
   on-hold, resolved) and the `account_id` custom field.
4. **Loads** results into a BigQuery mart table, one row per ticket.

### PHI Constraint

**No free text from tickets may be stored in the mart table.** No symptom
names, user messages, agent responses, or any content that could constitute
protected health information. The table contains only: ticket IDs, timestamps,
categorical resolution codes, and booleans. The LLM performs classification
in-memory; nothing identifiable lands in BigQuery.

### Incremental Strategy

- Track processed ticket IDs in the destination table.
- On each run, query Zendesk for symptom request tickets updated since the
  last processed timestamp.
- Only LLM-classify tickets not already in the table, or whose resolution
  status has changed (e.g. a ticket moved from on-hold to solved).
- Full historical backfill on first run.

### Data Sources

- **Zendesk API** — tickets with subject containing "Content request (Symptom)",
  their comments, custom fields (including `account_id` — field ID TBD),
  tags, timestamps, status history.
- **Macro templates** — reference doc for LLM classification
  ([zendesk_macros.md](zendesk_macros.md)).

### LLM Classification

**Must use Gemini via Vertex AI** — for PHI/privacy reasons, all LLM
processing that touches ticket content must go through Google Vertex AI (covered
by Human Health's BAA), not Anthropic/Claude models. This is the same approach
used by the existing symptom deduper triage pipeline
(`athena.tools.zendesk.llm.VertexLLM`) — reuse that infrastructure.

The classification task is lightweight: does a response roughly match one of
four macro templates? A cheap, fast model (Gemini Flash) should be sufficient.
During the build, validate this by comparing Gemini Flash accuracy against a
more capable Gemini model on a sample — the expectation is Flash handles it
fine.

The classifier receives the full comment thread for a ticket and the four macro
templates. It determines which resolution category the agent's response
corresponds to. Agents adapt the macros to each request so exact string matching
won't work, but the structure is consistent enough for high accuracy.

For `new_symptom` tickets that have a follow-up message (Macro 4), the
classifier also determines whether the added symptom was substantively reworded
from the user's original request. This is a boolean — not a text comparison
stored in the table.

Some tickets will have freeform responses that don't use a macro but still
clearly convey one of the three decisions. The classifier should handle these.
Genuinely ambiguous cases get classified as `other`.

## Output

### BigQuery mart table: `symptom_request_decisions`

One row per ticket.

| Column | Type | Description |
|--------|------|-------------|
| ticket_id | INTEGER | Zendesk ticket ID (natural key) |
| account_id | STRING | Human Health user account ID |
| resolution | STRING | `duplicate` / `condition` / `new_symptom` / `other` |
| symptom_reworded | BOOLEAN | For `new_symptom`: was the added symptom substantively different from the request? NULL for other resolutions |
| request_timestamp | TIMESTAMP | When the ticket was created |
| first_response_timestamp | TIMESTAMP | When the first agent response was sent |
| hold_start_timestamp | TIMESTAMP | When ticket was put on hold (NULL if not applicable) |
| hold_end_timestamp | TIMESTAMP | When ticket came off hold (NULL if not applicable) |
| resolution_timestamp | TIMESTAMP | When the final resolution response was sent |
| time_to_resolution_hours | FLOAT | request_timestamp → resolution_timestamp |
| classification_model | STRING | LLM model used for classification |
| processed_at | TIMESTAMP | When this row was created/updated by the pipeline |

### Open Questions

- [ ] What is the Zendesk custom field ID for `account_id`? (Investigate via API)
- [ ] Are there additional resolution edge cases beyond duplicate/condition/new_symptom/other?
- [ ] Does the Zendesk API expose ticket status change history (for hold timestamps), or do we need to infer from comments?

## Success Criteria

- [ ] Pipeline processes full Zendesk history on first run
- [ ] Daily incremental runs process only new/updated tickets (no re-classifying the full history)
- [ ] Resolution classification accuracy >95% validated against a manual sample
- [ ] No PHI in the output table — only IDs, timestamps, categoricals, and booleans
- [ ] Output table enables joining to user engagement/retention data via account_id
- [ ] Pipeline reuses existing Zendesk client (`athena.tools.zendesk`)
