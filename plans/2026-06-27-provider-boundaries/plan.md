# Plan: Fix provider-internal leakage from workflow skills

## Objective

Generic workflow skills and agents must stop exposing GitHub/GitLab implementation details. Workflow-facing files should describe repository operations in host-neutral terms and call stable neutral skills. Provider-specific mechanics should remain isolated behind integration/provider skills.

## Recurring leakage to remove

- `gh` / `glab`
- `github-publish` / `gitlab-publish`
- `github-pr-comments` / `gitlab-mr-comments`
- `open-pr.sh` / `open-mr.sh`
- `fetch-pr-comments.sh` / `fetch-mr-comments.sh`
- repeated `git remote get-url origin` host-detection snippets
- GitHub-only “PR comments” wording in generic workflows
- Claude workflow skills naming OpenCode internals such as `@implement`, `@implement-task`, or “OpenCode handoff”
- Base `core/opencode.json` permission entries for `glab` (provider-specific CLI should not appear in generic config)

## Target architecture

Workflow-facing files should use these neutral authored skills:

- `git-publish` — safe branch push for any git remote.
- `change-request-publish` — open a change request after detecting the host.
- `change-request-comments` — fetch and reply to change-request comments.
- `issue-tracker` — create/update tracker issues and perform duplicate checks.

Provider-specific CLI commands remain implementation details inside the neutral integration skills:

- `change-request-publish` directly runs `gh pr create` or `glab mr create` after host detection.
- `change-request-comments` delegates to the provider-specific `github-pr-comments` and `gitlab-mr-comments` skills.
- `issue-tracker` directly runs `gh issue ...` or `glab issue ...` after host detection.

The old `github-publish` and `gitlab-publish` skills are removed entirely; their only remaining behavior (opening PRs/MRs) is absorbed into `change-request-publish`.

## Scope and file mapping

This change is in `core/`, so verify whether stack overlays need matching changes. Initial investigation found no relevant workflow-provider leakage under `stacks/pnpm` or `stacks/maven`, but each task that changes wording must re-check stack ripple.

Template mapping to keep in mind:

| Source | Installed target |
|---|---|
| `core/agents/skills/*` | `.agents/skills/*` plus symlinked `.claude/skills/*` authored skills |
| `core/claude/skills/*` | `.claude/skills/*` workflow entry skills |
| `core/opencode/agents/*` | `.opencode/agents/*` |
| `core/docs/*` | `docs/*` |

Lockfile expectation: no lockfile changes are expected because the new skills are authored local skills, not remote skills. `core/skills-lock.json` tracks remote skills installed into target repos; `skills-lock.json` tracks self-maintenance remote skills for this repo. Neither lists authored skills.

Files added or changed by this plan:

```text
# New neutral integration skills
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
 core/agents/skills/issue-tracker/scripts/find-duplicate-issues.sh

# Bug workflow moved behind issue-tracker
 core/agents/skills/workflow-bug-analysis/SKILL.md
 core/agents/skills/workflow-bug-analysis/scripts/                    (delete entire directory)
 core/opencode/agents/bugfix.md
 core/claude/skills/bugfix/SKILL.md

# Provider publish skills replaced by change-request-publish
 core/agents/skills/github-publish/                                   (delete entire directory)
 core/agents/skills/gitlab-publish/                                   (delete entire directory)
 core/agents/skills/change-request-publish/scripts/open-change-request.sh  (absorbs open-pr.sh / open-mr.sh logic)

# Shared workflow skills and prompts
 core/agents/skills/workflow-implementation/SKILL.md
 core/agents/skills/workflow-implementation/implementer-prompt.md
 core/agents/skills/workflow-implementation/spec-reviewer-prompt.md
 core/agents/skills/workflow-implementation/code-quality-reviewer-prompt.md
 core/agents/skills/workflow-planning/plan-document-reviewer-prompt.md
 core/agents/skills/workflow-verification/SKILL.md

# OpenCode agents
 core/opencode/agents/brainstorm.md
 core/opencode/agents/planner.md
 core/opencode/agents/implement.md
 core/opencode/agents/implement-task.md   (verify-only; currently clean)
 core/opencode/agents/finish.md
 core/opencode/agents/review-plan.md
 core/opencode/agents/review-code.md
 core/opencode.json

# Claude workflow skills
 core/claude/skills/brainstorm/SKILL.md
 core/claude/skills/planner/SKILL.md
 core/claude/skills/implement/SKILL.md
 core/claude/skills/finish/SKILL.md
 core/claude/skills/review-plan/SKILL.md
 core/claude/skills/review-code/SKILL.md
 core/claude/skills/bugfix/SKILL.md

# Installers, docs, settings
 scripts/init.sh
 scripts/copy.sh
 README.md
 core/docs/agents/agent-workflow-extension.md
 core/docs/agents/review-plan.md
 core/docs/agents/review-code.md
 core/claude/settings.json

# Regression check
 scripts/check-workflow-boundaries.sh
```

