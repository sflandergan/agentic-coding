# Agentic Coding Toolkit

A reusable agentic coding toolkit that combines shared workflow skills, native
harness agents, and DDD docs and area docs.

## What the Toolkit Is

The release is organized around three canonical source trees:

| Source path | Contents |
|---|---|
| `skills/` | Authored workflow skills, installed through the Vercel `skills` CLI |
| `agents/` | Harness-native agents: OpenCode primary agents and cross-harness workers |
| `templates/` | Target-repository instructions, role docs, and harness configuration |

`manifest.json` is the release inventory. It records the authored and pinned
skills, agent sets, templates, plugin manifests, requirements, asset hashes, and
retired assets. `stacks/<name>/` contains optional stack overlays such as `pnpm`
and `maven`.

The legacy installer scripts are retained for one transition release only. They
are deprecated and will be removed in the next release; new installations must
use the `setup` skill.

## Target Users / Projects

Engineers who want OpenCode, Claude Code, or Codex workflows with shared DDD
docs, grilling, and TDD in their pnpm or Maven repositories.

The toolkit is stack-agnostic. Stack overlays add verification commands,
role-document additions, and configuration merges for a specific build system.

## Required Tools

| Tool | Install | Notes |
|---|---|---|
| `jq` | [Download or install via package manager](https://jqlang.github.io/jq/download/) | Used by the deprecated installer scripts and release validation |
| `npx` (Node.js) | [Download and install](https://nodejs.org/en/download) | Runs the [`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills add …`) |
| `codespell` | [Install via pip](https://github.com/codespell-project/codespell#installation) or [brew](https://formulae.brew.sh/formula/codespell) | Spellchecks markdown templates, agent/skill files, README content, and user-facing script text |

## Quick Start: the setup skill

Install `setup` inside the target Git repository. Project scope is recommended
because each repository can choose its own release, harnesses, and
configuration.

### Stable bootstrap

List the published tags, choose a semantic-version tag, and install `setup`
from that exact tag:

```bash
git ls-remote --tags --refs https://github.com/sflandergan/agentic-coding-next
tag='vMAJOR.MINOR.PATCH' # set this to a listed semantic-version tag
npx skills add https://github.com/sflandergan/agentic-coding-next/tree/$tag --skill setup --agent claude-code --agent opencode --agent codex --yes
npx skills add https://github.com/sflandergan/agentic-coding-next/tree/$tag --skill setup --agent claude-code --agent opencode --agent codex --yes --global
```

Use the first command for project scope and the second for global scope.

### Preview bootstrap (`main`)

`main` is preview content. Select it explicitly when preview behavior is wanted:

```bash
toolkit_remote='https://github.com/sflandergan/agentic-coding-next'
npx skills add "$toolkit_remote/tree/main" --skill setup --agent claude-code --agent opencode --agent codex --yes
npx skills add "$toolkit_remote/tree/main" --skill setup --agent claude-code --agent opencode --agent codex --yes --global
```

After bootstrap, invoke `/setup` (or the harness's equivalent skill invocation)
and approve its proposed reconciliation. Setup reads the selected release's
`manifest.json`; it does not copy skills from a fetched checkout.

Global installation still requires running from an existing Git repository. It
affects the user's other repositories and sessions, and all of them share one
installed skill and agent version; use project scope when repositories need
independent release versions or harness configuration.

## Legacy installer scripts

`scripts/init.sh` and `scripts/copy.sh` are deprecated and will be removed in
the next release. During this one-release transition window they remain
available for existing users, but they do not replace the setup workflow. The
scripts scaffold or merge the legacy template layout and should not be used for
new installations.

## Initial Stacks

- **pnpm** — TypeScript/Node.js monorepos
- **maven** — Java/Kotlin projects

## OpenCode model profiles

Setup inspects the target environment and proposes model or permission changes
for explicit approval. It offers two named profiles:

| Profile | Default | Behavior |
|---|---|---|
| `opencode-go` | Yes | Uses the bundled OpenCode-Go assignments below |
| `opencode-go-openai` | No | Adds the deterministic OpenAI overlay to the bundled assignments |

When existing model values are retained instead of selecting either profile,
setup records `configuration.opencodeModelProfile: custom-retained`.

### Workflow Assignments

| Workflow | `opencode-go` | OpenAI overlay in `opencode-go-openai` |
|---|---|---|
| `brainstorm` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `bugfix` | `opencode-go/qwen3.8-flash` | unchanged |
| `explore` | `opencode-go/mimo-v2.5` | unchanged |
| `finish` | `opencode-go/qwen3.8-flash` | unchanged |
| `idea` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `implement` | `opencode-go/qwen3.8-flash` | unchanged |
| `implement-task` | `opencode-go/deepseek-v4-flash`, `high` | `openai/gpt-5.6-luna`, `xhigh` |
| `planner` | `opencode-go/qwen3.8-flash` | unchanged |
| `review-code` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `review-plan` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `ui-design` | `opencode-go/glm-5.3-flash` | `openai/gpt-5.6-sol`, `medium` |
| `ui-design-task` | `opencode-go/qwen3.8-flash` | `openai/gpt-5.6-luna`, `xhigh` |

The top-level default model is Qwen 3.8 Flash, with DeepSeek V4 Flash as
`small_model`. The OpenAI overlay changes only the workflows shown in the
table; neither profile configures a third-party provider router.

## Installed Assets

### Authored skills

The authored skills live under the release's canonical `skills/` tree:

`brainstorm`, `bugfix`, `feature-documentation`, `finish`, `git-publish`, `github-pr-comments`, `grill-with-docs`, `idea`, `implement`, `implement-task`, `planner`, `planning-structure`, `review-code`, `review-plan`, `setup`, `ui-design`, `ui-design-task`, `verification-before-completion`

The `setup` skill installs skills through the Vercel `skills` CLI. Claude Code
and Codex plugins can provide the authored skills for their harnesses; setup
checks plugin coverage first and installs only uncovered skills. OpenCode and
other harnesses use the Vercel CLI skill installation mechanism. The toolkit
does not ask target repositories to maintain a copied canonical skill tree or
manually-created Claude skill symlinks.

### Harness agents

OpenCode has first-class orchestration agents. Its **primary agents** under
`agents/opencode/primary/` are:

`brainstorm`, `bugfix`, `idea`, `planner`, `implement`, `review-plan`, `review-code`, `finish`, `ui-design`

Its **worker subagents** under `agents/opencode/subagents/` are:

`implement-task`, `ui-design-task`

The same two cross-harness workers are available under `agents/claude/` as
Claude Code subagents and under `agents/codex/` as Codex TOML subagents:

`implement-task`, `ui-design-task`

Claude Code additionally receives `agents/claude/explore.md`, which shadows the
built-in `Explore` so repository investigation runs read-only on Haiku instead
of inheriting the main conversation's model.

OpenCode primary agents dispatch the workers; Claude Code and Codex receive
the worker subagents without the OpenCode primary-agent layer. Other harnesses
receive the skills only and have no native agent bundle in this release.

Setup-managed native agents use `.opencode/agents/*.md`,
`.claude/agents/*.md`, and `.codex/agents/*.toml` in project scope. Global
agents use the harness-logical `agent/` or `agents/` targets under the selected
harness home; the state file does not store absolute home paths.

### Project templates and docs

The `templates/` tree contains candidate target-repository instructions, role
docs, and harness configuration contributions. Setup proposes documentation and
context assets when repository discovery justifies them:

- `templates/AGENTS.md` and `templates/CLAUDE.md` — instruction entry points
- `templates/docs/agents/` — per-agent loading contracts
- `templates/docs/` — context maps, ADRs, feature docs, and area guidance
- `templates/opencode/` — OpenCode configuration and model profiles
- `templates/claude/` — Claude Code configuration
- `templates/codex/` — Codex configuration

Stack overlays under `stacks/<name>/` add only stack-specific guidance and
configuration after the selected OpenCode model profile. Initial overlays are
`pnpm` and `maven`; their OpenCode overlays contribute permission rules, not
model assignments.

## Skill installation and ownership

For target repositories, `npx skills add` is the supported distribution path.
The Vercel CLI manages installed skills and its `skills-lock.json`; setup uses
that mechanism rather than copying a fetched release checkout. A Claude Code or
Codex `agentic-coding` plugin owns authored skills only when its installed
metadata exposes those skills, so setup excludes those skills from Vercel-managed
installation for that harness. Uncovered authored skills and pinned third-party
skills remain Vercel-managed. Project-owned skills and documentation remain
untouched unless the user approves a change.

This repository's own self-maintenance runtime is separate: its local
`.agents/skills/` entries and `.claude/skills/` links are retained for the
agents that maintain this toolkit. That internal arrangement is not the target
repository distribution contract.

### Reconciliation state

A successful reconciliation writes `.agentic-coding.json`. Its `release` object
records the selected `ref`, `channel`, and immutable `commit`. For each harness,
`skillDistribution` records `authored` and `thirdParty` channels as `plugin` or
`vercel-cli`; `managedAssets` records each approved asset's ID, harness, scope,
logical target, and release hash; `configuration.contributions` records approved
managed configuration keys and values; and `retained` records existing content
with its asset ID, logical target, observed source, and reason. The state
records ownership and outcomes, not conversation text or a duplicate Vercel
lockfile.

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

## Setup reconciliation flow

`setup` is an interactive, reversible workflow. It begins with repository
discovery and release selection, resolves the selected ref and channel once to
an immutable commit, and then routes to the workflow for the repository's
state. Fresh setup and legacy adoption use the installation route; managed
repositories use the upgrade, repair, or reconfiguration route. Each route
shows findings, requests approval before writes, preserves unrelated project
content, and verifies the resulting assets and state.

### Modes and lifecycle

The same `setup` entry point determines the mode from repository evidence:

- **Fresh setup:** neither a usable `.agentic-coding.json` nor recognizable
  toolkit content exists. Discovery and a complete scoped proposal come first;
  a dirty tree requires approval before setup continues.
- **Legacy adoption:** recognizable skills, agents, role documents, or
  configuration exist without usable state. Setup classifies each candidate as
  exact, modified, or unproven against the selected release source or hash,
  presents the mapping, and obtains approval before adoption. An existing
  Vercel lockfile is not required.
- **Managed installation:** a valid `.agentic-coding.json` identifies an
  existing installation. Setup checks for a newer stable release or an
  explicitly selected preview, then offers upgrade, repair, or
  reconfiguration.

Stable and preview channels never switch silently, and the installed immutable
commit remains recorded in state. Upgrades reconcile the complete inventory
according to each harness's plugin or Vercel CLI ownership, update managed
assets, and propose retired assets for explicit removal. A changed Vercel-managed
`setup` skill is refreshed by itself and requires reinvocation; a changed
plugin-managed `setup` requires the owning plugin to be updated. Repair keeps
the installed release unless an upgrade is approved, while reconfiguration
changes only the selected scope, harness, distribution, configuration, model,
or documentation fields.

Same-name content is never auto-overwritten. Conflict choices follow one table:

| Evidence | Choices |
|---|---|
| Exact selected-release content | Adopt or replace |
| Modified or unproven content | Replace, rename then replace, or retain |
| Modified managed native asset | Replace or retain |
| Retired managed asset | Remove or retain |
| Project-owned documentation | Apply the displayed targeted edit or keep current text |

Retention records a warning and observed source; it does not claim that
selected-release content is installed. Documentation remains project-owned.

Failed operations report their actual on-disk result and keep the prior recorded
release unchanged; incomplete required work is not reported as successful.
Scratch is removed after successful verification and retained for recovery after
a failure.

## Installation scope and harness support

Project scope is the recommended default. It keeps skills, native agents, and
release upgrades isolated to one repository. Global scope is useful for a
shared personal setup, but its skills and native agents use one shared version
across the user's repositories and sessions. Use project scope when different
repositories need different releases or harness configuration.

The three first-class harnesses are Claude Code, OpenCode, and Codex. OpenCode
provides the primary workflow controllers and the cross-harness worker
subagents. Claude Code and Codex use shared skills as their workflow entry
points and receive the same worker subagents. Other compatible harnesses can
install the skills, but this toolkit creates no native agent definitions for
them.

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

The skill is authored (not remote), so it lives under the canonical
`skills/git-publish/` tree and is included in the authored-skill inventory.

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
- The toolkit **does not supply** this script. It is a target-owned adapter.
  Setup preserves an existing adapter rather than silently replacing it.
- Claude settings encode exact permissions for the three preview commands: `Bash(bash .agents/scripts/ui-design/preview.sh start)`, `Bash(bash .agents/scripts/ui-design/preview.sh probe)`, `Bash(bash .agents/scripts/ui-design/preview.sh stop)`.
- If a target overrides the preview adapter via a wrapper (e.g., Docker Compose), the new wrapper's own dependencies may require re-applying the presentation-root permissions.

## Maintainers: releasing the toolkit

Stable releases are published by the manual **Stable release** workflow
(`.github/workflows/release-stable.yml`). `main` permanently declares
`main`/`preview`; stable release metadata is never committed to `main`. The
workflow builds a release-only commit on top of the selected preview revision,
tags it, and pushes only the tag, so preview tracking repositories are never
disturbed by metadata-restoration commits.

To publish a release, dispatch the workflow with a bump selector:

```bash
gh workflow run release-stable.yml --ref main -f bump=patch
```

The workflow computes the next version from the highest existing stable tag
(a `patch` bump of `v2.1.0` publishes `v2.1.1`). Optionally pass
`-f source_revision=<branch-or-sha>` to release from a specific preview
revision (default `main`). The workflow validates the computed version and
repository state, prepares the stable manifest with
`scripts/prepare-release.sh`, runs `scripts/validate-release.sh` and the setup
test suite, creates the release-only commit and annotated tag, verifies the
tagged tree locally, pushes only `refs/tags/<version>`, and re-resolves the
published tag from the remote.

After the run succeeds, verify the release manually:

```bash
toolkit_remote='https://github.com/sflandergan/agentic-coding-next'
release_ref='v2.1.1'
release_path='.temp/release.json'
mkdir -p .temp
skills/setup/scripts/resolve-release.sh "$toolkit_remote" stable "$release_ref" "$release_path"
jq -e --arg ref "$release_ref" '.ref == $ref and .channel == "stable"' "$release_path"
```

Recovery rules:

- If the workflow fails before the push step, nothing was published; fix the
  cause and re-run.
- If the push fails because the remote tag already exists, do not force-push.
  Compare the remote tag's commit and manifest with the intended release and
  resolve the conflict explicitly.
- If post-push verification reports a mismatch, leave the immutable tag in
  place and investigate; never delete or move a published tag.

To exercise the preparation mechanics locally without pushing, run the script
against a scratch clone in `.temp/`:

```bash
rm -rf .temp/release-smoke
git clone --quiet --branch main . .temp/release-smoke
(cd .temp/release-smoke && bash scripts/prepare-release.sh --compute-version patch)
(cd .temp/release-smoke && bash scripts/prepare-release.sh v0.0.999)
git -C .temp/release-smoke checkout -- manifest.json
rm -rf .temp/release-smoke
```

The tagged `manifest.json` and declared assets are the immutable release source
that setup fetches and verifies.

## Extension Guide: Adding Future Stacks

To add a new stack:

1. Create `stacks/<new-stack>/` with:
   - `AGENTS.md`
   - `opencode.json`
   - `claude/settings.json`
   - `docs/agents/{planner,implement,implement-task,review-code,review-plan,finish}.md`

2. The stack assets are merged as follows:
    - **Stack `AGENTS.md`** is proposed as an addition to `templates/AGENTS.md`.
     - **Stack `opencode.json`** is deep-merged after the selected model profile; stack values win only for stack-owned keys.
    - **Stack `claude/settings.json`** permission arrays are unioned with de-duplication.
    - **Stack role-doc additions** are concatenated to the matching `templates/docs/agents/` role docs.

3. The `setup` skill proposes stack additions after repository evidence is
   inspected. The deprecated `init.sh` and `copy.sh` scripts retain their
   transition-window stack support.

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

Under `.agents/skills/` (with local `.claude/skills/` links for this repository's
self-maintenance runtime only):

| Skill | Purpose |
|---|---|
| `agent-planning` | Plan structure, file mapping, task granularity, self-review, and skill-change evaluation requirements |
| `agent-implementation` | Controller orchestration, worker status handling, skill evaluation gate, and completion |
| `agent-verification` | Evidence-before-claims gate, skill evaluation results, verification commands, and smoke runs |
| `agent-review` | Plan + diff review checklist, including skill evaluation evidence, aligned to `AGENTS.md` |
| `github-pr-comments` | PR comment fetching, classification, and reply workflow |
| `test-driven-development` | Remote skill from `obra/superpowers` — TDD discipline for feature and bugfix work |
| `writing-skills` | Remote skill from `obra/superpowers` for authoring skills |

Invoke in Claude Code with `/agent-planning`, `/agent-implementation`, `/agent-verification`, `/agent-review`, or `/github-pr-comments`. The `test-driven-development` and `writing-skills` skills are also exposed as `/test-driven-development` and `/writing-skills`.

### Lockfiles

Two lockfiles track remote skills at different scopes and are not expected to match:

- `skills-lock.json` — remote skills installed in this repo for self-maintenance. Currently tracks `test-driven-development` and `writing-skills` (both from `obra/superpowers`).
- `core/skills-lock.json` — remote skills installed into target repos by the toolkit. Currently tracks `context7-cli`, `domain-modeling` and `grilling` (from `mattpocock/skills`), `impeccable` (from `pbakaus/impeccable`), and `test-driven-development` and `writing-skills` (from `obra/superpowers`).

When updating skills, edit only the lockfile for the scope you changed.

## Future Work

Framework-specific stacks such as NestJS, Next.js/UI, Spring Boot, Java, and Kotlin conventions are out of scope. The toolkit is intentionally stack-agnostic; add stack-specific behavior through `stacks/<name>/` overlays.

For Claude-specific workflow details, see `templates/claude/README.md`.
