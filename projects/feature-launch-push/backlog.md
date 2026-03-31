# Backlog: feature-launch-push

## Ready

### Feature Launch Functionality

- [ ] **Add `last_hermes_run_at` to optimizer activity** — Modify `run_hermes_optimizer_with_persistence` to write a UTC epoch timestamp to BigTable `hermes` column family alongside `last_hermes_run_id`. Small, isolated change. (Autonomous)
- [ ] **Create FeatureLaunch definition + registry** — New base class in `campaigns/definitions/hermes_feature_launches.py` with `launch_id`, `nudge_id`, `audience`, optional `launch_after`. `FeatureLaunchRegistry` with auto-discovery and `get_active_launches()`. (Human review)
- [ ] **Add `feature_launch_message_ids` to PolicyContext** — Extend PolicyContext dataclass. Update optimizer activity to populate from active launches. (Autonomous)
- [ ] **Modify RandomExperimentPolicy for launch priority** — Partition eligible messages into launch/regular. Schedule launch messages first (deterministic, bypass holdout). Fill remaining slots randomly. Per-message holdout at staging. (Human review)
- [ ] **Build audience resolution activity** — New `resolve_feature_launch_audience` activity using BigTable scan + eligibility operators. Reuse pattern from `resolve_audience_from_criteria`. (Autonomous)
- [ ] **Build FeatureLaunchBatchWorkflow** — Temporal workflow: enumerate audience, process sequentially, cleanup + optimize per account, continue-as-new for long batches, worker startup trigger. (Human review)
- [ ] **Verify valid_time + cleanup behavior end-to-end** — Confirm that `valid_time = last_app_session_on` produces correct scheduling math. Confirm cleanup deletes future pending messages correctly when batch re-triggers. (Autonomous — test-driven)

### Campaign System Deprecation

- [ ] **Relocate shared code** — Move `SendTimeStrategy` to `campaigns/constants.py`. Verify `NotificationService` stays accessible for patterns. Update pattern imports. (Autonomous)
- [ ] **Remove campaign-only files** — Delete campaign workflows (scheduler, delivery, window, router), campaign activities (staging, delivery, notification), campaign definitions (feature_launches, ux_campaigns, evergreen_campaigns), campaign channels, models, registry, AudienceSpec. (Autonomous — run full test suite)
- [ ] **Update worker registration** — Remove campaign workflow/activity registrations from `datascience_worker.py`. Keep Hermes and pattern registrations. (Autonomous)
- [ ] **Clean up BigTable client** — Identify and remove campaign-specific staging methods (`staged_msg#` pattern) if no other system uses them. Verify before removing. (Autonomous — careful)
- [ ] **Remove campaign tests** — Delete test files for removed campaign code. (Autonomous)

## Later

- [ ] **First real feature launch** — Add a FeatureLaunch definition for an actual feature, deploy, and monitor.
- [ ] **Consider renaming `campaigns/` package** — With campaigns removed, the package is effectively `hermes/` + shared notification infra. A rename could improve clarity but is cosmetic and can wait.
