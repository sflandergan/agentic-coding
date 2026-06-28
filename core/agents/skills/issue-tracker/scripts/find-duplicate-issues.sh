#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: find-duplicate-issues.sh --title TITLE [--labels LABELS]

Options:
  --title      Search term for issue title (required)
  --labels     Comma-separated labels to filter by (optional)
EOF
  exit 1
}

TITLE=""
LABELS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --title)
      TITLE="$2"
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

# Detect host from the remote URL.
remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)
    label_args=()
    if [ -n "$LABELS" ]; then
      IFS=',' read -ra label_arr <<< "$LABELS"
      for label in "${label_arr[@]}"; do
        label_args+=(--label "$label")
      done
    fi
    gh issue list --search "$TITLE" "${label_args[@]}" --json number,title,url
    ;;
  *)
    label_args=()
    if [ -n "$LABELS" ]; then
      IFS=',' read -ra label_arr <<< "$LABELS"
      for label in "${label_arr[@]}"; do
        label_args+=(--label "$label")
      done
    fi
    glab issue list --search "$TITLE" "${label_args[@]}" --output json
    ;;
esac
