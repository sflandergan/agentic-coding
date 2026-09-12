#!/usr/bin/env bats
# publish-branch.sh test suite.
#
# Run with a scratch root below .temp/:
#   SCRATCH="$PWD/.temp/bats" bats core/agents/skills/git-publish/test/publish-branch.bats

TEST_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HELPER="$REPO_ROOT/core/agents/skills/git-publish/scripts/publish-branch.sh"
# Capture the real git binary before any test stub directory is prepended to PATH.
REAL_GIT="$(command -v git)"
REMOTE_HEAD='renovate/entry'

setup() {
  FIXTURE_DIR=""
  # shellcheck source=helpers/stubs.sh
  source "$TEST_DIR/helpers/stubs.sh"
  new_fixture "t$BATS_TEST_NUMBER"
  STUB_BIN="$FIXTURE_DIR/bin"
  STUB_DIR="$FIXTURE_DIR/stubs"
  WORKTREE="$FIXTURE_DIR/worktree"
  REMOTE="$FIXTURE_DIR/origin.git"

  export STUB_BIN STUB_DIR WORKTREE REMOTE REAL_GIT
  export GIT_STUB_DIR="$STUB_DIR" GH_STUB_DIR="$STUB_DIR"
  mkdir -p "$STUB_BIN" "$STUB_DIR"
  install_stubs
  export PATH="$STUB_BIN:$PATH"

  setup_repo
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

setup_repo() {
  rm -rf "$WORKTREE" "$REMOTE"
  # Silence both stdout and stderr on fixture git calls; bats merges setup
  # output into $output, so any chatter here breaks exact-equality assertions.
  "$REAL_GIT" init --bare "$REMOTE" >/dev/null 2>&1
  "$REAL_GIT" init "$WORKTREE" >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" checkout -b main >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" config user.email 'shell-test@example.invalid' >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" config user.name 'Shell Test' >/dev/null 2>&1
  printf 'base\n' > "$WORKTREE/base.txt"
  "$REAL_GIT" -C "$WORKTREE" add base.txt >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" commit -m 'create test base' >/dev/null 2>&1
  ENTRY_HEAD="$("$REAL_GIT" -C "$WORKTREE" rev-parse HEAD 2>/dev/null)"
  "$REAL_GIT" -C "$WORKTREE" remote add origin "$REMOTE" >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" push origin "HEAD:refs/heads/$REMOTE_HEAD" >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" checkout -b workspace-copy >/dev/null 2>&1

  export GH_PR_STATE='OPEN'
  export GH_PR_HEAD="$REMOTE_HEAD"
  export GH_PR_URL='https://github.com/example/repo/pull/42'
  export GH_PR_LIST_URL='https://github.com/example/repo/pull/77'
  reset_logs
}

new_tested_commit() {
  printf 'tested-%s\n' "${1:-change}" > "$WORKTREE/tested.txt"
  "$REAL_GIT" -C "$WORKTREE" add tested.txt >/dev/null 2>&1
  "$REAL_GIT" -C "$WORKTREE" commit -m "add tested ${1:-change}" >/dev/null 2>&1
  LOCAL_HEAD="$("$REAL_GIT" -C "$WORKTREE" rev-parse HEAD 2>/dev/null)"
}

run_helper_command() {
  (
    cd "$WORKTREE"
    "$HELPER" "$@"
  )
}

@test "default mode pushes before PR lookup and prints the existing PR URL" {
  new_tested_commit default-existing
  run run_helper_command
  [ "$status" -eq 0 ]
  [ "$(remote_sha workspace-copy)" = "$LOCAL_HEAD" ]
  [ "$output" = "$GH_PR_LIST_URL" ]
  [[ "$(git_push_args)" == *"origin workspace-copy"* ]]
  # The push happens before the PR lookup.
  [[ "$(<"$STUB_DIR/gh.calls")" == *"pr list"* ]]
}

@test "default mode creates a draft PR when none exists" {
  new_tested_commit default-draft
  export GH_PR_LIST_URL=''
  export GH_PR_CREATE_OUTPUT='https://github.com/example/repo/pull/99'

  run run_helper_command

  [ "$status" -eq 0 ]
  [ "$output" = "$GH_PR_CREATE_OUTPUT" ]
  [[ "$(<"$STUB_DIR/gh.calls")" == *"pr create --fill --draft"* ]]
  [[ "$(<"$STUB_DIR/gh.calls")" != *"pr ready"* ]]
}

@test "default mode rejects local main" {
  "$REAL_GIT" -C "$WORKTREE" checkout main >/dev/null
  new_tested_commit default-main
  run run_helper_command
  [ "$status" -eq 1 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"protected branch: main"* ]]
}

@test "default mode rejects local master" {
  "$REAL_GIT" -C "$WORKTREE" checkout -b master >/dev/null
  new_tested_commit default-master
  run run_helper_command
  [ "$status" -eq 1 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"protected branch: master"* ]]
}

@test "default mode rejects the resolved origin default branch" {
  # origin/HEAD resolves to main in this fixture; a branch named like the
  # resolved default is protected even when it is not main or master.
  "$REAL_GIT" -C "$WORKTREE" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/workspace-copy >/dev/null
  new_tested_commit default-resolved
  run run_helper_command
  [ "$status" -eq 1 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"protected branch: workspace-copy"* ]]
}

