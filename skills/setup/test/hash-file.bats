#!/usr/bin/env bats

setup() {
  HELPER="$BATS_TEST_DIRNAME/../scripts/hash-file.sh"
  BASH_BIN="$(command -v bash)"
  CHMOD_BIN="$(command -v chmod)"
  LN_BIN="$(command -v ln)"
  MKDIR_BIN="$(command -v mkdir)"
  RM_BIN="$(command -v rm)"
  RMDIR_BIN="$(command -v rmdir)"
  TR_BIN="$(command -v tr)"
  ORIGINAL_PATH="$PATH"

  scratch_root="${SCRATCH:-$PWD/.temp/setup-final-review-tests}"
  TEST_ROOT="$scratch_root/hash-file-${BATS_TEST_NUMBER:-0}-${RANDOM}"
  STUB_BIN="$TEST_ROOT/bin"
  SYSTEM_BIN="$TEST_ROOT/system-bin"
  "$MKDIR_BIN" -p "$STUB_BIN" "$SYSTEM_BIN"
  "$LN_BIN" -s "$TR_BIN" "$SYSTEM_BIN/tr"

  FIXTURE="$TEST_ROOT/native-asset"
  printf 'native asset\n' > "$FIXTURE"
  export TEST_ROOT STUB_BIN SYSTEM_BIN FIXTURE HASH_OUTPUT
  PATH="$STUB_BIN:$SYSTEM_BIN"
  export PATH
}

teardown() {
  PATH="$ORIGINAL_PATH"
  export PATH
  "$RM_BIN" -rf "$TEST_ROOT"
  if [[ -n "${SCRATCH:-}" ]]; then
    "$RMDIR_BIN" "$SCRATCH" 2>/dev/null || true
  fi
}

write_shasum_stub() {
  # The variables in this format string are expanded by the generated stub.
  # shellcheck disable=SC2016
  printf '#!%s\nset -u\nif [[ "${1:-}" != "-a" || "${2:-}" != "256" || "$#" -ne 3 ]]; then exit 2; fi\nprintf "%%s  %%s\\n" "$HASH_OUTPUT" "$3"\n' \
    "$BASH_BIN" > "$STUB_BIN/shasum"
  "$CHMOD_BIN" +x "$STUB_BIN/shasum"
}

write_sha256sum_stub() {
  # The variables in this format string are expanded by the generated stub.
  # shellcheck disable=SC2016
  printf '#!%s\nset -u\nif [[ "$#" -ne 1 ]]; then exit 2; fi\nprintf "%%s  %%s\\n" "$HASH_OUTPUT" "$1"\n' \
    "$BASH_BIN" > "$STUB_BIN/sha256sum"
  "$CHMOD_BIN" +x "$STUB_BIN/sha256sum"
}

@test "hashes through shasum and normalizes the digest" {
  HASH_OUTPUT='ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789'
  export HASH_OUTPUT
  write_shasum_stub
  expected="$(printf '%s' "$HASH_OUTPUT" | "$TR_BIN" '[:upper:]' '[:lower:]')"

  run "$BASH_BIN" "$HELPER" "$FIXTURE"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "falls back to sha256sum when shasum is unavailable" {
  HASH_OUTPUT='0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'
  export HASH_OUTPUT
  write_sha256sum_stub
  expected="$(printf '%s' "$HASH_OUTPUT" | "$TR_BIN" '[:upper:]' '[:lower:]')"

  run "$BASH_BIN" "$HELPER" "$FIXTURE"

  [ "$status" -eq 0 ]
  [ "$output" = "$expected" ]
}

@test "rejects a missing or non-file input" {
  run "$BASH_BIN" "$HELPER" "$TEST_ROOT/missing"
  [ "$status" -ne 0 ]

  "$MKDIR_BIN" "$TEST_ROOT/directory"
  run "$BASH_BIN" "$HELPER" "$TEST_ROOT/directory"
  [ "$status" -ne 0 ]
}

@test "fails when neither supported hash command exists" {
  run "$BASH_BIN" "$HELPER" "$FIXTURE"

  [ "$status" -ne 0 ]
}

@test "rejects malformed hash command output" {
  HASH_OUTPUT='not-a-digest'
  export HASH_OUTPUT
  write_shasum_stub

  run "$BASH_BIN" "$HELPER" "$FIXTURE"

  [ "$status" -ne 0 ]
}
