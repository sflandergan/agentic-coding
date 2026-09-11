---
name: github-pr-comments
description: Use when GitHub PR feedback lives in plain comments, inline comments, issue comments, or review threads
user-invocable: false
---

# GitHub PR Comments

Use this for solo-maintainer PR review workflows where feedback is stored as plain GitHub comments rather than formal review submissions.

## Skill Scope

This skill owns PR comment mechanics: fetching comments, distinguishing conversation comments from inline review threads, obtaining exact reply targets, and posting approved replies through project scripts.

This skill does not own role-level review orchestration.
The calling review agent decides how to interpret comments, validate technical claims, combine them with other findings, suggest fixes, edit files, dispatch implementers, or perform final self-review.

## Read Comments

Run the bundled read-only helper before proposing fixes.
It fetches top-level conversation comments and unresolved inline review threads:

```bash
bash .agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh [<pr>]
```

When `<pr>` is omitted, the script auto-detects the PR number from the current branch.

Run the command exactly as shown, without quoting the script path.

The default output is one filtered view: a three-line header, then every conversation comment with its full body, then every unresolved inline thread with a `path:line` anchor and the full body of each note in the thread.
Each thread header line carries the `thread_id` that the reply script expects, so identifying a reply target needs no second call and no raw JSON.

The default view does **not** include the diff.
Read the referenced code through the printed `path:line` anchors against the local checkout, with `git diff` and `git show`.
An anchor marked `(outdated)` is the thread's original diff location, not a line in the current checkout.
Locate the referenced logic by path and comment context.
When it is absent from the current file, inspect that file's history with `git log -- <path>` and `git show <revision>:<path>`.

Optional read-only modes:

- `--all` — additionally include resolved inline threads, each marked `[resolved]` on its header line.
- `--diff-only` — print the PR diff, for when the PR branch is not checked out locally.
- `--json` — the unfiltered `{ pr, conversationComments, threads }` payload.
  This is a last resort, for when the filtered view drops a field you need or when you are debugging the helper itself.
  Use the default view for normal review work.

Project automation expects `origin` to name the base repository.
Set `GH_REPO=owner/name` to name the base repository when running from a fork clone or when the repository cannot be derived from `origin`.

Do not call the GitHub CLI directly for reading PR metadata, conversation comments, inline threads, or diffs.
The helper is the stable interface for this workflow.

## Classify Comments

- Conversation comments are the top-level PR discussion.
- Inline threads are diff review threads, grouped with their replies.
  The default view shows unresolved threads only; `--all` adds the resolved ones.
- Outdated inline threads may still be valid.
  Verify one against the current code before dismissing it.

## Replies

Replying mutates GitHub state, so it is not hidden behind the read helper.
Approval for edits, fixes, planning, or any other non-GitHub action does not authorize posting GitHub comments.

Before posting an inline reply, present the exact reply batch to the user.
Include the target type (`inline thread`), the `thread_id`, and the body.
Wait for explicit approval for that batch.

After approval, post inline replies through the project script, using a `thread_id` printed by the read helper:

```bash
bash .agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh [<pr>] '[
  { "thread_id": 123456, "body": "Fixed in abc123." },
  { "thread_id": 789012, "body": "Good catch, updated." }
]'
```

The PR number is optional; when omitted, the script auto-detects it from the current branch.
Use a one-element array for a single reply.
The script prints posting status and suppresses the created-comment API response JSON.

This script replies inside existing inline threads only.
Conversation comments have no `thread_id`, and this script neither replies to nor opens them.

Post only the exact approved reply batch; never resolve, edit, or delete comments without explicit approval, and never treat top-level conversation comments as reply targets.