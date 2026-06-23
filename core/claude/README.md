# Claude Code agent setup

Claude Code runs the **conversational** half of the agent pipeline. The
**implementation** half stays in OpenCode. There is deliberately
**no orchestrator**: the OpenCode hand-off ends the Claude Code session, and reviews are
triggered by hand, so the workflows are discrete, manually-invoked entry points.

## The six skills

Each is a real `SKILL.md` under `.claude/skills/<name>/`, marked
`disable-model-invocation: true` — they never auto-trigger and stay out of the always-loaded
skill index. You start them with `/name`.

| Skill (`/name`) | OpenCode counterpart | Role |
| --- | --- | --- |
| `/brainstorm`  | `@brainstorm`  | Idea → approved `spec.md` (interactive; offers domain grilling) |
| `/bugfix`      | `@bugfix`      | Investigate bug → structured GitHub issue; does not fix |
| `/planner`     | `@planner`     | Spec → task-by-task `plan.md` (offers grilling only when new domain language or non-trivial decisions appear) |
| `/review-plan` | `@review-plan` | Review + finalize the OpenCode hand-off plan |
| `/review-code` | `@review-code` | Review a diff/PR → fix-plan hand-off doc |
| `/finish`      | `@finish`      | Durable feature doc, light glossary/ADR reconciliation, cleanup |

## Design principle: delegate to shared authored skills

The six entry-point skills carry per-agent glue (workflow steps, stop/hand-off gates,
escalation rules) but delegate the heavy-lift methodology to authored skills under
`.agents/skills/`. This avoids inlining duplicate copies of shared workflows.

### Shared authored skills

These shared skills are symlinked into `.claude/skills/` from `.agents/skills/`:

- `grill-with-docs` — used by `/brainstorm`, `/planner`, `/finish` (+ OpenCode)
- `workflow-bug-analysis` — used by `/bugfix`
- `workflow-brainstorming` — used by `/brainstorm`
- `workflow-planning` — used by `/planner`
- `workflow-verification` — used by `/finish`
- `feature-documentation` — used by `/finish`
- `github-pr-comments` — used by `/review-plan`, `/review-code` (+ OpenCode)

Remote skills (e.g. `context7-cli`, `next-best-practices`, `shadcn`, `zoom-out`,
`write-a-skill`) are declared in `skills-lock.json` and installed via the
[`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills add`). Each
lands in `.agents/skills/` and is symlinked into `.claude/skills/`.

## Shared files referenced by path (not duplicated)

- **Role docs** `docs/agents/<name>.md` — the authoritative "which docs to load" list for
  each agent. Each skill reads its role doc; the role doc points onward to `CONTEXT-MAP.md`,
  `docs/contexts/*`, `docs/adr/*`, and the area docs. Plain files, not skills → no leak.

## Grilling

Domain grilling is **offered, proportional, and never automatic**:

- `/brainstorm` offers `grill-with-docs` after an initial design is presented. It is
  never invoked automatically.
- `/planner` offers `grill-with-docs` only when a plan introduces new domain language
  or non-trivial decisions; it skips the deep pass for plans that introduce nothing new.
- `/finish` performs only light domain-doc reconciliation (glossary and ADR updates
  when implementation or review drifted the domain). It invokes `grill-with-docs` only
  when a divergence genuinely needs interrogating.

All three skills load the shared `grill-with-docs` skill on demand.

## Skill inventory in `.claude/skills/`

- **Authored agent skills (real dirs):** `brainstorm`, `bugfix`, `planner`, `review-plan`,
  `review-code`, `finish`.
- **Symlinked shared skills (auto-invocable):** `grill-with-docs`,
  `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`,
  `workflow-verification`, `feature-documentation`, `github-pr-comments`.

To add a newly-installed shared skill:
`ln -s ../../.agents/skills/<name> .claude/skills/<name>`. `.claude/skills/` is hand-managed.

## Permissions

`settings.json` encodes the project-wide permission union the skills need: edit
allowed; read-only git and common Unix commands allowed; `git push` / `gh pr create` /
`rm` ask first; branch-delete, worktree-remove denied.

## Usage

Type `/brainstorm`, `/bugfix`, `/planner`, `/review-plan`, `/review-code`, or `/finish`
(optionally with an argument, e.g. `/planner plans/2026-05-30-foo/spec.md`).
