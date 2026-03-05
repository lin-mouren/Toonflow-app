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
REPO_NAME="${REPO##*/}"

owner_type="$(gh api "users/${OWNER}" --jq '.type')"
if [[ "${owner_type}" != "Organization" ]]; then
  echo "Error: ${REPO} is not owned by an Organization (owner type: ${owner_type})."
  echo "Strict actor-level push restrictions for mirror require an Organization repo."
  exit 2
fi

echo "Applying repository settings to ${REPO} ..."
gh api -X PATCH "repos/${REPO}" \
  -f default_branch=main \
  -F allow_merge_commit=true \
  -F allow_squash_merge=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true >/dev/null

echo "Ensuring workflow token permissions ..."
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
    "required_approving_review_count": 1,
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
  "restrictions": {
    "users": [],
    "teams": [],
    "apps": ["github-actions"]
  },
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

echo "Protecting main ..."
gh api -X PUT "repos/${REPO}/branches/main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input "$tmp_main" >/dev/null

echo "Protecting mirror/upstream-main (github-actions push only) ..."
gh api -X PUT "repos/${REPO}/branches/mirror%2Fupstream-main/protection" \
  -H "Accept: application/vnd.github+json" \
  --input "$tmp_mirror" >/dev/null

if gh api "repos/${REPO}/branches/master" >/dev/null 2>&1; then
  echo "Locking legacy master ..."
  gh api -X PUT "repos/${REPO}/branches/master/protection" \
    -H "Accept: application/vnd.github+json" \
    --input "$tmp_master" >/dev/null
fi

echo "Done."
echo
echo "Current branch list for ${REPO}:"
gh api "repos/${REPO}/branches?per_page=100" --jq '.[].name'
