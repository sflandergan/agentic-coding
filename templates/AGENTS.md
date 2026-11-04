# AGENTS.md

This file is the minimal entry point for AI agents working in this repository. Keep it short because AI agents load it for every session.

## Project Context

This is a placeholder project description. Replace this section with a one-paragraph summary of the project's purpose, primary users, and core domain.

## Always Follow

- Work on a scoped branch, never directly on `main`.
- Do not revert, overwrite, or clean up changes you did not make unless the user explicitly asks.
- Prefer the smallest correct change over broad refactors.
- Prefer `git rm` over raw `rm` for tracked files.
- Workers edit only the files their task or role assigns; controllers own dispatch and acceptance.
- When a skill or role document tells you to dispatch the Explore subagent, treat that as the user's explicit request to use it.
<!-- TODO: Replace the scratch location below with the repository's own convention, e.g. an app-specific temp folder under /tmp with restricted permissions. -->
- Throwaway work goes below the repository's designated scratch location; clean up after use.

## Git Conventions

- Branches use `feature/`, `fix/`, or `chore/` prefixes with short kebab-case descriptions.
- Commits are concise, imperative, and focused on why.
- Keep commits scoped to one logical change.
- Do not add `Co-Authored-By` lines.

## Issue Tracking

Replace this section with where the project tracks issues and how agents read them, for example `gh issue view <number>` for GitHub issues.

## Verification Baseline

Replace this section with the project's verification commands. A typical baseline:

- Docs-only or comment-only changes do not require workspace verification.
- Code changes in one package/app require `lint`, `typecheck`, `test`, and any project-documented integration tests before handoff.
- Runtime behavior, config, package-boundary, or cross-package changes also require `build`.
- Completed user flows with browser/UI coverage also require end-to-end tests.
- If the user explicitly requests narrower verification, follow that request and state what was not run.

## Permissions

- Do not delete branches or remove worktrees.
- Use the `git-publish` skill for branch publication instead of invoking `git push` directly.

## Extending the Toolkit

To add a new stack overlay (e.g. Gradle, Go, Cargo):

1. Create `stacks/<name>/` with `AGENTS.md`, `opencode.json`, `claude/settings.json`, and `docs/agents/<role>.md` additions for the affected roles.
2. Update `scripts/init.sh` and `scripts/copy.sh` to include the new stack in their stack selection prompt.
3. Document the stack in the top-level `README.md`.
