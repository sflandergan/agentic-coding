#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: update-bug-issue.sh --issue NUMBER --body-file PATH

Options:
  --issue      Issue number to update (required)
  --body-file  Path to updated markdown body (required)
EOF
  exit 1
}

ISSUE=""
BODY_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --issue)
      ISSUE="$2"
      shift 2
      ;;
    --body-file)
      BODY_FILE="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage
      ;;
  esac
done

# Validate required arguments
if [ -z "$ISSUE" ]; then
  echo "Error: --issue is required" >&2
  usage
fi

if ! [[ "$ISSUE" =~ ^[0-9]+$ ]]; then
  echo "Error: --issue must be a positive integer, got '$ISSUE'" >&2
  exit 1
fi

if [ -z "$BODY_FILE" ]; then
  echo "Error: --body-file is required" >&2
  usage
fi

if [ ! -f "$BODY_FILE" ]; then
  echo "Error: body file '$BODY_FILE' does not exist" >&2
  exit 1
fi

if [ ! -s "$BODY_FILE" ]; then
  echo "Error: body file '$BODY_FILE' is empty" >&2
  exit 1
fi

# Check gh is available
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed. Install it from https://cli.github.com/" >&2
  exit 1
fi

# Update the issue
gh issue edit "$ISSUE" --body-file "$BODY_FILE"
URL=$(gh issue view "$ISSUE" --json url -q .url)
echo "$URL"
