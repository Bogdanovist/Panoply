# Solution Design: feature-launch-push

Status: draft

## Overview

A config-driven batch system that re-triggers the Hermes comms plan optimizer for targeted accounts when launching new features. Feature launches are defined as Python classes referencing existing Hermes nudges. A Temporal workflow processes accounts sequentially, calling the existing optimizer activities with `valid_time` set to each user's last session. The policy is modified to give feature launch messages priority over random selection and to bypass holdout.

This project also fully deprecates the legacy Campaign system, which previously handled feature launches via a separate pipeline. All feature launch functionality moves into Hermes, and Campaign-only code is removed.

## Key Decisions

### 1. Call optimizer activities directly, not HermesWorkflow

- **Choice**: The batch workflow calls `cleanup_previous_hermes_messages` + `run_hermes_optimizer_with_persistence` directly as activities, rather than starting HermesWorkflow as a child workflow.
- **Rationale**: HermesWorkflow has a 45-minute wait timer (unnecessary for batch), uses `workflow_id = f"{account_id}_hermes"` with USE_EXISTING conflict policy (would collide with in-progress session workflows), and runs feature computation child workflows (unnecessary overhead for bulk processing — features from BigTable are sufficiently current for inactive users).
- **Alternatives considered**: Starting HermesWorkflow as a child with `wait_time=0` — rejected because it still has workflow ID conflicts and runs unnecessary child workflows. Using a different workflow ID pattern — rejected because two simultaneous optimizers for the same account creates race conditions on cleanup/staging.
- **Trade-off**: We duplicate the cleanup → optimize → persist orchestration that HermesWorkflow does, but the logic lives in the activities themselves, not the workflow. The batch workflow just calls the same activities in the right order.

### 2. FeatureLaunch definition as a Python class with a registry

- **Choice**: New `FeatureLaunch` base class in `campaigns/definitions/` with auto-discovery via a `FeatureLaunchRegistry`. Each launch references a nudge by `message_id` and defines audience criteria.
- **Rationale**: Follows established patterns (HermesMessage subclass discovery, CampaignRegistry decorator). Config-like but Python, consistent with Matt's preference. The existing `feature_launches.py` uses the Campaign system — new Hermes-based launches are a separate definition type.
- **Alternatives considered**: Extending CampaignDefinition — rejected because the Campaign system defines message content inline and has a different delivery pipeline. Hermes-based launches reference nudges from the nudge bank and go through the Hermes optimizer.

### 3. Pass feature_launch_message_ids via PolicyContext

- **Choice**: Add `feature_launch_message_ids: List[str]` to `PolicyContext`. The optimizer activity populates this from active `FeatureLaunch` definitions. The policy uses it to partition messages into priority (feature launch) and regular (random selection).
- **Rationale**: Keeps the nudge definition clean (a nudge doesn't know it's part of a launch). The "launch-ness" is context, not an intrinsic property of the message. When a launch definition is removed, the nudge reverts to normal random selection automatically.
- **Alternatives considered**: Adding `is_feature_launch` flag to HermesMessage — rejected because the same nudge can be both a feature launch message and later an evergreen message.

### 4. Per-message holdout bypass (not journey-level)

- **Choice**: Feature launch messages are always staged with `is_holdout=False`. The journey-level holdout roll still happens, but it only applies to non-feature-launch messages in the journey. This requires the staging loop to accept per-message holdout flags.
- **Rationale**: If we set the entire journey to non-holdout when any feature launch message is present, regular messages would also escape holdout for these users, biasing the experiment.
- **Alternatives considered**: Journey-level bypass (simpler but biases holdout). Separate journey for feature launch messages (over-engineered).

### 5. Add last_hermes_run_at to BigTable for "already processed" detection

- **Choice**: Write a `last_hermes_run_at` UTC epoch timestamp to the `hermes` column family alongside `last_hermes_run_id`. The batch checks this against the launch time to skip already-processed accounts.
- **Rationale**: `last_hermes_run_id` is just a string with no timestamp. BigTable cell timestamps exist but aren't exposed by the current `load_features` API. An explicit column is simpler and more reliable.
- **Note**: This column is written by `run_hermes_optimizer_with_persistence` (existing activity) — needs a small modification to write the timestamp alongside the run_id.

