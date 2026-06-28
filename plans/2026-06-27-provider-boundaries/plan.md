# Plan: Fix provider-internal leakage from workflow skills

## Objective

Generic workflow skills and agents must stop exposing GitHub/GitLab implementation details. Workflow-facing files should describe repository operations in host-neutral terms and call stable neutral skills. Provider-specific mechanics should remain isolated behind integration/provider skills.

The recurring leakage to remove includes:

- `gh` / `glab`
- `github-publish` / `gitlab-publish`
- `github-pr-comments` / `gitlab-mr-comments`
- `open-pr.sh` / `open-mr.sh`
- `fetch-pr-comments.sh` / `fetch-mr-comments.sh`
- repeated `git remote get-url origin` host-detection snippets
- GitHub-only “PR comments” wording in generic workflows
- Claude workflow skills naming OpenCode internals such as `@implement`, `@implement-task`, or “OpenCode handoff”

## Target architecture

Workflow-facing files should use these neutral authored skills:

- `git-publish` — safe branch push for any git remote.
- `change-request-publish` — open a change request after detecting the host.
- `change-request-comments` — fetch and reply to change-request comments.
- `issue-tracker` — create/update tracker issues and perform duplicate checks.

Provider-specific skills remain implementation details behind those neutral interfaces:

- `github-publish`
- `gitlab-publish`
- `github-pr-comments`
- `gitlab-mr-comments`

## Scope and file mapping

This change is in `core/`, so verify whether stack overlays need matching changes. Initial investigation found no relevant workflow-provider leakage under `stacks/pnpm` or `stacks/maven`, but each task that changes wording must re-check stack ripple.

Template mapping to keep in mind:

| Source | Installed target |
|---|---|
| `core/agents/skills/*` | `.agents/skills/*` plus symlinked `.claude/skills/*` authored skills |
| `core/claude/skills/*` | `.claude/skills/*` workflow entry skills |
| `core/opencode/agents/*` | `.opencode/agents/*` |
| `core/docs/*` | `docs/*` |

Lockfile expectation: no lockfile changes are expected because the new skills are authored local skills, not remote skills.

---

## Task 1 — Add neutral repository integration skills

### Files to add

```text
core/agents/skills/git-publish/SKILL.md
core/agents/skills/git-publish/scripts/push-branch.sh

core/agents/skills/change-request-publish/SKILL.md
core/agents/skills/change-request-publish/scripts/open-change-request.sh

core/agents/skills/change-request-comments/SKILL.md
core/agents/skills/change-request-comments/scripts/fetch-comments.sh
core/agents/skills/change-request-comments/scripts/reply-to-comment.sh

core/agents/skills/issue-tracker/SKILL.md
core/agents/skills/issue-tracker/scripts/create-issue.sh
core/agents/skills/issue-tracker/scripts/update-issue.sh
```

### Requirements

- Each `SKILL.md` must have frontmatter with:
  - `name`
  - `description`
  - `user-invocable: false`
- `git-publish` scripts are provider-agnostic and use only `git`.
- `change-request-publish`, `change-request-comments`, and `issue-tracker` scripts own host detection.
- Neutral integration scripts delegate to existing provider-specific skills/scripts where possible.
- Host-specific details may appear inside these neutral integration skills because they are the boundary layer.
- Workflow-facing files must call only these neutral skills/scripts.

### Suggested implementation notes

- `git-publish/scripts/push-branch.sh` should push the current branch to `origin` using only `git`, refusing if the branch is the default branch or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. It must not inspect the remote host.
- `change-request-publish/scripts/open-change-request.sh` should detect the host and call either:
  - `.agents/skills/github-publish/scripts/open-pr.sh`
  - `.agents/skills/gitlab-publish/scripts/open-mr.sh`
- `change-request-comments` should wrap the existing GitHub/GitLab comment helpers.
- `issue-tracker` should provide a host-neutral interface for issue creation/update and duplicate checks.

### Verification

```bash
bash -n core/agents/skills/git-publish/scripts/*.sh
bash -n core/agents/skills/change-request-publish/scripts/*.sh
bash -n core/agents/skills/change-request-comments/scripts/*.sh
bash -n core/agents/skills/issue-tracker/scripts/*.sh
shellcheck core/agents/skills/git-publish/scripts/*.sh
shellcheck core/agents/skills/change-request-publish/scripts/*.sh
shellcheck core/agents/skills/change-request-comments/scripts/*.sh
shellcheck core/agents/skills/issue-tracker/scripts/*.sh
```

### Smoke `git-publish` against a local bare remote

