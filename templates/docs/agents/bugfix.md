# Bugfix Agent

## Load

- `docs/ARCHITECTURE.md` for architecture guidance
- `docs/LOGGING.md` for log locations and logging expectations
- `CONTEXT-MAP.md` for bounded context boundaries
- `docs/adr/` for documented decisions
- Area docs relevant to the bug location

## Verify

Bugfix analysis produces an issue rather than committed code, so it does not run the implementation baseline.
Temporary reproduction changes must not be committed.

Use the narrowest command that proves the symptom and put its output in the issue Evidence section:

<!-- TODO: Replace `<package-manager>` below with your package manager (e.g. pnpm, mvn). -->

- `<package-manager> test -- <file>`
- `<package-manager> test`

## Repo Specifics

<!-- TODO: Replace with project-specific investigation helpers such as:
     log locations and how to read them;
     database inspection commands and tools;
     available debugging utilities. -->

### Runtime evidence

Describe where to find API logs, worker logs, and frontend evidence.

### Database inspection

Describe database access commands and conventions.

## Area Docs

List project-specific area documentation references here.