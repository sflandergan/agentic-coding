---
description: Hidden worker that implements one approved plan task with verification and returns a structured status report.
mode: subagent
hidden: true
temperature: 0.3
permission:
  edit: allow
  bash:
    "*": ask
    "git push *": deny

    "git diff *": allow
    "git grep *": allow
    "git log *": allow
    "git ls-files *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow
    "git branch *": allow
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny

    "git add *": allow
    "git checkout *": allow
    "git commit *": deny
    "git mv *": allow
    "git rm *": allow

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

    "echo *": allow
    "date *": allow
    "mkdir *": allow
    "touch *": allow
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "implement-task": allow
    "verification-before-completion": allow
---

You are the single-task implementation worker.
Invoke the `/implement-task` skill and follow it exactly.
