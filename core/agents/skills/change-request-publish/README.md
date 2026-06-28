# change-request-publish — Design Rationale

## Why a script, not a raw `gh pr create` or `glab mr create`

The `open-change-request.sh` script inspects the current branch, checks whether a change request already exists, and then delegates to the correct provider CLI (`gh` for GitHub, `glab` for GitLab). This means workflow-facing files never need to know whether the repository is hosted on GitHub or GitLab.

## Host detection

The script reads `git remote get-url origin` to determine the host:

- `github.com` or `git@github.com:` → opens a pull request with `gh pr create`.
- Otherwise (commonly GitLab, including self-hosted instances) → opens a merge request with `glab mr create`.

## Branch guard

Refuses to open a change request when the current branch is `main`, `master`, or a detached `HEAD`.

## Idempotency

If a change request already exists for the current branch, the script prints the existing one and exits 0 instead of creating a duplicate.

## Provider differences

- GitHub pull requests use `gh pr create` with `--title` and `--body`.
- GitLab merge requests use `glab mr create` with `--title` and `--description`.
- The script abstracts these differences so callers use a single interface.

## Why workflow files should not call provider CLIs directly

Any workflow file that calls `gh pr create` or `glab mr create` directly bypasses the host detection, branch guard, and idempotency checks. Workflow instructions should tell agents to use the `change-request-publish` skill by name rather than invoking provider CLIs directly.
