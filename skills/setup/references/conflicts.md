# Conflict policies

Resolve each conflict immediately before writing the affected asset. Scope the
choice to the named target and state the selected outcome.

Before each choice, present one difference summary containing the target, the
current source if known, the selected source, and behavior-changing differences.
A behavior-changing difference alters instructions, commands, permissions,
models, paths, or links. Refresh the summary when a comparison input changes.

| Evidence | Choices | State result |
|---|---|---|
| Exact selected-release content | Adopt or replace | Adopt records a managed asset and selected hash; replace writes selected content and records the same hash |
| Modified or unproven content | Replace, rename then replace, or retain | Retain records a warning and observed source; it is not managed as selected content |
| Modified managed native asset | Replace or retain | Retain preserves the prior managed hash plus a warning |
| Retired managed asset | Remove or retain | Retain records the retirement warning for future runs |
| Project-owned documentation | Apply the displayed targeted edit or keep current text | Documentation is never content-hash managed |
