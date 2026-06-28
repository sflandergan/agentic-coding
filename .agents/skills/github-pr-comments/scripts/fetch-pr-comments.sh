#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 2 ]; then
  printf 'Usage: %s [<pr-number>] [--comments-only|--diff-only|--json]\n' "$0" >&2
  exit 2
fi

if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  pr="$1"
  mode="${2:-}"
else
  pr="$(gh pr view --json number --jq '.number')"
  mode="${1:-}"
fi
case "$mode" in
  ""|--comments-only|--diff-only|--json) ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    printf 'Usage: %s [<pr-number>] [--comments-only|--diff-only|--json]\n' "$0" >&2
    exit 2
    ;;
esac

if [ "$mode" = "--diff-only" ]; then
  gh pr diff "$pr"
  exit 0
fi

pr_json="$(gh pr view "$pr" --json number,title,headRefName,baseRefName,url,comments,headRepository)"
repo=$(jq -r '.headRepository.nameWithOwner' <<<"$pr_json")
issue_comments_json="$(gh api "repos/$repo/issues/$pr/comments")"
inline_comments_json="$(gh api graphql \
  -F owner="${repo%%/*}" \
  -F name="${repo#*/}" \
  -F pr="$pr" \
  -f query='query($owner: String!, $name: String!, $pr: Int!) {
    repository(owner: $owner, name: $name) {
      pullRequest(number: $pr) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            comments(first: 100) {
              nodes {
                id
                databaseId
                path
                line
                originalLine
                body
                createdAt
                updatedAt
                url
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
  }' \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved | not) | .comments.nodes[]]')"

if [ "$mode" = "--json" ]; then
  PR_JSON="$pr_json" ISSUE_COMMENTS_JSON="$issue_comments_json" INLINE_COMMENTS_JSON="$inline_comments_json" node <<'JS'
const payload = {
  pr: JSON.parse(process.env.PR_JSON ?? '{}'),
  issueComments: JSON.parse(process.env.ISSUE_COMMENTS_JSON ?? '[]'),
  inlineComments: JSON.parse(process.env.INLINE_COMMENTS_JSON ?? '[]'),
};

console.log(JSON.stringify(payload, null, 2));
JS
  exit 0
fi

printf '## Comment Summary\n'
PR_JSON="$pr_json" ISSUE_COMMENTS_JSON="$issue_comments_json" INLINE_COMMENTS_JSON="$inline_comments_json" node <<'JS'
const pr = JSON.parse(process.env.PR_JSON ?? '{}');
const issueComments = JSON.parse(process.env.ISSUE_COMMENTS_JSON ?? '[]');
const inlineComments = JSON.parse(process.env.INLINE_COMMENTS_JSON ?? '[]');

const summarize = (body) => {
  const firstLine = String(body ?? '').replace(/\s+/g, ' ').trim();
  return firstLine.length > 180 ? `${firstLine.slice(0, 177)}...` : firstLine;
};

console.log(`PR #${pr.number}: ${pr.title}`);
console.log(`Branch: ${pr.headRefName} -> ${pr.baseRefName}`);
console.log(`URL: ${pr.url}`);
console.log('');

console.log(`Issue comments (${issueComments.length})`);
for (const comment of issueComments) {
  console.log(`- id=${comment.id} author=${comment.user?.login ?? 'unknown'} updated=${comment.updated_at}: ${summarize(comment.body)}`);
}
console.log('');

console.log(`Unresolved inline comments (${inlineComments.length})`);
for (const comment of inlineComments) {
  const location = `${comment.path}:${comment.line ?? comment.originalLine ?? '?'}`;
  console.log(`- databaseId=${comment.databaseId} ${location} updated=${comment.updatedAt}: ${summarize(comment.body)}`);
}
JS

printf '\n## PR\n'
printf '%s\n' "$pr_json"

printf '\n## Issue Comments\n'
printf '%s\n' "$issue_comments_json"

printf '\n## Inline PR Comments\n'
printf '%s\n' "$inline_comments_json"

if [ "$mode" = "--comments-only" ]; then
  exit 0
fi

printf '\n## Diff\n'
gh pr diff "$pr"
