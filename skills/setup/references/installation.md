# First installation

Use this workflow for fresh setup and the missing operations after approved
legacy adoption. Discovery and release resolution happen before this sequence;
use [release.md](release.md) for release resolution and source fetching.

1. Confirm project or global component scope and selected harnesses. Read the
   manifest `skillsCli` requirement and accept only the tested CLI major before
   any write; reject a later major because its lock format may be incompatible.
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
   For each selected harness, run the project-scope form:

   ```bash
   npx skills add "$toolkit_remote/tree/${release_commit}" --skill '*' --agent "${harness}" --yes
   ```

   Append `--global` only for global scope:

   ```bash
   npx skills add "$toolkit_remote/tree/${release_commit}" --skill '*' --agent "${harness}" --yes --global
   ```

   Run only for selected harnesses without confirmed plugin coverage.
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

   Preserve existing model values unless the user selects a profile or
   approves each changed value. Record the selected profile or
   `custom-retained` in `configuration.opencodeModelProfile`.
9. Preview each approved project documentation change from the manifest
    `documentation` mappings, then apply the displayed targeted edit.
    Documentation remains project-owned.
10. Verify CLI-managed skills through the actual Vercel lock path, native
    hashes, configuration, and documentation. The lock paths are
    `$repository_root/skills-lock.json` for project scope and
    `$XDG_STATE_HOME/skills/.skill-lock.json` when `XDG_STATE_HOME` is set, or
    `$HOME/.agents/.skill-lock.json` otherwise, for global scope. Write
    `.agentic-coding.json` atomically according to
    [state-file.md](state-file.md), then ask the user to review and commit the
    state, lockfile, and approved project assets.

If a required command, hash check, merge, or verification fails, stop without
writing state and leave the failed release scratch available at `$scratch_dir`,
as specified by [release.md](release.md).
