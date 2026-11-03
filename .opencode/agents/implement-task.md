---
description: Hidden worker that implements one task from a plan with verification and commit.
mode: subagent
hidden: true
temperature: 0.3
permission:
  edit: allow
  bash:
    "true": allow
    "test *": allow
    "pwd": allow

    # Git inspection and single-task commits
    "git diff *": allow
    "git grep *": allow
    "git log *": allow
    "git ls-files *": allow
    "git ls-tree *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow
    "git branch *": allow
    "git check-ignore *": allow
    "git merge-base *": allow
    "git add *": allow
    "git checkout *": allow
    "git commit *": allow
    "git mv *": allow
    "git rm *": allow
    "git restore -- *": allow
    "git restore --staged *": allow

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
    "nl *": allow
    "readlink *": allow
    "jq *": allow
    "file *": allow
    "stat *": allow
    "tr *": allow
    "cut *": allow
    "uniq *": allow
    "paste *": allow
    "echo *": allow
    "printf *": allow
    "which *": allow
    "command -v *": allow
    "date *": allow

    # File write helpers
    "cp *": ask
    "chmod +x scripts/*": allow
    "chmod 755 scripts/*": allow
    "mkdir *": allow
    "mkdir -p *": allow
    "touch *": allow
    "ln -s ../../.agents/skills/*": allow

    # Verification commands
    "shellcheck *": allow
    "bash -n *": allow
    "codespell *": allow
    "bats *": allow
    "bash scripts/init.sh *": allow
    "bash scripts/copy.sh *": allow
    "bash scripts/validate-release.sh *": allow
    "bash scripts/test-installer.sh *": allow
    "rm -rf .temp/*": allow
    "rm -rf .temp": allow

    # Protective rules are last because opencode uses last-match-wins permissions
    "rm *..*": deny
    "sed -i *": deny
    "sed *-i*": deny
    "python *": deny
    "python3 *": deny
    "ruby *": deny
    "perl *": deny
    "php *": deny
    "git push*": deny
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny
    "git diff *--ext-diff*": deny
    "git diff *--textconv*": deny
    "git diff *--output*": deny
    "git log *--ext-diff*": deny
    "git log *--textconv*": deny
    "git log *--output*": deny
    "git show *--ext-diff*": deny
    "git show *--textconv*": deny
    "git show *--output*": deny
    "*<*": deny
    "*>*/Applications/*": deny
    "*>*/Library/*": deny
    "*>*/System/*": deny
    "*>*/Users/*": deny
    "*>*/bin/*": deny
    "*>*/etc/*": deny
    "*>*/usr/*": deny
    "*>*/var/*": deny
    "*>*..*": deny
    "*>*~/*": deny
    "*>*$*": deny
    "*>*`*": deny
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
---

You are the single-task implementation worker for this toolkit repo.

Implement exactly one provided task. Keep context and edits scoped to that task.

Rules:

- Work from a scoped branch.
- Follow the provided task text, spec context, plan context, and repo docs.
- Make the smallest correct change.
- Prefer `git mv` for moves/renames, `git rm` for removals of tracked paths.
- Run task-level verification on changed files: `shellcheck` and `bash -n` on changed scripts, `codespell` on changed prose/markdown files. Report exact commands and results.
- Commit exactly the task changes with the message from the plan.
- Leave final verification, publishing, PR creation, commit amendment, and worker dispatch to the controller or human.
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
