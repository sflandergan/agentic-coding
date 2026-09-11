#!/usr/bin/env bash
#
# test-installer.sh — Smoke-test init.sh and copy.sh installer output.
#
# Usage:
#   bash scripts/test-installer.sh <scratch-root>
#
# <scratch-root> must be under .temp/ — this script refuses to
# operate outside the repo's own scratch space.
#
# Exits 0 on success, 1 on any assertion failure.
#
# shellcheck disable=SC2317  # trap-exit functions are used by name

set -euo pipefail

# ---------------------------------------------------------------------------
# Guard: scratch root must be under .temp/
# ---------------------------------------------------------------------------
SCRATCH="$(cd "$1" && pwd)" 2>/dev/null || {
  echo "ERROR: usage: $0 <scratch-root>" >&2
  exit 1
}
case "$SCRATCH" in
  */".temp"/*|*/".temp")
    ;;
  *)
    echo "ERROR: scratch root must be under .temp/ (got: $SCRATCH)" >&2
    exit 1
    ;;
esac

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colours for pass/fail
PASS="  PASS"
FAIL="  FAIL"

pass_count=0
fail_count=0

pass() {
  local label="$1"
  echo "$PASS  $label"
  pass_count=$((pass_count + 1))
}

fail() {
  local label="$1"
  echo "$FAIL  $label"
  fail_count=$((fail_count + 1))
}

assert() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_not() {
  local label="$1"
  shift
  if "$@" &>/dev/null; then
    fail "$label (unexpectedly succeeded)"
  else
    pass "$label"
  fi
}

# ---------------------------------------------------------------------------
# Canonical authored skill names
# ---------------------------------------------------------------------------
AUTHORED_SKILLS="brainstorm bugfix feature-documentation finish git-publish github-pr-comments grill-with-docs idea implement implement-task planner planning-structure review-code review-plan ui-design ui-design-task verification-before-completion"

# Hidden (support/worker) skills that should have user-invocable: false
HIDDEN_SKILLS="feature-documentation git-publish github-pr-comments implement-task planning-structure ui-design-task verification-before-completion"

# ---------------------------------------------------------------------------
# Execute piped init and capture output; return staged target path on stdout.
# ---------------------------------------------------------------------------
run_init() {
  local stack_choice="$1"   # 1=pnpm, 2=maven
  local model_choice="$2"   # 1=opencode-go only, 2=+openai
  local target="$3"
  local brainstorm_y="${4:-n}"

  if [[ "$model_choice" == "2" ]]; then
    printf '%s\n%s\n%s\n%s\n' "$stack_choice" "$model_choice" "$brainstorm_y" "$target" \
      | bash "$REPO_ROOT/scripts/init.sh" 2>/dev/null
  else
    printf '%s\n%s\n%s\n' "$stack_choice" "$model_choice" "$target" \
      | bash "$REPO_ROOT/scripts/init.sh" 2>/dev/null
  fi
  echo "$target"
}

# ---------------------------------------------------------------------------
# Execute piped copy and capture output
# ---------------------------------------------------------------------------
run_copy() {
  local target="$1"
  local stack_choice="$2"   # 1=pnpm, 2=maven
  local model_choice="$3"   # 1=opencode-go only, 2=+openai
  local skills_mode="$4"    # 1=skip, 2=add, 3=override

  if [[ "$model_choice" == "2" ]]; then
    printf '%s\n%s\n%s\n' "$stack_choice" "$model_choice" "$skills_mode" \
      | bash "$REPO_ROOT/scripts/copy.sh" "$target" 2>/dev/null
  else
    printf '%s\n%s\n%s\n' "$stack_choice" "$model_choice" "$skills_mode" \
      | bash "$REPO_ROOT/scripts/copy.sh" "$target" 2>/dev/null
  fi
}

# ===================================================================
# TEST: Fresh pnpm init
# ===================================================================
echo ""
echo "=== Fresh pnpm init ==="
PNPM_TARGET="$SCRATCH/skill-smoke-pnpm"
mkdir -p "$SCRATCH"
run_init 1 1 "$PNPM_TARGET"

