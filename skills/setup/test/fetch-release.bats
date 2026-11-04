#!/usr/bin/env bats

load helpers/stubs.sh

setup() {
  stub_setup
  HELPER="$BATS_TEST_DIRNAME/../scripts/fetch-release.sh"
  SOURCE_REPO="$TEST_ROOT/source-repo"
  git init -q -b main "$SOURCE_REPO"
  git -C "$SOURCE_REPO" config user.email t@example.com
  git -C "$SOURCE_REPO" config user.name t

  write_test_manifest "$SOURCE_REPO/manifest.json" main preview
  printf 'preview release\n' > "$SOURCE_REPO/README.md"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm 'preview release'
  MAIN_COMMIT="$(git -C "$SOURCE_REPO" rev-parse HEAD)"

  git -C "$SOURCE_REPO" checkout -qb releases
  write_test_manifest "$SOURCE_REPO/manifest.json" v1.2.3 stable
  printf 'stable release 1.2.3\n' > "$SOURCE_REPO/README.md"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm 'release v1.2.3'
  git -C "$SOURCE_REPO" tag v1.2.3
  TAG_1_COMMIT="$(git -C "$SOURCE_REPO" rev-parse HEAD)"

  write_test_manifest "$SOURCE_REPO/manifest.json" v1.10.0 stable
  printf 'stable release 1.10.0\n' > "$SOURCE_REPO/README.md"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm 'release v1.10.0'
  git -C "$SOURCE_REPO" tag v1.10.0

  write_test_manifest "$SOURCE_REPO/manifest.json" v2.0.0 stable
  printf 'stable release 2.0.0\n' > "$SOURCE_REPO/README.md"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm 'release v2.0.0'
  git -C "$SOURCE_REPO" tag -a v2.0.0 -m 'release v2.0.0'
  ANNOTATED_COMMIT="$(git -C "$SOURCE_REPO" rev-parse HEAD)"

  git -C "$SOURCE_REPO" checkout -q main
  REMOTE="$SOURCE_REPO"
  export MAIN_COMMIT TAG_1_COMMIT ANNOTATED_COMMIT REMOTE
}

teardown() { stub_teardown; }

latest_refs() {
  "$REAL_GIT" -C "$SOURCE_REPO" ls-remote --tags "$REMOTE"
}

lowercase() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]'
}

create_tagged_manifest() {
  local tag="$1"
  local release_ref="$2"
  local channel="$3"

  git -C "$SOURCE_REPO" checkout -q releases
  write_test_manifest "$SOURCE_REPO/manifest.json" "$release_ref" "$channel"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm "release $tag"
  git -C "$SOURCE_REPO" tag "$tag"
  git -C "$SOURCE_REPO" checkout -q main
}

create_mutated_tagged_manifest() {
  local tag="$1"
  local release_ref="$2"
  local channel="$3"
  local mutation="$4"
  local manifest_path="$SOURCE_REPO/manifest.json"

  git -C "$SOURCE_REPO" checkout -q releases
  write_test_manifest "$manifest_path" "$release_ref" "$channel"
  jq "$mutation" "$manifest_path" > "$manifest_path.mutated"
  mv "$manifest_path.mutated" "$manifest_path"
  git -C "$SOURCE_REPO" add -A
  git -C "$SOURCE_REPO" commit -qm "release $tag"
  git -C "$SOURCE_REPO" tag "$tag"
  git -C "$SOURCE_REPO" checkout -q main
}

@test "manifest mode owns the scratch layout and records a lowercase exact-tag commit" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"

  [ "$status" -eq 0 ]
  [ -d "$scratch_dir/clone" ]
  [ -f "$scratch_dir/manifest.json" ]
  [ -f "$scratch_dir/release.json" ]
  [ "$(jq -r '.ref' "$scratch_dir/release.json")" = 'v1.2.3' ]
  [ "$(jq -r '.channel' "$scratch_dir/release.json")" = 'stable' ]
  [ "$(jq -r '.commit' "$scratch_dir/release.json")" = "$(lowercase "$TAG_1_COMMIT")" ]
  [ "$(git -C "$scratch_dir/clone" rev-parse HEAD)" = "$(lowercase "$TAG_1_COMMIT")" ]
}

