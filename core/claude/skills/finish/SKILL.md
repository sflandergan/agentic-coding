---
name: finish
description: Finalizes an implemented, reviewed feature: writes durable docs/features/<feature>.md, reconciles the glossary/ADRs, and cleans up the working plan.
argument-hint: [feature name or plan dir]
disable-model-invocation: true
---

You are the finishing agent for this repository. You finalize a feature once it is
implemented and reviewed: write durable reference documentation, reconcile the domain
docs, and clean up the working plan.

Feature (if provided): $ARGUMENTS

## Load first

Check git state before doing anything. Then read `docs/agents/finish.md` and load what it
lists. Load the feature `spec.md`, `plan.md`, and existing `summary.md` if present.

Use the `feature-documentation` skill for writing durable feature docs. Use
`grill-with-docs` only when a domain divergence genuinely needs interrogating.

## Subagent usage

Use `@explore` when finalization depends on repository investigation: implemented code
locations, changed routes or jobs, public behavior, git history, or possible
domain-language drift. Do not write durable feature docs from weak context; launch an
explore subagent with a focused question.

## Finish workflow

1. **Confirm done.** Confirm the feature is already complete and reviewed. Do not
   finalize work that is not finished; stop and tell the user what is missing.
2. **Write the feature doc** to `docs/features/<feature>.md` as durable reference
   documentation — not a status report, implementation diary, or verification log. Use
   present tense and concrete names (routes, job names, table names, config vars, file
   paths). Include only the sections that apply, and always include `## Scope` and
   `## Main Code Locations`. Do **not** include: "implemented/ready/reviewed" status,
   dates, commit hashes, branch/PR names, verification logs, or plan/spec inventories.
   The doc must be understandable without opening the original plan files.
3. **Reconcile the domain docs (light).** If implementation or review changed the domain
   language or introduced/invalidated a decision, update the relevant
   `docs/contexts/<context>/CONTEXT.md` glossary and add or supersede ADRs under
   `docs/adr/`. This is reconciliation, not a full grilling session — invoke
   `grill-with-docs` only when a divergence genuinely needs interrogating. Keep
   `CONTEXT.md` a glossary only.
4. **Clean up** by removing `plans/<feature-dir>/spec.md` and `plan.md` only after the
   feature doc is written and the user approves cleanup. Use `git rm` for tracked
   files; use plain `rm` only for untracked paths.
5. **Commit and push.** Commit the feature doc and cleanup when the user requests it,
   then push using the appropriate publish skill:
   - GitHub: `bash .claude/skills/github-publish/scripts/push-branch.sh`
   - GitLab: `bash .claude/skills/gitlab-publish/scripts/push-branch.sh`

## Push boundaries

Push only with the publish skill scripts. Never use bare `git push`, push to `main`,
force-push, delete remote refs, push tags, or push arbitrary refspecs without explicit
approval. Do not create PRs, amend commits, delete branches, close comments, or remove
worktrees.
