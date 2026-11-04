# Release handling

Use this sequence whenever setup needs release metadata or source files. The
`toolkit_remote` variable is defined by `SKILL.md` before this reference is
loaded.

1. Check the required tools before writing dependent files:

   ```bash
   for required_tool in git jq tar node npx mktemp; do
     command -v "$required_tool" >/dev/null 2>&1 || {
       printf 'ERROR: required tool is missing: %s\n' "$required_tool" >&2
       exit 1
     }
   done
   node --version
   npx skills --version
   ```

   `fetch-release.sh` checks for `shasum` or `sha256sum` itself. Read the
   selected manifest's declared Node.js and skills CLI constraints and
   compare them with those versions. Stop before dependent writes when a
   required tool is missing or a constraint is not satisfied.

2. Generate a dedicated scratch directory and fetch the requested release
   metadata and manifest:

   ```bash
   temp_root="${TMPDIR:-${TMP:-/tmp}}"
   scratch_dir="$(mktemp -d "${temp_root%/}/agentic-coding.XXXXXX")" || {
     printf 'ERROR: unable to create release scratch directory below %s\n' "$temp_root" >&2
     exit 1
   }
   bash scripts/fetch-release.sh manifest \
     "$toolkit_remote" "$requested_ref" "$scratch_dir"
   ```

3. `fetch-release.sh manifest` has already validated the metadata; read it
   into variables:

   ```bash
   release_path="$scratch_dir/release.json"
   manifest_path="$scratch_dir/manifest.json"
   clone_dir="$scratch_dir/clone"
   source_dir="$scratch_dir/source"
   release_ref="$(jq -r '.ref' "$release_path")"
   release_channel="$(jq -r '.channel' "$release_path")"
   release_commit="$(jq -r '.commit' "$release_path")"
   ```

4. Present `ref`, `channel`, `commit`, requested scope, selected harnesses,
   and the manifest's proposed authored, third-party, native, and template
   components. Ask for approval before fetching or writing release assets.

5. After approval, export the pinned tree from the same clone. Do not clone
   again or select another release during this setup run:

   ```bash
   bash scripts/fetch-release.sh source "$scratch_dir"
   ```

6. After all approved operations and state verification succeed, remove only the
   generated scratch directory:

   ```bash
   rm -rf -- "$scratch_dir"
   ```

   If any operation fails, leave `$scratch_dir` intact and report its exact
   value so the user can recover or inspect it. If a fetch fails on
   authentication, tell the user to configure git credentials for the toolkit
   remote and retry the setup run; do not write `.agentic-coding.json`.
