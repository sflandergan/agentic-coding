# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Term One**:
A one or two sentence description of the term.
_Avoid_: synonym one, synonym two

**Term Two**:
A one or two sentence description of the term.
_Avoid_: synonym, near-synonym

**Term Three**:
A one or two sentence description of the term.
_Avoid_: broader term, narrower term
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one
  and list the others under `_Avoid_`.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it
  does.
- **Only include terms specific to this project's context.** General programming concepts
  (timeouts, error types, utility patterns) don't belong even if the project uses them
  extensively. Before adding a term, ask: is this a concept unique to this context, or a
  general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to
  a single cohesive area, a flat list is fine.

## This repo: multi-context, centralized glossaries

`CONTEXT-MAP.md` lists the contexts, points to where each glossary lives, and describes
how they relate:

```md
# Context Map

## Contexts

- [Context A](./docs/contexts/context-a/CONTEXT.md) — short purpose statement
- [Context B](./docs/contexts/context-b/CONTEXT.md) — short purpose statement
- [Context C](./docs/contexts/context-c/CONTEXT.md) — short purpose statement

## Relationships

- **Context A → Context B**: short description of how A's outputs feed B.
- **Context C → Context B**: short description of how C's outputs feed B.
```

Glossaries are centralized under `docs/contexts/<context>/CONTEXT.md` — never
co-located with source. Read `CONTEXT-MAP.md` to find the relevant context, then open
its glossary. If it is unclear which context a topic belongs to, ask.
