## pnpm Stack

- Package manager: pnpm.
- Default verification commands: `pnpm lint`, `pnpm typecheck`, `pnpm test`.
- Run additional project-documented checks such as `pnpm test:integration`, `pnpm build`, or `pnpm test:e2e` when the target project defines them and the task scope requires them.
- Global installs are denied by default; do not run `pnpm -g` or `pnpm --global` from the toolkit workflow.
