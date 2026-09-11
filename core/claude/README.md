# Claude Code agent setup

Claude Code runs the **conversational** half of the agent pipeline. The
**implementation** half stays in OpenCode. There is deliberately
**no orchestrator**: the OpenCode hand-off ends the Claude Code session, and reviews are
triggered by hand, so the workflows are discrete, manually-invoked entry points.

## Skills

The canonical skill source is `.agents/skills/`. Every skill under `.claude/skills/`
is a **symlink** to `../../.agents/skills/<name>`. This avoids duplication — both
OpenCode and Claude Code read the same files.

User-facing skills are marked `disable-model-invocation: true` so they never
auto-trigger and stay out of the always-loaded skill index. Hidden support and
worker skills are additionally marked `user-invocable: false` so they stay out
of the user-facing skill list and are loaded by agents on demand.

### User-Facing Skills (invoked with `/name`)

| Skill (`/name`) | OpenCode counterpart | Role |
| --- | --- | --- |
| `/brainstorm` | `@brainstorm` | Idea → approved `spec.md` (interactive; offers domain grilling) |
| `/bugfix` | `@bugfix` | Investigate bug → structured GitHub issue; does not fix |
| `/finish` | `@finish` | Durable feature doc, light glossary/ADR reconciliation, cleanup |
| `/idea` | `@idea` | Rough prompt → structured feature pitch |
| `/implement` | `@implement` | Controller that dispatches `@implement-task` workers per plan task |
| `/planner` | `@planner` | Spec → task-by-task `plan.md` (offers grilling only when new domain language or non-trivial decisions appear) |
| `/review-code` | `@review-code` | Review a diff/PR → fix-plan hand-off doc |
| `/review-plan` | `@review-plan` | Review + finalize the OpenCode hand-off plan |
| `/ui-design` | `@ui-design` | Presentation design → HTML/CSS mockups, design tokens; dispatches `@ui-design-task` workers |
| `/grill-with-docs` | — | Domain grilling against DDD docs (loaded on demand by others) |

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
escalation rules) but delegate the heavy-lift methodology to authored skills under
`.agents/skills/`. This avoids inlining duplicate copies of shared workflows.

### Shared authored skills

These shared skills are symlinked into `.claude/skills/` from `.agents/skills/`:

- `grill-with-docs` — used by `/brainstorm`, `/planner`, `/finish` (+ OpenCode)
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
- `github-pr-comments` — used by `/review-plan`, `/review-code` (+ OpenCode)

Remote skills (e.g. `context7-cli`, `domain-modeling`, `grilling`, `impeccable`, `writing-skills`) are declared in `skills-lock.json` and installed via the
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

All authored skills are symlinked from `.agents/skills/`:

- **User-facing:** `brainstorm`, `bugfix`, `finish`, `grill-with-docs`, `idea`, `implement`, `planner`, `review-code`, `review-plan`, `ui-design`.
- **Hidden support:** `feature-documentation`, `git-publish`, `github-pr-comments`, `implement-task`, `planning-structure`, `ui-design-task`, `verification-before-completion`.

To add a newly-installed shared skill:
`ln -s ../../.agents/skills/<name> .claude/skills/<name>`. `.claude/skills/` is hand-managed
during init and copy; the installers maintain these symlinks automatically.

## Preview Adapter

The UI-design workflow requires a target-owned preview adapter at
`.agents/scripts/ui-design/preview.sh`. The toolkit does not supply this script — it
is a project responsibility. The adapter contract is:

- `bash .agents/scripts/ui-design/preview.sh start` — start the preview server
- `bash .agents/scripts/ui-design/preview.sh probe` — probe the server (exit 0 if ready)
- `bash .agents/scripts/ui-design/preview.sh stop` — stop the preview server

The installer preserves an existing `preview.sh` in every copy mode (add/override/skip).
If a target replaces the adapter with a wrapper (e.g., Docker Compose), the new wrapper's
dependencies may require re-applying the presentation-root permissions.

## Permissions

`settings.json` encodes the project-wide permission union the skills need: edit
allowed; read-only git and common Unix commands allowed; `git push` / `gh pr create` /
`rm` ask first; branch-delete, worktree-remove denied. The three preview-adapter commands
are allowed explicitly.

## Usage

Type `/brainstorm`, `/bugfix`, `/finish`, `/idea`, `/implement`, `/planner`,
`/review-code`, `/review-plan`, or `/ui-design` (optionally with an argument,
e.g. `/planner plans/2026-05-30-foo/spec.md`).
