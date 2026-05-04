# Design: cross-repo-contracts

Status: draft. Two independent workstreams. Each has a recommended path; alternatives are kept for grilling.

## Workstream 1 — Hermes BigTable schema discoverability and drift protection

### Goal

Make the column-family schema discoverable from both repos and protected by symmetric tests on both sides.

### Options

**Option A — Shared Python package.** Publish a small `hermes-feature-schema` package with typed accessors for the column families. Both repos depend on it.
- Pros: code-level enforcement; agents read the schema by reading the package.
- Cons: yet another package to publish/version/sync; new infra (internal PyPI / Artifact Registry) for a tiny artifact.
- Verdict: over-engineered for one schema.

**Option B — Generated types from a single source schema (Protobuf, JSON Schema).** Schema file lives in one location, generated code consumed by both repos.
- Pros: machine-checkable single source of truth.
- Cons: build complexity, generation step, generally heavyweight at this surface area.
- Verdict: defer unless the schema grows substantially.

**Option C — Neutral schema doc + symmetric contract tests. (Recommended.)**
1. Author a canonical schema doc in a neutral location (Panoply `strategic-context/contracts/hermes-bigtable-schema.md` is the most discoverable candidate). The doc names column families, key types, value types, and writer/reader expectations, normalized from ADR-003 and the actual reader code in datascience.
2. Update CLAUDE.md in both repos to reference the canonical doc.
3. Replace ADR-003 content with a one-line stub pointing at the canonical doc; preserve title and date for history.
4. Add an analytics-side contract test mirroring `datascience/cloud-run-services/temporal-workers/tests/test_feature_producer_consumer_contract.py`. It asserts that any analytics writer to BigTable uses only the documented column families with documented value types.
5. Extend the existing datascience contract test to also assert readers consume only documented columns.
- Pros: cheap; no new packaging; zero runtime overhead; both agents discover the contract via CLAUDE.md routing.
- Cons: schema isn't expressed as code; relies on docs being maintained.
- Verdict: right-sized. Promote to A or B if the schema grows or the tests prove inadequate.

### Recommended path

Option C, in the order listed above.

### Open questions for grilling

- Canonical home: Panoply `strategic-context/contracts/` vs. `cloud-infrastructure` (where the BigTable instance is provisioned). Panoply wins on agent-discoverability (already in agent context); cloud-infrastructure wins on locality to the resource being described. **Default: Panoply, unless cloud-infrastructure is already a CLAUDE.md-routed location for both repos.**
- Where does the analytics-side contract test live — in athena, in dbt, or in a new top-level test directory? The writers are in athena code paths, so athena is the obvious answer; raised here only because there is no precedent for cross-repo contract tests in analytics.

## Workstream 2 — ML dependency version coordination

### Goal

Prevent silent drift of ML deps that participate in the MLflow handoff. At minimum, fail fast when drift is introduced.

### Options

**Option A — Renovate/Dependabot rule that opens coordinated PRs.**
- Pros: automated; gentle; uses existing tooling.
- Cons: signals drift, doesn't prevent it; still needs human merge in both repos.

**Option B — Pre-merge CI check that fails when ML-handoff deps differ across repos.** Implementation: a small script reads the handoff dep list from both repos and asserts equality. Run in CI on both sides.
- Pros: hard prevention; impossible to merge a drifted bump without a corresponding sibling change.
- Cons: cross-repo CI is awkward (clone the sibling at HEAD, race conditions on merge order). Friction during emergencies (a security bump on one side can't merge until the other is ready).

**Option C — Single canonical pin file.** A `ml-handoff-pins.txt` (or `constraints.txt`) in one location that both repos pull from at install time.
- Pros: single source of truth; impossible to drift by construction.
- Cons: tooling — pip/uv don't natively support cross-repo constraints; needs a small generator step or a constraints file referenced via Git URL/raw URL.

**Option D — Runtime validation extended.** Today `mlflow_model_client.py:120-147` validates sklearn major.minor at load time. Extend to validate the full handoff dep list (numpy, pandas, pyarrow at minimum).
- Pros: backstop catches drift before bad serving.
- Cons: doesn't prevent drift; only detects it after artifacts are produced.

### Recommended path

**A (Renovate) + D (extended runtime validation), with B as a stretch goal.**

- Configure a Renovate rule in both repos that flags any change to the handoff dep list (sklearn, mlflow, numpy, pandas, pyarrow) and opens a tracking issue/PR in the sibling repo. Cheap to set up; coordinates without enforcing.
- Extend the existing `mlflow_model_client.py` validation to assert versions of all handoff deps, not just sklearn. This already catches the most damaging drift; expanding is incremental.
- Defer Option B until A+D demonstrably miss something we care about.

### Open questions for grilling

- Has sklearn major.minor validation actually been enough in practice? If we have no recorded incidents, this whole workstream may rank below current feature work. Worth pulling the incident log before scheduling.
- Should we adopt a uv workspace at `~/src/` level so both repos share lockfiles? Likely overkill — the deploy primitives differ — but naming it for completeness.
- Define the canonical "handoff dep list" once. Sklearn, mlflow, numpy, pandas, pyarrow are the obvious ones; is there anything else (e.g. Python minor version, joblib, scipy)? This list itself is a contract that should live wherever the BigTable schema doc ends up.

## Cross-cutting open questions (relevant to both workstreams)

- **Canonical home convention.** Both workstreams want a neutral place for cross-repo contracts. Picking the home (Panoply `strategic-context/contracts/` is the default proposed) opens the door to lifting the MLflow handoff doc, the BigTable schema, and the ML pin list all into one directory. Worth deciding the home convention *before* starting the work, so the first contract doc establishes the pattern.
- **Priority.** Neither workstream is urgent; we have not been bitten in production yet. PR #122 (MAB / PostHog dry_run) was a different class of issue. Worth weighing against current Hermes feature-launch work before scheduling either.
- **Sequencing.** Workstream 1 (BigTable schema) is more painful to fix later (more places drift can hide); Workstream 2 has a runtime backstop already. If only one happens, do Workstream 1 first.
