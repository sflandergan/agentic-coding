---
name: planning-structure
description: Use when writing or validating implementation or review-fix plan artifacts — directory layout, file names, index-to-task links, numbering, and slug rules.
user-invocable: false
---

# Planning Structure

This skill defines the artifact layout for multi-task implementation and review-fix plans. It does not own workflow behavior, quality rules, or role orchestration.

## Implementation Plan Layout

```text
plans/<feature-dir>/
  spec.md
  plan.md
  tasks/
    01-<task-slug>.md
    02-<task-slug>.md
```

### plan.md (summary index)

`plan.md` is the implementation entry point. It includes:

- Standard plan header (Goal, Architecture, Tech Stack)
- Docs used
- Verification baseline
- Ordered task overview table with columns: task number/title, objective, primary files touched, task-local verification, and a link to `tasks/NN-<slug>.md`

Each task summary in the index must link to its task file using a relative path: `[tasks/01-<slug>.md](tasks/01-<slug>.md)`.

### tasks/*.md (executable task files)

Each implementation task file contains the full executable task:

- Task number and title
- Objective (one sentence)
- Exact files to create/modify/test with paths
- Dependencies on prior tasks if any
- Bite-sized checkbox steps with code, commands, and expected outcomes
- TDD details for behavior changes (failing test, verify fail, implement, verify pass, commit)
- Exact commands with expected outcomes
- Intended commit message

Task files must be self-contained. An implementer reading only the task file must be able to execute the task without reading the surrounding plan, spec, or other task files unless the task explicitly requires additional context.

### Numbering and slug rules

- Task files use two-digit zero-padded numbers: `01-`, `02-`, ..., `99-`.
- Slugs are short kebab-case identifiers derived from the task title: `create-planning-structure-skill`, `update-workflow-planning`.
- The number prefix and slug are separated by a hyphen: `01-create-planning-structure-skill.md`.

## Review-Fix Plan Layout

Review fixes are organized into immutable, numbered rounds under `review-rounds/`.
Each round is a self-contained review-fix plan that can be implemented without reading earlier rounds.

```text
plans/<feature-dir>/
  review-rounds/
    01/
      plan.md
      tasks/
        01-<finding-slug>.md
    02/
      plan.md
      tasks/
        01-<finding-slug>.md
```

### Round plan.md (review-fix entry point)

`review-rounds/<NN>/plan.md` is the review-fix entry point for round `<NN>`.
It includes:

- Review context (what was reviewed, which PR/diff)
- Summarized approved findings for this round
- Fix strategy
- Task overview table with links to `tasks/NN-<slug>.md`
- Mapping from each finding/comment to a task or intentionally unresolved status with reason

### Round tasks/*.md (executable fix files)

Each task file contains executable fix steps for one finding or one tightly related finding group.
Same self-containment and numbering rules as implementation task files.
Task numbers restart at `01` inside each round.
