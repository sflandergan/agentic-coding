# First installation

Use this workflow for fresh setup and the missing operations after approved
legacy adoption. Discovery and release resolution happen before this sequence;
use [release.md](release.md) for release resolution and source fetching.

1. Confirm project or global component scope and selected harnesses. Record the
   confirmed skill scope as `skill_scope` (`project` or `global`). Read the
   manifest `skillsCli` requirement and accept only the tested CLI major before
   any write; reject a later major because its lock format may be incompatible.

   Resolve the matching lock path and snapshot existing lock keys before any
   install:

   ```bash
   case "$skill_scope" in
     project)
       lock_path="$repository_root/skills-lock.json"
       ;;
     global)
       if [ -n "${XDG_STATE_HOME:-}" ]; then
         lock_path="$XDG_STATE_HOME/skills/.skill-lock.json"
       else
         lock_path="$HOME/.agents/.skill-lock.json"
       fi
       ;;
     *)
       printf 'ERROR: unsupported skill scope: %s\n' "$skill_scope" >&2
       exit 1
       ;;
   esac

   lock_keys_before=""
   if [ -f "$lock_path" ]; then
     lock_keys_before="$(jq -r '.skills | keys[]' "$lock_path" | LC_ALL=C sort -u)"
   fi
   ```
2. Run both plugin inventory commands:

   ```bash
   claude plugin list --json
   codex plugin list --json
   ```

   Treat authored skills as plugin-managed for a harness only when the
   installed metadata identifies the `agentic-coding` plugin and exposes the
   corresponding authored inventory. Otherwise ask before excluding those
   skills from Vercel CLI installation.
3. Show the authored and third-party skill inventories, native assets,
   documentation contributions, target paths, configuration merges, OpenCode
   model choice, and collisions. Show the selected release `ref`, `channel`,
   and `commit` as resolved by [release.md](release.md).
4. Resolve each collision through [conflicts.md](conflicts.md) immediately
   before writing the affected asset.
5. Install every uncovered authored skill from the selected immutable commit.
   The only installable skills are the manifest's `skills.authored` and
   `skills.thirdParty` inventories. Do not build an install list by enumerating
   a directory under `skills/`, `.agents/skills/`, `.claude/skills/`, or
   another agent skill directory; install only manifest-declared names. The
   `--skill '*'` command below is permitted only after the preflight confirms
   the four repo-internal names are absent. The toolkit's repo-internal
   `.agents/skills/agent-*` skills declare `metadata.internal: true`; the Vercel
   CLI hides them from discovery and excludes them from `--skill '*'` when the
   selected release marks them and the installed CLI satisfies
   `requirements.skillsCli`. Ensure `INSTALL_INTERNAL_SKILLS` is unset or `0`
   for the preflight and install.

   Run the discovery preflight against the selected immutable release before
   any install:

   ```bash
   unset INSTALL_INTERNAL_SKILLS
   listing="$(NO_COLOR=1 npx skills add "$toolkit_remote/tree/${release_commit}" --list)"
   printf '%s\n' "$listing"
   ```

   Stop before installing when the listing includes `agent-planning`,
   `agent-implementation`, `agent-review`, or `agent-verification`. That result
   means the selected release does not mark its repo-internal skills with
   `metadata.internal: true`, or the installed CLI does not satisfy
   `requirements.skillsCli`. Select a release and CLI that meet both
   conditions.

   For each selected harness, run the project-scope form:

   ```bash
   npx skills add "$toolkit_remote/tree/${release_commit}" --skill '*' --agent "${harness}" --yes
   ```

   Append `--global` only for global scope:

   ```bash
   npx skills add "$toolkit_remote/tree/${release_commit}" --skill '*' --agent "${harness}" --yes --global
   ```

   Run only for selected harnesses without confirmed plugin coverage.

   The preflight above is mandatory; do not run the wildcard install command
   when it lists any of the four names.
