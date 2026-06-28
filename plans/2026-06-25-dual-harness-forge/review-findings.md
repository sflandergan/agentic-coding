# Review Findings Plan — PR #6 Dual Harness + GitLab Support

This plan consolidates the current PR comments and local review findings for fixing the remaining issues on `feature/support-claude-implement-and-glab`.

## Review summary

### Blocking issues

1. **Workflow-facing files leak skill internals.** OpenCode agents, Claude skills, and `workflow-bug-analysis` still instruct agents to run `.../skills/<name>/scripts/*.sh` directly. These files should name the skill to use, not its internal scripts.
2. **Provider-specific comment skills remain in the downstream install surface.** `github-pr-comments` and `gitlab-mr-comments` are still installed and documented even though PR feedback asks to move that logic behind `change-request-comments`.
3. **`change-request-comments` delegates to provider skill folders.** Its scripts still call `.agents/skills/github-pr-comments/...` and `.agents/skills/gitlab-mr-comments/...`, so removing those folders would break comment workflows unless the implementations move into the neutral skill.
4. **Permission/skill allowlists are inconsistent.** Several agents have script permissions without corresponding skill permissions, and review-code is missing publish capability for review-fix implementation plans.
5. **`AGENTS.md` does not yet encode the “no skill internals in workflow instructions” rule.** This is the root cause called out by the top-level PR comment.
6. **Neutral skill docs mix runtime instructions with design rationale.** Some `SKILL.md` files explain why the wrapper exists or expose implementation detail. Keep `SKILL.md` focused on invocation contract and move rationale into sibling `README.md` files.

### Advisory issues

1. **`core/claude/settings.json` has readability and policy drift.** Permissions should be grouped and `update-issue.sh` should appear in only one permission tier.
2. **`scripts/publish-branch.sh` conflicts with the new neutral skill model.** Decide whether to preserve the repo-local compatibility wrapper required by `AGENTS.md` or update `AGENTS.md` and self-maintenance symlinks.
3. **`scripts/check-workflow-boundaries.sh` catches provider names but not generic skill-internal script paths.** It should prevent both provider leakage and direct internal script leakage.

## Implementation tasks

### Task 1 — Add a hard workflow boundary rule to `AGENTS.md`

**Files**

- `AGENTS.md`

**Changes**

1. Add a section such as `## Skill Boundary Rule` after the symlink model.
2. State that workflow-facing files must instruct agents to use skills by name, for example `git-publish`, `change-request-publish`, `change-request-comments`, and `issue-tracker`.
3. State that workflow-facing files must not expose internal script paths like `.agents/skills/<skill>/scripts/*.sh` or `.claude/skills/<skill>/scripts/*.sh`. Boundary-skill implementation details may live in that skill's own scripts or sibling `README.md`; keep `SKILL.md` focused on the invocation contract.
4. Clarify that agent frontmatter and Claude settings may grant script permissions, but body instructions should stay skill-level.
5. Add provider-boundary language: provider-specific CLI details (`gh`, `glab`, provider comment scripts) belong only in provider/boundary skills, not generic workflow files.

**Verification**

```bash
codespell AGENTS.md
```

**Commit boundary**

```text
Document skill boundary rules for workflow instructions
```

### Task 2 — Move provider comment implementations into `change-request-comments`

**Files**

- `core/agents/skills/change-request-comments/SKILL.md`
- `core/agents/skills/change-request-comments/scripts/fetch-comments.sh`
- `core/agents/skills/change-request-comments/scripts/reply-to-comment.sh`
- `core/agents/skills/github-pr-comments/` (delete from downstream template)
- `core/agents/skills/gitlab-mr-comments/` (delete from downstream template)
- `.agents/skills/github-pr-comments/` (convert from symlink to self-maintenance copy if this repo still needs PR comment review)
- `.claude/skills/github-pr-comments` (keep symlink to `.agents/skills/github-pr-comments`)

**Changes**

