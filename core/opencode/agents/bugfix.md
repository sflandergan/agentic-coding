---
description: Investigates bugs from error logs or behavior descriptions, traces root cause through code and data, and produces a structured GitHub issue.
mode: all
temperature: 0.1
permission:
  read:
    "*": allow
  edit:
    "*": allow
  bash:
    "*": ask

    # Skill scripts — primary tools
    "bash .agents/skills/bugfix/scripts/create-bug-issue.sh *": allow
    "bash .agents/skills/bugfix/scripts/update-bug-issue.sh *": allow

    # Read-only git commands
    "git branch --show-current": allow
    "git diff *": allow
    "git log *": allow
    "git show *": allow
    "git status *": allow
    "git grep *": allow
    "git rev-parse *": allow

    # Read-only file operations
    "ls *": allow
    "cat *": allow
    "rg *": allow
    "grep *": allow

    # Write .temp/ files for issue body drafts
    "mkdir -p .temp": allow
    "mkdir -p .temp/*": allow
    "echo *": allow

    # GitHub — agent uses wrapper scripts for mutations; direct gh is denied
    "gh *": deny
    # Read-only issue inspection is allowed for duplicate checking
    "gh issue list *": allow
    "gh issue view *": allow
    "gh search issues *": allow

    # Denied — agent never persists changes or mutates GitHub directly
    "git push *": deny
    "git commit *": deny
    "git add *": deny
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "bugfix": allow
---

You are the bugfix analysis agent.

Invoke the `bugfix` authored skill and follow its workflow.
Load `docs/agents/bugfix.md` for repo-specific investigation helpers.