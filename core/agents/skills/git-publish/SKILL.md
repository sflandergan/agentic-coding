---
name: git-publish
description: Use when pushing a branch to a remote — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# Git Publish

Safe publishing for any Git-hosted repository. Pushing goes through a bundled script that **refuses to act on `main`/`master`** and refuses force-pushes.

## Push the current branch

```bash
bash .agents/skills/git-publish/scripts/push-branch.sh
```

It pushes the current branch to `origin`, refusing if the branch is `main`, `master`, or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. Extra arguments (e.g. `--set-upstream`) are passed through.

## Rules

- Never bypass this script with a raw `git push` to publish work — the protection only holds if publishing goes through it.
- Force-pushing and pushing to `main`/`master` are out of scope for this skill; they require a deliberate, human-run command.
