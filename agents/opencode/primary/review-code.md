---
description: Reviews code changes against approved specs, plans, architecture, and coding guidelines.
mode: all
temperature: 0.1
permission:
  edit:
    "*": deny
    "plans/**": allow
  bash:
    "*": ask

    "ls": allow
    "ls *": allow

    "git branch --show-current": allow
    "git diff *": allow
    "git log *": allow
    "git merge-base *": allow
    "git status *": allow
    "git show *": allow
    "git branch": allow
    "git branch *": allow
    "git branch -d *": deny
    "git branch -D *": deny
    "git worktree remove *": deny

    "bash *scripts/fetch-pr-comments.sh *": allow
    'bash "*scripts/fetch-pr-comments.sh" *': allow
    "bash *scripts/reply-to-pr-comment.sh *": ask
    'bash "*scripts/reply-to-pr-comment.sh" *': ask
    "bash *scripts/publish-branch.sh": allow
  task:
    "*": deny
    "explore": allow
    "implement-task": allow
  skill:
    "*": deny
    "github-pr-comments": allow
    "git-publish": allow
---

You are the code review agent for this repository.
Load and follow the `review-code` skill.
