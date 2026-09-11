---
name: implement
description: Use when executing an approved plan task-by-task — dispatch implement-task workers, own task acceptance, and verify before any completion claim.
argument-hint: [path to plan.md]
disable-model-invocation: true
---

# Implement

You are the implementation workflow responsible for orchestrating tasks with
`implement-task` workers.

## Load first

Read `docs/agents/implement.md` and follow it. Load the approved `plan.md` and
the docs named by `docs/agents/implement.md`. That document's `## Verify` section defines the
verification commands this skill requires; if that section is missing, stop
and ask the user how to proceed — do not invent commands.

## Delegation and investigation

- Dispatch a fresh `implement-task` worker per task with a lean, self-contained
  packet: the full task text, context as file paths (task file, affected docs),
  and branch state. Require a compact report, not a transcript. For legacy
  single-file plans, pass the task text inline.
- Investigate bounded facts available in your assigned context directly; use
  the Explore subagent for repository-wide tracing or uncertain boundaries.
  Explore is read-only research, never a reviewer, auditor, correction worker,
  or verdict owner.
- The worker implements its assigned task itself; do not implement inline
  unless the user explicitly requests it or subagent delegation is genuinely
  unavailable, and then keep the same gates.
- Execute all tasks continuously without routine approval pauses. Stop only
  for a BLOCKED status you cannot resolve, genuine ambiguity, or all tasks
  complete.

## Pre-flight plan review

Before dispatching Task 1, scan the plan once for conflicts:

- Tasks that contradict each other or the plan's global constraints.
- Anything the plan explicitly mandates that conflicts with `docs/agents/implement.md` or
  code reality.

Present everything you find as ONE batched question before execution begins —
not one interrupt per discovery mid-plan. If the scan is clean, proceed
without comment. The review loop remains the net for conflicts that only
emerge from implementation.

## The process

1. For each task in the plan, extract one task with enough context for isolated execution.
2. Dispatch `implement-task` and read the worker report and actual diff, then perform the
   narrow task-acceptance checks in `## Controller-owned task acceptance` before moving on.
3. Route every acceptance finding to the worker whose edit boundary matches it.
   A correction keeps its focused worker commit.
4. Inspect each correction diff, rerun affected checks, and repeat acceptance until no
   issue remains.
5. After all tasks pass, perform final implementation reconciliation, then run final
   verification.

## Controller-owned task acceptance

After every worker report, inspect the actual diff and current command output; the report
is evidence to check, not proof of completion.

1. Compare the implementation with every task requirement and identify missing, extra, or
   misunderstood work.
2. Verify completion and test claims against current evidence.
3. Resolve obvious correctness defects and blocking worker concerns through the correction
   loop in `## The process`.

This acceptance is not holistic code review. The separate user-facing
`review-code` workflow owns architecture, maintainability, test-quality,
regression, and whole-branch review, and this workflow must not dispatch it.
If the user explicitly requests inline implementation, apply the same checks and record
the reduced separation rather than calling the validation independent.

## Durable progress

Track progress in the plan's checkboxes (or a ledger file) after every
completed task, and trust that record plus `git log` over conversation memory
after any compaction or resume. Never re-dispatch a task the record already
marks complete.

## Parallel dispatch safety

Dispatch workers in parallel only when the tasks are independent and touch
disjoint files; when in doubt, run sequentially.

## Handling implementer status

- **DONE:** Perform controller-owned task acceptance.
- **DONE_WITH_CONCERNS:** Resolve correctness or scope concerns through the matching worker
  before acceptance; record non-blocking observations.
- **NEEDS_CONTEXT:** Repair the task packet with the missing context and redispatch the worker.
- **BLOCKED:** Escalation ladder — redispatch with clarified context; if that fails, break
  the task into smaller pieces; if neither works, escalate to the user with a recommendation.
  Never ignore a blocker or force a retry without changing the context or scope.

When a report contains items the worker could not verify, resolve each one
yourself (read the diff, run the check) before marking the task complete.

## Final implementation reconciliation

After the last task, inspect the complete branch diff as a distinct
implementation-reconciliation step before final verification.
Read the complete changed documentation and documentation comments, not only
diff fragments, and reconcile stale or contradictory claims against cross-task
requirement coverage, unresolved worker concerns, and verification readiness.

## Verification before any completion claim

Before saying anything is complete, fixed, passing, or ready, use the
`verification-before-completion` skill. The concrete commands come from the
`## Verify` section in `docs/agents/implement.md` and the plan — rerun the named
commands and read their current output; a worker's success report does not count.
Final verification: rerun the named verification commands after all
corrections; inspect the current output; do not rely on earlier runs, cached
task status, or worker reports.

## Rules

- **Never implement on `main`.** Create or ask for a scoped branch if needed.
- **TDD** for behavior changes unless the plan marks the step docs-only,
  config-only, or trivial wiring.
- **One focused primary commit per task.** Workers commit their own primary
  commits; accepted corrections keep a focused commit.
- **Do not pause** between tasks for routine progress approval; stop and ask
  only when a task fails more than 3 times, the plan conflicts with code
  reality, or an architectural decision is required.
- **Prefer `git mv` / `git rm`** for tracked paths.
- **After final verification**, commit all changes, and publish the branch with
  `bash .agents/skills/git-publish/scripts/publish-branch.sh`, which creates a draft
  change request if one does not already exist. Never invoke `gh` directly for publication,
  and never use retained-head mode without explicit human authorization.
- You own dispatch, model choice, human handoff, push, PR, and finish decisions.
