# PR Review Comments Implementation Plan

## Goal

Address the review comments on PR #1 by making the toolkit more project-agnostic, aligning Claude Code entry skills with their OpenCode counterparts, cleaning misplaced role-doc guidance, and documenting model-selection tradeoffs without adding the separate push-safety script.

## Scope

- Align Claude workflow entry skills with the matching OpenCode agents.
- Remove project-specific reusable-skill content and the database helper script.
- Fix incorrect authored-skill paths and Claude settings permissions.
- Clean redundant files and duplicated root guidance.
- Correct role-doc loading contracts and stack overlay guidance.
- Improve generic docs and README model/tooling documentation.
- Add an OpenAI-option user question for whether brainstorming should use `openai/gpt-5.5`.

## Non-Goals

- Do not add a safe push helper script or skill in this PR.
- Do not resolve PR comments on GitHub automatically.
- Do not change model defaults beyond the documented/scripted OpenAI-option behavior.

## Tasks

### 1. Align Claude Skills With OpenCode Agents

- Update `core/claude/skills/brainstorm/SKILL.md` to mirror `core/opencode/agents/brainstorm.md`.
- Update `core/claude/skills/planner/SKILL.md` to mirror `core/opencode/agents/planner.md`.
- Update `core/claude/skills/finish/SKILL.md` to mirror `core/opencode/agents/finish.md`.
- Update `core/claude/skills/review-code/SKILL.md` to mirror `core/opencode/agents/review-code.md`.
- Update `core/claude/skills/review-plan/SKILL.md` to mirror `core/opencode/agents/review-plan.md`.
- Remove “symlinked authored skill” wording from Claude entry prompts.
- Use direct `@explore` wording instead of “Dispatch the Explore subagent via the Agent tool.”
- Keep Claude-specific invocation syntax where appropriate, such as `/planner` for user-facing Claude continuation.
- Preserve the Claude boundary that implementation remains outside Claude.

### 2. Correct Grilling Documentation

- Update `core/claude/README.md` so it matches OpenCode behavior.
- Document that `brainstorm` offers `grill-with-docs`, not automatic grilling.
- Document that `planner` offers grilling only when new domain language or non-trivial decisions appear.
- Document that `finish` only performs light domain-doc reconciliation.
- Remove the “first release” sentence about future implementation changes.

### 3. Make Reusable Skills Project-Agnostic

- Update `core/agents/skills/feature-documentation/SKILL.md`.
- Remove API-vs-crawler-vs-database ownership wording.
- Remove product-specific API assumptions like unauthenticated `/api/**`.
- Replace the default `Jobs / Workflows` section with optional generic “Background Work / Operational Flows” wording.
- Update `core/agents/skills/grill-with-docs/CONTEXT-FORMAT.md` with neutral placeholder examples.
- Update `core/agents/skills/grill-with-docs/SKILL.md` with neutral placeholder examples.
- Delete `core/agents/skills/workflow-bug-analysis/scripts/db.sh`.
- Remove the database-query step and `db.sh` examples from `core/agents/skills/workflow-bug-analysis/SKILL.md`.
- Remove related deleted-script permissions from `core/claude/settings.json`.

### 4. Fix Relative Skill Paths

- Update `core/agents/skills/workflow-brainstorming/SKILL.md` to reference `./visual-companion.md`.
- Update `core/agents/skills/workflow-brainstorming/visual-companion.md` to use relative script paths like `./scripts/start-server.sh`.
- Remove `.opencode/skills/workflow-brainstorming/...` paths from authored reusable skills.

### 5. Fix Claude Settings Script Paths

- Change GitHub PR comment script permissions in `core/claude/settings.json` from `.agents/skills/...` to Claude-visible `.claude/skills/...` symlink paths.
- Remove the deleted `workflow-bug-analysis/scripts/db.sh` permission.
- Keep create/update bug issue script permissions only if those scripts remain.

### 6. Clean Redundant Files And Guidance

- Delete `.gitkeep` files in directories that already contain real files, at least `core/agents/skills/github-pr-comments/.gitkeep`.
- Check other commented `.gitkeep` candidates only if they are similarly redundant.
- Update `core/AGENTS.md`.
- Remove role-doc loading guidance if it belongs only in agent/skill prompts.
- Remove duplicated `git rm` guidance in the Permissions section.

### 7. Fix Role-Doc Loading Contracts

- Update `core/docs/agents/implement.md` so it loads the approved plan and loads the spec if present.
- Update `core/docs/agents/review-code.md` so the approved plan is required and the approved spec is optional/if present.
- Remove stack overlay role-doc snippets marked as misplaced:
  - `stacks/maven/docs/agents/implement-task.md`
  - `stacks/maven/docs/agents/implement.md`
  - `stacks/maven/docs/agents/review-plan.md`
  - `stacks/pnpm/docs/agents/finish.md`
  - `stacks/pnpm/docs/agents/implement.md`
- Delete files that become empty and confirm init/copy overlay handling tolerates their absence.

### 8. Make Generic Docs Language-Agnostic

- Update `core/docs/CODING_GUIDELINES.md`.
- Replace “functions” with language-neutral wording such as “units of behavior.”
- Update `core/docs/TESTING.md`.
- Remove the fixed `<package>/src/test` layout example.
- Replace it with framework-convention guidance.

### 9. Update README And Model Choice Flow

- Update `README.md` required tools.
- Replace `brew install jq` with a link to official jq installation docs.
- Add model-choice rationale:
  - Strong models for brainstorming and review.
  - Mid-tier models for planning and implementation orchestration.
  - Cheap/fast models for exploration and implementation tasks.
  - Mimo vs DeepSeek is a preference/reliability tradeoff.
  - Minimax is not default due to weaker availability/value outside promotions.
- Add OpenAI model option behavior that asks whether `brainstorm` should also be overridden to `openai/gpt-5.5`.
- Implement that prompt in `scripts/init.sh` and `scripts/copy.sh` if those scripts currently apply `core/models-openai.json` automatically.
- Ensure `core/models-openai.json` or the merge logic supports conditional brainstorm override.

### 10. Leave Push-Safety Script Out

- Do not add a push helper script or skill in this PR.
- Do not expand scope beyond removing or avoiding risky new push guidance.
- Leave broader push-safety improvements for the separate PR.

## Verification

- Validate changed JSON files with `jq empty`.
- Run shell syntax checks with `bash -n scripts/init.sh scripts/copy.sh`.
- Search for stale references:
  - `.opencode/skills/workflow-brainstorming`
  - `workflow-bug-analysis/scripts/db.sh`
  - project-specific `api` / `crawler` wording in reusable skills
  - “symlinked authored skill” in Claude entry prompts
- If stack role-doc files are deleted, inspect or test init/copy overlay handling for missing files.
