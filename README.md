# Agentic Coding Toolkit

A reusable agentic coding toolkit that layers OpenCode agents and Claude Code workflow skills over DDD docs and area docs.

## What the Toolkit Is

The toolkit provides a two-layer overlay model:

- **`core/`** — Always staged. Contains base agents, skills, configs, and docs.
- **`stacks/<name>/`** — Stack-specific overlay (e.g. `pnpm`, `maven`). Merged on top of core during init or copy.

Installer scripts (`init.sh`, `copy.sh`) map template directories under `core/` to dot target directories:

| Source in repo | Target dot-directory |
|---|---|
| `core/opencode/` | `.opencode/` |
| `core/claude/` | `.claude/` |
| `core/agents/` | `.agents/` |
| `core/docs/` | `docs/` |

The `.agents/skills/` tree is the single canonical source for all authored workflow skills. Entry-point agent skills under `.claude/skills/` are **symlinks** pointing to `../../.agents/skills/<name>`. This avoids duplicating skill content and keeps the OpenCode pipeline and Claude Code pipeline reading the same files.

## Target Users / Projects

Engineers who want OpenCode + Claude Code workflows with shared DDD docs, grilling, and TDD in their pnpm or Maven repos.

The toolkit is stack-agnostic in `core/`. Stack overlays add verification commands, role-doc additions, and config merges for a specific build system.

## Required Tools