@test "manifest mode fetches main explicitly and derives preview" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" main "$scratch_dir"

  [ "$status" -eq 0 ]
  [[ "$(<"$GIT_CALL_LOG")" == *'fetch --depth 1 origin refs/heads/main'* ]]
  [ "$(jq -c .release "$scratch_dir/manifest.json")" = '{"ref":"main","channel":"preview"}' ]
  [ "$(jq -r '.ref' "$scratch_dir/release.json")" = 'main' ]
  [ "$(jq -r '.channel' "$scratch_dir/release.json")" = 'preview' ]
  [ "$(jq -r '.commit' "$scratch_dir/release.json")" = "$(lowercase "$MAIN_COMMIT")" ]
}

@test "manifest mode selects the highest semantic-version tag for latest" {
  stub_git_output "$(latest_refs)"
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" latest "$scratch_dir"

  [ "$status" -eq 0 ]
  [ "$(jq -r '.ref' "$scratch_dir/release.json")" = 'v2.0.0' ]
  [ "$(jq -r '.commit' "$scratch_dir/release.json")" = "$(lowercase "$ANNOTATED_COMMIT")" ]
}

@test "latest retries its tag query once with identical arguments" {
  stub_git_output "$(latest_refs)"
  stub_git_results '1,0'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" latest "$scratch_dir"

  [ "$status" -eq 0 ]
  [ "$(grep -c '^ls-remote --tags' "$GIT_CALL_LOG")" -eq 2 ]
  [ "$(grep '^ls-remote --tags' "$GIT_CALL_LOG" | sed -n '1p')" = "ls-remote --tags $REMOTE" ]
  [ "$(grep '^ls-remote --tags' "$GIT_CALL_LOG" | sed -n '2p')" = "ls-remote --tags $REMOTE" ]
}

@test "an annotated tag records the peeled commit checked out at HEAD" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v2.0.0 "$scratch_dir"

  [ "$status" -eq 0 ]
  [ "$(git -C "$scratch_dir/clone" rev-parse HEAD)" = "$(lowercase "$ANNOTATED_COMMIT")" ]
  [ "$(jq -r '.commit' "$scratch_dir/release.json")" = "$(lowercase "$ANNOTATED_COMMIT")" ]
}

@test "manifest mode rejects a missing requested ref before installing outputs" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode rejects a malformed requested ref before installing outputs" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" release "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest ref disagreement preserves the existing outputs" {
  create_tagged_manifest v9.9.9 v9.9.8 stable
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  printf 'old manifest\n' > "$scratch_dir/manifest.json"
  printf 'old release\n' > "$scratch_dir/release.json"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ "$(<"$scratch_dir/manifest.json")" = 'old manifest' ]
  [ "$(<"$scratch_dir/release.json")" = 'old release' ]
}

@test "manifest channel disagreement preserves the existing outputs" {
  create_tagged_manifest v9.9.9 v9.9.9 preview
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  printf 'old manifest\n' > "$scratch_dir/manifest.json"
  printf 'old release\n' > "$scratch_dir/release.json"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ "$(<"$scratch_dir/manifest.json")" = 'old manifest' ]
  [ "$(<"$scratch_dir/release.json")" = 'old release' ]
}

@test "manifest mode rejects an unsupported schemaVersion" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable '.schemaVersion = 2'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode rejects a missing templates.agentsMd" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable 'del(.templates.agentsMd)'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode rejects a third-party commit that is not a lowercase 40-hex sha" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable \
    '.skills.thirdParty = [{name:"x",source:"y",sourceType:"github",commit:"not-a-commit"}]'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode rejects an empty subagents.claude entry" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable '.subagents.claude = [""]'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode rejects a non-array opencode.primary" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable '.opencode.primary = "build"'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode accepts optional third-party skillPath and computedHash strings" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable \
    '.skills.thirdParty = [{name:"x",source:"y",sourceType:"github",commit:"0123456789abcdef0123456789abcdef01234567",skillPath:"skills/x",computedHash:"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}]'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -eq 0 ]
  [ -f "$scratch_dir/manifest.json" ]
  [ -f "$scratch_dir/release.json" ]
  [ "$(jq -r '.skills.thirdParty[0].skillPath' "$scratch_dir/manifest.json")" = 'skills/x' ]
}

@test "manifest mode rejects a third-party entry with an empty name" {
  create_mutated_tagged_manifest v9.9.9 v9.9.9 stable \
    '.skills.thirdParty[0] = {name:"",source:"y",sourceType:"github",commit:"0123456789abcdef0123456789abcdef01234567"}'
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v9.9.9 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "manifest mode refuses to reuse a nonempty clone directory" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir/clone"
  printf 'keep\n' > "$scratch_dir/clone/data"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ "$(<"$scratch_dir/clone/data")" = 'keep' ]
  [ ! -e "$scratch_dir/manifest.json" ]
  [ ! -e "$scratch_dir/release.json" ]
}

