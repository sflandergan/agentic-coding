#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: create-issue.sh --title TITLE --body-file PATH [--labels LABELS]

Options:
  --title      Issue title (required)
  --body-file  Path to markdown file with the issue body (required)
  --labels     Comma-separated labels (optional)
EOF
  exit 1
}

TITLE=""
BODY_FILE=""
LABELS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)
      TITLE="$2"
      shift 2
      ;;
    --body-file)
      BODY_FILE="$2"
      shift 2
      ;;
    --labels)
      LABELS="$2"
      shift 2
      ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage
      ;;
  esac
done

# Validate required arguments.
if [ -z "$TITLE" ]; then
  echo "Error: --title is required" >&2
  usage
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

# Detect host from the remote URL.
remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)
    if [ -n "$LABELS" ]; then
      gh issue create --title "$TITLE" --body-file "$BODY_FILE" --label "$LABELS"
    else
      gh issue create --title "$TITLE" --body-file "$BODY_FILE"
    fi
    ;;
  *)
    if [ -n "$LABELS" ]; then
      glab issue create --title "$TITLE" --description-file "$BODY_FILE" --label "$LABELS"
    else
      glab issue create --title "$TITLE" --description-file "$BODY_FILE"
    fi
    ;;
esac
