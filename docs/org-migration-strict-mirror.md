# Org Migration + Strict Mirror Enforcement

This guide is for enforcing **actor-level push restrictions** on `mirror/upstream-main`.
GitHub personal repositories cannot strictly enforce "only GitHub Actions can push this branch."
Use this flow after moving the repository to an Organization.

## Target state

- Repository owner is an Organization.
- `main` remains the product iteration branch with PR + CI gates.
- `mirror/upstream-main` allows pushes from `github-actions` app only.
- `master` is locked (legacy branch, read-only).

## Migration checklist

1. Transfer the repository to an Organization you control:
   - GitHub UI: `Settings` -> `General` -> `Transfer`.
   - Or CLI: `gh repo transfer <org-name>`.
2. Confirm the default branch is `main`.
3. Confirm workflows exist on `main`:
   - `.github/workflows/ci.yml`
   - `.github/workflows/upstream-sync.yml`
4. Run the automation script:

```bash
./scripts/github/apply-org-branch-protection.sh <org>/<repo>
```

5. Validate:
   - Direct push to `main` is blocked.
   - Direct push to `mirror/upstream-main` is blocked for humans.
   - `Upstream Sync` workflow can still update `mirror/upstream-main`.

## Notes

- If your org has custom rulesets, keep this script as baseline and layer org rulesets on top.
- If `mirror` fast-forward fails due upstream history rewrite, use the break-glass process from `docs/upstream-sync-runbook.md`.
