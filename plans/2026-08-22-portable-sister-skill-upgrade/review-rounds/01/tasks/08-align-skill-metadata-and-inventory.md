# Task 08: Align Skill Metadata and Inventory

**Objective:** Make discovery trigger-first, install the writing-skill prerequisite, and finish inventory/count synchronization after Task 01's atomic publication migration.

**Requirements:** F8; threads 3839352179, 3839554545, 3839555739, 3839557821, plus the approved best-practice audit.

**Files:**
- Modify: remaining `core/agents/skills/*/SKILL.md` frontmatter
- Create: `.agents/skills/test-driven-development/` through the remote-skill installer
- Create: `.claude/skills/test-driven-development` relative symlink
- Modify: `skills-lock.json`
- Modify: `core/skills-lock.json`
- Modify: `README.md`
- Modify: `core/claude/README.md`
- Modify: `scripts/test-installer.sh`

- [ ] **Step 1: Normalize discovery metadata**

For every authored skill, begin `description` with `Use when` and state concrete trigger conditions only, not workflow steps. Keep names lowercase/hyphenated and preserve invocation flags. Do not add `agents/openai.yaml` for completeness; retain only existing UI/idea metadata with distinct product presentation.

- [ ] **Step 2: Install the declared prerequisite in both scopes**

Add `test-driven-development` from `obra/superpowers` to `skills-lock.json` (self-maintenance) and `core/skills-lock.json` (downstream), because `writing-skills` declares it required in both scopes. Run `npx skills add obra/superpowers --skill test-driven-development -a opencode --yes` at the repository root, verify `.agents/skills/test-driven-development/SKILL.md`, and create `.claude/skills/test-driven-development -> ../../.agents/skills/test-driven-development` if the installer does not.

- [ ] **Step 3: Synchronize publication and skill inventories**

Confirm Task 01 left no retired publication references. Add `planning-structure` to every hidden-support list/assertion. Remove numeric headings/count claims. State once that authored skills are canonical under `.agents/skills/` and symlinked into `.claude/skills/`. Make installer test inventories exactly match the authored tree.

- [ ] **Step 4: Run full verification**

```bash
bash -n scripts/init.sh scripts/copy.sh scripts/test-installer.sh
shellcheck scripts/init.sh scripts/copy.sh scripts/test-installer.sh
jq empty skills-lock.json core/skills-lock.json core/claude/settings.json
bash scripts/test-installer.sh
codespell README.md core scripts
status=0
while IFS= read -r skill_file; do
  rg -q '^name: [a-z0-9]+(-[a-z0-9]+)*$' "$skill_file" || status=1
  rg -q '^description: Use when .+' "$skill_file" || status=1
done < <(find core/agents/skills -name SKILL.md -print)
test "$status" -eq 0
if rg -n 'change-request-publish|publish-change-request\.sh|push-branch\.sh' README.md core scripts; then exit 1; fi
```

Expected: checks exit 0; pnpm and Maven smoke targets contain every authored skill; hidden skills are non-user-invocable; Claude entries are relative symlinks.

- [ ] **Step 5: Commit**

```bash
git add skills-lock.json core/skills-lock.json README.md core scripts .agents/skills .claude/skills
git commit -m "chore: align skill discovery and inventories"
```
