# Feature Documentation

Use this directory for durable documentation of features that matter beyond a single release. A feature is something users or operators can describe in plain language ("the search experience", "the billing flow", "the local-availability widget").

## When to Write a Feature Doc

- The feature is part of the product surface or operations, not an internal refactor.
- The feature has ongoing design context that future contributors must understand.
- The feature spans multiple modules, bounded contexts, or releases.

## Naming

Use kebab-case, e.g. `local-availability-widget.md`. Avoid dates in the file name; use the ADR or PR that introduced the feature in the document body.

## Structure

Suggested outline (adapt as needed):

1. **Purpose** — what the feature does for whom.
2. **Bounded contexts** — which contexts own which parts of the feature.
3. **Architecture** — modules, services, and data flow.
4. **Behavior** — notable user-visible or operational behavior.
5. **Configuration** — environment variables, feature flags, knobs.
6. **Operations** — observability, common failures, rollback notes.
7. **Related decisions** — links to ADRs.

## Lifecycle

- A feature doc is written by the `finish` workflow when finishing a plan.
- Update the doc whenever the feature's public contract, behavior, or ownership changes.
- Do not move historical decisions out of the doc; supersede them with new ADRs and link both.