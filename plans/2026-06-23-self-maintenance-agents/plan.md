# Self-Maintenance Agents & Skills — Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a self-maintenance agent + skill surface to this toolkit repo so it can maintain its own markdown templates and bash scripts.

**Configuration shape:** Four thin agents (`planning`, `implement`, `implement-task`, `review`) delegate to `agent-*` prefixed skills. Shared repo conventions live in a root `AGENTS.md` (ambient, not a skill). Skills are symlinked from `.claude/skills/` to `.agents/skills/` for Claude Code compatibility. A `writing-skills` remote skill from `obra/superpowers` replaces the old `mattpocock/skills` entry.

**Configuration surface:** OpenCode agent/config markdown, Claude Code skill compatibility symlinks, bash helper scripts, shellcheck, `npx skills`.

**Target Branch:** `chore/self-maintenance-agents`

**Prerequisites:** `jq`, `shellcheck`, `npx`/Node.js, `gh` CLI (for PR creation).

---

## Task 1: Scaffold repository branch and `.gitignore`

**Files:**
- Create: `.gitignore`

**Context:** The repo currently has no `.gitignore`. Smoke runs and scratch work will go under `.temp/`, which must never be committed.

- [ ] **Step 1: Create branch**

```bash
git checkout -b chore/self-maintenance-agents
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
# Scratch directory for smoke runs and throwaway work
.temp/

# Keep Claude Code local settings private
.claude/settings.local.json
```

- [ ] **Step 3: Verify file content**

```bash
cat .gitignore
```

Expected output contains `.temp/` and `.claude/settings.local.json`.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore for .temp/ and local Claude settings"
```

---

## Task 2: Create root `AGENTS.md` with shared conventions

**Files:**
- Create: `AGENTS.md`

**Context:** This replaces the former `toolkit-conventions` skill. It carries the repo knowledge every agent needs. It is loaded ambiently by OpenCode and inherited by Claude Code via `CLAUDE.md`.

- [ ] **Step 1: Write `AGENTS.md`**

```markdown
# AGENTS.md

Shared conventions for AI agents maintaining this toolkit repo. This file is loaded every session.

## What This Repo Is

A reusable agentic coding toolkit. The `core/` and `stacks/` trees are **templates** installed into other repos by `scripts/init.sh` and `scripts/copy.sh`. There is no application code, no DDD contexts, and no test suite — only markdown templates and bash scripts.

## Maintenance Surface

The files this repo's agents operate on:

- Markdown templates under `core/` and `stacks/`
- `README.md`
- `skills-lock.json` for this repo's self-maintenance skills
- `core/skills-lock.json` for the toolkit installed into target repos
- `scripts/init.sh` (~325 lines), `scripts/copy.sh` (~618 lines)

## Dot-Mapping (Source → Target)

The scripts copy these source directories to target dot-directories:

| Source in repo | Target dot-directory |
|---|---|
| `core/opencode/` | `.opencode/` |
| `core/claude/` | `.claude/` |
| `core/agents/` | `.agents/` |
| `core/docs/` | `docs/` |

## Core + Stacks Dual-Maintenance

When modifying a file under `core/`, check whether `stacks/pnpm/` or `stacks/maven/` has an overlay for the same file. Update stack overlays when the change affects stack-specific installed output, especially when adding a new template or changing behavior that an overlay intentionally customizes.

## Sync Invariants

These must stay consistent with the actual files:

- `README.md` agent/skill lists
- The dot-mapping table above
- Agent file names in `.opencode/agents/` vs what `opencode.json` references

## Skill Lockfile Scopes

The two lockfiles have different scopes and are not expected to match.

- `skills-lock.json` tracks remote skills installed in this repo for self-maintenance. Compare it against remote-sourced skill directories under `.agents/skills/`.
- `core/skills-lock.json` tracks remote skills installed into target repos by `scripts/init.sh` and `scripts/copy.sh`. Compare it against the skills the toolkit templates install for downstream projects.

When updating skills, edit only the lockfile for the scope you changed.

## SKILL.md Frontmatter Conventions

```yaml
---
name: skill-name          # lowercase, hyphen-separated, matches folder
description: Use when...  # required, third-person, front-load trigger keywords
user-invocable: false     # for skills only loaded by agents, not users
---
```

## Symlink Model

OpenCode is configured to read skills from `.agents/skills/<name>/SKILL.md`. Each skill is symlinked into `.claude/skills/<name>` (`ln -s ../../.agents/skills/<name>`) so Claude Code also sees it. This matches the model `copy.sh` uses for authored skills.

## .temp/ Scratch Rule

All smoke runs and throwaway work goes in `.temp/`, never `/tmp`. Clean up after use. `.temp/` is gitignored.

## Git Conventions

- Work on a scoped branch, never directly on `main`.
- Branches use `feature/`, `fix/`, or `chore/` prefixes with short kebab-case descriptions.
- Commits are concise, imperative, and focused on why.
- Prefer `git mv` for moves/renames of tracked paths. Use `git rm` for removals of tracked paths.
- Use `scripts/publish-branch.sh` for branch publishing and PR creation so branch-safety checks are centralized.
- Keep branch deletion, worktree removal, and force-push operations under explicit human control.
- Write commits without `Co-Authored-By` trailers.

## Verification Baseline

For changes in this repo:

