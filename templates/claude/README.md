# Claude Code agent setup

Claude Code and OpenCode run the same workflow skills through each harness's
skill interface. The only native agents are the workers (`explore`,
`implement-task`, `ui-design-task`). There is deliberately **no orchestrator**:
reviews and hand-offs are triggered by hand, so the workflows are discrete,
manually-invoked entry points.

## Skills

The canonical skill source is the toolkit's `skills/` tree. Setup installs selected
skills through the harness's supported mechanism, so OpenCode and Claude Code can
read the same workflow definitions without a harness-specific path assumption.

User-facing skills are marked `disable-model-invocation: true` so they never
auto-trigger and stay out of the always-loaded skill index. Hidden support and
worker skills are additionally marked `user-invocable: false` so they stay out
of the user-facing skill list and are loaded by agents on demand.

### User-Facing Skills (invoked with `/name`)

| Skill (`/name`) | Role |
| --- | --- |
| `/brainstorm` | Idea → approved `spec.md` (interactive; offers domain grilling) |
| `/bugfix` | Investigate bug → structured GitHub issue; does not fix |
| `/finish` | Durable feature doc, light glossary/ADR reconciliation, cleanup |
| `/idea` | Rough prompt → structured feature pitch |
| `/implement` | Controller that dispatches `@implement-task` workers per plan task |
| `/planner` | Spec → task-by-task `plan.md` (offers grilling only when new domain language or non-trivial decisions appear) |
| `/review-code` | Review a diff/PR → fix-plan hand-off doc |
| `/review-plan` | Review + finalize the implementation plan |
| `/ui-design` | Presentation design → HTML/CSS mockups, design tokens; dispatches `@ui-design-task` workers |
| `/grill-with-docs` | Domain grilling against DDD docs (loaded on demand by others) |

### Support and Worker Skills (hidden, `user-invocable: false`)

These are loaded on demand by agents, never invoked directly by the user:

| Skill | Purpose |
|---|---|
| `feature-documentation` | Compact capability maps under `docs/features/` |
| `git-publish` | Guarded Git/GitHub branch publication with draft PR creation and lease-safe retained-head updates |
| `github-pr-comments` | PR comment fetching, classification, and reply |
| `implement-task` | Single-task implementation worker (dispatched by implement controller) |
| `ui-design-task` | Presentation-only worker (dispatched by ui-design controller) |
| `verification-before-completion` | Evidence-before-claims gate — must run verification before claiming completion |

## Design principle: delegate to shared authored skills

The user-facing entry-point skills carry per-agent glue (workflow steps, stop/hand-off gates,
escalation rules) but delegate the heavy-lift methodology to the shared authored
skills. This avoids inlining duplicate copies of shared workflows.

### Shared authored skills

These shared skills are installed for Claude Code by setup:

- `grill-with-docs` — used by `/brainstorm`, `/planner`, `/finish` in both harnesses
- `bugfix` (including its scripts) — used by `/bugfix`
- `brainstorm` (including its preview scripts) — used by `/brainstorm`
- `planner` — used by `/planner`
- `implement` — used by `/implement`
- `implement-task` — used by `/implement`
- `ui-design` — used by `/ui-design`
- `ui-design-task` — used by `/ui-design`
- `review-code` — used by `/review-code`
- `review-plan` — used by `/review-plan`
- `finish` — used by `/finish`
- `idea` — used by `/idea`
- `feature-documentation` — used by `/finish`
- `verification-before-completion` — used by `/implement`, `/finish`
- `git-publish` — used by `/implement`, `/finish`, `/review-plan`, `/review-code` (via publish-branch.sh)
- `github-pr-comments` — used by `/review-plan`, `/review-code` in both harnesses

Remote skills (e.g. `context7-cli`, `domain-modeling`, `grilling`, `impeccable`, `writing-skills`) are declared in `skills-lock.json` and installed via the
[`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills add`). Each
is installed through the selected harness's skill mechanism.

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

## Skill inventory

All authored skills are installed through the selected harness's skill mechanism:

- **User-facing:** `brainstorm`, `bugfix`, `finish`, `grill-with-docs`, `idea`, `implement`, `planner`, `review-code`, `review-plan`, `ui-design`.
- **Hidden support:** `feature-documentation`, `git-publish`, `github-pr-comments`, `implement-task`, `planning-structure`, `ui-design-task`, `verification-before-completion`.

To add a newly-installed shared skill, run setup and approve the skill inventory
change. The harness manages its installed skill directory.

## Preview Adapter

The UI-design workflow requires a target-owned preview adapter at
`.agents/scripts/ui-design/preview.sh`. The toolkit does not supply this script — it
is a project responsibility. The adapter contract is:

- `bash .agents/scripts/ui-design/preview.sh start` — start the preview server
- `bash .agents/scripts/ui-design/preview.sh probe` — probe the server (exit 0 if ready)
- `bash .agents/scripts/ui-design/preview.sh stop` — stop the preview server

The installer preserves an existing `preview.sh` in every copy mode (add/override/skip).

## Usage

Type `/brainstorm`, `/bugfix`, `/finish`, `/idea`, `/implement`, `/planner`,
`/review-code`, `/review-plan`, or `/ui-design` (optionally with an argument,
e.g. `/planner plans/2026-05-30-foo/spec.md`).
