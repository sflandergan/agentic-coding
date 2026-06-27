---
name: gitlab-mr-comments
description: Use when GitLab merge request feedback lives in plain notes, inline diff discussions, or discussion threads
user-invocable: false
---

# GitLab MR Comments

Use this for team merge request review workflows where feedback is stored as GitLab notes and discussions. This is the GitLab equivalent of `github-pr-comments`.

## Baseline Failure To Avoid

Agents naturally mix the GitLab note surfaces: they may read a standalone conversation note when feedback is actually an unresolved inline diff discussion, post a new top-level note instead of replying inside the existing thread, or edit someone else's note instead of replying to it.

## Skill Scope

This skill owns MR note mechanics: fetching notes, discussions, and the diff; distinguishing standalone conversation notes from inline diff discussions; obtaining exact discussion IDs; and posting approved replies through project scripts.

This skill does not own role-level review orchestration. The calling review agent decides how to interpret notes, validate technical claims, combine them with other findings, suggest fixes, edit files, dispatch implementers, or perform final self-review.

## Read Notes

Use the bundled read-only helper before proposing fixes. It fetches standalone conversation notes, unresolved inline diff discussions, and the MR diff:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>]
```

When `<mr>` is omitted, the script auto-detects the MR internal ID (`iid`) from the current branch.

Run the command exactly as shown, without quoting the script path. The review agents have explicit auto-permissions for this command form.

The helper prints a compact summary first, then full MR metadata, the discussions JSON, and the MR diff. Use the summary for grouping and the full JSON sections for exact discussion IDs.

Optional read-only modes:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --comments-only
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --diff-only
bash .agents/skills/gitlab-mr-comments/scripts/fetch-mr-comments.sh [<mr>] --json
```

Do not call `glab` directly for reading MR metadata, notes, discussions, or diffs. The helper is the stable interface for this workflow.

## Classify Notes

- Standalone conversation notes: top-level MR discussion entries (`individual_note: true`), the GitLab analog of a plain comment.
- Inline diff discussions: resolvable threads whose notes carry a `diff position` (file path and line). Surface only those that are unresolved.
- Outdated inline discussions may still be valid; verify against the current diff before dismissing.

## Review Workflow

1. Fetch MR notes and diff when the caller's workflow involves an MR.
2. Use the summary to group target types, then use the full discussions JSON for exact discussion IDs.
3. Distinguish standalone conversation notes from inline diff discussions before posting replies.
4. Surface outdated inline discussions as context; the calling review agent decides whether they still apply.
5. For posting, require an exact approved reply batch with the discussion ID and body.
6. Post only the exact approved reply batch.

## Replies

Replying mutates GitLab state, so it is not hidden behind the read helper. Approval for edits, fixes, planning, or any other non-GitLab action does not authorize posting GitLab notes.

Before posting, present the exact reply batch to the user. Include the discussion ID and body. Wait for explicit approval for that batch.

After approval, reply inside the existing thread through the project script. Use the `id` of the discussion from the read helper as `discussion_id`:

Pass a JSON array as the final argument:

```bash
bash .agents/skills/gitlab-mr-comments/scripts/reply-to-mr-comment.sh [<mr>] '[
  { "discussion_id": "a1b2c3d4...", "body": "Fixed in abc123." },
  { "discussion_id": "e5f6g7h8...", "body": "Good catch, updated." }
]'
```

The MR number is optional; when omitted, the script auto-detects it from the current branch. Use a one-element array for a single reply. This script replies inside existing discussion threads; it does not open new standalone notes.

## Common Mistakes

- Treating standalone conversation notes as complete enough for inline diff review.
- Posting a new top-level note when the user asked to reply inside an inline thread.
- Resolving, editing, or deleting notes without explicit approval.
- Applying external feedback without checking whether it is technically correct.
- Treating approval for edits, fixes, planning, or other non-GitLab work as approval to post GitLab replies.
- Posting a reply batch that differs from the exact batch the user approved.
