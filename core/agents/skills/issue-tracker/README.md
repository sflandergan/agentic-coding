# issue-tracker — Design Rationale

## Why a host-agnostic issue tracker wrapper exists

GitHub and GitLab have different CLI tools (`gh` and `glab`) and slightly different flags for issue operations. A host-agnostic skill lets agents create, update, and search for issues without needing to know which provider hosts the repository.

## Host detection

All scripts read `git remote get-url origin` to determine the host:

- GitHub → delegates to `gh issue ...` commands.
- GitLab → delegates to `glab issue ...` commands.

## Provider differences abstracted by the scripts

| Operation | GitHub (`gh`) | GitLab (`glab`) |
|---|---|---|
| Create issue | `gh issue create --title ... --body-file ... --label ...` | `glab issue create --title ... --description ... --label ...` |
| Update issue | `gh issue edit <number> --body-file ...` | `glab issue update <number> --description ...` |
| Search issues | `gh issue list --search ... --label ... --json ...` | `glab issue list --search ... --label ... --output json` |

## Why provider CLIs should not be called directly from workflow files

Calling `gh` or `glab` directly from workflow files couples those files to a specific provider. The issue-tracker skill handles host detection and flag translation, so workflow instructions should tell agents to use the `issue-tracker` skill by name.