## Task dependencies

```text
Task 1 ─┬─> Task 2  (issue-tracker must exist before bug workflow can call it)
        ├─> Task 3a (shared workflow prompts reference neutral skills)
        ├─> Task 3b (OpenCode agents reference neutral skills)
        ├─> Task 3c (Claude skills reference neutral skills)
        └─> Task 4a (installers must know about new skills)

Task 3a/b/c ──> Task 5  (boundary check validates the updated workflow files)

All tasks ──> Task 6  (final verification)
```

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
core/agents/skills/issue-tracker/scripts/find-duplicate-issues.sh
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

### Implementation notes

#### `git-publish/scripts/push-branch.sh`

- Push the current branch to `origin`.
- Refuse if the current branch is `main`, `master`, or a detached `HEAD`.
- Refuse any `--force` / `-f` / `--force-with-lease` argument.
- Pass through other extra arguments (e.g. `--set-upstream`).
- Do not inspect the remote host.

For the initial implementation, protect `main|master|HEAD`. A future enhancement could query the remote default branch, but that requires network and is not needed to fix the leakage.

#### `change-request-publish/scripts/open-change-request.sh`

- Detect the host from `git remote get-url origin`:
  - GitHub (contains `github.com` or starts with `git@github.com:`) → open a pull request with `gh pr create`
  - Otherwise → open a merge request with `glab mr create` (GitLab is commonly self-hosted)
- Refuse if the current branch is `main`, `master`, or a detached `HEAD`.
- Skip creation when a change request already exists for the current branch, printing the existing one and exiting 0.
- Pass through all arguments (`"$@"`) to the provider CLI.
- Print the created change-request URL.

Workflow instructions (Claude `.claude/skills/...`, OpenCode `.agents/skills/...`) must call only the neutral script. Provider CLI names (`gh pr create`, `glab mr create`) are allowed inside this script because it is the boundary layer.

#### `change-request-comments/scripts/fetch-comments.sh`

- Detect host from `git remote get-url origin`.
- GitHub → delegate to `.agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh`
- GitLab → delegate to `.agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
- Pass through arguments and preserve exit code.

#### `change-request-comments/scripts/reply-to-comment.sh`

- Detect host from `git remote get-url origin`.
- GitHub → delegate to `.agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh`
- GitLab → delegate to `.agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`
- Pass through arguments and preserve exit code.

#### `issue-tracker/scripts/create-issue.sh`

- Accept `--title TITLE`, `--body-file PATH`, and optional `--labels LABELS`.
- Detect host from `git remote get-url origin`.
- GitHub → `gh issue create --title ... --body-file ... --label ...`
- GitLab → `glab issue create --title ... --description ... --label ...`
- Print the created issue URL.

#### `issue-tracker/scripts/update-issue.sh`

- Accept `--issue NUMBER` and `--body-file PATH`.
- Detect host from `git remote get-url origin`.
- GitHub → `gh issue edit <number> --body-file ...`
- GitLab → `glab issue update <number> --description ...`
- Print the issue URL.

#### `issue-tracker/scripts/find-duplicate-issues.sh`

- Accept `--title TITLE` and optional `--labels LABELS`.
- Detect host from `git remote get-url origin`.
- GitHub → `gh issue list --search ... --label ... --json number,title,url`
- GitLab → `glab issue list --search ... --label ... --output json` (or equivalent)
- Print a compact list of candidate duplicate issues, or nothing if none found.

### Provider publish skill removal

Because `change-request-publish` now owns opening PRs/MRs and `git-publish` owns pushing, the old `github-publish` and `gitlab-publish` skills are redundant.

#### Files to delete

```text
core/agents/skills/github-publish/
core/agents/skills/gitlab-publish/
```

Use `git rm -r` for these tracked directories.

#### Files to update

```text
core/agents/skills/change-request-publish/SKILL.md
```

Rewrite `change-request-publish/SKILL.md` to describe the neutral interface:

```markdown
# Change Request Publish

Open a change request (pull request or merge request) for the current branch after detecting the host.

## Detect the host

Inspect `git remote get-url origin`:

- GitHub (contains `github.com` or starts with `git@github.com:`) → open a pull request with `gh pr create`.
- Otherwise → open a merge request with `glab mr create` (commonly self-hosted GitLab).

## Open a change request

```bash
bash .agents/skills/change-request-publish/scripts/open-change-request.sh [provider flags]
```

The script refuses on `main`/`master`/detached `HEAD` and skips creation when a change request already exists for the branch. Pass `--fill`, `--title`/`--description`, or other flags supported by the underlying CLI.