@test "a failed fetch is retried with the same ref and succeeds" {
  GIT_FETCH_RESULTS='1,0'
  export GIT_FETCH_RESULTS
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"

  [ "$status" -eq 0 ]
  [ "$(grep -c 'fetch --depth 1 origin refs/tags/v1.2.3' "$GIT_CALL_LOG")" -eq 2 ]
  [ "$(jq -r '.ref' "$scratch_dir/release.json")" = 'v1.2.3' ]
}

@test "two failed fetches preserve the existing outputs" {
  GIT_FETCH_RESULTS='1,1'
  export GIT_FETCH_RESULTS
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  printf 'old manifest\n' > "$scratch_dir/manifest.json"
  printf 'old release\n' > "$scratch_dir/release.json"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"

  [ "$status" -ne 0 ]
  [ "$(grep -c 'fetch --depth 1 origin refs/tags/v1.2.3' "$GIT_CALL_LOG")" -eq 2 ]
  [ "$(<"$scratch_dir/manifest.json")" = 'old manifest' ]
  [ "$(<"$scratch_dir/release.json")" = 'old release' ]
}

@test "both modes reject a current-directory or root scratch path" {
  for scratch_dir in . /; do
    run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"
    [ "$status" -ne 0 ]
    run bash "$HELPER" source "$scratch_dir"
    [ "$status" -ne 0 ]
  done
}

@test "both modes reject a symlinked scratch directory" {
  real_scratch="$TEST_ROOT/real-scratch"
  symlink_scratch="$TEST_ROOT/symlink-scratch"
  mkdir -p "$real_scratch"
  ln -s "$real_scratch" "$symlink_scratch"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$symlink_scratch"
  [ "$status" -ne 0 ]
  run bash "$HELPER" source "$symlink_scratch"
  [ "$status" -ne 0 ]
}

@test "both modes reject a scratch path that is not a directory" {
  scratch_path="$TEST_ROOT/not-a-directory"
  printf 'not a directory\n' > "$scratch_path"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_path"
  [ "$status" -ne 0 ]
  run bash "$HELPER" source "$scratch_path"
  [ "$status" -ne 0 ]
}

@test "source mode verifies the retained artifacts and exports without git metadata" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"

  run bash "$HELPER" source "$scratch_dir"

  [ "$status" -eq 0 ]
  cmp -s "$scratch_dir/clone/manifest.json" "$scratch_dir/source/manifest.json"
  [ -f "$scratch_dir/source/manifest.json" ]
  [ -f "$scratch_dir/source/README.md" ]
  [ ! -e "$scratch_dir/source/.git" ]
}

@test "source mode rejects a changed clone HEAD" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"
  printf 'tampered\n' > "$scratch_dir/clone/tamper.txt"
  git -C "$scratch_dir/clone" add -A
  git -C "$scratch_dir/clone" -c user.email=t@example.com -c user.name=t commit -qm tamper

  run bash "$HELPER" source "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/source" ]
}

@test "source mode rejects an approved manifest hash mismatch" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"
  printf '\n' >> "$scratch_dir/manifest.json"

  run bash "$HELPER" source "$scratch_dir"

  [ "$status" -ne 0 ]
  [ ! -e "$scratch_dir/source" ]
}

@test "source mode does not overwrite a nonempty source directory" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"
  bash "$HELPER" manifest "$REMOTE" v1.2.3 "$scratch_dir"
  mkdir -p "$scratch_dir/source"
  printf 'project data\n' > "$scratch_dir/source/keep.txt"

  run bash "$HELPER" source "$scratch_dir"

  [ "$status" -ne 0 ]
  [ "$(<"$scratch_dir/source/keep.txt")" = 'project data' ]
}

@test "legacy argument-heavy command shapes return usage status" {
  scratch_dir="$TEST_ROOT/scratch"
  mkdir -p "$scratch_dir"

  run bash "$HELPER" manifest "$REMOTE" v1.2.3 stable "$TAG_1_COMMIT" \
    "$scratch_dir/manifest.json" "$scratch_dir/clone"
  [ "$status" -eq 2 ]

  run bash "$HELPER" source "$REMOTE" "$TAG_1_COMMIT" "$scratch_dir/manifest.json" \
    "$scratch_dir/clone" "$scratch_dir/source"
  [ "$status" -eq 2 ]
}
