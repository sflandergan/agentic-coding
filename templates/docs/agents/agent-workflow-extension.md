# Agent Workflow Extension Guide

Use this guide when changing coding assistant workflows, agents, or reusable skills.

## Boundaries

- `docs/agents/*.md` files are role loading/reference contracts. Keep them focused on which repository docs an agent must load for a workflow. Do not put detailed executable workflow behavior there.
- `opencode.json` defines the OpenCode `build` agent (the default agent that runs every workflow skill) and its permissions; `.opencode/agents/*.md` files define only the worker subagents (`explore`, `implement-task`, `ui-design-task`).
- `.claude/skills/*/SKILL.md` files define Claude skill behavior for the matching workflow.
- Shared skill files provide reusable mechanics shared by workflows. They may describe how to use bundled scripts or helpers, but they should not own role-level orchestration for review-plan, review-code, planner, implement, or finish workflows.

## Workflow Order

The canonical workflow follows this sequence, where each step is a human-initiated invocation:

```
idea → brainstorm → [optional ui-design] → planner → implement → review → finish
```

- **`idea`** — A rough prompt or high-level feature request. Produces a structured pitch.
- **`brainstorm`** — Generates or refines a spec from the idea. Optionally grills against DDD docs.
- **`ui-design`** — Optional. When presentation or visual structure decisions are needed, generates HTML/CSS mockups and design tokens before planning starts.
- **`planner`** — Breaks the spec into ordered, verifiable tasks in a plan file.
- **`implement`** — Dispatches `implement-task` workers per plan task. Each worker edits assigned files, runs verification, and commits.
- **`review`** — `review-plan` validates plans; `review-code` reviews diffs/PRs and produces fix-plan hand-off docs.
- **`finish`** — Writes feature docs, reconciles ADRs/glossary, publishes change requests.

Human checkpoints (spec review, plan review, code comments) sit between the automated steps.

## GitHub PR comment workflow boundary

- The `github-pr-comments` skill owns reading PR comments, classifying comment target types, obtaining exact IDs, and posting approved replies through project scripts.
- Review agents own deciding what the comments mean, validating technical claims, combining them with independent review findings, suggesting fixes, and requesting approval before edits or replies.

## Draft-First GitHub Pull-Request Publication

Publication is handled by one authored support skill, which is not a remote skill:

- **`git-publish`** — Load the skill and run `bash scripts/publish-branch.sh` from that skill's root. It provides guarded Git/GitHub branch publication, rejects protected branches, prints the existing PR URL or creates a draft PR, and supports lease-safe retained-head updates via `--existing-pr`, `--expected-head`, and `--head-branch`.

The retained-head lease exception is limited to a fully qualified `--force-with-lease=refs/heads/<head>:<expected-sha>`, requires explicit human authorization per invocation, and has no weaker-force fallback.

## UI-Design Preview Adapter Boundary

The `ui-design` workflow verifies presentation output differently from code:

- **Preview-first:** Verification runs by starting a local preview server, probing it for expected visual content, and stopping it. This replaces the typical verification-before-completion gates for UI work.
- **Adapter location:** `.agents/scripts/ui-design/preview.sh` — a target-owned script with three commands: `start`, `probe`, `stop`.
- **Toolkit boundary:** The toolkit does not supply this script. It is a target responsibility. The installer (`init.sh` and `copy.sh`) preserves an existing `preview.sh` in every skill mode (add/override/skip).
- **Permissions:** The exact three preview commands are encoded in `.claude/settings.json` as allowed Bash invocations. If a target replaces the adapter with a wrapper (e.g., Docker Compose), applying the new wrapper's permissions may require updating the presentation-root permissions in `settings.json`.

## Support and Worker Skills

Seven skills are marked `user-invocable: false` and are never invoked directly:

| Skill | Visibility | Dispatched By |
|---|---|---|
| `feature-documentation` | Hidden support | `finish` |
| `git-publish` | Hidden support | `implement`, `finish`, `review-plan`, `review-code` |
| `github-pr-comments` | Hidden support | `review-plan`, `review-code` |
| `implement-task` | Hidden worker | `implement` controller |
| `ui-design-task` | Hidden worker | `ui-design` controller |
| `verification-before-completion` | Hidden support | `implement`, `finish` |

## Skill installation model

The toolkit's `skills/` tree is the single canonical source. Setup installs the
selected skills through each harness's supported mechanism, so both pipelines read
the same workflow definitions without relying on a fixed installation root.

- A change to a toolkit skill is applied by running setup and approving the update.
- Remote skills installed via `npx skills add` are managed by the selected harness.

## Default placement rules

- If the change says what a role should do by default, update the matching workflow skill's `SKILL.md`; change `opencode.json` or `.claude/settings.json` only for permissions or model assignments.
- If the change says which docs a role must load, update the matching `docs/agents/*.md` file.
- If the change says how to run a shared helper script or avoid helper-specific mistakes, update the matching shared skill file.
- If a workflow change affects both OpenCode and Claude, update both definitions in the same plan and verify they remain aligned.

## Agent and skill references

- **OpenCode.** The `build` agent runs workflow skills and dispatches worker subagents by name with the `task` tool (e.g., `explore`, `implement-task`). A workflow skill may dispatch those workers, but should not name other workflow skills (e.g., `/brainstorm`, `/planner`) in its body — cross-workflow hand-offs are the user's responsibility.
- **Claude Code.** Skills are invoked by the user with `/skillname`. Subagents are dispatched via the Agent tool by name with a leading `@` (e.g., `@explore`). The setup-managed `.claude/agents/explore.md` shadows the built-in `Explore`, which would otherwise inherit the main conversation's model, and runs it read-only on Haiku. A workflow skill should not name other workflow skills (e.g., `/brainstorm`, `/planner`) in its body.
- **Shared skills** provide reusable mechanics — wrappers, scripts, methodology — and may be referenced by /name because they are not workflow orchestration.