## Rules

- Do not call `gh pr create` or `glab mr create` directly from workflow agents — use this skill's script.
- Do not create change requests from the default branch.
```

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

# Confirm old provider publish skills are gone
if [[ -d core/agents/skills/github-publish || -d core/agents/skills/gitlab-publish ]]; then
  echo "ERROR: github-publish and gitlab-publish skill directories must be deleted" >&2
  exit 1
fi
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

# Negative case: pushing main must be refused
git -C .temp/git-publish-smoke/work checkout main
if ( cd .temp/git-publish-smoke/work && bash .agents/skills/git-publish/scripts/push-branch.sh ); then
  echo "ERROR: push-branch.sh should have refused main" >&2
  exit 1
fi

rm -rf .temp/git-publish-smoke
```

### Commit boundary

One commit:

```text
Add neutral repository skills and remove redundant provider push scripts
```

---

## Task 2 — Move bug issue mechanics behind `issue-tracker`

### Decision

- The `issue-tracker` scripts added in Task 1 supersede the bug-issue scripts.
- Delete the old `workflow-bug-analysis/scripts/` directory entirely after updating all references. Use `git rm -r` for the tracked directory.
- Update `workflow-bug-analysis/SKILL.md` to call `issue-tracker` scripts and use “tracker issue” language.
- Update OpenCode and Claude bugfix entry points to reference `issue-tracker`, not provider CLIs or provider-specific scripts.

### Files to add/move/remove

```text
# Superseded by issue-tracker scripts from Task 1; delete:
core/agents/skills/workflow-bug-analysis/scripts/
```

### Files to update

```text
core/agents/skills/workflow-bug-analysis/SKILL.md
core/opencode/agents/bugfix.md
core/claude/skills/bugfix/SKILL.md
core/claude/settings.json
core/docs/agents/bugfix.md          (verify-only; should already be neutral)
```

### Requirements

- Replace “structured GitHub issue” with “structured tracker issue” everywhere in `workflow-bug-analysis/SKILL.md` and `bugfix/SKILL.md`.
- Remove direct `gh` / `glab` instructions from workflow-facing bug files.
- `workflow-bug-analysis` owns investigation and structured issue content.
- `issue-tracker` owns issue creation/update/duplicate-check mechanics.
- OpenCode and Claude bugfix entry points should call `workflow-bug-analysis` plus `issue-tracker`; they should not name provider CLIs or provider-specific scripts.

### Concrete wording changes

In `core/agents/skills/workflow-bug-analysis/SKILL.md`:

- Line 3 description: change `produces a structured GitHub issue` → `produces a structured tracker issue`.
- Line 9: change `produce a structured GitHub issue` → `produce a structured tracker issue`.
- Section 7: replace the `create-bug-issue.sh` invocation with:

  ```bash
  bash .agents/skills/issue-tracker/scripts/create-issue.sh \
    --title "Concise bug summary" \
    --body-file .temp/<slug>-issue-body.md \
    --labels "bug"
  ```

- Follow-up evidence: replace `update-bug-issue.sh` with `issue-tracker/scripts/update-issue.sh`.
- Add a step after hypothesis: check for duplicates with `issue-tracker/scripts/find-duplicate-issues.sh` before creating the issue.

In `core/claude/skills/bugfix/SKILL.md`:

- Line 3 description: `produces a structured GitHub issue` → `produces a structured tracker issue`.
- Line 9: `produce a well-structured GitHub issue` → `produce a well-structured tracker issue`.
- Remove the `gh` rules in the Rules section. Replace with:

  ```text
  - Never call `gh` or `glab` directly — use the `issue-tracker` scripts for issue mutations.
  - Use `issue-tracker/scripts/find-duplicate-issues.sh` for duplicate checking.
  ```

In `core/opencode/agents/bugfix.md`:

- Line 2 description: change `structured GitHub issue` → `structured tracker issue`.
- Replace the comment block that says `# GitHub — agent uses wrapper scripts for mutations; direct gh is denied` with a neutral note: `# Tracker issues — use issue-tracker scripts for mutations; direct gh/glab mutations are denied`.
- Keep read-only provider CLI entries as implementation support for the `issue-tracker` scripts (OpenCode checks the top-level Bash command, but keeping these allows also protects against accidental direct use):
  - `gh issue list *`: allow
  - `gh issue view *`: allow
  - `gh search issues *`: allow
  - `glab issue list *`: allow
  - `glab issue view *`: allow
- Keep the blanket deny for mutations:
  - `gh *`: deny
  - `glab *`: deny
- Add allow entries for:
  - `bash .agents/skills/issue-tracker/scripts/*.sh`
- Update instructions to say: “Use `issue-tracker/scripts/find-duplicate-issues.sh` for duplicate checks and `issue-tracker/scripts/create-issue.sh` to file the tracker issue.”

