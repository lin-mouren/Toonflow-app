#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [owner/repo]"
  exit 1
fi

if [[ $# -eq 1 ]]; then
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

OWNER="${REPO%%/*}"

owner_type="$(gh api "users/${OWNER}" --jq '.type')"
if [[ "${owner_type}" != "User" ]]; then
  echo "Error: ${REPO} is not owned by a personal account (owner type: ${owner_type})."
  echo "Use ./scripts/github/apply-org-branch-protection.sh for Organization repositories."
  exit 2
fi

echo "Applying personal-repo governance baseline to ${REPO} ..."
gh api -X PATCH "repos/${REPO}" \
  -f default_branch=main \
  -F allow_merge_commit=true \
  -F allow_squash_merge=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true >/dev/null

echo "Ensuring workflow token permissions (required for mirror sync push) ..."
gh api -X PUT "repos/${REPO}/actions/permissions/workflow" \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true >/dev/null

tmp_main="$(mktemp)"
tmp_mirror="$(mktemp)"
tmp_master="$(mktemp)"
trap 'rm -f "$tmp_main" "$tmp_mirror" "$tmp_master"' EXIT

cat >"$tmp_main" <<'JSON'
{
  "required_status_checks": {
    "strict": false,
    "contexts": ["CI / lint", "CI / build"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

cat >"$tmp_mirror" <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

cat >"$tmp_master" <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": true,
  "allow_fork_syncing": false
}
JSON

echo "Protecting main (PR gate + CI required, review count=0) ..."
gh api -X PUT "repos/${REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input "$tmp_main" >/dev/null

echo "Protecting mirror/upstream-main (personal mode, no actor restrictions) ..."
gh api -X PUT "repos/${REPO}/branches/mirror%2Fupstream-main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input "$tmp_mirror" >/dev/null

if gh api "repos/${REPO}/branches/master" >/dev/null 2>&1; then
  echo "Locking legacy master branch ..."
  gh api -X PUT "repos/${REPO}/branches/master/protection" \
    -H "Accept: application/vnd.github+json" \
    --input "$tmp_master" >/dev/null
fi

echo "Done."
echo
echo "Protection summary:"
gh api "repos/${REPO}/branches/main/protection" \
  --jq '"main: reviews=\(.required_pull_request_reviews.required_approving_review_count), checks=\(.required_status_checks.contexts | join(", ")), enforce_admins=\(.enforce_admins.enabled), force_push=\(.allow_force_pushes.enabled), deletions=\(.allow_deletions.enabled)"'
gh api "repos/${REPO}/branches/mirror%2Fupstream-main/protection" \
  --jq '"mirror/upstream-main: restrictions=\(.restrictions | tostring), enforce_admins=\(.enforce_admins.enabled), force_push=\(.allow_force_pushes.enabled), deletions=\(.allow_deletions.enabled)"'
