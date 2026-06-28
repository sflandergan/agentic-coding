#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGETS=(
  core/agents/skills/workflow-*
  core/claude/skills
  core/opencode/agents
)

EXCLUDES=(
  core/agents/skills/github-*
  core/agents/skills/gitlab-*
  core/agents/skills/git-publish
  core/agents/skills/change-request-publish
  core/agents/skills/change-request-comments
  core/agents/skills/issue-tracker
  scripts/init.sh
  scripts/copy.sh
  README.md
)

# Patterns that indicate provider-internal leakage.
# Focus on provider-specific skill names and write operations.
# Read-only CLI commands (gh issue view, glab issue list, etc.) are allowed
# as implementation support for the neutral wrapper scripts.
PATTERNS=(
  'github-publish'
  'gitlab-publish'
  'github-pr-comments'
  'gitlab-mr-comments'
  'open-pr\.sh'
  'open-mr\.sh'
  'fetch-pr-comments\.sh'
  'fetch-mr-comments\.sh'
)

# Build rg exclude globs
EXCLUDE_ARGS=()
for e in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--glob="!$e")
done

FAILED=0
for pattern in "${PATTERNS[@]}"; do
  if rg --line-number --glob='*' "${EXCLUDE_ARGS[@]}" "$pattern" "${TARGETS[@]}"; then
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "ERROR: provider-internal references found in generic workflow files." >&2
  exit 1
fi

echo "OK: no provider-internal leakage in generic workflow files."