- Markdown-only changes require format-specific validation: agent frontmatter, skill frontmatter, README inventory sync, and link/symlink spot checks as applicable.
- Bash script changes require `shellcheck` and `bash -n`.
- Script changes also require a smoke run against `.temp/`.
- Agent/skill/config changes require consistency checks: README lists, lockfiles, dot-mapping, and symlink integrity.
```

- [ ] **Step 2: Verify file exists and frontmatter is absent**

`AGENTS.md` is a plain markdown file, not a skill, so it must NOT have YAML frontmatter. Verify it starts with `# AGENTS.md`.

```bash
head -3 AGENTS.md
```

Expected:
```
# AGENTS.md

Shared conventions for AI agents maintaining this toolkit repo. This file is loaded every session.
```

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "chore: add AGENTS.md with shared repo conventions"
```

---

## Task 3: Create `CLAUDE.md`

**Files:**
- Create: `CLAUDE.md`

**Context:** One-line file so Claude Code inherits the same conventions as OpenCode.

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
@AGENTS.md
```

- [ ] **Step 2: Verify content**

```bash
cat CLAUDE.md
```

Expected output: exactly `@AGENTS.md`.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "chore: add CLAUDE.md referencing AGENTS.md"
```

---

## Task 3A: Create branch publishing helper

**Files:**
- Create: `scripts/publish-branch.sh`

**Context:** Centralize branch publishing and PR creation behind one safety-checked command. This avoids relying on `git push origin $(git rev-parse --abbrev-ref HEAD)`, which still pushes `main` when the current branch is `main`.

- [ ] **Step 1: Write `scripts/publish-branch.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

branch="$(git rev-parse --abbrev-ref HEAD)"

if [ "$branch" = "main" ]; then
  printf 'Refusing to publish protected branch: %s\n' "$branch" >&2
  exit 1
fi

git push -u origin "$branch"

pr_url="$(gh pr list --head "$branch" --json url --jq '.[0].url')"
if [ -n "$pr_url" ]; then
  printf '%s\n' "$pr_url"
else
  gh pr create --fill
fi
```

- [ ] **Step 2: Make script executable**

```bash
chmod +x scripts/publish-branch.sh
```

- [ ] **Step 3: Verify script syntax**

```bash
shellcheck scripts/publish-branch.sh
bash -n scripts/publish-branch.sh
```

Expected: both commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/publish-branch.sh
git commit -m "chore: add safe branch publishing helper"
```

---

## Task 4: Create `agent-planning` skill

**Files:**
- Create: `.agents/skills/agent-planning/SKILL.md`

**Context:** Trimmed version of `core/agents/skills/workflow-planning/SKILL.md` adapted for markdown + bash. No TDD, no code blocks. Emphasizes file mapping, core/stack ripple, sync invariants, and verification commands.

- [ ] **Step 1: Create directory and write skill**

```bash
mkdir -p .agents/skills/agent-planning
```

