#!/usr/bin/env bash
# Shared Bats fixtures for release-resolution and exact-source tests.

set -euo pipefail

stub_setup() {
  local scratch_root="${SCRATCH:-$PWD/.temp/setup-release-tests}"

  TEST_ROOT="$scratch_root/test-${BATS_TEST_NUMBER:-0}-${RANDOM}"
  STUB_BIN="$TEST_ROOT/bin"
  mkdir -p "$STUB_BIN"
  REAL_TAR="$(command -v tar)"
  export TEST_ROOT STUB_BIN REAL_TAR
  export PATH="$STUB_BIN:$PATH"

  GIT_OUTPUT_FILE="$TEST_ROOT/git-output"
  GIT_CALL_LOG="$TEST_ROOT/git-calls"
  GIT_RESULT_INDEX_FILE="$TEST_ROOT/git-result-index"
  GIT_RESULTS='0'
  CURL_PAYLOAD=''
  CURL_RESULTS='0'
  CURL_CALL_LOG="$TEST_ROOT/curl-calls"
  CURL_URL_LOG="$TEST_ROOT/curl-urls"
  TAR_CALL_LOG="$TEST_ROOT/tar-calls"
  export GIT_OUTPUT_FILE GIT_CALL_LOG GIT_RESULT_INDEX_FILE GIT_RESULTS CURL_PAYLOAD CURL_RESULTS CURL_CALL_LOG CURL_URL_LOG TAR_CALL_LOG
  : > "$GIT_OUTPUT_FILE"
  : > "$GIT_CALL_LOG"
  : > "$GIT_RESULT_INDEX_FILE"
  : > "$CURL_CALL_LOG"
  : > "$CURL_URL_LOG"
  : > "$TAR_CALL_LOG"

  cat > "$STUB_BIN/git" <<'EOF'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "$GIT_CALL_LOG"
if [[ "${1:-}" == 'ls-remote' ]]; then
  refspec=''
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
        refspec="$1"
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
exit 97
EOF
  chmod +x "$STUB_BIN/git"

  cat > "$STUB_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -u
output_path=''
url=''
saw_retry=0
saw_retry_all_errors=0
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    --retry)
      [[ "${2:-}" == '1' ]] || exit 96
      saw_retry=1
      shift 2
      ;;
    --retry-all-errors)
      saw_retry_all_errors=1
      shift
      ;;
    http://*|https://*)
      url="$1"
      shift
      ;;
    *)
      shift
      ;;
  esac
done
printf '%s\n' "$*" >> "$CURL_CALL_LOG"
printf '%s\n' "$url" >> "$CURL_URL_LOG"
[[ -n "$output_path" && "$saw_retry" -eq 1 && "$saw_retry_all_errors" -eq 1 ]] || exit 96

IFS=',' read -r -a results <<< "${CURL_RESULTS:-0}"
for result in "${results[@]}"; do
  printf '%s\n' "$result" >> "$CURL_CALL_LOG"
  if [[ "$result" == '0' ]]; then
    cp "$CURL_PAYLOAD" "$output_path"
    exit 0
  fi
done
exit "${results[${#results[@]}-1]}"
EOF
  chmod +x "$STUB_BIN/curl"

  cat > "$STUB_BIN/tar" <<EOF
#!/usr/bin/env bash
set -u
printf '%s\n' "\$*" >> "\$TAR_CALL_LOG"
exec "$REAL_TAR" "\$@"
EOF
  chmod +x "$STUB_BIN/tar"
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

stub_git_failure() {
  : > "$GIT_OUTPUT_FILE"
  GIT_RESULTS='1'
  export GIT_RESULTS
  : > "$GIT_RESULT_INDEX_FILE"
}

stub_git_results() {
  GIT_RESULTS="$1"
  export GIT_RESULTS
  : > "$GIT_RESULT_INDEX_FILE"
}

stub_curl_payload() {
  CURL_PAYLOAD="$1"
  CURL_RESULTS="${2:-0}"
  export CURL_PAYLOAD CURL_RESULTS
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

make_release_archive() {
  local archive_path="$1"
  local root_name="$2"
  local manifest_path="$3"
  local content_root="$TEST_ROOT/archive-content"

  rm -rf "$content_root"
  mkdir -p "$content_root/$root_name"
  cp "$manifest_path" "$content_root/$root_name/manifest.json"
  printf 'release asset\n' > "$content_root/$root_name/README.md"
  "$REAL_TAR" -czf "$archive_path" -C "$content_root" "$root_name"
}

make_archive_with_member() {
  local archive_path="$1"
  local root_name="$2"
  local member_name="$3"
  local member_content="${4:-unsafe}\n"
  local content_root="$TEST_ROOT/archive-content"
  local member_path

  rm -rf "$content_root"
  mkdir -p "$content_root/$root_name"
  printf '%b' "$member_content" > "$content_root/$root_name/manifest.json"
  member_path="$content_root/$root_name/$member_name"
  if [[ "$member_name" == /* || "$member_name" == ../* || "$member_name" == */../* ]]; then
    python3 - "$archive_path" "$root_name" "$member_name" "$member_content" <<'PY'
import io
import sys
import tarfile

archive_path, root_name, member_name, content = sys.argv[1:]
with tarfile.open(archive_path, "w:gz") as archive:
    root = tarfile.TarInfo(root_name + "/")
    root.type = tarfile.DIRTYPE
    archive.addfile(root)
    member = tarfile.TarInfo(member_name)
    payload = content.encode()
    member.size = len(payload)
    archive.addfile(member, io.BytesIO(payload))
PY
  else
    mkdir -p "$(dirname "$member_path")"
    printf '%b' "$member_content" > "$member_path"
    "$REAL_TAR" -czf "$archive_path" -C "$content_root" "$root_name"
  fi
}
