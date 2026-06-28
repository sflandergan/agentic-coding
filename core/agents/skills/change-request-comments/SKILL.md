---
name: change-request-comments
description: Use when reading or replying to pull request or merge request comments — detects GitHub vs GitLab and delegates to provider-specific skills
user-invocable: false
---

# Change Request Comments

Host-agnostic interface for reading and replying to change-request (PR/MR) comments. The script detects whether the repository is on GitHub or GitLab and delegates to the corresponding provider-specific skill.

## Fetch comments

```bash
bash .agents/skills/change-request-comments/scripts/fetch-comments.sh [<number>] [--comments-only|--diff-only|--json]
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub → delegates to `.agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh`
  - GitLab → delegates to `.agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh`
- Arguments and exit code are preserved.

## Reply to a comment

```bash
bash .agents/skills/change-request-comments/scripts/reply-to-comment.sh [<number>] '<replies-json>'
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub → delegates to `.agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh`
  - GitLab → delegates to `.agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh`
- Arguments and exit code are preserved.