1. Before deleting `core/agents/skills/github-pr-comments/`, preserve this repo's self-maintenance review workflow by converting `.agents/skills/github-pr-comments` from a symlink into a real self-maintenance skill directory copied from the current GitHub implementation. Keep `.claude/skills/github-pr-comments` symlinked to `.agents/skills/github-pr-comments`.
2. Replace the GitHub branch of `change-request-comments/scripts/fetch-comments.sh` with the implementation currently in `core/agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh`; keep the public wrapper name `fetch-comments.sh`.
3. Replace the GitHub branch of `change-request-comments/scripts/reply-to-comment.sh` with the implementation currently in `core/agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh`; keep the public wrapper name `reply-to-comment.sh`.
4. Replace the GitLab branch of `fetch-comments.sh` with the implementation currently in `core/agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`.
5. Replace the GitLab branch of `reply-to-comment.sh` with the implementation currently in `core/agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`.
6. Keep host detection inside `change-request-comments`; it may call `gh`/`glab` because this skill is the provider boundary layer.
7. Preserve behavior and flags from both provider implementations, including `--comments-only`, `--diff-only`, `--json`, comment reply payload handling, and exit-code behavior.
8. Remove references from `change-request-comments/SKILL.md` and scripts that say it delegates to `github-pr-comments` or `gitlab-mr-comments` skill folders.
9. Delete `core/agents/skills/github-pr-comments/` and `core/agents/skills/gitlab-mr-comments/` with `git rm -r` after their logic is represented inside `change-request-comments` and the self-maintenance GitHub skill no longer points at `core/`.

**Verification**

```bash
bash -n core/agents/skills/change-request-comments/scripts/*.sh
shellcheck core/agents/skills/change-request-comments/scripts/*.sh
! rg -n "github-pr-comments|gitlab-mr-comments" core/agents/skills/change-request-comments
test ! -e core/agents/skills/github-pr-comments
test ! -e core/agents/skills/gitlab-mr-comments
test -d .agents/skills/github-pr-comments
test "$(readlink .claude/skills/github-pr-comments)" = "../../.agents/skills/github-pr-comments"
```

Expected result: no delegation to provider skill folders remains in `change-request-comments`.

**Commit boundary**

```text
Move comment provider logic into change-request-comments
```

### Task 2A — Split neutral skill rationale into sibling READMEs

**Files**

- `core/agents/skills/git-publish/SKILL.md`
- `core/agents/skills/git-publish/README.md` (add)
- `core/agents/skills/change-request-publish/SKILL.md`
- `core/agents/skills/change-request-publish/README.md` (add)
- `core/agents/skills/change-request-comments/SKILL.md`
- `core/agents/skills/change-request-comments/README.md` (add)
- `core/agents/skills/issue-tracker/SKILL.md`
- `core/agents/skills/issue-tracker/README.md` (add)

**Changes**

1. Keep each `SKILL.md` focused on the agent-facing contract: when to use the skill, what high-level capability it provides, required inputs/outputs, and safety rules.
2. Remove design-rationale sections such as `Why a script, not a raw ...` from `SKILL.md` files.
3. Move the rationale into the sibling `README.md`, including why the wrapper exists, host-detection philosophy, branch/default-branch guards, provider differences, and why workflow-facing files should not call provider CLIs directly.
4. Do not expose provider-specific skill names or deleted provider folders in the downstream `SKILL.md` files. Provider CLI details may appear in these boundary-skill `README.md` files because they document the implementation rationale.
5. Keep script paths out of generic workflow docs. In boundary-skill docs, script paths may appear only where they describe the skill's own implementation or operator/debugging interface.

**Verification**

```bash
test -f core/agents/skills/git-publish/README.md
test -f core/agents/skills/change-request-publish/README.md
test -f core/agents/skills/change-request-comments/README.md
test -f core/agents/skills/issue-tracker/README.md
! rg -n '^## Why|Why a script|raw `git push`|raw `gh pr create`|raw `glab mr create`' \
  core/agents/skills/git-publish/SKILL.md \
  core/agents/skills/change-request-publish/SKILL.md \
  core/agents/skills/change-request-comments/SKILL.md \
  core/agents/skills/issue-tracker/SKILL.md
codespell \
  core/agents/skills/git-publish \
  core/agents/skills/change-request-publish \
  core/agents/skills/change-request-comments \
  core/agents/skills/issue-tracker
```

