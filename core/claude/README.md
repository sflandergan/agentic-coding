# Claude Code agent setup

Claude Code runs the **conversational** half of the agent pipeline. The
**implementation** half stays in OpenCode. There is deliberately
**no orchestrator**: the OpenCode hand-off ends the Claude Code session, and reviews are
triggered by hand, so the workflows are discrete, manually-invoked entry points.

In the first release, implementation is **OpenCode-only** — Claude Code does not dispatch
implementation workers.

## The six skills

Each is a real `SKILL.md` under `.claude/skills/<name>/`, marked
`disable-model-invocation: true` — they never auto-trigger and stay out of the always-loaded
skill index. You start them with `/name`.

| Skill (`/name`) | OpenCode counterpart | Role |
| --- | --- | --- |
| `/brainstorm`  | `@brainstorm`  | Idea → approved `spec.md` (interactive, grills the domain model) |
| `/bugfix`      | `@bugfix`      | Investigate bug → structured GitHub issue; does not fix |
| `/planner`     | `@planner`     | Spec → task-by-task `plan.md` (grills, TDD) |
| `/review-plan` | `@review-plan` | Review + finalize the OpenCode hand-off plan |
| `/review-code` | `@review-code` | Review a diff/PR → fix-plan hand-off doc |
| `/finish`      | `@finish`      | Durable feature doc, glossary/ADR reconciliation, cleanup |

## Design principle: delegate to symlinked authored skills

The six entry-point skills carry per-agent glue (workflow steps, stop/hand-off gates,
grilling proportionality, escalation rules) but delegate the heavy-lift methodology
to **symlinked authored skills** under `.claude/skills/`. This avoids inlining duplicate
copies of shared workflows.

### Symlinked authored skills

These shared skills are symlinked into `.claude/skills/` from `.agents/skills/`:

- `grill-with-docs` — used by `/brainstorm`, `/planner`, `/finish` (+ OpenCode)
- `workflow-bug-analysis` — used by `/bugfix`
- `workflow-brainstorming` — used by `/brainstorm`
- `workflow-planning` — used by `/planner`
- `workflow-verification` — used by `/finish`
- `feature-documentation` — used by `/finish`
- `github-pr-comments` — used by `/review-plan`, `/review-code` (+ OpenCode)

Remote skills (e.g. `context7-cli`, `next-best-practices`, `shadcn`, `zoom-out`,
`write-a-skill`) are installed through `skills-lock.json`.

## Shared files referenced by path (not duplicated)

- **Role docs** `docs/agents/<name>.md` — the authoritative "which docs to load" list for
  each agent. Each skill reads its role doc; the role doc points onward to `CONTEXT-MAP.md`,
  `docs/contexts/*`, `docs/adr/*`, and the area docs. Plain files, not skills → no leak.

## Grilling

`/brainstorm` and `/planner` treat domain grilling as **baked-in but proportional**: always
a quick glossary check, ramping to a relentless interrogation with inline `CONTEXT.md`/ADR
updates only when new or fuzzy terms or a real, hard-to-reverse decision appear. `/finish`
uses grilling only for light reconciliation. All three invoke the shared `grill-with-docs`
skill.

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
`rm` ask first; branch-delete, worktree-remove denied. The plan includes
`git rm` as an allowed operation — preferring `git rm` over plain `rm` for tracked files.

## Usage

Type `/brainstorm`, `/bugfix`, `/planner`, `/review-plan`, `/review-code`, or `/finish`
(optionally with an argument, e.g. `/planner plans/2026-05-30-foo/spec.md`).
