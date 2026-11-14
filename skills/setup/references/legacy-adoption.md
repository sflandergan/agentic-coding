# Legacy adoption

Use this workflow when [discovery](discovery.md) finds recognizable toolkit
content without a usable `.agentic-coding.json`. Start with the candidate paths
from discovery, resolve the selected release, and fetch its archive so
`source_dir` is available. Validate the manifest with
[manifest-schema.md](manifest-schema.md).

## Classify candidates

Compare each candidate with the matching file under `source_dir`, or compare
its content with the manifest hash when the manifest identifies that asset.
Use these classifications exactly:

- **Exact:** the candidate bytes match the selected source or its manifest
  hash.
- **Modified:** the candidate has proven selected-release provenance and its
  bytes differ from the selected source or hash.
- **Unproven:** the candidate cannot be tied to the selected source or hash.

For every candidate, present a row containing its current path, selected
source, canonical target, classification, and the behavior-changing differences
defined in [conflicts.md](conflicts.md). Resolve modified and unproven
candidates through [conflicts.md](conflicts.md) immediately before their
affected write.

Repo-internal skills are never adoption candidates. The toolkit's
`.agents/skills/agent-planning`, `agent-implementation`, `agent-review`, and
`agent-verification` directories are self-maintenance assets, not manifest
assets. If a candidate path matches one, report it as unexpected non-manifest
content, propose removal with `npx skills remove --skill <name> --yes`
(appending `--global` for global scope), and do not add it to `managedAssets`.

Approve each exact candidate before adopting it. Adoption leaves its bytes in
place and adds the candidate's `assetId`, harness, scope, canonical target, and
selected `releaseHash` to `managedAssets` in the state written under
[state-file.md](state-file.md). It does not rewrite the candidate.

List obsolete legacy links and paths as explicit retirement proposals with
their affected targets and replacement, if any. Apply removal only after
approval; never remove them as a side effect of adoption.

After classification and approved adoption decisions, run the missing
operations in [installation.md](installation.md). Legacy adoption does not
require an existing Vercel lockfile; the installation workflow creates or
updates the lock path when a Vercel-managed skill is installed.