Expected result: the `rg` command finds no rationale text in the listed `SKILL.md` files; rationale lives in the new sibling `README.md` files.

**Commit boundary**

```text
Move neutral skill rationale into READMEs
```

### Task 3 — Remove skill-internal script instructions from workflow-facing files

**Files**

- `core/opencode/agents/brainstorm.md`
- `core/opencode/agents/bugfix.md`
- `core/opencode/agents/planner.md`
- `core/opencode/agents/finish.md`
- `core/opencode/agents/implement.md`
- `core/opencode/agents/review-plan.md`
- `core/opencode/agents/review-code.md`
- `core/claude/skills/brainstorm/SKILL.md`
- `core/claude/skills/bugfix/SKILL.md`
- `core/claude/skills/finish/SKILL.md`
- `core/claude/skills/implement/SKILL.md`
- `core/claude/skills/planner/SKILL.md`
- `core/claude/skills/review-plan/SKILL.md`
- `core/claude/skills/review-code/SKILL.md`
- `core/agents/skills/workflow-bug-analysis/SKILL.md`
- `core/agents/skills/workflow-implementation/SKILL.md`

**Changes**

1. Replace body text such as ``bash .agents/skills/git-publish/scripts/push-branch.sh`` with skill-level language such as `use git-publish`.
2. Replace body text such as ``bash .claude/skills/change-request-publish/scripts/open-change-request.sh`` with `use change-request-publish`.
3. Replace `issue-tracker/scripts/create-issue.sh`, `update-issue.sh`, and `find-duplicate-issues.sh` instructions with `use issue-tracker to check duplicates, create tracker issues, and update tracker issues`.
4. In `workflow-implementation/SKILL.md`, keep the boundary concise: after verification, commit, then use `git-publish` and `change-request-publish`; do not explain script behavior.
5. Keep script paths only in permission blocks/frontmatter where the harness needs executable allow/ask patterns.

**Verification**

```bash
rg -n "\\.agents/skills/.*/scripts|\\.claude/skills/.*/scripts|issue-tracker/scripts" \
  core/opencode/agents \
  core/claude/skills \
  core/agents/skills/workflow-*

codespell \
  core/opencode/agents \
  core/claude/skills \
  core/agents/skills/workflow-*
```

Expected result: remaining script-path hits are only in permission/frontmatter blocks or in boundary skill docs, not workflow body instructions.

**Commit boundary**

```text
Use skill-level instructions in workflow files
```

### Task 4 — Align OpenCode agent permissions and skill allowlists

**Files**

- `core/opencode/agents/brainstorm.md`
- `core/opencode/agents/bugfix.md`
- `core/opencode/agents/planner.md`
- `core/opencode/agents/finish.md`
- `core/opencode/agents/implement.md`
- `core/opencode/agents/review-plan.md`
- `core/opencode/agents/review-code.md`

**Changes**

1. For each agent with `git-publish` script permission, add a corresponding `git-publish` skill allow entry.
2. For each agent that may open a change request, add both the `change-request-publish` skill allow entry and the script permission at the desired tier.
3. Apply PR feedback that `brainstorm` should allow opening a change request when publishing a brainstorming result.
4. Apply PR feedback that `review-plan` requires `git-publish`.
5. Apply PR feedback that `review-code` should be allowed to publish review-fix implementation plans; add `git-publish` permission and skill if this agent is expected to commit/publish its review-finding plan.
6. Keep direct script paths only in permission maps, not body instructions.

**Verification**

```bash
rg -n "git-publish|change-request-publish|change-request-comments|issue-tracker" core/opencode/agents
rg -n "\\.agents/skills/.*/scripts" core/opencode/agents
```

Expected result: permissions and skill allowlists line up, with script paths confined to permission maps.

**Commit boundary**

```text
Align OpenCode permissions for neutral repository skills
```

### Task 5 — Update installer skill inventories and README sync

**Files**

- `scripts/init.sh`
- `scripts/copy.sh`
- `README.md`
- `core/claude/README.md`
- `core/docs/agents/review-plan.md`
- `core/docs/agents/review-code.md`
- `core/docs/agents/agent-workflow-extension.md`

**Changes**

