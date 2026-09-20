#!/usr/bin/env bash
#
# Fetch and validate one release manifest without fetching the repository.
#
# Usage: fetch-release-manifest.sh TOOLKIT_REMOTE REQUESTED_REF CHANNEL COMMIT OUTPUT_PATH

set -euo pipefail

usage() {
  printf 'Usage: %s TOOLKIT_REMOTE REQUESTED_REF CHANNEL COMMIT OUTPUT_PATH\n' "$0" >&2
  exit 2
}

exitWithError() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$#" -eq 5 ]] || usage

remote="$1"
requested_ref="$2"
channel="$3"
commit="$4"
output_path="$5"

[[ -n "$remote" ]] || exitWithError 'toolkit remote must not be empty.'
[[ -n "$requested_ref" ]] || exitWithError 'requested ref must not be empty.'
[[ "$requested_ref" =~ ^[A-Za-z0-9_.\/-]+$ ]] || exitWithError 'requested ref contains unsupported characters.'
[[ "$channel" == 'stable' || "$channel" == 'preview' ]] || exitWithError 'channel must be stable or preview.'
[[ "$commit" =~ ^[0-9a-fA-F]{40}$ ]] || exitWithError 'commit must be exactly 40 hexadecimal characters.'
[[ -n "$output_path" ]] || exitWithError 'output path must not be empty.'

command -v curl >/dev/null 2>&1 || exitWithError 'curl is required.'
command -v jq >/dev/null 2>&1 || exitWithError 'jq is required.'

output_dir="${output_path%/*}"
[[ "$output_dir" != "$output_path" ]] || output_dir='.'
mkdir -p "$output_dir" || exitWithError "unable to create output directory: $output_dir"

temporary_path="$(mktemp "$output_dir/.fetch-release-manifest.XXXXXX")" || \
  exitWithError "unable to create a temporary manifest below: $output_dir"

cleanup() {
  if [[ -n "${temporary_path:-}" ]]; then
    rm -f "$temporary_path"
  fi
}
trap cleanup EXIT

remote_path="$remote"
remote_path="${remote_path#https://github.com/}"
remote_path="${remote_path#http://github.com/}"
remote_path="${remote_path%/}"
remote_path="${remote_path%.git}"
[[ "$remote_path" =~ ^[^/]+/[^/]+$ ]] || exitWithError 'toolkit remote must be a GitHub owner/repository URL.'
manifest_url="https://raw.githubusercontent.com/${remote_path}/${commit}/manifest.json"

if ! curl --fail --location --silent --show-error --retry 1 --retry-all-errors \
  "$manifest_url" --output "$temporary_path"; then
  exitWithError "unable to fetch release manifest at commit $commit from: $remote"
fi

if ! jq -e --arg requested_ref "$requested_ref" --arg channel "$channel" '
  (type == "object") and
  (.schemaVersion | if type == "number" then floor == . and . == 1 else false end) and
  (.release | type == "object") and
   (.release.ref | type == "string" and length > 0) and
  (.release.channel | type == "string" and (. == "stable" or . == "preview")) and
  (.skills | type == "object") and
  (.skills.authored |
    if type == "array" then
      all(.[];
        type == "object" and
        (.name | type == "string" and length > 0) and
        (.path | type == "string" and length > 0)
      )
    else false end
  ) and
  (.skills.thirdParty |
    if type == "array" then
      all(.[];
        type == "object" and
        (.name | type == "string" and length > 0) and
        (.source | type == "string" and length > 0) and
        (.sourceType | type == "string" and length > 0) and
        (.commit | type == "string" and test("^[0-9a-f]{40}$")) and
        ((has("skillPath") | not) or (.skillPath | type == "string")) and
        ((has("computedHash") | not) or (.computedHash | type == "string"))
      )
    else false end
  ) and
  (.opencode |
    if type == "object" then
      (.primary | if type == "array" then all(.[]; type == "string" and length > 0) else false end) and
      (.subagents | if type == "array" then all(.[]; type == "string" and length > 0) else false end)
    else false end
  ) and
  (.subagents |
    if type == "object" then
      (.claude | if type == "array" then all(.[]; type == "string" and length > 0) else false end) and
      (.codex | if type == "array" then all(.[]; type == "string" and length > 0) else false end) and
      (.opencode | if type == "array" then all(.[]; type == "string" and length > 0) else false end)
    else false end
  ) and
  (.templates |
    if type == "object" then
      (.agentsMd | type == "string" and length > 0) and
      (.roleDocs | type == "string" and length > 0) and
      (.harnessConfig |
        if type == "object" then
          (.claude | type == "string" and length > 0) and
          (.codex | type == "string" and length > 0) and
          (.opencode | type == "string" and length > 0)
        else false end
      )
    else false end
  ) and
   (.release.ref == $requested_ref) and
  (.release.channel == $channel)
' "$temporary_path" >/dev/null; then
  exitWithError 'fetched release manifest is malformed, unsupported, or does not match the resolved ref and channel.'
fi

mv "$temporary_path" "$output_path" || exitWithError "unable to install manifest: $output_path"
temporary_path=''