### 6. Audience resolution via BigTable (same as eligibility)

- **Choice**: Use the existing BigTable scan + eligibility operator pattern from `resolve_audience_from_criteria` in `message_staging_activities.py`.
- **Rationale**: Consistent with Matt's decision to use the same source as eligibility checks. The full table scan is a one-time cost at batch start. For large audiences, this is expensive but acceptable since the batch itself runs for hours/days.

### 7. valid_time derived from last_app_session_on

- **Choice**: For each account, read `last_app_session_on` (epoch timestamp) from BigTable features and convert to datetime for `valid_time`. This is the same field used to compute `days_since_last_app_session` in the eligibility system.
- **Rationale**: This is the actual last session time, which is what the scheduling math needs. Using `last_hermes_run_at` would be offset by ~45 minutes (the workflow wait time).

## Component Design

### FeatureLaunch Definition

**Location**: `campaigns/definitions/hermes_feature_launches.py` (new file)

```python
class FeatureLaunch:
    """Base class for Hermes feature launch definitions."""
    nudge_id: str              # References a HermesMessage.message_id
    audience: Dict[str, Any]   # Operator-suffix eligibility criteria
    launch_after: Optional[datetime] = None  # Default: active immediately on deploy

    @property
    def launch_id(self) -> str:
        """Derived from class name, like HermesMessage.message_id."""
```

**Registry**: `FeatureLaunchRegistry` with `get_active_launches(reference_time)` — returns launches where `launch_after` is None or in the past.

**Example**:
```python
class ForYouCardLaunch(FeatureLaunch):
    nudge_id = "for_you_card_announcement"
    audience = {"days_since_last_app_session__lte": 90}
    # No launch_after → starts immediately on deploy
```

### PolicyContext Extension

**Location**: `campaigns/optimizer/policies.py`

Add to `PolicyContext`:
```python
feature_launch_message_ids: List[str] = field(default_factory=list)
```

### RandomExperimentPolicy Modification

**Location**: `campaigns/optimizer/policies.py`

Modified `create_journey()` flow:

1. Filter out sent messages (unchanged)
2. **Partition**: `launch_messages` = messages where `message_id in context.feature_launch_message_ids`, `regular_messages` = the rest
3. **Schedule launch messages first**: iterate `launch_messages` (random order if multiple), schedule each in the first available slot with deterministic timing. Record decisions with `decision_type="FEATURE_LAUNCH_POSITION_N"`.
4. **Fill remaining slots**: from `regular_messages`, random selection up to `MAX_MESSAGES - len(launch_messages)`. Apply holdout to this portion only.
5. **Combine**: launch messages + regular messages = final journey. Journey `is_holdout` reflects the holdout roll but only affects regular messages at staging time.

### FeatureLaunchBatchWorkflow

**Location**: `campaigns/workflows/feature_launch_batch_workflow.py` (new file)

**Workflow ID**: `feature_launch_batch_{launch_id}`

**Parameters**: `launch_id: str`

**Flow**:
1. Read the `FeatureLaunch` definition for `launch_id`
2. If `launch_after` is set and in the future, sleep until then
3. Record `batch_started_at = workflow.now()`
4. **Enumerate audience**: call activity that scans BigTable with `audience` criteria → returns list of `account_ids`
5. **Process sequentially**: for each `account_id`:
   a. Load `last_hermes_run_at` from BigTable hermes column family
   b. If `last_hermes_run_at >= batch_started_at` → skip (already processed via natural session)
   c. Load `last_app_session_on` from BigTable features → convert to `valid_time`
   d. Call `cleanup_previous_hermes_messages(account_id, workflow.now())`
   e. Call `run_hermes_optimizer_with_persistence(account_id, run_id, valid_time, holdout_fraction=0.0)`
   f. Heartbeat with progress (N of total)
