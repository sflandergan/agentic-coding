# git-publish — Design Rationale

## Why a script, not a raw `git push`

`git push origin $(git rev-parse --abbrev-ref HEAD)` does **not** protect `main`: while you are on `main` it expands to `git push origin main`, and permission globs cannot see through the command substitution to block it. The guard has to inspect the current branch at run time, which is what the `push-branch.sh` script does.

## Host detection

The script reads `git remote get-url origin` to determine the remote, then pushes to that remote. No hardcoded remote name is assumed.

## Branch and default-branch guards

- Refuses to push when the current branch is `main`, `master`, or a detached `HEAD`.
- Refuses any `--force`, `-f`, or `--force-with-lease` argument — force-pushing is out of scope for this skill.

## Why workflow-facing files should not call `git push` directly

Any workflow file that calls `git push` bypasses the branch guard. The protection only holds if publishing goes through this script. Workflow instructions should tell agents to use the `git-publish` skill by name rather than invoking `git push` directly.
