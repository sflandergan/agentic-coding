# Dual-Harness Implementer & GitLab Platform Skills

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close two structural gaps identified by inspecting an adapted downstream project: (1) Claude Code has no `/implement` controller — implementation is OpenCode-only, and (2) publishing/review-comment skills are GitHub-only — no `glab` equivalents exist for GitLab-hosted projects.

**Configuration shape:** The Claude implementer adds two files to the core template layer and updates existing skills, agents, docs, and settings for cross-references. GitLab skills (`gitlab-publish`, `gitlab-mr-comments`) are added alongside the existing GitHub skills in `core/agents/skills/`. Both sets are always installed; the agents detect which platform the project uses from CLI availability and tool output. Permissions for `glab` are added to `opencode.json` and `claude/settings.json` alongside the existing `gh` permissions. The root `scripts/publish-branch.sh` is preserved as a compatibility wrapper that delegates to the new `github-publish` skill.

**Configuration surface:**
- New: `core/claude/skills/implement/SKILL.md`, `core/claude/agents/implement-task.md`
- New: `core/agents/skills/github-publish/` (publish skill wrapping the existing `scripts/publish-branch.sh` logic)
- New: `core/agents/skills/gitlab-publish/` (publish skill using `glab`)
- New: `core/agents/skills/gitlab-mr-comments/` (MR comment skill using `glab`)
- Modified: `core/claude/README.md`, `core/claude/skills/planner/SKILL.md`, `core/claude/skills/review-code/SKILL.md`, `core/claude/skills/review-plan/SKILL.md`, `core/claude/skills/brainstorm/SKILL.md`, `core/claude/skills/finish/SKILL.md`, `core/claude/settings.json`, `core/opencode/agents/implement.md`, `core/opencode/agents/finish.md`, `core/opencode/agents/review-code.md`, `core/opencode/agents/review-plan.md`, `core/opencode/agents/brainstorm.md`, `core/opencode/agents/planner.md`, `core/agents/skills/workflow-implementation/SKILL.md`, `core/opencode.json`, `README.md`, `scripts/init.sh`, `scripts/copy.sh`, `scripts/publish-branch.sh`

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
- Never work on or push to `main`. Publish through the appropriate publish skill — do not hand-roll `git push`.

## Finishing

After final verification, commit all changes and push the branch using the publish skill:
- GitHub: `bash .claude/skills/github-publish/scripts/push-branch.sh` then `bash .claude/skills/github-publish/scripts/open-pr.sh`
- GitLab: `bash .claude/skills/gitlab-publish/scripts/push-branch.sh` then `bash .claude/skills/gitlab-publish/scripts/open-mr.sh`

The publish scripts refuse `main`/`master` and skip creation when a PR/MR already exists for the branch.
```

- [ ] **Step 2: Verify**

Run: `codespell core/claude/skills/implement/SKILL.md`
Expected: no errors

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

Safe publishing for GitHub-hosted repositories. Pushing and opening pull requests go through bundled scripts that **refuse to act on `main`** and refuse force-pushes.

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

## Task 4: Create `gitlab-publish` Authored Skill

**Files:**
- Create: `core/agents/skills/gitlab-publish/SKILL.md`
- Create: `core/agents/skills/gitlab-publish/scripts/push-branch.sh`
- Create: `core/agents/skills/gitlab-publish/scripts/open-mr.sh`

- [ ] **Step 1: Write the SKILL.md**

Create `core/agents/skills/gitlab-publish/SKILL.md`:

```markdown
---
name: gitlab-publish
description: Use when pushing a branch or opening a merge request on a GitLab-hosted repository — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# GitLab Publish

Safe publishing for GitLab-hosted repositories. Pushing and opening merge requests go through bundled scripts that **refuse to act on `main`/`master`** and refuse force-pushes.

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

- [ ] **Step 2: Write push-branch.sh**

Create `core/agents/skills/gitlab-publish/scripts/push-branch.sh`:

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

