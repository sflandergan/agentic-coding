# Upgrade, repair, and reconfiguration

Use this workflow for a managed upgrade, repair, or reconfiguration. Keep the
installed release in place until the required operations and final verification
succeed.

## Read state and resolve the release

1. Require a clean tree and read the immutable installed release, actual CLI
   lock state, plugin inventory, and native hashes before proposing changes:

   ```bash
   test -z "$(git status --porcelain)"
   repository_root="$(git rev-parse --show-toplevel)"
   cat "$repository_root/.agentic-coding.json"
   case "$(jq -r '.scope.skills' "$repository_root/.agentic-coding.json")" in
     project)
       lock_path="$repository_root/skills-lock.json"
       cat "$lock_path"
       ;;
     global)
       if [ -n "${XDG_STATE_HOME:-}" ]; then
         lock_path="$XDG_STATE_HOME/skills/.skill-lock.json"
       else
         lock_path="$HOME/.agents/.skill-lock.json"
       fi
       cat "$lock_path"
       ;;
     *)
       printf 'ERROR: unsupported scope.skills: %s\n' "$(jq -r '.scope.skills' "$repository_root/.agentic-coding.json")" >&2
       exit 1
       ;;
   esac
   lock_keys_before=""
   if [ -f "$lock_path" ]; then
     lock_keys_before="$(jq -r '.skills | keys[]' "$lock_path" | LC_ALL=C sort -u)"
   fi
   claude plugin list --json
   codex plugin list --json
   ```

   Read `release.ref`, `release.channel`, and `release.commit` from the state
   file. For every managed native target, resolve its project or harness-
   logical path as defined by [manifest-schema.md](manifest-schema.md), then
   compare the on-disk hash with its recorded `releaseHash`:

   ```bash
   test "$(bash scripts/hash-file.sh "$target")" = "$releaseHash"
   ```

2. Resolve the requested stable `latest`, exact semantic-version, or preview
   release through [release.md](release.md). Validate its manifest with
   [manifest-schema.md](manifest-schema.md), and use its immutable `commit` as
   `$commit`. Do not resolve the release again during this run.

## Refresh `setup` before ordinary work

After the resolved source is available, compare the selected `setup` hash with
the installed hash reported by the matching Vercel lock entry or plugin
metadata. Classify ownership and hash once, then use exactly one of these
branches:

- **Selected `setup` hash equals installed hash:** continue. For a
  **plugin-managed `setup` unchanged**, continue normally without requesting a
  plugin update.
- **Changed Vercel-managed `setup`:** install only `setup` from
  `$toolkit_remote/tree/$commit`, using every selected non-plugin `--agent` and
  the recorded project or global scope. For example:

  ```bash
  npx skills add "$toolkit_remote/tree/$commit" --skill setup --agent claude-code --agent opencode --agent codex --yes
  npx skills add "$toolkit_remote/tree/$commit" --skill setup --agent claude-code --agent opencode --agent codex --yes --global
  ```

  Remove flags for unselected harnesses and plugin-managed harnesses; use only
  the command matching the recorded scope. Preserve `.agentic-coding.json`,
  stop, and ask the user to review and commit the refreshed skill and lockfile
  before reinvoking setup.
- **Changed plugin-managed `setup`:** tell the user which plugin owns it and
  request that plugin's update. Preserve the release state, do not install a
  Vercel-managed copy, and stop.

## Ordinary upgrade order

After self-refresh permits continuation, show additions, updates, local
modifications, retirements, configuration changes, and documentation additions
with their owner, target, and current/resulting status. Use the difference
summary and choices in [conflicts.md](conflicts.md) without inventing another
conflict policy. Then perform these operations in order:

1. Resolve each collision immediately before its operation through
   [conflicts.md](conflicts.md).
2. Install the complete uncovered authored inventory from
   `$toolkit_remote/tree/$commit`. An uncovered skill is authored content not
   covered by a plugin for that harness. Use the scoped commands in
   [installation.md](installation.md); one project-scope example is:

   Follow the manifest-only installation rule and the mandatory `--list`
   preflight in [installation.md](installation.md) step 5. Do not build an
   install list by enumerating `.agents/skills/` or another agent skill
   directory; the wildcard command below is permitted only after the preflight
   confirms the four repo-internal names are absent.

   ```bash
   npx skills add "$toolkit_remote/tree/$commit" --skill '*' --agent "$harness" --yes
   ```

   Append `--global` only for global scope.
3. Install every selected third-party skill from
   `https://github.com/$source/tree/$entry_commit`, passing the manifest's
   `name` as the skill name and each selected harness. The project-scope form
   is:

   ```bash
   npx skills add "https://github.com/$source/tree/$entry_commit" --skill "$skill_name" --agent "$harness" --yes
   ```

   Append `--global` only for global scope. The source, entry commit, and
   named-skill fields are defined by [manifest-schema.md](manifest-schema.md).
4. Reconcile each approved native asset and verify its hash as specified by
   [installation.md](installation.md):

   ```bash
   mkdir -p "$(dirname "$target")"
   cp "$source_dir/$source" "$target"
   test "$(bash scripts/hash-file.sh "$target")" = "$releaseHash"
   ```

5. Remove retired assets only after approval for that specific target. Preserve
   retained assets and their warning data in the state format owned by
   [state-file.md](state-file.md).
6. Propose OpenCode model-profile changes separately from structural
   configuration changes. Follow the merge and profile choices in
   [installation.md](installation.md).
7. Add only approved missing documentation guidance. Keep documentation
   project-owned and follow its targeted-edit rules in
   [installation.md](installation.md).
8. Verify every category, the named CLI lock path using the non-manifest skill
   check in [installation.md](installation.md) step 10, native hashes,
   configuration, documentation, and retained outcomes. Write the new state
   atomically only after all required operations succeed, following
   [state-file.md](state-file.md). Ask the user to review and commit the
   resulting state, lockfile, and project assets.

Repair uses the installed immutable `release.ref`, `release.channel`, and
`release.commit` unless the user also approves an upgrade. Reconfiguration
changes only the chosen scope, harness, distribution, configuration, model, or
documentation fields. Declining an available upgrade does not stop repair or
reconfiguration.

## Failure and retry at each operation

Every network command retries once with the same arguments. This includes
release resolution and fetching owned by [release.md](release.md), Vercel CLI
skill installation, and third-party skill installation. A second failure
stops that operation's dependent operations, leaves the recorded release
unchanged, and does not substitute another release.

For categories completed before the failure, report their exact on-disk result:
paths written or removed, hashes, lock entries, configuration and
documentation status, and retained warnings. Give the command that retries or
repairs each completed category. Do not describe a partially changed
installation as unchanged. Keep `$scratch_dir` and report its path; remove
scratch data only after all operations and state verification succeed.
