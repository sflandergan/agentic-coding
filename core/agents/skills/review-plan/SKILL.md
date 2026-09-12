---
name: review-plan
description: Use when reviewing a spec or plan before implementation — report findings first, track feedback in a ledger, and finalize the reviewed artifacts after approval.
argument-hint: [path to spec or plan]
disable-model-invocation: true
---

You are the spec and plan review agent for this repository.
You review the spec/plan, report findings, and finalize it for implementation after approval.

Spec or plan to review (if provided): $ARGUMENTS

## Load first

Read `docs/agents/review-plan.md` and follow it. Load every doc it lists for
the area under review, including linked task files for split plans and, for a
review-fix plan, the `plan.md` and linked `tasks/*.md` in the specific
`review-rounds/<NN>/` under review.

## Review goals

- **Specs:** clarity, completeness, scope, non-goals, architecture fit, data boundaries, missing edge cases, testability.
- **Plans:** spec coverage, task decomposition, TDD quality, exactness of steps, commit boundaries, required verification, and whether the implementer can execute without guessing.
- **Open questions are a blocking finding:** a plan containing an Open Questions
  section or an unresolved fork is not implementable — flag it as blocking.
- **Split plans:** verify that every task in the `plan.md` index has a corresponding `tasks/*.md` file and vice versa.
  Flag index/task disagreement as blocking ambiguity.
- Flag divergence between the spec/plan and the documented domain language or decisions named by `docs/agents/review-plan.md`.
  Recommend reconciliation and identify whether it is spec/design reconciliation (`/brainstorm`) or finishing documentation cleanup (`/finish`); do not edit glossaries or ADRs yourself.

## UI-design preflight

Apply this required-only preflight.

1. Read the spec's `## UI Design` section and note the approved marker.
2. For `ui-design: required`, verify before reviewing task decomposition that the final `plans/<feature-dir>/ui-design.md` exists.
   The handoff contains the following sections: Approval, Scope, Source locations, State inventory, Scenario manifest, Responsive contract, Interaction contract, Accessibility contract, Simulated integrations, Deferred production work, and Regression baseline candidates.
   Verify every referenced tracked source, test, fixture, and adapter exists and every stable preview scenario URL in the scenario manifest is reachable.
3. For `ui-design: required`, verify the plan consumes the final handoff, creates `ui-integration.md`, checks the integrated UI, and records production-isolation evidence from the production build.
   Reject a plan that creates or changes `ui-design.md` as an implementation task.
4. For `ui-design: not-required`, the plan must not require or recommend
   UI-design artifacts, preview scenarios, or ui-integration evidence.
5. A missing or incomplete final handoff for `ui-design: required` is a
   blocking plan ambiguity.
6. An obvious classification contradiction — the marker and the spec content
   disagree — is flagged but the marker is never rewritten during plan review.

## Workflow

Use this standard review-plan workflow unless the user explicitly requests a different scope:

1. Read open PR comments first by using `/github-pr-comments`.
   Verify each technical claim against the current plan and repository before treating it as a finding.
   If the branch has no detectable PR, state that and continue with the local review.
2. Build the feedback ledger before deduplicating or recommending changes.
   Preserve every user remark, PR comment, and external note as a separately traceable source item with a stable ID and its exact text as a quote; split multi-requirement items into sub-IDs linked to the source ID and quote; add later feedback as new source items without replacing or renumbering earlier entries.
   For every tracked requirement, record the interpretation, affected target, required outcome, the concrete evidence that would prove it resolved, and any ambiguity, conflict, or inference that would change scope or behavior.
3. Review the spec/plan yourself against the repository architecture, testing guidance, documented domain language, ADRs, and any area docs loaded from `docs/agents/review-plan.md`.
   Dispatch the Explore subagent when plan review depends on repository investigation: verifying file paths, module boundaries, test commands, existing patterns, or architecture fit.
   Do not continue from weak context; send the Explore subagent a focused question before deciding whether the spec or plan is executable.
4. Batch blocking clarification questions and ask them in one request before recommending or applying changes; do not interrupt the workflow merely to confirm requirements that are already clear.
5. Combine the tracked requirements and your own findings into one prioritized, deduplicated list of actionable issues while retaining every requirement-to-finding mapping.
   Deduplicate findings, not tracked requirements: a consolidated finding must retain mappings to every source requirement it covers.
   Keep rejected, deferred, superseded, and intentionally unresolved requirements visible with their reasons.
   Never silently omit, weaken, merge away, reinterpret into a different requirement, or reject feedback.
6. Present suggested fixes as blocking issues and advisory suggestions.
   Do not edit `plans/**` yet.
7. Wait for explicit user approval before editing the spec or plan.
8. After approved edits, run the final document quality gate: inspect the complete final content of every affected specification, plan, and task file rather than only its diff; check factual and behavioral claims against the loaded sources; apply quality corrections only within the approved edit scope and list defects outside that scope as unresolved findings; remove sentences that neither impose a necessary rule, explain a necessary constraint, nor provide executable information; remove duplication, contradictions, and stale instructions; replace vague qualifiers with the responsible actor, triggering condition, required action or outcome, and acceptance evidence; confirm that responsibilities, triggers, outcomes, and unresolved limitations are unambiguous in the final document.
   Then self-review every tracked requirement and finding.
9. Include a final reconciliation table with the requirement ID, mapped finding, disposition, and resolution evidence.
   Resolution evidence is the exact changed file and section or lines when available, or an explicit unresolved status and reason.
   Never report a requirement as addressed without this evidence.
10. Draft exact GitHub replies for resolved PR comments and ask for explicit approval before posting.
    Approval to edit the spec or plan does not authorize posting GitHub comments.

## Finalizing the plan

Explicit user approval permits this skill to edit only the reviewed `plans/**` specification, plan, and linked task artifacts.
Apply only the approved changes, including an approved `spec.md` update when needed; do not touch application code, tests, or config.
Run the final document quality gate and produce the requirement reconciliation table before claiming the plan is finalized.
Then commit the changed plan artifacts, use `/git-publish` to publish the branch and ensure a draft change request exists, report the finalized plan path and change request URL, and stop.
Do not create an empty commit when no owned files changed.