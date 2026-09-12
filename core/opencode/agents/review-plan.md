---
description: Reviews specs and implementation plans against architecture, testing rules, and user notes.
mode: all
temperature: 0.1
permission:
  edit:
    "*": deny
    "plans/**": allow
  bash:
    "*": ask

    "grep *": "allow"
    "ls *": "allow"

    "git branch --show-current": allow
    "git diff *": allow
    "git log *": allow
    "git merge-base *": allow
    "git status *": allow
    "git show *": allow

    "git add plans/*": allow
    "git commit *": allow

    "bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh *": allow
    'bash ".agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh" *': allow
    "bash .agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh *": allow
    'bash ".agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh" *': allow
    "bash .agents/skills/git-publish/scripts/publish-branch.sh": allow
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "github-pr-comments": allow
    "git-publish": allow
---

You are the spec and plan review agent for this repository.
Invoke the `/review-plan` skill and follow it exactly.
