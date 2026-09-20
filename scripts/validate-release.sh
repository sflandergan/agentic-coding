#!/usr/bin/env bash
#
# validate-release.sh — Validate the toolkit release manifest and inventory.
#
# Checks that the release manifest points at the authored toolkit assets and
# that its third-party skill records stay synchronized with the core lockfile.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! REPO_ROOT="$(git -C "$SCRIPT_DIR/.." rev-parse --show-toplevel 2>/dev/null)"; then
  echo "ERROR: unable to determine the repository root." >&2
  exit 1
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"

MANIFEST="$REPO_ROOT/manifest.json"
SKILLS_LOCK="$REPO_ROOT/core/skills-lock.json"

command -v jq >/dev/null 2>&1 || {
  echo "ERROR: jq is required to parse the release manifest." >&2
  exit 1
}

exitWithError() {
  echo "ERROR: $*" >&2
  exit 1
}

assertExists() {
  local declared_path="$1"
  local description="$2"
  local candidate="$REPO_ROOT/$declared_path"

  [[ -e "$candidate" ]] || exitWithError "$description does not exist: $declared_path"
}

assertFile() {
  local declared_path="$1"
  local description="$2"
  local candidate="$REPO_ROOT/$declared_path"

  [[ -f "$candidate" ]] || exitWithError "$description is not a file: $declared_path"
}

fileHash() {
  local file_path="$1"
  local hash

  IFS=' ' read -r hash _ < <(shasum -a 256 "$file_path")
  printf '%s\n' "$hash"
}