for skill_name in $AUTHORED_SKILLS; do
  assert "pnpm: .agents/skills/$skill_name/SKILL.md exists" \
    test -f "$PNPM_TARGET/.agents/skills/$skill_name/SKILL.md"

  actual_link="$(readlink "$PNPM_TARGET/.claude/skills/$skill_name" 2>/dev/null || echo '')"
  assert "pnpm: .claude/skills/$skill_name symlinks to ../../.agents/skills/$skill_name" \
    test "$actual_link" = "../../.agents/skills/$skill_name"
done

assert "pnpm: .opencode/agents/idea.md exists" \
  test -f "$PNPM_TARGET/.opencode/agents/idea.md"
assert "pnpm: .opencode/agents/ui-design.md exists" \
  test -f "$PNPM_TARGET/.opencode/agents/ui-design.md"
assert "pnpm: .opencode/agents/ui-design-task.md exists" \
  test -f "$PNPM_TARGET/.opencode/agents/ui-design-task.md"

assert "pnpm: docs/agents/idea.md exists" \
  test -f "$PNPM_TARGET/docs/agents/idea.md"
assert "pnpm: docs/agents/ui-design.md exists" \
  test -f "$PNPM_TARGET/docs/agents/ui-design.md"
assert "pnpm: docs/agents/ui-design-task.md exists" \
  test -f "$PNPM_TARGET/docs/agents/ui-design-task.md"

# Lock file has impeccable from pbakaus/impeccable
assert "pnpm: skills-lock.json has impeccable from pbakaus/impeccable" \
  jq -e '.skills.impeccable.source == "pbakaus/impeccable"' "$PNPM_TARGET/skills-lock.json"

# Toolkit does NOT supply preview.sh
assert_not "pnpm: no toolkit-supplied preview.sh" \
  test -f "$PNPM_TARGET/.agents/scripts/ui-design/preview.sh"

# Hidden skills have user-invocable: false
for hidden in $HIDDEN_SKILLS; do
  assert "pnpm: hidden skill $hidden has user-invocable: false" \
    grep -q "user-invocable: false" "$PNPM_TARGET/.agents/skills/$hidden/SKILL.md"
done

# ===================================================================
# TEST: Fresh maven init
# ===================================================================
echo ""
echo "=== Fresh maven init ==="
MAVEN_TARGET="$SCRATCH/skill-smoke-maven"
run_init 2 1 "$MAVEN_TARGET"

for skill_name in $AUTHORED_SKILLS; do
  assert "maven: .agents/skills/$skill_name/SKILL.md exists" \
    test -f "$MAVEN_TARGET/.agents/skills/$skill_name/SKILL.md"

  actual_link="$(readlink "$MAVEN_TARGET/.claude/skills/$skill_name" 2>/dev/null || echo '')"
  assert "maven: .claude/skills/$skill_name symlinks to ../../.agents/skills/$skill_name" \
    test "$actual_link" = "../../.agents/skills/$skill_name"
done

assert "maven: .opencode/agents/idea.md exists" \
  test -f "$MAVEN_TARGET/.opencode/agents/idea.md"
assert "maven: .opencode/agents/ui-design.md exists" \
  test -f "$MAVEN_TARGET/.opencode/agents/ui-design.md"
assert "maven: .opencode/agents/ui-design-task.md exists" \
  test -f "$MAVEN_TARGET/.opencode/agents/ui-design-task.md"

assert "maven: docs/agents/idea.md exists" \
  test -f "$MAVEN_TARGET/docs/agents/idea.md"
assert "maven: docs/agents/ui-design.md exists" \
  test -f "$MAVEN_TARGET/docs/agents/ui-design.md"
assert "maven: docs/agents/ui-design-task.md exists" \
  test -f "$MAVEN_TARGET/docs/agents/ui-design-task.md"

assert "maven: skills-lock.json has impeccable from pbakaus/impeccable" \
  jq -e '.skills.impeccable.source == "pbakaus/impeccable"' "$MAVEN_TARGET/skills-lock.json"

assert_not "maven: no toolkit-supplied preview.sh" \
  test -f "$MAVEN_TARGET/.agents/scripts/ui-design/preview.sh"

