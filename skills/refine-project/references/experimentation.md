# Strategic Context: Experimentation & Personalization

## Theme

Building the capability to run experiments well and make increasingly personalized, data-driven decisions about the user experience — from onboarding flows to upsell screens to in-app content.

## Current State

**PostHog experiments** are the primary experimentation tool, used mainly for onboarding decisions (which upsell screen variant, onboarding step ordering). These are evergreen experiments managed as multi-arm bandits — allocation percentages are adjusted over time to exploit winning variants while continuing to explore alternatives.

**Hermes** (in the datascience repo) is the existing personalization service. It operates asynchronously: decisions are computed at the end of a session and applied to the next session. This means it can't make real-time decisions during a user's first interaction (e.g., which onboarding screen to show), which is why PostHog feature flags fill that gap for onboarding experiments.

**Feature-library** (in-flight project) is building propensity models and policy classes for the asynchronous Hermes decisions — the "what to recommend next session" problem.

**MAB PostHog Allocator** (shipped, 2026-03-23) automated the multi-arm bandit allocation process with bias correction. Runs as a daily Cloud Run job (`athena-mab-debug-pipeline`). Uses a stratified Beta model for bias correction, Thompson Sampling with guardrails for allocation, and writes decisions to BigQuery (`mab_allocation_history`) for auditability. Streamlit dashboard page shows experiment performance. Component specs in `docs/specs/mab-*.md`. Known follow-up: migrate from standalone CLI to Temporal workflow pattern (currently the only pipeline not on Temporal).

## Direction

The strategic trajectory is toward **real-time contextual multi-arm bandits**:

1. **Done**: Population-level MAB via PostHog (same allocation % for all users). Automated with bias correction. ← *MAB Allocator project (shipped)*
2. **Next**: Contextual bandits using early-known user attributes (iOS/Android, country, acquisition channel) to personalize variant assignment per-user in real time.
3. **Eventually**: Unified personalization system where Hermes (or its successor) handles both session-level recommendations and real-time experiment assignment, with a shared policy framework.

The MAB Allocator is designed with this trajectory in mind: the core allocation logic (bias correction model, Thompson Sampling, policy guardrails) is separated from the PostHog-specific I/O layer. The PostHog parts are transitional; the statistical methodology is strategic and should evolve into the broader personalization system.

The feature-library project is building policy classes on a parallel track. These two streams should eventually be harmonised, but they're not blocking each other — the MAB Allocator is scoped as an MVP that can be merged with the feature-library approach in follow-up work.

## Constraints

- PostHog feature flags are the mechanism for experiment assignment — the app reads flags at runtime, so allocation changes must go through PostHog's API.
- First-flag-value-wins: PostHog reassigns users when allocation percentages change. Our analysis must use first-exposure only.
- The analytics repo architecture is in flux (pipeline separation changes by a colleague), so new work should minimize coupling to pipeline patterns. The MAB allocator is a standalone CLI (`mab-allocator`) not yet on Temporal — migrating it is a follow-up task.
- Hermes is in the datascience repo. The feature-launch-push project is the first managed work in this repo.
