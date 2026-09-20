#!/usr/bin/env bash
# Shared fixtures and stubs for publish-branch.bats.
#
# The scratch root is caller-supplied through $SCRATCH and must live below
# .temp/. Tests create named fixture directories under it via new_fixture;
# the bats teardown removes only a nonempty fixture proven below the
# validated root.

# Validate the caller-supplied scratch root. Fails closed on unset/empty
# roots, "/", the workspace root, and paths outside $PWD/.temp/.
validate_scratch_root() {
  if [ -z "${SCRATCH:-}" ]; then
    printf 'SCRATCH must be set to a scratch root below .temp/\n' >&2
    return 1
  fi
  local workspace
  workspace="$(git rev-parse --show-toplevel 2>/dev/null)" || workspace="$PWD"
  case "$SCRATCH" in
    / | "$workspace")
      printf 'SCRATCH must be a scratch root below .temp/, not "/" or the workspace root: %s\n' "$SCRATCH" >&2
      return 1
      ;;
  esac
  case "$SCRATCH" in
    "$PWD/.temp" | "$PWD/.temp"/* | .temp | .temp/*) ;;
    *)
      printf 'SCRATCH must live below .temp/: %s\n' "$SCRATCH" >&2
      return 1
      ;;
  esac
}

# Create a named fixture directory under $SCRATCH and expose it as $FIXTURE_DIR.
# Returns immediately on failed validation; FIXTURE_DIR is assigned only after
# the scratch root and the name have been validated.
new_fixture() {
  local name="$1"
  if [ -z "$name" ]; then
    printf 'Fixture name must not be empty\n' >&2
    return 1
  fi
  validate_scratch_root || return 1
  mkdir -p "$SCRATCH"
  FIXTURE_DIR="$SCRATCH/$name"
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR"
}

# Install the git and gh stubs. Requires STUB_BIN, STUB_DIR, and REAL_GIT.
install_stubs() {
: "${STUB_BIN:?STUB_BIN is required}"
: "${STUB_DIR:?STUB_DIR is required}"
: "${REAL_GIT:?REAL_GIT is required}"

cat > "$STUB_BIN/git" <<'GIT_STUB'
#!/usr/bin/env bash
set -euo pipefail

: "${GIT_STUB_DIR:?GIT_STUB_DIR is required}"
: "${REAL_GIT:?REAL_GIT is required}"
printf '%s\n' "$*" >> "$GIT_STUB_DIR/git.calls"
# Keep query output such as rev-parse available to the helper while silencing
# transport progress that would otherwise contaminate exact URL assertions.
if [ "${1:-}" = push ]; then
  exec "$REAL_GIT" "$@" >/dev/null 2>&1
fi
exec "$REAL_GIT" "$@" 2>/dev/null
GIT_STUB

cat > "$STUB_BIN/gh" <<'GH_STUB'
#!/usr/bin/env bash
set -euo pipefail

: "${GH_STUB_DIR:?GH_STUB_DIR is required}"
printf '%s\n' "$*" >> "$GH_STUB_DIR/gh.calls"

if [ "${1:-}" != "pr" ]; then
  printf 'stub: unexpected gh command: %s\n' "${1:-}" >&2
  exit 2
fi

case "${2:-}" in
  view)
    if [ "${GH_PR_VIEW_EXIT:-0}" -ne 0 ]; then
      exit "$GH_PR_VIEW_EXIT"
    fi
    printf '{"state":"%s","headRefName":"%s","url":"%s"}\n' \
      "${GH_PR_STATE:-OPEN}" "${GH_PR_HEAD:-renovate/entry}" "${GH_PR_URL:-https://github.com/example/repo/pull/42}"
    ;;
  list)
    printf '%s\n' "${GH_PR_LIST_URL:-}"
    ;;
  create)
    printf '%s\n' "${GH_PR_CREATE_OUTPUT:-https://github.com/example/repo/pull/99}"
    ;;
  *)
    printf 'stub: unexpected gh pr subcommand: %s\n' "${2:-}" >&2
    exit 2
    ;;
esac
GH_STUB

chmod +x "$STUB_BIN/git" "$STUB_BIN/gh"
}

reset_logs() {
  rm -f "$STUB_DIR/git.calls" "$STUB_DIR/gh.calls"
}

git_push_count() {
  local count=0 line
  if [ -f "$STUB_DIR/git.calls" ]; then
    while IFS= read -r line; do
      case "$line" in
        push\ *) count=$((count + 1)) ;;
      esac
    done < "$STUB_DIR/git.calls"
  fi
  printf '%s' "$count"
}

git_push_args() {
  local line
  if [ -f "$STUB_DIR/git.calls" ]; then
    while IFS= read -r line; do
      case "$line" in
        push\ *) printf '%s\n' "$line"; return 0 ;;
      esac
    done < "$STUB_DIR/git.calls"
  fi
  return 1
}

remote_sha() {
  "$REAL_GIT" --git-dir="$REMOTE" rev-parse "refs/heads/$1"
}
