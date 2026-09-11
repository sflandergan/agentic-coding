#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ] || [ -z "$1" ] || [ -z "$2" ]; then
  printf 'Usage: %s <pr-url-or-number> <expected-40-char-sha>\n' "$0" >&2
  exit 2
fi

pr="$1"
expected_sha="$2"

# Validate SHA is 40 hex characters.
if ! printf '%s' "$expected_sha" | grep -qE '^[0-9a-f]{40}$'; then
  printf 'Error: expected SHA must be 40 hex characters, got: %s\n' "$expected_sha" >&2
  exit 2
fi

view_pr() { gh pr view "$pr" --json state,isDraft,url,headRefOid; }

# GitHub's PR head view can lag behind a just-pushed branch, so a single
# read right after publication may report the previous head.
# Re-read a bounded number of times and accept only an exact match; a
# genuinely wrong head never converges and still fails closed.
max_attempts=3
attempt=0
while :; do
  # Read headRefOid before any mutation.
  metadata="$(view_pr)" || { printf 'Unable to read PR %s\n' "$pr" >&2; exit 1; }
  state="$(printf '%s' "$metadata" | jq -r '.state')"
  draft="$(printf '%s' "$metadata" | jq -r '.isDraft')"
  url="$(printf '%s' "$metadata" | jq -r '.url')"
  head_oid="$(printf '%s' "$metadata" | jq -r '.headRefOid')"

  if [ "$head_oid" = "$expected_sha" ]; then
    break
  fi
  attempt=$((attempt + 1))
  if [ "$attempt" -ge "$max_attempts" ]; then
    printf 'Error: headRefOid %s does not match expected SHA %s; no readiness mutation performed.\n' "$head_oid" "$expected_sha" >&2
    exit 1
  fi
  printf 'headRefOid %s does not yet match expected SHA %s; re-reading PR metadata.\n' "$head_oid" "$expected_sha" >&2
  sleep "${MARK_PR_READY_RETRY_SECONDS:-2}"
done

if [ "$state" != OPEN ]; then
  printf 'Refusing to mark closed PR ready: %s\n' "$pr" >&2
  exit 1
fi
if [ "$draft" = true ]; then
  gh pr ready "$pr" || { printf 'Failed to mark PR ready: %s\n' "$pr" >&2; exit 1; }
fi

# Read headRefOid after mutation and verify it still matches.
metadata="$(view_pr)" || { printf 'Unable to verify PR readiness: %s\n' "$pr" >&2; exit 1; }
state="$(printf '%s' "$metadata" | jq -r '.state')"
draft="$(printf '%s' "$metadata" | jq -r '.isDraft')"
url="$(printf '%s' "$metadata" | jq -r '.url')"
head_oid="$(printf '%s' "$metadata" | jq -r '.headRefOid')"

if [ "$head_oid" != "$expected_sha" ]; then
  printf 'Error: headRefOid changed from %s to %s after readiness; completion not claimed.\n' "$expected_sha" "$head_oid" >&2
  exit 1
fi

if [ "$state" != OPEN ] || [ "$draft" != false ]; then
  printf 'PR remains unintentionally draft or is no longer open: %s\n' "$pr" >&2
  exit 1
fi
printf '%s\n' "$url"