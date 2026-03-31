# Backlog: zd-symptom-decisions

## Ready

- [ ] **Investigate Zendesk ticket schema** — Fetch a sample symptom request ticket via the API. Identify: (1) the `account_id` custom field ID, (2) whether the Ticket Audits API (`/api/v2/tickets/{id}/audits`) exposes status change timestamps for hold start/end, (3) confirm comment structure and timestamps. Document findings in the design doc.
- [ ] **Build extractor** — `symptom_decisions/extractor.py`. Zendesk search with time-windowed backfill (3-month chunks to stay under 1K search limit) and incremental mode (updated >= watermark). Extract ticket metadata and comments. Reuse `ZendeskClient` and `_get_custom_field` pattern.
- [ ] **Build classifier** — `symptom_decisions/classifier.py`. LLM prompt with macro templates, structured JSON output → `(Resolution, symptom_reworded)`. Use `VertexLLM` with Gemini Flash. Include a validation script that compares Flash vs Pro accuracy on a sample.
- [ ] **Build loader + types** — `symptom_decisions/loader.py` and `types.py`. BigQuery writer following `AllocationHistoryWriter` pattern. Auto-create table, partitioned by `request_timestamp`. Watermark query for incremental loading.
- [ ] **Wire up pipeline + CLI** — `symptom_decisions/__init__.py` and `__main__.py`. Orchestrate extract → classify → load. CLI with `--backfill`, `--dry-run`, `--limit` flags.
- [ ] **Historical backfill** — Run full backfill against Zendesk. Validate a sample of classifications manually (target >95% accuracy).

## Later

- [ ] **Daily scheduling** — Register as Cloud Run Job with Cloud Scheduler. Terraform PR to cloud-infrastructure.
- [ ] **Classification accuracy report** — Script or dashboard to sample and review classifications over time.
