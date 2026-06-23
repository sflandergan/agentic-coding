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
| `jq` | [Official jq install docs](https://jqlang.github.io/jq/download/) | Required by init and copy scripts |
| `ctx7` | [Upstream docs](https://github.com/upstash/context7) | Used for remote skill installation; init.sh and copy.sh warn but do not fail when missing |

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

- **Strong models** for `brainstorm` (`qwen3.7-max`) and the three `review*` agents (`kimi-2.7-code`). These workflows need the most reasoning depth, and the OpenAI option swaps them to `openai/gpt-5.5` for the same reason.
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

`brainstorm`, `bugfix`, `finish`, `planner`, `review-code`, `review-plan`

### Authored Reusable Skills

Under `.agents/skills/`:

`grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `github-pr-comments`

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

The 6 workflow entry skills are real directories. The 7 authored skills are symlinked into `.claude/skills/` from `.agents/skills/`:

| Skill | Symlink Target |
|---|---|
| `grill-with-docs` | `../../.agents/skills/grill-with-docs` |
| `workflow-bug-analysis` | `../../.agents/skills/workflow-bug-analysis` |
| `workflow-brainstorming` | `../../.agents/skills/workflow-brainstorming` |
| `workflow-planning` | `../../.agents/skills/workflow-planning` |
| `workflow-verification` | `../../.agents/skills/workflow-verification` |
| `feature-documentation` | `../../.agents/skills/feature-documentation` |
| `github-pr-comments` | `../../.agents/skills/github-pr-comments` |

Each symlinked skill has `user-invocable: false` in its `SKILL.md` frontmatter so it stays hidden from Claude Code's user-facing skill list.

> **Note:** `workflow-implementation` is **not** symlinked into Claude — it is reserved for OpenCode's `@implement` / `@implement-task` flow.

## Recommended Human-in-the-Loop Workflow

| # | Step |
|---|---|
| 1 | Brainstorm feature/spec; optionally grill with docs. |
| 2 | Human reviews the spec and may comment on GitHub. |
| 3 | Run `review-plan` on the spec when needed. |
| 4 | Planner writes the implementation plan. |
| 5 | Human reviews the plan and may comment on GitHub. |
| 6 | Run `review-plan` on the plan. |
| 7 | Implement task-by-task (OpenCode `@implement` / `@implement-task`). |
| 8 | Human reviews code and may comment on GitHub. |
| 9 | Run `review-code`. |
| 10 | Implement review fixes and repeat review/fix cycles as needed. |
| 11 | `finish` writes summary/feature documentation and reconciles durable docs. |

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

## Future Work

Framework-specific stacks such as NestJS, Next.js/UI, Spring Boot, Java, and Kotlin conventions are out of scope. The toolkit is intentionally stack-agnostic in `core/`.

For Claude-specific workflow details, see `core/claude/README.md`.
