# UI Design Task Agent

## Load

- Required guides (the repository must declare these, e.g. frontend guide, TypeScript guide)
- The complete self-contained presentation task packet

## Repo Specifics

The worker may edit only presentation paths explicitly owned by its packet within the permitted presentation roots declared by the target repository.

The target repository must define its concrete presentation-root allowlist here (e.g. `src/components/**`, `src/layouts/**`, `src/pages/**`, `src/styles/**`, `src/messages/**`, `preview/**`, `public/**`).

It must not edit API clients, persistence, business logic, production integrations, tests, scripts, manifests, build configuration, or other paths.
It does not run correctness verification, commit, or dispatch subagents.

A missing adapter plus blank or example role values are installation-time configuration errors, not permission to infer default values.