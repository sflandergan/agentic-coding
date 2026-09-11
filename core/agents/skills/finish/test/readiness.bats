#!/usr/bin/env bats
set -euo pipefail

setup() {
  TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
  ROOT="$(git rev-parse --show-toplevel)"
  export REAL_GIT="$(command -v git)"

  source "$TEST_DIR/helpers/stubs.sh"
  FIXTURE_DIR=""
  new_fixture "t$BATS_TEST_NUMBER"
  TMP="$FIXTURE_DIR"
  mkdir -p "$TMP/bin"
  export CALLS="$TMP/calls"
  : > "$CALLS"
  export VIEW_COUNT="$TMP/view-count"
  printf '0\n' > "$VIEW_COUNT"

  setup_finish_stubs

  export PATH="$TMP/bin:$PATH"
}

teardown() {
  # Remove only a nonempty fixture proven below the validated scratch root.
  [ -n "${FIXTURE_DIR:-}" ] || return 0
  [ -d "$FIXTURE_DIR" ] || return 0
  [ -n "$(ls -A "$FIXTURE_DIR" 2>/dev/null)" ] || return 0
  validate_scratch_root || return 0
  case "$FIXTURE_DIR" in
    "$SCRATCH"/*) rm -rf "$FIXTURE_DIR" ;;
  esac
}

# --- mark-pr-ready.sh tests (unchanged) ---

@test "draft PR becomes ready" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  [[ "$(<"$CALLS")" == *"gh pr ready 42"* ]] || false
}

@test "already-ready PR is not mutated" {
  run env GH_VIEW_SEQUENCE=ready GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -eq 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "closed PR is rejected" {
  run env GH_VIEW_SEQUENCE=closed GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -ne 0 ]
}

@test "readiness command failure is reported" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=1 GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" == *"gh pr ready 42"* ]] || false
}

@test "PR that stays draft after ready is rejected" {
  run env GH_VIEW_SEQUENCE=stuck-draft GH_READY_RC=0 GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" == *"gh pr ready 42"* ]] || false
}

# --- mark-pr-ready.sh SHA validation tests ---

@test "mark-pr-ready.sh rejects non-40-char SHA" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 short-sha
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$output" == *"40"* ]] || false
}

@test "mark-pr-ready.sh rejects mismatched head before mutation" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 0000000000000000000000000000000000000000
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$output" == *"headRefOid"* ]] || false
}

@test "mark-pr-ready.sh rejects mismatched head after mutation" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    GH_VIEW_AFTER_READY_OID=0000000000000000000000000000000000000000 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" == *"gh pr ready"* ]] || false
  [[ "$output" == *"headRefOid"* ]] || false
}

@test "already-ready path requires exact head equality" {
  run env GH_VIEW_SEQUENCE=ready GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -eq 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "stale head read after publication is retried before readiness" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 \
    GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    GH_VIEW_STALE_READS=1 \
    GH_VIEW_STALE_OID=0000000000000000000000000000000000000000 \
    MARK_PR_READY_RETRY_SECONDS=0 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -eq 0 ]
  [[ "$(<"$CALLS")" == *"gh pr ready"* ]] || false
  [[ "$output" == *"https://github.com/example/repo/pull/42"* ]] || false
}

@test "persistent stale head read stops before readiness" {
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 \
    GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    GH_VIEW_STALE_READS=99 \
    GH_VIEW_STALE_OID=0000000000000000000000000000000000000000 \
    MARK_PR_READY_RETRY_SECONDS=0 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 abc123def456abc123def456abc123def456abc1
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$output" == *"headRefOid"* ]] || false
}

@test "already-ready path rejects mismatched head" {
  run env GH_VIEW_SEQUENCE=ready GH_HEAD_OID=abc123def456abc123def456abc123def456abc1 \
    bash "$ROOT/core/agents/skills/finish/scripts/mark-pr-ready.sh" 42 0000000000000000000000000000000000000000
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$output" == *"headRefOid"* ]] || false
}

# --- ensure-fresh.sh repository root discovery test ---

@test "ensure-fresh.sh works from subdirectory using git discovery" {
  # Create a subdirectory and run ensure-fresh.sh from there.
  # The script uses git commands that discover the root via git itself.
  mkdir -p "$TMP/subdir"
  run env FRESH_IS_ANCESTOR=yes \
    bash -c 'cd "$1/subdir" && bash "$2/core/agents/skills/finish/scripts/ensure-fresh.sh"' _ "$TMP" "$ROOT"
  [ "$status" -eq 0 ]
}

# --- publish-and-ready.sh SHA capture tests ---

@test "publish-and-ready.sh captures SHA and passes to mark-pr-ready.sh" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  [[ "$(<"$CALLS")" == *"gh pr ready"* ]] || false
}

# --- publish-and-ready.sh tests ---

@test "publish then ready composes successfully" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  [[ "$(<"$CALLS")" == *"gh pr ready"* ]] || false
}

@test "publication failure stops before readiness" {
  run env PUBLISH_RC=1 PUBLISH_HELPER="$TMP/publisher" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -ne 0 ]
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "already-current publication skips rebase" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  # No rebase was attempted
  [[ "$(<"$CALLS")" != *"git rebase"* ]] || false
}

@test "behind-base rebase before publication" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  # Skill-level flow: initial ensure-fresh.sh rebases, then publish-and-ready.sh
  # does the pre-publish recheck which finds the base still fresh.
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" \
    FRESH_IS_ANCESTOR=no FRESH_REBASE_RC=0 \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash -c '
      bash "$0/core/agents/skills/finish/scripts/ensure-fresh.sh" >/dev/null
      bash "$0/core/agents/skills/finish/scripts/publish-and-ready.sh"
    ' "$ROOT"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  # Rebase was performed by ensure-fresh.sh
  [[ "$(<"$CALLS")" == *"git rebase"* ]] || false
  # Publication and readiness still happen
  [[ "$(<"$CALLS")" == *"gh pr ready"* ]] || false
}

@test "publication suppressed after rebase failure" {
  # Skill-level flow: initial ensure-fresh.sh rebase fails.
  run env FRESH_IS_ANCESTOR=no FRESH_REBASE_RC=1 \
    bash "$ROOT/core/agents/skills/finish/scripts/ensure-fresh.sh"
  [ "$status" -ne 0 ]
  # Rebase was attempted
  [[ "$(<"$CALLS")" == *"git rebase"* ]] || false
}

@test "base movement before publication triggers retry outcome" {
  # Pre-publish recheck finds base moved and rebases → exit 99 (retry).
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    FRESH_RECHECK_IS_ANCESTOR=no FRESH_REBASE_RC=0 \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 99 ]
  # No publication or readiness was attempted
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr view"* ]] || false
  # Rebase was performed by the recheck
  [[ "$(<"$CALLS")" == *"git rebase"* ]] || false
}

@test "retry after recheck rebase leads to publication" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  # First attempt: recheck finds base moved → exit 99 (retry).
  run env FRESH_RECHECK_IS_ANCESTOR=no FRESH_REBASE_RC=0 \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 99 ]
  # No publisher or readiness was attempted in the first cycle
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false

  # Skill boundary: verification marker — the skill runs the complete
  # applicable verification gate between retry and second attempt.
  printf '>> verification boundary <<\n' >> "$CALLS"

  # Second attempt: recheck finds base fresh → publish → ready.
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]

  # Publisher appeared after the verification boundary
  local calls_content
  calls_content="$(<"$CALLS")"
  [[ "$calls_content" == *">> verification boundary <<"* ]] || false
  # Publisher marker appears after the boundary
  local before_boundary="${calls_content%">> verification boundary <<"*}"
  local after_boundary="${calls_content#*">> verification boundary <<"}"
  [[ "$before_boundary" != *"publisher"* ]] || false
  [[ "$after_boundary" == *"publisher"* ]] || false
  # Readiness appears after publisher
  local after_publisher="${after_boundary#*publisher}"
  [[ "$after_publisher" == *"gh pr ready"* ]] || false
}

@test "publishes argument-less when the remote branch does not exist" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_IDENTITY_REPO=example/repo \
    GH_PR_IDENTITY_HEAD_REF="$branch" GH_PR_IDENTITY_BASE=main \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  [[ "$(<"$CALLS")" == *"publisher "* ]] || false
  [[ "$(<"$CALLS")" != *"publisher --existing-pr"* ]] || false
}

# --- publish-and-ready.sh exact guarded publication tests ---

@test "publishes through the existing PR when exactly one open PR matches the branch and base" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  remote_sha="1111111111111111111111111111111111111111"
  candidates="[{\"number\":7,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo\"},\"headRepositoryOwner\":{\"login\":\"example\"},\"baseRefName\":\"main\"}]"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_LIST_JSON="$candidates" \
    FRESH_REMOTE_HEAD_SHA="$remote_sha" FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  local calls
  calls="$(<"$CALLS")"
  [[ "$calls" == *"publisher --existing-pr 7 --expected-head $remote_sha --head-branch $branch"* ]] || false
  # Readiness happens after the guarded publication.
  [[ "${calls#*publisher --existing-pr}" == *"gh pr ready"* ]] || false
}

@test "stops before publication when the only candidate belongs to a different repository" {
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  candidates="[{\"number\":7,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo-fork\"},\"headRepositoryOwner\":{\"login\":\"forkowner\"},\"baseRefName\":\"main\"}]"
  run env PUBLISH_HELPER="$TMP/publisher" GH_PR_LIST_JSON="$candidates" \
    FRESH_REMOTE_HEAD_SHA="1111111111111111111111111111111111111111" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "stops before publication when no open PR matches the expected base" {
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  candidates="[{\"number\":7,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo\"},\"headRepositoryOwner\":{\"login\":\"example\"},\"baseRefName\":\"release\"}]"
  run env PUBLISH_HELPER="$TMP/publisher" GH_PR_LIST_JSON="$candidates" \
    FRESH_REMOTE_HEAD_SHA="1111111111111111111111111111111111111111" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "stops before publication when multiple open PRs match the branch and base" {
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  candidates="[{\"number\":7,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo\"},\"headRepositoryOwner\":{\"login\":\"example\"},\"baseRefName\":\"main\"},{\"number\":8,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo\"},\"headRepositoryOwner\":{\"login\":\"example\"},\"baseRefName\":\"main\"}]"
  run env PUBLISH_HELPER="$TMP/publisher" GH_PR_LIST_JSON="$candidates" \
    FRESH_REMOTE_HEAD_SHA="1111111111111111111111111111111111111111" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "publication failure in the existing-PR path stops before readiness" {
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  candidates="[{\"number\":7,\"headRefName\":\"$branch\",\"headRepository\":{\"name\":\"repo\"},\"headRepositoryOwner\":{\"login\":\"example\"},\"baseRefName\":\"main\"}]"
  run env PUBLISH_RC=1 PUBLISH_HELPER="$TMP/publisher" GH_PR_LIST_JSON="$candidates" \
    FRESH_REMOTE_HEAD_SHA="1111111111111111111111111111111111111111" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Publication failed; PR readiness was not changed."* ]] || false
  [[ "$(<"$CALLS")" == *"publisher --existing-pr 7"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
}

@test "repository identity lookup failure stops before publication" {
  run env PUBLISH_HELPER="$TMP/publisher" GH_REPO_VIEW_RC=1 \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"git ls-remote"* ]] || false
}

@test "remote-head lookup failure stops before publication" {
  run env PUBLISH_HELPER="$TMP/publisher" FRESH_REMOTE_HEAD_RC=1 \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" == *"git ls-remote"* ]] || false
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr list"* ]] || false
}

@test "candidate PR lookup failure stops before publication" {
  run env PUBLISH_HELPER="$TMP/publisher" GH_PR_LIST_RC=1 \
    FRESH_REMOTE_HEAD_SHA="1111111111111111111111111111111111111111" \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" == *"gh pr list"* ]] || false
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
}

@test "stops before publication when the expected base is not an origin ref" {
  run env PUBLISH_HELPER="$TMP/publisher" FRESHNESS_BASE=main \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" != *"publisher"* ]] || false
  [[ "$output" == *"does not identify an origin/<branch> base"* ]] || false
}

@test "publishes directly without network discovery on main and detached HEAD" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env TEST_BRANCH=main GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_IDENTITY_REPO=example/repo \
    GH_PR_IDENTITY_HEAD_REF=main GH_PR_IDENTITY_BASE=main \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  local calls
  calls="$(<"$CALLS")"
  [[ "$calls" == *"publisher "* ]] || false
  [[ "$calls" != *"publisher --existing-pr"* ]] || false
  [[ "$calls" != *"gh repo view"* ]] || false
  [[ "$calls" != *"git ls-remote"* ]] || false
  [[ "$calls" != *"gh pr list"* ]] || false
}

@test "validates the returned PR identity before marking ready on first publication" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  branch="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_IDENTITY_REPO=example/repo \
    GH_PR_IDENTITY_HEAD_REF="$branch" GH_PR_IDENTITY_BASE=main \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 0 ]
  [ "$output" = 'https://github.com/example/repo/pull/42' ]
  local calls
  calls="$(<"$CALLS")"
  [[ "$calls" == *"publisher"* ]] || false
  [[ "$calls" == *"gh pr view https://github.com/example/repo/pull/42 --json state,url,headRefName,headRepository,headRepositoryOwner,baseRefName"* ]] || false
  # Readiness happens only after the identity validation view.
  [[ "${calls#*headRepositoryOwner,baseRefName}" == *"gh pr ready"* ]] || false
}

@test "stops before readiness when the returned PR identity differs on first publication" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_IDENTITY_REPO=other/repo \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  [[ "$(<"$CALLS")" == *"publisher"* ]] || false
  [[ "$(<"$CALLS")" != *"gh pr ready"* ]] || false
  [[ "$output" == *"PR readiness was not changed"* ]] || false
}

@test "stops before readiness when the returned PR lookup fails on first publication" {
  local_head="$(git -C "$ROOT" rev-parse HEAD)"
  run env GH_PR_VIEW_RC=1 GH_VIEW_SEQUENCE=draft GH_READY_RC=0 PUBLISH_HELPER="$TMP/publisher" \
    GH_HEAD_OID="$local_head" GH_PR_IDENTITY_REPO=example/repo \
    FRESH_RECHECK_IS_ANCESTOR=yes \
    bash "$ROOT/core/agents/skills/finish/scripts/publish-and-ready.sh"
  [ "$status" -eq 1 ]
  local calls
  calls="$(<"$CALLS")"
  [[ "$calls" == *"publisher"* ]] || false
  [[ "$calls" == *"gh pr view"*"state,url,headRefName,headRepository,headRepositoryOwner,baseRefName"* ]] || false
  [[ "$calls" != *"gh pr ready"* ]] || false
}