### Verification

```bash
rg -n "GitHub issue|GitLab issue|gh |glab|create-bug-issue|update-bug-issue" \
  core/agents/skills/workflow-bug-analysis \
  core/opencode/agents/bugfix.md \
  core/claude/skills/bugfix/SKILL.md

bash -n core/agents/skills/issue-tracker/scripts/*.sh
shellcheck core/agents/skills/issue-tracker/scripts/*.sh
```

Expected result: no provider-specific leakage remains in generic bug workflow files. Any remaining hit must be inside `issue-tracker` scripts (the boundary layer) or in a compatibility wrapper with an explicit migration reason.

### Commit boundary

One commit:

```text
Move bug issue publishing behind issue-tracker skill
```

---

## Task 3a — Neutralize shared workflow skills and prompts

### Files to update

```text
core/agents/skills/workflow-implementation/SKILL.md
core/agents/skills/workflow-implementation/implementer-prompt.md
core/agents/skills/workflow-implementation/spec-reviewer-prompt.md
core/agents/skills/workflow-implementation/code-quality-reviewer-prompt.md
core/agents/skills/workflow-planning/plan-document-reviewer-prompt.md
core/agents/skills/workflow-verification/SKILL.md
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

### Concrete change in `workflow-implementation/SKILL.md`

Replace the Boundaries block (currently lines 99–103):

```markdown
- After final verification, the controller commits all changes, then pushes the branch with `git-publish` and opens a change request with `change-request-publish`. Never push to the default branch.
```

### Concrete change in `workflow-verification/SKILL.md`

If it contains any host-detection or provider-specific publishing instructions, replace them with references to `git-publish` / `change-request-publish`. Verify first; this file is currently expected to be clean.

### Verification

```bash
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|gh |glab|open-pr\.sh|open-mr\.sh|fetch-pr-comments|fetch-mr-comments" \
  core/agents/skills/workflow-*
```

Expected result: no hits in generic workflow skill files.

### Commit boundary

One commit:

```text
Use neutral repository interfaces in shared workflow skills
```

---

## Task 3b — Neutralize OpenCode agents

### Files to update

```text
core/opencode/agents/brainstorm.md
core/opencode/agents/planner.md
core/opencode/agents/implement.md
core/opencode/agents/implement-task.md   (verify-only)
core/opencode/agents/finish.md
core/opencode/agents/review-plan.md
core/opencode/agents/review-code.md
core/opencode.json
```

### Permission changes

In each agent `.md` frontmatter, replace provider-specific Bash allow patterns with neutral ones.

#### `implement.md`

Remove:

```yaml
    "bash .agents/skills/github-publish/scripts/push-branch.sh*": allow
    "bash .agents/skills/github-publish/scripts/open-pr.sh*": ask
    "bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": allow
    "bash .agents/skills/gitlab-publish/scripts/open-mr.sh*": ask
```

Add:

```yaml
    "bash .agents/skills/git-publish/scripts/push-branch.sh*": allow
    "bash .agents/skills/change-request-publish/scripts/open-change-request.sh*": ask
```

Remove skill allows:

```yaml
    "github-publish": allow
    "gitlab-publish": allow
```

Add:

```yaml
    "git-publish": allow
    "change-request-publish": allow
```

#### `finish.md`

Same pattern as `implement.md` for publishing permissions. `finish.md` does not open change requests by default, but keep `change-request-publish` in `ask` if the agent is ever extended to do so.

#### `brainstorm.md` and `planner.md`

Remove:

```yaml
    "bash .agents/skills/github-publish/scripts/push-branch.sh*": allow
    "bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": allow
```

Add:

```yaml
    "bash .agents/skills/git-publish/scripts/push-branch.sh*": allow
```

#### `review-plan.md` and `review-code.md`

Remove:

```yaml
    "bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh *": allow
    "bash .agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh *": allow
    "bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh*": allow
    "bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh*": ask
```

Add:

```yaml
    "bash .agents/skills/change-request-comments/scripts/fetch-comments.sh *": allow
    "bash .agents/skills/change-request-comments/scripts/reply-to-comment.sh *": ask
```

Remove skill allows:

```yaml
    "github-pr-comments": allow
    "gitlab-mr-comments": allow
```

Add:

```yaml
    "change-request-comments": allow
```

#### `bugfix.md`

See Task 2.

#### `core/opencode.json`

Remove all base `glab` permission entries from `permission.bash`:

```json
    "glab mr create *": "ask",
    "glab mr list *": "allow",
    "glab mr view *": "allow",
    "glab mr diff *": "allow",
    "glab issue create *": "ask",
    "glab issue view *": "allow",
    "glab issue list *": "allow",
    "glab issue update *": "ask"