readFrontmatterName() {
  local skill_file="$1"
  local line
  local in_frontmatter=0
  local closed_frontmatter=0
  local found_name=0
  local frontmatter_name=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    if (( in_frontmatter == 0 )); then
      [[ "$line" == "---" ]] || return 1
      in_frontmatter=1
    elif [[ "$line" == "---" ]]; then
      closed_frontmatter=1
      break
    elif [[ "$line" == name:* ]]; then
      frontmatter_name="${line#name:}"
      frontmatter_name="${frontmatter_name#"${frontmatter_name%%[![:space:]]*}"}"
      frontmatter_name="${frontmatter_name%"${frontmatter_name##*[![:space:]]}"}"
      found_name=1
    fi
  done < "$skill_file"

  (( in_frontmatter == 1 && closed_frontmatter == 1 && found_name == 1 )) || return 1
  printf '%s\n' "$frontmatter_name"
}

validateManifestShape() {
  if ! jq -e '
    (type == "object") and
    (.schemaVersion | type == "number" and floor == . and . == 1) and
    (.release | type == "object") and
     (.release.ref | type == "string" and length > 0) and
     (.release.channel | type == "string" and (. == "stable" or . == "preview")) and
     ((.release.ref == "main" and .release.channel == "preview") or
       ((.release.ref | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) and .release.channel == "stable")) and
    (.skills | type == "object") and
    (.skills.authored | type == "array") and
    (.skills.authored | all(.[]; type == "object" and (.name | type == "string" and length > 0) and (.path | type == "string" and length > 0))) and
    (.skills.thirdParty | type == "array") and
    (.skills.thirdParty | all(.[]; type == "object" and (.name | type == "string" and length > 0) and (.source | type == "string" and length > 0) and (.sourceType | type == "string" and length > 0) and ((has("skillPath") | not) or (.skillPath | type == "string")) and (.commit | type == "string" and test("^[0-9a-f]{40}$")) and ((has("computedHash") | not) or (.computedHash | type == "string")))) and
    (.opencode | type == "object") and
    (.opencode.primary | type == "array") and
    (.opencode.primary | all(.[]; type == "string" and length > 0)) and
    (.opencode.subagents | type == "array") and
    (.opencode.subagents | all(.[]; type == "string" and length > 0)) and
    (.subagents | type == "object") and
    (.subagents.claude | type == "array") and
    (.subagents.claude | all(.[]; type == "string" and length > 0)) and
    (.subagents.codex | type == "array") and
    (.subagents.codex | all(.[]; type == "string" and length > 0)) and
     (.subagents.opencode | type == "array") and
     (.subagents.opencode | all(.[]; type == "string" and length > 0)) and
     (.nativeAssets | type == "array") and
     (.nativeAssets | all(.[];
       type == "object" and
       (.id | type == "string" and length > 0) and
       (.kind | type == "string" and (. == "agent" or . == "subagent")) and
       (.harness | type == "string" and (. == "opencode" or . == "claude-code" or . == "codex")) and
       (.source | type == "string" and length > 0) and
       (.projectTarget | type == "string" and length > 0) and
       (.globalTarget | type == "string" and length > 0) and
       (.releaseHash | type == "string" and test("^[0-9a-f]{64}$"))
     )) and
     (.configurationAssets | type == "array") and
     (.configurationAssets | all(.[];
       type == "object" and
       (.id | type == "string" and length > 0) and
       (.harness | type == "string" and (. == "opencode" or . == "claude-code" or . == "codex")) and
       (.source | type == "string" and length > 0) and
       (.projectTarget | type == "string" and length > 0) and
       ((.globalTarget == null) or (.globalTarget | type == "string" and length > 0)) and
       (.format | type == "string" and (. == "json" or . == "toml")) and
       (.mergeStrategy | type == "string" and (. == "deep-merge" or . == "permission-union")) and
       (.sourceHash | type == "string" and test("^[0-9a-f]{64}$"))
     )) and
     (.templates | type == "object") and
    (.templates.agentsMd | type == "string" and length > 0) and
    (.templates.roleDocs | type == "string" and length > 0) and
    (.templates.harnessConfig | type == "object") and
     (.templates.harnessConfig.claude | type == "string" and length > 0) and
     (.templates.harnessConfig.codex | type == "string" and length > 0) and
     (.templates.harnessConfig.opencode | type == "string" and length > 0) and
     (.documentation | type == "object") and
     (.documentation.agentsMd.source == "templates/AGENTS.md") and
     (.documentation.agentsMd.target == "AGENTS.md") and
     (.documentation.roleDocs.source == "templates/docs/agents/*") and
     (.documentation.roleDocs.target == "docs/agents/*") and
     (.documentation.claudeMdLink.source == "AGENTS.md") and
     (.documentation.claudeMdLink.target == "CLAUDE.md") and
     (.documentation.claudeMdLink.action == "relative-symlink")
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: missing or malformed required release fields (supported schemaVersion is 1)."
  fi
}

validateAuthoredSkills() {
  local declared_names
  local actual_names
  local name
  local declared_path
  local skill_file
  local frontmatter_name

  if ! jq -e '
    (.skills.authored | map(.name)) as $names |
    (.skills.authored | map(.path)) as $paths |
    (($names | unique | length) == ($names | length)) and
    (($paths | unique | length) == ($paths | length))
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: authored skill names and paths must be unique."
  fi

  [[ -d "$REPO_ROOT/skills" ]] || exitWithError "authored skills directory is missing: $REPO_ROOT/skills"
  declared_names="$(jq -r '.skills.authored | map(.name) | sort | .[]' "$MANIFEST")"
  actual_names="$(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \; | LC_ALL=C sort)"
  [[ "$declared_names" == "$actual_names" ]] || exitWithError "authored skill inventory does not match manifest (manifest: ${declared_names//$'\n'/, }; actual: ${actual_names//$'\n'/, })."

  while IFS=$'\t' read -r name declared_path; do
    skill_file="$REPO_ROOT/$declared_path/SKILL.md"
    [[ -d "$REPO_ROOT/$declared_path" ]] || exitWithError "authored skill path is not a directory: $declared_path"
    [[ -f "$skill_file" ]] || exitWithError "authored skill is missing SKILL.md: $declared_path"
    if ! frontmatter_name="$(readFrontmatterName "$skill_file")"; then
      exitWithError "authored skill has malformed frontmatter: $declared_path"
    fi
    [[ "$frontmatter_name" == "$name" ]] || exitWithError "authored skill frontmatter name does not match manifest: $declared_path"
  done < <(jq -r '.skills.authored[] | [.name, .path] | @tsv' "$MANIFEST")
}

compareAgentInventory() {
  local manifest_filter="$1"
  local agent_directory="$2"
  local extension="$3"
  local description="$4"
  local name
  local agent_file
  local agent_name
  local declared_names
  local actual_names

  declared_names="$(jq -r "$manifest_filter | sort | .[]" "$MANIFEST")"

  [[ -d "$agent_directory" ]] || exitWithError "$description directory is missing: $agent_directory"
  actual_names="$(
    while IFS= read -r -d '' agent_file; do
      agent_name="${agent_file##*/}"
      [[ "$agent_name" == *"$extension" ]] || exitWithError "$description has an unexpected file: $agent_file"
      printf '%s\n' "${agent_name%"$extension"}"
    done < <(find "$agent_directory" -mindepth 1 -maxdepth 1 -type f -print0) | LC_ALL=C sort
  )"
  [[ "$declared_names" == "$actual_names" ]] || exitWithError "$description inventory does not match manifest."
}

