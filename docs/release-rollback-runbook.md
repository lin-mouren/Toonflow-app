# Release Rollback Runbook

This runbook defines the rollback path for releases produced by `.github/workflows/release.yml`.

## Preconditions

- Use an account with permission to create tags and releases.
- Confirm a rollback owner (`lin-mouren`) and communication channel before execution.
- Do not delete existing release tags as first response; prefer forward rollback via a new tag.

## Identify rollback target

```bash
git fetch --tags origin
git tag --sort=-creatordate | head -n 20
```

Select:
- `broken_tag`: currently deployed but faulty tag (example: `v1.2.3`)
- `stable_tag`: last known good tag (example: `v1.2.2`)

## Execute rollback release

1. Create rollback branch from `stable_tag`:

```bash
git checkout -b release/rollback-$(date +%Y%m%d-%H%M) "$stable_tag"
```

2. Create a new rollback tag (do not reuse old tag):

```bash
rollback_tag="v1.2.4-rollback.1"
git tag -a "$rollback_tag" -m "rollback: revert production to $stable_tag from $broken_tag"
git push origin "$rollback_tag"
```

3. Verify GitHub Actions release run started:

```bash
gh run list -R lin-mouren/Toonflow-app --workflow "Build and Release" --limit 5
```

4. Approve `production` environment prompt when requested.

## Post-rollback validation

1. Confirm release artifacts correspond to `stable_tag` code lineage.
2. Smoke-test startup and critical user paths.
3. Update incident issue with:
- `broken_tag`
- `stable_tag`
- `rollback_tag`
- release workflow URL
- validation checklist results

## Follow-up

1. Open a fix PR on `main` for root cause.
2. Prepare next normal release tag after fix verification.
3. Keep rollback issue open until fix release is live.
