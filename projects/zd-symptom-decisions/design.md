# Solution Design: zd-symptom-decisions

Status: draft

## Overview

A daily incremental pipeline that mines the full Zendesk symptom request ticket
history, classifies each ticket's resolution using a cheap Gemini model, and
loads a PHI-free event table into BigQuery. The pipeline reuses the existing
Zendesk client and Vertex AI LLM wrapper — no new external integrations. Output
enables retention and engagement analysis of symptom decisions for the first
time.

## Key Decisions

### 1. Module location: `athena/athena/tools/symptom_decisions/`

- **Choice**: New module under `tools/`, alongside the existing `symptom_deduper/`
  and `zendesk/` modules.
- **Rationale**: This is a standalone analytical tool, not a pipeline with
  extract→dbt→test stages. It doesn't fit the Temporal workflow pattern (no dbt
  step, no extract from a data source). It's structurally similar to the symptom
  deduper triage tool — a CLI that reads from Zendesk, does processing, writes
  to BigQuery.
- **Alternatives considered**: Temporal workflow — overkill for a simple
  read→classify→write loop with no dbt dependency. Could migrate later if it
  needs orchestration with other steps.

### 2. Time-windowed Zendesk search for backfill

- **Choice**: For the initial historical backfill, search Zendesk in time
  windows (e.g. 3-month chunks) to stay under the Search API's 1,000-result
  hard limit. For daily incremental runs, a single search filtered by
  `updated>={last_run_date}` is sufficient (daily volume is tiny).
- **Rationale**: The existing `ZendeskClient.search_tickets()` handles
  pagination but Zendesk enforces a 1,000-result cap across all pages. With
  ~1–10K total tickets over 3 years, 3-month windows will comfortably stay
  under the limit (~250–800 tickets per window).
- **Alternatives considered**: Zendesk Incremental Exports API — more
  complex, returns all ticket types (not just symptom requests), would
  require a new client method. The time-window approach is simpler and uses
  existing code.

### 3. Gemini Flash via existing VertexLLM wrapper

- **Choice**: Use `athena.tools.zendesk.llm.VertexLLM` with `gemini-2.5-flash`
  (the default). Must be Gemini on Vertex AI for PHI/BAA compliance — same as
  the symptom deduper triage pipeline.
- **Rationale**: The classification task is simple (match a response to one of
  four macro templates). Flash is cheap, fast, and sufficient. During the build,
  validate on a sample by comparing Flash vs. Gemini Pro — expectation is Flash
  performs equally.
- **Alternatives considered**: Claude via Vertex AI Anthropic Model Garden —
  supported by the VertexLLM wrapper, but unnecessary for this task and more
  expensive. Must NOT use Anthropic API directly (PHI constraint).

### 4. Incremental loading via BigQuery watermark

- **Choice**: On each run, query the destination table for
  `MAX(processed_at)` as the watermark. Search Zendesk for symptom request
  tickets with `updated>={watermark}`. Skip tickets whose `ticket_id` already
  exists in the table unless status has changed (ticket moved from
  `hold` → `solved`). First run with no watermark triggers full backfill.
- **Rationale**: Simple, no external state. The destination table is its own
  bookmark. Re-processing tickets whose status changed handles the case where a
  "new symptom" ticket was on hold during one run and resolved by the next.
- **Alternatives considered**: External state file or separate watermark
  table — unnecessary complexity when the destination table serves the same
  purpose.

### 5. PHI-free output — classify in memory, store only codes

- **Choice**: The LLM receives full ticket content for classification but the
  output table contains only ticket IDs, timestamps, categorical codes, and
  booleans. No symptom names, user text, or agent responses are persisted.
- **Rationale**: Hard PHI constraint. The mart table must be safe for broad
  analytical access. All ticket content stays in-memory during processing and
  is discarded after classification.

### 6. Hold timestamps from ticket audit log or comment inference

- **Choice**: Investigate the Zendesk Ticket Audits API
  (`/api/v2/tickets/{id}/audits`) during implementation. Audits record every
  status change with timestamps. If audits are available and reliable, use them
  for precise hold start/end times. Fallback: infer from comment timestamps
  (the on-hold macro is Macro 3, the follow-up is Macro 4 — their timestamps
  bracket the hold period).
- **Rationale**: This is an open investigation item. The ticket object itself
  only has `created_at` and `updated_at`, not per-status-transition timestamps.
  Either approach works; audits are more precise. The Zendesk client may need a
  new `list_audits()` method if this route is taken.

## Component Design

### `athena/athena/tools/symptom_decisions/`

```
symptom_decisions/
├── __init__.py          # Public API: run_pipeline()
├── __main__.py          # CLI entry point
├── classifier.py        # LLM classification logic
├── extractor.py         # Zendesk ticket extraction and filtering
├── loader.py            # BigQuery table writer
└── types.py             # Dataclasses: TicketDecision, Resolution enum
```

### `types.py` — Data model

```python
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

class Resolution(str, Enum):
    DUPLICATE = "duplicate"
    CONDITION = "condition"
    NEW_SYMPTOM = "new_symptom"
    OTHER = "other"

@dataclass(frozen=True)
class TicketDecision:
    ticket_id: int
    account_id: str | None
    resolution: Resolution
    symptom_reworded: bool | None          # only for NEW_SYMPTOM
    request_timestamp: datetime
    first_response_timestamp: datetime | None
    hold_start_timestamp: datetime | None
    hold_end_timestamp: datetime | None
    resolution_timestamp: datetime | None
    time_to_resolution_hours: float | None
    classification_model: str
    processed_at: datetime
```

