#!/usr/bin/env bash
set -euo pipefail

remote_url="$(git remote get-url origin)"

case "$remote_url" in
  *github.com*)

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
    ;;

  *)

    if [ "$#" -gt 2 ]; then
      printf 'Usage: %s [<mr-iid>] [--comments-only|--diff-only|--json]\n' "$0" >&2
      exit 2
    fi

    if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
      mr="$1"
      mode="${2:-}"
    else
      mr="$(glab mr view -F json | jq -r '.iid')"
      mode="${1:-}"
    fi
    case "$mode" in
      ""|--comments-only|--diff-only|--json) ;;
      *)
        printf 'Unknown mode: %s\n' "$mode" >&2
        printf 'Usage: %s [<mr-iid>] [--comments-only|--diff-only|--json]\n' "$0" >&2
        exit 2
        ;;
    esac

    if [ "$mode" = "--diff-only" ]; then
      glab mr diff "$mr"
      exit 0
    fi

    mr_json="$(glab mr view "$mr" -F json)"
    discussions_json="$(glab api --paginate "projects/:id/merge_requests/$mr/discussions?per_page=100")"

    if [ "$mode" = "--json" ]; then
      jq -n \
        --argjson mr "$mr_json" \
        --argjson discussions "$discussions_json" \
        '{ mr: $mr, discussions: $discussions }'
      exit 0
    fi

    printf '## Note Summary\n'
    jq -r \
      --argjson mr "$mr_json" '
      def summarize: (. // "" | gsub("\\s+"; " ") | .[0:180]);
      "MR !\($mr.iid): \($mr.title)",
      "Branch: \($mr.source_branch) -> \($mr.target_branch)",
      "URL: \($mr.web_url)",
      "",
      "Standalone conversation notes (\([.[] | select(.individual_note == true)] | length)):",
      ( .[] | select(.individual_note == true) | .notes[] | select(.system == false)
        | "- discussion_id=\(.id // "?") note=\(.id) author=\(.author.username) updated=\(.updated_at): \(.body | summarize)" ),
      "",
      "Unresolved inline diff discussions:",
      ( .[] | select(.individual_note != true) | . as $d
        | select([.notes[] | select(.resolvable == true and .resolved == false)] | length > 0)
        | .notes[0] as $n
        | "- discussion_id=\($d.id) \($n.position.new_path // $n.position.old_path // "?"):\($n.position.new_line // $n.position.old_line // "?") author=\($n.author.username) updated=\($n.updated_at): \($n.body | summarize)" )
      ' <<<"$discussions_json"

    printf '\n## MR\n'
    printf '%s\n' "$mr_json"

    printf '\n## Discussions\n'
    printf '%s\n' "$discussions_json"

    if [ "$mode" = "--comments-only" ]; then
      exit 0
    fi

    printf '\n## Diff\n'
    glab mr diff "$mr"
    ;;
esac
