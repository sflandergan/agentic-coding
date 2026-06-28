# AGENTS.md

Shared conventions for AI agents maintaining this toolkit repo. This file is loaded every session.

## What This Repo Is

A reusable agentic coding toolkit. The `core/` and `stacks/` trees are **templates** installed into other repos by `scripts/init.sh` and `scripts/copy.sh`. There is no application code, no DDD contexts, and no test suite — only markdown templates and bash scripts.

## Maintenance Surface

The files this repo's agents operate on:

- Markdown templates under `core/` and `stacks/`
- `README.md`
- `skills-lock.json` for this repo's self-maintenance skills
- `core/skills-lock.json` for the toolkit installed into target repos
- `scripts/init.sh` (~325 lines), `scripts/copy.sh` (~618 lines)

## Dot-Mapping (Source → Target)

The scripts copy these source directories to target dot-directories:

| Source in repo | Target dot-directory |
|---|---|
| `core/opencode/` | `.opencode/` |
| `core/claude/` | `.claude/` |
| `core/agents/` | `.agents/` |
| `core/docs/` | `docs/` |

## Core + Stacks Dual-Maintenance

When modifying a file under `core/`, check whether `stacks/pnpm/` or `stacks/maven/` has an overlay for the same file. Update stack overlays when the change affects stack-specific installed output, especially when adding a new template or changing behavior that an overlay intentionally customizes.

## Sync Invariants

These must stay consistent with the actual files:

- `README.md` agent/skill lists
- The dot-mapping table above
- Agent file names in `.opencode/agents/` vs what `opencode.json` references

## Skill Lockfile Scopes

The two lockfiles have different scopes and are not expected to match.

- `skills-lock.json` tracks remote skills installed in this repo for self-maintenance. Compare it against remote-sourced skill directories under `.agents/skills/`.
- `core/skills-lock.json` tracks remote skills installed into target repos by `scripts/init.sh` and `scripts/copy.sh`. Compare it against the skills the toolkit templates install for downstream projects.

When updating skills, edit only the lockfile for the scope you changed.

## SKILL.md Frontmatter Conventions

```yaml
---
name: skill-name          # lowercase, hyphen-separated, matches folder
description: Use when...  # required, third-person, front-load trigger keywords
user-invocable: false     # for skills only loaded by agents, not users
---
```

## Symlink Model

OpenCode is configured to read skills from `.agents/skills/<name>/SKILL.md`. Each skill is symlinked into `.claude/skills/<name>` (`ln -s ../../.agents/skills/<name>`) so Claude Code also sees it. This matches the model `copy.sh` uses for authored skills.

## Skill Boundary Rule

Workflow-facing files (SKILL.md bodies, agent instructions, README workflow sections) must instruct agents to **use skills by name** — for example `git-publish`, `change-request-publish`, `change-request-comments`, or `issue-tracker` — rather than exposing internal implementation paths.

**Do not** reference internal script paths like `.agents/skills/<skill>/scripts/*.sh` or `.claude/skills/<skill>/scripts/*.sh` in workflow-facing content. Boundary-skill implementation details may live in that skill's own scripts or sibling `README.md`; keep the `SKILL.md` focused on the invocation contract.

Agent frontmatter and Claude settings may grant script permissions, but body instructions should stay at the skill level, not the script level.

**Provider-boundary language:** Provider-specific CLI details (`gh`, `glab`, provider comment scripts) belong only in provider or boundary skills, not in generic workflow files. Generic workflow files should remain provider-agnostic.

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
