#!/usr/bin/env bash
#
# copy.sh — Copy the agentic-coding toolkit into an existing Git project.
#
# Merges toolkit assets into a target project, preserving user-customized
# files and prompting before overwriting non-mergeable content.

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve toolkit root
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_tool() {
  local tool="$1"
  local hint="$2"
  if ! command -v "$tool" &>/dev/null; then
    die "'$tool' is required but not found on PATH. $hint"
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

# Prompt yes/no. $1 = prompt text, $2 = default (y or n). Returns 0 for yes.
ask_yn() {
  local prompt="$1"
  local default="${2:-n}"
  local hint
  if [[ "$default" == "y" ]]; then
    hint="Y/n"
  else
    hint="y/N"
  fi
  local reply
  read -rp "$prompt [$hint]: " reply
  reply="${reply:-$default}"
  reply_lower="$(echo "$reply" | tr '[:upper:]' '[:lower:]')"
  [[ "$reply_lower" == "y" || "$reply_lower" == "yes" ]]
}

# Ensure the .claude/skills/<name> symlink reflects the chosen SKILLS_MODE.
#   skip     -> never touch symlinks
#   add      -> create only when nothing exists (new or unlinked skill)
#   override -> always (re)point to the canonical target
ensure_symlink() {
  local skill_name="$1"
  local link_path="$TARGET/.claude/skills/$skill_name"
  local expected_target="../../.agents/skills/$skill_name"

  case "$SKILLS_MODE" in
    skip)
      return
      ;;
    add)
      [[ -d "$TARGET/.agents/skills/$skill_name" ]] || return
      # Leave anything already present untouched in add-only mode.
      [[ -L "$link_path" || -e "$link_path" ]] && return
      mkdir -p "$TARGET/.claude/skills"
      ln -s "$expected_target" "$link_path"
      COPIED+=(".claude/skills/$skill_name symlink (new)")
      ;;
    override)
      mkdir -p "$TARGET/.claude/skills"
      if [[ -L "$link_path" ]]; then
        [[ "$(readlink "$link_path")" == "$expected_target" ]] && return
        rm -f "$link_path"
        ln -s "$expected_target" "$link_path"
        COPIED+=(".claude/skills/$skill_name symlink (repointed)")
      elif [[ -e "$link_path" ]]; then
        rm -rf "$link_path"
        ln -s "$expected_target" "$link_path"
        COPIED+=(".claude/skills/$skill_name symlink (replaced non-symlink)")
      else
        ln -s "$expected_target" "$link_path"
        COPIED+=(".claude/skills/$skill_name symlink (new)")
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 1. Validate arguments
# ---------------------------------------------------------------------------
if [[ $# -ne 1 ]]; then
  die "Usage: $0 <target-project-path>"
fi

TARGET="$1"

# Resolve to absolute path
if [[ -d "$TARGET" ]]; then
  TARGET="$(cd "$TARGET" && pwd)"
else
  die "Target '$TARGET' does not exist."
fi

# ---------------------------------------------------------------------------
# 2. Validate target is a Git repo with clean working tree
# ---------------------------------------------------------------------------
if ! git -C "$TARGET" rev-parse --git-dir &>/dev/null; then
  die "'$TARGET' is not a Git repository."
fi

if [[ -n "$(git -C "$TARGET" status --short 2>/dev/null)" ]]; then
  die "Working tree in '$TARGET' is dirty. Please commit or stash changes before running copy."
fi

echo "Target project: $TARGET"

# ---------------------------------------------------------------------------
# 3. Check required tools
# ---------------------------------------------------------------------------
require_tool jq "Install with: brew install jq"
NPX_AVAILABLE=true
warn_tool npx "Install Node.js (provides npx) to enable remote skill installation. It will be skipped." || NPX_AVAILABLE=false

# ---------------------------------------------------------------------------
# 4. Prompt for stack
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
# 5. Prompt for model option
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
      if ask_yn "Also override brainstorm to openai/gpt-5.5?" "n"; then
        OPENAI_BRAINSTORM=true
      fi
      break
      ;;
    *)
      echo "Invalid selection. Please choose 1 or 2."
      ;;
  esac
done

# Ask up front whether to override an existing opencode.json's model selection.
# Only relevant when the target already has one; a new file always gets the
# selected models regardless.
OVERRIDE_MODELS=false
if [[ -f "$TARGET/opencode.json" ]]; then
  echo ""
  if ask_yn "Override model selection in existing opencode.json?" "n"; then
    OVERRIDE_MODELS=true
  fi
fi

# ---------------------------------------------------------------------------
# 5b. Prompt for skills handling mode
# ---------------------------------------------------------------------------
echo ""
echo "How should skills be handled?"
select SKILLS_choice in "Don't modify skills" "Add skills only" "Override skills"; do
  case "$SKILLS_choice" in
    "Don't modify skills") SKILLS_MODE="skip"; break ;;
    "Add skills only")     SKILLS_MODE="add"; break ;;
    "Override skills")      SKILLS_MODE="override"; break ;;
    *) echo "Invalid selection. Please choose 1, 2, or 3." ;;
  esac
