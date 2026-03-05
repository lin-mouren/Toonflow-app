# Upstream Sync Runbook

This repository uses:
- `main` as the product iteration branch.
- `mirror/upstream-main` as the upstream mirror branch.

Upstream mapping:
- Upstream repo: `HBAI-Ltd/Toonflow-app`
- Upstream source branch: `upstream/master`
- Mirror target branch: `origin/mirror/upstream-main`

## Branch model

- `main` accepts product development and feature PRs.
- `mirror/upstream-main` mirrors `upstream/master` by fast-forward only.
- Upstream changes flow into `main` via PR: `mirror/upstream-main -> main`.

## One-time local setup

```bash
git remote add upstream git@github.com:HBAI-Ltd/Toonflow-app.git
git fetch --prune upstream
```

## Manual mirror sync (ff-only)

```bash
git fetch --prune upstream
git checkout mirror/upstream-main
git merge --ff-only upstream/master
git push origin mirror/upstream-main
```

## Merge upstream into main (PR gate)

Use a PR from `mirror/upstream-main` to `main`.

If conflicts exist, do not modify `mirror/upstream-main` directly. Resolve in a temp branch:

```bash
git checkout main
git pull --ff-only origin main
git checkout -b sync/upstream-YYYYMMDD
git merge --no-ff origin/mirror/upstream-main
git push -u origin sync/upstream-YYYYMMDD
gh pr create --base main --head sync/upstream-YYYYMMDD \
  --title "chore(upstream): resolve conflicts" \
  --body "Resolve upstream sync conflicts"
```

## Automation

Workflows:
- `.github/workflows/ci.yml`
- `.github/workflows/upstream-sync.yml`

`upstream-sync.yml`:
- runs on schedule and on manual dispatch
- fast-forward syncs mirror from upstream
- creates or updates a PR from mirror to main when there are upstream deltas

## Governance baseline and snapshot

Apply personal-repo governance baseline:

```bash
./scripts/github/apply-personal-branch-baseline.sh lin-mouren/Toonflow-app
```

Generate a timestamped governance snapshot:

```bash
./scripts/github/snapshot-governance-state.sh lin-mouren/Toonflow-app
```

The output file is written to `docs/governance-snapshot-YYYY-MM-DD.md`.

## Break-glass (non-fast-forward upstream rewrite)

Trigger:
- `git merge --ff-only upstream/master` fails in local or in workflow

Procedure:
1. Temporarily allow force push on `mirror/upstream-main`.
2. Realign mirror to upstream:

```bash
git fetch --prune upstream
git checkout mirror/upstream-main
git reset --hard upstream/master
git push --force-with-lease origin mirror/upstream-main
```

3. Re-disable force push immediately.

## Important limitation (personal repository)

For personal repositories, GitHub does not support branch-protection push restrictions for specific actors (users/teams/apps). Because of this, enforcing "only GitHub Actions can push mirror" cannot be made strict via branch protection alone. If strict actor-level push restriction is required, move the repository to an organization and use rulesets/actor restrictions there.

For production-readiness tasks (deployment environment protection, secrets hardening, release traceability), follow:
- `docs/production-readiness-checklist.md`
