---
name: github-pr-comments
description: Use when GitHub PR feedback lives in plain comments, inline comments, issue comments, or review threads
user-invocable: false
---

# GitHub PR Comments

Use this for solo-maintainer PR review workflows where feedback is stored as plain GitHub comments rather than formal review submissions.

## Baseline Failure To Avoid

Agents naturally mix comment APIs: they may read reviews when feedback is actually an issue comment, post a top-level reply instead of an inline thread reply, or patch someone else's comment instead of posting a reply.

## Skill Scope

This skill owns PR comment mechanics: fetching comments and diffs, distinguishing issue comments from inline review comments, obtaining exact target IDs, and posting approved replies through project scripts.

This skill does not own role-level review orchestration. The calling review agent decides how to interpret comments, validate technical claims, combine them with other findings, suggest fixes, edit files, dispatch implementers, or perform final self-review.

## Read Comments

Use the bundled read-only helper before proposing fixes. It fetches top-level issue comments, unresolved inline review threads, and the PR diff:

```bash
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>]
```

When `<pr>` is omitted, the script auto-detects the PR number from the current branch.

Run the command exactly as shown, without quoting the script path. The review-code agent has explicit auto-permissions for this command form.

The helper prints a compact comment summary first, then full PR metadata, issue comments, inline comments, and the PR diff. Use the summary for grouping and the full JSON sections for exact `databaseId` values.

Optional read-only modes:

```bash
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>] --comments-only
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>] --diff-only
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>] --json
```

Do not call the GitHub CLI directly for reading PR metadata, issue comments, inline comments, or diffs. The helper is the stable interface for this workflow.

## Classify Comments

- Issue comments: top-level PR conversation, fetched from `issues/<pr>/comments`.
- Inline PR comments: unresolved diff review-thread comments, fetched through GitHub GraphQL `reviewThreads`.
- Outdated inline comments may still be valid; verify against current diff before dismissing.

## Review Workflow

1. Fetch PR comments and diff when the caller's workflow involves a PR.
2. Use the summary to group target types, then use the full JSON sections for exact `databaseId` values.
3. Distinguish top-level issue comments from inline review comments before posting replies.
4. Surface outdated inline comments as comment metadata/context; the calling review agent decides whether they still apply.
5. For posting, require an exact approved reply batch with target type, target ID when available, and body.
6. Post only the exact approved reply batch.

## Replies

Replying mutates GitHub state, so it is not hidden behind the read helper. Approval for edits, fixes, planning, or any other non-GitHub action does not authorize posting GitHub comments.

Before posting, present the exact reply batch to the user. Include the target type (`issue comment` or `inline review comment`), target ID when available, and body. Wait for explicit approval for that batch.

After approval, post inline review replies through the project script. Use the numeric `databaseId` from the read helper as `comment_id`:

Pass a JSON array as the final argument:

```bash
bash .agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh [<pr>] '[
  { "comment_id": 123456, "body": "Fixed in abc123." },
  { "comment_id": 789012, "body": "Good catch, updated." }
]'
```

The PR number is optional; when omitted, the script auto-detects it from the current branch. Use a one-element array for a single reply. This script replies to inline PR review comments only; it does not reply to top-level issue comments.

## Common Mistakes

- Treating top-level PR comments as complete enough for inline review.
- Posting a top-level PR comment when the user asked to reply to an inline thread.
- Resolving, editing, or deleting comments without explicit approval.
- Applying external feedback without checking whether it is technically correct.
- Treating approval for edits, fixes, planning, or other non-GitHub work as approval to post GitHub replies.
- Posting a reply batch that differs from the exact batch the user approved.