1. Remove `github-pr-comments` and `gitlab-mr-comments` from the `AUTHORED_SKILLS` arrays if Task 2 moved their implementation into `change-request-comments`.
2. Keep the neutral authored skills in both installer arrays: `git-publish`, `change-request-publish`, `change-request-comments`, and `issue-tracker`.
3. Update `README.md` authored skill list and symlink table to match the actual installed authored skills.
4. Update `core/claude/README.md` so it lists the neutral authored skills and removes stale `github-pr-comments`, `gitlab-mr-comments`, `github-publish`, and `gitlab-publish` references from downstream Claude documentation.
5. Remove README invocation guidance that points users at `/github-pr-comments`; use `/change-request-comments` or workflow-neutral language instead.
6. Update role docs and the workflow extension guide to name `change-request-comments` as the comment boundary.
7. Re-check `stacks/pnpm` and `stacks/maven` for overlays that need equivalent wording changes. Current expected result: no `agents/skills/` overlays exist in either stack; only stack docs/config overlays may need wording changes.
8. Lockfile check: confirm no lockfile edit is needed because `github-pr-comments` and `gitlab-mr-comments` are authored skills, not remote skills tracked by `core/skills-lock.json`. If a remote-skill entry is discovered, update only the affected lockfile scope.

**Verification**

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
codespell README.md core/claude/README.md core/docs/agents scripts/init.sh scripts/copy.sh
! rg -n "github-pr-comments|gitlab-mr-comments|github-publish|gitlab-publish" \
  README.md core/claude/README.md core/docs/agents scripts/init.sh scripts/copy.sh
! rg -n "github-pr-comments|gitlab-mr-comments|github|gitlab|PR|MR|gh |glab" stacks/pnpm stacks/maven
```

Expected result: provider comment skill names do not appear in downstream installer or generic docs except in explicitly justified boundary documentation.

**Commit boundary**

```text
Sync installers and docs with neutral comment skill
```

### Task 6 — Clean up Claude settings and OpenCode base config

**Files**

- `core/claude/settings.json`
- `core/opencode.json`

**Changes**

1. Group Claude permissions by neutral wrapper scripts, GitHub read-only support, and GitLab read-only support.
2. Put mutating neutral wrapper commands in `ask` unless the workflow intentionally allows them.
3. Ensure `issue-tracker/scripts/update-issue.sh` appears in only one permission tier.
4. Remove direct provider mutation permissions that are now handled through neutral wrapper scripts.
5. Keep `core/opencode.json` as a small permissive base config and avoid reintroducing `glab` base permissions.

**Verification**

```bash
jq . core/claude/settings.json > /dev/null
jq . core/opencode.json > /dev/null
! rg -n "github-publish|gitlab-publish|github-pr-comments|gitlab-mr-comments|create-bug-issue|update-bug-issue" \
  core/claude/settings.json core/opencode.json
