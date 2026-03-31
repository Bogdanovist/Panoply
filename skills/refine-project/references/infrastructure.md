# Strategic Context: Infrastructure as Code

## Theme

All GCP infrastructure is managed as Terraform in a single shared repository (`cloud-infrastructure`). This separation of concerns means infrastructure changes are always PRs to that repo, regardless of which application or data repo triggers the need. The pattern ensures infrastructure changes get explicit review, avoids scattered resource definitions across application repos, and creates a single source of truth for what exists in GCP.

## Current State

The cloud-infrastructure repo covers 7 GCP projects with shared modules. The core app (`human-app`) has three environments (dev/stg/prd) using the same module, ensuring environment parity. Data infrastructure (BigQuery, BigTable, BigLake, Cloud Functions) lives in the `human-datascience` module and `human-analytics` project directory.

There is no CI/CD for Terraform — plan/apply is manual. This is intentional given the blast radius of infrastructure changes, but means agent-generated PRs to this repo will need human review and manual application.

## Direction

When agents work on analytics or data science projects and discover they need infrastructure changes (e.g. a new BigQuery dataset, a Cloud Run service, an IAM binding, a new Cloud Scheduler job), they should:

1. Make the infrastructure change as a separate PR to `cloud-infrastructure`
2. Reference the triggering work in the PR description
3. The application-side changes can proceed in parallel but may depend on the infra PR being applied first

## Constraints

- Infrastructure PRs require human review and manual `terraform apply` — agents cannot apply changes
- Each project directory is an independent Terraform root with its own state — changes in one project cannot break another
- `human-shared-services` is NOT in this repo (predates Terraform, manages DNS/OAuth manually)
- No provider version pinning in code — be cautious about provider version drift
- PagerDuty integration key is a secret that must come from the environment, never hardcoded