```bash
mkdir -p .temp/git-publish-smoke
rm -rf .temp/git-publish-smoke/*
git init --bare .temp/git-publish-smoke/origin.git
git init .temp/git-publish-smoke/work
git -C .temp/git-publish-smoke/work remote add origin ../origin.git
git -C .temp/git-publish-smoke/work config user.email "test@example.com"
git -C .temp/git-publish-smoke/work config user.name "Test"
echo "init" > .temp/git-publish-smoke/work/README.md
git -C .temp/git-publish-smoke/work add README.md
git -C .temp/git-publish-smoke/work commit -m "init"
git -C .temp/git-publish-smoke/work checkout -b feature/test
( cd .temp/git-publish-smoke/work && bash .agents/skills/git-publish/scripts/push-branch.sh )
rm -rf .temp/git-publish-smoke
```

### Commit boundary

One commit:

```text
Add neutral repository integration skills
```

---

## Task 2 — Move bug issue mechanics behind `issue-tracker`

### Files to update

```text
core/agents/skills/workflow-bug-analysis/SKILL.md
core/opencode/agents/bugfix.md
core/claude/skills/bugfix/SKILL.md
core/claude/settings.json
```

### Files to remove, move, or convert to compatibility wrappers

```text
core/agents/skills/workflow-bug-analysis/scripts/create-bug-issue.sh
core/agents/skills/workflow-bug-analysis/scripts/update-bug-issue.sh
```

### Requirements

- Replace “structured GitHub issue” with “structured tracker issue”.
- Remove direct `gh` / `glab` instructions from workflow-facing bug files.
- `workflow-bug-analysis` owns investigation and structured issue content.
- `issue-tracker` owns issue creation/update mechanics.
- OpenCode and Claude bugfix entry points should call `workflow-bug-analysis` plus `issue-tracker`; they should not name provider CLIs or provider-specific scripts.

### Verification

```bash
rg -n "GitHub|GitLab|gh |glab|create-bug-issue|update-bug-issue" \
  core/agents/skills/workflow-bug-analysis \
  core/opencode/agents/bugfix.md \
  core/claude/skills/bugfix/SKILL.md

bash -n core/agents/skills/issue-tracker/scripts/*.sh
shellcheck core/agents/skills/issue-tracker/scripts/*.sh
```

Expected result: no provider-specific leakage remains in generic bug workflow files. Any remaining hit must be provider-boundary documentation or a compatibility wrapper with an explicit migration reason.

### Commit boundary

One commit:

```text
Move bug issue publishing behind issue tracker skill
```

---

## Task 3 — Replace provider-specific workflow wording

### Shared workflow files to update

```text
core/agents/skills/workflow-implementation/SKILL.md
core/agents/skills/workflow-implementation/implementer-prompt.md
core/agents/skills/workflow-implementation/spec-reviewer-prompt.md
core/agents/skills/workflow-implementation/code-quality-reviewer-prompt.md
core/agents/skills/workflow-planning/plan-document-reviewer-prompt.md
core/agents/skills/workflow-verification/SKILL.md
```

### OpenCode agent files to update

```text
core/opencode/agents/brainstorm.md
core/opencode/agents/planner.md
core/opencode/agents/implement.md
core/opencode/agents/finish.md
core/opencode/agents/review-plan.md
core/opencode/agents/review-code.md
core/opencode/agents/bugfix.md
```

### Claude workflow skill files to update

```text
core/claude/skills/brainstorm/SKILL.md
core/claude/skills/planner/SKILL.md
core/claude/skills/implement/SKILL.md
core/claude/skills/finish/SKILL.md
core/claude/skills/review-plan/SKILL.md
core/claude/skills/review-code/SKILL.md
core/claude/skills/bugfix/SKILL.md
```

### Replacement language

Use host-neutral language:

```text
Push branches through git-publish.
Open a change request through change-request-publish.
Read change-request comments through change-request-comments.
Create or update tracker issues through issue-tracker.
```

Avoid in generic workflow files:

```text
github-publish
gitlab-publish
github-pr-comments
gitlab-mr-comments
gh
glab
open-pr.sh
open-mr.sh
fetch-pr-comments.sh
fetch-mr-comments.sh
```

Also remove Claude workflow references to OpenCode internals, including:

```text
OpenCode handoff
@implement
@implement-task
```

unless the section is explicitly documenting high-level cross-harness availability rather than directing the Claude workflow to use OpenCode internals.

### Verification

```bash
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|gh |glab|open-pr\.sh|open-mr\.sh|fetch-pr-comments|fetch-mr-comments" \
  core/agents/skills/workflow-* \
  core/claude/skills \
  core/opencode/agents

rg -n "OpenCode handoff|@implement|@implement-task" core/claude/skills
```

Expected result: no hits in generic workflow files, or each remaining hit is explicitly justified and not a provider implementation leak.

### Commit boundary

One commit:

```text
Use neutral repository interfaces in workflows
```