jq '.permission.bash | keys' core/opencode.json
```

**Commit boundary**

```text
Normalize permissions for neutral repository workflows
```

### Task 7 — Replace the repo-local publish wrapper with self-maintenance skill symlinks

**Files**

- `AGENTS.md`
- `scripts/publish-branch.sh`
- `.agents/skills/git-publish`
- `.agents/skills/change-request-publish`

**Changes**

1. Delete `scripts/publish-branch.sh` with `git rm`.
2. Add self-maintenance symlinks so this repo can load the same neutral skills it installs downstream:
   - `.agents/skills/git-publish` → `../../core/agents/skills/git-publish`
   - `.agents/skills/change-request-publish` → `../../core/agents/skills/change-request-publish`
3. Update `AGENTS.md` Git Conventions to replace `Use scripts/publish-branch.sh` with `Use git-publish for branch pushes and change-request-publish for PR/MR creation`.
4. Confirm the symlink model remains clear: `.agents/skills/*` may contain repo-self-maintenance skills and symlinks to authored template skills; `core/agents/skills/*` remains the downstream template source.

**Verification**

```bash
test ! -e scripts/publish-branch.sh
ls -la .agents/skills/git-publish .agents/skills/change-request-publish
test "$(readlink .agents/skills/git-publish)" = "../../core/agents/skills/git-publish"
test "$(readlink .agents/skills/change-request-publish)" = "../../core/agents/skills/change-request-publish"
test "$(readlink .claude/skills/git-publish)" = "../../.agents/skills/git-publish"
test "$(readlink .claude/skills/change-request-publish)" = "../../.agents/skills/change-request-publish"
codespell AGENTS.md
```

**Commit boundary**

```text
Use neutral publish skills for repo maintenance
```

### Task 8 — Strengthen workflow boundary regression checks

**Files**

- `scripts/check-workflow-boundaries.sh`

**Changes**

1. Keep the existing provider-specific pattern checks.
2. Add checks for direct internal script references in workflow-facing body text, including `.agents/skills/.*/scripts/`, `.claude/skills/.*/scripts/`, and `<skill>/scripts/*.sh` forms.
3. Exclude boundary skill directories where script usage is the documented interface for that skill itself: `git-publish`, `change-request-publish`, `change-request-comments`, and `issue-tracker`.
4. Filter frontmatter permission blocks so valid OpenCode permission entries do not fail the body-instruction leakage check. Implement this explicitly by scanning only the markdown body after the opening YAML frontmatter (`--- ... ---`) for agent files; do not rely on a plain `rg` that cannot distinguish permissions from prose.
5. Keep permission-map script paths legal, but fail on the same paths in body prose, bullets, or examples in generic workflow files.
6. Run the check after Tasks 2–6 so the expected result is a clean pass. During earlier tasks, use the task-local `rg` commands because this regression check is not authoritative until this task updates it.

**Verification**

```bash
bash -n scripts/check-workflow-boundaries.sh
shellcheck scripts/check-workflow-boundaries.sh
bash scripts/check-workflow-boundaries.sh
```

**Commit boundary**

```text
Check workflow files for skill-internal leakage
```

## Final verification

Run from the repository root after all tasks:

```bash
bash -n scripts/init.sh scripts/copy.sh scripts/check-workflow-boundaries.sh
shellcheck scripts/init.sh scripts/copy.sh scripts/check-workflow-boundaries.sh
jq . core/claude/settings.json > /dev/null
jq . core/opencode.json > /dev/null
codespell AGENTS.md README.md core/claude/README.md core/agents/skills core/claude/skills core/opencode/agents core/docs/agents scripts
bash scripts/check-workflow-boundaries.sh
```

Smoke install under `.temp/`:

```bash
mkdir -p .temp/smoke-init
printf "1\n1\n.temp/smoke-init/target\n" | bash scripts/init.sh
ls -la .temp/smoke-init/target/.claude/skills
test ! -e .temp/smoke-init/target/.agents/skills/github-pr-comments
test ! -e .temp/smoke-init/target/.agents/skills/gitlab-mr-comments

mkdir -p .temp/smoke-copy/target
git -C .temp/smoke-copy/target init
git -C .temp/smoke-copy/target config user.email "test@example.com"
git -C .temp/smoke-copy/target config user.name "Test"
touch .temp/smoke-copy/target/README.md
git -C .temp/smoke-copy/target add README.md
git -C .temp/smoke-copy/target commit -m "init"
printf "1\n1\n" | bash scripts/copy.sh .temp/smoke-copy/target
ls -la .temp/smoke-copy/target/.claude/skills
test ! -e .temp/smoke-copy/target/.agents/skills/github-pr-comments
test ! -e .temp/smoke-copy/target/.agents/skills/gitlab-mr-comments

rm -rf .temp/smoke-init .temp/smoke-copy
```

## Acceptance criteria

- `AGENTS.md` explicitly prevents workflow-facing instructions from exposing skill internals.
- Generic workflow files name skills, not internal script paths.
- `change-request-comments` is the only downstream comment skill surface.
- Neutral skill `SKILL.md` files focus on invocation contracts; rationale lives in sibling `README.md` files.
- Installer arrays, README inventories, and symlink table match actual installed authored skills.
- OpenCode and Claude permissions allow neutral wrapper usage without documenting internal scripts in workflow bodies.
- Provider-specific CLI details live only inside boundary skills or provider-specific implementation code.
- Boundary checks prevent future provider-skill and internal-script leakage.
- Bash and smoke verification pass under `.temp/`.
