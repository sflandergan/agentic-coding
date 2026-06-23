#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
  printf 'Refusing to publish protected branch: %s\n' "$branch" >&2
  exit 1
fi

git push -u origin "$branch"

pr_url="$(gh pr list --head "$branch" --json url --jq '.[0].url')"
if [ -n "$pr_url" ]; then
  printf '%s\n' "$pr_url"
else
  gh pr create --fill
fi
