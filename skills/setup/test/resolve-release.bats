#!/usr/bin/env bats

load helpers/stubs.sh

setup() {
  stub_setup
  HELPER="$BATS_TEST_DIRNAME/../scripts/resolve-release.sh"
  REMOTE='https://github.com/example/toolkit'
}

teardown() {
  stub_teardown
}

@test "selects the newest stable tag from unsorted refs" {
  stub_git_output $'a111111111111111111111111111111111111111\trefs/tags/v1.2.0\nb222222222222222222222222222222222222222\trefs/tags/v1.10.0\nc333333333333333333333333333333333333333\trefs/tags/v1.9.9'
  output_path="$TEST_ROOT/release.json"

  run bash "$HELPER" "$REMOTE" stable latest "$output_path"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.ref' "$output_path")" = 'v1.10.0' ]
  [ "$(jq -r '.channel' "$output_path")" = 'stable' ]
  [ "$(jq -r '.commit' "$output_path")" = 'b222222222222222222222222222222222222222' ]
  [ "$(wc -l < "$GIT_CALL_LOG")" -eq 1 ]
}

@test "selects an exact semantic-version tag" {
  stub_git_output $'a111111111111111111111111111111111111111\trefs/tags/v1.2.0\nb222222222222222222222222222222222222222\trefs/tags/v1.10.0'
  output_path="$TEST_ROOT/release.json"

  run bash "$HELPER" "$REMOTE" stable v1.2.0 "$output_path"

  [ "$status" -eq 0 ]
  [ "$(jq -c . "$output_path")" = '{"ref":"v1.2.0","channel":"stable","commit":"a111111111111111111111111111111111111111"}' ]
}

@test "resolves preview main to its commit" {
  stub_git_output $'d444444444444444444444444444444444444444\trefs/heads/main\na111111111111111111111111111111111111111\trefs/tags/v1.0.0'
  output_path="$TEST_ROOT/release.json"

  run bash "$HELPER" "$REMOTE" preview main "$output_path"

  [ "$(cat "$GIT_CALL_LOG")" = "ls-remote $REMOTE refs/heads/main" ]
  [[ "$(cat "$GIT_CALL_LOG")" != *'--tags'* ]]
  [ "$status" -eq 0 ]
  [ "$(jq -r '.ref' "$output_path")" = 'main' ]
  [ "$(jq -r '.channel' "$output_path")" = 'preview' ]
  [ "$(jq -r '.commit' "$output_path")" = 'd444444444444444444444444444444444444444' ]
}

@test "rejects an exact semantic-version ref on the preview channel before querying" {
  output_path="$TEST_ROOT/release.json"
  printf 'keep this release\n' > "$output_path"

  run bash "$HELPER" "$REMOTE" preview v1.2.3 "$output_path"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_path")" = 'keep this release' ]
  [ "$(wc -l < "$GIT_CALL_LOG")" -eq 0 ]
}

@test "retries a failed release query once with identical arguments" {
  stub_git_output $'d444444444444444444444444444444444444444\trefs/heads/main'
  stub_git_results '1,0'
  output_path="$TEST_ROOT/retry.json"

  run bash "$HELPER" "$REMOTE" preview main "$output_path"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.commit' "$output_path")" = 'd444444444444444444444444444444444444444' ]
  [ "$(wc -l < "$GIT_CALL_LOG")" -eq 2 ]
  [ "$(sed -n '1p' "$GIT_CALL_LOG")" = "ls-remote $REMOTE refs/heads/main" ]
  [ "$(sed -n '2p' "$GIT_CALL_LOG")" = "ls-remote $REMOTE refs/heads/main" ]
}

@test "stops after two failed release queries and preserves output" {
  stub_git_results '1,1'
  output_path="$TEST_ROOT/failure.json"
  printf 'keep this release\n' > "$output_path"

  run bash "$HELPER" "$REMOTE" preview main "$output_path"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_path")" = 'keep this release' ]
  [ "$(wc -l < "$GIT_CALL_LOG")" -eq 2 ]
}

@test "uses the peeled commit for an annotated tag" {
  stub_git_output $'1111111111111111111111111111111111111111\trefs/tags/v2.0.0\n2222222222222222222222222222222222222222\trefs/tags/v2.0.0^{}'
  output_path="$TEST_ROOT/release.json"

  run bash "$HELPER" "$REMOTE" stable v2.0.0 "$output_path"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.commit' "$output_path")" = '2222222222222222222222222222222222222222' ]
}

@test "rejects an absent tag and preserves an existing output" {
  stub_git_output 'a111111111111111111111111111111111111111\trefs/tags/v1.0.0'
  output_path="$TEST_ROOT/release.json"
  printf 'keep this release\n' > "$output_path"

  run bash "$HELPER" "$REMOTE" stable v9.9.9 "$output_path"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_path")" = 'keep this release' ]
}
