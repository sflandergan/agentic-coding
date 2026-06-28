#!/usr/bin/env bash
#
# init.sh — Create a new project from the agentic-coding toolkit.
#
# Resolves the toolkit root from the script's own location so it works
# regardless of where the user invokes it from.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve toolkit root (works when invoked as `bash scripts/init.sh` from
# anywhere, or via an absolute/relative path).
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

require_tool() {
  local tool="$1"
  local hint="$2"
  if ! command -v "$tool" &>/dev/null; then
    echo "ERROR: '$tool' is required but not found on PATH."
    echo "$hint"
    exit 1
  fi
}

warn_tool() {
  local tool="$1"
  local hint="$2"
  if ! command -v "$tool" &>/dev/null; then
    echo "WARNING: '$tool' is not installed. $hint"
    return 1
  fi
  return 0
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# 1. Check required tools
# ---------------------------------------------------------------------------
require_tool jq "Install with: brew install jq"
NPX_AVAILABLE=true
warn_tool npx "Install Node.js (provides npx) to enable remote skill installation. It will be skipped." || NPX_AVAILABLE=false

# ---------------------------------------------------------------------------
# 2. Prompt for stack
# ---------------------------------------------------------------------------
echo ""
echo "Select a stack:"
select STACK_choice in "pnpm" "maven"; do
  if [[ -n "$STACK_choice" ]]; then
    STACK="$STACK_choice"
    break
  fi
  echo "Invalid selection. Please choose 1 or 2."
done

# ---------------------------------------------------------------------------
# 3. Prompt for model option
# ---------------------------------------------------------------------------
OPENAI_BRAINSTORM=false
echo ""
echo "Select model option:"
select MODEL_choice in "opencode-go only" "opencode-go + OpenAI"; do
  case "$MODEL_choice" in
    "opencode-go only")
      MODELS="opencode-go"
      break
      ;;
    "opencode-go + OpenAI")
      MODELS="opencode-go+openai"
      echo ""
      read -rp "Also override brainstorm to openai/gpt-5.5? [y/N]: " BRAINSTORM_REPLY
      BRAINSTORM_REPLY_LOWER="$(echo "${BRAINSTORM_REPLY:-n}" | tr '[:upper:]' '[:lower:]')"
      if [[ "$BRAINSTORM_REPLY_LOWER" == "y" || "$BRAINSTORM_REPLY_LOWER" == "yes" ]]; then
        OPENAI_BRAINSTORM=true
      fi
      break
      ;;
    *)
      echo "Invalid selection. Please choose 1 or 2."
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 4. Prompt for target directory
# ---------------------------------------------------------------------------
echo ""
read -rp "Target directory path or name: " TARGET_INPUT
if [[ -z "$TARGET_INPUT" ]]; then
  die "Target directory cannot be empty."
fi

# Resolve to absolute path
TARGET="$(cd "$(dirname "$TARGET_INPUT")" 2>/dev/null && echo "$(pwd)/$(basename "$TARGET_INPUT")" || echo "$TARGET_INPUT")"

# If the directory doesn't exist yet, it's fine; otherwise check it's empty
if [[ -d "$TARGET" ]]; then
  if [[ -n "$(ls -A "$TARGET" 2>/dev/null)" ]]; then
    die "Target directory '$TARGET' already exists and is not empty. Aborting."
  fi
fi

echo "Target: $TARGET"

# ---------------------------------------------------------------------------
# 5. Build staging directory
# ---------------------------------------------------------------------------
STAGE="$(mktemp -d)"
# (trap is set later so it can cover both $STAGE and the dedupe tempfile)

echo "Building staging area in $STAGE ..."

# --- 5a. Copy core directories (base layer) ---
# opencode/ → .opencode/
cp -R "$ROOT/core/opencode" "$STAGE/.opencode"

# claude/ → .claude/
cp -R "$ROOT/core/claude" "$STAGE/.claude"

# agents/ → .agents/
cp -R "$ROOT/core/agents" "$STAGE/.agents"

# docs/ → docs/
cp -R "$ROOT/core/docs" "$STAGE/docs"

# --- 5b. Copy root files from core ---
cp "$ROOT/core/AGENTS.md" "$STAGE/AGENTS.md"
cp "$ROOT/core/CLAUDE.md" "$STAGE/CLAUDE.md"
cp "$ROOT/core/CONTEXT-MAP.md" "$STAGE/CONTEXT-MAP.md"
cp "$ROOT/core/opencode.json" "$STAGE/opencode.json"
cp "$ROOT/core/models-openai.json" "$STAGE/models-openai.json"
cp "$ROOT/core/skills-lock.json" "$STAGE/skills-lock.json"

