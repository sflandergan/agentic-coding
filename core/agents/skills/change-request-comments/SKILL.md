---
name: change-request-comments
description: Use when reading or replying to pull request or merge request comments — detects GitHub vs GitLab and handles both inline
user-invocable: false
---

# Change Request Comments

Host-agnostic interface for reading and replying to change-request (PR/MR) comments. The scripts detect whether the repository is on GitHub or GitLab and handle both providers directly.

## Fetch comments

```bash
bash .agents/skills/change-request-comments/scripts/fetch-comments.sh [<number>] [--comments-only|--diff-only|--json]
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub: uses `gh` CLI and GraphQL to fetch issue comments, inline review threads, and PR diff.
  - GitLab: uses `glab` CLI to fetch discussions and MR diff.
- When `<number>` is omitted, the script auto-detects the PR/MR number from the current branch.

Optional modes:

- `--comments-only` — print comment metadata only, omit the diff.
- `--diff-only` — print the diff only, omit comments.
- `--json` — output a single JSON object with all data (PR/MR metadata, comments, discussions).

## Reply to a comment

```bash
bash .agents/skills/change-request-comments/scripts/reply-to-comment.sh [<number>] '<replies-json>'
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub: posts replies to inline PR review comments via `gh api`. Reply JSON uses `comment_id` (number).
  - GitLab: posts replies inside existing discussion threads via `glab mr note create`. Reply JSON uses `discussion_id` (string).
- The PR/MR number is optional; when omitted, the script auto-detects it from the current branch.

Reply payload format:

```bash
# GitHub
bash .agents/skills/change-request-comments/scripts/reply-to-comment.sh '<number>' '[
  { "comment_id": 123456, "body": "Fixed in abc123." },
  { "comment_id": 789012, "body": "Good catch, updated." }
]'

# GitLab
bash .agents/skills/change-request-comments/scripts/reply-to-comment.sh '<number>' '[
  { "discussion_id": "a1b2c3d4...", "body": "Fixed in abc123." },
  { "discussion_id": "e5f6g7h8...", "body": "Good catch, updated." }
]'
```
