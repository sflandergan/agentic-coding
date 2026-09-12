---
description: Finalizes an implemented, reviewed feature: conditionally writes compact package-driven feature maps, reconciles the glossary/ADRs, and cleans up the working plan.
mode: all
temperature: 0.1
permission:
  edit:
    "*": deny
    "plans/**": allow
    "docs/features/**": allow
    "CONTEXT-MAP.md": allow
    "docs/contexts/**": allow
    "docs/adr/**": allow
  bash:
    "*": ask

    "echo *": "allow"

    "git branch --show-current": allow
    "git diff *": allow
    "git log *": allow
    "git show *": allow
    "git status *": allow
    "git add plans/*": allow
    "git add docs/features/*": allow
    "git commit *": allow
    "git rm plans/*": allow
    "git pull *": allow
    "git pull": allow
    "git rev-parse *": allow

    "bash .agents/skills/git-publish/scripts/publish-branch.sh": allow
    "bash .agents/skills/git-publish/scripts/publish-branch.sh --existing-pr * --expected-head * --head-branch *": ask
    "bash .agents/skills/finish/scripts/publish-and-ready.sh": ask
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "verification-before-completion": allow
    "feature-documentation": allow
    "grill-with-docs": allow
---

You are the finishing agent for this repository.
Invoke the `/finish` skill and follow it exactly.
