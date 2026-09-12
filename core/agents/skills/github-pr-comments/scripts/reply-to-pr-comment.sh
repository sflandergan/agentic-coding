#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 1 ]; then
  pr=""
  replies_json="$1"
elif [ "$#" -eq 2 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
  pr="$1"
  replies_json="$2"
else
  printf 'Usage: %s [<pr>] <replies-json>\n' "$0" >&2
  exit 2
fi

command -v gh >/dev/null 2>&1 || { printf 'gh is not installed.\n' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'jq is not installed.\n' >&2; exit 1; }

# thread_id is the value fetch-pr-comments.sh prints as `thread_id=`: the
# databaseId of the thread's root note, which is what the replies endpoint takes.
if ! jq -e 'type == "array" and all(.[]; (.thread_id | type == "number" and . > 0 and . == floor) and (.body | type == "string" and length > 0))' \
  >/dev/null <<<"$replies_json"; then
  printf 'Reply JSON must be an array of { "thread_id": <id>, "body": non-empty string } objects.\n' >&2
  exit 2
fi

# The replies endpoint requires the BASE repository; project automation runs
# from a maintainer checkout whose origin is that repository. A contributor in
# a fork clone must override origin with GH_REPO=owner/name.
repo="${GH_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##')}"
[[ "$repo" =~ ^[^/]+/[^/]+$ ]] || { printf 'Unable to determine the GitHub repo; set GH_REPO=owner/name.\n' >&2; exit 1; }

# With no <pr>, resolve the pull request of the current branch (no -R: uses local git).
[ -n "$pr" ] || pr="$(gh pr view --json number --jq '.number')"

count="$(jq length <<<"$replies_json")"
printf 'Posting %d replies to PR #%s...\n' "$count" "$pr"

while IFS= read -r reply; do
  thread_id="$(jq -r '.thread_id' <<<"$reply")"
  body="$(jq -r '.body' <<<"$reply")"

  printf '  Replying to thread %s... ' "$thread_id"
  # Redirected: the created-comment object is large and carries nothing the
  # caller needs beyond the success of the call.
  gh api --method POST "repos/$repo/pulls/$pr/comments/$thread_id/replies" -f body="$body" >/dev/null
  printf 'done\n'
done < <(jq -c '.[]' <<<"$replies_json")

printf 'All %d replies posted.\n' "$count"