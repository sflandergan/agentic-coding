#!/usr/bin/env bash
#
# prepare-release.sh — Prepare a stable release manifest for tagging.
#
# Modes:
#   --compute-version <major|minor|patch>
#       Print the highest existing stable tag and the next stable version on
#       separate vX.Y.Z lines. The caller is responsible for having fetched
#       remote tags first. Uses v0.1.0 as the previous version when no tags
#       exist. Never contacts the network.
#   <version>
#       Validate the requested version and repository state, rewrite only the
#       manifest release metadata from main/preview to <version>/stable, and
#       run the release validator and the setup test suite. Produces a
#       validated working tree for the release workflow to commit; it never
#       commits, tags, or pushes.
#
# Environment overrides (used by scripts/test/prepare-release.bats):
#   RELEASE_REPO_ROOT        repository root to operate on (default: git toplevel)
#   SCRATCH                  scratch directory for the setup test suite

set -euo pipefail

usage() {
  printf 'Usage: scripts/prepare-release.sh <version>\n' >&2
  printf '       scripts/prepare-release.sh --compute-version <major|minor|patch>\n' >&2
  exit 1
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if [[ -n "${RELEASE_REPO_ROOT:-}" ]]; then
  REPO_ROOT="$RELEASE_REPO_ROOT"
else
  REPO_ROOT="$(git rev-parse --show-toplevel)" ||
    fail "unable to determine the repository root."
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"
MANIFEST="$REPO_ROOT/manifest.json"
SCRATCH="${SCRATCH:-$REPO_ROOT/.temp/prepare-release}"

command -v jq >/dev/null 2>&1 || fail "jq is required to parse the release manifest."

compute_version() {
  local bump="$1"
  local highest previous major minor patch

  case "$bump" in
    major|minor|patch) ;;
    *) fail "bump must be major, minor, or patch: $bump" ;;
  esac

  highest="$(
    git -C "$REPO_ROOT" tag -l 'v*' \
      | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -n 1 || true
  )"

  if [[ -z "$highest" ]]; then
    previous=v0.1.0
    major=0 minor=1 patch=0
  else
    previous="$highest"
    IFS='.' read -r major minor patch <<< "${highest#v}"
    [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ && "$patch" =~ ^[0-9]+$ ]] ||
      fail "highest stable tag is not semantic: $highest"
  fi

  case "$bump" in
    major) major=$((major + 1)); minor=0; patch=0 ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    patch) patch=$((patch + 1)) ;;
  esac

  printf '%s\nv%d.%d.%d\n' "$previous" "$major" "$minor" "$patch"
}

prepare_release() {
  local version="$1"

  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
    fail "version must match ^v[0-9]+\\.[0-9]+\\.[0-9]+\$ : $version"

  command -v bats >/dev/null 2>&1 || fail "bats is required to run the setup test suite."
  [[ -f "$MANIFEST" ]] || fail "release manifest does not exist: $MANIFEST"

  # The source state must be the preview development manifest.
  jq -e '.release.ref == "main" and .release.channel == "preview"' "$MANIFEST" >/dev/null ||
    fail "source manifest is not main/preview: $MANIFEST"

  # The requested tag must not exist locally.
  if git -C "$REPO_ROOT" rev-parse -q --verify "refs/tags/$version" >/dev/null 2>&1; then
    fail "tag already exists: $version"
  fi

  # Rewrite only the release metadata.
  jq --arg ref "$version" '.release.ref = $ref | .release.channel = "stable"' \
    "$MANIFEST" > "$MANIFEST.tmp" ||
    fail "unable to rewrite manifest release metadata."
  mv "$MANIFEST.tmp" "$MANIFEST"

  jq -e --arg ref "$version" '.release.ref == $ref and .release.channel == "stable"' \
    "$MANIFEST" >/dev/null ||
    fail "manifest does not declare the requested stable release after rewrite."

  # Validate the prepared tree.
  bash "$REPO_ROOT/scripts/validate-release.sh" ||
    fail "release validation failed for $version."

  mkdir -p "$SCRATCH"
  SCRATCH="$SCRATCH" bats "$REPO_ROOT"/skills/setup/test/*.bats ||
    fail "setup test suite failed for $version."

  echo "PASS: prepared stable release manifest for $version."
}

main() {
  if [[ "${1:-}" == "--compute-version" ]]; then
    [[ $# -eq 2 ]] || usage
    compute_version "$2"
  else
    [[ $# -eq 1 ]] || usage
    prepare_release "$1"
  fi
}

main "$@"
