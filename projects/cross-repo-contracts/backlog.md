# Backlog: cross-repo-contracts

Light. Most tasks are gated on design decisions in `design.md`.

## Pending decision (do these first)

- [ ] **Choose canonical home for cross-repo contracts.** Panoply `strategic-context/contracts/` vs. `cloud-infrastructure`. Affects both workstreams. Default proposed: Panoply.
- [ ] **Confirm priority.** Neither workstream is urgent — confirm before scheduling against current Hermes feature work.

## Workstream 1 — Hermes BigTable schema (assumes Option C)

- [ ] Author `<canonical-home>/hermes-bigtable-schema.md` from ADR-003 plus reader code in `account_featurestore_client.py`. Normalize: column families, key types, value types, writer/reader expectations.
- [ ] Update `analytics/CLAUDE.md` and `datascience/CLAUDE.md` to reference the canonical doc location.
- [ ] Replace ADR-003 content with a one-line stub pointing at the canonical doc. Preserve ADR title and date for history.
- [ ] Add analytics-side contract test mirroring `datascience/cloud-run-services/temporal-workers/tests/test_feature_producer_consumer_contract.py`. Asserts writers conform to documented schema.
- [ ] Extend datascience-side contract test to assert readers consume only documented columns.

## Workstream 2 — ML dep coordination (assumes A + D)

- [ ] Define the canonical "handoff dep list" (sklearn, mlflow, numpy, pandas, pyarrow — confirm completeness). Document it in `<canonical-home>/ml-handoff-pins.md`.
- [ ] Configure Renovate rule on both repos: any change to handoff deps opens a tracking PR/issue in the sibling repo.
- [ ] Extend `cloud-run-services/temporal-workers/campaigns/activities/mlflow_model_client.py:120-147` to validate numpy, pandas, pyarrow versions in addition to sklearn.

## Discovery / nice-to-have

- [ ] Run a deliberate drift simulation on a branch: bump sklearn in one repo, retrain a propensity model, attempt to load on the other side. Confirms the runtime backstop catches it before relying on it.
- [ ] Audit other artifacts for similar coordination needs (themis prompt registry — owned by colleague, but worth checking the inventory). Anything else routed through MLflow that has dep-pinning implications?
- [ ] Pull the incident log: have we ever actually been bitten by either of these failure modes? Drives priority calibration.
