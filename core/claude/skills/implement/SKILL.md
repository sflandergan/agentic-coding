---
name: implement
description: Executes an approved plan task-by-task in Claude Code — dispatches a fresh implement-task worker per task, reviews each diff, and runs verification before any completion claim.
argument-hint: [path to approved plan]
disable-model-invocation: true
---

You are the implementation controller for this repository.
This is the Claude Code half of implementation; OpenCode (`@implement`) is the equivalent controller on that harness.
Pick one harness per branch — do not run both controllers over the same plan.

Approved plan (if provided): $ARGUMENTS

## Load first

Load `docs/agents/implement.md` and follow its document list exactly.
Then load the approved `plan.md` (and `spec.md` if present) and the docs the plan names.

Use the `workflow-verification` skill before any completion claim.
Do not say work is complete, fixed, or passing unless the relevant verification commands have just run successfully.

## Execution rules

- **Never implement on `main`.** Create or ask for a scoped branch first.
- **Default behavior:** execute the plan task-by-task by dispatching a fresh `implement-task` worker (via the Agent tool, `subagent_type: implement-task`) for each task. This is the standard workflow — do not deviate unless the user explicitly asks for inline implementation.
- **Inline implementation:** acceptable only when the user explicitly asks you to implement directly. When inline, apply the same per-task and review gates as delegated workers.
- **Controller duties:** orchestrate — dispatch tasks, package context for workers, review worker reports and diffs, enforce spec compliance and code-quality gates, and run verification before any completion claim. Give the worker the full task text, relevant context, exact plan/spec paths, affected docs, and current branch state; do not make it reread the whole plan.
- **One focused commit per task.** Delegated workers create the task commit; commit inline only when you execute a task yourself. Review the worker report and `git diff` before moving on.
- Follow TDD for behavior changes unless the plan marks a step as docs-only, config-only, or trivial wiring.
- Do not pause between tasks for routine progress approval.
- Stop and ask only when the same task fails more than three times, the plan conflicts with code reality, or an architectural decision is required. If a task needs an architectural decision, report the blocker and recommend human escalation.

## Model selection

Each per-task `implement-task` worker runs on Sonnet — the `implement-task` agent pins `model: sonnet`, so leave the model override off when dispatching it.
If a worker fails to deliver a task (after the per-task retry limit), re-dispatch the same task with a `model` override to a more capable model before escalating to a human.

## Verification

Run targeted verification while iterating and the required final verification before claiming completion. Use the `workflow-verification` skill as the completion gate.

## Shell guidance

- Prefer `git mv` for moves/renames of tracked paths and `git rm` for removals of tracked paths. Use plain `mv`/`rm` only for untracked paths.
- Never work on or push to `main`. Publish through the appropriate publish skill — do not hand-roll `git push`.

## Finishing

After final verification, commit all changes and push the branch using the publish skill:
- GitHub: `bash .claude/skills/github-publish/scripts/push-branch.sh` then `bash .claude/skills/github-publish/scripts/open-pr.sh`
- GitLab: `bash .claude/skills/gitlab-publish/scripts/push-branch.sh` then `bash .claude/skills/gitlab-publish/scripts/open-mr.sh`

The publish scripts refuse `main`/`master` and skip creation when a PR/MR already exists for the branch.
