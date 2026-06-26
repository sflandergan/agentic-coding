#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing: current branch is "%s". Open a pull request from a feature branch.\n' "$branch" >&2
    exit 1
    ;;
esac

# Skip creation if a pull request already exists for this branch.
existing="$(gh pr list --head "$branch" --json url --jq 'length')"
if [ "${existing:-0}" -gt 0 ]; then
  printf 'A pull request already exists for branch "%s":\n' "$branch"
  gh pr list --head "$branch" --json url,title --jq '.[] | "  \(.title) — \(.url)"'
  exit 0
fi

printf 'Opening pull request for branch "%s"...\n' "$branch"
gh pr create --head "$branch" "$@"
