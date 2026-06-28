---
name: issue-tracker
description: Use when creating, updating, or searching for issues — detects GitHub vs GitLab and delegates to the appropriate CLI
user-invocable: false
---

# Issue Tracker

Host-agnostic interface for issue management. Scripts detect whether the repository is hosted on GitHub or GitLab and delegate to the correct provider CLI (`gh` or `glab`).

## Create an issue

```bash
bash .agents/skills/issue-tracker/scripts/create-issue.sh --title TITLE --body-file PATH [--labels LABELS]
```

- Prints the created issue URL.

## Update an issue

```bash
bash .agents/skills/issue-tracker/scripts/update-issue.sh --issue NUMBER --body-file PATH
```

- Prints the issue URL.

## Find duplicate issues

```bash
bash .agents/skills/issue-tracker/scripts/find-duplicate-issues.sh --title TITLE [--labels LABELS]
```

- **Host detection**: reads `git remote get-url origin` to determine the host.
  - GitHub → `gh issue list --search ... --label ... --json number,title,url`
  - GitLab → `glab issue list --search ... --label ... --output json`
- Prints a compact list of candidate duplicate issues, or nothing if none found.
