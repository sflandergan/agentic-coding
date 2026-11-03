# Planner Agent

## Load

- Approved spec file
- `docs/ARCHITECTURE.md` for architecture guidance
- `CONTEXT-MAP.md` for bounded contexts and relationships, then relevant `docs/contexts/<context>/CONTEXT.md` glossaries for domain terms
- `docs/adr/` for documented decisions
- `docs/LOGGING.md` for logging rules
- `docs/TESTING.md` for testing rules
- `docs/CODING_GUIDELINES.md` for code changes
- Area docs listed below when the plan touches that area
- `docs/agents/agent-workflow-extension.md` when adapting coding assistant workflows, agents, or skills

## Repo Specifics

- Before a task introduces an identifier for a domain concept the context glossary does not define, stop and resolve the term with the user through the `domain-modeling` skill; tasks may only name glossary terms or effect-named mechanics.

## Area Docs

<!-- Add project-specific area docs here. -->