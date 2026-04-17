# Organizational Context

Last updated: 2026-03-06

## Who

**Matt** — Head of Customer at **Human Health**, a direct-to-consumer health app that helps people manage chronic illness. Matt sits across data and growth, acting as the glue between marketing (top of funnel), data science (models and personalization), and product (feature strategy).

Matt is not part of the product engineering team — there's a separate team that handles day-to-day product delivery. Matt shapes key features (especially AI-powered ones), owns marketing and product analytics, and builds the personalization systems that drive engagement and conversion.

## What We're Building

### The Big Picture

End-to-end revenue optimization and customer engagement for Human Health — from marketing attribution at the top of funnel through to subscriber conversion and retention.

The Human Health app has a concept called **"the assistant"** — an in-app personalization engine that suggests actions to users: daily health tasks, articles, features to explore, and upgrade prompts for the paid subscription. The goal is to make these suggestions smart, personalized, and increasingly AI-driven.

Matt's work spans:
- **Marketing analytics** — attribution, campaign performance, top-of-funnel optimization
- **Product analytics** — user behavior, engagement patterns, feature adoption
- **Personalization models** — algorithms that decide what to show each user, when to send push notifications, which emails to trigger
- **Actionable dashboards** — Streamlit apps that don't just report data but let the marketing team take action directly (e.g., configure a new notification type and deploy it)
- **AI-first analytics** — agents that interpret data daily, surface opportunities and issues, and recommend actions

### Repositories

**Analytics repo** (monorepo, registered as `analytics`)
- Data pipelines that transform source data into mart tables
- Model development and training
- Streamlit dashboards for marketing and product teams
- **Not user-facing** — this is the safe repo for fast iteration. If things break, no users are affected. This is where agent-driven development can move fastest.

**Data Science repo** (`datascience`)
- Live endpoints that serve personalization decisions to the app backend
- Hermes (the personalization service) lives here
- **User-facing** — changes here directly affect the app. Requires more care, more testing, more review. The analytics/datascience repo boundary is a deliberate safety boundary, especially important with agent-driven development.

**Cloud Infrastructure repo** (`cloud-infrastructure`)
- Shared Terraform layer — all GCP infrastructure lives here (Cloud Run, BigQuery, IAM, networking)
- One directory per GCP project, shared modules for reusable components
- **Supporting repo** — when work in analytics or datascience needs infrastructure changes, those changes are PRs here

### Key Insight for Agents

The analytics repo is where most work happens. It's designed to be safe for fast iteration. The data science repo is where tested, validated models get deployed as live services — that's the careful step. Agents should understand this boundary and adjust their confidence and caution accordingly. Infrastructure changes (new datasets, service accounts, IAM bindings, Cloud Run services) are always PRs to cloud-infrastructure, never inline in the application repos.

## How Matt Works

### Preferences

- **Simplicity first. Always.** Agent-driven development can produce large, sprawling codebases fast — that's the risk, not the benefit. Before writing any code, understand the problem deeply. Prefer solutions that remove code and reduce complexity over ones that add it. Reuse existing components. If a fix introduces a new mechanism (timer, flag, wrapper, polling loop, process), that's a smell — the system probably already has something that should handle the case. Spend the extra tokens to think carefully and build clean, maintainable systems. Sloppy code — even in spikes — compounds into tech debt that slows everything down. The goal is a small, well-understood codebase, not a large one.
- **Don't over-prescribe.** Give agents flexibility to reason about the best approach. Avoid rigid processes when intelligent judgment would serve better.
- **Bias to action, but ask when in doubt.** Agents should have initiative like good engineers — but the judgment of when to act vs. when to ask should improve over time through feedback.
- **Small/confident changes can be done speculatively** — do the work but don't commit it until the human approves. Large/expensive work should wait for approval before starting.
- **Organizational context enables good trade-offs.** The reason for this document: when agents understand the business context, they make better subtle decisions in the minutiae of implementation — just like a good engineer with organizational awareness.
- **Quality is non-negotiable but shouldn't slow velocity.** Ship fast, but ship solid, maintainable, functional code. Guardrails and tests are investments in going faster, not obstacles.
- **Decision visibility over permission gates.** Rather than asking permission for every choice, make decisions visible so the human can review asynchronously and course-correct. This builds trust and calibration over time.

### Capacity and Scale

- 2-3 projects in flight across 2-3 repos at any given time
- Matt's attention is the bottleneck — prioritize the human task queue by what unblocks the most agent work
- When Matt sits down to work, he wants a clear, prioritised list of things that need his input

### Communication Style

- Conversational, direct, low ceremony
- Prefers collaborative documentation — work together to develop good specs and docs through dialogue, refine them over time. Not "write a spec and throw it over the wall" but "build the document together through conversation." Values concise, well-structured documentation as a product of that collaboration.
- Values honest opinions and pushback from agents — "what do you think?" is a genuine question
- Strategic context matters more than implementation details — explain the "why" and let agents figure out the "how"

## Technology Context

- Data pipelines: dbt, BigQuery
- Dashboards: Streamlit, deployed via Cloud Run
- Live services: Python, hosted in GCP
- Agent tooling: Claude Code, Claude CLI
- Task management: Linear
- Version control: GitHub
