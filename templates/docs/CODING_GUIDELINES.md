# Coding Guidelines

## Naming

- Use clear, intention-revealing names that match the domain language in `docs/contexts/*/CONTEXT.md`.
- Name domain concepts only with terms the relevant `docs/contexts/<context>/CONTEXT.md` glossary defines (find the context through `CONTEXT-MAP.md`), honoring its prohibited-alternatives (_Avoid_) list.
- Name technical mechanics by their observable effect in the platform's own vocabulary (DOM, HTTP, SQL, or the language and framework in use), for example `focusHeading` rather than `focusAfterAuthoritativeTransition`.
- When a name needs a domain concept the glossary does not define, do not coin one; raise the term through your workflow role (planner, implement worker, or reviewer).
- Avoid abbreviations unless the domain already uses them.
- Prefer full words over single letters except for well-known loop indices and stream/map parameters.

## Code Shape

- Keep units of behavior small and focused on one responsibility. The exact form depends on the language (functions, methods, procedures, classes, modules), but the principle is the same: each unit does one thing.
- Prefer pure units of behavior and immutable data structures where practical.
- Keep files focused; split when a file grows past a single responsibility.
- Make the smallest correct change; do not refactor unrelated code in the same change.

## Comments

- Comment on behavior and constraints, not on ecosystem analogies or obvious mechanics.
- Keep comments up to date; remove stale comments when you change the code they describe.
- Use doc comments for public APIs; explain the contract, not the implementation.

## Smallest Correct Change

- Prefer the smallest correct change over broad refactors.
- Do not rewrite code outside the scope of the current task.
- Do not revert, overwrite, or clean up changes you did not make.