```

Generic agents should not need provider CLI permissions in the base config. Any provider CLI access needed by `issue-tracker` scripts is covered by the agent frontmatter that invokes those scripts (OpenCode checks the immediate Bash command; the script's internal CLI calls are not surfaced to the permission layer).

### Instruction changes

Replace every host-detection block of the form:

```markdown
Detect host from `git remote get-url origin`:
- GitHub (contains `github.com` or starts with `git@github.com:`) → use `github-publish`
- Otherwise → use `gitlab-publish`
```

with:

```markdown
Push the branch with `bash .agents/skills/git-publish/scripts/push-branch.sh`. To open a change request, use `bash .agents/skills/change-request-publish/scripts/open-change-request.sh`.
```

In `review-plan.md` and `review-code.md`, replace references to `github-pr-comments` / `gitlab-mr-comments` skills with `change-request-comments`.

### Verification

```bash
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|gh |glab|open-pr\.sh|open-mr\.sh|fetch-pr-comments|fetch-mr-comments" \
  core/opencode/agents

jq '.permission.bash | keys' core/opencode.json
```

Expected result: no provider-specific leakage in generic agent files. `core/opencode.json` should no longer contain `glab` keys.

### Commit boundary

One commit:

```text
Use neutral repository interfaces in OpenCode agents
```

---

## Task 3c — Neutralize Claude workflow skills

### Files to update

```text
core/claude/skills/brainstorm/SKILL.md
core/claude/skills/planner/SKILL.md
core/claude/skills/implement/SKILL.md
core/claude/skills/finish/SKILL.md
core/claude/skills/review-plan/SKILL.md
core/claude/skills/review-code/SKILL.md
core/claude/skills/bugfix/SKILL.md
```

### Description/frontmatter updates

- `planner/SKILL.md`: change `ready for OpenCode handoff` → `ready for implementation handoff`.
- `review-plan/SKILL.md`: change `finalizes it into the OpenCode handoff document` → `finalizes it into the implementation handoff document`.
- `bugfix/SKILL.md`: change `produces a structured GitHub issue` → `produces a structured tracker issue` (also in body).

### Shell guidance updates

Replace every occurrence of:

```markdown
Publish through the host-appropriate publish skill. Detect host from `git remote get-url origin`:
- GitHub (contains `github.com` or starts with `git@github.com:`) → `bash .claude/skills/github-publish/scripts/push-branch.sh`
- Otherwise → `bash .claude/skills/gitlab-publish/scripts/push-branch.sh` — GitLab is commonly self-hosted
Never hand-roll `git push`.
```

with:

```markdown
Publish through the neutral git-publish skill:
- Push the current branch with `bash .claude/skills/git-publish/scripts/push-branch.sh`.
- Open a change request with `bash .claude/skills/change-request-publish/scripts/open-change-request.sh` when needed.
Never hand-roll `git push`.
```

Apply this in `brainstorm/SKILL.md`, `planner/SKILL.md`, `implement/SKILL.md`, `finish/SKILL.md`, and `review-plan/SKILL.md`.

### Skill reference updates

In `review-plan/SKILL.md` and `review-code/SKILL.md`:

- Replace `Use github-pr-comments for GitHub remotes and gitlab-mr-comments for non-GitHub ...` with `Use change-request-comments for reading and drafting replies to change-request comments.`
- Replace references to `github-pr-comments` / `gitlab-mr-comments` with `change-request-comments`.

### OpenCode internal reference updates

Remove in generic workflow body text:

```text
OpenCode handoff
@implement
@implement-task
```

Exceptions allowed only in an explicit cross-harness availability note. Keep such notes minimal and rephrase agent names as neutral harness references where possible:

- `implement/SKILL.md` may keep a short cross-harness note such as:
  ```markdown
  This is the Claude Code implementation controller. OpenCode has an equivalent controller agent.
  ```
  Do not keep `@implement` in normal workflow instructions.
- `review-code/SKILL.md` currently says:
  ```markdown
  In Claude Code, prefer writing the fix-plan handoff document and handing it to OpenCode (`@implement` / `@implement-task`) for TDD implementation.
  ```
  Replace with:
  ```markdown
  In Claude Code, prefer writing the fix-plan handoff document and handing it to the OpenCode implement agent for TDD implementation.
  ```
- `planner/SKILL.md` currently says:
  ```markdown
  - Keep task boundaries small enough that the implementer executes without guessing.
  - Implementation can run in either harness: Claude Code (`/implement`) or OpenCode (`@implement`). Pick one per branch. Suggest the user's preferred harness.
  ```
  The second bullet is a cross-harness availability note and may stay, but remove `@implement` and replace with `the OpenCode implement agent`.

### Verification

```bash
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|gh |glab|open-pr\.sh|open-mr\.sh|fetch-pr-comments|fetch-mr-comments" \
  core/claude/skills