| Tool | Install | Notes |
|---|---|---|
| `jq` | [Download or install via package manager](https://jqlang.github.io/jq/download/) | Required by init and copy scripts |
| `npx` (Node.js) | [Download and install](https://nodejs.org/en/download) | Runs the [`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills add …`) for remote skill installation; init.sh and copy.sh warn but do not fail when missing |
| `codespell` | [Install via pip](https://github.com/codespell-project/codespell#installation) or [brew](https://formulae.brew.sh/formula/codespell) | Spellchecks markdown templates, agent/skill files, README content, and user-facing script text |

## Quick Start: init.sh

Scaffold a brand new project:

```bash
./scripts/init.sh
```

The script prompts for:

1. **Stack** — e.g. `pnpm` or `maven`
2. **Model option** — `opencode-go only` (default) or `opencode-go + OpenAI`
3. **Target path** — where to create the project

## Quick Start: copy.sh

Merge toolkit assets into an existing project:

```bash
./scripts/copy.sh /path/to/existing-project
```

Requires a **clean Git working tree** in the target. The script validates this by checking that `git status --short` prints no output. If the working tree is dirty, the script fails with instructions to commit or stash first.

## Initial Stacks

- **pnpm** — TypeScript/Node.js monorepos
- **maven** — Java/Kotlin projects

## Model Option

During init you choose a model option:

| Option | Default | Behavior |
|---|---|---|
| `opencode-go only` | Yes | All agents use the bundled OpenCode-Go profile below |
| `opencode-go + OpenAI` | No | Applies one deterministic OpenAI overlay on top of the bundled profile for high-reasoning workflows |

### Workflow Assignments

| Workflow | Bundled OpenCode-Go profile | OpenAI overlay |
|---|---|---|
| `brainstorm` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `bugfix` | `opencode-go/qwen3.8-flash`, `max` | unchanged |
| `explore` | `opencode-go/mimo-v2.5` | unchanged |
| `finish` | `opencode-go/qwen3.8-flash` | unchanged |
| `idea` | `opencode-go/glm-5.3-flash`| `openai/gpt-5.6-sol`, `medium` |
| `implement` | `opencode-go/qwen3.8-flash` | unchanged |
| `implement-task` | `opencode-go/deepseek-v4-flash`, `high` | `openai/gpt-5.6-luna`, `xhigh` |
| `planner` | `opencode-go/qwen3.8-flash` | unchanged |
| `review-code` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `review-plan` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `ui-design` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `ui-design-task` | `opencode-go/qwen3.8-flash` | `openai/gpt-5.6-luna`, `xhigh` |

The top-level default model is Mimo V2.5 Pro, with DeepSeek V4 Flash as `small_model`.

### Model Choice Rationale

The bundled OpenCode-Go profile assigns models by workflow shape:

- **GLM 5.3 Flash** handles idea intake, brainstorming, and holistic code/plan reviews (`idea`, `brainstorm`, `review-code`, `review-plan` and `ui-design`) as the sol alternative when OpenAI is not used.
- **Qwen 3.8 Flash** handles implementation, planning, and bugfixing (`implement`, `planner`, `bugfix` and `ui-design-task`). These assignments are never overridden by OpenAI models.
- **DeepSeek V4 Flash at `high`** handles tightly bounded implementation tasks (`implement-task`). DeepSeek V4 Flash is text-only, so it is not used for UI work.
- **Mimo V2.5** handles frequent exploration and UI slices (`explore`, `ui-design-task`), where speed and cost dominate.
- **Mimo V2.5 Pro** handles controller and default work (`finish` and the top-level `model`).

When you pick the `opencode-go + OpenAI` option, the installer applies `core/models-openai.json` as a single deterministic overlay: **Sol at `medium`** takes over open-ended ideation and holistic reviews (`idea`, `brainstorm`, `review-code`, `review-plan`), while **Luna at `xhigh`** handles implementation and UI design tasks (`implement-task`, `ui-design-task`). Implementation, planning, and bugfixing (`implement`, `planner`, `bugfix`) always keep their bundled Qwen 3.8 Flash assignments and are never overridden by OpenAI models; all other workflows keep their bundled assignments.

Neither profile configures a third-party provider router, and the `opencode-go only` selection contains no `openai/` model references.

## Installed Assets

### OpenCode Agents

Under `.opencode/agents/` — agents invoked with `@agentname` in OpenCode:

`brainstorm`, `bugfix`, `finish`, `idea`, `implement`, `implement-task`, `planner`, `review-code`, `review-plan`, `ui-design`, `ui-design-task`

### Authored Reusable Skills (Single Canonical Source)

Under `.agents/skills/` — the single canonical skill tree. Every skill lives here. Those that are also visible to Claude Code are symlinked into `.claude/skills/`:

`brainstorm`, `bugfix`, `feature-documentation`, `finish`, `git-publish`, `github-pr-comments`, `grill-with-docs`, `idea`, `implement`, `implement-task`, `planner`, `planning-structure`, `review-code`, `review-plan`, `ui-design`, `ui-design-task`, `verification-before-completion`

#### Support and Worker Skills (Hidden from Users)

Hidden support skills are marked `user-invocable: false` so they stay invisible in Claude Code's user-facing skill list and are never invoked directly by the user. They are loaded by agents on demand:

| Hidden Skill | Purpose |
|---|---|
| `feature-documentation` | Compact package-driven capability maps under `docs/features/` |
| `git-publish` | Guarded Git/GitHub branch publication — protected-branch rejection, draft PR creation, lease-safe retained-head updates |
| `github-pr-comments` | GitHub PR comment fetching, classification, and reply workflow |
| `implement-task` | Single-task implementation worker — dispatched by the implement controller, not user-facing |
| `planning-structure` | Shared artifact contract for implementation and review-fix plan structures |
| `ui-design-task` | Presentation-only worker for one self-contained UI-design task packet — dispatched by ui-design controller, not user-facing |
| `verification-before-completion` | Evidence-before-claims gate — must run verification before claiming completion |

### Claude Workflow Entry Skills

Under `.claude/skills/` — all authored skills are symlinked from `.agents/skills/` to `../../.agents/skills/<name>`:

`brainstorm`, `bugfix`, `feature-documentation`, `finish`, `git-publish`, `github-pr-comments`, `grill-with-docs`, `idea`, `implement`, `implement-task`, `planner`, `planning-structure`, `review-code`, `review-plan`, `ui-design`, `ui-design-task`, `verification-before-completion`

User-facing skills are marked `disable-model-invocation: true` so they never auto-trigger and are invoked with `/skillname`; hidden support and worker skills are marked `user-invocable: false` and are loaded on demand by agents.

### DDD Docs

Under `docs/`:

- `CONTEXT-MAP.md`
- `docs/contexts/placeholder/CONTEXT.md`
- `docs/adr/0001-record-architecture-decisions.md`
- `docs/adr/ADR-TEMPLATE.md`
- `docs/features/README.md`

### Area Docs

- `docs/ARCHITECTURE.md`
- `docs/CODING_GUIDELINES.md`
- `docs/TESTING.md`
- `docs/LOGGING.md`

### Role Docs

Under `docs/agents/` — per-agent loading contracts:

`brainstorm.md`, `bugfix.md`, `finish.md`, `idea.md`, `implement.md`, `implement-task.md`, `planner.md`, `review-code.md`, `review-plan.md`, `ui-design.md`, `ui-design-task.md`

## Claude Symlink Model

All authored skills under `.agents/skills/` are symlinked into `.claude/skills/<name>` → `../../.agents/skills/<name>`. There are no "real" skill directories under `.claude/skills/` — every skill is accessed via symlink. This means:

- **OpenCode** reads agent files from `.opencode/agents/` and skill methodology from `.agents/skills/`.
- **Claude Code** reads entry-point skill files from `.claude/skills/<name>/SKILL.md`, which are real symlinked directories, and loads shared methodology from the same `.agents/skills/` tree.
- **No duplication.** A change to a skill's files under `.agents/skills/` is immediately visible to both pipelines.

| Symlink | Resolves To |
|---|---|
| `.claude/skills/<skill-name>` | `../../.agents/skills/<name>` |

Each authored skill under `.agents/skills/` carries a `SKILL.md` with frontmatter. User-facing skills are marked `disable-model-invocation: true` and are visible in Claude Code's `/` command list; hidden support and worker skills are marked `user-invocable: false`.

> **Note:** Support skills (`implement-task`, `feature-documentation`, `git-publish`, `github-pr-comments`, `planning-structure`, `ui-design-task`, `verification-before-completion`) are loaded by agents on demand, never invoked directly by the user. They remain symlinked like all other skills so Claude Code can resolve their `SKILL.md` when an agent references them.

## Recommended Human-in-the-Loop Workflow

![Workflow diagram showing the human-in-the-loop cycle: ideation and planning (steps 1–6) followed by an implementation cycle (steps 7–11). Blue icons represent human input; robot icons represent LLM agents; purple steps are think-and-plan; orange steps are reviews; green is implementation; dark is finish.](workflow.PNG)

The diagram above maps the full cycle from brainstorming a feature through to shipping documentation. Each numbered step corresponds to an agent or skill invocation you trigger at the right moment — the human checkpoints (steps 2, 5, 8) are where you pause, review, and optionally leave GitHub comments before the next AI-driven step takes over.

### Workflow Order

The canonical workflow follows this sequence:

```
idea → brainstorm → [optional ui-design] → planner → implement → review → finish
```

### Ideation & Planning (steps 1–7)

| # | Step | Invocation |
|---|---|---|
| 1 | **Idea pitch** — a rough prompt or high-level feature request. | OpenCode `@idea` or Claude `/idea`. |
| 2 | **Brainstorm feature/spec** — generate or refine a spec. Optionally grill it against existing DDD docs. | OpenCode `@brainstorm` or Claude `/brainstorm`. |
| 3 | **Human reviews the spec** — read, comment, and refine. Pause and iterate as needed. | Human checkpoint (no agent invocation). |
| 4 | **UI Design (optional)** — when presentation or visual structure decisions are needed, a ui-design phase generates HTML/CSS mockups and design tokens before planning starts. | OpenCode `@ui-design` (controller) which spawns `@ui-design-task` workers. |
| 5 | **Review spec** — validate the spec for completeness and alignment. | OpenCode `@review-plan` or Claude `/review-plan`. |
| 6 | **Planner writes the implementation plan** — break the spec into ordered, verifiable tasks. | OpenCode `@planner` or Claude `/planner`. |
| 7 | **Human reviews the plan** — confirm scope, ordering, and task granularity. | Human checkpoint (no agent invocation). |

### Implementation Cycle (steps 8–12)

| # | Step | Invocation |
|---|---|---|
| 8 | **Review plan** — final plan review before implementation begins. | OpenCode `@review-plan` or Claude `/review-plan`. |
| 9 | **Implement task-by-task** — dispatch one worker per plan task, verify, and commit. | OpenCode `@implement` (controller) which spawns `@implement-task` workers. |
| 10 | **Human comments code** — review the diff and leave inline comments or GitHub review notes. | Human checkpoint (no agent invocation). |
| 11 | **Review code** — analyze review feedback and determine required changes. | OpenCode `@review-code` or Claude `/review-code`. |
| 12 | **Finish** — write summary and feature documentation, reconcile durable docs (ADRs, context maps, etc.). | OpenCode `@finish` or Claude `/finish`. |

### Draft-First GitHub Pull-Request Publication

Publication of branches and change requests follows a draft-first model:

- **`git-publish`** — Guarded Git/GitHub branch publication. Pushes the current branch to the remote with safe defaults, prints the existing PR URL or creates a draft PR (`gh pr create --fill --draft`), and supports lease-safe retained-head updates (`--existing-pr`, `--expected-head`, `--head-branch`).

The skill is authored (not remote) and no lockfile tracks it. It lives under `.agents/skills/` and is symlinked into `.claude/skills/`.

#### Retained-Head Lease Exception

The only allowed exception to the "no force-push" rule is an explicitly authorized retained-head update through `git-publish`:

- Uses a **fully qualified lease**: `--force-with-lease=refs/heads/<head>:<expected-sha>`.
- Requires explicit human authorization per invocation.
- One attempt with no weaker-force fallback (no bare `--force` or `-f` if the lease fails).

This is encoded in the agent permissions and enforced by the publication scripts themselves.

### UI-Design Preview-First Verification Exception

The `ui-design` workflow verifies presentation output differently from code implementation:

- **Preview-first:** Design output is verified by starting a local preview server, probing it for expected visual content, and stopping the preview. This replaces the typical verification-before-completion gates.
- The adapter boundary is at `.agents/scripts/ui-design/preview.sh` — a target-owned script with three commands:
  - `start` — start the preview server
  - `probe` — probe the server and return true/false
  - `stop` — stop the preview server
- The toolkit **does not supply** this script. It is a target-owned adapter. The installer preserves an existing `preview.sh` in every copy mode (add/override/skip).
- Claude settings encode exact permissions for the three preview commands: `Bash(bash .agents/scripts/ui-design/preview.sh start)`, `Bash(bash .agents/scripts/ui-design/preview.sh probe)`, `Bash(bash .agents/scripts/ui-design/preview.sh stop)`.
- If a target overrides the preview adapter via a wrapper (e.g., Docker Compose), the new wrapper's own dependencies may require re-applying the presentation-root permissions.

## Extension Guide: Adding Future Stacks

To add a new stack:

1. Create `stacks/<new-stack>/` with:
   - `AGENTS.md`
   - `opencode.json`
   - `claude/settings.json`
   - `docs/agents/{planner,implement,implement-task,review-code,review-plan,finish}.md`

2. The stack assets are merged as follows:
   - **Stack `AGENTS.md`** is concatenated to the core `AGENTS.md` on init.
   - **Stack `opencode.json`** is deep-merged with the core one (stack values win on conflict).
   - **Stack `claude/settings.json`** permission arrays are unioned with de-duplication.
   - **Stack role-doc additions** are concatenated to the matching core role docs.

3. The `init.sh` and `copy.sh` scripts already support the new stack once the directory exists — no script changes needed.

## Self-Maintenance Agents

This repo maintains its own markdown templates and bash scripts with a small agent + skill surface. The agents and skills below are **not** installed into target projects — they are only loaded when working on this repo itself.

### Shared Conventions

`AGENTS.md` at the repo root carries the conventions every agent needs (maintenance surface, dot-mapping, sync invariants, git conventions, verification baseline). It is loaded ambiently by OpenCode and inherited by Claude Code via `CLAUDE.md`, which is a one-line file containing `@AGENTS.md`.

### Agents

Under `.opencode/agents/`:

| Agent | Mode | Purpose |
|---|---|---|
| `planning` | primary | Writes lightweight plans to `plans/YYYY-MM-DD-<feature>/plan.md` |
| `implement` | primary | Controller that dispatches `implement-task` workers per plan task |
| `implement-task` | subagent (hidden) | Worker for exactly one task — verifies, commits, reports |
| `review` | primary | Reviews plans and diffs against `AGENTS.md` conventions |

Invoke with `@planning`, `@implement`, `@implement-task`, or `@review` in OpenCode.

### Skills

Under `.agents/skills/` (symlinked into `.claude/skills/` for Claude Code compatibility):

| Skill | Purpose |
|---|---|
| `agent-planning` | Plan structure, file mapping, task granularity, self-review |
| `agent-implementation` | Controller orchestration, worker status handling, completion |
| `agent-verification` | Evidence-before-claims gate, verification commands, smoke runs |
| `agent-review` | Plan + diff review checklist aligned to `AGENTS.md` |
| `github-pr-comments` | PR comment fetching, classification, and reply workflow |
| `writing-skills` | Remote skill from `obra/superpowers` for authoring skills |

Invoke in Claude Code with `/agent-planning`, `/agent-implementation`, `/agent-verification`, `/agent-review`, or `/github-pr-comments`. The `writing-skills` skill is also exposed as `/writing-skills`.

### Lockfiles

Two lockfiles track remote skills at different scopes and are not expected to match:

- `skills-lock.json` — remote skills installed in this repo for self-maintenance. Currently tracks `writing-skills` only.
- `core/skills-lock.json` — remote skills installed into target repos by the toolkit. Currently tracks `context7-cli`, `domain-modeling` and `grilling` (from `mattpocock/skills`), `impeccable` (from `pbakaus/impeccable`), and `writing-skills`.

When updating skills, edit only the lockfile for the scope you changed.

## Future Work

Framework-specific stacks such as NestJS, Next.js/UI, Spring Boot, Java, and Kotlin conventions are out of scope. The toolkit is intentionally stack-agnostic in `core/`.

For Claude-specific workflow details, see `core/claude/README.md`.
