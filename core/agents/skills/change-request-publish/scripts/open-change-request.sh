#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing: current branch is "%s". Open a change request from a feature branch.\n' "$branch" >&2
    exit 1
    ;;
esac

# Detect host from the remote URL.
remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)
    provider="github"
    ;;
  *)
    provider="gitlab"
    ;;
esac

if [ "$provider" = "github" ]; then
  # Skip creation if a pull request already exists for this branch.
  existing="$(gh pr list --head "$branch" --json url --jq 'length')"
  if [ "${existing:-0}" -gt 0 ]; then
    printf 'A pull request already exists for branch "%s":\n' "$branch"
    gh pr list --head "$branch" --json url,title --jq '.[] | "  \(.title) — \(.url)"'
    exit 0
  fi

  printf 'Opening pull request for branch "%s"...\n' "$branch"
  gh pr create --head "$branch" "$@"
else
  # Skip creation if a merge request already exists for this branch.
  existing="$(glab mr list --source-branch "$branch" -F json 2>/dev/null | jq -r 'length' || echo 0)"
  if [ "${existing:-0}" -gt 0 ]; then
    printf 'A merge request already exists for branch "%s":\n' "$branch"
    glab mr list --source-branch "$branch"
    exit 0
  fi

  printf 'Opening merge request for branch "%s"...\n' "$branch"
  glab mr create --source-branch "$branch" "$@"
fi
