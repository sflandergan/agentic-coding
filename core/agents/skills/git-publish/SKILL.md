---
name: git-publish
description: Use when pushing a branch to a remote — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# Git Publish

Safe publishing for any Git-hosted repository. Pushing goes through a bundled script that **refuses to act on `main`/`master`** and refuses force-pushes.

## Why a script, not a raw `git push`

`git push origin $(git rev-parse --abbrev-ref HEAD)` does **not** protect `main`: while you are on `main` it expands to `git push origin main`, and permission globs cannot see through the command substitution to block it. The guard has to inspect the current branch at run time, which is what this script does.

## Push the current branch

```bash
bash .agents/skills/git-publish/scripts/push-branch.sh
```

It pushes the current branch to `origin`, refusing if the branch is `main`, `master`, or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. Extra arguments (e.g. `--set-upstream`) are passed through.

## Rules

- Never bypass this script with a raw `git push` to publish work — the protection only holds if publishing goes through it.
- Force-pushing and pushing to `main`/`master` are out of scope for this skill; they require a deliberate, human-run command.
