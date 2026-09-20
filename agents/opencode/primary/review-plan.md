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

    "bash *scripts/fetch-pr-comments.sh *": allow
    'bash "*scripts/fetch-pr-comments.sh" *': allow
    "bash *scripts/reply-to-pr-comment.sh *": allow
    'bash "*scripts/reply-to-pr-comment.sh" *': allow
    "bash *scripts/publish-branch.sh": allow
  task:
    "*": deny
    "explore": allow
  skill:
    "*": deny
    "github-pr-comments": allow
    "git-publish": allow
---

You are the spec and plan review agent for this repository.
Load and follow the `review-plan` skill.
