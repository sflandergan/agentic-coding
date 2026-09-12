---
name: ui-design
description: Use when an approved specification marks `ui-design: required` — produce approved presentation code through a preview-first interactive loop with ui-design-task workers, inspect every scenario and viewport against the live preview, and write the final handoff.
argument-hint: [path to approved specification]
disable-model-invocation: true
---

# UI Design Workflow

You are the UI-design workflow.
Keep design direction authoritative, orchestrate delegated implementation, run inspection, and write the final handoff.
This workflow does not run automated correctness verification.

## Load first

Read `docs/agents/ui-design.md` and follow it.
Load the approved specification from the argument path.

## 1. Preflight

- Confirm the approved specification contains `ui-design: required` in its `## UI Design` section; if it says `ui-design: not-required`, stop and report that UI design is not required.
- Run the preview command and readiness check defined in `docs/agents/ui-design.md`; stop if the preview is unavailable.
- The adapter is bounded: `start` is idempotent and starts the preview server if not already running; `probe` owns a finite internal timeout and returns nonzero when the preview is not ready — do not add an unbounded retry loop; `stop` is idempotent and stops only ownership-proven processes.
- Keep the preview running throughout the interactive session; stop it on completion, failure, or cancellation.
- Write temporary screenshots and inspection notes in the repository's scratch location and remove them when finished.
- Keep preview code out of production source and configuration; fixtures use conspicuously synthetic stable data.
- Dispatch the Explore subagent when repository investigation is needed to locate existing components, routes, styles, tests, or boundaries.
- Stop for clarification when required product behavior is unspecified.

## 2. Craft and inventory

- Invoke `/impeccable craft` and follow it exactly.
- Derive the full state, content, responsive, accessibility, simulated, and deferred inventory in the active session.
- Working inventory and visual-direction context remain in the active UI-design/Craft session; do not duplicate inventory into a temporary tracked document.

## 3. Interactive loop

The interactive loop alternates between implementation and human feedback rounds until the direction is provisionally accepted, then proceeds to final inspection and approval (section 4).

### Implementation

- Make small presentation changes directly; delegate substantial, clearly bounded presentation slices to `@ui-design-task` using self-contained inline packets.
- Each packet includes: the approved direction relevant to the slice, exact owned files, target preview scenario and viewport, required states and content variants, responsive, interaction, and accessibility constraints, explicitly deferred behavior, and concise completion criteria.
- The worker edits its owned presentation scope and reports files and evidence; it does not rerun Craft, reinterpret the direction, connect production services, invent product behavior, or approve its own result.
- On `NEEDS_CONTEXT`, supply a corrected packet or take back the slice.
- On `BLOCKED`, take back or reslice the work; do not redispatch `ui-design-task` or fall back to `implement-task`.
- If a worker modifies files outside its packet ownership, remove only the unowned hunks introduced by that worker, without overwriting pre-existing changes, and then redispatch or correct the slice safely.
- Review every worker diff for file ownership and direction compliance before continuing.
- Run workers in parallel only when their file ownership is disjoint.

### Feedback round

Every presentation iteration ends with a feedback handoff containing:

- **Preview:** one exact, clickable scenario URL.
- **Changed:** a concise summary of the iteration.
- **Responsive checks:** screen-size behavior that particularly needs attention, without prescribing one viewport or creating separate approval gates per viewport.
- **Please review:** focused visual or interaction questions.

After this handoff, stop and wait for explicit human feedback.
Readiness checks, worker completion, automated inspection, and silence do not count as approval.
The human may resize and inspect the page at any screen sizes they choose.

Before sending the feedback handoff, you may capture one bounded screenshot of the active scenario to validate that the intended rendering is available — not a Playwright test suite, inspection of unrelated scenarios, or autonomous visual refinement.
After sending the feedback handoff, wait for the human response; a direct human request may authorize a bounded browser inspection during an iteration.
Before handing off an iteration, you may fix mechanical blockers revealed by the bounded rendering check, but not use this allowance for silent visual refinement.
If the preview becomes unavailable, restore it and supply a working URL rather than substituting screenshots or automation for human review.

### Iteration cycle

Apply the implementation change, make small integration corrections, refresh the preview, and perform the bounded rendering check — either capture one optional screenshot of the active scenario or confirm availability through an available browser tool — then present the iteration for human feedback.
Repeat implementation and feedback rounds until the direction is provisionally accepted.
A response such as "looks good" during iteration is provisional acceptance and starts the final inspection pass (section 4).

## 4. Final inspection and approval

Collect four evidence classes before requesting final human approval:

1. **Automated screenshot evidence:** capture the documented scenario and viewport inventory without running a Playwright test suite. Screenshots are defect evidence, not approval evidence.
2. **Source-inspection evidence:** inspect semantic structure, labels, focus styling, responsive rules, and declared visible states where those facts are established by source.
3. **Human-review requests:** ask the human to exercise keyboard flow, focus transitions, and interaction usability against the live preview. The agent cannot exercise these with available browser tools.
4. **Accepted limitations:** identify every inventory item that was not actually inspected and require the human to accept those limitations explicitly before final approval.

Screenshots do not prove keyboard behavior, DOM semantics, exact contrast ratios, or interaction behavior, and the live preview is design feedback, not evidence that tests, types, builds, integrations, or production behavior pass.
Follow the UI-design exception declared by the repository's verification guide.
If evidence collection causes a code change, return to a new human feedback round (section 3).
Whether or not evidence collection finds defects, present the live preview URL together with the collected evidence and accepted limitations, then wait for explicit final human approval.

Only after final approval, write the final handoff at the location in `docs/agents/ui-design.md`.
- The handoff contains the following sections: Approval, Scope, Source locations, State inventory, Scenario manifest, Responsive contract, Interaction contract, Accessibility contract, Simulated integrations, Deferred production work, and Regression baseline candidates.
- The Deferred production work section must state that automated verification (lint, typecheck, tests, build, integration, end-to-end) was deferred and that the changed presentation code is not verified.
- Neither UI-design nor `ui-design-task` edits an existing test whose expectations became obsolete; the handoff records the affected behavior and regression baseline candidates for implementation.
- Create one final commit; it may run the repository's normal pre-commit hooks. UI-design runs no separate test, lint, typecheck, build, integration, or end-to-end commands before that commit.

## 5. Failure and reconciliation

- If the preview cannot start or its readiness check fails, stop and report the failure; if the preview fails after an iteration, restore a renderable preview before requesting feedback.
- If product behavior is unspecified, ask the human.
- Do not write a draft or temporary handoff, silently reconstruct context when the session loses material state, or connect production services or invent production behavior.
- Stop every process you started on completion, failure, or cancellation.
- Material presentation changes after approval require focused UI-design reconciliation.