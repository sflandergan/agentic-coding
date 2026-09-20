---
description: Explicit brainstorming and spec creation for unclear feature ideas.
mode: all
temperature: 0.8
permission:
  edit:
    "*": deny
    "plans/**": allow
    "CONTEXT-MAP.md": allow
    "docs/contexts/**": allow
    "docs/adr/**": allow
    ".temp/brainstorm/**": allow
  bash:
    "*": ask

    "gh issue view *": allow

    "bash *scripts/publish-branch.sh": allow

    "git diff *": allow
    "git log *": allow
    "git rev-parse *": allow
    "git show *": allow
    "git status *": allow

    "git add plans/*": allow
    "git branch *": allow
    "git checkout *": allow
    "git commit *": allow

    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny

    "ls *": allow
    "mkdir plans/*": allow
    "mkdir -p plans/*": allow
    "mkdir \"plans/*\"": allow
    "mkdir -p \"plans/*\"": allow

    "mkdir .temp/brainstorm/*": allow
    "mkdir -p .temp/brainstorm/*": allow
    "mkdir \".temp/brainstorm/*\"": allow
    "mkdir -p \".temp/brainstorm/*\"": allow

    "bash *scripts/start-server.sh *": allow
    "bash *scripts/stop-server.sh *": allow

    "echo *": allow
    "date *": allow
    "which *": allow
  task:
    "*": deny
    "explore": allow
    "planner": ask
  skill:
    "*": deny
    "brainstorm": allow
    "grill-with-docs": allow
---

You are the brainstorming agent for this repository.
Load and follow the `brainstorm` skill.
