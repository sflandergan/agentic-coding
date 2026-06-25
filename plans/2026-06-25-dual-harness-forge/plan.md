# Dual-Harness Implementer & Forge-Agnostic Publishing

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close two structural gaps identified by inspecting an adapted downstream project: (1) Claude Code has no `/implement` controller — implementation is OpenCode-only, and (2) publishing is GitHub-only with no skill wrapper, making it impossible to swap forge platforms or prevent agents from bypassing push safety.

**Configuration shape:** The Claude implementer adds two files to the core template layer (`core/claude/`) and updates six existing files for cross-references and documentation. Forge-agnostic publishing replaces the raw `scripts/publish-branch.sh` with a `github-publish` authored skill (same pattern as `github-pr-comments`), then adds a `gitlab` forge overlay under `core/forge/gitlab/` with its own publish and MR-comment skills. The installer scripts get a forge prompt.

**Configuration surface:**
- New: `core/claude/skills/implement/SKILL.md`, `core/claude/agents/implement-task.md`
- New: `core/agents/skills/github-publish/SKILL.md`, `core/agents/skills/github-publish/scripts/push-branch.sh`, `core/agents/skills/github-publish/scripts/open-pr.sh`
- New: `core/forge/gitlab/` tree (publish skill, MR-comments skill, opencode.json overlay, claude/settings.json overlay, AGENTS.md addition)
- Modified: `core/claude/README.md`, `core/claude/skills/planner/SKILL.md`, `core/claude/skills/review-code/SKILL.md`, `core/claude/skills/review-plan/SKILL.md`, `core/opencode/agents/implement.md`, `core/opencode/agents/implement-task.md`, `core/claude/settings.json`, `core/AGENTS.md`, `README.md`, `scripts/init.sh`, `scripts/copy.sh`
- Removed: `scripts/publish-branch.sh` (replaced by `github-publish` skill)

## File Map

### Part A — Claude Dual-Harness Implementer (core)

| File | Action | Responsibility |
|---|---|---|
| `core/claude/skills/implement/SKILL.md` | Create | Claude `/implement` controller — dispatches `implement-task` workers |
| `core/claude/agents/implement-task.md` | Create | Claude `implement-task` subagent definition |
| `core/claude/README.md` | Modify | Add `/implement` to skill table, add `implement-task` agent, update symlink inventory |
| `core/claude/skills/planner/SKILL.md` | Modify | Update stop conditions: mention `/implement` as Claude alternative to OpenCode handoff |
| `core/claude/skills/review-code/SKILL.md` | Modify | Update escalation rules: mention `/implement` for fix-plan execution |
| `core/claude/skills/review-plan/SKILL.md` | Modify | Update handoff text: mention `/implement` as Claude alternative |
| `core/docs/agents/implement-task.md` | Verify | Already correct — no changes expected |
| `README.md` | Modify | Add `implement` to Claude skill list, add `implement-task` agent mention |

### Part B — Forge-Agnostic Publishing (core)

