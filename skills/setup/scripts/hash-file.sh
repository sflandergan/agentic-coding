#!/usr/bin/env bash
# Print one normalized SHA-256 digest for a regular file.

set -euo pipefail

usage() {
  printf 'Usage: %s FILE\n' "$0" >&2
  exit 2
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

[[ "$#" -eq 1 ]] || usage

target="$1"
[[ -f "$target" ]] || error "input is not a regular file: $target"

hash_output=''
if command -v shasum >/dev/null 2>&1; then
  if ! hash_output="$(shasum -a 256 "$target" 2>/dev/null)"; then
    error 'shasum failed.'
  fi
elif command -v sha256sum >/dev/null 2>&1; then
  if ! hash_output="$(sha256sum "$target" 2>/dev/null)"; then
    error 'sha256sum failed.'
  fi
else
  error 'neither shasum nor sha256sum is available.'
fi

[[ -n "$hash_output" && "$hash_output" != *$'\n'* ]] || \
  error 'hash command returned malformed output.'
digest="${hash_output%%[[:space:]]*}"
[[ "$digest" =~ ^[0-9A-Fa-f]{64}$ ]] || \
  error 'hash command returned malformed output.'

digest="$(printf '%s' "$digest" | tr '[:upper:]' '[:lower:]')"
printf '%s\n' "$digest"
