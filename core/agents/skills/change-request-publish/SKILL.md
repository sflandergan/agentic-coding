---
name: change-request-publish
description: Use when opening a pull request or merge request — detects GitHub vs GitLab and delegates to the appropriate CLI
user-invocable: false
---

# Change Request Publish

Safe publishing for any Git-hosted repository. Opening a change request (pull request or merge request) goes through a bundled script that **detects the host** from the remote URL and delegates to the appropriate CLI.

## Why a script, not a raw `gh pr create` or `glab mr create`

The script inspects the current branch, checks whether a change request already exists, and then delegates to the correct provider CLI. This means workflow-facing files never need to know whether the repository is hosted on GitHub or GitLab.

## Open a change request

```bash
bash .agents/skills/change-request-publish/scripts/open-change-request.sh [--title TITLE --description DESCRIPTION]
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub (`github.com` or `git@github.com:`) → opens a pull request with `gh pr create`.
  - Otherwise (GitLab) → opens a merge request with `glab mr create` (GitLab is commonly self-hosted).
- **Branch guard**: refuses on `main`, `master`, or detached `HEAD`.
- **Idempotent**: skips creation when a change request already exists for the current branch, printing the existing one and exiting 0.
- **Pass-through**: all extra arguments are forwarded to the provider CLI.
- **Output**: prints the created change-request URL.

## Rules

- Force-pushing and pushing to `main`/`master` are out of scope for this skill; they require a deliberate, human-run command.
