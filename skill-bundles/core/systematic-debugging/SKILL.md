---
name: systematic-debugging
description: >
  Disciplined diagnosis loop for data-pipeline bugs: bad rows, broken queries,
  dropped data, dbt test failures, Temporal workflow crashes, perf regressions.
  Pin the data, build a deterministic check, hypothesise before instrumenting.
  Use when something is broken, throwing, returning the wrong number, or running
  much slower than it used to.
---

# Systematic Debugging

A discipline for data-pipeline bugs. Skip phases only when explicitly justified.

The stack assumed throughout: **BigQuery** (warehouse), **dbt** (transforms),
**Temporal** (orchestration), **BigTable** (raw event source), **pandas** (in-Python
shaping), **pytest** (code tests), **dbt singular tests** (data assertions),
**Streamlit** (dashboards), **Hex** (ad-hoc analysis). Adapt the *tools* to your
context, but the *phases* don't change.

## Phase 1 — Pin the data, then build a deterministic check

**THIS IS THE SKILL.** Everything else is mechanical. If you can ask "did the
bug show up?" in under five seconds, against data that doesn't move, you will
find the cause. If you can't, no amount of staring at SQL will save you.

Live data drifts. A bug you chase against `prod` or even `*-debug` BigQuery
datasets will be a different bug tomorrow. **Detach from live sources first.**

### Pin the data

In rough order of preference:

1. **`bq query --destination_table` into a personal scratch dataset** with the
   minimal slice that reproduces. One day, one experiment arm, one
   `account_id` — whatever isolates it.
2. **`bq extract` to GCS, then `gsutil cp` to a local Parquet/CSV** under
   `tests/fixtures/` or `~/scratch/`. Now the data lives on your laptop and
   nothing upstream can move it.
3. **`pandas.read_gbq(...).to_parquet(...)`** from a Python REPL or a one-shot
   script in `athena/scripts/` (or the equivalent scripts directory in the
   repo you're working in). That directory is the project-blessed home for
   ad-hoc analysis — use it.
4. **BigTable**: dump the relevant row-key range to JSON Lines via a script
   modelled on `athena/athena/etl/bigtable_account_events.py`. Don't debug
   against live BigTable — checkpoint state can mask the bug.
5. **dbt**: `dbt run --select +<model>+ --target debug` against a static
   upstream snapshot, then `dbt show --select <model>` to inspect output.
   Compile-only via `dbt compile --select <model>` if you only need to read
   the rendered SQL.

### Build the check

The "test" is whatever returns PASS/FAIL on the **specific symptom the user
reported** (not a similar-shaped symptom nearby).

- **Wrong aggregate** → SQL `SELECT` with the expected vs actual side by side,
  or `assert df['col'].sum() == expected` in a one-liner.
- **Missing rows** → `SELECT key FROM expected EXCEPT DISTINCT SELECT key FROM actual`.
- **Duplicates / row explosion** → `SELECT key, COUNT(*) FROM t GROUP BY key HAVING COUNT(*) > 1`.
- **Wrong join cardinality** → run the join, group by the left-side PK, assert
  count == 1 (or whatever the contract is).
- **dbt test failure** → the failing singular test in `dbt/tests/unit/` or
  `dbt/tests/e2e/` *is* the check. Don't write a new one until Phase 5.
- **Temporal workflow crash** → minimal workflow input that reproduces, run via
  `uv run python -m <project>.temporal.worker` against a debug Temporal namespace.
- **Streamlit / Hex render bug** → headless Streamlit (`streamlit run …
  --server.headless true`) or a Hex thread, but pin the input data first.

### Iterate on the loop itself

A 30-second flaky check is barely better than no check. A 2-second
deterministic check is a debugging superpower.

- **Faster.** Shrink the snapshot. One `account_id` beats a million. One day
  beats a year. `LIMIT` aggressively.
- **Sharper.** Assert on the *specific* wrong number, not "result is non-empty".
- **More deterministic.** Pin time (`@frozen_time` / explicit `CURRENT_DATE`),
  pin RNG, pin model versions, freeze the snapshot to disk.

### When you genuinely cannot pin the data

Stop and say so explicitly. List what you tried. Then ask the user for
**exactly one** of:

- A sanitised export of the offending slice (account_id, date range, experiment arm)
- Read access to a non-prod replica or a BigQuery snapshot of the relevant tables
- Permission to add temporary instrumentation to the live pipeline (`logging.info` calls
  with `[DEBUG-xxxx]` tags — see Phase 4)

Do **not** proceed to hypothesise without a loop. You'll burn the user's time
and your context.

## Phase 2 — Reproduce

Run the check. Watch the bug appear. Confirm:

- [ ] The check produces the failure mode the **user** described — not a
      different failure that happens to be nearby. Wrong bug = wrong fix. A row
      count off by 17 is not the same bug as one off by 1700; a `NULL` is not a
      `0`; `delivered_at IS NULL` is not the same as `delivered_at` in the
      future.
- [ ] The failure is reproducible across multiple runs (or, for genuinely
      non-deterministic bugs like Temporal worker races, reproducible at a high
      enough rate to debug against — keep raising the rate until it is).
- [ ] You have captured the exact symptom (failing query output, dbt test row
      count, error message, slow timing) so Phase 5 can verify the fix actually
      addresses it.

Do not proceed until you reproduce.

## Phase 3 — Hypothesise

Generate **3–5 ranked falsifiable hypotheses** before testing any of them.
Single-hypothesis generation anchors on the first plausible idea — usually
wrong.

Each hypothesis must make a **prediction**:

> "If <X> is the cause, then <changing Y> will make the bug disappear / make it
> worse / change the failing row count from N to M."

If you can't state the prediction, the hypothesis is a vibe — sharpen or discard.

### The data-pipeline usual suspects

Bias your ranking toward these. They are vastly more common than novel causes.

1. **Join cardinality** — silent M:M where 1:1 was assumed. Row explosion or
   row loss. *Probe: group-by left-PK, count.*
2. **NULL semantics** — `NULL ≠ ''`, `NULL ≠ 0`, `WHERE x != 'foo'` excludes
   NULLs, `COUNT(col)` skips NULLs but `COUNT(*)` doesn't, `SUM` over all-NULL
   returns NULL not 0.
3. **Timezone / date-vs-timestamp** — UTC boundary slip, naive vs aware,
   `DATE(timestamp)` in the wrong TZ. `assert_timing_sanity` exists in
   `dbt/tests/unit/` *because this bites repeatedly*.
4. **Filter / aggregation ordering** — `WHERE` before vs after `JOIN` /
   `GROUP BY`; `HAVING` vs `WHERE`; window function evaluated before the
   `WHERE` you thought filtered its input.
5. **Control-group / counterfactual contamination** — control members
   accidentally delivered to, or test members in the control measurement.
   `assert_control_group_not_delivered` exists for this; it is currently
   downgraded to `warn` while a suspected upstream DQ issue is investigated —
   do not assume `warn` means "fine".
6. **Referential integrity** — child rows whose parent doesn't exist (or no
   longer exists). `assert_hermes_referential_integrity` is the existing
   pattern.
