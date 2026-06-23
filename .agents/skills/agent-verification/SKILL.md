---
name: agent-verification
description: Use when about to claim work is complete, committed, or ready — the done gate for this toolkit repo
user-invocable: false
---

# Agent Verification — Self-Maintenance

**Core principle:** Evidence before claims, always. If you haven't run the verification command, you cannot claim it passes.

## The Gate

```
BEFORE claiming any status:
1. IDENTIFY: What command proves this claim?
2. RUN: Execute the FULL command (fresh, complete)
3. READ: Full output, check exit code
4. VERIFY: Does output confirm the claim?
5. ONLY THEN: Make the claim (with evidence)
```

## Verification Commands

### For bash scripts (`scripts/init.sh`, `scripts/copy.sh`)

```bash
shellcheck scripts/init.sh scripts/copy.sh
bash -n scripts/init.sh
bash -n scripts/copy.sh
```

### Smoke run (scripts)

Run the script against a throwaway target dir under `.temp/`:

```bash
mkdir -p .temp/smoke-test
echo -e "1\n1\n.temp/smoke-test/target" | bash scripts/init.sh
```

For `copy.sh`:

```bash
mkdir -p .temp/smoke-copy && cd .temp/smoke-copy && git init && echo "placeholder" > README.md && git add . && git commit -m "init"
cd ../..
echo -e "1\n1" | bash scripts/copy.sh .temp/smoke-copy
```

Clean up after:

```bash
rm -rf .temp/smoke-test .temp/smoke-copy
```

### For markdown files

No compilation check, but verify:
- SKILL.md frontmatter has required `name` and `description`
- Agent `.md` files have required `description` in frontmatter
- No broken relative links (manual spot-check)

### Consistency checks

```bash
# README lists match actual files
ls .opencode/agents/          # should match README's agent list
ls .agents/skills/            # should match README's skill list

# Lockfiles match their distinct scopes
jq '.skills | keys' skills-lock.json
jq '.skills | keys' core/skills-lock.json

# Symlinks resolve
ls -la .claude/skills/        # each should point to ../../.agents/skills/<name>
```

## Claim Rules

- Use evidence-based language tied to command output.
- Run verification before success claims.
- Run relevant checks before commits, publishing, or PR creation.
- Verify agent success reports independently.

## When To Apply

ALWAYS before:
- Any completion or success claim
- Any commit
- Any push or PR creation
- Moving to next task

## Bottom Line

Run the command. Read the output. THEN claim the result.