validateNativeAgents() {
  compareAgentInventory '.opencode.primary' "$REPO_ROOT/agents/opencode/primary" '.md' 'OpenCode primary agent'
  compareAgentInventory '.opencode.subagents' "$REPO_ROOT/agents/opencode/subagents" '.md' 'OpenCode subagent'
  compareAgentInventory '.subagents.claude' "$REPO_ROOT/agents/claude" '.md' 'Claude subagent'
  compareAgentInventory '.subagents.codex' "$REPO_ROOT/agents/codex" '.toml' 'Codex subagent'
  compareAgentInventory '.subagents.opencode' "$REPO_ROOT/agents/opencode/subagents" '.md' 'OpenCode cross-harness subagent'
}

validateNativeAssets() {
  local source
  local declared_hash
  local actual_hash

  if ! jq -e '
    [(.opencode.primary[] | "opencode-primary:" + .),
     (.opencode.subagents[] | "opencode-subagent:" + .),
     (.subagents.claude[] | "claude-subagent:" + .),
     (.subagents.codex[] | "codex-subagent:" + .)] as $expected |
    (.nativeAssets | map(.id)) as $actual |
    (($actual | unique | length) == ($actual | length)) and
    (($expected | sort) == ($actual | sort))
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: nativeAssets IDs must exactly match the declared agent inventories."
  fi

  if ! jq -e '
    def pairs($assets; $field):
      ($assets | map([.source, .[$field]])) as $values |
      (($values | unique | length) == ($values | length));
    (.nativeAssets + .configurationAssets) as $assets |
    pairs($assets; "projectTarget") and pairs($assets; "globalTarget")
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: native and configuration source/target pairs must be unique."
  fi

  if ! jq -e '
    all(.nativeAssets[];
      if (.id | startswith("opencode-primary:")) then
        (.id | split(":")[1]) as $name |
        (.kind == "agent" and .harness == "opencode" and
         .source == ("agents/opencode/primary/" + $name + ".md") and
         .projectTarget == (".opencode/agents/" + $name + ".md") and
         .globalTarget == ("agent/" + $name + ".md"))
      elif (.id | startswith("opencode-subagent:")) then
        (.id | split(":")[1]) as $name |
        (.kind == "subagent" and .harness == "opencode" and
         .source == ("agents/opencode/subagents/" + $name + ".md") and
         .projectTarget == (".opencode/agents/" + $name + ".md") and
         .globalTarget == ("agent/" + $name + ".md"))
      elif (.id | startswith("claude-subagent:")) then
        (.id | split(":")[1]) as $name |
        (.kind == "subagent" and .harness == "claude-code" and
         .source == ("agents/claude/" + $name + ".md") and
         .projectTarget == (".claude/agents/" + $name + ".md") and
         .globalTarget == ("agents/" + $name + ".md"))
      elif (.id | startswith("codex-subagent:")) then
        (.id | split(":")[1]) as $name |
        (.kind == "subagent" and .harness == "codex" and
         .source == ("agents/codex/" + $name + ".toml") and
         .projectTarget == (".codex/agents/" + $name + ".toml") and
         .globalTarget == ("agents/" + $name + ".toml"))
      else false end
    )
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: native asset IDs, harnesses, sources, or targets are inconsistent."
  fi

  while IFS=$'\t' read -r source declared_hash; do
    assertFile "$source" 'native asset source'
    actual_hash="$(fileHash "$REPO_ROOT/$source")"
    [[ "$actual_hash" == "$declared_hash" ]] ||
      exitWithError "$MANIFEST: releaseHash does not match native asset source: $source"
  done < <(jq -r '.nativeAssets[] | [.source, .releaseHash] | @tsv' "$MANIFEST")
}

