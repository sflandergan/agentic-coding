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

# --- Skill-internal script path check ---
# Per the Skill Boundary Rule, body text should use skill names, not internal
# script paths like .agents/skills/<skill>/scripts/*.sh. Only check body text
# (after YAML frontmatter) for OpenCode agent files.

SCRIPT_PATH_PATTERNS=(
  '\.agents/skills/.*/scripts/'
  '\.claude/skills/.*/scripts/'
)

# Boundary skill directories where script usage is the documented interface
BOUNDARY_SKILLS=(
  core/agents/skills/git-publish
  core/agents/skills/change-request-publish
  core/agents/skills/change-request-comments
  core/agents/skills/issue-tracker
)

# Expand target globs to actual files
TARGET_FILES=()
for target in "${TARGETS[@]}"; do
  while IFS= read -r file; do
    [[ -f "$file" ]] && TARGET_FILES+=("$file")
  done < <(find "$target" -name '*.md' -type f 2>/dev/null)
done

if [[ ${#TARGET_FILES[@]} -eq 0 ]]; then
  echo "OK: no workflow files found to check." >&2
  exit 0
fi

for file in "${TARGET_FILES[@]}"; do
  # Skip boundary skill docs
  skip=false
  for boundary in "${BOUNDARY_SKILLS[@]}"; do
    if [[ "$file" == "$boundary"/* ]]; then
      skip=true
      break
    fi
  done
  [[ "$skip" == true ]] && continue

  # For OpenCode agent files, only check body text (after second ---)
  if [[ "$file" == core/opencode/agents/*.md ]]; then
    body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$file")
  else
    body=$(cat "$file")
  fi

  for pattern in "${SCRIPT_PATH_PATTERNS[@]}"; do
    if echo "$body" | rg -n "$pattern" 2>/dev/null; then
      echo "  ^ in $file" >&2
      FAILED=1
    fi
  done
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "ERROR: skill-internal script references found in workflow body text." >&2
  exit 1
fi

# --- Bare boundary-skill reference check ---
# Workflow-facing body text must use slash references (e.g. /git-publish) for
# boundary skills, not bare backticked names (e.g. `git-publish`).

BOUNDARY_SKILL_NAMES=(
  'git-publish'
  'change-request-publish'
  'change-request-comments'
  'issue-tracker'
)

for file in "${TARGET_FILES[@]}"; do
  # Skip boundary skill docs
  skip=false
  for boundary in "${BOUNDARY_SKILLS[@]}"; do
    if [[ "$file" == "$boundary"/* ]]; then
      skip=true
      break
    fi
  done
  [[ "$skip" == true ]] && continue

  # For OpenCode agent files, only check body text (after second ---)
  if [[ "$file" == core/opencode/agents/*.md ]]; then
    body=$(awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$file")
  else
    body=$(cat "$file")
  fi

  for skill_name in "${BOUNDARY_SKILL_NAMES[@]}"; do
    # Match backtick-wrapped name without leading slash
    if echo "$body" | rg -n "[^/]\`$skill_name\`" 2>/dev/null; then
      echo "  ^ bare reference in $file" >&2
      FAILED=1
    fi
    # Also match start-of-line backtick-wrapped name without leading slash
    if echo "$body" | rg -n "^\`$skill_name\`" 2>/dev/null; then
      echo "  ^ bare reference in $file" >&2
      FAILED=1
    fi
  done
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "ERROR: bare boundary-skill references found; use slash form (e.g. /git-publish)." >&2
  exit 1
fi

echo "OK: no provider-internal leakage in generic workflow files."
