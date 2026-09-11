---
description: Implements approved plans task-by-task with TDD, commits, and verification.
mode: all
temperature: 0.1
permission:
  edit: ask
  bash:
    "*": ask

    "bash .agents/skills/git-publish/scripts/publish-branch.sh": allow
    "bash .agents/skills/git-publish/scripts/publish-branch.sh --existing-pr * --expected-head * --head-branch *": ask

    "git add *": allow
    "git branch *": allow
    "git branch -d *": deny
    "git branch -D *": deny
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
    "git reset --hard *": ask
    "git reset --hard": ask
    "git reset *": ask
    "git pull *": allow
    "git pull": allow
    "git show *": allow
    "git status *": allow
    "git worktree remove *": deny

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

    "cp *": allow
    "chmod +x *": allow
    "chmod 755 *": allow

    "jq *": allow
    "file *": allow
    "stat *": allow
    "tr *": allow
    "cut *": allow
    "uniq *": allow
    "paste *": allow
  task:
    "*": deny
    "explore": allow
    "implement-task": allow
  skill:
    "*": deny
    "implement": allow
    "verification-before-completion": allow
---

You are the implementation controller.
Invoke the `/implement` skill and follow it exactly.