validateConfigurationAssets() {
  local source
  local declared_hash
  local actual_hash

  if ! jq -e '
    [
      {id: "claude-code:settings", harness: "claude-code", source: "templates/claude/settings.json", projectTarget: ".claude/settings.json", globalTarget: "settings.json", format: "json", mergeStrategy: "permission-union"},
      {id: "codex:config", harness: "codex", source: "templates/codex/config.toml", projectTarget: ".codex/config.toml", globalTarget: "config.toml", format: "toml", mergeStrategy: "deep-merge"},
      {id: "opencode:config", harness: "opencode", source: "templates/opencode/opencode.json", projectTarget: "opencode.json", globalTarget: "opencode.json", format: "json", mergeStrategy: "deep-merge"},
      {id: "opencode:model-profile:openai", harness: "opencode", source: "templates/opencode/models-openai.json", projectTarget: "opencode.json", globalTarget: "opencode.json", format: "json", mergeStrategy: "deep-merge"}
    ] as $expected |
    (.configurationAssets | map(del(.sourceHash)) | sort_by(.id)) == ($expected | sort_by(.id)) and
    ((.configurationAssets | map(.id) | unique | length) == (.configurationAssets | length))
  ' "$MANIFEST" >/dev/null; then
    exitWithError "$MANIFEST: configurationAssets must enumerate each supported harness configuration exactly once."
  fi

  while IFS=$'\t' read -r source declared_hash; do
    assertFile "$source" 'configuration asset source'
    actual_hash="$(fileHash "$REPO_ROOT/$source")"
    [[ "$actual_hash" == "$declared_hash" ]] ||
      exitWithError "$MANIFEST: sourceHash does not match configuration asset source: $source"
  done < <(jq -r '.configurationAssets[] | [.source, .sourceHash] | @tsv' "$MANIFEST")
}

validateTemplates() {
  local declared_path
  local harness

  declared_path="$(jq -r '.templates.agentsMd' "$MANIFEST")"
  assertExists "$declared_path" 'templates.agentsMd'
  declared_path="$(jq -r '.templates.roleDocs' "$MANIFEST")"
  assertExists "$declared_path" 'templates.roleDocs'
  for harness in claude codex opencode; do
    declared_path="$(jq -r --arg harness "$harness" '.templates.harnessConfig[$harness]' "$MANIFEST")"
    assertExists "$declared_path" "templates.harnessConfig.$harness"
  done
}

validateThirdPartySkills() {
  local mismatch

  if ! jq -e '
    (.skills | type == "object") and
    (.skills | all(to_entries[]; .value | type == "object" and (.source | type == "string" and length > 0) and (.sourceType | type == "string" and length > 0) and ((has("skillPath") | not) or (.skillPath | type == "string")) and (.commit | type == "string" and test("^[0-9a-f]{40}$")) and ((has("computedHash") | not) or (.computedHash | type == "string"))))
  ' "$SKILLS_LOCK" >/dev/null; then
    exitWithError "$SKILLS_LOCK: missing or malformed skill lock entries."
  fi

  if ! mismatch="$(jq -nr --slurpfile manifest "$MANIFEST" --slurpfile lock "$SKILLS_LOCK" '
    def compare_optional($manifest_entry; $lock_entry; $field):
      if (($manifest_entry | has($field)) != ($lock_entry | has($field))) then
        "skill \($manifest_entry.name) differs in field presence: \($field)"
      elif ($manifest_entry | has($field)) and ($manifest_entry[$field] != $lock_entry[$field]) then
        "skill \($manifest_entry.name) has a different \($field)"
      else
        empty
      end;

    def compare_entry($name):
      ($manifest[0].skills.thirdParty | map(select(.name == $name)) | .[0]) as $manifest_entry |
      $lock[0].skills[$name] as $lock_entry |
      if $manifest_entry.source != $lock_entry.source then
        "skill \($name) has a different source"
      elif $manifest_entry.sourceType != $lock_entry.sourceType then
        "skill \($name) has a different sourceType"
      else
        ["skillPath", "commit", "computedHash"][] as $field |
        compare_optional($manifest_entry; $lock_entry; $field)
      end;

    ($manifest[0].skills.thirdParty | map(.name) | sort) as $manifest_names |
    ($lock[0].skills | keys | sort) as $lock_names |
    if $manifest_names != $lock_names then
      error("skill name sets differ (manifest: \($manifest_names | join(", ")); lock: \($lock_names | join(", ")))" )
    else
      ([$lock_names[] as $name | compare_entry($name)] | map(select(. != null)) | .[0]) as $mismatch |
      if $mismatch == null then true else error($mismatch) end
    end
  ' 2>&1)"; then
    exitWithError "skills.thirdParty does not match $SKILLS_LOCK: $mismatch"
  fi
}

[[ -f "$MANIFEST" ]] || exitWithError "release manifest does not exist: $MANIFEST"
[[ -f "$SKILLS_LOCK" ]] || exitWithError "skill lockfile does not exist: $SKILLS_LOCK"

validateManifestShape
validateAuthoredSkills
validateNativeAgents
validateNativeAssets
validateConfigurationAssets
validateTemplates
validateThirdPartySkills
echo "PASS: release manifest is valid."
