# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.

## This repo: multi-context, centralized glossaries

This repo is multi-context. `CONTEXT-MAP.md` at the repo root lists the contexts, points to where each glossary lives, and describes how they relate:

```md
# Context Map

## Contexts

- [Catalog](./docs/contexts/catalog/CONTEXT.md) — the canonical bike database
- [Dealer Network](./docs/contexts/dealer-network/CONTEXT.md) — dealers, locations, manufacturer associations
- [Dealer Inventory](./docs/contexts/dealer-inventory/CONTEXT.md) — confirmed dealer offers
- [Crawling](./docs/contexts/crawling/CONTEXT.md) — the ingestion machinery

## Relationships

- **Crawling → Catalog**: manufacturer-site crawling discovers bikes and writes them via the internal API
- **Crawling → Dealer Inventory**: dealer-site crawling produces candidates that become Offers once matched and confirmed
```

Glossaries are centralized under `docs/contexts/<context>/CONTEXT.md` — never co-located with source. Read `CONTEXT-MAP.md` to find the relevant context, then open its glossary. If it is unclear which context a topic belongs to, ask.
