# Release manifest schema

The toolkit release manifest is `manifest.json` at the release root. It is the
single inventory used by setup to select authored assets, pinned third-party
skills, harness integrations, and retired content. Setup must reject a
manifest whose `schemaVersion` is unsupported before applying any category.

## Fields

- **`schemaVersion`** — required positive integer describing the manifest
  format. This release supports schema version `1`. A selected release with a
  different or malformed value is unsupported and must be refused.
- **`release`** — required object with `ref` and `channel` (`stable` or
  `preview`). The preview release uses `ref: "main"`; a stable release uses a
  `vMAJOR.MINOR.PATCH` semantic-version tag. The selected ref must agree with
  the release information presented to the user. The resolver, not this file,
  supplies the immutable commit recorded in state.
- **`skills.authored`** — array of objects with a skill `name` and repository
  `path`. These are toolkit-authored skills and are resolved from the declared
  path, such as `skills/brainstorm`. The path must stay inside the selected
  release and contain the expected skill file.

  These entries and the pinned third-party entries are the only skills setup
  may install. The toolkit's `.agents/skills/` self-maintenance skills are not
  manifest assets: `agent-planning`, `agent-implementation`, `agent-review`,
  and `agent-verification` declare `metadata.internal: true` and must never be
  installed or replaced in a target repository.
- **Third-party skills in `skills`** — the pinned skill descriptors. Each
  descriptor has a `name`, `source`, `sourceType`, and required `commit`. The
  commit is a 40-character lowercase hexadecimal revision used to construct
  the GitHub tree URL passed to `npx skills add`; descriptors may also include
  a `skillPath` and `computedHash`. These fields are installation provenance,
  not permission to copy a fetched checkout.
- **`opencode`** — object containing the OpenCode `primary` (always empty; the build agent runs workflow skills) and `subagents`
  name lists. These names resolve to the corresponding harness-native agent
  assets in the release.
- **`subagents`** — per-harness name lists for `claude`, `codex`, and
  `opencode`.
- **`nativeAssets`** — the complete release-hash-managed inventory of native
  agents and OpenCode plugin files. Each entry has an ID, `kind` (`agent`,
  `subagent`, or `plugin`), `harness`, repository-relative `source`, project
  and logical global targets, and a lowercase SHA-256 `releaseHash` of that
  source. Worker agents use IDs `opencode-subagent:<name>`,
  `claude-subagent:<name>`, or `codex-subagent:<name>`. Plugin entries ship
  harness runtime files that are not agents; the Mistral 3rd-party compatibility plugin
  entries use IDs `opencode-plugin:mistral-3rd-party`,
  `opencode-plugin:mistral-3rd-party-compatibility`, and
  `opencode-plugin:mistral-3rd-party-readme`, whose project targets mirror their
  sources under `.opencode/plugins/`.
- **`configurationAssets`** — the complete inventory of harness configuration
  contributions. Each entry has an ID, harness, source, project/global
  targets, format, merge strategy, and lowercase SHA-256 `sourceHash`.
  `claude-code:settings` uses `permission-union`; `codex:config`,
  `opencode:config`, `opencode:model-profile:openai`, and
  `opencode:model-profile:mistral` use `deep-merge`.
  Configuration hashes protect only approved managed contributions, not the
  rest of a project-owned configuration file.
- **`templates`** — paths for `agentsMd`, role documents, and the Claude Code,
  Codex, and OpenCode harness configuration contributions. These are source
  paths for approved reconciliation, not a license to overwrite project-owned
  files.
- **`documentation`** — project-owned documentation mappings. The manifest
  maps `templates/AGENTS.md` to `AGENTS.md` and
  `templates/docs/agents/*` to `docs/agents/*`. When Claude Code is selected
  and `CLAUDE.md` is absent, setup may create the relative symlink
  `CLAUDE.md` → `AGENTS.md`; an existing file or link is preserved unless the
  user approves a change. Documentation is never release-hash managed.