| File | Action | Responsibility |
|---|---|---|
| `core/agents/skills/github-publish/SKILL.md` | Create | Safe publishing skill — refuses `main`, refuses force-push |
| `core/agents/skills/github-publish/scripts/push-branch.sh` | Create | Push guard (from `scripts/publish-branch.sh`, hardened) |
| `core/agents/skills/github-publish/scripts/open-pr.sh` | Create | PR creation with existence check |
| `core/opencode/agents/implement.md` | Modify | Replace raw `git push` / `gh pr create` with `github-publish` skill references |
| `core/opencode/agents/implement-task.md` | Modify | No changes expected (workers don't push) |
| `core/opencode/agents/finish.md` | Modify | Replace raw `git push` with `github-publish` skill reference |
| `core/claude/skills/finish/SKILL.md` | Modify | Replace raw `git push` with `github-publish` skill reference |
| `core/claude/skills/brainstorm/SKILL.md` | Modify | Replace raw `git push` with `github-publish` skill reference |
| `core/claude/settings.json` | Modify | Add `github-publish` script permissions |
| `scripts/publish-branch.sh` | Delete | Replaced by `github-publish` skill |
| `README.md` | Modify | Add `github-publish` to authored skills list |

### Part C — GitLab Forge Overlay

| File | Action | Responsibility |
|---|---|---|
| `core/forge/gitlab/AGENTS.md` | Create | GitLab-specific conventions addition |
| `core/forge/gitlab/.agents/skills/gitlab-publish/SKILL.md` | Create | GitLab safe publishing skill |
| `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/push-branch.sh` | Create | Push guard (refuses `main`/`master`) |
| `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/open-mr.sh` | Create | MR creation with `glab` |
| `core/forge/gitlab/.agents/skills/gitlab-mr-comments/SKILL.md` | Create | GitLab MR comment fetching and reply |
| `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh` | Create | MR discussion fetcher |
| `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh` | Create | MR discussion reply poster |
| `core/forge/gitlab/opencode.json` | Create | GitLab-specific bash permission overlays |
| `core/forge/gitlab/claude/settings.json` | Create | GitLab-specific Claude permission overlays |
| `core/forge/gitlab/docs/agents/review-plan.md` | Create | GitLab MR comments loading addition |
| `core/forge/gitlab/docs/agents/review-code.md` | Create | GitLab MR comments loading addition |
| `core/forge/gitlab/docs/agents/bugfix.md` | Create | GitLab issue creation addition |
| `scripts/init.sh` | Modify | Add forge prompt (github/gitlab) |
| `scripts/copy.sh` | Modify | Add forge prompt, merge forge overlay |
| `README.md` | Modify | Document forge dimension, update symlink table |

---

## Task 1: Create Claude `/implement` Controller Skill

**Files:**
- Create: `core/claude/skills/implement/SKILL.md`

- [ ] **Step 1: Write the implement controller skill**

Create `core/claude/skills/implement/SKILL.md`:

```markdown
---
name: implement
description: Executes an approved plan task-by-task in Claude Code — dispatches a fresh implement-task worker per task, reviews each diff, and runs verification before any completion claim.
argument-hint: [path to approved plan]
disable-model-invocation: true
---

You are the implementation controller for this repository.
This is the Claude Code half of implementation; OpenCode (`@implement`) is the equivalent controller on that harness.
Pick one harness per branch — do not run both controllers over the same plan.

Approved plan (if provided): $ARGUMENTS

## Load first

Load `docs/agents/implement.md` and follow its document list exactly.
Then load the approved `plan.md` (and `spec.md` if present) and the docs the plan names.

Use the `workflow-verification` skill before any completion claim.
Do not say work is complete, fixed, or passing unless the relevant verification commands have just run successfully.

## Execution rules

- **Never implement on `main`.** Create or ask for a scoped branch first.
- **Default behavior:** execute the plan task-by-task by dispatching a fresh `implement-task` worker (via the Agent tool, `subagent_type: implement-task`) for each task. This is the standard workflow — do not deviate unless the user explicitly asks for inline implementation.
- **Inline implementation:** acceptable only when the user explicitly asks you to implement directly. When inline, apply the same per-task and review gates as delegated workers.
- **Controller duties:** orchestrate — dispatch tasks, package context for workers, review worker reports and diffs, enforce spec compliance and code-quality gates, and run verification before any completion claim. Give the worker the full task text, relevant context, exact plan/spec paths, affected docs, and current branch state; do not make it reread the whole plan.
- **One focused commit per task.** Delegated workers create the task commit; commit inline only when you execute a task yourself. Review the worker report and `git diff` before moving on.
- Follow TDD for behavior changes unless the plan marks a step as docs-only, config-only, or trivial wiring.
- Do not pause between tasks for routine progress approval.
- Stop and ask only when the same task fails more than three times, the plan conflicts with code reality, or an architectural decision is required. If a task needs an architectural decision, report the blocker and recommend human escalation.

## Model selection

Each per-task `implement-task` worker runs on Sonnet — the `implement-task` agent pins `model: sonnet`, so leave the model override off when dispatching it.
If a worker fails to deliver a task (after the per-task retry limit), re-dispatch the same task with a `model` override to a more capable model before escalating to a human.

## Verification

Run targeted verification while iterating and the required final verification before claiming completion. Use the `workflow-verification` skill as the completion gate.

## Shell guidance

- Prefer `git mv` for moves/renames of tracked paths and `git rm` for removals of tracked paths. Use plain `mv`/`rm` only for untracked paths.
- Never work on or push to `main`. Publish through the `github-publish` skill — do not hand-roll `git push`.

## Finishing

After final verification, commit all changes and push the branch with the `github-publish` skill:
`bash .claude/skills/github-publish/scripts/push-branch.sh`.
Then open a pull request with `bash .claude/skills/github-publish/scripts/open-pr.sh` — it skips creation when a PR already exists for the branch.
```

- [ ] **Step 2: Verify**

Run: `codespell core/claude/skills/implement/SKILL.md`
Expected: no errors (or only false positives for agent-specific terms)

- [ ] **Step 3: Commit**

```bash
git add core/claude/skills/implement/SKILL.md
git commit -m "feat: add Claude /implement controller skill"
```

---

## Task 2: Create Claude `implement-task` Subagent

**Files:**
- Create: `core/claude/agents/implement-task.md`

- [ ] **Step 1: Write the implement-task subagent definition**

Create `core/claude/agents/implement-task.md`:

```markdown
---
name: implement-task
description: Worker that implements one approved plan task with TDD, a single focused commit, and self-review. Dispatched by the /implement controller — one fresh worker per task.
tools: Bash, Read, Edit, Write, Glob, Grep, Agent
model: sonnet
---

You are the single-task implementation worker for this repository.

Implement exactly one task provided by the `/implement` controller.
Do not read or execute unrelated tasks from the plan unless the controller explicitly asks.

Load `docs/agents/implement-task.md` and only the task context, spec/plan excerpts, and docs provided or named by the controller.

## Rules

- Never work on `main`.
- Follow the provided task text, spec/plan context, and the repository docs the guide (`docs/agents/implement-task.md`) tells you to load for the area you touch.
- Follow TDD for behavior changes unless the task is explicitly docs-only, config-only, or trivial wiring.
- Make the smallest correct change. Make small, justified adaptations to fit the current codebase, and report them clearly.
- If you need to verify an exact file path, module boundary, or existing pattern before editing, dispatch an `Explore` subagent with a focused question rather than guessing. Use it only for read-only verification of your one task — do not re-plan, widen scope, or dispatch other implementers.
- Prefer `git mv` for moves/renames of tracked paths and `git rm` for removals of tracked paths. Use plain `mv`/`rm` only for untracked paths.
- Commit exactly the task changes with the commit message specified by the plan, or a concise message if the plan omitted one.
- Do not push, create pull requests, amend commits, delete branches, remove worktrees, or dispatch other implementers.
- If requirements are unclear, report `NEEDS_CONTEXT` before editing.
- If blocked after three attempts on the same issue, report `BLOCKED` with what you tried.

Before reporting, self-review the diff for spec compliance, overbuilding, tests, and obvious defects.

## Report format

- **Status:** `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED`
- **Commit:** commit SHA or `none`
- **Implemented:** concise summary
- **Verification:** exact commands run and results
- **Files changed:** paths
- **Concerns:** anything the controller should inspect
```

- [ ] **Step 2: Verify**

Run: `codespell core/claude/agents/implement-task.md`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add core/claude/agents/implement-task.md
git commit -m "feat: add Claude implement-task subagent definition"
```

---

## Task 3: Create `github-publish` Authored Skill

**Files:**
- Create: `core/agents/skills/github-publish/SKILL.md`
- Create: `core/agents/skills/github-publish/scripts/push-branch.sh`
- Create: `core/agents/skills/github-publish/scripts/open-pr.sh`

- [ ] **Step 1: Write the SKILL.md**

Create `core/agents/skills/github-publish/SKILL.md`:

```markdown
---
name: github-publish
description: Use when pushing a branch or opening a pull request — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# GitHub Publish

Safe publishing for this repository. Pushing and opening pull requests go through bundled scripts that **refuse to act on `main`** and refuse force-pushes.

## Why a script, not a raw `git push`

`git push origin $(git rev-parse --abbrev-ref HEAD)` does **not** protect `main`: while you are on `main` it expands to `git push origin main`, and permission globs cannot see through the command substitution to block it. The guard has to inspect the current branch at run time, which is what these scripts do.

## Push the current branch

```bash
bash .agents/skills/github-publish/scripts/push-branch.sh
```

It pushes the current branch to `origin`, refusing if the branch is `main` or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. Extra arguments (e.g. `--set-upstream`) are passed through.

## Open a pull request

```bash
bash .agents/skills/github-publish/scripts/open-pr.sh [gh pr create flags]
```

It refuses on `main`, skips creation when a PR already exists for the current branch (printing the existing one), and otherwise runs `gh pr create` for the current branch. Pass `--fill` to derive the title/description from commits, or `--title`/`--description` explicitly.

## Rules

- Never bypass these scripts with a raw `git push` to publish work — the protection only holds if publishing goes through them.
- Force-pushing and pushing to `main` are out of scope for this skill; they require a deliberate, human-run command.
```

- [ ] **Step 2: Write push-branch.sh**

Create `core/agents/skills/github-publish/scripts/push-branch.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing to push: current branch is "%s". Create a scoped feature branch first.\n' "$branch" >&2
    exit 1
    ;;
esac

# Force-pushing is never part of safe publishing.
for arg in "$@"; do
  case "$arg" in
    --force|-f|--force-with-lease|--force-with-lease=*)
      printf 'Refusing to force-push from this script. Force-push must be a deliberate, human-run command.\n' >&2
      exit 1
      ;;
  esac