```markdown
---
name: agent-planning
description: Use when a spec or requirements for this toolkit repo need to be turned into a plan, before touching files
user-invocable: false
---

# Agent Planning — Self-Maintenance

Write lightweight implementation plans for this toolkit repo. There is no application code — the maintenance surface is markdown templates and bash scripts.

**Announce at start:** "I'm using the agent-planning skill to create the implementation plan."

**Save plans to:** `plans/YYYY-MM-DD-<feature-name>/plan.md`, next to the spec.

## Scope Check

If the spec covers multiple independent concerns, suggest splitting into separate plans.

## File Mapping

Before defining tasks, map out which files will be created or modified. For each file:

- What it is responsible for
- Whether a `stacks/*` overlay also needs updating (core+stacks dual-maintenance)
- Whether `README.md`, this repo's `skills-lock.json`, `core/skills-lock.json`, or the dot-mapping table need updates for their distinct scopes

## Task Granularity

Each task is one focused commit. Steps within a task are 2-5 minute actions:

- "Write the file" — step
- "Verify syntax" — step
- "Commit" — step

No rigid TDD — verification is shellcheck, bash -n, smoke runs, and consistency checks.

## Plan Document Header

```markdown
# [Feature Name] Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence]

**Configuration shape:** [2-3 sentences]

**Configuration surface:** [Key files, tools, and validation commands]
```

## Task Structure

```markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file`
- Modify: `exact/path/to/existing`

- [ ] **Step 1: [Action]**

[Content — exact paths, complete file content or commands]

- [ ] **Step 2: Verify**

Run: `shellcheck scripts/foo.sh`
Expected: no errors

- [ ] **Step 3: Commit**

```bash
git add path/to/file
git commit -m "chore: description"
```
```

## No Placeholders

Every step must contain actual content. Replace placeholder phrases such as "TBD", "TODO", "implement later", "add appropriate handling", and "similar to Task N" with concrete instructions.

## Self-Review

After writing the plan:

1. **Spec coverage:** Can you point to a task for each spec requirement?
2. **Placeholder scan:** Search for red-flag patterns.
3. **Sync check:** Do README, repo lockfile, core template lockfile, and dot-mapping need updates for their separate scopes? Are those tasks included?

Fix inline. No re-review needed.

## Completion

After saving the plan, report the plan path and any open questions. Stop after reporting.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 .agents/skills/agent-planning/SKILL.md
```

Expected:
```
---
name: agent-planning
description: Use when a spec or requirements for this toolkit repo need to be turned into a plan, before touching files
user-invocable: false
---
```

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/agent-planning/SKILL.md
git commit -m "chore: add agent-planning skill for self-maintenance"
```

---

## Task 5: Create `agent-implementation` skill

**Files:**
- Create: `.agents/skills/agent-implementation/SKILL.md`

**Context:** Adapted from `core/agents/skills/workflow-implementation/SKILL.md` but lighter. No TDD, no DDD. Focuses on controller/worker pattern for markdown + bash.

- [ ] **Step 1: Create directory and write skill**

```bash
mkdir -p .agents/skills/agent-implementation
```

```markdown
---
name: agent-implementation
description: Use when executing an approved plan for this toolkit repo task-by-task with commits and verification
user-invocable: false
---

# Agent Implementation — Self-Maintenance

Controller orchestration for implementing plans against this toolkit repo.

**Core principle:** Fresh `implement-task` worker per task + verification gate = quality commits.

**Continuous execution:** Execute all tasks from the plan without routine pauses between tasks. Stop for: BLOCKED status, genuine ambiguity, or all tasks complete.

## The Process

1. Extract one task with enough context for isolated execution.
2. Give the worker the full task text, relevant spec/plan paths, and current branch state.
3. Review the worker report and diff before moving on.
4. Fix and re-review every open issue before marking the task complete.
5. Run final verification before any completion or push claim.

## Worker Contract

The `implement-task` worker:

- Implements exactly one task
- Creates or modifies only the files specified
- Runs verification (shellcheck, bash -n, smoke runs as applicable)
- Commits with a focused message
- Reports status: DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- Does not push, create PRs, or dispatch other workers

## Handling Worker Status

- **DONE:** Verify the diff, move to next task.
- **DONE_WITH_CONCERNS:** Read concerns. If about correctness, address before continuing.
- **NEEDS_CONTEXT:** Provide missing context and re-dispatch.
- **BLOCKED:** Assess: context problem → provide more; plan wrong → escalate to human.

Treat every worker escalation as actionable. If the worker said it's stuck, something needs to change.

## Operating Rules

- Start from a scoped branch.
- Run the relevant verification before status claims and before moving to the next task.
- Resolve correctness issues before continuing.
- Dispatch workers sequentially by default; use parallel workers only for independent tasks touching disjoint files.
- Give each worker the task text, relevant context, and branch state.

## Completion

After all tasks complete and final verification passes:

1. Commit all changes.
2. If the human asked for publishing, run `scripts/publish-branch.sh`.
3. Report the final verification evidence and PR URL when one was created.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -4 .agents/skills/agent-implementation/SKILL.md
```

Expected:
```
---
name: agent-implementation
description: Use when executing an approved plan for this toolkit repo task-by-task with commits and verification
---
```

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/agent-implementation/SKILL.md
git commit -m "chore: add agent-implementation skill for self-maintenance"
```

---

## Task 6: Create `agent-verification` skill

**Files:**
- Create: `.agents/skills/agent-verification/SKILL.md`

**Context:** The "done" gate for the maintenance surface: shellcheck, bash -n, smoke runs, and consistency checks.

- [ ] **Step 1: Create directory and write skill**

```bash
mkdir -p .agents/skills/agent-verification
```

```markdown
---
name: agent-verification
description: Use when about to claim work is complete, committed, or ready — the done gate for this toolkit repo
user-invocable: false
---

# Agent Verification — Self-Maintenance

**Core principle:** Evidence before claims, always. If you haven't run the verification command, you cannot claim it passes.

## The Gate

```
BEFORE claiming any status:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code
4. VERIFY: Does output confirm the claim?
5. ONLY THEN: Make the claim (with evidence)
```

## Verification Commands

### For bash scripts (`scripts/init.sh`, `scripts/copy.sh`)

```bash
shellcheck scripts/init.sh scripts/copy.sh
bash -n scripts/init.sh
bash -n scripts/copy.sh
```

### Smoke run (scripts)

Run the script against a throwaway target dir under `.temp/`:

```bash
mkdir -p .temp/smoke-test
echo -e "1\n1\n.temp/smoke-test/target" | bash scripts/init.sh
```

For `copy.sh`:

```bash
mkdir -p .temp/smoke-copy && cd .temp/smoke-copy && git init && echo "placeholder" > README.md && git add . && git commit -m "init"
cd ../..
echo -e "1\n1" | bash scripts/copy.sh .temp/smoke-copy
```

Clean up after:

```bash
rm -rf .temp/smoke-test .temp/smoke-copy
```

### For markdown files

No compilation check, but verify:
- SKILL.md frontmatter has required `name` and `description`
- Agent `.md` files have required `description` in frontmatter
- No broken relative links (manual spot-check)

### Consistency checks

```bash
# README lists match actual files
ls .opencode/agents/          # should match README's agent list
ls .agents/skills/            # should match README's skill list

# Lockfiles match their distinct scopes
jq '.skills | keys' skills-lock.json
jq '.skills | keys' core/skills-lock.json

# Symlinks resolve
ls -la .claude/skills/        # each should point to ../../.agents/skills/<name>
```

## Claim Rules

- Use evidence-based language tied to command output.
- Run verification before success claims.
- Run relevant checks before commits, publishing, or PR creation.
- Verify agent success reports independently.

## When To Apply

ALWAYS before:
- Any completion or success claim
- Any commit
- Any push or PR creation
- Moving to next task

## Bottom Line

Run the command. Read the output. THEN claim the result.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 .agents/skills/agent-verification/SKILL.md
```

Expected:
```
---
name: agent-verification
description: Use when about to claim work is complete, committed, or ready — the done gate for this toolkit repo
user-invocable: false
---
```

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/agent-verification/SKILL.md
git commit -m "chore: add agent-verification skill for self-maintenance"
```

---

## Task 7: Create `agent-review` skill

**Files:**
- Create: `.agents/skills/agent-review/SKILL.md`

**Context:** Single review agent covering both plan-review and diff-review (per spec §3).

- [ ] **Step 1: Create directory and write skill**

```bash
mkdir -p .agents/skills/agent-review
```

```markdown
---
name: agent-review
description: Use when reviewing plans or diffs for this toolkit repo against the shared conventions in AGENTS.md
user-invocable: false
---

# Agent Review — Self-Maintenance

Review plans and diffs against the conventions in `AGENTS.md`.

## Review Checklist

### For plans

- [ ] Spec coverage: every requirement has a task
- [ ] File mapping includes core/stack ripple check
- [ ] Sync invariants addressed (README, lockfiles, dot-mapping)
- [ ] No placeholders (TBD, TODO, "similar to Task N")
- [ ] Verification commands included per task
- [ ] Task boundaries produce one commit each

### For diffs

- [ ] Changes match the approved plan
- [ ] SKILL.md frontmatter has `name` and `description`
- [ ] Agent `.md` has `description` in frontmatter
- [ ] Symlinks in `.claude/skills/` resolve correctly
- [ ] `skills-lock.json` reflects this repo's self-maintenance skills
- [ ] `core/skills-lock.json` reflects target-project template skills
- [ ] README agent/skill lists match actual files
- [ ] Shell scripts pass shellcheck and bash -n
- [ ] No force-push, no branch deletion, no worktree removal
- [ ] Commits are concise, imperative, scoped to one logical change
- [ ] No Co-Authored-By lines

## Review Priorities

1. Bugs, broken scripts, incorrect symlinks
2. Missing sync: README vs files, lockfiles vs installed skills
3. Convention violations from AGENTS.md
4. Unnecessary scope expansion

## Output

Present findings ordered by severity with file and line references. If no findings, say so.

Review and report findings without editing files directly. Provide suggested fixes when useful.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 .agents/skills/agent-review/SKILL.md
```

Expected:
```
---
name: agent-review
description: Use when reviewing plans or diffs for this toolkit repo against the shared conventions in AGENTS.md
user-invocable: false
---
```

- [ ] **Step 3: Commit**

```bash
git add .agents/skills/agent-review/SKILL.md
git commit -m "chore: add agent-review skill for self-maintenance"
```

---

## Task 8: Create `.claude/skills/` symlinks

**Files:**
- Create: `.claude/skills/agent-planning` → `../../.agents/skills/agent-planning`
- Create: `.claude/skills/agent-implementation` → `../../.agents/skills/agent-implementation`
- Create: `.claude/skills/agent-verification` → `../../.agents/skills/agent-verification`
- Create: `.claude/skills/agent-review` → `../../.agents/skills/agent-review`

**Context:** Same symlink model `copy.sh` uses for authored skills.

- [ ] **Step 1: Create directory and symlinks**

```bash
mkdir -p .claude/skills
ln -sf ../../.agents/skills/agent-planning .claude/skills/agent-planning
ln -sf ../../.agents/skills/agent-implementation .claude/skills/agent-implementation
ln -sf ../../.agents/skills/agent-verification .claude/skills/agent-verification
ln -sf ../../.agents/skills/agent-review .claude/skills/agent-review
```

- [ ] **Step 2: Verify symlinks resolve**

```bash
ls -la .claude/skills/
```

Expected output (4 symlinks, all pointing to `../../.agents/skills/<name>`):
```
agent-planning -> ../../.agents/skills/agent-planning
agent-implementation -> ../../.agents/skills/agent-implementation
agent-verification -> ../../.agents/skills/agent-verification
agent-review -> ../../.agents/skills/agent-review
```

Verify content is readable:

```bash
cat .claude/skills/agent-planning/SKILL.md | head -3
```

Expected: `---\nname: agent-planning`.

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/
git commit -m "chore: add .claude/skills symlinks for Claude Code compatibility"
```

---

## Task 9: Create `planning` agent

**Files:**
- Create: `.opencode/agents/planning.md`

**Context:** Mode primary. Uses a distinct `planning` name instead of overriding OpenCode's built-in `plan` agent. Edit restricted to `plans/**`. Loads `agent-planning` and `writing-skills`.

- [ ] **Step 1: Create directory and write agent**

```bash
mkdir -p .opencode/agents
```

```markdown
---
description: Writes lightweight plans for this toolkit repo's markdown + bash maintenance surface.
mode: primary
temperature: 0.2
permission:
  edit:
    "*": deny
    "plans/**": allow
  bash:
    "*": ask
    # File read and inspection
    "grep *": allow
    "ls *": allow
    "wc *": allow
    "date *": allow
    "which *": allow
    # Directory creation for plans
    "mkdir plans/*": allow
    "mkdir -p plans/*": allow
    # Git inspection and plan commits
    "git diff *": allow
    "git log *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow
    "git add plans/*": allow
    "git branch *": allow
    "git checkout *": allow
    "git commit *": allow
    # Protective denials are last because opencode uses last-match-wins permissions
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny
    "git push --force *": deny
    "git push -f *": deny
    "git push origin --force *": deny
    "git push origin -f *": deny
    "git push origin main*": deny
    "git push origin +main*": deny
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "agent-planning": allow
    "writing-skills": allow
---

You are the planning agent for this toolkit repo.

Load the approved spec first. Use the `agent-planning` skill to write the plan.

Your task is to write implementation plans to `plans/YYYY-MM-DD-feature-name/plan.md` next to the spec.

Plan requirements:

- Map affected files, including core/stacks ripple.
- Split work into tasks with one logical commit per task.
- Include exact file paths, concrete steps, verification commands, and commit messages.
- Check that README, lockfiles, and sync invariants are addressed.
- Every step has actual content.
- State which docs were used.

Use `@explore` when you need to investigate before planning. Continue after the context is strong enough to support the plan.

After writing the plan, report the plan path and any open questions.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -4 .opencode/agents/planning.md
```

Expected:
```
---
description: Writes lightweight plans for this toolkit repo's markdown + bash maintenance surface.
mode: primary
```

- [ ] **Step 3: Commit**

```bash
git add .opencode/agents/planning.md
git commit -m "chore: add planning agent for self-maintenance"
```

---

## Task 10: Create `implement` agent

**Files:**
- Create: `.opencode/agents/implement.md`

**Context:** Mode primary. Edit allowed everywhere. Dispatches `implement-task` workers. Includes `.temp/` permissions for smoke runs.

- [ ] **Step 1: Write agent**

```markdown
---
description: Implements approved plans task-by-task with verification and commits for this toolkit repo.
mode: primary
temperature: 0.1
permission:
  edit: allow
  bash:
    "*": ask
    # GitHub PR operations
    "gh pr create *": allow
    "gh pr list *": allow
    "gh pr view *": allow
    # Git write and inspection operations
    "git add *": allow
    "git branch *": allow
    "git checkout *": allow
    "git commit *": allow
    "git diff *": allow
    "git grep *": allow
    "git log *": allow
    "git mv *": allow
    "git rev-parse *": allow
    "git rm *": allow
    "git rebase *": allow
    "git reset --soft *": allow
    "git reset --mixed *": allow
    "git pull *": allow
    "git show *": allow
    "git status *": allow
    # File read and inspection
    "cat *": allow
    "diff *": allow
    "find *": allow
    "grep *": allow
    "head *": allow
    "ls *": allow
    "rg *": allow
    "sed -n *": allow
    "sort *": allow
    "tail *": allow
    "wc *": allow
    # File write and transformation helpers
    "cp *": allow
    "chmod +x scripts/*": allow
    "chmod 755 scripts/*": allow
    "jq *": allow
    "file *": allow
    "stat *": allow
    "tr *": allow
    "cut *": allow
    "uniq *": allow
    "paste *": allow
    "echo *": allow
    "date *": allow
    "mkdir *": allow
    "mkdir -p *": allow
    "mkdir .temp/*": allow
    "mkdir -p .temp/*": allow
    # Verification commands
    "shellcheck *": allow
    "bash -n *": allow
    "rm -rf .temp/*": allow
    "rm -rf .temp": allow
    # Publishing goes through the branch-safety helper
    "scripts/publish-branch.sh": allow
    "bash scripts/publish-branch.sh": allow
    # Protective rules are last because opencode uses last-match-wins permissions
    "git branch -d *": deny
    "git branch -D *": deny
    "git reset --hard *": ask
    "git worktree remove *": deny
    "git push": ask
    "git push origin *": ask
    "git push --force *": deny
    "git push -f *": deny
    "git push origin --force *": deny
    "git push origin -f *": deny
    "git push origin main*": deny
    "git push origin +main*": deny
    "git push origin --delete *": deny
    "git push origin :*": deny
    "git push origin *:*": ask
    "git push origin --tags*": ask
    "git push origin tag *": ask
  task:
    "*": deny
    "explore": allow
    "implement-task": allow
  skill:
    "*": deny
    "agent-implementation": allow
    "agent-verification": allow
---

You are the implementation controller for this toolkit repo.

Use the `agent-implementation` skill for orchestration. Use `agent-verification` before any completion claim.

Execution rules:

- Work from a scoped branch before editing.
- Prefer `git mv` for moves/renames, `git rm` for removals of tracked paths.
- Use `scripts/publish-branch.sh` for publishing and PR creation.
- Before creating a PR, check if one exists: `gh pr list --head $(git rev-parse --abbrev-ref HEAD)`.
- Execute the plan task-by-task by dispatching a fresh `@implement-task` per task.
- Review each worker's report and diff before moving on.
- Continue between tasks without routine approval pauses.
- Stop only for: BLOCKED status, genuine ambiguity, or all tasks complete.
- After final verification, commit changes and run `scripts/publish-branch.sh` when the human asks for publishing.

Verification for this repo:

- `shellcheck` and `bash -n` on changed scripts.
- Smoke-run `init.sh`/`copy.sh` against `.temp/` when scripts changed.
- Consistency checks: README lists ↔ actual files ↔ lockfiles ↔ dot-mapping.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -4 .opencode/agents/implement.md
```

Expected:
```
---
description: Implements approved plans task-by-task with verification and commits for this toolkit repo.
mode: primary
```

- [ ] **Step 3: Commit**

```bash
git add .opencode/agents/implement.md
git commit -m "chore: add implement agent for self-maintenance"
```

---

## Task 11: Create `implement-task` agent

**Files:**
- Create: `.opencode/agents/implement-task.md`

**Context:** Mode subagent, hidden. Worker for exactly one task. No push/PR.

- [ ] **Step 1: Write agent**

```markdown
---
description: Hidden worker that implements one task from a plan with verification and commit.
mode: subagent
hidden: true
temperature: 0.3
permission:
  edit: allow
  bash:
    "*": ask
    # Git inspection and single-task commits
    "git diff *": allow
    "git grep *": allow
    "git log *": allow
    "git ls-files *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow
    "git branch *": allow
    "git add *": allow
    "git checkout *": allow
    "git commit *": allow
    "git mv *": allow
    "git rm *": allow
    # File read and inspection
    "cat *": allow
    "diff *": allow
    "find *": allow
    "grep *": allow
    "head *": allow
    "ls *": allow
    "pwd": allow
    "rg *": allow
    "sort *": allow
    "sed -n *": allow
    "tail *": allow
    "wc *": allow
    # File write and transformation helpers
    "cp *": allow
    "chmod +x scripts/*": allow
    "chmod 755 scripts/*": allow
    "jq *": allow
    "file *": allow
    "stat *": allow
    "tr *": allow
    "cut *": allow
    "uniq *": allow
    "paste *": allow
    "echo *": allow
    "date *": allow
    "mkdir *": allow
    "mkdir -p *": allow
    "mkdir .temp/*": allow
    "mkdir -p .temp/*": allow
    "touch *": allow
    # Verification and symlink commands
    "shellcheck *": allow
    "bash -n *": allow
    "ln -s *": allow
    "rm -rf .temp/*": allow
    "rm -rf .temp": allow
    # Protective rules are last because opencode uses last-match-wins permissions
    "git push *": deny
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "agent-verification": allow
---

You are the single-task implementation worker for this toolkit repo.

Implement exactly one task provided by `@implement`. Keep context and edits scoped to that task.

Rules:

- Work from a scoped branch.
- Follow the provided task text, spec context, plan context, and repo docs.
- Make the smallest correct change.
- Prefer `git mv` for moves/renames, `git rm` for removals of tracked paths.
- Run verification: `shellcheck` and `bash -n` on changed scripts, smoke runs when applicable, consistency checks.
- Commit exactly the task changes with the message from the plan.
- Leave publishing, PR creation, commit amendment, and worker dispatch to the controller or human.
- If requirements are unclear, report `NEEDS_CONTEXT` before editing.
- If blocked after three attempts, report `BLOCKED` with what you tried.

Before reporting, self-review the diff for correctness, overbuilding, and obvious defects.

Report format:

- **Status:** DONE, DONE_WITH_CONCERNS, NEEDS_CONTEXT, or BLOCKED
- **Commit:** commit SHA or none
- **Implemented:** concise summary
- **Verification:** exact commands run and results
- **Files changed:** paths
- **Concerns:** anything the controller should inspect
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -5 .opencode/agents/implement-task.md
```

Expected:
```
---
description: Hidden worker that implements one task from a plan with verification and commit.
mode: subagent
hidden: true
```

- [ ] **Step 3: Commit**

```bash
git add .opencode/agents/implement-task.md
git commit -m "chore: add implement-task subagent for self-maintenance"
```

---

## Task 12: Create `review` agent

**Files:**
- Create: `.opencode/agents/review.md`

**Context:** Mode primary. Single agent for plan + diff review. Edit restricted to `plans/**`. Read-only `.temp/` access for verification inspection.

- [ ] **Step 1: Write agent**

```markdown
---
description: Reviews plans and diffs for this toolkit repo against AGENTS.md conventions.
mode: primary
temperature: 0.1
permission:
  edit:
    "*": deny
    "plans/**": allow
  bash:
    "*": ask
    # File read and inspection
    "ls": allow
    "ls *": allow
    "ls .temp/*": allow
    "find .temp/*": allow
    "grep *": allow
    # Git inspection
    "git branch --show-current": allow
    "git diff *": allow
    "git log *": allow
    "git merge-base *": allow
    "git status *": allow
    "git show *": allow
    "git branch": allow
    "git branch *": allow
    # Verification commands
    "shellcheck *": allow
    "bash -n *": allow
    # Protective rules are last because opencode uses last-match-wins permissions
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny
    "git push *": ask
    "git push origin main*": deny
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "agent-review": allow
    "agent-verification": allow
---

You are the review agent for this toolkit repo.

Use the `agent-review` skill for the review checklist. Use `agent-verification` for evidence-based claims.

Review goals:

- For plans: spec coverage, file mapping, core/stack ripple, sync invariants, no placeholders, verification commands.
- For diffs: plan conformance, SKILL.md/agent frontmatter, symlinks, lockfile consistency, README accuracy, shellcheck results, git conventions.

Combine your findings into one deduplicated, prioritized list. Separate blocking issues from advisory suggestions. Cite file paths and sections.

Review and report findings without editing files directly. Provide suggested fixes when useful.

Use `@explore` when you need to investigate before judging a finding.
```

- [ ] **Step 2: Validate frontmatter**

```bash
head -4 .opencode/agents/review.md
```

Expected:
```
---
description: Reviews plans and diffs for this toolkit repo against AGENTS.md conventions.
mode: primary
```

- [ ] **Step 3: Commit**

```bash
git add .opencode/agents/review.md
git commit -m "chore: add review agent for self-maintenance"
```

---

## Task 13: Create `opencode.json`

**Files:**
- Create: `opencode.json`

**Context:** Root config assigns models, registers `.agents/skills`, disables built-in `build` and `plan`, and sets `default_agent: planning`.

- [ ] **Step 1: Write config**

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "planning",
  "model": "opencode-go/mimo-v2.5-pro",
  "small_model": "opencode-go/mimo-v2.5",
  "skills": {
    "paths": [".agents/skills"]
  },
  "agent": {
    "build": {
      "disable": true
    },
    "plan": {
      "disable": true
    },
    "planning": {
      "model": "opencode-go/mimo-v2.5-pro"
    },
    "implement": {
      "model": "opencode-go/mimo-v2.5-pro"
    },
    "implement-task": {
      "model": "opencode-go/mimo-v2.5",
      "mode": "subagent"
    },
    "review": {
      "model": "opencode-go/kimi-k2.7-code"
    }
  },
  "permission": {
    "bash": {
      "*": "ask",
      "git branch -d *": "deny",
      "git branch -D *": "deny",
      "git worktree remove *": "deny"
    },
    "edit": {
      "*": "allow"
    },
    "read": {
      "*": "allow"
    },
    "webfetch": "ask"
  }
}
```

**Note:** The built-in `plan` and `build` agents are explicitly disabled. The custom planning agent is `.opencode/agents/planning.md`.

- [ ] **Step 2: Validate JSON**

```bash
jq . opencode.json
```

Expected: Valid JSON, no errors, pretty-printed output matches the file.

- [ ] **Step 3: Commit**

```bash
git add opencode.json
git commit -m "chore: add opencode.json with model and agent config"
```

---

## Task 14: Update `core/skills-lock.json` — swap writing-skills source

**Files:**
- Modify: `core/skills-lock.json`

**Context:** This is the template lockfile installed into target repos. Replace `write-a-skill` (mattpocock/skills) with `writing-skills` (obra/superpowers).

- [ ] **Step 1: Verify obra/superpowers resolves non-interactively**

```bash
npx skills add obra/superpowers --skill writing-skills --yes 2>&1 | tail -30
```

Expected: Repository cloned, skill found, installation completes without prompting. If this fails, stop and escalate.

- [ ] **Step 2: Replace the lockfile entry**

Current content of `core/skills-lock.json`:
```json
{
  "version": 1,
  "skills": {
    "context7-cli": {
      "source": "upstash/context7",
      "sourceType": "github"
    },
    "write-a-skill": {
      "source": "mattpocock/skills",
      "sourceType": "github"
    }
  }
}
```

New content:
```json
{
  "version": 1,
  "skills": {
    "context7-cli": {
      "source": "upstash/context7",
      "sourceType": "github"
    },
    "writing-skills": {
      "source": "obra/superpowers",
      "sourceType": "github"
    }
  }
}
```

- [ ] **Step 3: Validate JSON**

```bash
jq . core/skills-lock.json
```

Expected: Valid JSON with `writing-skills` key and `obra/superpowers` source.

- [ ] **Step 4: Commit**

```bash
git add core/skills-lock.json
git commit -m "chore: swap writing-skills source to obra/superpowers in core lockfile"
```

---

## Task 15: Install `writing-skills` into this repo

**Files:**
- Create: `.agents/skills/writing-skills/SKILL.md` (via npx skills install)
- Create: `.claude/skills/writing-skills` symlink (manually, fallback)

**Context:** Remote skill tracked in root `skills-lock.json`. The `npx skills add` command may or may not create the Claude symlink; the fallback covers both cases.

- [ ] **Step 1: Install the skill**

```bash
npx skills add obra/superpowers --skill writing-skills -a opencode --yes
```

- [ ] **Step 2: Verify installation**

```bash
ls .agents/skills/writing-skills/SKILL.md
```

Expected: File exists.

- [ ] **Step 3: Ensure Claude symlink exists**

```bash
if [ ! -e .claude/skills/writing-skills ]; then
  ln -s ../../.agents/skills/writing-skills .claude/skills/writing-skills
fi
ls -la .claude/skills/writing-skills
```

Expected: Symlink resolves to `../../.agents/skills/writing-skills` and `SKILL.md` is readable.

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/writing-skills/ .claude/skills/writing-skills
git commit -m "chore: install writing-skills from obra/superpowers"
```

---

## Task 16: Create root `skills-lock.json`

**Files:**
- Create: `skills-lock.json`

**Context:** Tracks provenance for the remote skill installed in this repo itself. Separate from `core/skills-lock.json` (the template).

- [ ] **Step 1: Write lockfile**

```json
{
  "version": 1,
  "skills": {
    "writing-skills": {
      "source": "obra/superpowers",
      "sourceType": "github"
    }
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
jq . skills-lock.json
```

- [ ] **Step 3: Commit**

```bash
git add skills-lock.json
git commit -m "chore: add root skills-lock.json for writing-skills provenance"
```

---

## Task 17: Final verification and README update

**Files:**
- Modify: `README.md`

**Context:** README lists must match actual files (sync invariant). Also run the full verification suite.

- [ ] **Step 1: Run shellcheck and bash syntax checks**

```bash
shellcheck scripts/init.sh scripts/copy.sh
bash -n scripts/init.sh
bash -n scripts/copy.sh
```

Expected: `shellcheck` exits 0, `bash -n` exits 0 for both scripts.

- [ ] **Step 2: Validate all JSON files**

```bash
jq . opencode.json > /dev/null
jq . skills-lock.json > /dev/null
jq . core/skills-lock.json > /dev/null
```

Expected: All exit 0.

- [ ] **Step 3: Verify symlink integrity**

```bash
ls -la .claude/skills/
```

Expected (5 symlinks):
```
agent-planning -> ../../.agents/skills/agent-planning
agent-implementation -> ../../.agents/skills/agent-implementation
agent-verification -> ../../.agents/skills/agent-verification
agent-review -> ../../.agents/skills/agent-review
writing-skills -> ../../.agents/skills/writing-skills
```

- [ ] **Step 4: Verify file existence**

```bash
ls .opencode/agents/planning.md .opencode/agents/implement.md .opencode/agents/implement-task.md .opencode/agents/review.md
ls .agents/skills/agent-planning/SKILL.md .agents/skills/agent-implementation/SKILL.md .agents/skills/agent-verification/SKILL.md .agents/skills/agent-review/SKILL.md .agents/skills/writing-skills/SKILL.md
ls AGENTS.md CLAUDE.md .gitignore opencode.json skills-lock.json scripts/publish-branch.sh
```

- [ ] **Step 5: Smoke-run `init.sh` (optional but recommended)**

```bash
mkdir -p .temp/smoke-init
echo -e "1\n1\n$(pwd)/.temp/smoke-init/target" | bash scripts/init.sh
ls .temp/smoke-init/target/.agents/skills/writing-skills/SKILL.md
rm -rf .temp/smoke-init
```

Expected: Target repo created, `writing-skills` installed at target's `.agents/skills/writing-skills/SKILL.md`.

- [ ] **Step 6: Smoke-run `copy.sh` (optional but recommended)**

```bash
mkdir -p .temp/smoke-copy && cd .temp/smoke-copy && git init && echo "placeholder" > README.md && git add . && git commit -m "init" && cd ../..
echo -e "1\n1" | bash scripts/copy.sh "$(pwd)/.temp/smoke-copy"
ls .temp/smoke-copy/.agents/skills/writing-skills/SKILL.md
rm -rf .temp/smoke-copy
```

Expected: Toolkit merged into existing repo, `writing-skills` installed.

- [ ] **Step 7: Update `README.md`**

Add a "Self-Maintenance Agents" section documenting:

- The 4 agents: `planning`, `implement`, `implement-task`, `review`
- The 5 skills: `agent-planning`, `agent-implementation`, `agent-verification`, `agent-review`, `writing-skills`
- The `AGENTS.md` + `CLAUDE.md` convention
- That `writing-skills` is sourced from `obra/superpowers`
- How to invoke them (`@planning`, `@implement`, `@review` in OpenCode; `/agent-planning`, etc. in Claude Code)

Also update any existing agent/skill inventory lists to include the new entries.

- [ ] **Step 8: Verify README sync**

After editing, check that README lists match actual files:

```bash
echo "Agents in .opencode/agents/:" && ls .opencode/agents/
echo "Skills in .agents/skills/:" && ls .agents/skills/
```

Compare against README. They must match.

- [ ] **Step 9: Commit README**

```bash
git add README.md
git commit -m "docs: document self-maintenance agents and skills in README"
```

---

## Final Verification Checklist

Before claiming the implementation complete, run:

```bash
# 1. Script syntax
shellcheck scripts/init.sh scripts/copy.sh
bash -n scripts/init.sh
bash -n scripts/copy.sh

# 2. JSON validity
jq . opencode.json
jq . skills-lock.json
jq . core/skills-lock.json

# 3. Symlink integrity
ls -la .claude/skills/

# 4. Required files exist
ls .opencode/agents/planning.md .opencode/agents/implement.md .opencode/agents/implement-task.md .opencode/agents/review.md
ls .agents/skills/agent-planning/SKILL.md .agents/skills/agent-implementation/SKILL.md .agents/skills/agent-verification/SKILL.md .agents/skills/agent-review/SKILL.md .agents/skills/writing-skills/SKILL.md
ls AGENTS.md CLAUDE.md .gitignore opencode.json skills-lock.json scripts/publish-branch.sh

# 5. README sync (manual compare)
ls .opencode/agents/
ls .agents/skills/
```

All checks must pass before creating a PR.

---

## Completion

After final verification passes:

1. Publish the branch and create/view the PR:
   ```bash
   scripts/publish-branch.sh
   ```

2. Report the PR URL and final status.

---

## Docs Used

- `plans/2026-06-23-self-maintenance-agents-spec.md` (the design spec)
- `core/opencode/agents/planner.md`, `core/opencode/agents/implement.md`, `core/opencode/agents/implement-task.md`, `core/opencode/agents/review-code.md` (template patterns)
- `core/agents/skills/workflow-planning/SKILL.md`, `core/agents/skills/workflow-implementation/SKILL.md`, `core/agents/skills/workflow-verification/SKILL.md` (template skill patterns)
- `core/opencode.json` (template config pattern)
- `scripts/init.sh`, `scripts/copy.sh` (lockfile and symlink logic)
- `https://opencode.ai/config.json` (schema validation, agent fields, permission object shape)
- OpenCode permission model guidance: per-tool permission objects use insertion order with last matching rule winning
- Claude Code skills compatibility model via `.claude/skills/<name>` symlinks to `.agents/skills/<name>`
