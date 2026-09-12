#!/usr/bin/env bash
# publish-and-ready.sh — Publish the final commit and mark the PR ready.
#
# Performs the pre-publish freshness recheck, then publishes and marks ready.
# The finish skill runs the initial freshness check and verification separately
# before invoking this script.
#
# Publication mode selection (safety invariants):
#   The origin repository, head branch, and expected base form one PR
#   identity; a pull request is never chosen by result order.
#   A retained remote branch publishes only through the guarded existing-PR
#   mode when exactly one open PR matches that identity; zero or multiple
#   matches stop before publication.
#   An absent remote branch uses the publisher's argument-less first
#   publication, and the returned PR is validated against the same identity
#   before any readiness mutation.
#   This script short-circuits main and detached HEAD locally with no
#   network discovery; the publisher itself refuses only main.
#
# Exit codes:
#   0   Published and marked ready.
#   1   Discovery, publication, identity, or readiness failure.
#   99  Pre-publish recheck rebased the head.  The skill must rerun the
#       complete applicable verification gate and retry publication.
#
# Publication mode:
#   When the current branch exists on the remote with an open PR, the
#   publisher runs in guarded existing-PR mode (--existing-pr,
#   --expected-head, --head-branch) so a head rewritten by a freshness
#   rebase publishes safely.  Otherwise the publisher runs in its
#   argument-less first-publication mode.
#
# Environment:
#   PUBLISH_HELPER  Path to the publication script
#                   (default: .agents/skills/git-publish/scripts/publish-branch.sh).
#   FRESHNESS_BASE  Base branch ref passed through to ensure-fresh.sh; it also
#                   supplies the expected base branch for PR identity checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ------------------------------------------------------------------
# 1. Pre-publish freshness recheck — verify the base has not moved.
# ------------------------------------------------------------------
rc=0
bash "$SCRIPT_DIR/ensure-fresh.sh" --recheck >/dev/null || rc=$?
case $rc in
  0) ;;                          # fresh — proceed
  3)                             # base moved, rebase performed
    printf 'Base moved before publication; rerun verification and retry.\n' >&2
    exit 99
    ;;
  *)                             # fetch or rebase failure
    printf 'Freshness recheck failed; publication was not attempted.\n' >&2
    exit 1
    ;;
esac

# ------------------------------------------------------------------
# 2. Capture the exact local SHA that passed verification.
# ------------------------------------------------------------------
published_sha="$(git rev-parse HEAD)"

publisher="${PUBLISH_HELPER:-.agents/skills/git-publish/scripts/publish-branch.sh}"
branch="$(git rev-parse --abbrev-ref HEAD)"

# ------------------------------------------------------------------
# Discovery helpers.
# Each helper echoes data or returns non-zero; the top-level flow owns
# user-facing failure messages and the exit-1 decision.
# ------------------------------------------------------------------

# Echoes "<owner>\t<repository>" for the origin repository.
resolve_repo_identity() {
  local name_with_owner
  name_with_owner="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')" || return 1
  case "$name_with_owner" in
    */?*) printf '%s\t%s\n' "${name_with_owner%/*}" "${name_with_owner#*/}" ;;
    *) return 1 ;;
  esac
}

# Echoes the expected base branch; FRESHNESS_BASE must name an origin ref.
resolve_expected_base() {
  local ref="${FRESHNESS_BASE:-origin/main}"
  case "$ref" in
    origin/?*) printf '%s\n' "${ref#origin/}" ;;
    *) return 1 ;;
  esac
}

# Echoes the exact remote head SHA for $1, or empty when the branch is absent.
read_remote_head() {
  local out
  out="$(git ls-remote origin "refs/heads/$1")" || return 1
  printf '%s\n' "${out%%$'\t'*}"
}

# Echoes "<match-count>\t<first-match-number>" for open PRs whose full
# identity matches $1 head, $2 owner, $3 repository, $4 base.
# The number field is empty when the count is 0 and must only be used
# when the count is 1.
select_exact_prs() {
  local head="$1" owner="$2" name="$3" base="$4"
  local candidates summary
  candidates="$(gh pr list --head "$head" --state open \
    --json number,headRefName,headRepository,headRepositoryOwner,baseRefName)" || return 1
  summary="$(printf '%s' "$candidates" | jq -r --arg head "$head" --arg owner "$owner" \
    --arg name "$name" --arg base "$base" '
      [ .[] | select(
          .headRepositoryOwner.login == $owner
          and .headRepository.name == $name
          and .headRefName == $head
          and .baseRefName == $base
        ) ]
      | "\(length)\t\(.[0].number // "")"')" || return 1
  printf '%s\n' "$summary"
}

