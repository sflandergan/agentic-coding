---
name: feature-documentation
description: Use when writing or updating durable feature reference documentation under docs/features
user-invocable: false
---

# Feature Documentation

## Overview

Write durable feature reference documentation for engineers and product readers. A feature doc explains what exists, how it behaves, where it lives, and which boundaries matter. It is not a status report, implementation diary, PR summary, or verification log.

Use this skill whenever creating or updating `docs/features/*.md`.

## Required Style

- Write in present tense: describe current behavior.
- Prefer concrete names: routes, job names, table names, config variables, modules, and file paths.
- Explain ownership boundaries, especially API-vs-crawler-vs-database responsibilities.
- Include only sections that apply to the feature.
- Keep implementation history out of the doc unless it explains a durable design decision.

Do not include:

- implementation status such as "implemented", "ready", or "reviewed"
- dates, commit hashes, branch names, PR numbers, or cleanup notes
- verification logs or lists of test commands
- plan/spec file inventories
- agent handoff language

## Document Shape

Use this sample as the default shape. Rename, omit, or add sections only when the feature needs it.

```markdown
# <Feature Name> Feature

Briefly describe what this feature adds in durable product/engineering terms. Write this as reference documentation, not as an implementation status report.

## Scope

- User-visible or system capability 1.
- User-visible or system capability 2.
- Important boundary or non-goal if useful.

## APIs

Describe public/internal APIs if the feature adds or changes any.

### Public API

All `/api/**` routes are unauthenticated and intended for browser or frontend consumption.

| Method | Route | Purpose |
|---|---|---|
| `GET` | `/api/example` | Describe what the route returns and why it exists. |

### Internal APIs

All `/internal/**` routes are protected by internal machine authentication.

- `METHOD /internal/example` — purpose and important behavior.

## Jobs / Workflows

Describe jobs, scripts, or operational flows.

- `job-name`
  - What it does.
  - What state it reads/writes.
  - Important scheduling, retry, or idempotency behavior.

## Database State

Describe important tables, fields, uniqueness, and ownership boundaries.

- `table_name`
  - Purpose.
  - Important keys or lifecycle fields.

## Configuration

- `ENV_VAR` — purpose and default if relevant.

## Main Code Locations

- Area: `path/to/file.ts`, `path/to/directory`
```

## Writing Workflow

1. Read the relevant plan/spec files to understand the feature scope.
2. Identify the durable concepts users will need later: APIs, jobs, database state, configuration, workflows, code locations, and operational behavior.
3. Draft the feature doc using the sample shape above.
4. Remove transient implementation details.
5. Check that every section answers "what exists and how should I understand/use it?"

## Quality Checklist

Before handing off, verify the document:

- starts with a one-paragraph feature description
- has a `## Scope` section
- includes API/job/database/configuration sections only when relevant
- includes `## Main Code Locations`
- avoids status-report language
- avoids commit hashes, dates, branch names, and verification logs
- is understandable without opening the original plan files
