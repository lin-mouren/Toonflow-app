# Production Readiness Checklist (Personal Repo Mode)

This document operationalizes pending production hardening tasks while the repository remains under a personal account.

## Scope

- Repository: `lin-mouren/Toonflow-app`
- Upstream: `HBAI-Ltd/Toonflow-app`
- Branch model: `main` + `mirror/upstream-main`
- Current policy: no strict actor-level mirror push restriction

## Current status (as of 2026-03-06)

- `issues` is enabled (`has_issues=true`) for break-glass incident tracking.
- `production` environment has been created.
- `production` deployment branch policy is now `custom_branch_policies=true`.
- `production` deployment sources are restricted to:
  - `main` (branch)
  - `v*` (tag)
- `production` required reviewer is configured (`lin-mouren`).
- `production` admin bypass is disabled (`can_admins_bypass=false`).
- `secret_scanning` and `secret_scanning_push_protection` are enabled.
- `dependabot_security_updates` is enabled.
- default workflow token permission is `read`; write permissions are job-scoped.
- `main` protection now requires `1` approval with CODEOWNERS review.
- upstream sync drill capability is implemented in `.github/workflows/upstream-sync.yml` (`drill_ff_failure`).
- release rollback runbook exists at `docs/release-rollback-runbook.md`.
- upstream ff failure fan-out is configured via issue + owner mention + webhook secret `UPSTREAM_SYNC_ALERT_WEBHOOK_URL`.
- rehearsal release tag `v0.0.0-alpha.1` completed end-to-end production gate validation.

## P0: Deployment environment protection

Goal: block accidental production release without explicit approval.

Actions:
1. Create GitHub Environment `production`.
2. Add required reviewers for `production`.
3. Restrict deployment branches to `main` and release tags (`v*`).
4. Store release secrets only in `production` environment.
5. Verify `.github/workflows/release.yml` references `environment: production`.

Validation:
- Tag push requires environment approval before release job executes.
- Non-`main` branch cannot deploy to `production`.

## P0: Supply chain and credential hardening

Goal: reduce token/secret risk from CI and release pipelines.

Actions:
1. Keep action versions pinned to immutable commit SHA.
2. Keep workflow/job `permissions` minimal (default read; elevate per job only).
3. Enable repository Secret Scanning and Push Protection.
4. Rotate external deployment credentials on a fixed interval (for example every 30 days).
5. Restrict personal access tokens; prefer short-lived `GITHUB_TOKEN`.

Validation:
- No unpinned action versions in workflow files.
- Token scopes observed in workflows match least privilege.

## P0: Release traceability and rollback

Goal: every production artifact is traceable to source and recoverable.

Actions:
1. Release by annotated tag (`vX.Y.Z`) only.
2. Use merge-commit history on `main` (squash/rebase disabled).
3. Keep generated release notes enabled.
4. Maintain rollback runbook with:
   - previous stable tag
   - rollback owner
   - communication checklist
5. Store governance snapshot per change window.

Validation:
- Any release can be traced: release tag -> commit -> merged PR.
- Rollback command path is documented and tested.

## P1: Review strength ladder

Goal: start fast with 0-approval gate, then raise review strength at production milestone.

Current:
- `main` required approvals: `1`
- required checks: `lint`, `build`

Upgrade path:
1. Move `required_approving_review_count` from `0` to `1`.
2. Keep `required_conversation_resolution=true`.
3. Enforce high-risk path reviews via `CODEOWNERS`.

Trigger suggestion:
- Switch to 1-approval gate before first public production rollout.

## P1: Upstream sync observability

Goal: mirror sync failures surface quickly and route to the right owner.

Actions:
1. Keep `upstream-sync.yml` break-glass issue auto-open enabled.
2. Add notification fan-out for sync failure issue events (email/Slack/webhook).
3. Track a weekly metric:
   - successful sync runs
   - failed ff-only runs
   - mean time to recovery

Validation:
- FF failure creates/updates an issue with run URL and remediation steps.
- On-call owner receives notification within SLA.

## Closure evidence (2026-03-06)

1. Release rehearsal
- tag: `v0.0.0-alpha.1`
- workflow run: `22728142335`
- run URL: `https://github.com/lin-mouren/Toonflow-app/actions/runs/22728142335`
- production environment approval completed by required reviewer
- GitHub Release created with multi-platform artifacts:
  - `https://github.com/lin-mouren/Toonflow-app/releases/tag/v0.0.0-alpha.1`

2. Upstream drill rehearsal
- workflow run: `22730995682` (expected failure path)
- run URL: `https://github.com/lin-mouren/Toonflow-app/actions/runs/22730995682`
- drill issue: `#16` (created then closed after verification)
- webhook fan-out: `Webhook status: sent`
- mirror branch integrity: unchanged SHA before/after drill

## Operations cadence

- Weekly:
  - run `./scripts/github/snapshot-governance-state.sh`
  - verify mirror/upstream SHA equality
- Monthly:
  - review branch protection drift
  - rotate deployment credentials
- Per release:
  - verify `production` environment approval path
  - verify release provenance and rollback readiness
