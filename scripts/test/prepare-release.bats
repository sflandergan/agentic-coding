#!/usr/bin/env bats
#
# Focused tests for scripts/prepare-release.sh.
#
# Each test runs the script against a throwaway git fixture repo. The release
# validator is stubbed at the path the script invokes; bats is stubbed on PATH.

setup() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/prepare-release.XXXXXX")"
  FIXTURE="$TEST_ROOT/repo"
  SCRIPT="$BATS_TEST_DIRNAME/../prepare-release.sh"
  mkdir -p "$FIXTURE/scripts" "$FIXTURE/skills/setup/test"

  git -C "$FIXTURE" init --quiet
  git -C "$FIXTURE" config user.email test@example.com
  git -C "$FIXTURE" config user.name test
  printf 'placeholder so the bats glob matches\n' > "$FIXTURE/skills/setup/test/dummy.bats"

  # Stub release validator: logs invocations, exits $VALIDATOR_EXIT.
  printf '#!/usr/bin/env bash\necho "validator $*" >> "$VALIDATOR_LOG"\nexit "${VALIDATOR_EXIT:-0}"\n' \
    > "$FIXTURE/scripts/validate-release.sh"
  chmod +x "$FIXTURE/scripts/validate-release.sh"

  # Stub bats on PATH: logs invocations, exits $BATS_EXIT.
  mkdir -p "$TEST_ROOT/bin"
  printf '#!/usr/bin/env bash\necho "bats $*" >> "$BATS_LOG"\nexit "${BATS_EXIT:-0}"\n' \
    > "$TEST_ROOT/bin/bats"
  chmod +x "$TEST_ROOT/bin/bats"

  VALIDATOR_LOG="$TEST_ROOT/validator.log"
  BATS_LOG="$TEST_ROOT/bats.log"
  : > "$VALIDATOR_LOG"
  : > "$BATS_LOG"

  write_manifest "$FIXTURE/manifest.json" main preview
  cp "$FIXTURE/manifest.json" "$TEST_ROOT/before.json"
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit --quiet -m init
  HEAD_BEFORE="$(git -C "$FIXTURE" rev-parse HEAD)"

  export RELEASE_REPO_ROOT="$FIXTURE"
  export SCRATCH="$TEST_ROOT/scratch"
  export PATH="$TEST_ROOT/bin:$PATH"
  export VALIDATOR_LOG BATS_LOG
}

teardown() {
  rm -rf "$TEST_ROOT"
}

write_manifest() {
  local output_path="$1"
  local release_ref="$2"
  local channel="$3"

  jq -n --arg release_ref "$release_ref" --arg channel "$channel" '
    {
      schemaVersion: 1,
      release: {ref: $release_ref, channel: $channel},
      skills: {
        authored: [{name: "setup", path: "skills/setup"}],
        thirdParty: []
      },
      opencode: {primary: ["planner"], subagents: ["implement-task"]},
      subagents: {
        claude: ["implement-task"],
        codex: ["implement-task"],
        opencode: ["implement-task"]
      },
      templates: {
        agentsMd: "templates/AGENTS.md",
        roleDocs: "templates/docs/agents",
        harnessConfig: {
          opencode: "templates/opencode"
        }
      }
    }
  ' > "$output_path"
}

assert_manifest_unchanged() {
  local fixture_manifest="$1"
  local before="$2"
  [[ "$(jq -S 'del(.release)' "$before")" == "$(jq -S 'del(.release)' "$fixture_manifest")" ]]
}

@test "accepts a valid unused version from a preview manifest" {
  run bash "$SCRIPT" v2.1.1

  [ "$status" -eq 0 ]
  [ "$(jq -r '.release.ref' "$FIXTURE/manifest.json")" = 'v2.1.1' ]
  [ "$(jq -r '.release.channel' "$FIXTURE/manifest.json")" = 'stable' ]
  assert_manifest_unchanged "$FIXTURE/manifest.json" "$TEST_ROOT/before.json"
  [ "$(grep -c validator "$VALIDATOR_LOG")" -eq 1 ]
  [ "$(grep -c bats "$BATS_LOG")" -eq 1 ]
}

@test "changes no manifest fields except release metadata" {
  run bash "$SCRIPT" v2.1.1

  [ "$status" -eq 0 ]
  assert_manifest_unchanged "$FIXTURE/manifest.json" "$TEST_ROOT/before.json"
}