done

printf 'Pushing branch "%s" to origin...\n' "$branch"
git push origin "$branch" "$@"
```

- [ ] **Step 3: Write open-pr.sh**

Create `core/agents/skills/github-publish/scripts/open-pr.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing: current branch is "%s". Open a pull request from a feature branch.\n' "$branch" >&2
    exit 1
    ;;
esac

# Skip creation if a pull request already exists for this branch.
existing="$(gh pr list --head "$branch" --json url --jq 'length')"
if [ "${existing:-0}" -gt 0 ]; then
  printf 'A pull request already exists for branch "%s":\n' "$branch"
  gh pr list --head "$branch" --json url,title --jq '.[] | "  \(.title) — \(.url)"'
  exit 0
fi

printf 'Opening pull request for branch "%s"...\n' "$branch"
gh pr create --head "$branch" "$@"
```

- [ ] **Step 4: Make scripts executable**

```bash
chmod +x core/agents/skills/github-publish/scripts/push-branch.sh
chmod +x core/agents/skills/github-publish/scripts/open-pr.sh
```

- [ ] **Step 5: Verify**

Run: `shellcheck core/agents/skills/github-publish/scripts/*.sh`
Run: `bash -n core/agents/skills/github-publish/scripts/*.sh`
Run: `codespell core/agents/skills/github-publish/SKILL.md`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/github-publish/
git commit -m "feat: add github-publish authored skill with push guard and PR opener"
```

---

## Task 4: Wire `github-publish` into OpenCode Agents

**Files:**
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/finish.md`

- [ ] **Step 1: Update implement.md**

In `core/opencode/agents/implement.md`:

Replace the raw push/PR instructions in the body (lines 100-113) with `github-publish` skill references. Specifically:

- Replace line 100 (`Always use 'git push origin $(git rev-parse --abbrev-ref HEAD)'...`) with:
  `Publish through the 'github-publish' skill — 'bash .agents/skills/github-publish/scripts/push-branch.sh' to push, which refuses 'main'. Never hand-roll 'git push': 'git push origin $(...)' silently pushes 'main' when the current branch is 'main'.`

- Replace line 101 (the `gh pr list --head` check) with:
  `Open a pull request with 'bash .agents/skills/github-publish/scripts/open-pr.sh' — it skips creation when a PR already exists for the current branch.`

- Replace line 113 (the final push+PR block) with:
  `After final verification, commit all changes, push the branch with 'bash .agents/skills/github-publish/scripts/push-branch.sh', and open a GitHub pull request with 'bash .agents/skills/github-publish/scripts/open-pr.sh' (it no-ops when a PR already exists). The push script refuses 'main'.`

- Add `github-publish` to the skill permission allowlist:
  Replace `"workflow-implementation": allow` with:
  ```
  "workflow-implementation": allow
  "github-publish": allow
  ```

- Add the publish script to bash permissions:
  After the `"git push origin $(git rev-parse --abbrev-ref HEAD)": allow` line, add:
  ```
  "bash .agents/skills/github-publish/scripts/push-branch.sh*": allow
  "bash .agents/skills/github-publish/scripts/open-pr.sh*": ask
  ```

- Remove the `"git push origin $(git rev-parse --abbrev-ref HEAD)": allow` line (no longer needed since the skill handles it).

- [ ] **Step 2: Update finish.md**

In `core/opencode/agents/finish.md`:

- Replace the push instruction in the body with a `github-publish` skill reference.
- Add `github-publish` to the skill permission allowlist.
- Add the publish script permissions to bash.
- Remove any raw `git push` permission lines that are replaced by the skill.

- [ ] **Step 3: Verify**

Run: `codespell core/opencode/agents/implement.md core/opencode/agents/finish.md`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add core/opencode/agents/implement.md core/opencode/agents/finish.md
git commit -m "refactor: wire github-publish skill into OpenCode implement and finish agents"
```

---

## Task 5: Wire `github-publish` into Claude Skills

**Files:**
- Modify: `core/claude/skills/finish/SKILL.md`
- Modify: `core/claude/skills/brainstorm/SKILL.md`
- Modify: `core/claude/settings.json`

- [ ] **Step 1: Update finish/SKILL.md**

In `core/claude/skills/finish/SKILL.md`:

- Replace step 5 (lines 49-51) push instruction:
  From: `git push origin $(git rev-parse --abbrev-ref HEAD)`
  To: `bash .claude/skills/github-publish/scripts/push-branch.sh`

- Update the "Push boundaries" section (lines 53-57):
  Replace the raw `git push` instruction with:
  `Push only with 'bash .claude/skills/github-publish/scripts/push-branch.sh'. Never use bare 'git push', push to 'main', force-push, delete remote refs, push tags, or push arbitrary refspecs without explicit approval. Do not create PRs, amend commits, delete branches, close comments, or remove worktrees.`

- [ ] **Step 2: Update brainstorm/SKILL.md**

In `core/claude/skills/brainstorm/SKILL.md`:

- Replace the shell guidance (lines 34-35):
  From: `Always use 'git push origin $(git rev-parse --abbrev-ref HEAD)' — never use bare 'git push' to avoid accidentally pushing to 'main'.`
  To: `Publish through the 'github-publish' skill — 'bash .claude/skills/github-publish/scripts/push-branch.sh'. Never hand-roll 'git push'.`

- [ ] **Step 3: Update settings.json**

In `core/claude/settings.json`:

Add to the `allow` array:
```
"Bash(bash .claude/skills/github-publish/scripts/push-branch.sh:*)"
```

Add to the `ask` array:
```
"Bash(bash .claude/skills/github-publish/scripts/open-pr.sh:*)"
```

- [ ] **Step 4: Verify**

Run: `codespell core/claude/skills/finish/SKILL.md core/claude/skills/brainstorm/SKILL.md`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add core/claude/skills/finish/SKILL.md core/claude/skills/brainstorm/SKILL.md core/claude/settings.json
git commit -m "refactor: wire github-publish skill into Claude finish, brainstorm, and settings"
```

---

## Task 6: Delete Raw `scripts/publish-branch.sh`

**Files:**
- Delete: `scripts/publish-branch.sh`

- [ ] **Step 1: Remove the file**

```bash
git rm scripts/publish-branch.sh
```

- [ ] **Step 2: Update AGENTS.md references**

In `AGENTS.md` (repo-root self-maintenance conventions), the line referencing `scripts/publish-branch.sh` needs updating:

Replace:
`Use 'scripts/publish-branch.sh' for branch publishing and PR creation so branch-safety checks are centralized.`

With:
`Use the 'github-publish' skill scripts for branch publishing and PR creation so branch-safety checks are centralized. Never hand-roll 'git push'.`

- [ ] **Step 3: Verify**

Run: `codespell AGENTS.md`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md
git commit -m "refactor: replace publish-branch.sh with github-publish skill references"
```

---

## Task 7: Update Claude README for Dual Harness

**Files:**
- Modify: `core/claude/README.md`

- [ ] **Step 1: Update the skill table**

In `core/claude/README.md`, update the skill table to add `/implement`:

```markdown
| Skill (`/name`) | OpenCode counterpart | Role |
| --- | --- | --- |
| `/brainstorm`  | `@brainstorm`  | Idea → approved `spec.md` (interactive; offers domain grilling) |
| `/bugfix`      | `@bugfix`      | Investigate bug → structured GitHub issue; does not fix |
| `/planner`     | `@planner`     | Spec → task-by-task `plan.md` (offers grilling only when new domain language or non-trivial decisions appear) |
| `/implement`   | `@implement`   | Execute plan task-by-task via `implement-task` workers, verify, commit |
| `/review-plan` | `@review-plan` | Review + finalize the hand-off plan |
| `/review-code` | `@review-code` | Review a diff/PR → fix-plan hand-off doc |
| `/finish`      | `@finish`      | Durable feature doc, light glossary/ADR reconciliation, cleanup |
```

- [ ] **Step 2: Update the design principle section**

Replace the opening paragraph:
From: `Claude Code runs the **conversational** half of the agent pipeline. The **implementation** half stays in OpenCode.`
To: `Claude Code runs both the **conversational** and **implementation** halves of the agent pipeline. OpenCode provides the same pipeline; pick one harness per branch.`

- [ ] **Step 3: Update the shared authored skills list**

Add `github-publish` to the shared authored skills list:
`- 'github-publish' — used by '/implement', '/finish' (+ OpenCode)`

Update the symlink inventory to include `github-publish`:
Add to the symlinked shared skills list:
`- 'github-publish' — used by '/implement', '/finish' (+ OpenCode)`

- [ ] **Step 4: Update the "Usage" section**

Update the usage line to include `/implement`:
`Type '/brainstorm', '/bugfix', '/implement', '/planner', '/review-plan', '/review-code', or '/finish'`

- [ ] **Step 5: Update the permissions section**

Update the permissions description to mention the `github-publish` skill scripts instead of `gh pr create`.

- [ ] **Step 6: Verify**

Run: `codespell core/claude/README.md`
Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add core/claude/README.md
git commit -m "docs: update Claude README for /implement controller and github-publish skill"
```

---

## Task 8: Update Existing Claude Skills for `/implement` Cross-References

**Files:**
- Modify: `core/claude/skills/planner/SKILL.md`
- Modify: `core/claude/skills/review-code/SKILL.md`
- Modify: `core/claude/skills/review-plan/SKILL.md`

- [ ] **Step 1: Update planner/SKILL.md stop conditions**

In `core/claude/skills/planner/SKILL.md`, replace the stop conditions (lines 74-77):

From:
```
- After the plan is written, **stop**. Optionally suggest `/review-plan` before handoff.
- Implementation runs in **OpenCode** (`@implement` / `@implement-task`), not Claude Code.
  Hand off to OpenCode for execution.
```

To:
```
- After the plan is written, **stop**. Optionally suggest `/review-plan` before handoff.
- Implementation can run in either harness: Claude Code (`/implement`) or OpenCode
  (`@implement`). Pick one per branch. Suggest the user's preferred harness.
```

- [ ] **Step 2: Update review-code/SKILL.md escalation rules**

In `core/claude/skills/review-code/SKILL.md`, update step 7 (lines 73-76):

From:
```
7. If the user approves dispatching `@implement-task` for trivial review-scoped fixes,
   dispatch focused tasks only after presenting the exact fix instructions. In Claude
   Code, prefer writing the fix-plan handoff document and handing it to OpenCode
   (`@implement` / `@implement-task`) for TDD implementation.
```

To:
```
7. If the user approves dispatching `@implement-task` or `/implement` for trivial
   review-scoped fixes, dispatch focused tasks only after presenting the exact fix
   instructions. Pick one harness per branch.
```

- [ ] **Step 3: Update review-plan/SKILL.md finalization**

In `core/claude/skills/review-plan/SKILL.md`, update the handoff section (line 78):

From:
`4. Report the finalized plan path and confirm it is ready for OpenCode handoff.`

To:
`4. Report the finalized plan path and confirm it is ready for implementation handoff (Claude '/implement' or OpenCode '@implement').`

- [ ] **Step 4: Verify**

Run: `codespell core/claude/skills/planner/SKILL.md core/claude/skills/review-code/SKILL.md core/claude/skills/review-plan/SKILL.md`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add core/claude/skills/planner/SKILL.md core/claude/skills/review-code/SKILL.md core/claude/skills/review-plan/SKILL.md
git commit -m "refactor: update Claude planner, review-code, review-plan for dual-harness /implement"
```

---

## Task 9: Symlink `github-publish` into Claude Skills

**Files:**
- Modify: `core/claude/` (symlink creation — handled by `init.sh` / `copy.sh`)
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Update init.sh symlink creation**

In `scripts/init.sh`, find the section that creates Claude symlinks (the loop that symlinks authored skills from `.agents/skills/` into `.claude/skills/`). Add `github-publish` to the list of skills to symlink.

The exact location depends on the current script structure. Look for the array or loop that lists: `grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-verification`, `feature-documentation`, `github-pr-comments`.

Add `github-publish` to that list.

- [ ] **Step 2: Update copy.sh symlink creation**

Same change in `scripts/copy.sh` — add `github-publish` to the symlink list.

- [ ] **Step 3: Verify**

Run: `shellcheck scripts/init.sh scripts/copy.sh`
Run: `bash -n scripts/init.sh scripts/copy.sh`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add scripts/init.sh scripts/copy.sh
git commit -m "feat: add github-publish to Claude symlink creation in installer scripts"
```

---

## Task 10: Create GitLab Forge Overlay Structure

**Files:**
- Create: `core/forge/gitlab/AGENTS.md`
- Create: `core/forge/gitlab/.agents/skills/gitlab-publish/SKILL.md`
- Create: `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/push-branch.sh`
- Create: `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/open-mr.sh`
- Create: `core/forge/gitlab/.agents/skills/gitlab-mr-comments/SKILL.md`
- Create: `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
- Create: `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`

- [ ] **Step 1: Create AGENTS.md**

Create `core/forge/gitlab/AGENTS.md`:

```markdown
## GitLab Conventions

This repository uses GitLab as its forge. Merge requests (not pull requests) are the review surface. Use `glab` (GitLab CLI) for all forge operations.

- Publishing goes through `gitlab-publish` skill scripts — never hand-roll `git push`.
- MR comment workflows go through `gitlab-mr-comments` skill scripts.
- Issues are created and managed via `glab issue create/view/list/update`.
```

- [ ] **Step 2: Create gitlab-publish SKILL.md**

Create `core/forge/gitlab/.agents/skills/gitlab-publish/SKILL.md`:

```markdown
---
name: gitlab-publish
description: Use when pushing a branch or opening a merge request — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# GitLab Publish

Safe publishing for this repository. Pushing and opening merge requests go through bundled scripts that **refuse to act on `main`/`master`** and refuse force-pushes.

## Why a script, not a raw `git push`

`git push origin $(git rev-parse --abbrev-ref HEAD)` does **not** protect `main`: while you are on `main` it expands to `git push origin main`, and permission globs cannot see through the command substitution to block it. The guard has to inspect the current branch at run time, which is what these scripts do.

## Push the current branch

```bash
bash .agents/skills/gitlab-publish/scripts/push-branch.sh
```

It pushes the current branch to `origin`, refusing if the branch is `main`, `master`, or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. Extra arguments (e.g. `--set-upstream`) are passed through.

## Open a merge request

```bash
bash .agents/skills/gitlab-publish/scripts/open-mr.sh [glab mr create flags]
```

It refuses on `main`/`master`, skips creation when an MR already exists for the current branch (printing the existing one), and otherwise runs `glab mr create` for the current branch. Pass `--fill` to derive the title/description from commits, or `--title`/`--description` explicitly.

## Rules

- Never bypass these scripts with a raw `git push` to publish work — the protection only holds if publishing goes through them.
- Force-pushing and pushing to `main`/`master` are out of scope for this skill; they require a deliberate, human-run command.
```

- [ ] **Step 3: Create gitlab-publish push-branch.sh**

Create `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/push-branch.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing to push: current branch is "%s". Create a scoped feature branch first.\n' "$branch" >&2
    exit 1
    ;;
esac

# Force-pushing is never part of safe publishing.
for arg in "$@"; do
  case "$arg" in
    --force|-f|--force-with-lease|--force-with-lease=*)
      printf 'Refusing to force-push from this script. Force-push must be a deliberate, human-run command.\n' >&2
      exit 1
      ;;
  esac
done

printf 'Pushing branch "%s" to origin...\n' "$branch"
git push origin "$branch" "$@"
```

- [ ] **Step 4: Create gitlab-publish open-mr.sh**

Create `core/forge/gitlab/.agents/skills/gitlab-publish/scripts/open-mr.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

case "$branch" in
  main|master|HEAD)
    printf 'Refusing: current branch is "%s". Open a merge request from a feature branch.\n' "$branch" >&2
    exit 1
    ;;
esac

# Skip creation if a merge request already exists for this branch.
existing="$(glab mr list --source-branch "$branch" -F json 2>/dev/null | jq -r 'length' || echo 0)"
if [ "${existing:-0}" -gt 0 ]; then
  printf 'A merge request already exists for branch "%s":\n' "$branch"
  glab mr list --source-branch "$branch"
  exit 0
fi

printf 'Opening merge request for branch "%s"...\n' "$branch"
glab mr create --source-branch "$branch" "$@"
```

- [ ] **Step 5: Create gitlab-mr-comments SKILL.md**

Create `core/forge/gitlab/.agents/skills/gitlab-mr-comments/SKILL.md`:

```markdown
---
name: gitlab-mr-comments
description: Use when GitLab merge request feedback lives in plain notes, inline diff discussions, or discussion threads
user-invocable: false
---

# GitLab MR Comments

Use this for team merge request review workflows where feedback is stored as GitLab notes and discussions.

## Baseline Failure To Avoid

Agents naturally mix the GitLab note surfaces: they may read a standalone conversation note when feedback is actually an unresolved inline diff discussion, post a new top-level note instead of replying inside the existing thread, or edit someone else's note instead of replying to it.

## Skill Scope

This skill owns MR note mechanics: fetching notes, discussions, and the diff; distinguishing standalone conversation notes from inline diff discussions; obtaining exact discussion IDs; and posting approved replies through project scripts.

This skill does not own role-level review orchestration. The calling review agent decides how to interpret notes, validate technical claims, combine them with other findings, suggest fixes, edit files, dispatch implementers, or perform final self-review.

## Read Notes

Use the bundled read-only helper before proposing fixes. It fetches standalone conversation notes, unresolved inline diff discussions, and the MR diff:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>]
```

When `<mr>` is omitted, the script auto-detects the MR internal ID (`iid`) from the current branch.

Run the command exactly as shown, without quoting the script path. The review agents have explicit auto-permissions for this command form.

The helper prints a compact summary first, then full MR metadata, the discussions JSON, and the MR diff. Use the summary for grouping and the full JSON sections for exact discussion IDs.

Optional read-only modes:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --comments-only
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --diff-only
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --json
```

Do not call `glab` directly for reading MR metadata, notes, discussions, or diffs. The helper is the stable interface for this workflow.

## Classify Notes

- Standalone conversation notes: top-level MR discussion entries (`individual_note: true`), the GitLab analog of a plain comment.
- Inline diff discussions: resolvable threads whose notes carry a `diff position` (file path and line). Surface only those that are unresolved.
- Outdated inline discussions may still be valid; verify against the current diff before dismissing.

## Review Workflow

1. Fetch MR notes and diff when the caller's workflow involves an MR.
2. Use the summary to group target types, then use the full discussions JSON for exact discussion IDs.
3. Distinguish standalone conversation notes from inline diff discussions before posting replies.
4. Surface outdated inline discussions as context; the calling review agent decides whether they still apply.
5. For posting, require an exact approved reply batch with the discussion ID and body.
6. Post only the exact approved reply batch.

## Replies

Replying mutates GitLab state, so it is not hidden behind the read helper. Approval for edits, fixes, planning, or any other non-GitLab action does not authorize posting GitLab notes.

Before posting, present the exact reply batch to the user. Include the discussion ID and body. Wait for explicit approval for that batch.

After approval, reply inside the existing thread through the project script. Use the `id` of the discussion from the read helper as `discussion_id`:

Pass a JSON array as the final argument:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh [<mr>] '[
  { "discussion_id": "a1b2c3d4...", "body": "Fixed in abc123." },
  { "discussion_id": "e5f6g7h8...", "body": "Good catch, updated." }
]'
```

The MR number is optional; when omitted, the script auto-detects it from the current branch. Use a one-element array for a single reply. This script replies inside existing discussion threads; it does not open new standalone notes.

## Common Mistakes

- Treating standalone conversation notes as complete enough for inline diff review.
- Posting a new top-level note when the user asked to reply inside an inline thread.
- Resolving, editing, or deleting notes without explicit approval.
- Applying external feedback without checking whether it is technically correct.
- Treating approval for edits, fixes, planning, or other non-GitLab work as approval to post GitLab replies.
- Posting a reply batch that differs from the exact batch the user approved.
```

- [ ] **Step 6: Create gitlab-mr-comments fetch-mr-comments.sh**

Create `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -gt 2 ]; then
  printf 'Usage: %s [<mr-iid>] [--comments-only|--diff-only|--json]\n' "$0" >&2
  exit 2
fi

if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
  mr="$1"
  mode="${2:-}"
else
  mr="$(glab mr view -F json | jq -r '.iid')"
  mode="${1:-}"
fi
case "$mode" in
  ""|--comments-only|--diff-only|--json) ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    printf 'Usage: %s [<mr-iid>] [--comments-only|--diff-only|--json]\n' "$0" >&2
    exit 2
    ;;
esac

if [ "$mode" = "--diff-only" ]; then
  glab mr diff "$mr"
  exit 0
fi

mr_json="$(glab mr view "$mr" -F json)"
discussions_json="$(glab api --paginate "projects/:id/merge_requests/$mr/discussions?per_page=100")"

if [ "$mode" = "--json" ]; then
  jq -n \
    --argjson mr "$mr_json" \
    --argjson discussions "$discussions_json" \
    '{ mr: $mr, discussions: $discussions }'
  exit 0
fi

printf '## Note Summary\n'
jq -r \
  --argjson mr "$mr_json" '
  def summarize: (. // "" | gsub("\\s+"; " ") | .[0:180]);
  "MR !\($mr.iid): \($mr.title)",
  "Branch: \($mr.source_branch) -> \($mr.target_branch)",
  "URL: \($mr.web_url)",
  "",
  "Standalone conversation notes (\([.[] | select(.individual_note == true)] | length)):",
  ( .[] | select(.individual_note == true) | .notes[] | select(.system == false)
    | "- discussion_id=\(.id // "?") note=\(.id) author=\(.author.username) updated=\(.updated_at): \(.body | summarize)" ),
  "",
  "Unresolved inline diff discussions:",
  ( .[] | select(.individual_note != true) | . as $d
    | select([.notes[] | select(.resolvable == true and .resolved == false)] | length > 0)
    | .notes[0] as $n
    | "- discussion_id=\($d.id) \($n.position.new_path // $n.position.old_path // "?"):\($n.position.new_line // $n.position.old_line // "?") author=\($n.author.username) updated=\($n.updated_at): \($n.body | summarize)" )
  ' <<<"$discussions_json"

printf '\n## MR\n'
printf '%s\n' "$mr_json"

printf '\n## Discussions\n'
printf '%s\n' "$discussions_json"

if [ "$mode" = "--comments-only" ]; then
  exit 0
fi

printf '\n## Diff\n'
glab mr diff "$mr"
```

- [ ] **Step 7: Create gitlab-mr-comments reply-to-mr-comment.sh**

Create `core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 1 ]; then
  mr="$(glab mr view -F json | jq -r '.iid')"
  replies_json="$1"
elif [ "$#" -eq 2 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
  mr="$1"
  replies_json="$2"
else
  printf 'Usage: %s [<mr-iid>] <replies-json>\n' "$0" >&2
  exit 2
fi

if ! jq -e 'type == "array" and all(.[]; (.discussion_id | type == "string") and (.body | type == "string"))' \
  >/dev/null <<<"$replies_json"; then
  printf 'Reply JSON must be an array of { "discussion_id": string, "body": string } objects.\n' >&2
  exit 2
fi

count=$(jq length <<<"$replies_json")
printf 'Posting %d replies to MR !%s...\n' "$count" "$mr"

while IFS= read -r reply; do
  discussion_id=$(jq -r '.discussion_id' <<<"$reply")
  body=$(jq -r '.body' <<<"$reply")

  printf '  Replying to discussion %s... ' "$discussion_id"
  glab mr note create "$mr" --reply "$discussion_id" -m "$body"
  printf 'done\n'
done < <(jq -c '.[]' <<<"$replies_json")

printf 'All %d replies posted.\n' "$count"
```

- [ ] **Step 8: Make all scripts executable**

```bash
chmod +x core/forge/gitlab/.agents/skills/gitlab-publish/scripts/*.sh
chmod +x core/forge/gitlab/.agents/skills/gitlab-mr-comments/scripts/*.sh
```

- [ ] **Step 9: Verify**

Run: `shellcheck core/forge/gitlab/.agents/skills/*/scripts/*.sh`
Run: `bash -n core/forge/gitlab/.agents/skills/*/scripts/*.sh`
Run: `codespell core/forge/gitlab/.agents/skills/*/SKILL.md core/forge/gitlab/AGENTS.md`
Expected: no errors

- [ ] **Step 10: Commit**

```bash
git add core/forge/gitlab/
git commit -m "feat: add GitLab forge overlay with gitlab-publish and gitlab-mr-comments skills"
```

---

## Task 11: Create GitLab Forge Config Overlays

**Files:**
- Create: `core/forge/gitlab/opencode.json`
- Create: `core/forge/gitlab/claude/settings.json`
- Create: `core/forge/gitlab/docs/agents/review-plan.md`
- Create: `core/forge/gitlab/docs/agents/review-code.md`
- Create: `core/forge/gitlab/docs/agents/bugfix.md`

- [ ] **Step 1: Create opencode.json overlay**

Create `core/forge/gitlab/opencode.json`:

```json
{
  "agent": {
    "implement": {
      "permission": {
        "bash": {
          "glab mr create *": "allow",
          "glab mr list *": "allow",
          "glab mr view *": "allow",
          "bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": "allow",
          "bash .agents/skills/gitlab-publish/scripts/open-mr.sh*": "ask",
          "gh pr create *": "deny",
          "gh pr list *": "deny",
          "gh pr view *": "deny"
        },
        "skill": {
          "github-publish": "deny",
          "gitlab-publish": "allow"
        }
      }
    },
    "finish": {
      "permission": {
        "bash": {
          "glab mr create *": "allow",
          "glab mr list *": "allow",
          "glab mr view *": "allow",
          "bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": "allow",
          "bash .agents/skills/gitlab-publish/scripts/open-mr.sh*": "ask",
          "gh pr create *": "deny",
          "gh pr list *": "deny",
          "gh pr view *": "deny"
        },
        "skill": {
          "github-publish": "deny",
          "gitlab-publish": "allow"
        }
      }
    },
    "bugfix": {
      "permission": {
        "bash": {
          "glab issue create *": "allow",
          "glab issue view *": "allow",
          "glab issue list *": "allow",
          "glab issue update *": "allow",
          "gh issue create *": "deny",
          "gh issue view *": "deny",
          "gh issue list *": "deny"
        }
      }
    },
    "review-plan": {
      "permission": {
        "bash": {
          "glab mr view *": "allow",
          "glab mr diff *": "allow",
          "bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh*": "allow",
          "bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh*": "ask",
          "gh pr view *": "deny",
          "gh pr diff *": "deny"
        },
        "skill": {
          "github-pr-comments": "deny",
          "gitlab-mr-comments": "allow"
        }
      }
    },
    "review-code": {
      "permission": {
        "bash": {
          "glab mr view *": "allow",
          "glab mr diff *": "allow",
          "bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh*": "allow",
          "bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh*": "ask",
          "gh pr view *": "deny",
          "gh pr diff *": "deny"
        },
        "skill": {
          "github-pr-comments": "deny",
          "gitlab-mr-comments": "allow"
        }
      }
    }
  }
}
```

- [ ] **Step 2: Create claude/settings.json overlay**

Create `core/forge/gitlab/claude/settings.json`:

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(glab mr view:*)",
      "Bash(glab mr diff:*)",
      "Bash(glab mr list:*)",
      "Bash(glab issue view:*)",
      "Bash(glab issue list:*)",
      "Bash(bash .claude/skills/gitlab-publish/scripts/push-branch.sh:*)",
      "Bash(bash .claude/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh:*)"
    ],
    "ask": [
      "Bash(glab mr create:*)",
      "Bash(glab mr note create:*)",
      "Bash(glab issue create:*)",
      "Bash(glab issue update:*)",
      "Bash(bash .claude/skills/gitlab-publish/scripts/open-mr.sh:*)",
      "Bash(bash .claude/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh:*)"
    ],
    "deny": [
      "Bash(gh pr create:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr view:*)",
      "Bash(gh issue create:*)",
      "Bash(gh issue view:*)"
    ]
  }
}
```