- **`assetHashes`** — optional map of release asset identifiers to hashes. Use
  it to verify managed non-skill assets and to establish later conflict
  provenance.
- **`requirements`** — required runtime versions, including the Node.js and
  `skills` CLI constraints. Check requirements before applying a dependent
  operation.
- **`pluginManifests`** — harness-to-manifest paths for plugin coverage, such
  as Claude Code and Codex. Validate an installed plugin manifest before
  excluding its covered authored skills from Vercel CLI management.
- **`retired`** — array of asset or skill identifiers no longer shipped, such
  as the former `opencode-primary:<name>` agents whose project target was
  `.opencode/agents/<name>.md`. Present these as proposed removals and obtain
  approval before deleting anything. `retired` entries are bare asset
  identifiers without target paths. Setup derives a removal target only for
  identifiers this schema defines (`opencode-primary:<name>`); retiring
  `opencode-plugin:*` identifiers requires a target-derivation rule added in
  the release that retires them.

Native and configuration sources must exist in the selected release. `agent`
and `subagent` native asset IDs exactly cover the OpenCode, Claude Code, and
Codex worker inventories; `plugin` native assets are listed separately, with no
duplicate IDs or source/target pairs. Project targets must use the harness
paths declared by the asset, and logical global targets are relative to the
harness home:

| Harness | Global home | Agent target | Configuration target |
|---|---|---|---|
| Claude Code | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` | `agents/<name>.md` | `settings.json` |
| Codex | `${CODEX_HOME:-$HOME/.codex}` | `agents/<name>.toml` | `config.toml` |
| OpenCode | `${XDG_CONFIG_HOME:-$HOME/.config}/opencode` | `agent/<name>.md` | `opencode.json` |

Plugin native assets for OpenCode resolve their logical global targets under the
OpenCode `plugins/` directory, for example `plugins/mistral-3rd-party.ts`.

OpenCode worker agents, including the `explore` override of the built-in
agent, use the `agent/` global directory. Missing
required fields, invalid types, duplicate names, paths outside the release,
hash mismatches, or inconsistent release/channel data make the manifest
unusable. Unknown fields may be ignored only when the declared schema version
is compatible.

## Compatibility and self-refresh

The selected release must declare a supported schema version. A changed
`setup` skill is handled before ordinary reconciliation: install only the new
`setup` skill through `npx skills add`, make no release-state change, delete
the fetched checkout, and ask the user to reinvoke setup.

An unchanged setup skill may consume a newer manifest only when that manifest
explicitly declares a schema version compatible with this setup skill. A newer
unsupported schema always stops setup; it must not be interpreted using an
older schema or silently downgraded to `main`.

## Skill resolution

Resolve authored skills from each `skills.authored[].path`, but install them
through `npx skills add` rather than copying directories from the fetched
release. Resolve pinned third-party skills from their declared source and
pinning fields by constructing the GitHub tree URL from `source` and `commit`
and passing it to `npx skills add`. The source repository's skills lockfile
records third-party pins; those pins are mirrored in the manifest's
third-party skill inventory for release inventory purposes. Setup must not
create a second lockfile or overwrite a lockfile belonging to an unrelated
source.

For each harness, first resolve plugin coverage. An authored skill exposed by
an installed Claude Code or Codex plugin is plugin-managed for that harness;
exclude it from Vercel CLI installation and updates. Install only uncovered
authored skills and the pinned third-party skills assigned to that harness.

A repo-internal skill lives under the toolkit repository's `.agents/skills/`
directory, is absent from the manifest, and declares `metadata.internal: true`
in its frontmatter. Install only names from `skills.authored` and
`skills.thirdParty`. Do not build an install list by enumerating
`.agents/skills/`, `.claude/skills/`, or another agent skill directory; the
Vercel CLI wildcard is permitted only after the preflight in
[installation.md](installation.md) step 5 confirms the repo-internal names are
absent.
