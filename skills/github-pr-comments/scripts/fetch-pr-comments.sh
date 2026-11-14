#!/usr/bin/env bash
set -euo pipefail

usage() { printf 'Usage: %s [<pr>] [--all|--diff-only|--json]\n' "$0" >&2; exit 2; }

pr=""
mode=""
# Arguments are processed left-to-right; a recognized mode may appear before or
# after the optional PR number, but only one mode is accepted.
while [ "$#" -gt 0 ]; do
  case "$1" in
    --all|--diff-only|--json)
      [ -z "$mode" ] || usage
      mode="$1"
      ;;
    # Empty or nonnumeric non-mode tokens are invalid; the pattern matches
    # any string that contains at least one nondigit.
    *[!0-9]*|'') usage ;;
    *)
      # The remaining all-digit token is the optional PR number; only one is
      # accepted.
      [ -z "$pr" ] || usage
      pr="$1"
      ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 || { printf 'gh is not installed.\n' >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { printf 'jq is not installed.\n' >&2; exit 1; }

# Reads and replies must address the BASE repository; project automation runs
# from a maintainer checkout whose origin is that repository. A contributor in
# a fork clone must override origin with GH_REPO=owner/name.
repo="${GH_REPO:-$(git remote get-url origin 2>/dev/null | sed -E 's#^git@[^:]+:##; s#^https?://[^/]+/##; s#\.git$##')}"
[[ "$repo" =~ ^[^/]+/[^/]+$ ]] || { printf 'Unable to determine the GitHub repo; set GH_REPO=owner/name.\n' >&2; exit 1; }

# With no <pr>, resolve the pull request of the current branch (no -R: uses local git).
[ -n "$pr" ] || pr="$(gh pr view --json number --jq '.number')"

if [ "$mode" = "--diff-only" ]; then
  gh pr diff "$pr" -R "$repo"
  exit 0
fi

pr_json="$(gh pr view "$pr" -R "$repo" --json number,title,headRefName,baseRefName,url)"

# `comments` is deliberately not selected above: gh returns the same conversation
# comments the REST call below returns, and selecting both duplicated every body.
#
# --paginate without --slurp emits one JSON array per page, which is not a single
# JSON document. --slurp wraps the pages in an outer array, so one empty page
# yields [[]]. `flatten` normalizes both shapes and is an identity operation on a
# flat array of objects.
conversation_json="$(gh api --paginate --slurp "repos/$repo/issues/$pr/comments?per_page=100" | jq 'flatten')"

# --jq runs per page and streams thread objects; `jq -s` collects the stream into
# one array, which avoids depending on --slurp's nesting shape here.
# comments(first: 100) is NOT paginated: a thread with more than 100 notes
# truncates. Threads that long do not occur in this project's review workflow.
# single-quoted GraphQL query is intentional ($vars are gh-substituted)
# shellcheck disable=SC2016
threads_json="$(gh api graphql --paginate \
  -F owner="${repo%%/*}" \
  -F name="${repo#*/}" \
  -F pr="$pr" \
  -f query='query($owner: String!, $name: String!, $pr: Int!, $endCursor: String) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100, after: $endCursor) {
          pageInfo { hasNextPage endCursor }
          nodes {
            isResolved
            isOutdated
            path
            line
            originalLine
            comments(first: 100) {
              nodes { databaseId author { login } body createdAt updatedAt }
            }
          }
        }
      }
    }
  }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes[]' | jq -s '.')"

if [ "$mode" = "--json" ]; then
  jq -n \
    --argjson pr "$pr_json" \
    --argjson conversation "$conversation_json" \
    --argjson threads "$threads_json" \
    '{ pr: $pr, conversationComments: $conversation, threads: $threads }'
  exit 0
fi

all=false
[ "$mode" = "--all" ] && all=true

jq -r -n \
  --argjson pr "$pr_json" \
  --argjson conversation "$conversation_json" \
  --argjson threads "$threads_json" \
  --argjson all "$all" '
  # "path:line" for a live thread, "path:originalLine (outdated)" for a thread
  # whose anchor no longer exists on the current diff.
  def anchor:
    "\(.path // "?"):\(.line // .originalLine // "?")"
    + (if .isOutdated then " (outdated)" else "" end);

  ( $threads | map(select($all or (.isResolved | not))) ) as $shown
  | "PR #\($pr.number): \($pr.title)",
    "Branch: \($pr.headRefName) -> \($pr.baseRefName)",
    "URL: \($pr.url)",
    "",
    "## Conversation comments (\($conversation | length))",
    ( $conversation[]?
      | "",
        "author=\(.user.login // "unknown") created=\(.created_at)",
        .body
    ),
    "",
    "## \(if $all then "Inline threads" else "Unresolved inline threads" end) (\($shown | length))",
    ( $shown[]
      | .comments.nodes as $notes
      | $notes[0] as $root
      | "",
        "thread_id=\($root.databaseId) \(anchor) author=\($root.author.login // "unknown") updated=\($root.updatedAt)"
          + (if .isResolved then " [resolved]" else "" end),
        ( $notes[] | "[\(.author.login // "unknown") \(.updatedAt)] \(.body)" )
    )
  '