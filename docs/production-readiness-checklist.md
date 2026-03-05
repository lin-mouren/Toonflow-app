# Production Readiness Checklist (Personal Repo Mode)

This document operationalizes pending production hardening tasks while the repository remains under a personal account.

## Scope

- Repository: `lin-mouren/Toonflow-app`
- Upstream: `HBAI-Ltd/Toonflow-app`
- Branch model: `main` + `mirror/upstream-main`
- Current policy: no strict actor-level mirror push restriction

## Current status (as of 2026-03-05)

- `production` environment has been created with `protected_branches=true`.
- `production` required reviewers are not configured yet.
- `secret_scanning` and `secret_scanning_push_protection` are enabled.
- `dependabot_security_updates` is enabled.

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
- `main` required approvals: `0`
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
