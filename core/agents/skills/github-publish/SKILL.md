---
name: github-publish
description: Use when pushing a branch or opening a pull request — guards against pushing to the default branch and against force-pushing
user-invocable: false
---

# GitHub Publish

Safe publishing for GitHub-hosted repositories. Pushing and opening pull requests go through bundled scripts that **refuse to act on `main`** and refuse force-pushes.

## Why a script, not a raw `git push`

`git push origin $(git rev-parse --abbrev-ref HEAD)` does **not** protect `main`: while you are on `main` it expands to `git push origin main`, and permission globs cannot see through the command substitution to block it. The guard has to inspect the current branch at run time, which is what these scripts do.

## Push the current branch

```bash
bash .agents/skills/github-publish/scripts/push-branch.sh
```

It pushes the current branch to `origin`, refusing if the branch is `main` or a detached `HEAD`, and refusing any `--force` / `-f` / `--force-with-lease` argument. Extra arguments (e.g. `--set-upstream`) are passed through.

## Open a pull request

```bash
bash .agents/skills/github-publish/scripts/open-pr.sh [gh pr create flags]
```

It refuses on `main`, skips creation when a PR already exists for the current branch (printing the existing one), and otherwise runs `gh pr create` for the current branch. Pass `--fill` to derive the title/description from commits, or `--title`/`--description` explicitly.

## Rules

- Never bypass these scripts with a raw `git push` to publish work — the protection only holds if publishing goes through them.
- Force-pushing and pushing to `main` are out of scope for this skill; they require a deliberate, human-run command.
