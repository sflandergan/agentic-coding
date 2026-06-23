---
name: agent-planning
description: Use when a spec or requirements for this toolkit repo need to be turned into a plan, before touching files
user-invocable: false
---

# Agent Planning — Self-Maintenance

Write lightweight implementation plans for this toolkit repo. There is no application code — the maintenance surface is markdown templates and bash scripts.

**Announce at start:** "I'm using the agent-planning skill to create the implementation plan."

**Save plans to:** `plans/YYYY-MM-DD-<feature-name>/plan.md`, next to the spec.

## Scope Check

If the spec covers multiple independent concerns, suggest splitting into separate plans.

## File Mapping

Before defining tasks, map out which files will be created or modified. For each file:

- What it is responsible for
- Whether a `stacks/*` overlay also needs updating (core+stacks dual-maintenance)
- Whether `README.md`, this repo's `skills-lock.json`, `core/skills-lock.json`, or the dot-mapping table need updates for their distinct scopes

## Task Granularity

Each task is one focused commit. Steps within a task are 2-5 minute actions:

- "Write the file" — step
- "Verify syntax" — step
- "Commit" — step

No rigid TDD — verification is shellcheck, bash -n, smoke runs, codespell for prose-heavy changes, and consistency checks.

## Spellcheck Planning

When a task creates or modifies markdown templates, agent files, skill files, README content, or user-facing script text, include a `codespell` verification step for the changed files. Keep it scoped to the files touched by the task unless the plan intentionally adds or updates repo-wide spelling policy.

## Plan Document Header

```markdown
# [Feature Name] Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence]

**Configuration shape:** [2-3 sentences]

**Configuration surface:** [Key files, tools, and validation commands]
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file`
- Modify: `exact/path/to/existing`

- [ ] **Step 1: [Action]**

[Content — exact paths, complete file content or commands]

- [ ] **Step 2: Verify**

Run: `shellcheck scripts/foo.sh`
Run: `codespell exact/path/to/file.md`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add path/to/file
git commit -m "chore: description"
```
```

## No Placeholders

Every step must contain actual content. Replace placeholder phrases such as "TBD", "TODO", "implement later", "add appropriate handling", and "similar to Task N" with concrete instructions.

## Self-Review

After writing the plan:

1. **Spec coverage:** Can you point to a task for each spec requirement?
2. **Placeholder scan:** Search for red-flag patterns.
3. **Sync check:** Do README, repo lockfile, core template lockfile, and dot-mapping need updates for their separate scopes? Are those tasks included?

Fix inline. No re-review needed.

## Completion

After saving the plan, report the plan path and any open questions. Stop after reporting.