rg -n "OpenCode handoff|@implement|@implement-task" core/claude/skills
```

Expected result: no hits in generic workflow files, or each remaining hit is explicitly justified as a cross-harness availability note and not a provider implementation leak.

### Commit boundary

One commit:

```text
Use neutral repository interfaces in Claude workflow skills
```

---

## Task 4a — Register new authored skills in installers

### Files to update

```text
scripts/init.sh
scripts/copy.sh
```

### Installer requirements

Add these authored skills to both installer `AUTHORED_SKILLS` arrays:

```text
git-publish
change-request-publish
change-request-comments
issue-tracker
```

Place them after `feature-documentation` and before `github-pr-comments`:

```bash
AUTHORED_SKILLS=(
  grill-with-docs
  workflow-bug-analysis
  workflow-brainstorming
  workflow-planning
  workflow-verification
  feature-documentation
  git-publish
  change-request-publish
  change-request-comments
  issue-tracker
  github-pr-comments
  gitlab-mr-comments
)
```

Note: `github-publish` and `gitlab-publish` are removed from the list because `change-request-publish` now handles opening PRs/MRs directly.

The existing frontmatter verification loop in `init.sh` will automatically verify `user-invocable: false` for the new skills.

### Verification

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh

mkdir -p .temp/smoke-test
printf "1\n1\n.temp/smoke-test/target\n" | bash scripts/init.sh
ls -la .temp/smoke-test/target/.claude/skills | grep -E 'git-publish|change-request-publish|change-request-comments|issue-tracker'
rm -rf .temp/smoke-test
```

Expected result: the new symlinks exist in `.claude/skills/`.

### Commit boundary

One commit:

```text
Register neutral repository skills in installers
```

---

## Task 4b — Update README and role docs

### Files to update

```text
README.md
core/docs/agents/review-plan.md
core/docs/agents/review-code.md
core/docs/agents/agent-workflow-extension.md
```

### README requirements

- **Installed authored reusable skill list** (line 104): add the four new skills and remove `github-publish`/`gitlab-publish` because `change-request-publish` replaces them.

  Current:
  ```text
  `grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `github-publish`, `github-pr-comments`, `gitlab-publish`, `gitlab-mr-comments`
  ```

  Updated:
  ```text
  `grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `git-publish`, `change-request-publish`, `change-request-comments`, `issue-tracker`, `github-pr-comments`, `gitlab-mr-comments`
  ```

- **Claude symlink table** (lines 131–142): add rows for the four new skills and remove the rows for `github-publish` and `gitlab-publish`.

- **Recommended workflow wording**: update step 8 caption from `leave inline comments or GitHub review notes` to `leave inline comments or change-request review notes`.

### Role doc requirements

In `core/docs/agents/review-plan.md` and `core/docs/agents/review-code.md`, replace:

```markdown
- `github-pr-comments` skill for reading and drafting replies to GitHub PR feedback
- `gitlab-mr-comments` skill for reading and drafting replies to GitLab MR feedback
```

with:

```markdown
- `change-request-comments` skill for reading and drafting replies to change-request feedback
```

In `review-code.md`, the `Git diff or PR diff under review` bullet is generic enough to keep, but optionally rephrase to `Git diff or change-request diff under review` if desired.

### Extension guide requirements

Update `core/docs/agents/agent-workflow-extension.md`:

- Rename `## GitHub PR comment workflow boundary` to `## Change-request comment workflow boundary`.
- Replace the bullet `The github-pr-comments skill owns reading PR comments, classifying comment target types, obtaining exact IDs, and posting approved replies through project scripts.` with:
  ```markdown
  - The `change-request-comments` skill owns reading change-request comments, classifying comment target types, obtaining exact IDs, and posting approved replies through project scripts.
  - Provider-specific mechanics (`github-pr-comments`, `gitlab-mr-comments`, `gh`, `glab`) belong only in provider skills or neutral integration skills, never in generic workflow skills or agent instructions.
  ```
- Keep existing OpenCode/Claude boundary guidance.

### Stack ripple check

```bash
rg -n "github|gitlab|PR|MR|gh |glab" stacks/pnpm stacks/maven
```

Update stack overlays only if they contain affected workflow wording. The pre-flight check indicates no hits, so no overlay changes are expected.

### Verification

```bash
codespell README.md core/docs/agents

rg -n "github-pr-comments|gitlab-mr-comments" README.md core/docs/agents
rg -n "GitHub PR comment workflow boundary" core/docs/agents
```

Expected result: the old skill names no longer appear in generic docs; only `change-request-comments` and neutral wording remain.

### Commit boundary

One commit:

```text
Document neutral repository skills in README and role docs
```

---

## Task 4c — Update Claude settings and core/opencode.json

### Files to update

