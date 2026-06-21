# Coding Guidelines

## Naming

- Use clear, intention-revealing names that match the domain language in `docs/contexts/*/CONTEXT.md`.
- Avoid abbreviations unless the domain already uses them.
- Prefer full words over single letters except for well-known loop indices and stream/map parameters.

## Code Shape

- Keep functions small and focused on one responsibility.
- Prefer pure functions and immutable data where practical.
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