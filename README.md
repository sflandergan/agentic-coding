# Agentic Coding Toolkit

A reusable agentic coding toolkit that layers OpenCode agents and Claude Code workflow skills over DDD docs and area docs.

## What the Toolkit Is

The toolkit provides a two-layer overlay model:

- **`core/`** — Always staged. Contains base agents, skills, configs, and docs.
- **`stacks/<name>/`** — Stack-specific overlay (e.g. `pnpm`, `maven`). Merged on top of core during init or copy.

Installer scripts (`init.sh`, `copy.sh`) map non-dot template directories to dot target directories:

| Source | Target |
|---|---|
| `opencode/` | `.opencode/` |
| `claude/` | `.claude/` |
| `agents/` | `.agents/` |
| `docs/` | `docs/` |

## Target Users / Projects

Engineers who want OpenCode + Claude Code workflows with shared DDD docs, grilling, and TDD in their pnpm or Maven repos.

The toolkit is stack-agnostic in `core/`. Stack overlays add verification commands, role-doc additions, and config merges for a specific build system.

## Required Tools

| Tool | Install | Notes |
|---|---|---|
| `jq` | [Download or install via paket manager](https://jqlang.github.io/jq/download/) | Required by init and copy scripts |
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
3. **OpenAI brainstorm override** — when the OpenAI option is chosen, also override `brainstorm` to `openai/gpt-5.5` (y/N)
4. **Target path** — where to create the project

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
| `opencode-go only` | Yes | All agents use the bundled default model |
| `opencode-go + OpenAI` | No | Overrides `bugfix`, `review-code`, `review-plan` agents to use `openai/gpt-5.5`. Optionally also overrides `brainstorm` when you answer yes to the follow-up prompt. |

### Model Choice Rationale

The bundled `opencode.json` assigns models by workflow strength profile:

- **Strong models** for `brainstorm` (`qwen3.7-max`) and the `review*` agents (`kimi-2.7-code`). These workflows need the most reasoning depth, and the OpenAI option swaps them to `openai/gpt-5.5` for the same reason.
- **Mid-tier models** for `planner`, `finish`, and the `implement` controller (`mimo-v2.5-pro`). These need reliability and structured output but not the strongest reasoning.
- **Cheap / fast models** for `explore` and `implement-task` (`mimo-v2.5`). These are invoked frequently on tightly scoped work, so speed and cost dominate.
- **Mimo vs. DeepSeek** is mainly a preference tradeoff. Both are reliable and produce good results; this toolkit defaults to `mimo-v2.5*` because it has been more consistent for these workflows.
- **Minimax** (`minimax-m3`) is intentionally not the default. It is not selected because its availability and value outside of promotional periods is weaker than the families above for this workload. It remains a usable alternative for individual agents via `opencode.json` overrides.

When you pick the `opencode-go + OpenAI` option, the installer applies `core/models-openai.json`, which overrides `bugfix`, `review-code`, and `review-plan` to `openai/gpt-5.5`. Because brainstorming also benefits from the strongest model available, the installer follows up with a yes/no prompt: answering yes adds a `brainstorm` override on top so `brainstorm` uses `openai/gpt-5.5` as well. Answering no leaves `brainstorm` on its bundled strong model.

## Installed Assets

### OpenCode Agents

Under `.opencode/agents/`:

`brainstorm`, `bugfix`, `finish`, `implement`, `implement-task`, `planner`, `review-code`, `review-plan`

### Claude Workflow Entry Skills

Under `.claude/skills/` (all marked `disable-model-invocation: true`):

`brainstorm`, `bugfix`, `implement`, `finish`, `planner`, `review-code`, `review-plan`

### Authored Reusable Skills

Under `.agents/skills/`:

`grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `git-publish`, `change-request-publish`, `change-request-comments`, `issue-tracker`

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

Under `docs/agents/` — per-agent loading contracts. See the individual files for details.

## Claude Symlink Model

The workflow entry skills are real directories. The authored skills are symlinked into `.claude/skills/` from `.agents/skills/`:

| Skill | Symlink Target |
|---|---|
| `grill-with-docs` | `../../.agents/skills/grill-with-docs` |
| `workflow-bug-analysis` | `../../.agents/skills/workflow-bug-analysis` |
| `workflow-brainstorming` | `../../.agents/skills/workflow-brainstorming` |
| `workflow-planning` | `../../.agents/skills/workflow-planning` |
| `workflow-verification` | `../../.agents/skills/workflow-verification` |
| `feature-documentation` | `../../.agents/skills/feature-documentation` |
| `git-publish` | `../../.agents/skills/git-publish` |
| `change-request-publish` | `../../.agents/skills/change-request-publish` |
| `change-request-comments` | `../../.agents/skills/change-request-comments` |
| `issue-tracker` | `../../.agents/skills/issue-tracker` |
| `workflow-implementation` | `../../.agents/skills/workflow-implementation` |

Each symlinked skill has `user-invocable: false` in its `SKILL.md` frontmatter so it stays hidden from Claude Code's user-facing skill list.

## Recommended Human-in-the-Loop Workflow

![Workflow diagram showing the human-in-the-loop cycle: ideation and planning (steps 1–6) followed by an implementation cycle (steps 7–11). Blue icons represent human input; robot icons represent LLM agents; purple steps are think-and-plan; orange steps are reviews; green is implementation; dark is finish.](workflow.PNG)

The diagram above maps the full cycle from brainstorming a feature through to shipping documentation. Each numbered step corresponds to an agent or skill invocation you trigger at the right moment — the human checkpoints (steps 2, 5, 8) are where you pause, review, and optionally leave GitHub comments before the next AI-driven step takes over.

### Ideation & Planning (steps 1–6)

| # | Step | Invocation |
|---|---|---|
| 1 | **Brainstorm feature/spec** — generate or refine a spec. Optionally grill it against existing DDD docs. | OpenCode `@brainstorm` or Claude `/brainstorm`. |
| 2 | **Human reviews the spec** — read, comment, and refine. Pause and iterate as needed. | Human checkpoint (no agent invocation). |
| 3 | **Review spec** — validate the spec for completeness and alignment. | OpenCode `@review-plan` or Claude `/review-plan`. |
| 4 | **Planner writes the implementation plan** — break the spec into ordered, verifiable tasks. | OpenCode `@planner` or Claude `/planner`. |
| 5 | **Human reviews the plan** — confirm scope, ordering, and task granularity. | Human checkpoint (no agent invocation). |
| 6 | **Review plan** — final plan review before implementation begins. | OpenCode `@review-plan` or Claude `/review-plan`. |

### Implementation Cycle (steps 7–11)

| # | Step | Invocation |
|---|---|---|
| 7 | **Implement task-by-task** — dispatch one worker per plan task, verify, and commit. | Claude `/implement` or OpenCode `@implement` (controller) which spawns implement-task workers. Pick one harness per branch. |
| 8 | **Human comments code** — review the diff and leave inline comments or change-request review notes. | Human checkpoint (no agent invocation). |
| 9 | **Review code** — analyze review feedback and determine required changes. | OpenCode `@review-code` or Claude `/review-code`. |
| 10 | **Review / Remark plan** — if code review surfaces scope changes, update the plan and loop back to step 7. Repeat until the plan is sound and complete. | OpenCode `@planner` or Claude `/planner` to revise; then re-enter implementation at step 7. |
| 11 | **Finish** — write summary and feature documentation, reconcile durable docs (ADRs, context maps, etc.). | OpenCode `@finish` or Claude `/finish`. |

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
| `change-request-comments` | Comment fetching, classification, and reply workflow |
| `writing-skills` | Remote skill from `obra/superpowers` for authoring skills |

Invoke in Claude Code with `/agent-planning`, `/agent-implementation`, `/agent-verification`, `/agent-review`, or `/change-request-comments`. The `writing-skills` skill is also exposed as `/writing-skills`.

### Lockfiles

Two lockfiles track remote skills at different scopes and are not expected to match:

- `skills-lock.json` — remote skills installed in this repo for self-maintenance.
- `core/skills-lock.json` — remote skills installed into target repos by the toolkit.

When updating skills, edit only the lockfile for the scope you changed.

## Future Work

Framework-specific stacks such as NestJS, Next.js/UI, Spring Boot, Java, and Kotlin conventions are out of scope. The toolkit is intentionally stack-agnostic in `core/`.

For Claude-specific workflow details, see `core/claude/README.md`.