```text
core/claude/settings.json
core/opencode.json
```

### Claude settings requirements

Replace provider-specific workflow-facing allow entries with neutral wrapper scripts. Keep provider CLI entries only as implementation support for the wrapper layer (read-only issue/comment list commands used by `issue-tracker` and `change-request-comments`).

In `permissions.allow`, replace:

```json
      "Bash(bash .claude/skills/github-pr-comments/scripts/fetch-pr-comments.sh:*)",
      "Bash(bash .claude/skills/workflow-bug-analysis/scripts/create-bug-issue.sh:*)",
      "Bash(gh issue list:*)",
      "Bash(gh issue view:*)",
      "Bash(gh search issues:*)",
      "Bash(bash .claude/skills/github-publish/scripts/push-branch.sh:*)",
      "Bash(bash .claude/skills/gitlab-publish/scripts/push-branch.sh:*)",
      "Bash(bash .claude/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh:*)",
      "Bash(glab mr view:*)",
      "Bash(glab mr diff:*)",
      "Bash(glab mr list:*)",
      "Bash(glab issue view:*)",
      "Bash(glab issue list:*)",
```

with:

```json
      "Bash(bash .claude/skills/git-publish/scripts/push-branch.sh:*)",
      "Bash(bash .claude/skills/change-request-comments/scripts/fetch-comments.sh:*)",
      "Bash(bash .claude/skills/issue-tracker/scripts/create-issue.sh:*)",
      "Bash(bash .claude/skills/issue-tracker/scripts/update-issue.sh:*)",
      "Bash(bash .claude/skills/issue-tracker/scripts/find-duplicate-issues.sh:*)",
      "Bash(gh issue list:*)",
      "Bash(gh issue view:*)",
      "Bash(gh search issues:*)",
      "Bash(glab issue list:*)",
      "Bash(glab issue view:*)",
```

Note: `change-request-publish` opens a PR/MR, which is a mutation. The existing settings kept `open-pr.sh`/`open-mr.sh` in `ask`, so keep `change-request-publish/scripts/open-change-request.sh` in `ask` for parity.

In `permissions.ask`, replace:

```json
      "Bash(bash .claude/skills/github-pr-comments/scripts/reply-to-pr-comment.sh:*)",
      "Bash(bash .claude/skills/workflow-bug-analysis/scripts/update-bug-issue.sh:*)",
      "Bash(bash .claude/skills/github-publish/scripts/open-pr.sh:*)",
      "Bash(bash .claude/skills/gitlab-publish/scripts/open-mr.sh:*)",
      "Bash(bash .claude/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh:*)",
```

with:

```json
      "Bash(bash .claude/skills/change-request-publish/scripts/open-change-request.sh:*)",
      "Bash(bash .claude/skills/change-request-comments/scripts/reply-to-comment.sh:*)",
      "Bash(bash .claude/skills/issue-tracker/scripts/update-issue.sh:*)",
```

Remove direct `gh`/`glab` mutation entries from `ask` unless the wrapper layer still needs them. The wrapper scripts call `gh pr create` / `glab mr create` internally; Claude Code permissions are checked against the top-level Bash command, not subprocesses, so only the wrapper script path needs to be permitted. Remove:

```json
      "Bash(gh pr create:*)",
      "Bash(glab mr create:*)",
      "Bash(glab mr note create:*)",
      "Bash(glab issue create:*)",
      "Bash(glab issue update:*)",
```

### `core/opencode.json` requirements

Remove all `glab` base permission entries (see Task 3b for the exact list).

### Verification

```bash
jq . core/claude/settings.json > /dev/null
jq . core/opencode.json > /dev/null

# Confirm neutral entries are present and old workflow-facing entries are gone
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|create-bug-issue|update-bug-issue" core/claude/settings.json core/opencode.json
```

Expected result: only neutral wrapper script entries remain for workflow operations. Provider CLI entries remain only as read-only implementation support if still needed.

### Commit boundary

One commit:

```text
Update permissions for neutral repository skills
```

---

## Task 5 — Add workflow boundary regression check

### File to add

```text
scripts/check-workflow-boundaries.sh
```

### Requirements

The script must fail (exit non-zero) when generic workflow-facing files contain direct provider internals.

#### Scan targets

```text
core/agents/skills/workflow-*
core/claude/skills
core/opencode/agents
```

#### Disallowed patterns in generic workflow files

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

#### Allowed boundary locations

Provider-specific references are permitted only in:

```text
core/agents/skills/github-*
core/agents/skills/gitlab-*
core/agents/skills/git-publish
core/agents/skills/change-request-publish
core/agents/skills/change-request-comments
core/agents/skills/issue-tracker
scripts/init.sh
scripts/copy.sh
README.md
```

