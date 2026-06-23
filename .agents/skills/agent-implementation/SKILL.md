---
name: agent-implementation
description: Use when executing an approved plan for this toolkit repo task-by-task with commits and verification
user-invocable: false
---

# Agent Implementation — Self-Maintenance

Controller orchestration for implementing plans against this toolkit repo.

**Core principle:** Fresh `implement-task` worker per task + verification gate = quality commits.

**Continuous execution:** Execute all tasks from the plan without routine pauses between tasks. Stop for: BLOCKED status, genuine ambiguity, or all tasks complete.

## The Process

1. Extract one task with enough context for isolated execution.
2. Give the worker the full task text, relevant spec/plan paths, and current branch state.
3. Review the worker report and diff before moving on.
4. Fix and re-review every open issue before marking the task complete.
5. Run final verification before any completion or push claim.

## Worker Contract

The `implement-task` worker:

- Implements exactly one task
- Creates or modifies only the files specified
- Runs task-level verification on changed files (shellcheck, bash -n, codespell on changed prose/markdown files)
- Commits with a focused message
- Reports status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- Does not push, create PRs, or dispatch other workers

## Handling Worker Status

- **DONE:** Verify the diff, move to next task.
- **DONE_WITH_CONCERNS:** Read concerns. If about correctness, address before continuing.
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch.
- **BLOCKED:** Assess: context problem → provide more; plan wrong → escalate to human.

Treat every worker escalation as actionable. If the worker said it's stuck, something needs to change.

## Operating Rules

- Start from a scoped branch.
- Run the relevant verification before status claims and before moving to the next task.
- Resolve correctness issues before continuing.
- Dispatch workers sequentially by default; use parallel workers only for independent tasks touching disjoint files.
- Give each worker the task text, relevant context, and branch state.

## Completion

After all tasks complete and final verification passes:

1. Commit all changes.
2. If the human asked for publishing, run `scripts/publish-branch.sh`.
3. Report the final verification evidence and PR URL when one was created.
