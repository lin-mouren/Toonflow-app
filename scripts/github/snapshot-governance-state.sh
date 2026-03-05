#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 2 ]]; then
  echo "Usage: $0 [owner/repo] [output-file]"
  exit 1
fi

if [[ $# -ge 1 ]]; then
  REPO="$1"
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    origin_url="$(git remote get-url origin 2>/dev/null || true)"
    if [[ "$origin_url" == https://github.com/*/* || "$origin_url" == git@github.com:*/* ]]; then
      REPO="$(printf '%s' "$origin_url" | sed -E 's#^https://github.com/##; s#^git@github.com:##; s#\\.git$##')"
      REPO="${REPO%.git}"
    fi
  fi
  if [[ -z "${REPO:-}" ]]; then
    REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  fi
fi

if [[ $# -eq 2 ]]; then
  OUT_FILE="$2"
else
  file_day="$(date +%F)"
  OUT_FILE="docs/governance-snapshot-${file_day}.md"
fi

UPSTREAM_REPO="${UPSTREAM_REPO:-HBAI-Ltd/Toonflow-app}"
timestamp_local="$(date '+%Y-%m-%d %H:%M:%S %Z')"
timestamp_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

default_branch="$(gh repo view "$REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')"
merge_commit_allowed="$(gh repo view "$REPO" --json mergeCommitAllowed --jq '.mergeCommitAllowed')"
rebase_merge_allowed="$(gh repo view "$REPO" --json rebaseMergeAllowed --jq '.rebaseMergeAllowed')"
squash_merge_allowed="$(gh repo view "$REPO" --json squashMergeAllowed --jq '.squashMergeAllowed')"
delete_branch_on_merge="$(gh repo view "$REPO" --json deleteBranchOnMerge --jq '.deleteBranchOnMerge')"

main_required_reviews="$(gh api "repos/${REPO}/branches/main/protection" --jq '.required_pull_request_reviews.required_approving_review_count')"
main_checks="$(gh api "repos/${REPO}/branches/main/protection" --jq '.required_status_checks.contexts | join(", ")')"
main_enforce_admins="$(gh api "repos/${REPO}/branches/main/protection" --jq '.enforce_admins.enabled')"
main_allow_force_pushes="$(gh api "repos/${REPO}/branches/main/protection" --jq '.allow_force_pushes.enabled')"
main_allow_deletions="$(gh api "repos/${REPO}/branches/main/protection" --jq '.allow_deletions.enabled')"
main_require_conversation_resolution="$(gh api "repos/${REPO}/branches/main/protection" --jq '.required_conversation_resolution.enabled')"

mirror_enforce_admins="$(gh api "repos/${REPO}/branches/mirror%2Fupstream-main/protection" --jq '.enforce_admins.enabled')"
mirror_allow_force_pushes="$(gh api "repos/${REPO}/branches/mirror%2Fupstream-main/protection" --jq '.allow_force_pushes.enabled')"
mirror_allow_deletions="$(gh api "repos/${REPO}/branches/mirror%2Fupstream-main/protection" --jq '.allow_deletions.enabled')"
mirror_restrictions="$(gh api "repos/${REPO}/branches/mirror%2Fupstream-main/protection" --jq '.restrictions | tostring')"

compare_status="$(gh api "repos/${REPO}/compare/mirror/upstream-main...main" --jq '.status')"
compare_ahead_by="$(gh api "repos/${REPO}/compare/mirror/upstream-main...main" --jq '.ahead_by')"
compare_behind_by="$(gh api "repos/${REPO}/compare/mirror/upstream-main...main" --jq '.behind_by')"

upstream_default_branch="$(gh repo view "$UPSTREAM_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name')"
mirror_sha="$(gh api "repos/${REPO}/git/ref/heads/mirror/upstream-main" --jq '.object.sha')"
upstream_sha="$(gh api "repos/${UPSTREAM_REPO}/git/ref/heads/${upstream_default_branch}" --jq '.object.sha')"

secret_scanning_status="$(gh api "repos/${REPO}" --jq '.security_and_analysis.secret_scanning.status // "unknown"')"
secret_scanning_push_protection_status="$(gh api "repos/${REPO}" --jq '.security_and_analysis.secret_scanning_push_protection.status // "unknown"')"
dependabot_security_updates_status="$(gh api "repos/${REPO}" --jq '.security_and_analysis.dependabot_security_updates.status // "unknown"')"

if gh api "repos/${REPO}/environments/production" >/dev/null 2>&1; then
  production_environment_exists="true"
  production_can_admins_bypass="$(gh api "repos/${REPO}/environments/production" --jq '.can_admins_bypass')"
  production_branch_policy="$(gh api "repos/${REPO}/environments/production" --jq '.deployment_branch_policy | tostring')"
  production_has_required_reviewers="$(gh api "repos/${REPO}/environments/production" --jq 'any(.protection_rules[]?; .type == "required_reviewers")')"
else
  production_environment_exists="false"
  production_can_admins_bypass="unknown"
  production_branch_policy="unknown"
  production_has_required_reviewers="unknown"
fi

mkdir -p "$(dirname "$OUT_FILE")"
cat >"$OUT_FILE" <<EOF
# Governance Snapshot: ${REPO}

Generated at:
- Local time: ${timestamp_local}
- UTC time: ${timestamp_utc}

## Repository settings

- default_branch: \`${default_branch}\`
- merge_commit_allowed: \`${merge_commit_allowed}\`
- rebase_merge_allowed: \`${rebase_merge_allowed}\`
- squash_merge_allowed: \`${squash_merge_allowed}\`
- delete_branch_on_merge: \`${delete_branch_on_merge}\`

## Branch protection: main

- required_approving_review_count: \`${main_required_reviews}\`
- required_status_checks: \`${main_checks}\`
- enforce_admins: \`${main_enforce_admins}\`
- allow_force_pushes: \`${main_allow_force_pushes}\`
- allow_deletions: \`${main_allow_deletions}\`
- required_conversation_resolution: \`${main_require_conversation_resolution}\`

## Branch protection: mirror/upstream-main

- enforce_admins: \`${mirror_enforce_admins}\`
- allow_force_pushes: \`${mirror_allow_force_pushes}\`
- allow_deletions: \`${mirror_allow_deletions}\`
- restrictions: \`${mirror_restrictions}\`

## Mirror alignment

- upstream repository: \`${UPSTREAM_REPO}\`
- upstream default branch: \`${upstream_default_branch}\`
- compare status (\`mirror/upstream-main...main\`): \`${compare_status}\`
- compare ahead_by: \`${compare_ahead_by}\`
- compare behind_by: \`${compare_behind_by}\`
- mirror sha: \`${mirror_sha}\`
- upstream sha: \`${upstream_sha}\`
- mirror equals upstream: \`$([[ "$mirror_sha" == "$upstream_sha" ]] && echo true || echo false)\`

## Security and deployment hardening status

- secret_scanning: \`${secret_scanning_status}\`
- secret_scanning_push_protection: \`${secret_scanning_push_protection_status}\`
- dependabot_security_updates: \`${dependabot_security_updates_status}\`
- production_environment_exists: \`${production_environment_exists}\`
- production_can_admins_bypass: \`${production_can_admins_bypass}\`
- production_branch_policy: \`${production_branch_policy}\`
- production_has_required_reviewers: \`${production_has_required_reviewers}\`
EOF

echo "Wrote ${OUT_FILE}"