# --- 5c. Merge stack overlays (stack overrides core) ---

# opencode.json: deep-merge (stack overrides on conflict)
jq -s '.[0] * .[1]' "$ROOT/core/opencode.json" "$ROOT/stacks/$STACK/opencode.json" > "$STAGE/opencode.json"

# .claude/settings.json: merge permission arrays by tier with de-duplication
jq -s '
  def uniq_array(a; b): ((a // []) + (b // [])) | unique;
  .[0] as $core | .[1] as $stack |
  ($core * $stack)
  | .permissions.allow = uniq_array($core.permissions.allow; $stack.permissions.allow)
  | .permissions.ask = uniq_array($core.permissions.ask; $stack.permissions.ask)
  | .permissions.deny = uniq_array($core.permissions.deny; $stack.permissions.deny)
' "$ROOT/core/claude/settings.json" "$ROOT/stacks/$STACK/claude/settings.json" > "$STAGE/.claude/settings.json"

# skills-lock.json: merge only if stack has one
if [[ -f "$ROOT/stacks/$STACK/skills-lock.json" ]]; then
  jq -s '{ version: (.[0].version // .[1].version // 1), skills: ((.[0].skills // {}) * (.[1].skills // {})) }' \
    "$ROOT/core/skills-lock.json" "$ROOT/stacks/$STACK/skills-lock.json" > "$STAGE/skills-lock.json"
else
  cp "$ROOT/core/skills-lock.json" "$STAGE/skills-lock.json"
fi

# --- 5d. AGENTS.md: concatenate core + stack (stack appended) ---
if [[ -f "$ROOT/stacks/$STACK/AGENTS.md" ]]; then
  {
    cat "$ROOT/core/AGENTS.md"
    echo ""
    cat "$ROOT/stacks/$STACK/AGENTS.md"
  } > "$STAGE/AGENTS.md"
else
  cp "$ROOT/core/AGENTS.md" "$STAGE/AGENTS.md"
fi

# --- 5e. Role docs: concatenate core + stack additions ---
# For each .md in core/docs/agents/ AND stacks/<stack>/docs/agents/ with the
# same name, concatenate with a blank line between. Otherwise copy as-is.
mkdir -p "$STAGE/docs/agents"

# Collect all unique filenames from both sides, then process each
# (bash 3.2 compatible: no associative arrays; dedupe via sort -u)
_seen_tmp="$(mktemp)"
trap 'rm -rf "$STAGE" "$_seen_tmp"' EXIT
for f in "$ROOT/core/docs/agents/"*.md "$ROOT/stacks/$STACK/docs/agents/"*.md; do
  [[ -f "$f" ]] || continue
  fname="$(basename "$f")"
  grep -qxF "$fname" "$_seen_tmp" && continue
  echo "$fname" >> "$_seen_tmp"

  core_file="$ROOT/core/docs/agents/$fname"
  stack_file="$ROOT/stacks/$STACK/docs/agents/$fname"

  if [[ -f "$core_file" && -f "$stack_file" ]]; then
    {
      cat "$core_file"
      echo ""
      cat "$stack_file"
    } > "$STAGE/docs/agents/$fname"
  elif [[ -f "$core_file" ]]; then
    cp "$core_file" "$STAGE/docs/agents/$fname"
  elif [[ -f "$stack_file" ]]; then
    cp "$stack_file" "$STAGE/docs/agents/$fname"
  fi
done
rm -f "$_seen_tmp"

# --- 5f. OpenAI patch (model option) ---
if [[ "$MODELS" == "opencode-go+openai" ]]; then
  if [[ "$OPENAI_BRAINSTORM" == "true" ]]; then
    OPENAI_PATCH_FILE="$ROOT/core/models-openai-brainstorm.json"
  else
    OPENAI_PATCH_FILE="$ROOT/core/models-openai.json"
  fi
  jq -s '.[0] * .[1]' "$STAGE/opencode.json" "$OPENAI_PATCH_FILE" > "$STAGE/opencode.json.tmp"
  mv "$STAGE/opencode.json.tmp" "$STAGE/opencode.json"
fi

# ---------------------------------------------------------------------------
# 6. Copy staged content into target
# ---------------------------------------------------------------------------
mkdir -p "$TARGET"
cp -R "$STAGE/." "$TARGET/"

echo "Staged files copied to $TARGET"

# ---------------------------------------------------------------------------
# 7. Create Claude authored-skill symlinks
# ---------------------------------------------------------------------------
# Each symlink lives at TARGET/.claude/skills/<name> and points to
# ../../.agents/skills/<name> (relative from the .claude/skills dir).
AUTHORED_SKILLS=(
  "grill-with-docs"
  "workflow-bug-analysis"
  "workflow-brainstorming"
  "workflow-planning"
  "workflow-verification"
  "feature-documentation"
  "git-publish"
  "change-request-publish"
  "change-request-comments"
  "issue-tracker"
)

mkdir -p "$TARGET/.claude/skills"
for skill_name in "${AUTHORED_SKILLS[@]}"; do
  ln -sfn "../../.agents/skills/$skill_name" "$TARGET/.claude/skills/$skill_name"
done

# Verify user-invocable: false in each authored skill's SKILL.md
echo "Verifying authored skill frontmatter..."
for skill_name in "${AUTHORED_SKILLS[@]}"; do
  skill_md="$TARGET/.agents/skills/$skill_name/SKILL.md"
  if [[ -f "$skill_md" ]]; then
    if ! grep -q "user-invocable: false" "$skill_md"; then
      echo "WARNING: $skill_md is missing 'user-invocable: false' in frontmatter."
    fi
  else
    echo "WARNING: $skill_md not found; symlink verification skipped."
  fi
done

# ---------------------------------------------------------------------------
# 7b. Install .claude/agents/*.md
# ---------------------------------------------------------------------------
echo ""
for agent_file in "$STAGE/.claude/agents/"*.md; do
  [[ -f "$agent_file" ]] || continue
  fname="$(basename "$agent_file")"
  dst="$TARGET/.claude/agents/$fname"
  if [[ -e "$dst" ]]; then
    echo "  Skipping .claude/agents/$fname (already exists)"
  else
    mkdir -p "$TARGET/.claude/agents"
    cp "$agent_file" "$dst"
    echo "  Installed .claude/agents/$fname"
  fi
done

# ---------------------------------------------------------------------------
# 8. Install remote skills from merged lock file
# ---------------------------------------------------------------------------
if [[ "$NPX_AVAILABLE" == "true" ]]; then
  echo "Installing remote skills from skills-lock.json..."
  skill_keys=$(jq -r '.skills | keys[]' "$TARGET/skills-lock.json")
  for key in $skill_keys; do
    source_repo=$(jq -r ".skills[\"$key\"].source // empty" "$TARGET/skills-lock.json")
    source_type=$(jq -r ".skills[\"$key\"].sourceType // empty" "$TARGET/skills-lock.json")
    [[ -n "$source_repo" ]] || continue
    # Map the lock source to a `skills` CLI source arg:
    #   github -> owner/repo shorthand; gitlab -> full URL.
    case "$source_type" in
      gitlab) src="https://gitlab.com/$source_repo" ;;
      *)      src="$source_repo" ;;
    esac
    echo "  Installing $key from $src ..."
    # Install the canonical SKILL.md tree into .agents/skills/ (the shared
    # agents dir, also read by OpenCode), then symlink it into .claude/skills/
    # exactly like the authored skills above.
    if ( cd "$TARGET" && npx --yes skills add "$src" --skill "$key" -a opencode --yes ); then
      ln -sfn "../../.agents/skills/$key" "$TARGET/.claude/skills/$key"
    else
      echo "  WARNING: failed to install $key"
    fi
  done