---

## Task 4 — Register new authored skills in installers and docs

### Files to update

```text
scripts/init.sh
scripts/copy.sh
README.md
core/docs/agents/agent-workflow-extension.md
core/claude/settings.json
```

### Installer requirements

Add these authored skills to both installer skill lists:

```text
git-publish
change-request-publish
change-request-comments
issue-tracker
```

Relevant current locations:

- `scripts/init.sh` authored skills array near the Claude authored-skill symlink step.
- `scripts/copy.sh` authored skills array for `.agents/skills/<authored-skill>/` handling.

### README requirements

Update:

- Installed authored reusable skill list.
- Claude symlink table.
- Recommended workflow wording where generic text says GitHub comments or PR-only language.

### Extension guide requirements

Update `core/docs/agents/agent-workflow-extension.md`:

- Replace “GitHub PR comment workflow boundary” with “change-request comment workflow boundary”.
- Document that provider-specific mechanics belong only in provider or neutral integration skills.
- Keep existing OpenCode/Claude boundary guidance.

### Claude settings requirements

Update `core/claude/settings.json`:

- Allow neutral wrapper scripts.
- Keep mutation operations in `ask` where appropriate.
- Keep provider script permissions only as implementation support for the wrapper layer, not as workflow instructions.

### Stack ripple check

```bash
rg -n "github|gitlab|PR|MR|gh |glab" stacks/pnpm stacks/maven
```

Update stack overlays only if they contain affected workflow wording.

### Verification

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
jq . core/claude/settings.json
```

Smoke `init.sh` enough to verify new symlinks:

```bash
mkdir -p .temp/smoke-test
printf "1\n1\n.temp/smoke-test/target\n" | bash scripts/init.sh
ls -la .temp/smoke-test/target/.claude/skills
rm -rf .temp/smoke-test
```

### Commit boundary

One commit:

```text
Register neutral repository skills in installers
```

---

## Task 5 — Add workflow boundary regression check

### File to add

```text
scripts/check-workflow-boundaries.sh
```

### Requirements

The script should fail when generic workflow-facing files contain direct provider internals.

Scan at least:

```text
core/agents/skills/workflow-*
core/claude/skills
core/opencode/agents
```

Disallowed examples in generic workflow files:

```text
github-publish
gitlab-publish
github-pr-comments
gitlab-mr-comments
gh 
glab
open-pr.sh
open-mr.sh
fetch-pr-comments.sh
fetch-mr-comments.sh
```

Allow provider-specific references in boundary locations:

```text
core/agents/skills/github-*
core/agents/skills/gitlab-*
core/agents/skills/change-request-publish
core/agents/skills/change-request-comments
core/agents/skills/issue-tracker
scripts/init.sh
scripts/copy.sh
README.md
```

### Verification

```bash
bash -n scripts/check-workflow-boundaries.sh
shellcheck scripts/check-workflow-boundaries.sh
bash scripts/check-workflow-boundaries.sh
```

### Commit boundary

One commit:

```text
Add workflow provider boundary check
```

---

## Task 6 — Final verification and acceptance

### Full verification

```bash
bash -n scripts/init.sh scripts/copy.sh scripts/check-workflow-boundaries.sh
shellcheck scripts/init.sh scripts/copy.sh scripts/check-workflow-boundaries.sh
codespell README.md core/agents/skills core/claude/skills core/opencode/agents core/docs/agents
bash scripts/check-workflow-boundaries.sh
```

### Smoke `init.sh`

```bash
mkdir -p .temp/smoke-init
printf "1\n1\n.temp/smoke-init/target\n" | bash scripts/init.sh
ls -la .temp/smoke-init/target/.claude/skills
```

### Smoke `copy.sh`

```bash
mkdir -p .temp/smoke-copy/target
git -C .temp/smoke-copy/target init
touch .temp/smoke-copy/target/README.md
git -C .temp/smoke-copy/target add README.md
git -C .temp/smoke-copy/target commit -m "init"
printf "1\n1\n" | bash scripts/copy.sh .temp/smoke-copy/target
ls -la .temp/smoke-copy/target/.claude/skills
```

### Cleanup

```bash
rm -rf .temp/smoke-init .temp/smoke-copy
```

### Acceptance criteria

- Generic workflow skills no longer expose GitHub/GitLab mechanics.
- Provider-specific mechanics are isolated to provider skills or neutral integration skills.
- New authored skills are installed by `init.sh` and `copy.sh`.
- Claude symlinks resolve for all new authored skills.
- README skill lists and symlink table match actual installed assets.
- Stack overlays are checked for ripple effects.
- Boundary check prevents future provider-internal leakage.
- Bash scripts pass `bash -n` and `shellcheck`.
- Smoke installs succeed under `.temp/`.
