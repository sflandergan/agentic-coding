# Implement Agent

## Load

- Approved plan
- Approved spec, if present
- `docs/CODING_GUIDELINES.md` for coding rules
- `docs/TESTING.md` for verification rules
- Docs explicitly named by the plan

## Verify

```bash
# Replace with project-specific commands:
# <package-manager> lint
# <package-manager> typecheck
# <package-manager> test
# <package-manager> build
```

## Repo Specifics

- Name the repository's changed-code audit document and the enumerations it requires; the controller and workers apply it.

## UI Integration

Used only when the approved spec's `## UI Design` marker is `ui-design: required`.

<!-- TODO: Replace with repository-specific UI integration configuration:
     startup commands and readiness URLs;
     deterministic local data setup and teardown;
     prohibited endpoints, credentials, or data. -->

<!-- TODO: Replace with repository-specific implementation configuration, such as:
     directories the worker may write to during implementation. -->