else
  echo ""
  echo "npx not available; manually install these remote skills with 'npx skills add':"
  jq -r '.skills | keys[]' "$TARGET/skills-lock.json" | while read -r key; do
    source_repo=$(jq -r ".skills[\"$key\"].source // empty" "$TARGET/skills-lock.json")
    source_type=$(jq -r ".skills[\"$key\"].sourceType // empty" "$TARGET/skills-lock.json")
    echo "  - $key ($source_type/$source_repo)"
  done
fi

# ---------------------------------------------------------------------------
# 9. Print next steps
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "Toolkit initialized successfully!"
echo "========================================"
echo ""
echo "  Target:      $TARGET"
echo "  Stack:       $STACK"
echo "  Models:      $MODELS"
if [[ "$OPENAI_BRAINSTORM" == "true" ]]; then
  echo "  OpenAI brainstorm override: yes"
else
  echo "  OpenAI brainstorm override: no"
fi
echo ""
echo "Installed assets:"
echo "  - OpenCode agents in .opencode/agents/"
echo "  - Claude workflow skills in .claude/skills/"
echo "  - Authored skills in .agents/skills/"
echo "  - DDD docs in docs/"
echo "  - Area docs (AGENTS.md, ARCHITECTURE.md, etc.)"
echo "  - Configuration: opencode.json, .claude/settings.json"
echo ""
echo "Next steps:"
echo "  cd $TARGET"
echo "  # Review AGENTS.md and customize for your project"
echo "  # Start with @brainstorm or /brainstorm"
echo ""
