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
  packet: the task file path (for example, `tasks/01-<slug>.md`), relevant
  context as file paths (affected docs), and branch state. Require a compact
  report, not a transcript. For legacy single-file plans, extract the task text
  and pass it directly to the worker as inline task text.
- Use the Explore subagent only for focused, read-only repository research when
  acceptance depends on a factual question. Explore is not a reviewer, UI
  auditor, correction worker, or workflow verdict owner, and it is never a
  substitute for a missing capability.
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

This skill defines the process and the quality gates:

1. For each task in the plan index, read the linked `tasks/NN-<slug>.md` file to get the full executable task.
   Task paths are relative to the directory that contains the plan file you were given, so implementation plans and review-fix rounds under `review-rounds/<NN>/` both work the same way.
2. Dispatch `implement-task` with the **task file path** (for example, `tasks/01-<slug>.md`), relevant context, affected docs, and branch state. The worker reads the task file directly — do not paste the task text or make the worker reread the surrounding plan when the task file exists.
3. Read the worker report and actual diff, then perform the narrow task-acceptance checks in `## Controller-owned task acceptance` before moving on.
4. Route every acceptance finding to the worker whose edit boundary matches it: `implement-task` for behavior, production integration, data, tests, configuration, or other non-presentation work; `ui-design-task` for a bounded presentation-only correction within approved UI direction. Do not route a design-direction conflict to either worker.
5. Inspect each correction diff, rerun affected checks, and repeat acceptance until no issue remains. An `implement-task` correction keeps its focused worker commit. Incorporate an accepted non-committing `ui-design-task` correction into the applicable primary task commit when acceptance is still on that task, or into the integration commit during the UI completion gate.
6. After all tasks pass, perform final implementation reconciliation, then run the conditional UI gate and final verification.

## Controller-owned task acceptance

After every worker report, inspect the actual diff and current command output; the report
is evidence to check, not proof of completion.

1. Compare the implementation with every task requirement and identify missing, extra, or
   misunderstood work.
2. Verify completion and test claims against current evidence.
3. Confirm every changed-code audit required by the repository role document, including required enumerations and evidence for exceptions.
4. Reject any domain-sounding name a task or worker report introduces that the context glossary does not define; return the term to planning or the user before accepting the task as `DONE`.
5. If `ui-design-task` changes files or behavior outside its packet or presentation boundary, reject only those worker-owned hunks without disturbing pre-existing work and reroute the finding to `implement-task` or focused human-led UI-design reconciliation as appropriate.
6. Resolve obvious correctness defects and blocking worker concerns through the correction
   loop in `## The process`.

This workflow's acceptance and reconciliation are not holistic code review. The separate user-facing
`review-code` workflow owns architecture, maintainability, test-quality,
regression, and whole-branch review, and this workflow must not dispatch it.
If the user explicitly requests inline implementation, apply the same checks and record
the reduced separation rather than calling the validation independent.

## Error handling

- If a required validation, audit, or worker capability is unavailable, stop and report the exact missing capability; never substitute Explore.
- If a UI finding requires changing approved design direction, stop for focused UI-design reconciliation rather than asking either correction worker to invent a decision.

## Lean dispatch prompts / file hand-offs

A dispatch prompt describes one task, not the session's history. Hand context
over as file paths (the task file, affected docs), never by pasting long
excerpts. Require the worker to return a compact report, not a transcript.

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
requirement coverage, unresolved worker concerns, UI-gate readiness, and
verification readiness.

## UI integration activation

After the final implementation reconciliation and before final verification, read the
approved specification's `## UI Design` marker. When the marker is
`ui-design: not-required`, do not require UI integration evidence or run a
visual gate. When the marker is `ui-design: required`, read
`plans/<feature-dir>/ui-design.md` and require the implementation plan to
name production routes, deterministic local data setup, local startup and
readiness commands, and the installed Impeccable capabilities used by the
gate. Stop and report the exact missing input when any requirement is absent.

## Integrated UI completion gate

This gate runs only for `ui-design: required`.
Use the startup, readiness, local-data, teardown, and safety steps named in the
role document's UI integration section.

