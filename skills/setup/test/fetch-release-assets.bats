#!/usr/bin/env bats

load helpers/stubs.sh

setup() {
  stub_setup
  HELPER="$BATS_TEST_DIRNAME/../scripts/fetch-release-assets.sh"
  REMOTE='https://github.com/example/toolkit'
  COMMIT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  MANIFEST_PATH="$TEST_ROOT/manifest.json"
  write_test_manifest "$MANIFEST_PATH" v1.2.3 stable
}

teardown() {
  stub_teardown
}

@test "extracts a matching archive into a caller-provided directory" {
  archive="$TEST_ROOT/release.tar.gz"
  make_release_archive "$archive" "toolkit-$COMMIT" "$MANIFEST_PATH"
  stub_curl_payload "$archive"
  output_dir="$TEST_ROOT/extracted"

  run bash "$HELPER" "$REMOTE" "$COMMIT" "$MANIFEST_PATH" "$output_dir"

  [ "$status" -eq 0 ]
  [ -f "$output_dir/manifest.json" ]
  cmp -s "$MANIFEST_PATH" "$output_dir/manifest.json"
  [[ "$(cat "$TAR_CALL_LOG")" == *'--strip-components=1'* ]]
}

@test "rejects an absolute archive member" {
  archive="$TEST_ROOT/absolute.tar.gz"
  make_archive_with_member "$archive" "toolkit-$COMMIT" '/outside.txt'
  stub_curl_payload "$archive"
  output_dir="$TEST_ROOT/extracted"

  run bash "$HELPER" "$REMOTE" "$COMMIT" "$MANIFEST_PATH" "$output_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$output_dir" ]
}

@test "rejects parent traversal in an archive member" {
  archive="$TEST_ROOT/traversal.tar.gz"
  make_archive_with_member "$archive" "toolkit-$COMMIT" 'toolkit-root/../outside.txt'
  stub_curl_payload "$archive"
  output_dir="$TEST_ROOT/extracted"

  run bash "$HELPER" "$REMOTE" "$COMMIT" "$MANIFEST_PATH" "$output_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$output_dir" ]
}

@test "rejects an archive root that does not contain the resolved commit" {
  archive="$TEST_ROOT/wrong-root.tar.gz"
  make_release_archive "$archive" 'toolkit-wrong-commit' "$MANIFEST_PATH"
  stub_curl_payload "$archive"
  output_dir="$TEST_ROOT/extracted"

  run bash "$HELPER" "$REMOTE" "$COMMIT" "$MANIFEST_PATH" "$output_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$output_dir" ]
}

@test "does not overwrite a nonempty output directory" {
  archive="$TEST_ROOT/release.tar.gz"
  make_release_archive "$archive" "toolkit-$COMMIT" "$MANIFEST_PATH"
  stub_curl_payload "$archive"
  output_dir="$TEST_ROOT/existing"
  mkdir -p "$output_dir"
  printf 'project data\n' > "$output_dir/keep.txt"

  run bash "$HELPER" "$REMOTE" "$COMMIT" "$MANIFEST_PATH" "$output_dir"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_dir/keep.txt")" = 'project data' ]
}
