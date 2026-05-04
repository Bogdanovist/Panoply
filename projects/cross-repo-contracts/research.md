# Research: cross-repo-contracts

Source: 2026-05-04 codebase investigation. Two general-purpose research agents inspected `~/src/datascience/` and `~/src/analytics/` in parallel, focusing on Hermes-relevant code paths and the artifact handoff between the repos.

## Repo split — what's load-bearing and what isn't

### Genuinely load-bearing

- **Online vs. offline runtime.** Datascience runs Cloud Run **Services** (long-lived FastAPI in `datascience/cloud-run-services/datascience-service/app.py`), long-lived Temporal workers, Cloud Functions, Airflow. GCP project: `human-ds-sandbox`. Analytics runs Cloud Run **Jobs** (batch only), Streamlit dashboards, Temporal workers as ephemeral job runners. No FastAPI anywhere. GCP project: `human-analytics`.
- **Deploy primitive, CI workflows, and GCP projects all differ.** Merging would re-create the boundary as a directory split inside one repo, with no real saving.

### Stated reasons that don't survive scrutiny

- **"Analytics doesn't touch users"** — false. MAB writes to PostHog feature flags daily (`analytics/athena/athena/mab/runner.py:236-244`); PR #122 had to force `dry_run=True` because non-prod was nudging live PostHog. Themis ships prompt-registry updates that flow into prod Find Treatment. Both have user-facing impact, just on a slower cadence and through different mechanisms than real-time HTTP.
- **"Different coding standards"** — true but smaller than the framing suggested. Analytics has ruff (`E,F,I,W,PLC0415`) only; no mypy, black, coverage gate, or pre-commit. Datascience has all four plus an 80% coverage floor and a `make pre-push` gate. Lifting analytics to that bar is a few days of config work, not an architectural reason to keep things split.

### The clean part of the seam

The MLflow Model Registry handoff for propensity models is well-engineered:
- Training: `analytics/athena/athena/models/propensity/registry.py:56-128` registers `propensity-{name}@champion` with a `feature_contract.json` artifact (feature names, dtypes, preprocessing, training metrics, runtime versions, config hash).
- Serving: `datascience/cloud-run-services/temporal-workers/campaigns/activities/mlflow_model_client.py:120-147` validates sklearn major.minor and runs a NaN smoke test before serving.
- Mirror docs on both sides (`MLFLOW_BRIDGE.md` in each repo). Promotion = bump `@champion` alias; no redeploy.

## Problem 1: Hermes BigTable schema — detail

### The contract has three parties

1. `HermesWorkflow` at `datascience/cloud-run-services/temporal-workers/campaigns/workflows/hermes_workflow.py` — runs propensity scoring then comms-plan optimizer. Writes propensity scores and features to BigTable.
2. `HermesService` at `datascience/cloud-run-services/datascience-service/hermes/service.py` — exposes `GET/PUT /hermes/nudges` and `GET/PUT /hermes/variants` (registered in `app.py:234-285`). Reads scores via the `account_featurestore_client`.
3. Analytics — writes upstream features (the propensity-scoring inputs) into BigTable column families `features` and `hermes`.

### Where the contract is documented

`analytics/athena/docs/decisions/003-hermes-joins-via-bigtable-bridge.md` (ADR-003). Single source. Lives only in the analytics repo. Discoverability for an agent working in datascience: poor — there is no link from datascience CLAUDE.md or docs.

### What protects against drift today

- Within datascience: `tests/test_feature_producer_consumer_contract.py` (Tier-1) guards feature producers and consumers within this repo, plus a Tier-2 e2e in CI (`cd-hermes-e2e-tests.yaml`). Does **not** cover analytics-side writes.
- Nothing on the analytics side asserts the schema matches what datascience expects.

### Failure mode

A rename or type change on either side that doesn't land in the other repo. Not caught at PR time on either side; discovered when a serving read returns nothing or wrong types.

## Problem 2: ML dep pinning — detail

### Pinned identically across repos

sklearn 1.6.1, mlflow 3.5.1, numpy 2.2.2, plus pandas and pyarrow. Locations:
- `analytics/athena/pyproject.toml:60-67`
- `datascience/cloud-run-services/requirements.txt`

### What protects against drift today

- `mlflow_model_client.py:120-147` validates sklearn major.minor at load time. Catches drift at serve time, not at PR time.
- No automation prevents merging an unaligned bump.

### Failure mode

Analytics bumps sklearn for an unrelated dashboard improvement. Models retrained under the new version serialize with binary changes that don't deserialize cleanly on the older serving side. Surfaces in serving logs as load failures or, worse, silently corrupted predictions if the deserializer is permissive.

## What was explicitly *not* found

- No Python imports between the two repos (`grep -rn "from analytics\|import analytics" --include="*.py"` in datascience returns nothing; same in reverse).
- No shared package, no submodule, no monorepo workspace.
- No coordinated CI between the repos.

The seam is genuinely file-mediated (artifacts + ADRs). The two problems above are the file-mediated parts that aren't tightly enough controlled.

## Cited files (entry points for future investigation)

- `/Users/matthumanhealth/src/datascience/cloud-run-services/temporal-workers/campaigns/workflows/hermes_workflow.py`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/temporal-workers/campaigns/activities/mlflow_model_client.py:120-147`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/temporal-workers/campaigns/activities/feature_bridge.py:1-44`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/datascience-service/hermes/service.py`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/datascience-service/app.py:234-285`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/temporal-workers/MLFLOW_BRIDGE.md`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/temporal-workers/tests/test_feature_producer_consumer_contract.py`
- `/Users/matthumanhealth/src/datascience/cloud-run-services/requirements.txt`
- `/Users/matthumanhealth/src/analytics/athena/athena/models/propensity/registry.py:56-128`
- `/Users/matthumanhealth/src/analytics/athena/athena/models/propensity/MLFLOW_BRIDGE.md`
- `/Users/matthumanhealth/src/analytics/athena/docs/decisions/003-hermes-joins-via-bigtable-bridge.md`
- `/Users/matthumanhealth/src/analytics/athena/pyproject.toml:60-67`
- `/Users/matthumanhealth/src/analytics/pyproject.toml`
- `/Users/matthumanhealth/src/analytics/.github/workflows/ci.yml`