done

# ---------------------------------------------------------------------------
# 6. Build staging directory
# ---------------------------------------------------------------------------
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "Building staging area in $STAGE ..."

# --- 6a. Copy core directories (base layer) ---
cp -R "$ROOT/core/opencode" "$STAGE/.opencode"
cp -R "$ROOT/core/claude" "$STAGE/.claude"
cp -R "$ROOT/core/agents" "$STAGE/.agents"
cp -R "$ROOT/core/docs" "$STAGE/docs"

# --- 6b. Copy root files from core ---
cp "$ROOT/core/AGENTS.md" "$STAGE/AGENTS.md"
cp "$ROOT/core/CLAUDE.md" "$STAGE/CLAUDE.md"
cp "$ROOT/core/CONTEXT-MAP.md" "$STAGE/CONTEXT-MAP.md"
cp "$ROOT/core/opencode.json" "$STAGE/opencode.json"
cp "$ROOT/core/models-openai.json" "$STAGE/models-openai.json"
cp "$ROOT/core/skills-lock.json" "$STAGE/skills-lock.json"

# --- 6c. Merge stack overlays (stack overrides core) ---
jq -s '.[0] * .[1]' "$ROOT/core/opencode.json" "$ROOT/stacks/$STACK/opencode.json" > "$STAGE/opencode.json"

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

# --- 6d. AGENTS.md: concatenate core + stack (stack appended) ---
if [[ -f "$ROOT/stacks/$STACK/AGENTS.md" ]]; then
  {
    cat "$ROOT/core/AGENTS.md"
    echo ""
    cat "$ROOT/stacks/$STACK/AGENTS.md"
  } > "$STAGE/AGENTS.md"
else
  cp "$ROOT/core/AGENTS.md" "$STAGE/AGENTS.md"
fi

# --- 6e. Role docs: concatenate core + stack additions ---
mkdir -p "$STAGE/docs/agents"

_seen_role=""
for f in "$ROOT/core/docs/agents/"*.md "$ROOT/stacks/$STACK/docs/agents/"*.md; do
  [[ -f "$f" ]] || continue
  fname="$(basename "$f")"
  # Skip if already processed (simple string-based dedup for bash 3 compat)
  if [[ " $_seen_role " == *" $fname "* ]]; then
    continue
  fi
  _seen_role="$_seen_role $fname"

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

# --- 6f. OpenAI patch (model option) ---
if [[ "$MODELS" == "opencode-go+openai" ]]; then
  if [[ "$OPENAI_BRAINSTORM" == "true" ]]; then
    OPENAI_PATCH_FILE="$ROOT/core/models-openai-brainstorm.json"
  else
    OPENAI_PATCH_FILE="$ROOT/core/models-openai.json"
  fi
  jq -s '.[0] * .[1]' "$STAGE/opencode.json" "$OPENAI_PATCH_FILE" > "$STAGE/opencode.json.tmp"
  mv "$STAGE/opencode.json.tmp" "$STAGE/opencode.json"
fi

echo "Staging area ready."

# ---------------------------------------------------------------------------
# Track files that are skipped for the summary
# ---------------------------------------------------------------------------
SKIPPED=()
COPIED=()

# ---------------------------------------------------------------------------
# 7. AGENTS.md and CLAUDE.md handling
# ---------------------------------------------------------------------------
if [[ -s "$TARGET/AGENTS.md" ]]; then
  echo ""
  echo "AGENTS.md already exists in the target."
  if ask_yn "Keep it as-is? (no = append the toolkit's AGENTS.md to it)" "y"; then
    SKIPPED+=("AGENTS.md (existing non-empty, kept as-is)")
  else
    {
      cat "$TARGET/AGENTS.md"
      echo ""
      cat "$STAGE/AGENTS.md"
    } > "$STAGE/AGENTS.md.tmp"
    mv "$STAGE/AGENTS.md.tmp" "$TARGET/AGENTS.md"
    COPIED+=("AGENTS.md (merged)")
  fi
else
  cp "$STAGE/AGENTS.md" "$TARGET/AGENTS.md"
  COPIED+=("AGENTS.md (new)")
fi

