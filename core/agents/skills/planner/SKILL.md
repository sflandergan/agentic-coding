---
name: planner
description: Use when turning an approved spec or clear requirements into a reviewable plan.md with checkbox tasks and TDD steps — resolves every fork during planning and ships zero open questions.
argument-hint: [path to spec or requirements]
disable-model-invocation: true
---

# Writing Plans

Write comprehensive implementation plans as bite-sized tasks an engineer with
zero codebase context can execute: exact files, complete code, testing, and
docs for every task. DRY. YAGNI. TDD. Frequent commits.

## Load first

Read `docs/agents/planner.md` and follow it. Load the approved spec first, then
every relevant doc listed by `docs/agents/planner.md`.

If requirements are missing entirely (no spec, no clear requirements), ask the
user to provide an approved spec or do a separate brainstorming/design pass. Do
not invoke brainstorming automatically.

- Investigate bounded facts available in the loaded context directly; use the
  Explore subagent for repository-wide tracing or uncertain boundaries — never
  guess file paths, module boundaries, or assumptions.

## Ordered workflow

1. **Scope check.** If the spec covers multiple independent subsystems, suggest
   breaking it into separate plans — one per subsystem, each producing working,
   testable software on its own.
2. **UI-design preflight** (below).
3. **Resolve uncertainty** (below) — plans ship with zero open questions.
4. **Map the file structure.** Before defining tasks, decide which files are
   created or modified and each one's responsibility. Design units with clear
   boundaries; prefer smaller, focused files; files that change together live
   together; follow established patterns in existing codebases.
5. **Write the plan** following `/planning-structure`.
6. **Self-review** (below), fix inline, and report.

## UI-design preflight

Before task decomposition, read the approved spec's `## UI Design` section and
note the marker. The marker is the spec author's classification — do not change
it.

### `ui-design: required`

Verify the following before proceeding:

1. `plans/<feature-dir>/ui-design.md` exists as the final handoff.
2. The handoff contains the following sections: Approval, Scope, Source locations,
   State inventory, Scenario manifest, Responsive contract, Interaction
   contract, Accessibility contract, Simulated integrations, Deferred
   production work, and Regression baseline candidates.
3. Every referenced tracked source, test, fixture, and adapter exists.
4. Every stable preview scenario URL listed in the Scenario manifest is
   reachable.

When a check fails, report the exact gap to the human — do not silently
reclassify the spec as `not-required` or silently redesign the approved
presentation.
If `plans/<feature-dir>/ui-design.md` is missing, tell the human to run `ui-design`
to produce the handoff before continuing.
Treat the final handoff as read-only input; no production-plan task may create or
change it.

Plan the deferred production work plus the creation of
`plans/<feature-dir>/ui-integration.md` and production-isolation evidence.

### `ui-design: not-required`

Plan the feature through the standard path; no UI-design artifacts, preview
scenarios, or ui-integration evidence.

### Contradictions

An obvious contradiction between the marker and the spec content — for example a
new-screen spec marked `not-required`, or a backend-only spec marked `required`
— is reported to the human rather than silently reclassified.

## Resolving uncertainty (mandatory)

Plans ship with **zero** open questions. There is no Open Questions section, and
a plan is not complete while an unresolved fork remains. Resolve uncertainty
during planning — never defer it to the reader.

- When planning reaches a genuine fork — two defensible task breakdowns, a spec
  sentence supporting two readings, an unclear dependency or rollout order —
  **stop and ask the user**, using the `question` or `AskUserQuestion` tool,
  whichever is available, always attaching your recommended answer.
- Questions answerable from the codebase must be explored (e.g. via the
  Explore subagent), not asked.
- If a fork cannot be resolved interactively, state the assumption you verified
  and adopted, prominently, in the plan — an explicit stated assumption is the
  only permitted substitute for an answer.

## Plan artifact structure

Follow `/planning-structure` for directory layout, file names, numbering, and slug rules.

Write the plan to `plans/YYYY-MM-DD-feature-name/plan.md`, next to the spec.
The plan is a single file containing all tasks as checkbox sections.

**Plan header (every plan MUST start with this):**

```markdown
# [Feature Name] Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Task right-sizing and structure

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. Fold setup, configuration, scaffolding, and
documentation steps into the task whose deliverable needs them; split only
where a reviewer could meaningfully reject one task while approving its
neighbor. Each task ends with an independently testable deliverable.

Each step is one action (2-5 minutes): write the failing test → run it to
verify it fails → implement the minimal code → run the tests to verify they
pass → commit.

Each task uses this structure:

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `<the focused test command for this package>`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `<the focused test command for this package>`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```

## No placeholders

Every step must contain the actual content an engineer needs. These are
plan failures: "TBD", "TODO", "implement later", "fill in details";
"add appropriate error handling" / "add validation" / "handle edge cases";
"write tests for the above" without actual test code; "similar to Task N"
(repeat the code — tasks may be read out of order); steps that describe what
to do without showing how; references to types, functions, or methods not
defined in any task.

## Self-review

After writing the complete plan, check it against the spec yourself — not a
subagent dispatch:

1. **Spec coverage:** every requirement has a task; add a task for any gap.
2. **Placeholder scan:** no patterns from "No placeholders".
3. **Type consistency:** types, method signatures, and property names match
   across tasks.
4. **Zero open questions:** every fork resolved or carried as a prominently
   stated, verified assumption.

Fix issues inline.

## Grilling (proportional)

Use `/grill-with-docs` when the plan introduces new or fuzzy domain language or
a real, hard-to-reverse decision, pointing it at the docs named by
`docs/agents/planner.md`. Skip it for plans that introduce no new terms or
decisions.

## Verification

Include package-level and root verification commands, and integration tests for
cross-package changes when the project's testing guidance requires them.
Follow the project's stack-aware verification rules.

## Shell guidance

Prefer relative workspace paths in commands and examples (e.g.
`mkdir -p plans/2026-05-30-feature-name`). Avoid absolute workspace paths
unless a tool requires them.

## Completion

After saving the plan, report the plan path, docs used, and self-review
findings. Plans contain no open questions. After the user approves the plan,
commit the plan/spec artifacts if they changed, and stop. Do not create an
empty commit when no owned files changed. Do not invoke implementation agents
automatically — ask the user first.