6. **continue_as_new** every N accounts (e.g., 1000) to prevent unbounded workflow history
7. On completion, log summary

**Idempotency**: Temporal's workflow ID deduplication prevents double-starts. If the worker restarts mid-batch, Temporal resumes from the last checkpoint.

**Startup trigger**: On worker startup, check all `FeatureLaunch` definitions. For any active launch without a running/completed batch workflow, start one. Uses `WorkflowIDConflictPolicy.USE_EXISTING` so redeployments are no-ops.

### Optimizer Activity Modification

**Location**: `campaigns/activities/comms_plan_optimizer_activities.py`

`run_hermes_optimizer_with_persistence` needs two changes:
1. Write `last_hermes_run_at` (UTC epoch) alongside `last_hermes_run_id`
2. Populate `feature_launch_message_ids` in `PolicyContext` from `FeatureLaunchRegistry.get_active_launches()`

### Batch Audience Activity

**Location**: `campaigns/activities/feature_launch_activities.py` (new file)

New activity: `resolve_feature_launch_audience(audience_criteria) → List[str]`

Reuses the BigTable scan pattern from `resolve_audience_from_criteria` in `message_staging_activities.py`, adapted for Hermes eligibility operators.

## Data Flow

```
Deploy with new FeatureLaunch definition
  │
  ▼
Worker startup → check active launches → start FeatureLaunchBatchWorkflow
  │
  ▼
Enumerate audience (BigTable scan with eligibility criteria)
  │
  ▼
For each account (sequential):
  │
  ├─ last_hermes_run_at >= batch_started_at? → SKIP
  │
  ├─ Load last_app_session_on → valid_time
  │
  ├─ cleanup_previous_hermes_messages(account_id, now)
  │     └─ Deletes all pending messages scheduled after now
  │
  └─ run_hermes_optimizer_with_persistence(account_id, run_id, valid_time)
        ├─ Load features, sent history, metadata
        ├─ Evaluate eligibility (includes new nudge)
        ├─ Policy: schedule feature launch messages first (bypass holdout)
        ├─ Policy: fill remaining slots randomly (normal holdout)
        ├─ Stage messages in BigTable
        ├─ Write last_hermes_run_at + last_hermes_run_id
        └─ Persist analytics
```

**For natural session-triggered workflows** (unchanged flow, but with awareness of launches):
- `run_hermes_optimizer_with_persistence` now reads active feature launches
- Policy gives priority to feature launch messages
- User who had a session after deploy gets the feature launch message naturally
- Batch later skips them via `last_hermes_run_at` check

## Campaign System Deprecation

The legacy Campaign system has a separate pipeline for feature launches (audience resolution → message staging → batch delivery). Hermes-based feature launches replace this entirely. All Campaign-only code should be removed to keep the codebase clean.

### Dependency Analysis

**Campaign-only code (safe to remove):**
- `campaigns/registry.py` — CampaignDefinition, CampaignRegistry, CampaignMode, register_campaign decorator
- `campaigns/models.py` — CampaignConfig, CampaignStatus, etc.
- `campaigns/definitions/feature_launches.py` — Old campaign-based feature launches
- `campaigns/definitions/ux_campaigns.py` — UX/survey campaigns
- `campaigns/definitions/evergreen_campaigns.py` — Evergreen campaigns
- `campaigns/definitions/__init__.py` — Remove campaign definition imports (keep hermes_messages)
- `campaigns/workflows/campaign_scheduler_workflow.py`
- `campaigns/workflows/campaign_delivery_workflow.py`
- `campaigns/workflows/campaign_window_workflow.py`
- `campaigns/workflows/campaign_router_workflow.py`
- `campaigns/activities/message_staging_activities.py`
- `campaigns/activities/message_delivery_activities.py`
- `campaigns/activities/notification_delivery_activity.py`
- `campaigns/activities/alias_mapping_activities.py`
- `campaigns/activities/start_external_workflow_activity.py`
- `campaigns/channels/` — entire directory (base.py, push.py, registry.py)
- `campaigns/audience/spec.py` — AudienceSpec (campaign-only)