6. Install every third-party manifest entry from its immutable source tree and
   named skill. For each selected harness, use the matching scope form:

   ```bash
   npx skills add "https://github.com/${source}/tree/${entry_commit}" --skill "${skill_name}" --agent "${harness}" --yes
   npx skills add "https://github.com/${source}/tree/${entry_commit}" --skill "${skill_name}" --agent "${harness}" --yes --global
   ```

   Use the first form for project scope and the second for global scope. Use
   the manifest `source`, `commit` (as `entry_commit`), and `name` fields.
7. Reconcile each approved native asset from `source_dir`, the extracted
   selected-release source from [release.md](release.md), to its manifest
   `nativeAssets` target. Copy `$source_dir/$source` to the approved
   `projectTarget`, or resolve the logical `globalTarget` against the harness
   home defined by [manifest-schema.md](manifest-schema.md). For every applied
   file, create its parent directory, copy the source, and compare its hash
   with the manifest `releaseHash`:

   ```bash
   mkdir -p "$(dirname "$target")"
   cp "$source_dir/$source" "$target"
   test "$(bash scripts/hash-file.sh "$target")" = "$releaseHash"
   ```

8. Structurally merge each approved harness configuration contribution from
   `configurationAssets` using its declared merge strategy. Preserve unrelated
   keys. Parse the existing target first and reject invalid configuration
   instead of replacing it. Apply structural agent and permission additions
   independently from model changes.
   When OpenCode is selected, show existing and proposed model values and offer
   these profiles:

   - `opencode-go`: base `templates/opencode/opencode.json`.
   - `opencode-go-openai`: the base profile plus
     `templates/opencode/models-openai.json`.
   - `opencode-go-mistral`: the base profile plus
     `templates/opencode/models-mistral.json`; also approve the three
     Mistral 3rd-party compatibility plugin assets from `nativeAssets`, because OpenCode V1 needs
     the plugin's request adapter for Mistral-hosted models. Setup lists the
     assets with the profile but does not enforce the pairing.

   Preserve existing model values unless the user selects a profile or
   approves each changed value. Record the selected profile or
   `custom-retained` in `configuration.opencodeModelProfile`.
9. Preview each approved project documentation change from the manifest
    `documentation` mappings, then apply the displayed targeted edit.
    Documentation remains project-owned.
10. Verify CLI-managed skills through the actual Vercel lock path, native
    hashes, configuration, and documentation.

    Read the lock and fail only for repo-internal skills or for newly added
    entries that are absent from the manifest's authored and third-party
    inventories. Do not treat a pre-existing lock entry from another source as
    a toolkit asset.

    ```bash
    if [ -f "$lock_path" ]; then
      installed_skills="$(jq -r '.skills | keys[]' "$lock_path" | LC_ALL=C sort -u)"
    else
      installed_skills=""
    fi
    manifest_skills="$(
      jq -r '.skills.authored[].name, .skills.thirdParty[].name' "$manifest_path" \
        | LC_ALL=C sort -u
    )"
    repo_internal_skills=$'agent-implementation\nagent-planning\nagent-review\nagent-verification'
    unexpected=""
    while IFS= read -r installed; do
      [ -n "$installed" ] || continue
      if grep -Fxq "$installed" <<< "$repo_internal_skills"; then
        unexpected+="$installed"$'\n'
      elif ! grep -Fxq "$installed" <<< "$lock_keys_before" &&
           ! grep -Fxq "$installed" <<< "$manifest_skills"; then
        unexpected+="$installed"$'\n'
      fi
    done <<< "$installed_skills"
    if [ -n "$unexpected" ]; then
      printf 'ERROR: Vercel lock contains unexpected skill(s):\n%s' "$unexpected" >&2
      exit 1
    fi
    ```

    If the check fails, stop before writing state. Report each unexpected name
    with its installed path and the exact
    `npx skills remove --skill <name> --yes` command, appending `--global` for
    global scope; remove only after approval. A pre-existing lock entry from
    another source is not a toolkit violation and must be left untouched.

    Write `.agentic-coding.json` atomically according to
    [state-file.md](state-file.md), then ask the user to review and commit the
    state, lockfile, and approved project assets.

If a required command, hash check, merge, or verification fails, stop without
writing state and leave the failed release scratch available at `$scratch_dir`,
as specified by [release.md](release.md).
