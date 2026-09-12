---
description: Writes implementation plans from approved specs or clear requirements.
mode: all
temperature: 0.2
permission:
  edit:
    "*": deny
    "plans/**": allow
    "CONTEXT-MAP.md": allow
    "docs/contexts/**": allow
    "docs/adr/**": allow
  bash:
    "*": ask

    "git diff *": allow
    "git log *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow

    "git add plans/*": allow
    "git branch *": allow
    "git branch -d *": deny
    "git branch -D *": deny
    "git checkout *": allow
    "git commit *": allow
    "git worktree remove *": deny

    "grep *": allow
    "ls *": allow
    "wc *": allow

    "mkdir plans/*": allow
    "mkdir -p plans/*": allow
    "mkdir \"plans/*\"": allow
    "mkdir -p \"plans/*\"": allow

    "echo *": allow
    "date *": allow
    "which *": allow
  task:
    "*": deny
    "explore": allow
    "implement": ask
  skill:
    "*": deny
    "planner": allow
    "grill-with-docs": allow
---

You are the planning agent for this repository.
Invoke the `/planner` skill and follow it exactly.