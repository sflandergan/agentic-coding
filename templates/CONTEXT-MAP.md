# Context Map

This repository is organized into bounded contexts that each own a slice of the domain and a small set of ubiquitous-language terms. Use this map to find the right context before making cross-cutting changes.

## How to Use This Map

- Each context has its own glossary under `docs/contexts/<context>/CONTEXT.md`.
- A new context requires an entry here and a corresponding `CONTEXT.md` glossary.
- Cross-context relationships follow the patterns below; document the pattern in the relevant `CONTEXT.md`.

## Relationship Patterns

- **Customer/Supplier (C/S):** one context consumes the output of another.
- **Conformist (CF):** one context adopts another's model without translation.
- **Anti-Corruption Layer (ACL):** one context translates or shields itself from another.
- **Shared Kernel (SK):** two contexts share a small, jointly owned model.
- **Open-Host Service (OHS):** one context exposes a public protocol for others to consume.

## Contexts

| Context | Purpose | Upstream | Downstream | Relationship |
|---|---|---|---|---|
| `placeholder` | Example context for new projects | — | — | — |

## Architectural Decisions

See `docs/adr/` for recorded decisions that affect context boundaries and integration patterns.