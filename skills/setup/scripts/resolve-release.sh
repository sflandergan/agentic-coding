#!/usr/bin/env bash
# Resolve a user-facing toolkit release ref to one immutable commit.

set -euo pipefail

usage() {
  printf 'Usage: %s TOOLKIT_REMOTE CHANNEL REQUESTED_REF OUTPUT_PATH\n' "$0" >&2
  exit 2
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$#" -eq 4 ]] || usage

remote="$1"
channel="$2"
requested_ref="$3"
output_path="$4"

[[ -n "$remote" ]] || error 'toolkit remote must not be empty.'
case "$channel" in
  stable|preview) ;;
  *) error "channel must be stable or preview: $channel" ;;
esac
[[ -n "$output_path" ]] || error 'output path must not be empty.'

case "$requested_ref" in
  latest)
    [[ "$channel" == 'stable' ]] || error 'latest releases must use the stable channel.'
    ;;
  main)
    [[ "$channel" == 'preview' ]] || error 'main releases must use the preview channel.'
    ;;
  *)
    [[ "$requested_ref" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] || \
      error 'requested ref must be latest, main, or an exact semantic-version tag.'
    [[ "$channel" == 'stable' ]] || \
      error 'exact semantic-version releases must use the stable channel.'
    ;;
esac

if [[ "$channel" == 'preview' && "$requested_ref" == 'main' ]]; then
  query_args=(ls-remote "$remote" refs/heads/main)
else
  query_args=(ls-remote --tags "$remote")
fi

command -v git >/dev/null 2>&1 || error 'git is required.'
command -v jq >/dev/null 2>&1 || error 'jq is required.'

output_dir="${output_path%/*}"
if [[ "$output_dir" == "$output_path" ]]; then
  output_dir='.'
elif [[ -z "$output_dir" ]]; then
  output_dir='/'
fi
mkdir -p "$output_dir" || error "unable to create output directory: $output_dir"

refs_path="$(mktemp "$output_dir/.resolve-release-refs.XXXXXX")" || \
  error "unable to create a temporary refs file below: $output_dir"
temporary_output=''
cleanup() {
  rm -f "$refs_path"
  if [[ -n "$temporary_output" ]]; then
    rm -f "$temporary_output"
  fi
}
trap cleanup EXIT

if ! git "${query_args[@]}" > "$refs_path"; then
  if ! git "${query_args[@]}" > "$refs_path"; then
    error "unable to query release refs from the toolkit remote: $remote"
  fi
fi

version_is_greater() {
  local candidate="$1"
  local current="$2"
  local candidate_version="${candidate#v}"
  local current_version="${current#v}"
  local candidate_major candidate_minor candidate_patch
  local current_major current_minor current_patch

  IFS='.' read -r candidate_major candidate_minor candidate_patch <<< "$candidate_version"
  IFS='.' read -r current_major current_minor current_patch <<< "$current_version"
  candidate_major=$((10#$candidate_major))
  candidate_minor=$((10#$candidate_minor))
  candidate_patch=$((10#$candidate_patch))
  current_major=$((10#$current_major))
  current_minor=$((10#$current_minor))
  current_patch=$((10#$current_patch))

  (( candidate_major > current_major )) || {
    (( candidate_major == current_major && candidate_minor > current_minor )) || {
      (( candidate_major == current_major && candidate_minor == current_minor && candidate_patch > current_patch ))
    }
  }
}

selected_ref=''
selected_commit=''
best_tag=''
best_commit=''

while IFS=$'\t' read -r object ref; do
  [[ "$object" =~ ^[0-9a-fA-F]{40}$ ]] || continue

  if [[ "$requested_ref" == 'main' ]]; then
    if [[ "$ref" == 'refs/heads/main' ]]; then
      selected_ref='main'
      selected_commit="$object"
    fi
    continue
  fi

  if [[ "$ref" == "refs/tags/$requested_ref^{}" ]]; then
    selected_ref="$requested_ref"
    selected_commit="$object"
    continue
  fi

  if [[ "$ref" != refs/tags/* ]]; then
    continue
  fi
  tag="${ref#refs/tags/}"
  if [[ "$tag" == *'^{}' ]]; then
    peeled_tag="${tag%\^\{\}}"
    if [[ "$requested_ref" == 'latest' && "$peeled_tag" == "$best_tag" ]]; then
      best_commit="$object"
    fi
    continue
  fi

  if [[ "$requested_ref" == 'latest' ]]; then
    if [[ "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]] && {
      [[ -z "$best_tag" ]] || version_is_greater "$tag" "$best_tag"
    }; then
      best_tag="$tag"
      best_commit="$object"
    fi
  elif [[ "$tag" == "$requested_ref" ]]; then
    selected_ref="$tag"
    selected_commit="$object"
  fi
done < "$refs_path"

if [[ "$requested_ref" == 'latest' ]]; then
  selected_ref="$best_tag"
  selected_commit="$best_commit"
fi

[[ -n "$selected_ref" && -n "$selected_commit" ]] || \
  error "requested release ref was not found: $requested_ref"
[[ "$selected_commit" =~ ^[0-9a-fA-F]{40}$ ]] || \
  error "resolved release does not have a 40-character commit: $selected_ref"

temporary_output="$(mktemp "$output_dir/.resolve-release.XXXXXX")" || \
  error "unable to create a temporary release file below: $output_dir"
jq -n \
  --arg ref "$selected_ref" \
  --arg channel "$channel" \
  --arg commit "$selected_commit" \
  '{ref: $ref, channel: $channel, commit: $commit}' > "$temporary_output" || \
  error 'unable to write resolved release metadata.'
mv "$temporary_output" "$output_path" || error "unable to install release metadata: $output_path"
temporary_output=''