#### Implementation outline

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGETS=(
  core/agents/skills/workflow-*
  core/claude/skills
  core/opencode/agents
)

EXCLUDES=(
  core/agents/skills/github-*
  core/agents/skills/gitlab-*
  core/agents/skills/git-publish
  core/agents/skills/change-request-publish
  core/agents/skills/change-request-comments
  core/agents/skills/issue-tracker
  scripts/init.sh
  scripts/copy.sh
  README.md
)

PATTERNS=(
  'github-publish'
  'gitlab-publish'
  'github-pr-comments'
  'gitlab-mr-comments'
  'gh '
  'glab '
  'open-pr\.sh'
  'open-mr\.sh'
  'fetch-pr-comments\.sh'
  'fetch-mr-comments\.sh'
)

# Build rg exclude globs
EXCLUDE_ARGS=()
for e in "${EXCLUDES[@]}"; do
  EXCLUDE_ARGS+=(--glob="!$e")
done

FAILED=0
for pattern in "${PATTERNS[@]}"; do
  if rg --line-number --glob='*' "${EXCLUDE_ARGS[@]}" "$pattern" "${TARGETS[@]}"; then
    FAILED=1
  fi
done

if [[ "$FAILED" -ne 0 ]]; then
  echo "ERROR: provider-internal references found in generic workflow files." >&2
  exit 1
fi

echo "OK: no provider-internal leakage in generic workflow files."
```

#### Optional extension

Add a second pass that scans Claude workflow skills for OpenCode internals (`OpenCode handoff`, `@implement`, `@implement-task`). Allow them only in explicit cross-harness availability notes. This is optional because Task 3c already verifies it with `rg`.

### Verification

```bash
bash -n scripts/check-workflow-boundaries.sh
shellcheck scripts/check-workflow-boundaries.sh
bash scripts/check-workflow-boundaries.sh
```

Expected result: script exits 0 after all Task 3 changes are complete; it should fail against the current `main` state (confirming it catches leakage).

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

Expected result: all four new skills appear as symlinks in `.claude/skills/`.

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

Expected result: all four new skills appear as symlinks in `.claude/skills/`.

### Cleanup

```bash
rm -rf .temp/smoke-init .temp/smoke-copy
```

### Acceptance criteria

- Generic workflow skills no longer expose GitHub/GitLab mechanics.
- Provider-specific mechanics are isolated to provider skills or neutral integration skills.
- Old provider publish skills (`github-publish/`, `gitlab-publish/`) are removed; `change-request-publish` and `git-publish` are the only publishing paths.
- New authored skills are installed by `init.sh` and `copy.sh`.
- Claude symlinks resolve for all new authored skills.
- README skill lists and symlink table match actual installed assets.
- `core/docs/agents/review-plan.md`, `review-code.md`, and `agent-workflow-extension.md` use neutral skill names.
- `core/opencode.json` no longer contains provider-specific `glab` base permissions.
- `core/claude/settings.json` allows neutral wrapper scripts and no longer lists workflow-facing provider scripts.
- Stack overlays are checked for ripple effects.
- Boundary check prevents future provider-internal leakage.
- Bash scripts pass `bash -n` and `shellcheck`.
- Smoke installs succeed under `.temp/`.

---

## Open questions / decisions

1. **Provider publish skills.** `github-publish/` and `gitlab-publish/` are removed entirely. `git-publish` owns safe branch pushes and `change-request-publish` owns opening PRs/MRs. Provider CLI commands (`gh pr create`, `glab mr create`) live only inside `change-request-publish/scripts/open-change-request.sh`.

2. **Default branch detection in `git-publish`.** Decision: protect `main|master|HEAD` for the initial implementation. This matches the existing provider scripts and is sufficient for the leakage fix.

3. **Duplicate-check interface.** Decision: add `issue-tracker/scripts/find-duplicate-issues.sh` with `--title` and optional `--labels`. Return a compact list; callers decide what constitutes a duplicate.

4. **`core/opencode.json` `glab` removal.** Decision: remove all base `glab` entries. Any OpenCode agent that still needs provider CLI access must declare it in its own frontmatter, but generic workflow agents should not.

5. **Claude `change-request-publish` permission tier.** Decision: keep `change-request-publish/scripts/open-change-request.sh` in `ask` to match the current `open-pr.sh`/`open-mr.sh` behavior. If the workflow is later changed to auto-open change requests, move it to `allow`.

---

## Pre-flight baseline

Run these commands before starting implementation to confirm the current leakage:

```bash
rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|gh |glab|open-pr\.sh|open-mr\.sh|fetch-pr-comments|fetch-mr-comments" \
  core/agents/skills/workflow-* core/claude/skills core/opencode/agents

rg -n "OpenCode handoff|@implement|@implement-task" core/claude/skills

jq '.permission.bash | keys' core/opencode.json
```
