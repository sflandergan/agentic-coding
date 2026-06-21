# Logging

## Log Levels

| Level | When to use |
|---|---|
| `error` | The system failed to perform a required operation and the user-visible or operational state is wrong. |
| `warn` | The system succeeded but a recoverable problem occurred (fallback used, retry triggered, deprecated path taken). |
| `info` | Normal, expected lifecycle events (startup, shutdown, scheduled job started, configuration summary). |
| `debug` | Diagnostic detail useful during development; disable in production by default. |
| `trace` | Very verbose diagnostic detail; never enable in production. |

## Format

Document the log format the project uses here. Common choices:

- Structured JSON with stable field names.
- Key-value pairs with a delimiter.
- Plain text with a project-defined header.

Include the minimum fields the project guarantees (timestamp, level, message, request/trace id, logger name).

## Configuration

Document how to configure logging here:

- Default level per environment.
- How to override the level at runtime.
- Where logs are written (stdout, file, aggregator).
- Sampling rules for high-volume paths.

## What Not to Log

- Secrets, credentials, tokens, or session identifiers.
- Personally identifiable information unless explicitly required and approved.
- Request and response bodies for sensitive endpoints.