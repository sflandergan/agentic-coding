# change-request-comments — Design Rationale

## Why a host-agnostic comment skill exists

Pull request and merge request comments have different APIs, data models, and CLI tools on GitHub (`gh`) and GitLab (`glab`). A host-agnostic skill lets agents read and reply to change-request comments without needing to know which provider hosts the repository.

## Host detection

The scripts read `git remote get-url origin` to determine the host:

- GitHub → uses `gh` CLI and GraphQL to fetch issue comments, inline review threads, and PR diff.
- GitLab → uses `glab` CLI to fetch discussions and MR diff.

The PR/MR number can be auto-detected from the current branch when omitted.

## Provider-specific reply formats

The reply payload format differs between providers:

- GitHub replies target `comment_id` (a numeric ID) and are posted via `gh api`.
- GitLab replies target `discussion_id` (a string ID) and are posted inside existing discussion threads via `glab mr note create`.

The `reply-to-comment.sh` script abstracts these differences behind a unified JSON interface.

## Why provider-specific CLIs should not be called directly from workflow files

Calling `gh` or `glab` directly from workflow files couples those files to a specific provider. The comment skill handles host detection and format translation, so workflow instructions should tell agents to use the `change-request-comments` skill by name.
