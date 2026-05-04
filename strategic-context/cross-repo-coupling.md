# Cross-repo coupling between datascience and analytics

Source: 2026-05-04 codebase investigation, run from a Panoply session that started by asking whether to add a third "coordination repo" (Jupiter) to manage cross-repo work between `~/src/datascience/` and `~/src/analytics/`. Two parallel research agents inspected both repos, focused on Hermes-relevant code paths and the artifact handoff between the repos. This doc captures what was found and the smells worth picking up later — it is *not* a plan.

## What the research concluded about the split itself

**Keep it.** The split is load-bearing for runtime/deploy reasons:

- Datascience runs Cloud Run **Services** (long-lived FastAPI in `datascience/cloud-run-services/datascience-service/app.py`), long-lived Temporal workers, Cloud Functions, Airflow. GCP project: `human-ds-sandbox`.
- Analytics runs Cloud Run **Jobs** (batch only), Streamlit dashboards, Temporal workers as ephemeral job runners. No FastAPI anywhere. GCP project: `human-analytics`.

Two stated reasons for the split don't fully hold up:
- *"Analytics doesn't touch users"* — false. MAB writes to PostHog feature flags daily (`analytics/athena/athena/mab/runner.py:236-244`); PR #122 had to force `dry_run=True` because non-prod was nudging live PostHog. Themis ships prompt-registry updates that flow into prod.
- *"Different coding standards"* — true but smaller than it sounded. Analytics has ruff only; datascience has ruff + black + mypy + 80% coverage + pre-commit + `make pre-push`. Closing the gap is days of config, not architecture.

The MLflow Model Registry handoff for propensity models is genuinely well-engineered: training in `analytics/athena/athena/models/propensity/registry.py:56-128` registers `propensity-{name}@champion` with a `feature_contract.json` artifact; serving in `datascience/cloud-run-services/temporal-workers/campaigns/activities/mlflow_model_client.py:120-147` validates sklearn major.minor and runs a NaN smoke test. Mirror docs on both sides (`MLFLOW_BRIDGE.md`). That's how a cross-repo handoff *should* look — and it's why merging the repos felt regressive.

## Smell 1 — Hermes BigTable schema is a tri-party contract documented in only one place

Three pieces of code talk via the BigTable `hermes` column family:

1. `HermesWorkflow` (datascience temporal-workers, `cloud-run-services/temporal-workers/campaigns/workflows/hermes_workflow.py`) writes propensity scores + features.
2. `HermesService` (datascience-service, `cloud-run-services/datascience-service/hermes/service.py`, registered in `app.py:234-285`) reads scores via `account_featurestore_client`.
3. Analytics writes upstream features into the same column families.

The schema isn't expressed as code anywhere. It's column-family naming convention, and the only documentation is `analytics/athena/docs/decisions/003-hermes-joins-via-bigtable-bridge.md`. An agent working in datascience won't naturally find that ADR.

Within datascience there's a contract test (`tests/test_feature_producer_consumer_contract.py`) plus a Tier-2 e2e in CI (`cd-hermes-e2e-tests.yaml`). That covers writer/reader *within* the repo. It does not cover the analytics-side writer.

**Failure mode:** rename or type change on either side that doesn't land in the other; surfaces at serve time as missing reads or wrong types, not at PR time.

**Things worth considering when this gets picked up:**
- Pragmatic version: lift the schema doc into a place both repos' CLAUDE.md route to (Panoply, cloud-infrastructure, even just a sibling `analytics/docs/contracts/` referenced from datascience CLAUDE.md), and add a symmetric contract test on the analytics side.
- Lighter version: just a CLAUDE.md cross-link from datascience to ADR-003 — accepts the smell but at least makes the contract discoverable.
- Heavier version: lift the schema into a shared package or generated types. Probably overkill for one schema; reconsider only if the schema grows.

## Smell 2 — ML dep versions are pinned identically by hand

sklearn 1.6.1, mlflow 3.5.1, numpy 2.2.2, plus pandas and pyarrow are pinned in both:
- `analytics/athena/pyproject.toml:60-67`
- `datascience/cloud-run-services/requirements.txt`

The artifact handoff is a serialized model. Sklearn diverging silently breaks deserialization. The runtime check at `mlflow_model_client.py:120-147` validates sklearn major.minor at *load* time — that's a backstop, not prevention.

**Failure mode:** unaligned bump (e.g. analytics bumps sklearn for an unrelated dashboard improvement); models retrained under the new version don't deserialize cleanly on the older serving side. Surfaces in serving logs as load failures, or — if the deserializer is permissive — silently wrong predictions.

**Things worth considering when this gets picked up:**
- Lightest: extend the runtime validation to cover numpy/pandas/pyarrow alongside sklearn. Cheap incremental tightening of a thing that already exists.
- Light: Renovate/Dependabot rule that flags handoff-dep changes in either repo and opens a tracking PR/issue in the sibling.
- Heavier: cross-repo CI check that fails when handoff deps differ. Adds friction during emergency security bumps.
- Probably overkill: uv workspace at `~/src/` level, shared constraints file. Different deploy primitives make this awkward.

## Worth checking before scheduling either

Has either failure mode actually bitten us? PR #122 (MAB / PostHog dry_run) was a different class of issue. If neither of these smells has caused an incident, both rank below current Hermes feature work. Pull the incident log before doing anything.

## Explicitly out of scope here

- **Themis vendoring** — `themis/themis/pipeline/` is a hand-copy of `datascience/cloud-run-services/temporal-workers/health_lab/`, with a per-file ruff exemption in root `pyproject.toml:11-16` to keep re-syncing mechanical. Real architectural smell, separate owner.
- **Coding-standards gap** between analytics and datascience. Real but small.
- **Repo merge / Jupiter** — considered and rejected.

## Citation index

Datascience side:
- `cloud-run-services/temporal-workers/campaigns/workflows/hermes_workflow.py`
- `cloud-run-services/temporal-workers/campaigns/activities/mlflow_model_client.py:120-147`
- `cloud-run-services/temporal-workers/campaigns/activities/feature_bridge.py:1-44`
- `cloud-run-services/datascience-service/hermes/service.py`
- `cloud-run-services/datascience-service/app.py:234-285`
- `cloud-run-services/temporal-workers/MLFLOW_BRIDGE.md`
- `cloud-run-services/temporal-workers/tests/test_feature_producer_consumer_contract.py`
- `cloud-run-services/requirements.txt`

Analytics side:
- `athena/athena/models/propensity/registry.py:56-128`
- `athena/athena/models/propensity/MLFLOW_BRIDGE.md`
- `athena/docs/decisions/003-hermes-joins-via-bigtable-bridge.md`
- `athena/pyproject.toml:60-67`
- `pyproject.toml` (root, ruff exemption for vendored themis pipeline)
- `.github/workflows/ci.yml`
- `athena/athena/mab/runner.py:236-244` (the "analytics doesn't touch users" counterexample)
