---
name: git-publish
description: Use when a workflow must publish the current non-protected branch to GitHub, ensure a PR exists, or force-update a retained PR head branch under a lease.
user-invocable: false
---

# Publish the Current Branch

Run:

```bash
bash .agents/skills/git-publish/scripts/publish-branch.sh
```

The script:

1. Detects the current branch.
2. Refuses detached HEAD and protected branches — `main`, `master`, and the resolved default branch (`origin/HEAD`, falling back to `main`).
3. Pushes the current branch to `origin` with upstream tracking.
4. Prints the existing PR URL when one already exists and leaves its readiness unchanged.
5. Otherwise creates a draft PR with `gh pr create --fill --draft` and prints its URL.

If publishing fails because the branch is behind, has diverged, or needs a rebase, stop and report the Git failure to the calling workflow. Rebasing, pulling, or conflict resolution belongs to the workflow agent, not this narrow publish helper.

# Publish to an Existing PR

When a workflow already owns an existing pull request and wants to force-update its retained head branch without an approval prompt, run:

```bash
bash .agents/skills/git-publish/scripts/publish-branch.sh \
  --existing-pr <number> \
  --expected-head <sha> \
  --head-branch <head-branch>
```

All three arguments are required together:

- `<number>` is a positive pull-request number.
- `<sha>` is the 40-character hexadecimal SHA that the remote head branch is expected to point at when publication starts.
- `<head-branch>` is the retained pull-request `headRefName`; it must pass Git branch-ref validation and must not be a protected branch.

The script:

1. Treats the explicit `<head-branch>` as the remote destination; the local branch name is irrelevant, so local `main` and detached `HEAD` are accepted in this mode.
2. Verifies the pull request exists, is open, and still reports `<head-branch>` as its head branch.
3. Pushes the tested local `HEAD` with the qualified lease `refs/heads/<head-branch>:<sha>` to the explicit refspec `HEAD:refs/heads/<head-branch>`.
4. Prints the existing pull-request URL.

This mode never creates or merges a pull request. If the lease is stale because the remote head moved, the push fails and the script stops; never retry with an unqualified force push or switch to a newly renamed head branch.

Do not run raw `git push` or raw `gh pr create` when this skill is available.
