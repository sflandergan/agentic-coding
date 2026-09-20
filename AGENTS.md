# AGENTS.md

Shared conventions for AI agents maintaining this toolkit repo. This file is loaded every session.

## What This Repo Is

A reusable agentic coding toolkit. The `skills/`, `agents/`, `templates/`, and
`stacks/` trees are source assets distributed to other repositories by the
setup skill; `scripts/init.sh` and `scripts/copy.sh` are deprecated transition
tools. There is no application code, no DDD contexts, and no test suite — only
markdown templates and bash scripts.

## Maintenance Surface

The files this repo's agents operate on:

- Authored skills under `skills/`
- Harness-native agents under `agents/`
- Markdown and harness templates under `templates/` and `stacks/`
- `README.md`
- `manifest.json`
- `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`
- `skills-lock.json` for this repo's self-maintenance skills
- `core/skills-lock.json` for third-party skills installed into target repos
- Deprecated `scripts/init.sh` (~325 lines), `scripts/copy.sh` (~618 lines)

## Dot-Mapping (Source → Target)

During the deprecation window, the scripts copy these source directories to
target paths:

| Source in repo | Target dot-directory |
|---|---|
| `templates/opencode/` + `agents/opencode/` | `.opencode/` |
| `templates/claude/` | `.claude/` |
| `templates/docs/` | `docs/` |
| `templates/AGENTS.md` | `AGENTS.md` |

## Canonical Sources + Stacks Dual-Maintenance

When modifying `templates/`, `agents/`, or `skills/`, check whether
`stacks/pnpm/` or `stacks/maven/` has an overlay for the same installed output.
Update stack overlays when a change affects stack-specific behavior, especially
when adding a new template or changing behavior that an overlay intentionally
customizes.

## Sync Invariants

These must stay consistent with the actual files:

- `README.md` agent/skill lists
- `manifest.json` inventories and declared paths
- The dot-mapping table above
- Agent file names in `agents/opencode/` vs what `templates/opencode/opencode.json` references
- Plugin manifest component paths vs canonical source files

## Skill Lockfile Scopes

The two lockfiles have different scopes and are not expected to match.

- `skills-lock.json` tracks remote skills installed in this repo for self-maintenance. Compare it against remote-sourced skill directories under `.agents/skills/`.
- `core/skills-lock.json` tracks remote skills installed into target repos by the Vercel `skills` CLI (and by the deprecated scripts during the transition). Compare it against the pinned third-party skills declared in `manifest.json`.

When updating skills, edit only the lockfile for the scope you changed.

## Skill Authoring

```yaml
---
name: skill-name          # lowercase, hyphen-separated, matches folder
description: Use when...  # required, third-person, front-load trigger keywords
user-invocable: false     # for skills only loaded by agents, not users
---
```

- Load and follow `writing-skills` and `test-driven-development` before creating or editing a skill.
- State each workflow as trigger, action, and observable result; include exact commands, paths, state changes, and failure behavior where only one implementation is safe.
- Give each rule one owner and link to it elsewhere. Required references are linked directly from `SKILL.md` and stay one level deep.
- Use one term for each concept, define it before use, and make user choices mutually exclusive.
- Shape verbose or incomplete output with a positive structure. Use prohibitions only for unsafe or disallowed behavior.
- Keep only information an agent needs to act. Put deterministic mechanics in tested scripts and say whether a script is executed or read.
- Test current behavior first, then the candidate skill with the same fresh-agent scenarios. Record the failures fixed and the passing evidence.

## Symlink Model

For target repositories, the setup skill installs skills through the Vercel
`skills` CLI. That CLI and an installed Claude Code or Codex plugin own their
respective skill distribution; setup does not treat a copied skill directory or
hand-written `.claude/skills/` symlink as the canonical source.

This repository's own runtime is unchanged: OpenCode reads self-maintenance
skills from `.agents/skills/<name>/SKILL.md`, and each local skill is symlinked
into `.claude/skills/<name>` with `ln -s ../../.agents/skills/<name>`. This
internal symlink model is for maintaining this toolkit, not for target-repo
installation.

## .temp/ Scratch Rule

All smoke runs and throwaway work goes in `.temp/`, never `/tmp`. Clean up after use. `.temp/` is gitignored.

## Git Conventions

- Work on a scoped branch, never directly on `main`.
- Branches use `feature/`, `fix/`, or `chore/` prefixes with short kebab-case descriptions.
- Commits are concise, imperative, and focused on why.
- Prefer `git mv` for moves/renames of tracked paths. Use `git rm` for removals of tracked paths.
- Use `scripts/publish-branch.sh` for branch publishing and PR creation so branch-safety checks are centralized.
- Keep branch deletion, worktree removal, and force-push operations under explicit human control.
- Write commits without `Co-Authored-By` trailers.

## Verification Baseline

For changes in this repo:

- Markdown-only changes require format-specific validation: agent frontmatter, skill frontmatter, README inventory sync, and link/symlink spot checks as applicable.
- Bash script changes require `shellcheck` and `bash -n`.
- Script changes also require a smoke run against `.temp/`.
- Agent/skill/config changes require consistency checks: README lists, lockfiles, dot-mapping, and symlink integrity.
