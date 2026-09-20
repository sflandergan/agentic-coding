---
name: feature-documentation
description: Use when deciding, writing, merging, or updating compact package-driven capability maps under docs/features
user-invocable: false
---

# Compact Feature Maps

## Purpose and applicability

A feature map gives a compact overview of what has been built for a named capability, then points to the main packages and stable entry points used to extend it, and finally notes the non-obvious decisions that constrain extending it. It is not durable documentation for every endpoint, UI, job, fix, or delivery.

- A feature map exists only when it materially helps an engineer understand or extend a named capability or exposes a non-obvious ADR constraint.
- Omit or merge a map when the capability does not stand alone or its packages are already clear from a broader map.
- API and frontend surfaces of one capability belong in one map unless each surface is independently extendable.
- Prefer one map per durable package-spanning capability; do not create refinement or workflow-stage micro-maps.

## Required investigation

1. Start from the completed diff and changed packages; group affected files by package or feature-module root.
2. Read `docs/features/README.md` and neighboring maps to detect overlap.
3. Verify the current package roots and stable entry points in source.
4. Load applicable architecture guides independently for correctness; do not add them as map back-references.
5. Read only ADRs whose non-obvious decisions may constrain the capability.
6. Decide to create, update, merge, rename, remove, or omit the map before writing.

## Default shape

```markdown
# <Capability> Feature Map

<Two or three present-tense sentences: what the built capability does, who owns it,
and the boundary with adjacent capabilities.>

## Main Packages and Entry Points

- `<package-or-feature-module-root>/` — why an engineer starts here.
- `<stable-entry-file>` — include only when opening the package root is insufficient.

## Non-obvious Decisions

- [ADR NNNN](../adr/NNNN-slug.md) — the constraint this decision imposes.
```

`## Non-obvious Decisions` is optional and omitted when no qualifying ADR exists. No `## Architecture References` or mandatory `## Scope` section is allowed.

## Authority and ADR policy

- Maps must not reproduce architecture, schemas, database layouts, algorithms, configuration inventories, tests, rationale, implementation history, status, roadmaps, or verification evidence.
- Guides own reusable mechanics and change when reusable mechanics or cross-feature boundaries change; glossaries own terminology and change only when domain terminology changes; ADRs own consequential rationale.
- Include an ADR only when its decision directly constrains extension and is non-obvious beyond general guides.
- Create or update an ADR only when all three conditions hold: changing the decision would be meaningfully costly, the result is surprising without rationale, and genuine alternatives were considered and traded off.
- If an implemented ADR-worthy decision lacks reliable evidence of alternatives or rationale, stop and ask the owner; never fabricate a retrospective ADR.

## Handoff checks

- Every listed package or entry point exists.
- Every ADR link resolves and its decision actually constrains the capability.
- The map does not duplicate a neighboring capability or split API/UI without independent value.
- The index is synchronized atomically with every map addition, merge, rename, or removal.
- Prose is present tense and contains no dates, branches, PRs, plans, status, tests, or verification history.