**Shared code that Patterns depends on (must keep or relocate):**
- `campaigns/constants.py` — DeeplinkAction, DeeperInsightsParams, payload keys → **keep as-is** (stable, used by patterns and Hermes)
- `campaigns/audience/eligibility.py` — EligibilityService → **keep** (used by patterns)
- `campaigns/audience/hermes_eligibility.py` — HermesEligibilityService → **keep** (Hermes)
- `campaigns/audience/timestamp_mapping.py` → **keep** (shared)
- `campaigns/activities/shared_activity_clients.py` → **keep** (Hermes activities)

**Pattern imports that need relocation:**
- `from campaigns.services.notification_service import NotificationService` → Move `NotificationService` to `campaigns/services/` or a shared location. Patterns use it for send time optimization. The service itself is generic (send time calculations, frequency cap checks) — not campaign-specific logic.
- `from campaigns.registry import SendTimeStrategy` → Move `SendTimeStrategy` enum to `campaigns/constants.py` (where other shared enums already live).

**Hermes system (stays):**
- `campaigns/workflows/hermes_workflow.py`, `hermes_delivery_workflow.py`, `hermes_e2e_test_workflow.py`
- `campaigns/definitions/hermes_messages.py`
- `campaigns/optimizer/` — entire directory
- `campaigns/activities/comms_plan_optimizer_activities.py`, `hermes_delivery_activities.py`, `hermes_analytics_activities.py`, `hermes_e2e_test_activities.py`

### Cleanup Approach

1. **Relocate shared code first**: Move `SendTimeStrategy` to constants.py, keep `NotificationService` in place (patterns still import it). Update imports.
2. **Remove campaign-only files**: Delete campaign workflows, activities, definitions, channels, models, registry, AudienceSpec.
3. **Update `campaigns/definitions/__init__.py`**: Remove imports of deleted definition modules.
4. **Update worker registration** (`datascience_worker.py`): Remove campaign workflow/activity registrations.
5. **Clean up BigTable client**: Identify and remove campaign-specific staging methods (the `staged_msg#` row pattern used by campaigns, as opposed to `hermes_msg#` used by Hermes). Be careful here — verify no other system uses these methods.
6. **Remove tests** for deleted campaign code.

### Risk Mitigation

- **Pattern notifications must not break.** Verify all pattern imports resolve after cleanup. Run pattern tests.
- **Hermes delivery must not break.** The HermesDeliveryWorkflow and its activities are completely separate from campaign delivery. Verify no cross-references.
- **Worker startup must not break.** Campaign workflows/activities are registered conditionally (CAMPAIGN_WORKER_ENABLED flag). Removing them from registration is safe, but verify no other conditional logic depends on them.

## Review Plan

### Requires Human Review

- **Policy priority logic** (`policies.py` changes): Novel behavior — feature launch messages override random selection and bypass holdout. This is the core behavioral change and affects all users.
- **FeatureLaunch definition pattern** (new base class + registry): Sets the precedent for how all future launches are configured. Worth reviewing the API surface.
- **FeatureLaunchBatchWorkflow**: New workflow orchestrating bulk account processing. Review sequential processing, continue-as-new boundary, and the startup trigger mechanism.
- **Per-message holdout staging**: Changes the staging loop to support per-message holdout flags instead of journey-level only.

### Autonomous

- **last_hermes_run_at column write**: Small addition to existing activity — write a timestamp alongside the existing run_id write.
- **Audience resolution activity**: Reuses existing BigTable scan pattern.
- **Tests**: Unit tests for policy priority, integration tests for batch workflow.
- **Worker registration**: Registering new workflow/activities with the Temporal worker.
- **Campaign cleanup — shared code relocation**: Moving SendTimeStrategy to constants.py, updating pattern imports. Mechanical changes.
- **Campaign cleanup — file removal**: Deleting campaign-only files. Straightforward once shared code is relocated. Autonomous, but run full test suite to verify nothing breaks.