- [ ] **Step 3: Write open-mr.sh**

Create `core/agents/skills/gitlab-publish/scripts/open-mr.sh`:

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

- [ ] **Step 4: Make scripts executable**

```bash
chmod +x core/agents/skills/gitlab-publish/scripts/push-branch.sh
chmod +x core/agents/skills/gitlab-publish/scripts/open-mr.sh
```

- [ ] **Step 5: Verify**

Run: `shellcheck core/agents/skills/gitlab-publish/scripts/*.sh`
Run: `bash -n core/agents/skills/gitlab-publish/scripts/*.sh`
Run: `codespell core/agents/skills/gitlab-publish/SKILL.md`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/gitlab-publish/
git commit -m "feat: add gitlab-publish authored skill with push guard and MR opener"
```

---

## Task 5: Create `gitlab-mr-comments` Authored Skill

**Files:**
- Create: `core/agents/skills/gitlab-mr-comments/SKILL.md`
- Create: `core/agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
- Create: `core/agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`

- [ ] **Step 1: Write the SKILL.md**

Create `core/agents/skills/gitlab-mr-comments/SKILL.md`:

```markdown
---
name: gitlab-mr-comments
description: Use when GitLab merge request feedback lives in plain notes, inline diff discussions, or discussion threads
user-invocable: false
---

# GitLab MR Comments

Use this for team merge request review workflows where feedback is stored as GitLab notes and discussions. This is the GitLab equivalent of `github-pr-comments`.

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

- [ ] **Step 2: Write fetch-mr-comments.sh**

Create `core/agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`:

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

- [ ] **Step 3: Write reply-to-mr-comment.sh**

Create `core/agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`:

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

- [ ] **Step 4: Make scripts executable**

```bash
chmod +x core/agents/skills/gitlab-mr-comments/scripts/*.sh
```

- [ ] **Step 5: Verify**

Run: `shellcheck core/agents/skills/gitlab-mr-comments/scripts/*.sh`
Run: `bash -n core/agents/skills/gitlab-mr-comments/scripts/*.sh`
Run: `codespell core/agents/skills/gitlab-mr-comments/SKILL.md`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/gitlab-mr-comments/
git commit -m "feat: add gitlab-mr-comments authored skill with MR discussion fetch and reply"
```

---

## Task 6: Wire `github-publish` into OpenCode Agents

**Files:**
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/finish.md`

- [ ] **Step 1: Update implement.md**

In `core/opencode/agents/implement.md`:

Replace the raw push/PR instructions with `github-publish` skill references:

- Replace line 100 (`Always use 'git push origin $(git rev-parse --abbrev-ref HEAD)'...`) with:
  `Publish through the 'github-publish' skill — 'bash .agents/skills/github-publish/scripts/push-branch.sh' to push, which refuses 'main'. Never hand-roll 'git push': 'git push origin $(...)' silently pushes 'main' when the current branch is 'main'.`

- Replace line 101 (the `gh pr list --head` check) with:
  `Open a pull request with 'bash .agents/skills/github-publish/scripts/open-pr.sh' — it skips creation when a PR already exists for the current branch.`

- Replace line 113 (the final push+PR block) with:
  `After final verification, commit all changes, push the branch with 'bash .agents/skills/github-publish/scripts/push-branch.sh', and open a GitHub pull request with 'bash .agents/skills/github-publish/scripts/open-pr.sh' (it no-ops when a PR already exists). The push script refuses 'main'.`

- Add `github-publish` to the skill permission allowlist after `"workflow-verification": allow`.

- Add the publish script bash permissions:
  ```
  "bash .agents/skills/github-publish/scripts/push-branch.sh*": allow
  "bash .agents/skills/github-publish/scripts/open-pr.sh*": ask
  ```

- Remove the `"git push origin $(git rev-parse --abbrev-ref HEAD)": allow` line.

- [ ] **Step 2: Update finish.md**

Same pattern in `core/opencode/agents/finish.md` — replace raw push instructions with `github-publish` skill references, add the skill to the allowlist, add script bash permissions.

- [ ] **Step 3: Verify**

Run: `codespell core/opencode/agents/implement.md core/opencode/agents/finish.md`
Expected: no errors

- [ ] **Step 4: Commit**

```bash
git add core/opencode/agents/implement.md core/opencode/agents/finish.md
git commit -m "refactor: wire github-publish skill into OpenCode implement and finish agents"
```

---

## Task 7: Wire `gitlab-publish` into OpenCode Agents

**Files:**
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/finish.md`
- Modify: `core/opencode.json`

- [ ] **Step 1: Add gitlab-publish permissions to implement.md**

In `core/opencode/agents/implement.md`, add alongside the `github-publish` permissions:

```yaml
    "bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": allow
    "bash .agents/skills/gitlab-publish/scripts/open-mr.sh*": ask
```

And add to the skill allowlist:
```yaml
    "gitlab-publish": allow
```

- [ ] **Step 2: Add gitlab-publish permissions to finish.md**

Same pattern in `core/opencode/agents/finish.md`.

- [ ] **Step 3: Add glab permissions to opencode.json**

In `core/opencode.json`, add to the global permission bash section:

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

- [ ] **Step 4: Verify**

Run: `jq . core/opencode.json`
Expected: valid JSON

- [ ] **Step 5: Commit**

```bash
git add core/opencode/agents/implement.md core/opencode/agents/finish.md core/opencode.json
git commit -m "feat: add gitlab-publish permissions and glab CLI access to OpenCode agents"
```

---

## Task 8: Wire Skills into Claude Settings

**Files:**
- Modify: `core/claude/settings.json`
- Modify: `core/claude/skills/finish/SKILL.md`
- Modify: `core/claude/skills/brainstorm/SKILL.md`

- [ ] **Step 1: Update settings.json**

In `core/claude/settings.json`, add to the `allow` array:
```
"Bash(bash .claude/skills/github-publish/scripts/push-branch.sh:*)",
"Bash(bash .claude/skills/gitlab-publish/scripts/push-branch.sh:*)",
"Bash(bash .claude/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh:*)",
"Bash(glab mr view:*)",
"Bash(glab mr diff:*)",
"Bash(glab mr list:*)",
"Bash(glab issue view:*)",
"Bash(glab issue list:*)"
```

Add to the `ask` array:
```
"Bash(bash .claude/skills/github-publish/scripts/open-pr.sh:*)",
"Bash(bash .claude/skills/gitlab-publish/scripts/open-mr.sh:*)",
"Bash(bash .claude/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh:*)",
"Bash(glab mr create:*)",
"Bash(glab mr note create:*)",
"Bash(glab issue create:*)",
"Bash(glab issue update:*)"
```

- [ ] **Step 2: Update finish/SKILL.md**

Replace the push instructions (step 5 and the "Push boundaries" section) to reference both publish skills:

```markdown
5. **Commit and push.** Commit the feature doc and cleanup when the user requests it,
   then push using the appropriate publish skill:
   - GitHub: `bash .claude/skills/github-publish/scripts/push-branch.sh`
   - GitLab: `bash .claude/skills/gitlab-publish/scripts/push-branch.sh`

## Push boundaries

Push only with the publish skill scripts. Never use bare `git push`, push to `main`,
force-push, delete remote refs, push tags, or push arbitrary refspecs without explicit
approval. Do not create PRs, amend commits, delete branches, close comments, or remove
worktrees.
```

- [ ] **Step 3: Update brainstorm/SKILL.md**

Replace the shell guidance (lines 34-35):

```markdown
- Publish through the appropriate publish skill — `bash .claude/skills/github-publish/scripts/push-branch.sh` (GitHub) or `bash .claude/skills/gitlab-publish/scripts/push-branch.sh` (GitLab). Never hand-roll `git push`.
```

- [ ] **Step 4: Verify**

Run: `codespell core/claude/skills/finish/SKILL.md core/claude/skills/brainstorm/SKILL.md`
Run: `jq . core/claude/settings.json`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add core/claude/settings.json core/claude/skills/finish/SKILL.md core/claude/skills/brainstorm/SKILL.md
git commit -m "feat: wire publish and gitlab skills into Claude settings, finish, and brainstorm"
```

---

## Task 9: Wire `gitlab-mr-comments` into Review Agents

**Files:**
- Modify: `core/opencode/agents/review-code.md` (verify — may not exist as a separate file)
- Modify: `core/opencode/agents/review-plan.md` (verify)
- Modify: `core/claude/skills/review-code/SKILL.md`
- Modify: `core/claude/skills/review-plan/SKILL.md`
- Modify: `core/docs/agents/review-code.md`
- Modify: `core/docs/agents/review-plan.md`

- [ ] **Step 1: Update role docs to mention both comment skills**

In `core/docs/agents/review-code.md`, add to the Load section:
```markdown
- `github-pr-comments` or `gitlab-mr-comments` skill for PR/MR feedback (detect which CLI is available)
```

In `core/docs/agents/review-plan.md`, add the same.

- [ ] **Step 2: Update Claude review-code/SKILL.md**

In `core/claude/skills/review-code/SKILL.md`, update the references to `github-pr-comments`:

Replace: `Use the 'github-pr-comments' skill for reading and drafting replies to PR comments.`
With: `Use the 'github-pr-comments' skill for GitHub PRs or 'gitlab-mr-comments' skill for GitLab MRs. Detect which CLI is available ('gh' or 'glab') or which the user specifies.`

Update step 1 similarly:
Replace: `Read open PR comments first by using the 'github-pr-comments' skill.`
With: `Read open PR/MR comments first using the appropriate skill: 'github-pr-comments' for GitHub or 'gitlab-mr-comments' for GitLab.`

- [ ] **Step 3: Update Claude review-plan/SKILL.md**

Same pattern — update references to mention both skills with detection.

- [ ] **Step 4: Add glab permissions to OpenCode review agents**

In `core/opencode/agents/review-plan.md` and `core/opencode/agents/review-code.md`, add bash permissions for the gitlab-mr-comments scripts:

```yaml
    "bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh*": allow
    "bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh*": ask
    "glab mr view *": allow
    "glab mr diff *": allow
```

And add `gitlab-mr-comments` to the skill allowlist.

- [ ] **Step 5: Verify**

Run: `codespell core/claude/skills/review-code/SKILL.md core/claude/skills/review-plan/SKILL.md core/docs/agents/review-code.md core/docs/agents/review-plan.md`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add core/claude/skills/review-code/SKILL.md core/claude/skills/review-plan/SKILL.md core/docs/agents/review-code.md core/docs/agents/review-plan.md core/opencode/agents/review-code.md core/opencode/agents/review-plan.md
git commit -m "feat: wire gitlab-mr-comments into review agents alongside github-pr-comments"
```

---

## Task 10: Update Claude README for Dual Harness

**Files:**
- Modify: `core/claude/README.md`

- [ ] **Step 1: Update the skill table**

Add `/implement` to the skill table:

```markdown
| Skill (`/name`) | OpenCode counterpart | Role |
| --- | --- | --- |
| `/brainstorm`  | `@brainstorm`  | Idea → approved `spec.md` (interactive; offers domain grilling) |
| `/bugfix`      | `@bugfix`      | Investigate bug → structured issue; does not fix |
| `/planner`     | `@planner`     | Spec → task-by-task `plan.md` (offers grilling only when new domain language or non-trivial decisions appear) |
| `/implement`   | `@implement`   | Execute plan task-by-task via `implement-task` workers, verify, commit |
| `/review-plan` | `@review-plan` | Review + finalize the hand-off plan |
| `/review-code` | `@review-code` | Review a diff/PR/MR → fix-plan hand-off doc |
| `/finish`      | `@finish`      | Durable feature doc, light glossary/ADR reconciliation, cleanup |
```

- [ ] **Step 2: Update the design principle section**

Replace the opening paragraph:
From: `Claude Code runs the **conversational** half of the agent pipeline. The **implementation** half stays in OpenCode.`
To: `Claude Code runs both the **conversational** and **implementation** halves of the agent pipeline. OpenCode provides the same pipeline; pick one harness per branch.`

- [ ] **Step 3: Update the shared authored skills list**

Add to the shared authored skills list:
```
- `github-publish` — used by `/implement`, `/finish` (+ OpenCode)
- `gitlab-publish` — used by `/implement`, `/finish` (+ OpenCode; GitLab equivalent)
- `gitlab-mr-comments` — used by `/review-plan`, `/review-code` (+ OpenCode; GitLab equivalent of `github-pr-comments`)
```

- [ ] **Step 4: Update the "Usage" section**

Update the usage line to include `/implement`:
`Type '/brainstorm', '/bugfix', '/implement', '/planner', '/review-plan', '/review-code', or '/finish'`

- [ ] **Step 5: Update the permissions section**

Mention that permissions include both `gh` and `glab` CLI access, and both GitHub and GitLab publish/comment skill scripts.

- [ ] **Step 6: Update the symlink inventory**

The symlink table should now include:
```
| `github-publish` | `../../.agents/skills/github-publish` |
| `gitlab-publish` | `../../.agents/skills/gitlab-publish` |
| `gitlab-mr-comments` | `../../.agents/skills/gitlab-mr-comments` |
```

Remove the note about `workflow-implementation` being reserved for OpenCode.

- [ ] **Step 7: Verify**

Run: `codespell core/claude/README.md`
Expected: no errors

- [ ] **Step 8: Commit**

```bash
git add core/claude/README.md
git commit -m "docs: update Claude README for /implement controller and GitLab skills"
```

---

## Task 11: Update Existing Claude Skills for `/implement` Cross-References

**Files:**
- Modify: `core/claude/skills/planner/SKILL.md`
- Modify: `core/claude/skills/review-code/SKILL.md` (if not already updated in Task 9)
- Modify: `core/claude/skills/review-plan/SKILL.md` (if not already updated in Task 9)

- [ ] **Step 1: Update planner/SKILL.md stop conditions**

Replace the stop conditions (lines 74-77):

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

- [ ] **Step 2: Verify**

Run: `codespell core/claude/skills/planner/SKILL.md`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add core/claude/skills/planner/SKILL.md
git commit -m "refactor: update Claude planner for dual-harness /implement handoff"
```

---

## Task 12: Convert `scripts/publish-branch.sh` to Compatibility Wrapper and Update Installers

**Files:**
- Modify: `scripts/publish-branch.sh`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Convert publish-branch.sh into a wrapper around the github-publish skill**

The repo's self-maintenance agents (`@implement`, `@planning`, `@review`) and `AGENTS.md` still reference `scripts/publish-branch.sh`. Keep that path working by replacing its contents with a wrapper that delegates to the new `github-publish` skill scripts.

Write `scripts/publish-branch.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Compatibility wrapper: this repo's self-maintenance agents still invoke
# scripts/publish-branch.sh. It delegates to the github-publish authored skill.
bash core/agents/skills/github-publish/scripts/push-branch.sh --set-upstream
bash core/agents/skills/github-publish/scripts/open-pr.sh --fill
```

Make it executable:

```bash
chmod +x scripts/publish-branch.sh
```

- [ ] **Step 2: Add new skills to init.sh symlink list**

In `scripts/init.sh`, find the section that creates Claude symlinks (the loop that symlinks authored skills from `.agents/skills/` into `.claude/skills/`). Add `github-publish`, `gitlab-publish`, and `gitlab-mr-comments` to the list.

Also ensure `gitlab-publish` and `gitlab-mr-comments` are copied into `.agents/skills/` alongside the existing skills.

- [ ] **Step 3: Add new skills to copy.sh symlink list**

Same changes in `scripts/copy.sh`.

- [ ] **Step 4: Add `.claude/agents/` handling to the installers**

The new Claude `implement-task` subagent lives in `core/claude/agents/implement-task.md`. Add copy logic to both `scripts/init.sh` and `scripts/copy.sh` so `.claude/agents/*.md` is installed into target projects, analogous to how `.opencode/agents/*.md` is handled.

- [ ] **Step 5: Verify**

Run: `shellcheck scripts/init.sh scripts/copy.sh scripts/publish-branch.sh`
Run: `bash -n scripts/init.sh scripts/copy.sh scripts/publish-branch.sh`
Run: `codespell scripts/publish-branch.sh`
Expected: no errors

- [ ] **Step 6: Smoke-run the installers**

Run a smoke test against `.temp/`:

```bash
rm -rf .temp/smoke-init
./scripts/init.sh
# When prompted, choose a test target under .temp/smoke-init and any stack.
# After the run, verify that .temp/smoke-init/.claude/agents/implement-task.md exists
# and that .temp/smoke-init/.claude/skills/github-publish is a symlink resolving
# to ../../.agents/skills/github-publish.

rm -rf .temp/smoke-copy
mkdir -p .temp/smoke-copy && cd .temp/smoke-copy && git init && git commit --allow-empty -m "init" && cd ../..
./scripts/copy.sh .temp/smoke-copy
# Verify the same .claude/agents and .claude/skills symlink outcomes.
```

Clean up `.temp/smoke-init` and `.temp/smoke-copy` after verification.

- [ ] **Step 7: Commit**

```bash
git add scripts/publish-branch.sh scripts/init.sh scripts/copy.sh
git commit -m "feat: add gitlab skills and claude agents to installers, wrap publish-branch.sh"
```

---

## Task 13: Replace Remaining Raw Push References

**Files:**
- Modify: `core/agents/skills/workflow-implementation/SKILL.md`
- Modify: `core/claude/skills/planner/SKILL.md`
- Modify: `core/claude/skills/review-plan/SKILL.md`
- Modify: `core/opencode/agents/brainstorm.md`
- Modify: `core/opencode/agents/planner.md`
- Modify: `core/opencode/agents/review-plan.md`

- [ ] **Step 1: Update shared implementation skill**

In `core/agents/skills/workflow-implementation/SKILL.md`, replace the raw push/PR instruction at line 100 with:

`After final verification, the controller commits all changes, pushes the branch with 'bash .agents/skills/github-publish/scripts/push-branch.sh', and opens a GitHub pull request with 'bash .agents/skills/github-publish/scripts/open-pr.sh' if one does not already exist. Never push to 'main'.`

- [ ] **Step 2: Update Claude planner and review-plan skills**

In `core/claude/skills/planner/SKILL.md` line 69 and `core/claude/skills/review-plan/SKILL.md` line 81, replace the raw `git push origin $(git rev-parse --abbrev-ref HEAD)` instruction with:

`- Publish through the appropriate publish skill — 'bash .claude/skills/github-publish/scripts/push-branch.sh' (GitHub) or 'bash .claude/skills/gitlab-publish/scripts/push-branch.sh' (GitLab). Never hand-roll 'git push'.`

- [ ] **Step 3: Update OpenCode brainstorm, planner, and review-plan agents**

In `core/opencode/agents/brainstorm.md` line 97, `core/opencode/agents/planner.md` line 91, and `core/opencode/agents/review-plan.md` line 73, replace the raw push instruction with publish-skill references and add the publish script bash permissions:

```yaml
"bash .agents/skills/github-publish/scripts/push-branch.sh*": allow
"bash .agents/skills/gitlab-publish/scripts/push-branch.sh*": allow
```

Remove the `"git push origin $(git rev-parse --abbrev-ref HEAD)": allow` permission from each of these agents (where present).

- [ ] **Step 4: Verify**

Run: `codespell core/agents/skills/workflow-implementation/SKILL.md core/claude/skills/planner/SKILL.md core/claude/skills/review-plan/SKILL.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/opencode/agents/review-plan.md`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills/workflow-implementation/SKILL.md core/claude/skills/planner/SKILL.md core/claude/skills/review-plan/SKILL.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/opencode/agents/review-plan.md
git commit -m "refactor: replace remaining raw push references with publish skills"
```

---

## Task 14: Update Top-Level README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update Installed Assets section**

Add `implement` to the Claude Workflow Entry Skills:
```
`brainstorm`, `bugfix`, `implement`, `finish`, `planner`, `review-code`, `review-plan`
```

Add GitLab skills to the Authored Reusable Skills:
```
`grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-implementation`, `workflow-verification`, `feature-documentation`, `github-publish`, `github-pr-comments`, `gitlab-publish`, `gitlab-mr-comments`
```

- [ ] **Step 2: Update Claude Symlink Model section**

Add to the symlink table:
```markdown
| `github-publish` | `../../.agents/skills/github-publish` |
| `gitlab-publish` | `../../.agents/skills/gitlab-publish` |
| `gitlab-mr-comments` | `../../.agents/skills/gitlab-mr-comments` |
```

Remove the note about `workflow-implementation` being reserved for OpenCode.

- [ ] **Step 3: Update workflow table**

In the Implementation Cycle table, update step 7:
From: `OpenCode '@implement' (controller) which spawns '@implement-task' workers.`
To: `Claude '/implement' or OpenCode '@implement' (controller) which spawns implement-task workers. Pick one harness per branch.`

- [ ] **Step 4: Verify**

Run: `codespell README.md`
Expected: no errors

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: update README for dual-harness /implement and GitLab skills"
```

---

## Task 15: Consistency Verification

- [ ] **Step 1: Verify symlink table completeness**

The Claude symlink table should list exactly these skills:
- `grill-with-docs`, `workflow-bug-analysis`, `workflow-brainstorming`, `workflow-planning`, `workflow-verification`, `feature-documentation`
- `github-publish`, `github-pr-comments`
- `gitlab-publish`, `gitlab-mr-comments`

(10 total)

- [ ] **Step 2: Verify no stale raw push references**

Run: `grep -R 'git push origin \$(git rev-parse' core/ --include="*.md"`
Expected: no matches

- [ ] **Step 3: Verify all skills exist on disk**

Run: `ls core/agents/skills/github-publish/SKILL.md core/agents/skills/gitlab-publish/SKILL.md core/agents/skills/gitlab-mr-comments/SKILL.md`
Expected: all three files exist

- [ ] **Step 4: Verify lockfiles**

No changes to `skills-lock.json` or `core/skills-lock.json` — no new remote skills are being installed. All new skills are authored.

- [ ] **Step 5: Final codespell pass**

Run: `codespell core/ README.md scripts/`
Expected: no errors

---

## Docs Used

- `AGENTS.md` (repo-root conventions) — dot-mapping, sync invariants, skill lockfile scopes
- `core/claude/README.md` — current Claude skill inventory and symlink model
- `core/AGENTS.md` (template) — dual pipeline description, permissions
- `README.md` — installed assets, workflow table, extension guide
- `scripts/init.sh` — current installer flow and symlink creation
- `scripts/copy.sh` — current copy flow and symlink creation
- All `core/opencode/agents/*.md` — current agent definitions and permissions
- All `core/claude/skills/*/SKILL.md` — current Claude skill definitions
- `core/claude/settings.json` — current Claude permissions
- `core/agents/skills/github-pr-comments/` — pattern reference for platform skills
- `scripts/publish-branch.sh` — current publishing script (to be converted to a github-publish compatibility wrapper)
