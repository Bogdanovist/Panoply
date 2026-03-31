# Intent: feature-launch-push

## Problem

Hermes schedules push notifications at the end of a user's session — future messages are planned based on what the user did, then cleared and re-planned when the next session occurs. This reactive pattern works well for ongoing engagement but creates a gap when launching new features: there's no mechanism to proactively reach users who haven't had a recent session. Lapsed or infrequent users — often the highest-value targets for re-engagement — won't see the new nudge until they happen to come back.

## Approach

Build a **feature launch batch process** that re-triggers the existing Hermes end-of-session workflow for accounts matching a configurable audience definition. By going through the standard Hermes pipeline, feature launch notifications inherit all existing frequency capping, eligibility checks, and scheduling logic — no parallel notification system needed.

### How it works

1. **Config-driven feature launches**: Each feature launch is defined as a Python definition (similar to nudge definitions) specifying:
   - Which nudge to send (by reference — the nudge itself lives in the standard nudge bank)
   - Audience criteria using the existing operator-suffix eligibility syntax (e.g., `{"days_since_last_session__gt": 7, "is_plus_subscriber__eq": 1}`), evaluated against BigTable account features (same source as existing eligibility checks)
   - Optional `launch_after` datetime — if omitted, the batch starts executing immediately on deploy; if set, execution is deferred until that time (useful for pre-staging launches)
   - The audience definition is *separate* from the nudge's own eligibility — the audience controls who gets batch-processed, the nudge eligibility controls whether the nudge is actually eligible for that user
   - The config is **self-resolving**: the launch definition plus the current time is sufficient to determine whether a launch is pending, in-progress, or completed — no manual cleanup needed

2. **Batch processing workflow** (Temporal):
   - Query for accounts matching the audience definition
   - Iterate **sequentially** (not parallel) to avoid overloading Temporal workers
   - For each account:
     - Check if `last_hermes_run_id` timestamp is after the feature launch deployment time → **skip** (already processed via natural session)
     - If not yet processed, trigger HermesWorkflow with `valid_time` set to the user's **last actual session time** (not current time), so scheduling math (e.g., "send 7 days after last session") remains correct
   - Processing can take hours or days — that's acceptable

3. **Policy priority for feature launch messages**:
   - Feature launch messages are scheduled **deterministically** in the first available slot — they override the normal random selection
   - They **bypass holdout** — all eligible users receive the message
   - They **count toward MAX_MESSAGES** (currently 5)
   - Multiple active feature launches: all get priority slots, randomly selected among them, then remaining slots filled via normal randomization
   - This is a simple initial approach — the policy will get smarter over time

4. **Natural deduplication**: Two layers ensure users aren't processed or messaged redundantly:
   - **Batch-level**: If a user has had a natural session after the feature launch deployment (detected via `last_hermes_run_id` timestamp), the batch skips them — their session-triggered workflow already evaluated the new nudge.
   - **Message-level**: Hermes already has send-once deduplication as default behavior. `RandomExperimentPolicy` filters out messages that appear in `sent_message_history` (loaded from BigTable — all `hermes_msg#` rows with `status="sent"` for the account). Once a nudge has been delivered, it's permanently excluded from future selections. This ensures feature launch messages are only ever sent once per user.

### What stays the same

- Nudges are added to the standard nudge bank (not defined inline in the feature launch config)
- All frequency capping and eligibility rules apply as normal
- The existing cleanup-on-new-session logic works unchanged — if a user starts a new session after the batch processes them, pending messages get cleared and re-planned as usual

## Resolved Questions

- **Audience query source**: BigTable account features — same source as existing eligibility checks, keeping it consistent.
- **Launch timing**: Starts on deploy by default. Optional `launch_after` datetime for pre-staging.
- **Monitoring**: Standard activity logging for now — no dedicated dashboard needed at this stage.
- **Config lifecycle**: Self-resolving — the config definition plus current time determines state (pending/in-progress/completed). No manual cleanup required.
- **Send-once guarantee**: Already handled by Hermes's default deduplication — `sent_message_history` in BigTable prevents re-selection of delivered messages. No special handling needed.

## Success Criteria

- [ ] New feature launches can be configured via Python definitions without writing bespoke logic
- [ ] Batch process correctly triggers Hermes for targeted accounts using `valid_time` for scheduling math
- [ ] Feature launch messages get priority scheduling, bypass holdout, and respect MAX_MESSAGES
- [ ] Users who have had a natural session after deployment are correctly skipped
- [ ] Sequential processing doesn't overload Temporal workers
- [ ] Each user receives a given feature launch message at most once (verified via existing send-once deduplication)
- [ ] Existing Hermes behavior is unchanged for normal session-triggered flows
- [ ] Legacy Campaign system fully deprecated — all campaign-only code removed
- [ ] Pattern notifications continue working (shared code preserved/relocated)

## Context

This is a step toward more proactive, targeted communication capabilities in Hermes. The current reactive model (session-triggered only) limits the ability to reach users at strategically important moments. Feature launches are the first use case, but the batch-trigger-with-audience-filter pattern could extend to other proactive outreach scenarios (e.g., re-engagement campaigns, seasonal messaging).

The policy priority mechanism (feature launch messages override randomization) is intentionally simple. It will evolve as the broader policy framework matures through the feature-library project.
