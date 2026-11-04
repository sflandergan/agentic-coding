#!/usr/bin/env bash
# Shared Bats fixtures for release selection and exact-source tests.

set -euo pipefail

stub_setup() {
  local scratch_root="${SCRATCH:-$PWD/.temp/setup-release-tests}"

  TEST_ROOT="$scratch_root/test-${BATS_TEST_NUMBER:-0}-${RANDOM}"
  STUB_BIN="$TEST_ROOT/bin"
  mkdir -p "$STUB_BIN"
  REAL_GIT="$(command -v git)"
  export TEST_ROOT STUB_BIN REAL_GIT
  export PATH="$STUB_BIN:$PATH"

  GIT_OUTPUT_FILE="$TEST_ROOT/git-output"
  GIT_CALL_LOG="$TEST_ROOT/git-calls"
  GIT_RESULT_INDEX_FILE="$TEST_ROOT/git-result-index"
  GIT_FETCH_INDEX_FILE="$TEST_ROOT/git-fetch-index"
  GIT_RESULTS='0'
  GIT_FETCH_RESULTS='0'
  export GIT_OUTPUT_FILE GIT_CALL_LOG GIT_RESULT_INDEX_FILE GIT_FETCH_INDEX_FILE GIT_RESULTS GIT_FETCH_RESULTS
  : > "$GIT_OUTPUT_FILE"
  : > "$GIT_CALL_LOG"
  : > "$GIT_RESULT_INDEX_FILE"
  : > "$GIT_FETCH_INDEX_FILE"

  cat > "$STUB_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$GIT_CALL_LOG"
is_fetch=0
for argument in "$@"; do
  if [[ "$argument" == 'fetch' ]]; then
    is_fetch=1
    break
  fi
done
if [[ "$is_fetch" -eq 1 ]]; then
  IFS=',' read -r -a fetch_results <<< "${GIT_FETCH_RESULTS:-0}"
  fetch_index=0
  if [[ -s "$GIT_FETCH_INDEX_FILE" ]]; then
    fetch_index="$(<"$GIT_FETCH_INDEX_FILE")"
  fi
  (( fetch_index < ${#fetch_results[@]} )) || fetch_index=$((${#fetch_results[@]} - 1))
  fetch_result="${fetch_results[$fetch_index]}"
  printf '%s\n' "$((fetch_index + 1))" > "$GIT_FETCH_INDEX_FILE"
  if [[ "$fetch_result" -ne 0 ]]; then
    exit "$fetch_result"
  fi
  exec "$REAL_GIT" "$@"
fi
if [[ "${1:-}" == 'ls-remote' ]]; then
  refspec=''
  remote_seen=0
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      ls-remote|--tags)
        [[ "$1" == '--tags' ]] && refspec='refs/tags/*'
        ;;
      --heads)
        refspec='refs/heads/*'
        ;;
      -*|http://*|https://*)
        ;;
      *)
        if [[ "$remote_seen" -eq 0 ]]; then
          remote_seen=1
        else
          refspec="$1"
        fi
        ;;
    esac
    shift
  done

  IFS=',' read -r -a results <<< "${GIT_RESULTS:-${GIT_STATUS:-0}}"
  result_index=0
  if [[ -s "$GIT_RESULT_INDEX_FILE" ]]; then
    result_index="$(<"$GIT_RESULT_INDEX_FILE")"
  fi
  (( result_index < ${#results[@]} )) || result_index=$((${#results[@]} - 1))
  result="${results[$result_index]}"
  printf '%s\n' "$((result_index + 1))" > "$GIT_RESULT_INDEX_FILE"
  if [[ "$result" -ne 0 ]]; then
    exit "$result"
  fi

  while IFS= read -r line; do
    ref="${line#*$'\t'}"
    if [[ -z "$refspec" || "$ref" == $refspec ]]; then
      printf '%s\n' "$line"
    fi
  done < "$GIT_OUTPUT_FILE"
  exit 0
fi
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$STUB_BIN/git"
}

stub_teardown() {
  rm -rf "$TEST_ROOT"
  if [[ -n "${SCRATCH:-}" ]]; then
    rmdir "$SCRATCH" 2>/dev/null || true
  fi
}

stub_git_output() {
  printf '%s\n' "$1" > "$GIT_OUTPUT_FILE"
  GIT_RESULTS='0'
  export GIT_RESULTS
  : > "$GIT_RESULT_INDEX_FILE"
}

stub_git_results() {
  GIT_RESULTS="$1"
  export GIT_RESULTS
  : > "$GIT_RESULT_INDEX_FILE"
}

write_test_manifest() {
  local output_path="$1"
  local release_ref="$2"
  local channel="$3"

  jq -n --arg release_ref "$release_ref" --arg channel "$channel" '
    {
      schemaVersion: 1,
      release: {ref: $release_ref, channel: $channel},
      skills: {
        authored: [{name: "setup", path: "skills/setup"}]
      },
      opencode: {primary: ["planner"], subagents: ["implement-task"]},
      subagents: {
        claude: ["implement-task"],
        codex: ["implement-task"],
        opencode: ["implement-task"]
      },
      templates: {
        agentsMd: "templates/AGENTS.md",
        roleDocs: "templates/docs/agents",
        harnessConfig: {
          claude: "templates/claude",
          codex: "templates/codex",
          opencode: "templates/opencode"
        }
      }
    } | .skills["third" + "Party"] = []
  ' > "$output_path"
}