@test "never commits or tags" {
  run bash "$SCRIPT" v2.1.1

  [ "$status" -eq 0 ]
  [ "$(git -C "$FIXTURE" rev-parse HEAD)" = "$HEAD_BEFORE" ]
  [ -z "$(git -C "$FIXTURE" tag -l v2.1.1)" ]
  [ -z "$(git -C "$FIXTURE" status --porcelain -- ':!manifest.json')" ]
}

@test "rejects malformed versions" {
  for bad in v2.1 2.1.1 v2.1.1.1 vlatest; do
    run bash "$SCRIPT" "$bad"
    [ "$status" -ne 0 ]
  done
  assert_manifest_unchanged "$FIXTURE/manifest.json" "$TEST_ROOT/before.json"
}

@test "computes a patch bump from the highest existing tag" {
  git -C "$FIXTURE" tag v2.1.0
  git -C "$FIXTURE" tag v1.9.9

  run bash "$SCRIPT" --compute-version patch

  [ "$status" -eq 0 ]
  [ "$output" = $'v2.1.0\nv2.1.1' ]
}

@test "computes minor and major bumps from the highest existing tag" {
  git -C "$FIXTURE" tag v2.1.0

  run bash "$SCRIPT" --compute-version minor
  [ "$status" -eq 0 ]
  [ "$output" = $'v2.1.0\nv2.2.0' ]

  run bash "$SCRIPT" --compute-version major
  [ "$status" -eq 0 ]
  [ "$output" = $'v2.1.0\nv3.0.0' ]
}

@test "version computation ignores non-semantic tags" {
  git -C "$FIXTURE" tag v2.1.0
  git -C "$FIXTURE" tag v2.1.0-rc1
  git -C "$FIXTURE" tag release-2

  run bash "$SCRIPT" --compute-version patch

  [ "$status" -eq 0 ]
  [ "$output" = $'v2.1.0\nv2.1.1' ]
}

@test "version computation starts from v0.1.0 when no tags exist" {
  run bash "$SCRIPT" --compute-version patch

  [ "$status" -eq 0 ]
  [ "$output" = $'v0.1.0\nv0.1.1' ]
}

@test "rejects an invalid bump component" {
  for bad in patchx MAJOR "" v2.1.1; do
    run bash "$SCRIPT" --compute-version "$bad"
    [ "$status" -ne 0 ]
  done
}

@test "rejects an existing tag" {
  git -C "$FIXTURE" tag v2.1.1

  run bash "$SCRIPT" v2.1.1

  [ "$status" -ne 0 ]
  assert_manifest_unchanged "$FIXTURE/manifest.json" "$TEST_ROOT/before.json"
}

@test "rejects a source manifest that is not main/preview" {
  write_manifest "$FIXTURE/manifest.json" v2.0.0 stable

  run bash "$SCRIPT" v2.1.1

  [ "$status" -ne 0 ]
  [ "$(jq -r '.release.ref' "$FIXTURE/manifest.json")" = 'v2.0.0' ]
}

@test "propagates release-validator failure" {
  export VALIDATOR_EXIT=1

  run bash "$SCRIPT" v2.1.1

  [ "$status" -ne 0 ]
  [ "$(grep -c validator "$VALIDATOR_LOG")" -eq 1 ]
}

@test "propagates setup-test failure" {
  export BATS_EXIT=1

  run bash "$SCRIPT" v2.1.1

  [ "$status" -ne 0 ]
  [ "$(grep -c bats "$BATS_LOG")" -eq 1 ]
}

@test "fails when bats is unavailable" {
  mkdir -p "$TEST_ROOT/minimal-bin"
  ln -sf "$(command -v bash)" "$TEST_ROOT/minimal-bin/bash"
  ln -sf "$(command -v git)" "$TEST_ROOT/minimal-bin/git"
  ln -sf "$(command -v jq)" "$TEST_ROOT/minimal-bin/jq"

  run env -i HOME="$HOME" PATH="$TEST_ROOT/minimal-bin" \
    RELEASE_REPO_ROOT="$FIXTURE" bash "$SCRIPT" v2.1.1

  [ "$status" -ne 0 ]
  [[ "$output" == *"bats is required"* ]]
}
