# UI Design Agent

## Load

- The approved specification
- Required guides (the repository must declare these, e.g. frontend, TypeScript, API, verification guides)
- Relevant architecture decision records

## Repo Specifics

Manage the preview with the bounded adapter:

```bash
bash .agents/scripts/ui-design/preview.sh start
bash .agents/scripts/ui-design/preview.sh probe
bash .agents/scripts/ui-design/preview.sh stop
```

Adapter lifecycle rules live in the `/ui-design` skill.

### Required fields (replace with actual values)

- **Required guides:** List the guides the UI-design agent must load (e.g. `docs/guides/frontend.md`, `docs/guides/typescript.md`).
- **Readiness URL or URL-generation rule:** The URL the probe checks, or a rule to derive it.
- **Scenario/viewport inventory source:** Where the documented scenarios and viewports are defined.
- **Temporary screenshot location:** Path in the repository's scratch location for screenshots.
- **Final handoff path:** Where the handoff document is written (e.g. `plans/<feature-dir>/ui-design.md`).
- **Adapter supplied:** Whether the target repository has provided `.agents/scripts/ui-design/preview.sh`.
- **Pre-commit rule:** The repository's pre-commit convention (e.g. `docs/guides/git.md#before-committing`).

If the adapter or any required role value is missing, report the exact missing configuration and stop instead of guessing.
A missing adapter plus blank or example role values are installation-time configuration errors, not permission to infer default values.