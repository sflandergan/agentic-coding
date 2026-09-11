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
<!-- TODO: Replace the scratch location below with the repository's own convention, e.g. an app-specific temp folder under /tmp with restricted permissions. -->
- Throwaway work goes below the repository's designated scratch location; clean up after use.

## Git Conventions

- Branches use `feature/`, `fix/`, or `chore/` prefixes with short kebab-case descriptions.
- Commits are concise, imperative, and focused on why.
- Keep commits scoped to one logical change.
- Do not add `Co-Authored-By` lines.

## Verification Baseline

Replace this section with the project's verification commands. A typical baseline:

- Docs-only or comment-only changes do not require workspace verification.
- Code changes in one package/app require `lint`, `typecheck`, `test`, and any project-documented integration tests before handoff.
- Runtime behavior, config, package-boundary, or cross-package changes also require `build`.
- Completed user flows with browser/UI coverage also require end-to-end tests.
- If the user explicitly requests narrower verification, follow that request and state what was not run.

## Dual Pipeline

This repository uses two complementary AI pipelines that share the same docs:

- **OpenCode agents** in `.opencode/agents/*.md` — invoked with `@agentname`.
- **Claude Code skills** in `.claude/skills/*/SKILL.md` — invoked with `/skillname`.

Both pipelines read the same loading contracts under `docs/agents/*` and the same reusable authored skills under `.agents/skills/*`. The shared context layer is:

- `CONTEXT-MAP.md` and `docs/contexts/*` — bounded contexts and glossaries.
- `docs/adr/*` — recorded architectural decisions.
- `docs/ARCHITECTURE.md`, `docs/CODING_GUIDELINES.md`, `docs/TESTING.md`, `docs/LOGGING.md` — area rules.

When a workflow change affects both pipelines, update both definitions in the same change and verify they remain aligned.

## Permissions

- Do not delete branches or remove worktrees.
- Do not force-push. The only exception is an explicitly authorized retained-head
  update through `git-publish` with `--existing-pr`, `--expected-head`, and
  `--head-branch`, which uses a fully qualified lease
  (`--force-with-lease=refs/heads/<head>:<expected-sha>`) and never falls back
  to bare `--force` or `-f`.
- All branch publication must go through
  `bash .agents/skills/git-publish/scripts/publish-branch.sh`.
  Never invoke `git push` or `gh pr create` directly.
- The UI-design workflow verifies presentation output via a target-owned preview adapter
  at `.agents/scripts/ui-design/preview.sh`. The toolkit does not supply this script.
  Permissions for `start`, `probe`, and `stop` are encoded in `.claude/settings.json`.
- The `implement-task` worker is a subagent dispatched by the `implement` controller.
  It edits only assigned files, runs role-defined verification, and returns a structured
  status report. It does not create PRs, push branches, or publish change requests.
- The `ui-design-task` worker is a subagent dispatched by the `ui-design` controller.
  It edits only presentation files within its owned scope and does not run tests,
  verification, or commits.

## Extending the Toolkit

To add a new stack overlay (e.g. Gradle, Go, Cargo):

1. Create `stacks/<name>/` with `AGENTS.md`, `opencode.json`, `claude/settings.json`, and `docs/agents/<role>.md` additions for the affected roles.
2. Update `scripts/init.sh` and `scripts/copy.sh` to include the new stack in their stack selection prompt.
3. Document the stack in the top-level `README.md`.
