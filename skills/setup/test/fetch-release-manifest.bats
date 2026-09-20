#!/usr/bin/env bats

load helpers/stubs.sh

setup() {
  stub_setup
  HELPER="$BATS_TEST_DIRNAME/../scripts/fetch-release-manifest.sh"
  REMOTE='https://github.com/example/toolkit'
  COMMIT='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
  PAYLOAD="$TEST_ROOT/manifest.json"
  write_test_manifest "$PAYLOAD" v1.2.3 stable
  stub_curl_payload "$PAYLOAD"
}

teardown() {
  stub_teardown
}

@test "fetches a manifest at the immutable commit and validates its ref" {
  output_path="$TEST_ROOT/fetched.json"

  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$output_path"

  [ "$status" -eq 0 ]
  cmp -s "$PAYLOAD" "$output_path"
  [ "$(cat "$CURL_URL_LOG")" = "https://raw.githubusercontent.com/example/toolkit/$COMMIT/manifest.json" ]
}

@test "rejects malformed and unsupported manifests" {
  malformed="$TEST_ROOT/malformed.json"
  printf '{"schemaVersion":1\n' > "$malformed"
  stub_curl_payload "$malformed"
  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$TEST_ROOT/malformed-output.json"
  [ "$status" -ne 0 ]

  unsupported="$TEST_ROOT/unsupported.json"
  printf '{"schemaVersion":2}\n' > "$unsupported"
  stub_curl_payload "$unsupported"
  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$TEST_ROOT/unsupported-output.json"
  [ "$status" -ne 0 ]
}

@test "rejects a manifest ref or channel mismatch and preserves output" {
  mismatch="$TEST_ROOT/mismatch.json"
  write_test_manifest "$mismatch" v1.2.4 stable
  stub_curl_payload "$mismatch"
  output_path="$TEST_ROOT/output.json"
  printf 'unchanged\n' > "$output_path"

  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$output_path"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_path")" = 'unchanged' ]
}

@test "retries once and succeeds" {
  output_path="$TEST_ROOT/retry.json"
  stub_curl_payload "$PAYLOAD" '22,0'

  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$output_path"

  [ "$status" -eq 0 ]
  [ "$(grep -c '^22$' "$CURL_CALL_LOG")" -eq 1 ]
  [ "$(grep -c '^0$' "$CURL_CALL_LOG")" -eq 1 ]
}

@test "stops after two failed attempts and preserves output" {
  output_path="$TEST_ROOT/failure.json"
  printf 'keep me\n' > "$output_path"
  stub_curl_payload "$PAYLOAD" '22,22'

  run bash "$HELPER" "$REMOTE" v1.2.3 stable "$COMMIT" "$output_path"

  [ "$status" -ne 0 ]
  [ "$(cat "$output_path")" = 'keep me' ]
  [ "$(grep -c '^22$' "$CURL_CALL_LOG")" -eq 2 ]
}
