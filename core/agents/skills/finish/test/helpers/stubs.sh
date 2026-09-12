#!/usr/bin/env bash

# Shared stubs for finish skill tests.
# Source this file from Bats setup() before creating the fixture; then call
# setup_finish_stubs after TMP, ROOT, CALLS, and VIEW_COUNT are set.

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

setup_finish_stubs() {
  : "${TEST_DIR:?TEST_DIR is required}"
  : "${TMP:?TMP is required}"
  : "${ROOT:?ROOT is required}"
  : "${CALLS:?CALLS is required}"
  : "${VIEW_COUNT:?VIEW_COUNT is required}"

  setup_gh_stub
  setup_publisher_stub
  setup_git_freshness_stubs
}

setup_gh_stub() {
  cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >> "$CALLS"
case "${1:-} ${2:-}" in
  "repo view")
    if [ "${GH_REPO_VIEW_RC:-0}" -ne 0 ]; then exit "$GH_REPO_VIEW_RC"; fi
    printf '%s\n' "${GH_REPO_NAME_WITH_OWNER:-example/repo}"
    ;;
  "pr list")
    if [ "${GH_PR_LIST_RC:-0}" -ne 0 ]; then exit "$GH_PR_LIST_RC"; fi
    printf '%s\n' "${GH_PR_LIST_JSON:-[]}"
    ;;
  "pr view")
    if [ "${GH_PR_VIEW_RC:-0}" -ne 0 ]; then exit "$GH_PR_VIEW_RC"; fi
    head_oid="${GH_HEAD_OID:-abc123def456abc123def456abc123def456abc1}"
    identity_repo="${GH_PR_IDENTITY_REPO:-example/repo}"
    identity_head="${GH_PR_IDENTITY_HEAD_REF:-$("$REAL_GIT" rev-parse --abbrev-ref HEAD)}"
    identity_base="${GH_PR_IDENTITY_BASE:-main}"
    identity_owner="${identity_repo%/*}"
    identity_name="${identity_repo#*/}"
    # Model GitHub's stale PR head view right after a force-push: the first
    # GH_VIEW_STALE_READS pr view calls report GH_VIEW_STALE_OID instead of
    # the real head, then the view converges. Stale reads do not advance the
    # draft->ready sequence because they observe the same pre-mutation state.
    stale_file="${VIEW_COUNT}-stale"
    stale_n="$(cat "$stale_file" 2>/dev/null || printf '0')"
    stale_n=$((stale_n + 1))
    printf '%s\n' "$stale_n" > "$stale_file"
    if [ "$stale_n" -le "${GH_VIEW_STALE_READS:-0}" ]; then
      head_oid="${GH_VIEW_STALE_OID:-$head_oid}"
      state="OPEN"
      draft=true
      if [ "${GH_VIEW_SEQUENCE:-}" = closed ]; then
        state="CLOSED"; draft=false
      fi
      printf '{"state":"%s","isDraft":%s,"url":"https://github.com/example/repo/pull/42","headRefOid":"%s","headRefName":"%s","baseRefName":"%s","headRepository":{"name":"%s"},"headRepositoryOwner":{"login":"%s"}}\n' \
        "$state" "$draft" "$head_oid" "$identity_head" "$identity_base" "$identity_name" "$identity_owner"
      exit 0
    fi
    count="$(cat "$VIEW_COUNT")"
    # Only readiness views (they request isDraft) advance the draft->ready sequence.
    case "$*" in
      *isDraft*)
        count=$((count + 1))
        printf '%s\n' "$count" > "$VIEW_COUNT"
        ;;
    esac
    if [ "$count" -gt 1 ] && [ -n "${GH_VIEW_AFTER_READY_OID:-}" ]; then
      head_oid="$GH_VIEW_AFTER_READY_OID"
    fi
    state="OPEN"
    draft=true
    if [ "${GH_VIEW_SEQUENCE:-}" = closed ]; then
      state="CLOSED"; draft=false
    elif [ "${GH_VIEW_SEQUENCE:-}" = ready ]; then
      draft=false
    elif [ "${GH_VIEW_SEQUENCE:-}" = draft ] && [ "$count" -gt 1 ]; then
      draft=false
    fi
    printf '{"state":"%s","isDraft":%s,"url":"https://github.com/example/repo/pull/42","headRefOid":"%s","headRefName":"%s","baseRefName":"%s","headRepository":{"name":"%s"},"headRepositoryOwner":{"login":"%s"}}\n' \
      "$state" "$draft" "$head_oid" "$identity_head" "$identity_base" "$identity_name" "$identity_owner"
    ;;
  "pr ready") exit "${GH_READY_RC:-0}" ;;
  *) printf 'unexpected gh command\n' >&2; exit 2 ;;
esac
STUB
  chmod +x "$TMP/bin/gh"
}

setup_publisher_stub() {
  cat > "$TMP/publisher" <<'PUBLISHER'
#!/usr/bin/env bash
set -euo pipefail
printf 'publisher %s\n' "$*" >> "$CALLS"
if [ "${PUBLISH_RC:-0}" -ne 0 ]; then exit "$PUBLISH_RC"; fi
printf 'https://github.com/example/repo/pull/42\n'
PUBLISHER
  chmod +x "$TMP/publisher"
}

setup_git_freshness_stubs() {
  # Stub git for fetch, merge-base, and rebase operations used by ensure-fresh.sh.
  # Delegates real operations through to the real git when not intercepted.
  cat > "$TMP/bin/git" <<'GIT_STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$CALLS"
case "${1:-}" in
  fetch)
    exit "${FRESH_FETCH_RC:-0}"
    ;;
  merge-base)
    if [ "${2:-}" = "--is-ancestor" ]; then
      if [ "${FRESHNESS_RECHECKING:-0}" = "1" ]; then
        # Recheck mode — use the recheck-specific env var
        if [ "${FRESH_RECHECK_IS_ANCESTOR:-yes}" = "yes" ]; then
          exit 0
        else
          exit 1
        fi
      else
        # Initial mode
        if [ "${FRESH_IS_ANCESTOR:-yes}" = "yes" ]; then
          exit 0
        else
          exit 1
        fi
      fi
    fi
    # Fall through to real git for other merge-base queries
    exec "$REAL_GIT" "$@" 2>/dev/null
    ;;
  rebase)
    exit "${FRESH_REBASE_RC:-0}"
    ;;
  ls-remote)
    # Intercept before the real-git fallback so publication discovery never hits the network.
    if [ "${FRESH_REMOTE_HEAD_RC:-0}" -ne 0 ]; then exit "$FRESH_REMOTE_HEAD_RC"; fi
    if [ -n "${FRESH_REMOTE_HEAD_SHA:-}" ]; then
      printf '%s\t%s\n' "$FRESH_REMOTE_HEAD_SHA" "${3:-}"
    fi
    exit 0
    ;;
  rev-parse)
    # TEST_BRANCH overrides the abbreviated branch name so tests can pin
    # main/detached-HEAD handling without a real checkout.
    if [ "${2:-}" = "--abbrev-ref" ] && [ -n "${TEST_BRANCH:-}" ]; then
      printf '%s\n' "$TEST_BRANCH"
      exit 0
    fi
    exec "$REAL_GIT" "$@" 2>/dev/null
    ;;
  *)
    exec "$REAL_GIT" "$@" 2>/dev/null
    ;;
esac
GIT_STUB
  chmod +x "$TMP/bin/git"
}
