#!/usr/bin/env bash
# Fetch and safely extract one exact toolkit release archive.

set -euo pipefail

usage() {
  printf 'Usage: %s TOOLKIT_REMOTE COMMIT MANIFEST_PATH OUTPUT_DIR\n' "$0" >&2
  exit 2
}

exit_with_error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$#" -eq 4 ]] || usage

remote="$1"
commit="$2"
manifest_path="$3"
output_dir="$4"

[[ -n "$remote" ]] || exit_with_error 'toolkit remote must not be empty.'
[[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || exit_with_error 'commit must be exactly 40 hexadecimal characters.'
[[ -f "$manifest_path" ]] || exit_with_error "manifest path is not a file: $manifest_path"
[[ -n "$output_dir" ]] || exit_with_error 'output directory must not be empty.'
[[ "$output_dir" != '.' && "$output_dir" != '/' ]] || \
  exit_with_error 'output directory must be a dedicated directory, not the current or filesystem root.'

command -v curl >/dev/null 2>&1 || exit_with_error 'curl is required.'
command -v tar >/dev/null 2>&1 || exit_with_error 'tar is required.'
if command -v shasum >/dev/null 2>&1; then
  sha_mode='shasum'
elif command -v sha256sum >/dev/null 2>&1; then
  sha_mode='sha256sum'
else
  exit_with_error 'shasum or sha256sum is required.'
fi

remote_path="$remote"
remote_path="${remote_path#https://github.com/}"
remote_path="${remote_path#http://github.com/}"
remote_path="${remote_path%/}"
remote_path="${remote_path%.git}"
[[ "$remote_path" =~ ^[^/]+/[^/]+$ ]] || \
  exit_with_error 'toolkit remote must be a GitHub owner/repository URL.'
repo_name="${remote_path##*/}"

output_parent="${output_dir%/*}"
if [[ "$output_parent" == "$output_dir" ]]; then
  output_parent='.'
elif [[ -z "$output_parent" ]]; then
  output_parent='/'
fi
mkdir -p "$output_parent" || exit_with_error "unable to create output parent: $output_parent"

check_output_directory() {
  if [[ -L "$output_dir" ]]; then
    exit_with_error "output directory must not be a symbolic link: $output_dir"
  fi
  if [[ -e "$output_dir" ]]; then
    [[ -d "$output_dir" ]] || exit_with_error "output path is not a directory: $output_dir"
    local entries=()
    shopt -s nullglob dotglob
    entries=("$output_dir"/*)
    shopt -u nullglob dotglob
    (( ${#entries[@]} == 0 )) || exit_with_error "output directory is nonempty; refusing to overwrite: $output_dir"
  fi
}
check_output_directory

sha256_file() {
  if [[ "$sha_mode" == 'shasum' ]]; then
    shasum -a 256 "$1" | cut -d ' ' -f 1
  else
    sha256sum "$1" | cut -d ' ' -f 1
  fi
}

manifest_hash="$(sha256_file "$manifest_path")" || \
  exit_with_error "unable to hash manifest: $manifest_path"

stage_dir="$(mktemp -d "$output_parent/.fetch-release-assets.XXXXXX")" || \
  exit_with_error "unable to create a temporary extraction directory below: $output_parent"
archive_path="$stage_dir/release.tar.gz"
members_path="$stage_dir/archive-members"
extracted_dir="$stage_dir/extracted"
backup_path=''
cleanup() {
  if [[ -n "$backup_path" && ! -e "$output_dir" ]]; then
    mv "$backup_path" "$output_dir" 2>/dev/null || \
      printf 'ERROR: unable to restore the previous output directory: %s\n' "$output_dir" >&2
  fi
  rm -rf "$stage_dir"
}
trap cleanup EXIT

archive_url="https://github.com/${remote_path}/archive/${commit}.tar.gz"
if ! curl --fail --location --silent --show-error --retry 1 --retry-all-errors \
  "$archive_url" --output "$archive_path"; then
  exit_with_error "unable to fetch release archive at commit $commit from: $remote"
fi

if ! tar -tzf "$archive_path" > "$members_path"; then
  exit_with_error 'downloaded release archive is not a readable tar archive.'
fi

archive_root=''
saw_member=0
while IFS= read -r member || [[ -n "$member" ]]; do
  [[ -n "$member" ]] || exit_with_error 'release archive contains an empty member name.'
  case "$member" in
    /*|..|../*|*/../*|*/..)
      exit_with_error "release archive contains an unsafe member path: $member"
      ;;
  esac

  top_level="${member%%/*}"
  [[ -n "$top_level" && "$top_level" != '.' && "$top_level" != '..' ]] || \
    exit_with_error "release archive contains an invalid root: $member"
  if [[ -z "$archive_root" ]]; then
    archive_root="$top_level"
  elif [[ "$archive_root" != "$top_level" ]]; then
    exit_with_error 'release archive contains more than one root directory.'
  fi
  saw_member=1
done < "$members_path"

[[ "$saw_member" -eq 1 ]] || exit_with_error 'release archive is empty.'
expected_root="${repo_name}-${commit}"
[[ "$archive_root" == "$expected_root" ]] || \
  exit_with_error "release archive root does not match commit $commit: $archive_root"

mkdir -p "$extracted_dir"
if ! tar -xzf "$archive_path" --strip-components=1 -C "$extracted_dir"; then
  exit_with_error 'unable to extract the release archive.'
fi

extracted_manifest="$extracted_dir/manifest.json"
[[ -f "$extracted_manifest" && ! -L "$extracted_manifest" ]] || \
  exit_with_error 'extracted release does not contain a regular manifest.json.'
extracted_hash="$(sha256_file "$extracted_manifest")" || \
  exit_with_error 'unable to hash the extracted manifest.'
[[ "$manifest_hash" == "$extracted_hash" ]] || \
  exit_with_error 'extracted manifest does not match the approved manifest.'

check_output_directory
if [[ -e "$output_dir" ]]; then
  backup_path="$(mktemp -d "$output_parent/.fetch-release-assets-backup.XXXXXX")" || \
    exit_with_error "unable to create an output backup below: $output_parent"
  rmdir "$backup_path" || exit_with_error 'unable to prepare the output backup directory.'
  mv "$output_dir" "$backup_path" || \
    exit_with_error "unable to move the existing output directory aside: $output_dir"
fi
if ! mv "$extracted_dir" "$output_dir"; then
  exit_with_error "unable to install extracted release into: $output_dir"
fi

if [[ -n "$backup_path" ]]; then
  rm -rf "$backup_path" || \
    printf 'WARNING: unable to remove the temporary output backup: %s\n' "$backup_path" >&2
  backup_path=''
fi
printf 'Fetched release archive at commit %s into %s\n' "$commit" "$output_dir"
