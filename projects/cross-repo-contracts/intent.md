# Intent: cross-repo-contracts

## Problem

The datascience and analytics repos are split for genuine reasons (online vs. offline runtime, different deploy primitives, different GCP projects), but two contracts that span the seam are inadequately protected:

1. **The Hermes BigTable column family schema is a tri-party contract documented in only one repo.** `HermesWorkflow` (datascience temporal-workers) writes propensity scores and features to BigTable column family `hermes`. `HermesService` (datascience-service) reads those scores via the account featurestore client. Analytics writes upstream features. The schema has no code-level expression — it is a column-family naming convention. The only documentation lives in `analytics/athena/docs/decisions/003-hermes-joins-via-bigtable-bridge.md` (ADR-003). An agent working in datascience would not naturally discover it.

2. **Critical ML dependency versions are pinned identically by hand across both repos.** sklearn 1.6.1, mlflow 3.5.1, numpy 2.2.2, plus pandas and pyarrow are pinned in both `analytics/athena/pyproject.toml:60-67` and `datascience/cloud-run-services/requirements.txt`. The handoff is a serialized model artifact — sklearn versions diverging silently breaks deserialization. Today's only protection is `mlflow_model_client.py:120-147` validating sklearn major.minor at *load* time. Nothing catches drift at PR time.

## Why this matters

Both are silent failure modes. The repo split itself is load-bearing and should not be undone, and the MLflow Model Registry handoff for propensity models is genuinely well-engineered (see `research.md`). These two specific seams are the leaky parts: drift in either is discovered late (at serve time or in QA), not at the PR that introduced it.

## Origin

Surfaced during the 2026-05-04 conversation that explored whether to merge the two repos or stand up a third coordination repo ("Jupiter"). Conclusion: keep the split, decline Jupiter, harden the two specific seams identified here.

A third issue surfaced in the same investigation — Themis vendoring workflow source from datascience — is being handled separately by a colleague and is explicitly out of scope here.

## Scope

In scope:
- Make the BigTable Hermes schema discoverable from both repos and protect against drift via symmetric contract tests.
- Make ML dep pin coordination automated or loudly enforced.

Out of scope:
- Repo merge or new coordination repo (rejected after analysis).
- Themis vendoring (separate owner).
- General coding-standards alignment between the repos (real but not urgent; tracked elsewhere if at all).
- Any other coupling between the repos.

## Status

Draft. Both workstreams have a recommended path in `design.md` but neither is committed. Priority is open — neither has bitten us in production yet, so this competes with current Hermes feature work for attention.
