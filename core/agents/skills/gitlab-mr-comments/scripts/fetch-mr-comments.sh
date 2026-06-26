#!/usr/bin/env bash
set -euo pipefail

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
