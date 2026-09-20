---
name: setup
description: Reconciles fresh installations, legacy adoption, upgrades, repairs, and reconfiguration of the agentic coding toolkit in an existing Git repository.
user-invocable: true
---

# Setup

The toolkit remote is `https://github.com/sflandergan/agentic-coding-next`. It
is the toolkit's source repository, not the target repository's own Git
remote. Every reference command uses this shell variable for it:

```bash
toolkit_remote='https://github.com/sflandergan/agentic-coding-next'
```

Start with [repository discovery](references/discovery.md), then use
[the mode table](references/modes.md) to classify the run. Use
[bootstrap](references/bootstrap.md) only when installing this skill, and use
[release handling](references/release.md) to resolve and fetch an exact
release.

## Workflow routing

- For **fresh setup** or **legacy adoption**, follow
  [the first-installation workflow](references/installation.md). Legacy
  candidates use [legacy adoption](references/legacy-adoption.md) before the
  missing installation operations.
- For a **managed upgrade**, **repair**, or **reconfiguration**, follow
  [the upgrade workflow](references/upgrade.md).

## Reference index

- [Bootstrap](references/bootstrap.md)
- [Discovery](references/discovery.md)
- [Installation](references/installation.md)
- [Legacy adoption](references/legacy-adoption.md)
- [Modes](references/modes.md)
- [Release handling](references/release.md)
- [Upgrade, repair, and reconfiguration](references/upgrade.md)
- [Conflict policies](references/conflicts.md)
- [Release manifest schema](references/manifest-schema.md)
- [State file](references/state-file.md)