### `extractor.py` — Zendesk ticket extraction

- **Purpose**: Search Zendesk for symptom request tickets, extract metadata,
  fetch comments for classification.
- **Interface**:
  - `fetch_symptom_tickets(zd, since=None)` → `list[dict]` — searches for
    tickets with subject containing "Content request (Symptom)". When `since`
    is provided, filters to `updated>={since}`. For backfill (no `since`),
    iterates in time windows to stay under the 1,000-result search limit.
  - `extract_ticket_metadata(ticket, comments)` → timestamps, account_id,
    status info. Uses the existing `_get_custom_field()` helper pattern from
    the triage module.
- **Key constraints**:
  - Must handle the Zendesk Search API's 1,000-result limit via time windowing.
  - The `account_id` custom field ID is unknown — to be discovered during
    investigation (first backlog item). Use the same `_get_custom_field()`
    pattern as `SEARCH_TERM_FIELD_ID` in the triage module.

### `classifier.py` — LLM classification

- **Purpose**: Given a ticket's comment thread, determine the resolution
  category and (for new_symptom) whether the symptom was reworded.
- **Interface**:
  - `classify_ticket(comments, llm) → (Resolution, bool | None)` — sends the
    comment thread to Gemini with the macro templates as system context.
    Returns the resolution category and the `symptom_reworded` boolean.
- **Key constraints**:
  - Must use `VertexLLM` from `athena.tools.zendesk.llm` — no Anthropic API.
  - Macro templates embedded in the prompt (loaded from
    `zendesk_macros.md` or hardcoded after validation — TBD during build).
  - Must request structured JSON output to avoid parsing fragility.
  - The LLM sees full ticket text in-memory but no text is returned or stored
    — only the classification codes.

### `loader.py` — BigQuery writer

- **Purpose**: Write `TicketDecision` rows to the `symptom_request_decisions`
  BigQuery table.
- **Interface**:
  - `DecisionWriter(client, table_ref)` — follows the
    `AllocationHistoryWriter` pattern from `athena/mab/history.py`.
  - `write(decisions: list[TicketDecision]) → bool`
  - `get_watermark() → datetime | None` — queries `MAX(processed_at)` from
    the destination table for incremental loading.
  - `get_processed_ticket_ids() → set[int]` — for deduplication during backfill.
- **Key constraints**:
  - Auto-creates table with schema if it doesn't exist (same pattern as
    `AllocationHistoryWriter`).
  - Table partitioned by `request_timestamp` (the natural time dimension for
    analysis).
  - Uses `ANALYTICS_BQ_PROJECT` and `ANALYTICS_BQ_DATASET` env vars for
    table location.

### `__main__.py` — CLI

```
uv run python -m athena.tools.symptom_decisions
uv run python -m athena.tools.symptom_decisions --dry-run
uv run python -m athena.tools.symptom_decisions --backfill
uv run python -m athena.tools.symptom_decisions --limit 10
```

- Default mode: incremental (process tickets updated since last run).
- `--backfill`: full historical extraction with time-windowed search.
- `--dry-run`: extract and classify but don't write to BigQuery — log results.
- `--limit N`: process at most N tickets (for testing / validation).

## Data Flow

```
Zendesk Search API
    │
    ▼
fetch_symptom_tickets()        ← time-windowed for backfill, updated>= for incremental
    │
    ├── ticket metadata        → extract_ticket_metadata()  → timestamps, account_id
    │
    └── list_comments()        → classify_ticket()          → Resolution, symptom_reworded
            │                       │
            │                       ▼
            │                  VertexLLM (Gemini Flash)
            │                       │
            │                       ▼
            │                  (Resolution, symptom_reworded)
            ▼
    TicketDecision dataclass
            │
            ▼
    DecisionWriter.write()     → BigQuery: symptom_request_decisions
```

## Dependencies

All already in `athena/pyproject.toml` — no new packages needed:

- `google-cloud-bigquery` — BigQuery reads and writes
- `google-genai` — Vertex AI Gemini access (via existing VertexLLM)
- `requests` — Zendesk API (via existing ZendeskClient)

## Review Plan

### Requires Human Review

- **Data model / schema**: The BigQuery table schema and what gets stored —
  critical to get right for the downstream retention/engagement analysis, and
  must be validated against the PHI constraint.
- **LLM classification prompt**: The prompt that classifies ticket responses
  against macro templates — need human review to confirm it handles the
  adapted-macro edge cases correctly.
- **Zendesk field mapping**: The `account_id` custom field ID discovery and
  any other field mappings that come from the investigation step.

### Autonomous

- **Extractor module**: Standard Zendesk search + pagination — follows
  established patterns from the triage module.
- **BigQuery loader**: Direct reuse of the `AllocationHistoryWriter` pattern.
- **CLI and orchestration**: Standard argparse CLI — same pattern as the
  triage module.
- **Tests**: Unit tests for classifier (mocked LLM), extractor (mocked
  Zendesk), loader (mocked BigQuery). E2E test against real Zendesk + BigQuery.
