#!/usr/bin/env bash
set -euo pipefail

# Detect host from the remote URL.
remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)
    exec bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh "$@"
    ;;
  *)
    exec bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh "$@"
    ;;
esac
