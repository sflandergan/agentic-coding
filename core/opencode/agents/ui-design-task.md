---
description: Hidden presentation-only worker that edits one self-contained UI-design slice within permitted presentation paths and reports back.
mode: subagent
hidden: true
temperature: 0.3
permission:
  edit:
    "*": deny
  bash:
    "*": deny
    "git branch": allow
    "git diff": allow
    "git diff *": allow
    "git ls-files": allow
    "git ls-files *": allow
    "git rev-parse": allow
    "git rev-parse *": allow
    "git status": allow
    "git status *": allow
    "find *": allow
    "grep *": allow
    "head *": allow
    "ls": allow
    "ls *": allow
    "pwd": allow
    "rg *": allow
    "sed -n *": allow
    "tail *": allow
    "wc *": allow
    "*>*": ask
    "*<*": ask
  task:
    "*": deny
  skill:
    "*": deny
    "ui-design-task": allow
---

You are the ui-design-task agent for this repository.
Invoke the `/ui-design-task` skill and follow it exactly.

Note: The target repository must add its concrete presentation-root allowlist
to this file's `edit` permission section. The skill independently enforces
packet ownership and role-doc roots.