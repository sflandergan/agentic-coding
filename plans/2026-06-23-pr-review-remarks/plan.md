# PR Review Remarks Follow-up Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address approved PR review feedback for the self-maintenance agent configuration without changing the target-project toolkit templates beyond intentional symlink reuse.

**Configuration shape:** The change tightens self-maintenance OpenCode permissions, teaches the review agent to consume PR comments through the existing `github-pr-comments` skill, and refines planning/publishing behavior. The existing `core/agents/skills/github-pr-comments` skill remains the source of truth and is symlinked into the root self-maintenance skill set.

**Configuration surface:** Root self-maintenance files under `.opencode/`, `.agents/`, `.claude/`, `README.md`, and `scripts/publish-branch.sh`. Verify markdown/frontmatter, symlink targets, README inventory, script syntax, and spelling on touched prose files.

## Source Review Comments Covered

- Use the existing `github-pr-comments` skill internally for maintenance review and symlink it into the root skill surface.
- Split/clarify review skill responsibilities and include PR comment fetching.
- Phrase the self-maintenance review workflow like the core `review-plan` / `review-code` split: plan reviews update the reviewed plan/spec after approval; diff reviews write a separate review-finding implementation plan for `@implement` when fixes need planning.
- Reduce global `opencode.json` permissions because per-agent permissions own operational access.
- Tighten implementation agent shell permissions: remove unused `cut`/`paste`, avoid broad `cp`, keep `echo` but deny redirect forms.
- Deny direct push operations when publishing is handled by `scripts/publish-branch.sh`.
- Let planning publish/open a PR after writing a plan.
- Remove the `master` branch check from `scripts/publish-branch.sh`.
- Simplify planning skill wording around task steps and verification.
- Remove unnecessary implement-task backreference to `@implement`.
- Clarify verification ownership between `implement` and `implement-task`.

## File Mapping and Sync Invariants

| File | Action | Notes |
|---|---|---|
| `.agents/skills/github-pr-comments` | Add symlink | Points to `../../core/agents/skills/github-pr-comments`; self-maintenance-only reuse of existing core skill. |
| `.claude/skills/github-pr-comments` | Add symlink | Points to `../../.agents/skills/github-pr-comments`, matching repo symlink model. |
| `.opencode/agents/review.md` | Modify | Allow `github-pr-comments` skill and read-only fetch helper. |
| `.agents/skills/agent-review/SKILL.md` | Modify | Split plan/diff review guidance and add PR comment fetch workflow. |
| `README.md` | Modify | Add `github-pr-comments` to self-maintenance skill inventory and invocation text. |
| `opencode.json` | Modify | Reduce global permissions to safe defaults. |
| `.opencode/agents/implement.md` | Modify | Tighten shell permissions and direct-push policy. |
| `.opencode/agents/implement-task.md` | Modify | Tighten shell permissions, wording, and verification contract. |
| `.opencode/agents/planning.md` | Modify | Publish/open PR through helper after writing plan. |
| `.agents/skills/agent-planning/SKILL.md` | Modify | Simplify task granularity and verification wording. |
| `scripts/publish-branch.sh` | Modify | Remove `master` protected branch check. |

**Core/stacks ripple:** No stack overlays need updates. The only `core/` interaction is reusing the existing `core/agents/skills/github-pr-comments` skill by symlink from the root self-maintenance surface; no target-project installed output changes are intended.

**Lockfiles:** Do not change `skills-lock.json` or `core/skills-lock.json`. `github-pr-comments` is an authored in-repo skill, not a new remote skill. The root `skills-lock.json` remains scoped to remote self-maintenance skills, currently `writing-skills`.

**README sync:** Update the self-maintenance skill list under `README.md` so it matches `.agents/skills/` after adding the symlink.

**Dot-mapping:** No dot-mapping changes.

## Task 1: Add PR Comment Workflow to Review Agent

**Files:**

- Add symlink: `.agents/skills/github-pr-comments`
- Add symlink: `.claude/skills/github-pr-comments`
- Modify: `.opencode/agents/review.md`
- Modify: `.agents/skills/agent-review/SKILL.md`
- Modify: `README.md`

- [ ] **Step 1: Add self-maintenance skill symlinks**

Create symlinks:

```bash
ln -s ../../core/agents/skills/github-pr-comments .agents/skills/github-pr-comments
ln -s ../../.agents/skills/github-pr-comments .claude/skills/github-pr-comments
```

- [ ] **Step 2: Allow review agent to use the PR comment skill**

In `.opencode/agents/review.md`:

- Add the read-only helper permission under `permission.bash`:

