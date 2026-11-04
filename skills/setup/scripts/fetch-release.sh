#!/usr/bin/env bash
# Select, fetch, validate, and export one toolkit release.
# Usage:
#   fetch-release.sh manifest TOOLKIT_REMOTE REQUESTED_REF SCRATCH_DIR
#   fetch-release.sh source SCRATCH_DIR

set -euo pipefail

# Globals set by functions below.
sha_mode=''
fetch_error=''
SELECTED_REF=''
SELECTED_CHANNEL=''
SELECTED_FETCH_REF=''
CHECKED_OUT_COMMIT=''
RELEASE_REF=''
RELEASE_CHANNEL=''
RELEASE_COMMIT=''

# Print the two usage lines to stderr and exit 2.
usage() {
  printf 'Usage: %s manifest TOOLKIT_REMOTE REQUESTED_REF SCRATCH_DIR\n' "$0" >&2
  printf '       %s source SCRATCH_DIR\n' "$0" >&2
  exit 2
}

# Print ERROR: MESSAGE to stderr and exit 1.
exit_with_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup_paths=()
# Remove every path registered in cleanup_paths; runs from the EXIT trap.
cleanup() {
  local path
  (( ${#cleanup_paths[@]} > 0 )) || return 0
  for path in "${cleanup_paths[@]}"; do
    [[ -n "$path" ]] && rm -rf -- "$path"
  done
}

# Register PATH in cleanup_paths so the EXIT trap removes it.
add_cleanup_path() {
  cleanup_paths+=("$1")
}

# print the lowercase SHA-256 of FILE; uses sha_mode from check_prerequisites.
sha256_file() {
  local digest
  if [[ "$sha_mode" == 'shasum' ]]; then
    digest="$(shasum -a 256 "$1" | cut -d ' ' -f 1)"
  else
    digest="$(sha256sum "$1" | cut -d ' ' -f 1)"
  fi
  [[ "$digest" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  printf '%s\n' "$digest" | tr '[:upper:]' '[:lower:]'
}

# SCRATCH_DIR must be a nonempty dedicated existing directory, not a symlink.
validate_scratch_directory() {
  local scratch_dir="$1"

  [[ -n "$scratch_dir" ]] || exit_with_error 'scratch directory must not be empty.'
  [[ "$scratch_dir" != '.' && "$scratch_dir" != '/' ]] || \
    exit_with_error 'scratch directory must be a dedicated directory, not the current or filesystem root.'
  [[ ! -L "$scratch_dir" ]] || \
    exit_with_error "scratch directory must not be a symbolic link: $scratch_dir"
  [[ -d "$scratch_dir" ]] || \
    exit_with_error "scratch path is not an existing directory: $scratch_dir"
}

# an output path must be absent or a regular non-symlink file.
validate_output_file() {
  local path="$1"

  [[ ! -L "$path" ]] || exit_with_error "output file must not be a symbolic link: $path"
  if [[ -e "$path" && ! -f "$path" ]]; then
    exit_with_error "output path is not a regular file: $path"
  fi
}

# LABEL DIRECTORY: directory must be absent or empty.
validate_empty_directory() {
  local label="$1"
  local directory="$2"

  if [[ -L "$directory" ]]; then
    exit_with_error "$label directory must not be a symbolic link: $directory"
  fi
  if [[ -e "$directory" ]]; then
    [[ -d "$directory" ]] || exit_with_error "$label path is not a directory: $directory"
    [[ -z "$(find "$directory" -mindepth 1 -print -quit)" ]] || \
      exit_with_error "$label directory is nonempty; refusing to overwrite: $directory"
  fi
}

# true when vMAJOR.MINOR.PATCH CANDIDATE is greater than CURRENT; kept as plain arithmetic for portability across BSD and GNU sort.
version_is_greater() {
  local candidate="$1"
  local current="$2"
  local candidate_version="${candidate#v}"
  local current_version="${current#v}"
  local candidate_major candidate_minor candidate_patch
  local current_major current_minor current_patch

  IFS='.' read -r candidate_major candidate_minor candidate_patch <<< "$candidate_version"
  IFS='.' read -r current_major current_minor current_patch <<< "$current_version"
  if (( 10#$candidate_major > 10#$current_major )); then
    return 0
  fi
  if (( 10#$candidate_major < 10#$current_major )); then
    return 1
  fi
  if (( 10#$candidate_minor > 10#$current_minor )); then
    return 0
  fi
  if (( 10#$candidate_minor < 10#$current_minor )); then
    return 1
  fi
  (( 10#$candidate_patch > 10#$current_patch ))
}

# Require git, jq, mktemp, tar, and a SHA-256 tool; sets sha_mode.
check_prerequisites() {
  command -v git >/dev/null 2>&1 || exit_with_error 'git is required.'
  command -v jq >/dev/null 2>&1 || exit_with_error 'jq is required.'
  command -v mktemp >/dev/null 2>&1 || exit_with_error 'mktemp is required.'
  command -v tar >/dev/null 2>&1 || exit_with_error 'tar is required.'
  if command -v shasum >/dev/null 2>&1; then
    sha_mode='shasum'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha_mode='sha256sum'
  else
    exit_with_error 'shasum or sha256sum is required.'
  fi
}

# Write REMOTE tags to REFS_FILE, retrying once, or exit with the git error.
query_release_tags() {
  local remote="$1"
  local refs_file="$2"
  local query_error=''

  for _ in 1 2; do
    if query_error="$(GIT_TERMINAL_PROMPT=0 git ls-remote --tags "$remote" 2>&1 > "$refs_file")"; then
      return 0
    fi
  done
  query_error="${query_error//$'\n'/ }"
  exit_with_error "unable to query release tags from $remote${query_error:+; git reported: $query_error}"
}

# Print the highest vMAJOR.MINOR.PATCH tag on REMOTE; registers its temp refs file in cleanup_paths.
latest_stable_tag() {
  local remote="$1"
  local scratch_dir="$2"
  local refs_file
  local object ref tag
  local best_tag=''

  refs_file="$(mktemp "$scratch_dir/.fetch-release-refs.XXXXXX")" || \
    exit_with_error "unable to create a temporary refs file below: $scratch_dir"
  add_cleanup_path "$refs_file"
  query_release_tags "$remote" "$refs_file"

  while IFS=$'\t' read -r object ref; do
    [[ "$object" =~ ^[0-9a-fA-F]{40}$ ]] || continue
    [[ "$ref" =~ ^refs/tags/(v[0-9]+\.[0-9]+\.[0-9]+)$ ]] || continue
    tag="${BASH_REMATCH[1]}"
    if [[ -z "$best_tag" ]] || version_is_greater "$tag" "$best_tag"; then
      best_tag="$tag"
    fi
  done < "$refs_file"

  if [[ -z "$best_tag" ]]; then
    rm -f -- "$refs_file"
    exit_with_error 'no semantic-version release tags were found.'
  fi
  if ! grep -Eq "^[0-9a-fA-F]{40}[[:space:]]refs/tags/${best_tag//./\\.}(\\^\\{\\})?$" "$refs_file"; then
    rm -f -- "$refs_file"
    exit_with_error "selected release tag was not returned by the toolkit remote: $best_tag"
  fi
  rm -f -- "$refs_file"
  printf '%s\n' "$best_tag"
}

# Resolve REQUESTED_REF against REMOTE; sets SELECTED_REF, SELECTED_CHANNEL, SELECTED_FETCH_REF.
select_release_ref() {
  local remote="$1"
  local requested_ref="$2"
  local scratch_dir="$3"

  case "$requested_ref" in
    main)
      SELECTED_REF='main'
      SELECTED_CHANNEL='preview'
      SELECTED_FETCH_REF='refs/heads/main'
      ;;
    latest)
      SELECTED_REF="$(latest_stable_tag "$remote" "$scratch_dir")"
      SELECTED_CHANNEL='stable'
      SELECTED_FETCH_REF="refs/tags/$SELECTED_REF"
      ;;
    v[0-9]*.[0-9]*.[0-9]*)
      [[ "$requested_ref" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
        exit_with_error 'requested ref must be latest, main, or an exact vMAJOR.MINOR.PATCH tag.'
      SELECTED_REF="$requested_ref"
      SELECTED_CHANNEL='stable'
      SELECTED_FETCH_REF="refs/tags/$requested_ref"
      ;;
    *)
      exit_with_error 'requested ref must be latest, main, or an exact vMAJOR.MINOR.PATCH tag.'
      ;;
  esac
}

# Initialize CLONE_DIR with origin at REMOTE; sets fetch_error on failure.
init_release_clone() {
  local clone_dir="$1"
  local remote="$2"

  if ! GIT_TERMINAL_PROMPT=0 git init -q "$clone_dir"; then
    fetch_error='unable to initialize the release clone'
    return 1
  fi
  if GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" remote get-url origin >/dev/null 2>&1; then
    if ! GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" remote set-url origin "$remote"; then
      fetch_error='unable to configure the release clone remote'
      return 1
    fi
  elif ! GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" remote add origin "$remote"; then
    fetch_error='unable to configure the release clone remote'
    return 1
  fi
}

# Check out FETCH_HEAD in CLONE_DIR; sets CHECKED_OUT_COMMIT or fetch_error on failure.
checkout_release_commit() {
  local clone_dir="$1"
  local checkout_error=''

  if ! checkout_error="$(GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" checkout -q --detach FETCH_HEAD 2>&1 > /dev/null)"; then
    fetch_error="$checkout_error"
    return 1
  fi
  CHECKED_OUT_COMMIT="$(git -C "$clone_dir" rev-parse HEAD | tr '[:upper:]' '[:lower:]')"
  if [[ ! "$CHECKED_OUT_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
    fetch_error='checked-out release did not resolve to a lowercase 40-character commit'
    return 1
  fi
}

# Fetch FETCH_REF from REMOTE into CLONE_DIR; sets CHECKED_OUT_COMMIT on success, fetch_error on failure.
fetch_release_ref() {
  local clone_dir="$1"
  local remote="$2"
  local fetch_ref="$3"
  local attempt_error=''
  local result=1

  if init_release_clone "$clone_dir" "$remote"; then
    for _ in 1 2; do
      if ! attempt_error="$(GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" fetch --depth 1 origin "$fetch_ref" 2>&1 > /dev/null)"; then
        fetch_error="$attempt_error"
        continue
      fi
      checkout_release_commit "$clone_dir" && result=0
      break
    done
  fi

  fetch_error="${fetch_error//$'\n'/ }"
  return "$result"
}

# Validate MANIFEST_PATH against EXPECTED_REF/EXPECTED_CHANNEL; skills/setup/references/manifest-schema.md owns the prose schema.
validate_manifest() {
  local manifest_path="$1"
  local expected_ref="$2"
  local expected_channel="$3"

  jq -e --arg expected_ref "$expected_ref" --arg expected_channel "$expected_channel" '
    def nonempty: type == "string" and length > 0;
    def nonempty_strings: type == "array" and all(.[]; nonempty);
    def object_of(f): type == "object" and f;

    (type == "object") and
    (.schemaVersion | if type == "number" then floor == . and . == 1 else false end) and
    (.release | object_of(true)) and
    (.release.ref | nonempty) and
    (.release.channel | nonempty and (. == "stable" or . == "preview")) and
    (.skills | object_of(true)) and
    (.skills.authored |
      type == "array" and
      all(.[];
        object_of((.name | nonempty) and (.path | nonempty))
      )
    ) and
    (.skills.thirdParty |
      type == "array" and
      all(.[];
        object_of((.name | nonempty) and
          (.source | nonempty) and
          (.sourceType | nonempty) and
          (.commit | type == "string" and test("^[0-9a-f]{40}$")) and
          ((has("skillPath") | not) or (.skillPath | type == "string")) and
          ((has("computedHash") | not) or (.computedHash | type == "string")))
      )
    ) and
    (.opencode | object_of((.primary | nonempty_strings) and (.subagents | nonempty_strings))) and
    (.subagents | object_of(
      (.claude | nonempty_strings) and
      (.codex | nonempty_strings) and
      (.opencode | nonempty_strings))) and
    (.templates | object_of(
      (.agentsMd | nonempty) and
      (.roleDocs | nonempty) and
      (.harnessConfig | object_of((.claude | nonempty) and (.codex | nonempty) and (.opencode | nonempty))))) and
    (.release.ref == $expected_ref) and (.release.channel == $expected_channel)
  ' "$manifest_path" >/dev/null
}

# Restore the backed-up manifest and release metadata pair from BACKUP_DIR so a failed install leaves the previous pair untouched.
restore_release_outputs() {
  local manifest_path="$1"
  local release_path="$2"
  local backup_dir="$3"
  local had_manifest="$4"
  local had_release="$5"

  rm -f -- "$manifest_path" "$release_path"
  if [[ "$had_manifest" -eq 1 ]]; then
    mv "$backup_dir/manifest.json" "$manifest_path" || \
      printf 'ERROR: unable to restore the previous manifest: %s\n' "$manifest_path" >&2
  fi
  if [[ "$had_release" -eq 1 ]]; then
    mv "$backup_dir/release.json" "$release_path" || \
      printf 'ERROR: unable to restore the previous release metadata: %s\n' "$release_path" >&2
  fi
}

# Replace manifest.json and release.json in the scratch directory as a pair: back up any existing files, move the new ones in, and on any failure restore the backups so the previous pair is left untouched.
install_release_outputs() {
  local manifest_tmp="$1"
  local release_tmp="$2"
  local manifest_path="$3"
  local release_path="$4"
  local scratch_dir="$5"
  local backup_dir
  local had_manifest=0
  local had_release=0

  validate_output_file "$manifest_path"
  validate_output_file "$release_path"
  backup_dir="$(mktemp -d "$scratch_dir/.fetch-release-backup.XXXXXX")" || return 1
  if [[ -e "$manifest_path" ]]; then
    had_manifest=1
    if ! mv "$manifest_path" "$backup_dir/manifest.json"; then
      rm -rf -- "$backup_dir"
      return 1
    fi
  fi
  if [[ -e "$release_path" ]]; then
    had_release=1
    if ! mv "$release_path" "$backup_dir/release.json"; then
      restore_release_outputs "$manifest_path" "$release_path" "$backup_dir" "$had_manifest" 0
      rm -rf -- "$backup_dir"
      return 1
    fi
  fi

  if ! mv "$manifest_tmp" "$manifest_path"; then
    restore_release_outputs "$manifest_path" "$release_path" "$backup_dir" "$had_manifest" "$had_release"
    rm -rf -- "$backup_dir"
    return 1
  fi
  if ! mv "$release_tmp" "$release_path"; then
    restore_release_outputs "$manifest_path" "$release_path" "$backup_dir" "$had_manifest" "$had_release"
    rm -rf -- "$backup_dir"
    return 1
  fi
  rm -rf -- "$backup_dir" || printf 'WARNING: unable to remove temporary output backup: %s\n' "$backup_dir" >&2
  return 0
}

# Fetch SELECTED_FETCH_REF into CLONE_DIR, read HEAD:manifest.json into MANIFEST_TMP, and validate it against SELECTED_REF and SELECTED_CHANNEL.
fetch_and_validate_manifest() {
  local remote="$1"
  local clone_dir="$2"
  local manifest_tmp="$3"

  if ! fetch_release_ref "$clone_dir" "$remote" "$SELECTED_FETCH_REF"; then
    exit_with_error "unable to fetch release ref $SELECTED_REF from $remote${fetch_error:+; git reported: $fetch_error}"
  fi
  if ! GIT_TERMINAL_PROMPT=0 git -C "$clone_dir" show HEAD:manifest.json > "$manifest_tmp"; then
    exit_with_error "unable to read release manifest at ref $SELECTED_REF from: $remote"
  fi
  if ! validate_manifest "$manifest_tmp" "$SELECTED_REF" "$SELECTED_CHANNEL"; then
    exit_with_error 'fetched release manifest is malformed, unsupported, or does not match the selected ref and channel.'
  fi
}

# Write {ref, channel, commit} from SELECTED_REF, SELECTED_CHANNEL, and CHECKED_OUT_COMMIT to RELEASE_TMP.
write_release_metadata() {
  local release_tmp="$1"

  if ! jq -n \
    --arg ref "$SELECTED_REF" \
    --arg channel "$SELECTED_CHANNEL" \
    --arg commit "$CHECKED_OUT_COMMIT" \
    '{ref: $ref, channel: $channel, commit: $commit}' > "$release_tmp"; then
    exit_with_error 'unable to write release metadata.'
  fi
}

# Manifest mode: validate arguments, select the ref, fetch and validate the manifest, write release metadata, install the output pair, and print the summary.
manifest_mode() {
  local remote="$1"
  local requested_ref="$2"
  local scratch_dir="$3"
  local clone_dir="$scratch_dir/clone"
  local manifest_path="$scratch_dir/manifest.json"
  local release_path="$scratch_dir/release.json"
  local manifest_tmp
  local release_tmp

  [[ -n "$remote" ]] || exit_with_error 'toolkit remote must not be empty.'
  validate_scratch_directory "$scratch_dir"
  validate_output_file "$manifest_path"
  validate_output_file "$release_path"
  validate_empty_directory 'clone' "$clone_dir"
  select_release_ref "$remote" "$requested_ref" "$scratch_dir"

  manifest_tmp="$(mktemp "$scratch_dir/.fetch-release-manifest.XXXXXX")" || \
    exit_with_error "unable to create a temporary manifest below: $scratch_dir"
  add_cleanup_path "$manifest_tmp"
  fetch_and_validate_manifest "$remote" "$clone_dir" "$manifest_tmp"

  release_tmp="$(mktemp "$scratch_dir/.fetch-release-release.XXXXXX")" || \
    exit_with_error "unable to create temporary release metadata below: $scratch_dir"
  add_cleanup_path "$release_tmp"
  write_release_metadata "$release_tmp"

  install_release_outputs "$manifest_tmp" "$release_tmp" "$manifest_path" "$release_path" "$scratch_dir" || \
    exit_with_error 'unable to install release metadata atomically.'
  printf 'Fetched release %s at commit %s into %s\n' "$SELECTED_REF" "$CHECKED_OUT_COMMIT" "$scratch_dir"
}

# Read RELEASE_PATH, validate its shape, and set RELEASE_REF, RELEASE_CHANNEL, RELEASE_COMMIT.
read_release_metadata() {
  local release_path="$1"

  if ! jq -e '
    (type == "object") and
    (.ref | type == "string" and ((. == "main") or test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))) and
    (.channel | type == "string" and ((. == "preview") or (. == "stable"))) and
    (.commit | type == "string" and test("^[0-9a-f]{40}$")) and
    ((.ref == "main" and .channel == "preview") or
      ((.ref | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and .channel == "stable"))
  ' "$release_path" >/dev/null; then
    exit_with_error "release metadata is malformed: $release_path"
  fi
  RELEASE_REF="$(jq -r '.ref' "$release_path")"
  RELEASE_CHANNEL="$(jq -r '.channel' "$release_path")"
  RELEASE_COMMIT="$(jq -r '.commit' "$release_path")"
}

# Verify CLONE_DIR HEAD equals RELEASE_COMMIT, is a work tree, and its committed manifest matches MANIFEST_PATH.
verify_clone_matches_approval() {
  local clone_dir="$1"
  local manifest_path="$2"
  local scratch_dir="$3"
  local head_commit clone_manifest_hash approved_manifest_hash
  local committed_manifest_tmp

  [[ ! -L "$clone_dir" && -d "$clone_dir" ]] || \
    exit_with_error "release clone is not a directory: $clone_dir"
  if ! head_commit="$(git -C "$clone_dir" rev-parse HEAD 2>/dev/null | tr '[:upper:]' '[:lower:]')"; then
    exit_with_error "unable to inspect the fetched release clone: $clone_dir"
  fi
  [[ "$head_commit" == "$RELEASE_COMMIT" ]] || \
    exit_with_error "release clone HEAD does not match pinned commit $RELEASE_COMMIT: $head_commit"
  [[ "$(git -C "$clone_dir" rev-parse --is-inside-work-tree 2>/dev/null)" == 'true' ]] || \
    exit_with_error "release clone is not a work tree: $clone_dir"

  committed_manifest_tmp="$(mktemp "$scratch_dir/.fetch-release-committed-manifest.XXXXXX")" || \
    exit_with_error "unable to create a temporary committed manifest below: $scratch_dir"
  add_cleanup_path "$committed_manifest_tmp"
  if ! git -C "$clone_dir" show "$RELEASE_COMMIT:manifest.json" > "$committed_manifest_tmp"; then
    exit_with_error 'release clone does not contain a committed root manifest.'
  fi
  clone_manifest_hash="$(sha256_file "$committed_manifest_tmp")" || \
    exit_with_error 'unable to hash the committed release manifest.'
  approved_manifest_hash="$(sha256_file "$manifest_path")" || \
    exit_with_error "unable to hash manifest: $manifest_path"
  [[ "$clone_manifest_hash" == "$approved_manifest_hash" ]] || \
    exit_with_error 'committed release manifest does not match the approved manifest.'
}

# Stage RELEASE_COMMIT from CLONE_DIR under SCRATCH_DIR and install it into SOURCE_DIR.
export_release_tree() {
  local clone_dir="$1"
  local scratch_dir="$2"
  local source_dir="$3"
  local stage_dir extracted_dir

  stage_dir="$(mktemp -d "$scratch_dir/.fetch-release-stage.XXXXXX")" || \
    exit_with_error "unable to create a temporary extraction directory below: $scratch_dir"
  add_cleanup_path "$stage_dir"
  extracted_dir="$stage_dir/source"
  mkdir -p "$extracted_dir"
  if ! git -C "$clone_dir" archive "$RELEASE_COMMIT" | tar -x -C "$extracted_dir"; then
    exit_with_error 'unable to extract the fetched release tree.'
  fi

  [[ ! -d "$source_dir" ]] || rmdir "$source_dir" || \
    exit_with_error "unable to prepare the source directory: $source_dir"
  mv "$extracted_dir" "$source_dir" || \
    exit_with_error "unable to install extracted release into: $source_dir"
}

# Source mode: validate arguments, read release metadata, validate the approved manifest, verify the clone matches the approval, prepare the output directory, export the release tree, and print the summary.
source_mode() {
  local scratch_dir="$1"
  local clone_dir="$scratch_dir/clone"
  local manifest_path="$scratch_dir/manifest.json"
  local release_path="$scratch_dir/release.json"
  local source_dir="$scratch_dir/source"

  validate_scratch_directory "$scratch_dir"
  [[ ! -L "$release_path" && -f "$release_path" ]] || \
    exit_with_error "release metadata is not a regular file: $release_path"
  [[ ! -L "$manifest_path" && -f "$manifest_path" ]] || \
    exit_with_error "approved manifest is not a regular file: $manifest_path"
  read_release_metadata "$release_path"
  if ! validate_manifest "$manifest_path" "$RELEASE_REF" "$RELEASE_CHANNEL"; then
    exit_with_error 'approved release manifest is malformed or does not match release metadata.'
  fi
  verify_clone_matches_approval "$clone_dir" "$manifest_path" "$scratch_dir"
  validate_empty_directory 'output' "$source_dir"
  export_release_tree "$clone_dir" "$scratch_dir" "$source_dir"
  printf 'Fetched release at commit %s into %s\n' "$RELEASE_COMMIT" "$source_dir"
}

[[ "$#" -ge 1 ]] || usage
mode="$1"
shift
check_prerequisites
trap cleanup EXIT

case "$mode" in
  manifest)
    [[ "$#" -eq 3 ]] || usage
    manifest_mode "$1" "$2" "$3"
    ;;
  source)
    [[ "$#" -eq 1 ]] || usage
    source_mode "$1"
    ;;
  *)
    usage
    ;;
esac
