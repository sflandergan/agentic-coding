#!/usr/bin/env bash
set -euo pipefail

remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)

    if [ "$#" -eq 1 ]; then
      pr_info="$(gh pr view --json number,headRepository)"
      replies_json="$1"
    elif [ "$#" -eq 2 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
      pr_info="$(gh pr view "$1" --json number,headRepository)"
      replies_json="$2"
    else
      printf 'Usage: %s [<pr-number>] <replies-json>\n' "$0" >&2
      exit 2
    fi

    pr=$(jq -r '.number' <<<"$pr_info")
    repo=$(jq -r '.headRepository.nameWithOwner' <<<"$pr_info")

    if ! jq -e 'type == "array" and all(.[]; (.comment_id | type == "number") and (.body | type == "string"))' \
      >/dev/null <<<"$replies_json"; then
      printf 'Reply JSON must be an array of { "comment_id": number, "body": string } objects.\n' >&2
      exit 2
    fi

    count=$(jq length <<<"$replies_json")
    printf 'Posting %d replies to PR #%s...\n' "$count" "$pr"

    while IFS= read -r reply; do
      comment_id=$(jq -r '.comment_id' <<<"$reply")
      body=$(jq -r '.body' <<<"$reply")

      printf '  Replying to comment %s... ' "$comment_id"
      gh api --method POST "repos/$repo/pulls/$pr/comments/$comment_id/replies" \
        -f body="$body"
      printf 'done\n'
    done < <(jq -c '.[]' <<<"$replies_json")

    printf 'All %d replies posted.\n' "$count"
    ;;

  *)

    if [ "$#" -eq 1 ]; then
      mr="$(glab mr view -F json | jq -r '.iid')"
      replies_json="$1"
    elif [ "$#" -eq 2 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
      mr="$1"
      replies_json="$2"
    else
      printf 'Usage: %s [<mr-iid>] <replies-json>\n' "$0" >&2
      exit 2
    fi

    if ! jq -e 'type == "array" and all(.[]; (.discussion_id | type == "string") and (.body | type == "string"))' \
      >/dev/null <<<"$replies_json"; then
      printf 'Reply JSON must be an array of { "discussion_id": string, "body": string } objects.\n' >&2
      exit 2
    fi

    count=$(jq length <<<"$replies_json")
    printf 'Posting %d replies to MR !%s...\n' "$count" "$mr"

    while IFS= read -r reply; do
      discussion_id=$(jq -r '.discussion_id' <<<"$reply")
      body=$(jq -r '.body' <<<"$reply")

      printf '  Replying to discussion %s... ' "$discussion_id"
      glab mr note create "$mr" --reply "$discussion_id" -m "$body"
      printf 'done\n'
    done < <(jq -c '.[]' <<<"$replies_json")

    printf 'All %d replies posted.\n' "$count"
    ;;
esac
