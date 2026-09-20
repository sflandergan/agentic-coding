# Release handling

Use this sequence whenever setup needs release metadata or source files. The
`toolkit_remote` variable is defined by `SKILL.md` before this reference is
loaded.

1. Check the required tools before writing dependent files:

   ```bash
   command -v git curl jq tar node npx mktemp
   node --version
   npx skills --version
   ```

   Read the selected manifest's declared Node.js and skills CLI constraints
   and compare them with those versions. Stop before dependent writes when a
   required tool is missing or a constraint is not satisfied.

2. Resolve the requested release once. `latest` selects the highest semantic
   version tag on the stable channel, an exact semantic-version tag must
   exist, and `main` resolves the preview branch `refs/heads/main`:

   ```bash
   temp_root="${TMPDIR:-${TMP:-/tmp}}"
   scratch_dir="$(mktemp -d "${temp_root%/}/agentic-coding.XXXXXX")" || {
     printf 'ERROR: unable to create release scratch directory below %s\n' "$temp_root" >&2
     exit 1
   }
   release_path="$scratch_dir/release.json"
   bash scripts/resolve-release.sh "$toolkit_remote" "$channel" "$requested_ref" "$release_path"
   ```

3. Read the resolver output and require a user-facing `ref`, a `stable` or
   `preview` `channel`, and a 40-character hexadecimal `commit`:

   ```bash
   jq -e '
     (.ref | type == "string" and length > 0) and
     (.channel == "stable" or .channel == "preview") and
     (.commit | type == "string" and test("^[0-9a-fA-F]{40}$"))
   ' "$release_path"
   release_ref="$(jq -r '.ref' "$release_path")"
   release_channel="$(jq -r '.channel' "$release_path")"
   release_commit="$(jq -r '.commit' "$release_path")"
   ```

4. Fetch only the selected release metadata into the generated scratch directory:

   ```bash
   manifest_path="$scratch_dir/manifest.json"
   bash scripts/fetch-release-manifest.sh \
     "$toolkit_remote" "$release_ref" "$release_channel" "$release_commit" "$manifest_path"
   ```

5. Present `ref`, `channel`, `commit`, requested scope, selected harnesses,
   and the manifest's proposed authored, third-party, native, and template
   components. Ask for approval before fetching or writing release assets.

6. After approval, fetch the archive at the same immutable commit. Do not run
   the resolver again during this setup run:

   ```bash
   source_dir="$scratch_dir/source"
   bash scripts/fetch-release-assets.sh \
     "$toolkit_remote" "$release_commit" "$manifest_path" "$source_dir"
   ```

7. After all approved operations and state verification succeed, remove only the
   generated scratch directory:

   ```bash
   rm -rf -- "$scratch_dir"
   ```

   If any operation fails, leave `$scratch_dir` intact and report its exact
   value so the user can recover or inspect it.
