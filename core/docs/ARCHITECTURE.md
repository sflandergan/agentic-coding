# Architecture

## System Overview

Describe the system at a high level: what it does, who uses it, and how it is deployed. Keep this section short and stable.

## Module Structure

Describe the top-level packages, services, or apps. List each module with a one-line purpose and link to its deeper docs.

## Area-Specific Documentation

| Area | Doc |
|---|---|
| Architecture overview | `docs/ARCHITECTURE.md` |
| Coding rules | `docs/CODING_GUIDELINES.md` |
| Testing rules | `docs/TESTING.md` |
| Logging rules | `docs/LOGGING.md` |
| Bounded contexts | `CONTEXT-MAP.md` |
| Context glossary | `docs/contexts/<context>/CONTEXT.md` |
| Decisions | `docs/adr/` |
| Features | `docs/features/` |

## Adding a New Area

1. Add a doc under `docs/` describing the area's purpose and rules.
2. Add a row to the table above.
3. Reference the new doc from the relevant `docs/agents/<role>.md` loading contract.