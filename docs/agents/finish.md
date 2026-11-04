# Finish Agent

Role document for the `finish` skill in this toolkit repo. The skill is linked
into `.agents/skills/` and `.claude/skills/` for self-maintenance only.

## Load

- The target plan directory `plans/<feature-dir>/` from the caller (`spec.md`, `plan.md`, `tasks/`, `review-rounds/`)
- `AGENTS.md` — maintenance surface, sync invariants, git conventions
- `README.md` — inventory lists that must match the changed files

This repo has no feature maps, context glossaries, or ADRs. Step 2 of the skill
reduces to the sync-invariant check below; do not create `docs/features/`,
`CONTEXT-MAP.md`, or `docs/adr/` here, and do not invoke `feature-documentation`
or `grill-with-docs`.

## Sync invariants to confirm in Step 2

Compare the final diff with the invariants in `AGENTS.md`:

- `README.md` agent and skill lists
- `manifest.json` inventories and declared paths
- the dot-mapping table
- lockfile scopes (`skills-lock.json` vs `core/skills-lock.json`)
- `.claude/skills/` symlinks and `.agents/skills/` symlinks

Repair drift in the same commit as the cleanup.

## Publication

Publish through the skill's `publish-and-ready.sh`, which delegates to the
`git-publish` skill. Do not use `git push` or `gh pr create` directly.

## Verify

Run fresh and read the output. Scope each command to the changed files.

- Bash scripts: `shellcheck <changed scripts>` and `bash -n <changed scripts>`
- Script behavior changes: smoke run against `.temp/`, then remove the scratch directory
- Skill script tests: `bats <skill>/test` for any skill whose scripts changed
- Prose, templates, agents, skills, README: `codespell <changed files>`
- Plugin changes under `.opencode/plugins/`: `cd .opencode && bun test ./plugins/mistral-3rd-party/test`
- Configuration: `jq -e . <changed json files>` and `opencode debug config`
- Consistency: README lists, `manifest.json`, lockfiles, dot-mapping, symlink resolution (`ls -la .agents/skills .claude/skills`)

Docs-only or comment-only changes after a clean rebase need only the `codespell`
and consistency checks.
