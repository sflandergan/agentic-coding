# Bootstrap

1. List published tags before selecting a stable release:

```bash
git ls-remote --tags --refs "$toolkit_remote"
```

2. Install `setup` from the selected stable tag for the selected harnesses:

```bash
npx skills add "$toolkit_remote/tree/$tag" --skill setup --agent claude-code --agent opencode --agent codex --yes
npx skills add "$toolkit_remote/tree/$tag" --skill setup --agent claude-code --agent opencode --agent codex --yes --global
```

3. Install preview explicitly from `main` for the selected harnesses:

```bash
npx skills add "$toolkit_remote/tree/main" --skill setup --agent claude-code --agent opencode --agent codex --yes
npx skills add "$toolkit_remote/tree/main" --skill setup --agent claude-code --agent opencode --agent codex --yes --global
```
