# Record architecture decisions

## Status

Accepted

## Context and Problem Statement

Architecture decisions are currently implicit and scattered across conversations, PRs, and code comments. This makes it hard for new contributors to understand why the system is designed the way it is, and hard for existing contributors to recall the rationale behind past choices.

We need a lightweight, version-controlled way to record significant architectural decisions so they are discoverable, reviewable, and durable.

## Decision Drivers

- Decisions must be discoverable by anyone reading the repository.
- The format must be lightweight enough to write in minutes, not hours.
- Decisions must be version-controlled and reviewed like code.
- The format should be widely recognized or easily adopted by contributors familiar with industry standards.

## Considered Options

- ADR (Architecture Decision Record) in Markdown
- Wiki pages
- Inline code comments
- Decision sections in README files

## Decision Outcome

Chosen option: **ADR in Markdown** using the [MADR](https://adr.github.io/madr/) 4.0 structure, stored in `docs/adr/`.

- Each decision gets a numbered file: `docs/adr/NNNN-title-with-dashes.md`.
- The title is a short imperative verb phrase describing the decision.
- The status field tracks the decision lifecycle: proposed → accepted → rejected/deprecated/superseded.
- An ADR template is provided at `docs/adr/ADR-TEMPLATE.md`.

### Pros

- Discoverable: all decisions live in one directory with consistent naming.
- Durable: version-controlled and reviewable like any other change.
- Lightweight: Markdown files, no special tooling required.
- Standardized: MADR is a recognized format with broad adoption.

### Cons

- Overhead: requires discipline to write a record for every significant decision.
- Maintenance: superseded decisions must not be deleted; they are superseded by reference.
- Discoverability gap: contributors must know to check `docs/adr/`.

## Links

- [MADR project](https://adr.github.io/madr/)
- ADR template: `docs/adr/ADR-TEMPLATE.md`