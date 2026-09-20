# Repository discovery

Discovery inspects the repository without modifying files. Produce exactly
these five named outputs and keep observations separate from proposals.

## Outputs

1. **Repository identity:** `repository_root`, current branch, and Git tree
   status as `clean` or `dirty`. Use the actual repository root and
   repository-relative paths for all other outputs.
2. **Instructions and ownership:** applicable `AGENTS.md`, `CLAUDE.md`, and
   nested instruction files, with their precedence and path ownership
   boundaries.
3. **Stack and verification:** the detected stack and the verification
   commands that its repository configuration defines.
4. **Installed integrations:** selected or detected harnesses; installed
   Claude Code and Codex toolkit plugin metadata; Vercel-managed skills and
   their scope; native assets; harness configuration; project documentation;
   and the Vercel lock paths for each scope.
5. **Missing decision facts:** only facts whose absence changes component
   scope, ownership, release choice, or a destructive operation.

For output 4, distinguish plugin-managed authored skills from Vercel-managed
skills only after reading installed plugin metadata and its exposed inventory.
Mark unknown source or ownership as unknown. Ask only for output 5 facts.

Use [modes.md](modes.md) to classify the run.
