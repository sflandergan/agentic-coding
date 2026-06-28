#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing to push: current branch is "%s". Create a scoped feature branch first.\n' "$branch" >&2
    exit 1
    ;;
esac

# Force-pushing is never part of safe publishing.
for arg in "$@"; do
  case "$arg" in
    --force|-f|--force-with-lease|--force-with-lease=*)
      printf 'Refusing to force-push from this script. Force-push must be a deliberate, human-run command.\n' >&2
      exit 1
      ;;
  esac
done

printf 'Pushing branch "%s" to origin...\n' "$branch"
git push origin "$branch" "$@"