@test "default mode rejects a detached HEAD" {
  new_tested_commit default-detached
  "$REAL_GIT" -C "$WORKTREE" checkout --detach >/dev/null
  run run_helper_command
  [ "$status" -eq 1 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"Detached HEAD"* ]]
}

@test "existing PR publishes a differently named local branch" {
  new_tested_commit differently-named
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 0 ]
  [ "$output" = "$GH_PR_URL" ]
  [ "$(remote_sha "$REMOTE_HEAD")" = "$LOCAL_HEAD" ]
  [ "$(git_push_count)" -eq 1 ]
  [[ "$(git_push_args)" == *"--force-with-lease=refs/heads/$REMOTE_HEAD:$ENTRY_HEAD"* ]]
  [[ "$(git_push_args)" == *"HEAD:refs/heads/$REMOTE_HEAD"* ]]
}

@test "existing PR publication accepts a detached HEAD" {
  new_tested_commit detached
  "$REAL_GIT" -C "$WORKTREE" checkout --detach "$LOCAL_HEAD" >/dev/null
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 0 ]
  [ "$(remote_sha "$REMOTE_HEAD")" = "$LOCAL_HEAD" ]
}

@test "existing PR publication accepts local main" {
  "$REAL_GIT" -C "$WORKTREE" checkout main >/dev/null
  new_tested_commit local-main
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 0 ]
  [ "$(remote_sha "$REMOTE_HEAD")" = "$LOCAL_HEAD" ]
}

@test "existing PR publication rejects a changed PR head before pushing" {
  new_tested_commit renamed-pr
  export GH_PR_HEAD='renovate/renamed'
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 1 ]
  [ "$(remote_sha "$REMOTE_HEAD")" = "$ENTRY_HEAD" ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"head branch renovate/renamed does not match requested head branch renovate/entry"* ]]
}

@test "existing PR publication rejects a closed PR before pushing" {
  new_tested_commit closed-pr
  export GH_PR_STATE='CLOSED'
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 1 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"state is CLOSED"* ]]
}

@test "existing PR publication rejects an invalid destination" {
  new_tested_commit invalid-destination
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch 'invalid branch'
  [ "$status" -eq 2 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"valid branch ref"* ]]
}

@test "existing PR publication rejects main as the destination" {
  new_tested_commit main-destination
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch main
  [ "$status" -eq 2 ]
  [ "$(git_push_count)" -eq 0 ]
  [[ "$output" == *"protected head branch: main"* ]]
}

@test "existing PR publication rejects incomplete arguments" {
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--existing-pr, --expected-head, and --head-branch are required together"* ]]

  run run_helper_command --existing-pr 42 --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 2 ]

  run run_helper_command --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 2 ]

  run run_helper_command --head-branch "$REMOTE_HEAD"
  [ "$status" -eq 2 ]

  run run_helper_command --existing-pr
  [ "$status" -eq 2 ]

  run run_helper_command --expected-head
  [ "$status" -eq 2 ]

  run run_helper_command --head-branch
  [ "$status" -eq 2 ]

  [ "$(git_push_count)" -eq 0 ]
}

@test "existing PR publication rejects unknown and mixed flags" {
  run run_helper_command --unknown-flag
  [ "$status" -eq 2 ]
  [[ "$output" == *"Unknown option"* ]]

  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD" --unknown-flag
  [ "$status" -eq 2 ]
  [ "$(git_push_count)" -eq 0 ]
}

@test "existing PR publication rejects a stale expected-head lease without retry" {
  new_tested_commit lease-tested
  TESTED_HEAD="$LOCAL_HEAD"
  printf 'remote-move\n' > "$WORKTREE/remote-move.txt"
  "$REAL_GIT" -C "$WORKTREE" add remote-move.txt
  "$REAL_GIT" -C "$WORKTREE" commit -m 'move remote head' >/dev/null
  REMOTE_MOVED_HEAD="$("$REAL_GIT" -C "$WORKTREE" rev-parse HEAD)"
  "$REAL_GIT" -C "$WORKTREE" push origin "HEAD:refs/heads/$REMOTE_HEAD" >/dev/null
  "$REAL_GIT" -C "$WORKTREE" reset --hard "$TESTED_HEAD" >/dev/null
  reset_logs

  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"
  [ "$status" -ne 0 ]
  [ "$(git_push_count)" -eq 1 ]
  [ "$(remote_sha "$REMOTE_HEAD")" = "$REMOTE_MOVED_HEAD" ]
  [[ "$(git_push_args)" == *"--force-with-lease=refs/heads/$REMOTE_HEAD:$ENTRY_HEAD"* ]]
  [[ "$(git_push_args)" == *"HEAD:refs/heads/$REMOTE_HEAD"* ]]
  [[ "$(git_push_args)" != *"origin $REMOTE_HEAD"* ]]
}

@test "existing PR publication does not change readiness" {
  new_tested_commit existing-ready-state
  run run_helper_command --existing-pr 42 --expected-head "$ENTRY_HEAD" --head-branch "$REMOTE_HEAD"

  [ "$status" -eq 0 ]
  [[ "$(<"$STUB_DIR/gh.calls")" != *"pr create"* ]]
  [[ "$(<"$STUB_DIR/gh.calls")" != *"pr ready"* ]]
}
