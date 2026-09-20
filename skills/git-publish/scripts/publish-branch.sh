#!/usr/bin/env bash
# publish-branch.sh — Guarded Git/GitHub branch publication.
#
# Two modes:
#   1. Default (no flags): push the current branch, then print the existing
#      open PR's URL or create a draft PR with `gh pr create --fill --draft`.
#   2. Exact existing-PR mode (--existing-pr, --expected-head, --head-branch
#      required together): validate the named PR's identity and perform one
#      fully qualified lease update of the retained head branch.
#
# Default mode rejects detached HEAD and protected branches (main, master,
# and the resolved origin default). Exact mode accepts local main and
# detached HEAD but still refuses a protected head branch.

set -euo pipefail

# ---------------------------------------------------------------------------
# Protected-branch guard
# ---------------------------------------------------------------------------
# Resolve the remote default branch (e.g. main, master). Falls back to "main"
# when origin/HEAD is not set.
resolve_default_branch() {
  local default
  default="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||')" || true
  if [ -z "$default" ]; then
    if git rev-parse --verify refs/remotes/origin/main >/dev/null 2>&1; then
      printf 'main\n'
    elif git rev-parse --verify refs/remotes/origin/master >/dev/null 2>&1; then
      printf 'master\n'
    else
      printf 'main\n'
    fi
  else
    printf '%s\n' "$default"
  fi
}

is_protected_branch() {
  local branch="$1"
  case "$branch" in
    main | master) return 0 ;;
  esac
  [ "$branch" = "$(resolve_default_branch)" ]
}

# ---------------------------------------------------------------------------
# Exact-mode argument validation
# ---------------------------------------------------------------------------
validate_existing_pr_args() {
  local existing_pr_set="$1"
  local expected_head_set="$2"
  local head_branch_set="$3"
  local existing_pr="$4"
  local expected_head="$5"
  local head_branch="$6"

  if [ "$existing_pr_set" -ne 1 ] || [ "$expected_head_set" -ne 1 ] ||
    [ "$head_branch_set" -ne 1 ] || [ -z "$existing_pr" ] ||
    [ -z "$expected_head" ] || [ -z "$head_branch" ]; then
    printf '%s\n' '--existing-pr, --expected-head, and --head-branch are required together' >&2
    exit 2
  fi

  case "$existing_pr" in
    '' | *[!0-9]*)
      printf 'Pull-request number must be a positive integer: %s\n' "$existing_pr" >&2
      exit 2
      ;;
  esac
  if [ "$existing_pr" -le 0 ]; then
    printf 'Pull-request number must be a positive integer: %s\n' "$existing_pr" >&2
    exit 2
  fi

  case "$expected_head" in
    '' | *[!0-9a-fA-F]*)
      printf 'Expected head must be a 40-character hex SHA: %s\n' "$expected_head" >&2
      exit 2
      ;;
  esac
  if [ "${#expected_head}" -ne 40 ]; then
    printf 'Expected head must be a 40-character hex SHA: %s\n' "$expected_head" >&2
    exit 2
  fi
}

validate_head_branch() {
  if is_protected_branch "$1"; then
    printf 'Refusing to publish to protected head branch: %s\n' "$1" >&2
    exit 2
  fi

  if ! git check-ref-format --branch "$1" >/dev/null 2>&1; then
    printf 'Head branch must be a valid branch ref and not protected: %s\n' "$1" >&2
    exit 2
  fi
}

load_pr_metadata() {
  command -v jq >/dev/null 2>&1 || { printf 'jq is not installed.\n' >&2; exit 1; }

  if ! pr_json="$(gh pr view "$1" --json state,headRefName,url)"; then
    printf 'PR #%s not found\n' "$1" >&2
    exit 1
  fi
  pr_state="$(printf '%s' "$pr_json" | jq -r '.state')"
  pr_head="$(printf '%s' "$pr_json" | jq -r '.headRefName')"
  pr_url="$(printf '%s' "$pr_json" | jq -r '.url')"
}

validate_pr_state_and_head() {
  if [ "$2" != 'OPEN' ]; then
    printf 'Refusing to publish to PR #%s: state is %s\n' "$1" "$2" >&2
    exit 1
  fi

  if [ "$3" != "$4" ]; then
    printf 'Refusing to publish to PR #%s: head branch %s does not match requested head branch %s\n' \
      "$1" "$3" "$4" >&2
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
existing_pr=''
expected_head=''
head_branch=''
existing_pr_set=0
expected_head_set=0
head_branch_set=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --existing-pr)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--existing-pr requires a pull-request number' >&2
        exit 2
      fi
      existing_pr="$2"
      existing_pr_set=1
      shift 2
      ;;
    --expected-head)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--expected-head requires a commit SHA' >&2
        exit 2
      fi
      expected_head="$2"
      expected_head_set=1
      shift 2
      ;;
    --head-branch)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' '--head-branch requires a branch name' >&2
        exit 2
      fi
      head_branch="$2"
      head_branch_set=1
      shift 2
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Exact existing-PR mode
# ---------------------------------------------------------------------------
if [ "$existing_pr_set" -eq 1 ] || [ "$expected_head_set" -eq 1 ] || [ "$head_branch_set" -eq 1 ]; then
  validate_existing_pr_args \
    "$existing_pr_set" "$expected_head_set" "$head_branch_set" \
    "$existing_pr" "$expected_head" "$head_branch"
  validate_head_branch "$head_branch"
  load_pr_metadata "$existing_pr"
  validate_pr_state_and_head "$existing_pr" "$pr_state" "$pr_head" "$head_branch"

  git push \
    --force-with-lease="refs/heads/$head_branch:$expected_head" \
    origin \
    "HEAD:refs/heads/$head_branch"
  printf '%s\n' "$pr_url"
else
  # ---------------------------------------------------------------------------
  # Default mode
  # ---------------------------------------------------------------------------
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
    printf 'Not in a Git repository\n' >&2
    exit 1
  }

  if [ "$branch" = 'HEAD' ]; then
    printf 'Detached HEAD: cannot publish. Switch to a scoped branch first.\n' >&2
    exit 1
  fi

  if is_protected_branch "$branch"; then
    printf 'Refusing to publish protected branch: %s\n' "$branch" >&2
    exit 1
  fi

  git push -u origin "$branch"

  pr_url="$(gh pr list --head "$branch" --json url --jq '.[0].url')"
  if [ -n "$pr_url" ]; then
    printf '%s\n' "$pr_url"
  else
    gh pr create --fill --draft
  fi
fi