# Returns 0 only when PR $5 is open and matches the identity
# $1 owner, $2 name, $3 head, $4 base.
published_pr_matches_identity() {
  local owner="$1" name="$2" head="$3" base="$4" pr_url="$5"
  local json
  json="$(gh pr view "$pr_url" \
    --json state,url,headRefName,headRepository,headRepositoryOwner,baseRefName)" || return 1
  printf '%s' "$json" | jq -e --arg owner "$owner" --arg name "$name" \
    --arg head "$head" --arg base "$base" '
      .state == "OPEN"
      and .headRepositoryOwner.login == $owner
      and .headRepository.name == $name
      and .headRefName == $head
      and .baseRefName == $base' >/dev/null
}

# ------------------------------------------------------------------
# 3. Publish the final commit through the selected mode.
# ------------------------------------------------------------------
publish() {
  if ! pr_url="$(bash "$publisher" "$@")"; then
    printf 'Publication failed; PR readiness was not changed.\n' >&2
    exit 1
  fi
}

# Publishes a branch whose remote head exists through the guarded
# existing-PR mode; zero or multiple exact matches stop before publication.
# Assumes remote_head is non-empty.
publish_retained_branch() {
  local match match_count pr_number
  match="$(select_exact_prs "$branch" "$repo_owner" "$repo_name" "$expected_base")" || {
    printf 'Unable to list open pull requests for branch %s; publication was not attempted.\n' "$branch" >&2
    exit 1
  }
  match_count="${match%%$'\t'*}"
  pr_number="${match#*$'\t'}"
  if [ "$match_count" != '1' ]; then
    printf 'Branch %s on %s/%s against base %s has %s exact open pull requests; expected exactly one; publication was not attempted.\n' \
      "$branch" "$repo_owner" "$repo_name" "$expected_base" "$match_count" >&2
    exit 1
  fi
  publish --existing-pr "$pr_number" --expected-head "$remote_head" --head-branch "$branch"
}

# Publishes a branch with no remote head and validates the returned PR
# against the identity before any readiness mutation.
publish_first_branch() {
  publish
  published_pr_matches_identity \
    "$repo_owner" "$repo_name" "$branch" "$expected_base" "$pr_url" || {
    printf 'Published PR %s does not match the expected identity %s/%s:%s against base %s; PR readiness was not changed.\n' \
      "$pr_url" "$repo_owner" "$repo_name" "$branch" "$expected_base" >&2
    exit 1
  }
}

if [ "$branch" = 'HEAD' ] || [ "$branch" = 'main' ]; then
  # No network discovery here; the publisher itself refuses only main.
  publish
else
  identity="$(resolve_repo_identity)" || {
    printf 'Unable to resolve the origin repository identity; publication for branch %s was not attempted.\n' "$branch" >&2
    exit 1
  }
  repo_owner="${identity%%$'\t'*}"
  repo_name="${identity#*$'\t'}"
  expected_base="$(resolve_expected_base)" || {
    printf 'FRESHNESS_BASE "%s" does not identify an origin/<branch> base; publication for branch %s was not attempted.\n' "${FRESHNESS_BASE:-origin/main}" "$branch" >&2
    exit 1
  }
  remote_head="$(read_remote_head "$branch")" || {
    printf 'Unable to query the remote head for branch %s; publication was not attempted.\n' "$branch" >&2
    exit 1
  }
  if [ -n "$remote_head" ]; then
    publish_retained_branch
  else
    publish_first_branch
  fi
fi

# ------------------------------------------------------------------
# 4. Mark the open PR ready, passing the verified SHA.
# ------------------------------------------------------------------
if ! bash "$SCRIPT_DIR/mark-pr-ready.sh" "$pr_url" "$published_sha"; then
  printf 'Publication succeeded but PR readiness failed: %s\n' "$pr_url" >&2
  exit 1
fi