After all plan tasks and final implementation reconciliation are complete:

1. Start the plan's local environment and wait for every documented readiness URL.
2. Reach each approved handoff state at its planned production route using deterministic local data.
3. Run the planned behavior, accessibility, responsive, and completed-flow checks.
4. Invoke `/impeccable audit` and `/impeccable critique` against the checked local result.
5. Record each test, audit, critique, or human finding with its source and disposition.
6. Classify every actionable finding and route it by boundary: a presentation correction within the approved direction goes to `ui-design-task`; a behavior, integration, data, test, configuration, or cross-boundary correction goes to `implement-task`; a material conflict with the approved direction stops for focused human-led UI-design reconciliation.
7. Give `ui-design-task` a self-contained presentation packet. It does not verify, commit, reinterpret design direction, or edit outside that packet.
8. Inspect every correction diff and reject only out-of-packet worker hunks without disturbing pre-existing work. Rerun affected checks, include accepted non-committing UI corrections in the final integration commit, and repeat until each finding is corrected, explicitly accepted by the human, or escalated as a material design conflict.
9. Present the checked local result for human approval.
10. After approval, record concise integration evidence.
11. Stop every process started by the gate on success, failure, or cancellation.

Each finding's disposition is corrected, an accepted limitation approved by the human, or an unresolved material conflict requiring focused UI-design reconciliation.
Write `plans/<feature-dir>/ui-integration.md` with the routes and deterministic data used, handoff-state mapping, dated command results, audit and critique findings and dispositions, human approval, and accepted limitations.

## Verification before any completion claim

Before saying anything is complete, fixed, passing, or ready, use the
`verification-before-completion` skill. The concrete commands come from the
`## Verify` section in `docs/agents/implement.md` and the plan — rerun the named commands and
read their current output; a worker's success report does not count. After
a worker reports success, verify its diff and rerun the relevant checks
yourself. Final verification: rerun the named verification commands after
the integrated gate and all corrections; inspect the
current output; do not rely on earlier runs, cached task status, or worker
reports.

## Rules

- **Never implement on `main`.** Continue on the work's existing branch and PR; create a scoped branch only when none exists, and never open a second branch or PR for the plan's work.
- **Default:** dispatch a fresh `implement-task` worker per task; inline
  implementation only when the user explicitly asks, applying the same gates.
- Follow the repository's testing guidance loaded by the role document for test selection and task verification steps.
- **One focused primary commit per task;** workers commit their own primary commits, and accepted corrections keep a focused commit or are incorporated into the applicable task or integration commit as the worker contract dictates.
- **Do not pause** between tasks for routine progress approval; stop and ask
  only when a task fails more than 3 times, the plan conflicts with code
  reality, or an architectural decision is required.
- **Prefer `git mv` / `git rm`** for tracked paths.
- **After final verification**, use the `git-publish` skill to publish and
  ensure a PR exists: load the skill and run `bash scripts/publish-branch.sh`
  from its root, which creates a draft change request if one does not already
  exist. Report the PR URL, and stop. Never raw `git push` or raw `gh pr create`;
  never invoke `gh` directly for publication, and never use retained-head mode
  without explicit human authorization.

## Red flags

**Never:**

- Start implementation on `main` without explicit user consent.
- Skip controller-owned task acceptance, correction-diff inspection, affected-check reruns, final implementation reconciliation, or the final verification gate.
- Use Explore as a reviewer, auditor, correction worker, or verdict owner.
- Move to the next task while a controller acceptance issue or worker concern remains unresolved.
- Make an `implement-task` worker read the entire plan file when the task file path is available.
- Accept a worker report without checking its claims against the diff and current command output.
- Dispatch multiple implementation workers in parallel unless the plan explicitly says the tasks are independent and they touch disjoint files.

## Boundaries

- You own dispatch, model choice, human handoff, push, PR, and finish decisions.
- After final verification, commit all changes.
- This skill only defines execution discipline and review gates.
- Workers follow TDD instructions embedded in the approved plan for behavior
  changes.
- Inline execution is acceptable only when the user explicitly requests it or
  subagent delegation is genuinely unavailable, but keep the same task/review
  gates.