- [ ] **Step 3: Create role doc overlays**

Create `core/forge/gitlab/docs/agents/review-plan.md`:

```markdown
## GitLab

- Use `gitlab-mr-comments` skill (not `github-pr-comments`) for MR feedback workflows.
- Fetch MR comments: `bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
```

Create `core/forge/gitlab/docs/agents/review-code.md`:

```markdown
## GitLab

- Use `gitlab-mr-comments` skill (not `github-pr-comments`) for MR feedback workflows.
- Fetch MR comments: `bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
```

Create `core/forge/gitlab/docs/agents/bugfix.md`:

```markdown
## GitLab

- Create issues with `glab issue create` (not `gh issue create`).
- Update issues with `glab issue update`.
```

- [ ] **Step 4: Verify**

Run: `jq . core/forge/gitlab/opencode.json`
Run: `jq . core/forge/gitlab/claude/settings.json`
Run: `codespell core/forge/gitlab/docs/agents/*.md`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add core/forge/gitlab/opencode.json core/forge/gitlab/claude/settings.json core/forge/gitlab/docs/
git commit -m "feat: add GitLab forge config overlays and role doc additions"
```

---

## Task 12: Add Forge Selection to Installer Scripts

**Files:**
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Add forge prompt to init.sh**

In `scripts/init.sh`, add a forge selection prompt after the stack selection. The prompt should offer `github` (default) and `gitlab`.

When `gitlab` is selected:
1. Apply `core/forge/gitlab/opencode.json` overlay (deep-merge, same as stacks)
2. Apply `core/forge/gitlab/claude/settings.json` overlay (permission union, same as stacks)
3. Apply `core/forge/gitlab/AGENTS.md` addition (concatenate, same as stacks)
4. Copy `core/forge/gitlab/.agents/skills/` into the target `.agents/skills/`
5. Create symlinks for `gitlab-publish` and `gitlab-mr-comments` into `.claude/skills/`
6. Do NOT copy `core/agents/skills/github-publish/` or `core/agents/skills/github-pr-comments/`
7. Concatenate `core/forge/gitlab/docs/agents/*.md` additions to the matching role docs

When `github` is selected:
1. Copy `core/agents/skills/github-publish/` as normal
2. Copy `core/agents/skills/github-pr-comments/` as normal
3. No forge overlay applied

- [ ] **Step 2: Add forge prompt to copy.sh**

Same logic in `scripts/copy.sh`. The forge prompt appears alongside the stack prompt.

- [ ] **Step 3: Verify**

Run: `shellcheck scripts/init.sh scripts/copy.sh`
Run: `bash -n scripts/init.sh scripts/copy.sh`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add scripts/init.sh scripts/copy.sh
git commit -m "feat: add forge selection (github/gitlab) to installer scripts"
```

---

## Task 13: Update Top-Level README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Installed Assets section**

In `README.md`:

Add `implement` to the Claude Workflow Entry Skills list:
```
`brainstorm`, `bugfix`, `implement`, `finish`, `planner`, `review-code`, `review-plan`
```

Add `github-publish` to the Authored Reusable Skills list:
```
`grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `github-publish`, `github-pr-comments`
```

- [ ] **Step 2: Update Claude Symlink Model section**

Add `github-publish` to the symlink table:

```markdown
| `github-publish` | `../../.agents/skills/github-publish` |
```

Remove the note about `workflow-implementation` being reserved for OpenCode — with the dual-harness design, Claude now also has `/implement`.

- [ ] **Step 3: Add Forge dimension documentation**

After the "Initial Stacks" section, add:

```markdown
## Forge Dimension

The toolkit supports two forge platforms, orthogonal to the stack choice:

| Forge | Publish Skill | PR/MR Comments Skill | CLI |
|---|---|---|---|
| **github** (default) | `github-publish` | `github-pr-comments` | `gh` |
| **gitlab** | `gitlab-publish` | `gitlab-mr-comments` | `glab` |

During `init.sh` or `copy.sh`, you choose a forge alongside the stack. The GitLab forge overlay replaces GitHub skills with GitLab equivalents and swaps `gh` permissions for `glab` permissions in both OpenCode and Claude configs.
```

- [ ] **Step 4: Update the Extension Guide**

In the Extension Guide section, add a note about forge overlays:

```markdown
## Adding Future Forges

To add a new forge (e.g. Bitbucket, Gitea):

1. Create `core/forge/<name>/` with:
   - `AGENTS.md` (forge-specific conventions)
   - `.agents/skills/<forge>-publish/` (publish skill with scripts)
   - `.agents/skills/<forge>-pr-comments/` or `<forge>-mr-comments/` (review feedback skill)
   - `opencode.json` (forge-specific permission overlays)
   - `claude/settings.json` (forge-specific permission overlays)
   - `docs/agents/<role>.md` additions for review/bugfix roles

2. The forge assets are merged identically to stacks: config deep-merged, permissions unioned, role docs concatenated, skills copied and symlinked.
```

- [ ] **Step 5: Update the workflow table**

In the Implementation Cycle table, update step 7:
From: `OpenCode '@implement' (controller) which spawns '@implement-task' workers.`
To: `Claude '/implement' or OpenCode '@implement' (controller) which spawns implement-task workers. Pick one harness per branch.`

- [ ] **Step 6: Verify**

Run: `codespell README.md`
Expected: no errors

- [ ] **Step 7: Commit**

```bash
git add README.md
git commit -m "docs: update README for dual-harness /implement, github-publish skill, and forge dimension"
```

---

## Task 14: Consistency Verification

- [ ] **Step 1: Verify all symlinks are accounted for**

Check that the symlink table in both `core/claude/README.md` and `README.md` lists exactly these skills:
- `grill-with-docs`
- `workflow-bug-analysis`
- `workflow-brainstorming`
- `workflow-planning`
- `workflow-verification`
- `feature-documentation`
- `github-publish`
- `github-pr-comments`

(8 total for GitHub forge; GitLab forge replaces `github-publish` and `github-pr-comments` with `gitlab-publish` and `gitlab-mr-comments`)

- [ ] **Step 2: Verify no stale `gh` references remain in core**

Run: `grep -r "gh pr\|gh issue" core/ --include="*.md" --include="*.json" --include="*.sh" | grep -v "github-" | grep -v "forge/gitlab"`
Expected: no matches (all `gh` references should be inside `github-*` skills or denied in the GitLab overlay)

- [ ] **Step 3: Verify no stale `git push origin $(git rev-parse"` references remain**

Run: `grep -r 'git push origin' core/ --include="*.md" | grep -v "github-publish" | grep -v "gitlab-publish"`
Expected: no matches (all push instructions should reference the publish skills)

- [ ] **Step 4: Verify all agent files reference the correct skills**

Check that:
- `core/opencode/agents/implement.md` references `github-publish` skill (not raw push)
- `core/opencode/agents/finish.md` references `github-publish` skill (not raw push)
- `core/claude/skills/implement/SKILL.md` references `github-publish` skill
- `core/claude/skills/finish/SKILL.md` references `github-publish` skill
- `core/claude/skills/brainstorm/SKILL.md` references `github-publish` skill

- [ ] **Step 5: Verify lockfiles**

No changes to `skills-lock.json` or `core/skills-lock.json` — no new remote skills are being installed.

- [ ] **Step 6: Final codespell pass**

Run: `codespell core/ AGENTS.md README.md`
Expected: no errors (or only known false positives)

- [ ] **Step 7: Commit (if any fixes needed)**

```bash
git add -A
git commit -m "chore: consistency fixes from verification pass"
```

---

## Docs Used

- `AGENTS.md` (repo-root conventions) — dot-mapping, sync invariants, skill lockfile scopes
- `core/claude/README.md` — current Claude skill inventory and symlink model
- `core/AGENTS.md` (template) — dual pipeline description, permissions
- `README.md` — installed assets, workflow table, extension guide
- `scripts/init.sh` — current installer flow
- `scripts/copy.sh` — current copy flow
- All `core/opencode/agents/*.md` — current agent definitions and permissions
- All `core/claude/skills/*/SKILL.md` — current Claude skill definitions
- `core/claude/settings.json` — current Claude permissions
- `core/agents/skills/github-pr-comments/` — pattern reference for forge skills
- `scripts/publish-branch.sh` — current publishing script (to be replaced)