```yaml
    "bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh *": allow
```

- Add the skill permission under `permission.skill`:

```yaml
    "github-pr-comments": allow
```

- Update the body to load `github-pr-comments` when reviewing PR remarks or PR diffs.

- [ ] **Step 3: Split and extend review skill guidance**

In `.agents/skills/agent-review/SKILL.md`:

- Keep one checklist for plan review.
- Keep one checklist for diff review.
- Add a `PR Comment Review` section that says to use `github-pr-comments` and run:

```bash
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>]
```

- State that inline comments must be checked against the current diff before accepting or dismissing them.
- Add a `Required Workflow` section phrased like the core review agents:

```markdown
Use this standard self-maintenance review workflow unless the user explicitly requests a different scope:

1. Read open PR comments first by using the `github-pr-comments` skill. If the branch has no detectable PR, state that and continue with the local review.
2. Identify whether the review target is a spec/plan or a diff. If multiple candidate plans exist and the user did not state which one to use, ask before continuing the plan-conformance part of the review.
3. Review the target yourself against `AGENTS.md`, repository conventions, sync invariants, and any approved spec or plan.
4. Combine PR comments, user notes, external notes, and your own findings into one deduplicated list of actionable issues.
5. Present suggested fixes as blocking issues and advisory suggestions first. Do not edit files yet.
6. For approved spec/plan review fixes, update the reviewed spec or plan directly under `plans/**`.
7. For approved diff review fixes that need planning or exceed trivial review-scoped changes, write a review-finding implementation plan next to the original plan, for example `plans/<feature-dir>/review-findings.md`. Do not adapt an unrelated implementation plan for new review findings, and do not create a new date-prefixed folder for review findings when an original plan exists.
8. After plan updates or review-finding plan creation, self-review every tracked remark and finding. Map each item to the changed section, review-finding plan section, or intentional unresolved status.
9. Draft exact GitHub replies for resolved PR comments and ask for explicit approval before posting. Approval to edit files or write a plan does not authorize posting GitHub comments.
```

- Keep the distinction explicit: **plan review updates the reviewed plan/spec after approval; diff review writes a review-finding implementation plan for `@implement` after approval.**

- [ ] **Step 4: Update README self-maintenance inventory**

In `README.md`, under the self-maintenance `Skills` section:

- Add `github-pr-comments` to the table.
- Update the invocation sentence to include `/github-pr-comments` if the section lists invocable skills.
- Preserve the distinction that this self-maintenance surface is not installed into target projects.

- [ ] **Step 5: Verify**

Run:

```bash
ls -la .agents/skills .claude/skills
codespell .opencode/agents/review.md .agents/skills/agent-review/SKILL.md README.md
```

Expected:

- Both symlinks resolve to the existing `github-pr-comments` skill.
- Codespell reports no errors.

- [ ] **Step 6: Commit**

```bash
git add .agents/skills/github-pr-comments .claude/skills/github-pr-comments .opencode/agents/review.md .agents/skills/agent-review/SKILL.md README.md
git commit -m "chore: add pr comment skill to review agent"
```

## Task 2: Tighten OpenCode and Implementation Agent Permissions

**Files:**

- Modify: `opencode.json`
- Modify: `.opencode/agents/implement.md`
- Modify: `.opencode/agents/implement-task.md`

- [ ] **Step 1: Reduce global permissions**

In `opencode.json`, change the root `permission` block so global defaults do not grant broad editing or bash execution. Keep read access enabled.

Use this shape unless OpenCode schema validation requires a different deny representation:

```json
"permission": {
  "bash": {
    "*": "ask"
  },
  "edit": {
    "*": "deny"
  },
  "read": {
    "*": "allow"
  },
  "webfetch": "ask"
}
```

- [ ] **Step 2: Tighten implement-task shell permissions**

In `.opencode/agents/implement-task.md`:

- Remove:

```yaml
    "cut *": allow
    "paste *": allow
```

- Change broad copy permission from allow to ask:

```yaml
    "cp *": ask
```

- Keep:

```yaml
    "echo *": allow
```

- Add protective deny rules after the `echo *` allow and after other broad helper allows, relying on last-match-wins behavior:

```yaml
    "echo *> *": deny
    "echo *>> *": deny
    "echo *>| *": deny
```

- Keep direct push denied:

```yaml
    "git push *": deny
```

- [ ] **Step 3: Tighten implement controller shell permissions**

In `.opencode/agents/implement.md`:

- Remove:

```yaml
    "cut *": allow
    "paste *": allow
```

- Change broad copy permission from allow to ask:

```yaml
    "cp *": ask
```

- Keep:

```yaml
    "echo *": allow
```

- Add protective deny rules after broad helper allows:

```yaml
    "echo *> *": deny
    "echo *>> *": deny
    "echo *>| *": deny
```

- Replace direct push ask/allow patterns with direct push denial:

```yaml
    "git push *": deny
```

- Keep only the publish helper permissions for publishing:

```yaml
    "scripts/publish-branch.sh": allow
    "bash scripts/publish-branch.sh": allow
```

- [ ] **Step 4: Refine implement-task wording**

In `.opencode/agents/implement-task.md`:

- Replace:

```markdown
Implement exactly one task provided by `@implement`. Keep context and edits scoped to that task.
```

with:

```markdown
Implement exactly one provided task. Keep context and edits scoped to that task.
```

- Clarify verification ownership so the worker runs task-level verification and the controller runs final verification. Preserve the worker requirement to report exact commands and results.

- [ ] **Step 5: Refine implement controller wording**

In `.opencode/agents/implement.md`:

- Keep the controller responsible for final verification and publishing through `scripts/publish-branch.sh` when the human asks.
- State that direct `git push` is not used by the agent; publishing goes through the helper.

- [ ] **Step 6: Verify**

Run:

```bash
codespell opencode.json .opencode/agents/implement.md .opencode/agents/implement-task.md
```

Expected: no spelling errors.

- [ ] **Step 7: Commit**

```bash
git add opencode.json .opencode/agents/implement.md .opencode/agents/implement-task.md
git commit -m "chore: tighten self-maintenance agent permissions"
```

## Task 3: Refine Planning and Publish Helper Behavior

**Files:**

- Modify: `.opencode/agents/planning.md`
- Modify: `.agents/skills/agent-planning/SKILL.md`
- Modify: `scripts/publish-branch.sh`

- [ ] **Step 1: Allow planning to publish through the helper**

In `.opencode/agents/planning.md`, add helper permissions under `permission.bash`:

```yaml
    "scripts/publish-branch.sh": allow
    "bash scripts/publish-branch.sh": allow
```

Do not add direct `git push` permissions.

- [ ] **Step 2: Update planning final behavior**

In `.opencode/agents/planning.md`, replace the final instruction:

```markdown
After writing the plan, report the plan path and any open questions.
```

with guidance to:

- Commit the plan file.
- Run `scripts/publish-branch.sh` to push the branch and create or report the PR.
- Report the plan path, PR URL, and any open questions.

- [ ] **Step 3: Simplify agent-planning skill wording**

In `.agents/skills/agent-planning/SKILL.md`:

- Replace “Steps within a task are 2-5 minute actions” with “Steps within a task are small concrete actions”.
- Replace the “No rigid TDD” line with direct verification guidance:

```markdown
Verification should match the changed files: shellcheck and `bash -n` for bash scripts, smoke runs for script behavior changes, `codespell` for prose-heavy changes, and consistency checks for README, lockfiles, symlinks, and dot-mapping.
```

- [ ] **Step 4: Remove master branch check**

In `scripts/publish-branch.sh`, change:

```bash
if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
```

to:

```bash
if [ "$branch" = "main" ]; then
```

- [ ] **Step 5: Verify**

Run:

```bash
bash -n scripts/publish-branch.sh
shellcheck scripts/publish-branch.sh
codespell .opencode/agents/planning.md .agents/skills/agent-planning/SKILL.md scripts/publish-branch.sh
```

Expected:

- Bash syntax check passes.
- Shellcheck reports no issues when installed.
- Codespell reports no errors.

- [ ] **Step 6: Commit**

```bash
git add .opencode/agents/planning.md .agents/skills/agent-planning/SKILL.md scripts/publish-branch.sh
git commit -m "chore: refine planning publish workflow"
```

## Final Verification

Run after all tasks are complete:

```bash
bash -n scripts/publish-branch.sh
shellcheck scripts/publish-branch.sh
ls -la .agents/skills .claude/skills
codespell README.md .opencode/agents/*.md .agents/skills/agent-planning/SKILL.md .agents/skills/agent-review/SKILL.md scripts/publish-branch.sh
git status --short
```

Expected:

- `bash -n` passes.
- `shellcheck` passes when available.
- Symlinks resolve and match the repo symlink model.
- README self-maintenance skill list matches `.agents/skills/`.
- No spelling errors in touched prose files.
- Working tree is clean after commits.

If `shellcheck` or `codespell` is unavailable, install it or record that the verification could not be run with the exact command output.