# ===================================================================
# TEST: Existing-target copy — add / override / skip modes
# ===================================================================
echo ""
echo "=== Existing-target copy modes ==="

# Create base fixture: a mini repo with a project-owned brainstorm skill,
# a non-symlink Claude customization, and a target-owned preview adapter.
BASE="$SCRATCH/skill-smoke-copy-base"
mkdir -p "$BASE/.agents/skills/brainstorm"
mkdir -p "$BASE/.agents/scripts/ui-design"
mkdir -p "$BASE/.claude/skills/brainstorm"
printf '%s\n' 'project skill marker' > "$BASE/.agents/skills/brainstorm/SKILL.md"
printf '%s\n' 'project Claude marker' > "$BASE/.claude/skills/brainstorm/KEEP.md"
cat > "$BASE/.agents/scripts/ui-design/preview.sh" << 'PREVIEW_EOF'
#!/usr/bin/env bash
printf "project-preview:%s\n" "$1"
PREVIEW_EOF

git -C "$BASE" init
git -C "$BASE" add .
git -C "$BASE" -c user.name='Smoke Test' -c user.email='smoke@example.com' commit -q -m 'test: add existing customization'

# Clone for each mode
ADD_TARGET="$SCRATCH/skill-smoke-copy-add"
OVERRIDE_TARGET="$SCRATCH/skill-smoke-copy-override"
SKIP_TARGET="$SCRATCH/skill-smoke-copy-skip"
git clone --quiet "$BASE" "$ADD_TARGET"
git clone --quiet "$BASE" "$OVERRIDE_TARGET"
git clone --quiet "$BASE" "$SKIP_TARGET"

# Run copy with add mode
run_copy "$ADD_TARGET" 1 1 2
# Run copy with override mode
run_copy "$OVERRIDE_TARGET" 1 1 3
# Run copy with skip mode
run_copy "$SKIP_TARGET" 1 1 1

# add mode preserves existing project skill marker
assert "add mode: preserves existing project skill marker" \
  grep -q 'project skill marker' "$ADD_TARGET/.agents/skills/brainstorm/SKILL.md"

# skip mode preserves existing project skill marker
assert "skip mode: preserves existing project skill marker" \
  grep -q 'project skill marker' "$SKIP_TARGET/.agents/skills/brainstorm/SKILL.md"

# override mode replaces the skill (project marker gone)
assert_not "override mode: replaces existing skill (project marker gone)" \
  grep -q 'project skill marker' "$OVERRIDE_TARGET/.agents/skills/brainstorm/SKILL.md"

# Override mode should have the toolkit's brainstrom SKILL.md
assert "override mode: has toolkit brainstorm SKILL.md" \
  test -f "$OVERRIDE_TARGET/.agents/skills/brainstorm/SKILL.md"

# Non-symlink Claude customization preserved in add and skip modes
assert "add mode: preserves non-symlink Claude KEEP.md" \
  test -f "$ADD_TARGET/.claude/skills/brainstorm/KEEP.md"
assert "skip mode: preserves non-symlink Claude KEEP.md" \
  test -f "$SKIP_TARGET/.claude/skills/brainstorm/KEEP.md"

# Override mode replaces the claude skill dir with a symlink
actual_link_override="$(readlink "$OVERRIDE_TARGET/.claude/skills/brainstorm" 2>/dev/null || echo '')"
assert "override mode: claude brainstorm is symlink to canonical target" \
  test "$actual_link_override" = "../../.agents/skills/brainstorm"

# All modes preserve the target-owned preview adapter
for mode_path in "$ADD_TARGET" "$OVERRIDE_TARGET" "$SKIP_TARGET"; do
  assert "${mode_path##*/}: preserves target-owned preview.sh" \
    cmp -s "$BASE/.agents/scripts/ui-design/preview.sh" "$mode_path/.agents/scripts/ui-design/preview.sh"
done

# ===================================================================
# Summary
# ===================================================================
echo ""
echo "========================================"
echo "  Results: $pass_count passed, $fail_count failed"
echo "========================================"

if [[ "$fail_count" -gt 0 ]]; then
  exit 1
fi
exit 0