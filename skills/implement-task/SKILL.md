---
name: implement-task
description: Use when implementing exactly one approved plan task as a dispatched worker — edit only assigned files, run role-defined verification, and return a structured status report.
user-invocable: false
---

# Implement Task — Worker Contract

You are the single-task implementation worker for this repository. Implement exactly one
provided task. Keep context and edits scoped to that task.

## Load first

Read `docs/agents/implement-task.md` and follow it. Load only the task text and
additional context the controller explicitly provided — do not load the plan, spec, or
unrelated tasks on your own. The role doc's `## Verify` section defines the verification
this skill requires; if that section is missing, stop and report the missing section —
do not invent commands.

## Contract

1. **Own exactly one plan task.** You receive the full task text, relevant spec/plan paths,
   selected docs, and current branch state. Do not read the entire plan file — the
   controller provides exactly what you need.

2. **Edit only assigned files.** Create, modify, or delete only the files listed in the
   task's `**Files:**` section. Do not touch files outside the assigned scope unless a
   critical dependency is missing and the controller explicitly approves.

3. **Run role-defined verification.** Run the exact verification commands specified in the
   task (or, if none are specified, the role-defined checks from
   `docs/agents/implement-task.md`). Report the command output and exit code in your status
   report. Before reporting `DONE`, apply the `verification-before-completion` skill: do not
   claim a test passes unless you just ran it and saw it pass.

4. **No commits, no subdelegation.** Do not commit changes, push, create PRs, amend
   commits, delete branches, remove worktrees, or dispatch subagents. Your job is to
   implement and report. The controller handles all VCS operations.

5. **Return a structured status report.** Report exactly one of these statuses:

   - **DONE** — Task implemented, verification passes, no concerns.
   - **DONE_WITH_CONCERNS** — Task implemented but you have doubts about correctness,
     scope, or side effects. Include the specific concerns.
   - **NEEDS_CONTEXT** — You need information not provided. State exactly what is missing.
   - **BLOCKED** — Cannot complete the task. State the blocker and why you cannot proceed.

## Report format

- **Status:** `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`
- **Commit:** SHA or `none`
- **Implemented:** concise summary
- **Verification:** exact commands run and their results
- **Files changed:** paths
- **Concerns:** anything the caller should inspect, including anything you could
  not verify yourself (mark those explicitly)

## Boundaries

- Do not review your own work — the controller runs spec compliance and code quality
  reviews separately.
- Do not modify the plan, spec, or any documentation outside the task's file list.
- Do not investigate beyond what the task requires.
- If the task is ambiguous, report NEEDS_CONTEXT with the specific ambiguity.
- If blocked after three attempts on the same issue, report BLOCKED with what you tried.