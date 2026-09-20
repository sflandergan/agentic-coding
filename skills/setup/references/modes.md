# Setup modes

Determine the mode before proposing changes. A state file is authoritative only
when it is valid enough to identify a managed installation; malformed state is
a repair finding, not permission to treat the repository as fresh. After
classification, use [discovery.md](discovery.md) for inspection findings and
the routed workflow below for operations.

| Evidence | Mode | Required decision path |
| --- | --- | --- |
| `.agentic-coding.json` is present and identifies a supported installation | Managed | Check for a newer release first, then offer upgrade. Continue with repair or reconfiguration even when upgrade is declined. |
| No state file, but recognizable toolkit skills, agents, role documents, or configuration are present | Legacy adoption | Follow [legacy adoption](legacy-adoption.md) to classify candidates, approve mappings, and continue with missing installation operations. |
| Neither a usable state file nor recognizable toolkit content is present | Fresh setup | Discover the repository and propose a complete, scoped installation. |

## Managed installations

Use [upgrade.md](upgrade.md). An upgrade decline is not a repair or
configuration decline; the user may still request either of those operations.

## Legacy adoption

Recognizable names include toolkit workflow skills such as `brainstorm`,
`bugfix`, `finish`, `idea`, `implement`, `planner`, `review-code`,
`review-plan`, and `ui-design`; other authored skills such as
`feature-documentation`, `git-publish`, `github-pr-comments`,
`grill-with-docs`, `implement-task`, `planning-structure`, `setup`,
`ui-design-task`, and `verification-before-completion`; role documents under
`docs/agents/`; `AGENTS.md` or `CLAUDE.md`; harness configuration such as
`opencode.json`, `settings.json`, or `config.toml`; and toolkit lockfiles or
plugin manifests. The list is a detection aid, not proof of ownership.

Use [legacy-adoption.md](legacy-adoption.md) for candidate classification and
approval. Use [conflicts.md](conflicts.md) for the permitted outcomes.

## Fresh setup

Use [installation.md](installation.md). Treat all content as project-owned
until inspection and approval establish otherwise. A fresh setup may start
from a dirty tree only after the user sees and approves the existing changes.

## Classification outcomes

Use **upgrade** when an approved newer release will be reconciled, **repair**
when an existing managed asset is missing or inconsistent, and
**reconfiguration** when scope, harnesses, distribution, model guidance, or
role documentation changes. A run can combine an upgrade with repair or
reconfiguration, but each approved change must remain identifiable in the
final report.

The routed workflows own release fetching, conflict decisions, application,
state writing, and verification.