7. **BigTable extraction state** — checkpoint resumed from a stale row key,
   partial extraction, late-arriving events with backdated timestamps that
   landed *before* the checkpoint moved past them. See
   `athena/athena/etl/_checkpoint.py`.
8. **Temporal non-determinism** — workflow code reading wall-clock time, RNG,
   external state, or iterating over an unordered map. Workflows must be
   deterministic; activities are where side effects live.
9. **dbt model staleness / wrong `ref()`** — model selected without its
   upstreams (`dbt run --select model` not `+model`), stale incremental, wrong
   `target`, env-var override pointing at the wrong dataset.
10. **Engine semantic drift** — `DISTINCT`, `ORDER BY NULLS FIRST/LAST`,
    division by zero, integer division, string equality with whitespace, and
    timestamp precision differ between BigQuery, pandas, and any local
    DuckDB-style probe you're using to sanity-check.
11. **Schema drift upstream** — BigTable column family added/removed, source
    PostHog action renamed, seed CSV columns reordered. Check `git log` on
    `dbt/seeds/` and the relevant staging models.
12. **Sample bias** — works on debug dataset because debug doesn't have the
    edge case. Confirm the offending row exists in your snapshot.

**Show the ranked list to the user before instrumenting.** They often have
context that re-ranks instantly ("we just promoted a new champion model" /
"marketing backfilled that source yesterday" / "there's a known TZ issue with
the new tapped_at field"). Cheap checkpoint, big time saver.

## Phase 4 — Instrument

Each probe must map to a specific prediction from Phase 3. **Change one
variable at a time.**

### Tool preference for data work

1. **Inspect the data first, not the code.** `df.describe()`, `df.head(20)`,
   `SELECT * FROM t LIMIT 20`, `bq show <table>`. Most data bugs are visible
   in 20 rows.
2. **Cardinality probes between every transform stage.**
   ```sql
   SELECT key, COUNT(*) FROM stage_n GROUP BY key HAVING COUNT(*) > 1
   ```
3. **Diff intermediate stages.** Snapshot the output of stage N-1 and stage N
   to Parquet. `pandas.testing.assert_frame_equal` or a SQL `EXCEPT DISTINCT`
   in both directions. Find the *first* stage where the bug appears.
4. **`bq query --dry_run`** for cost / bytes-scanned regressions, and
   BigQuery's execution-details pane (or `INFORMATION_SCHEMA.JOBS`) for query
   plan and stage timings. Measure first, fix second — never guess at perf.
5. **dbt: `dbt show --select <model> --limit 100`**, `dbt compile --select
   <model>` to read rendered SQL, `dbt run --select +<model>+` to rebuild with
   upstreams.
6. **Temporal: replay workflow history** locally against the failing workflow
   ID. The replay test catches non-determinism the live worker missed.
7. **`logging` (stdlib) at activity / function boundaries.** Tag every debug
   line with a unique prefix:
   ```python
   logger.info("[DEBUG-a4f2] partition=%s rowcount=%d", partition, len(df))
   ```
   Cleanup at the end is one `grep -r "\[DEBUG-a4f2\]"`. Untagged logs
   survive; tagged logs die.

Never "log everything and grep". Targeted probes that distinguish hypotheses.

## Phase 5 — Fix + regression test

Write the regression test **before the fix** — but only at the **correct
seam**.

A correct seam is one where the test exercises the **real bug pattern as it
occurs at the call site**. A unit test that mocks away the join doesn't catch
join-cardinality bugs. A pytest that builds a tiny pandas DataFrame doesn't
catch a BigQuery-specific NULL handling difference.

### Seam menu — pick the highest-fidelity one available

1. **dbt singular test in `dbt/tests/unit/` or `dbt/tests/e2e/`** — this is the
   canonical regression-test pattern in this codebase. Six exist already
   (`assert_timing_sanity`, `assert_hermes_referential_integrity`,
   `assert_control_group_not_delivered`, `assert_recent_data_completeness`,
   `assert_hermes_fallback_delivers`, `assert_asa_resolution_rate`). Add a
   seventh. SQL that returns failing rows; zero rows = pass.
2. **dbt generic test in `schema.yml`** — for column-level invariants
   (`unique`, `not_null`, `accepted_values`, `relationships`). Use when the
   invariant is single-column.
3. **pytest under `<project>/tests/`** — for Python code paths
   (Temporal activities, ETL transforms, ML scoring). Mirror the existing test
   layout (`test_etl/`, `test_temporal/`, `test_models/`).
4. **Temporal workflow replay test** — for non-determinism bugs in workflow
   code. See `atlas/tests/test_temporal/`.
5. **Pinned-fixture pytest** — Parquet under `tests/fixtures/`, loaded into a
   pandas DataFrame, transformation applied, assertion checked. Use when the
   bug is in pandas-side shaping logic.

If no correct seam exists — the transform is one giant SQL with no testable
boundary, or the bug only appears in a Temporal workflow that can't be
isolated — **that itself is the finding.** Note it. Flag for refactor in
Phase 6. Do not write a fake test at the wrong seam; it gives false
confidence.

If a correct seam exists:

1. Turn the minimised repro into a failing test at that seam.
2. Watch it fail.
3. Apply the fix.
4. Watch it pass.
5. Re-run the Phase 1 check on the original (un-minimised) snapshot.

### On test severity

The existing `assert_control_group_not_delivered` is downgraded to `severity:
warn` while the upstream DQ issue is investigated. That is the correct
pattern when the assertion is right but the data is wrong and outside your
control. Do **not** delete the test, do not move it to `error` and ignore CI
failures, and do not silently `LIMIT 0` it. Downgrade with a comment that
links to the investigation.

## Phase 6 — Cleanup + post-mortem

Required before declaring done:

- [ ] Original snapshot check no longer reproduces (re-run Phase 1)
- [ ] Regression test passes — `make test` (pytest), `make dbt-parse`, and the
      relevant `dbt test --select <test_name>` all green. Or absence of seam
      documented.
- [ ] All `[DEBUG-...]` instrumentation removed
      (`grep -rn "\[DEBUG-" .` returns nothing)
- [ ] Throwaway scratch BigQuery tables deleted (`bq rm -f -t
      <project>:<scratch_dataset>.<table>`)
- [ ] Local Parquet snapshots either deleted or promoted to
      `tests/fixtures/` with a comment naming the bug they pin
- [ ] Reusable analysis scripts promoted to `<project>/scripts/` (don't leave
      them in `~/scratch/`)
- [ ] The hypothesis that turned out correct is stated in the commit message
      — so the next debugger learns

### Then ask: would a data-quality check at the boundary have caught this?

Most data bugs are recurrences of a bug that wasn't constraint-checked at
ingest or staging. If the answer is yes, **add the check now**:

- New **dbt singular test** for cross-table invariants
- New **dbt generic test** in the relevant `schema.yml` for column invariants
- **`dbt source freshness`** entry if it was a staleness bug
- **Activity-level assertion** in the Temporal workflow if it was a workflow-input bug

Make the recommendation **after** the fix is in, not before — you have more
information now than when you started.

## Red flags: you're skipping investigation

| Thought                                       | Reality                                       |
| --------------------------------------------- | --------------------------------------------- |
| "Let me just rerun the dbt model"             | Masking, not diagnosing                       |
| "I'll add a `WHERE x IS NOT NULL` and see"    | Guessing without a hypothesis                 |
| "The Temporal workflow probably just retried" | Workflows are deterministic; find out why     |
| "It works in debug, must be a prod thing"     | Pin the prod data and reproduce locally       |
| "This usually fixes it"                       | Past fixes don't explain current bugs         |
| "I don't have time to pin the data"           | You don't have time *not* to                  |

## When to question the architecture

If you've attempted three or more fixes and the bug persists, or if Phase 5
reveals there's no correct seam to lock down the bug:

**Stop fixing. Question the architecture.** A bug that has no testable seam
is a design problem, not a code problem. Use AskUserQuestion to flag it
before continuing — the user may want to scope a refactor, or accept the bug
with a documented workaround, or escalate.