if [[ -f "$TARGET/CLAUDE.md" ]]; then
  SKIPPED+=("CLAUDE.md (existing, skipped)")
else
  cp "$STAGE/CLAUDE.md" "$TARGET/CLAUDE.md"
  COPIED+=("CLAUDE.md (new)")
fi

# ---------------------------------------------------------------------------
# 8. opencode.json handling
# ---------------------------------------------------------------------------
if [[ -f "$TARGET/opencode.json" ]]; then
  if [[ "$OVERRIDE_MODELS" == "true" ]]; then
    # Overlay the selected model values (top-level model/small_model and each
    # agent's model) onto the existing file. Provider/permission keys and any
    # existing per-agent customizations are preserved.
    jq -s '
      .[0] as $existing | .[1] as $staged |
      $existing
      | .model = ($staged.model // $existing.model)
      | .small_model = ($staged.small_model // $existing.small_model)
      | .agent = (
          reduce ($staged.agent // {} | to_entries[]) as $e
            ($existing.agent // {};
             .[$e.key] = ((.[$e.key] // $e.value) + {model: $e.value.model}))
        )
    ' "$TARGET/opencode.json" "$STAGE/opencode.json" > "$STAGE/opencode.json.tmp"
    mv "$STAGE/opencode.json.tmp" "$TARGET/opencode.json"
    COPIED+=("opencode.json (models overridden)")
  else
    jq -s '
      .[0] as $existing | .[1] as $staged |
      $existing | .agent = (($staged.agent // {}) * ($existing.agent // {}))
    ' "$TARGET/opencode.json" "$STAGE/opencode.json" > "$STAGE/opencode.json.tmp"
    mv "$STAGE/opencode.json.tmp" "$TARGET/opencode.json"
    COPIED+=("opencode.json (merged agent entries)")
  fi
else
  cp "$STAGE/opencode.json" "$TARGET/opencode.json"
  COPIED+=("opencode.json (new)")
fi

# ---------------------------------------------------------------------------
# 9. .claude/settings.json handling
# ---------------------------------------------------------------------------
if [[ -f "$TARGET/.claude/settings.json" ]]; then
  mkdir -p "$TARGET/.claude"
  jq -s '
    def uniq_array(a; b): ((a // []) + (b // [])) | unique;
    .[0] as $existing | .[1] as $staged |
    $existing
    | .permissions.allow = uniq_array($existing.permissions.allow; $staged.permissions.allow)
    | .permissions.ask = uniq_array($existing.permissions.ask; $staged.permissions.ask)
    | .permissions.deny = uniq_array($existing.permissions.deny; $staged.permissions.deny)
  ' "$TARGET/.claude/settings.json" "$STAGE/.claude/settings.json" > "$STAGE/.claude/settings.json.tmp"
  mv "$STAGE/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
  COPIED+=(".claude/settings.json (merged permissions)")
else
  mkdir -p "$TARGET/.claude"
  cp "$STAGE/.claude/settings.json" "$TARGET/.claude/settings.json"
  COPIED+=(".claude/settings.json (new)")
fi

# ---------------------------------------------------------------------------
# 10. .opencode/agents/*.md handling
# ---------------------------------------------------------------------------
echo ""
for agent_file in "$STAGE/.opencode/agents/"*.md; do
  [[ -f "$agent_file" ]] || continue
  fname="$(basename "$agent_file")"
  dst="$TARGET/.opencode/agents/$fname"
  if [[ -e "$dst" ]]; then
    if [[ "$SKILLS_MODE" == "override" ]]; then
      mkdir -p "$TARGET/.opencode/agents"
      cp "$agent_file" "$dst"
      COPIED+=(".opencode/agents/$fname (overwritten)")
    else
      SKIPPED+=(".opencode/agents/$fname (existing, skipped)")
    fi
  elif [[ "$SKILLS_MODE" == "skip" ]]; then
    SKIPPED+=(".opencode/agents/$fname (new, skipped: don't modify)")
  else
    mkdir -p "$TARGET/.opencode/agents"
    cp "$agent_file" "$dst"
    COPIED+=(".opencode/agents/$fname (new)")
  fi
done

# ---------------------------------------------------------------------------
# 10b. .claude/agents/*.md handling
# ---------------------------------------------------------------------------
echo ""
for agent_file in "$STAGE/.claude/agents/"*.md; do
  [[ -f "$agent_file" ]] || continue
  fname="$(basename "$agent_file")"
  dst="$TARGET/.claude/agents/$fname"
  if [[ -e "$dst" ]]; then
    if [[ "$SKILLS_MODE" == "override" ]]; then
      mkdir -p "$TARGET/.claude/agents"
      cp "$agent_file" "$dst"
      COPIED+=(".claude/agents/$fname (overwritten)")
    else
      SKIPPED+=(".claude/agents/$fname (existing, skipped)")
    fi
  elif [[ "$SKILLS_MODE" == "skip" ]]; then
    SKIPPED+=(".claude/agents/$fname (new, skipped: don't modify)")
  else
    mkdir -p "$TARGET/.claude/agents"
    cp "$agent_file" "$dst"
    COPIED+=(".claude/agents/$fname (new)")
  fi
done

# ---------------------------------------------------------------------------
# 11. .claude/skills/{brainstorm,bugfix,finish,implement,planner,review-code,review-plan}/
# ---------------------------------------------------------------------------
echo ""
CLAUDE_SKILLS=(brainstorm bugfix finish implement planner review-code review-plan)
for skill_name in "${CLAUDE_SKILLS[@]}"; do
  src="$STAGE/.claude/skills/$skill_name"
  dst="$TARGET/.claude/skills/$skill_name"
  if [[ -e "$dst" ]]; then
    if [[ "$SKILLS_MODE" == "override" ]]; then
      rm -rf "$dst"
      mkdir -p "$TARGET/.claude/skills"
      cp -R "$src" "$dst"
      COPIED+=(".claude/skills/$skill_name/ (overwritten)")
    else
      SKIPPED+=(".claude/skills/$skill_name/ (existing, skipped)")
    fi
  elif [[ "$SKILLS_MODE" == "skip" ]]; then
    SKIPPED+=(".claude/skills/$skill_name/ (new, skipped: don't modify)")
  else
    mkdir -p "$TARGET/.claude/skills"
    cp -R "$src" "$dst"
    COPIED+=(".claude/skills/$skill_name/ (new)")
  fi
done

# ---------------------------------------------------------------------------
# 12. .agents/skills/<authored-skill>/ handling
# ---------------------------------------------------------------------------
echo ""
AUTHORED_SKILLS=(
  grill-with-docs
  workflow-bug-analysis
  workflow-brainstorming
  workflow-planning
  workflow-verification
  feature-documentation
  git-publish
  change-request-publish
  change-request-comments
  issue-tracker
)
for skill_name in "${AUTHORED_SKILLS[@]}"; do
  src="$STAGE/.agents/skills/$skill_name"
  dst="$TARGET/.agents/skills/$skill_name"
  if [[ -e "$dst" ]]; then
    if [[ "$SKILLS_MODE" == "override" ]]; then
      rm -rf "$dst"
      mkdir -p "$TARGET/.agents/skills"
      cp -R "$src" "$dst"
      COPIED+=(".agents/skills/$skill_name/ (overwritten)")
    else
      SKIPPED+=(".agents/skills/$skill_name/ (existing, skipped)")
    fi
  elif [[ "$SKILLS_MODE" == "skip" ]]; then
    SKIPPED+=(".agents/skills/$skill_name/ (new, skipped: don't modify)")
  else
    mkdir -p "$TARGET/.agents/skills"
    cp -R "$src" "$dst"
    COPIED+=(".agents/skills/$skill_name/ (new)")
  fi
  # Symlink follows the skill action (see ensure_symlink / SKILLS_MODE).
  ensure_symlink "$skill_name"
done

# ---------------------------------------------------------------------------
# 13. .claude/README.md handling
# ---------------------------------------------------------------------------
echo ""
if [[ -f "$TARGET/.claude/README.md" ]]; then
  if ask_yn "Overwrite .claude/README.md?" "n"; then
    cp "$STAGE/.claude/README.md" "$TARGET/.claude/README.md"
    COPIED+=(".claude/README.md (overwritten)")
  else
    SKIPPED+=(".claude/README.md (existing, skipped)")
  fi
else
  mkdir -p "$TARGET/.claude"
  cp "$STAGE/.claude/README.md" "$TARGET/.claude/README.md"
  COPIED+=(".claude/README.md (new)")
fi

# ---------------------------------------------------------------------------
# 14. DDD docs and area docs — create missing files only, never overwrite
#     Silent skip with a printed notice per file.
# ---------------------------------------------------------------------------
echo ""
# Top-level area docs
for doc_file in "$STAGE/docs/ARCHITECTURE.md" "$STAGE/docs/CODING_GUIDELINES.md" \
                "$STAGE/docs/TESTING.md" "$STAGE/docs/LOGGING.md" "$STAGE/CONTEXT-MAP.md"; do
  [[ -f "$doc_file" ]] || continue
  fname="$(basename "$doc_file")"
  if [[ "$fname" == "CONTEXT-MAP.md" ]]; then
    target_path="$TARGET/$fname"
  else
    target_path="$TARGET/docs/$fname"
  fi
  if [[ -f "$target_path" ]]; then
    SKIPPED+=("$fname (existing, skipped)")
  else
    mkdir -p "$(dirname "$target_path")"
    cp "$doc_file" "$target_path"
    COPIED+=("$fname (new)")
  fi
done

# Recursive docs: docs/agents/, docs/contexts/, docs/adr/, docs/features/
for subdir in agents contexts adr features; do
  src_dir="$STAGE/docs/$subdir"
  [[ -d "$src_dir" ]] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$STAGE/docs/"}"
    target_path="$TARGET/docs/$rel"
    if [[ -f "$target_path" ]]; then
      SKIPPED+=("docs/$rel (existing, skipped)")
    else
      mkdir -p "$(dirname "$target_path")"
      cp "$file" "$target_path"
      COPIED+=("docs/$rel (new)")
    fi
  done < <(find "$src_dir" -type f -not -name '.gitkeep' -print0)
done

# ---------------------------------------------------------------------------
# 15. skills-lock.json handling
# ---------------------------------------------------------------------------
echo ""
if [[ -f "$TARGET/skills-lock.json" ]]; then
  jq -s '{ version: (.[0].version // .[1].version // 1), skills: ((.[1].skills // {}) * (.[0].skills // {})) }' \
    "$TARGET/skills-lock.json" "$STAGE/skills-lock.json" > "$STAGE/skills-lock.json.tmp"
  mv "$STAGE/skills-lock.json.tmp" "$TARGET/skills-lock.json"
  COPIED+=("skills-lock.json (merged)")
else
  cp "$STAGE/skills-lock.json" "$TARGET/skills-lock.json"
  COPIED+=("skills-lock.json (new)")
fi

# ---------------------------------------------------------------------------
# 16. Install remote skills from merged lock file
# ---------------------------------------------------------------------------
echo ""
if [[ "$SKILLS_MODE" == "skip" ]]; then
  echo "Skills mode is 'don't modify'; skipping remote skill installation."
elif [[ "$NPX_AVAILABLE" == "true" ]]; then
  echo "Installing remote skills from skills-lock.json..."
  skill_keys=$(jq -r '.skills | keys[]' "$TARGET/skills-lock.json")
  for key in $skill_keys; do
    source_repo=$(jq -r ".skills[\"$key\"].source // empty" "$TARGET/skills-lock.json")
    source_type=$(jq -r ".skills[\"$key\"].sourceType // empty" "$TARGET/skills-lock.json")
    [[ -n "$source_repo" ]] || continue
    # add-only: leave already-installed skills untouched.
    if [[ "$SKILLS_MODE" == "add" && -e "$TARGET/.agents/skills/$key" ]]; then
      echo "  Skipping $key (already present; add-only mode)."
      SKIPPED+=("remote skill $key (existing, skipped)")
      continue
    fi
    # Map the lock source to a `skills` CLI source arg:
    #   github -> owner/repo shorthand; gitlab -> full URL.
    case "$source_type" in
      gitlab) src="https://gitlab.com/$source_repo" ;;
      *)      src="$source_repo" ;;
    esac
    echo "  Installing $key from $src ..."
    # Install the canonical SKILL.md tree into .agents/skills/ (also read by
    # OpenCode), then symlink it into .claude/skills/ like the authored skills.
    if ( cd "$TARGET" && npx --yes skills add "$src" --skill "$key" -a opencode --yes ); then
      ensure_symlink "$key"
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
# 17. Print summary
# ---------------------------------------------------------------------------
echo ""
echo "========================================"
echo "Toolkit copy completed!"
echo "========================================"
echo ""
echo "  Target: $TARGET"
echo "  Stack:  $STACK"
echo "  Models: $MODELS"
echo "  Skills: $SKILLS_MODE"
if [[ "$OPENAI_BRAINSTORM" == "true" ]]; then
  echo "  OpenAI brainstorm override: yes"
else
  echo "  OpenAI brainstorm override: no"
fi
echo ""

if [[ ${#COPIED[@]} -gt 0 ]]; then
  echo "Installed files:"
  for item in "${COPIED[@]}"; do
    echo "  + $item"
  done
  echo ""
fi

if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "Skipped files (already exist in target):"
  for item in "${SKIPPED[@]}"; do
    echo "  - $item"
  done
  echo ""
fi

echo "Next steps:"
echo "  cd $TARGET"
echo "  # Review AGENTS.md and customize for your project"
echo "  # Start with @brainstorm or /brainstorm"
echo ""
