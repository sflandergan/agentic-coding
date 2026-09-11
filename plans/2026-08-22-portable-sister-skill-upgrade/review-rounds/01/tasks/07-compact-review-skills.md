# Task 07: Compact Review Skills

**Objective:** Reduce review duplication while preserving findings-first output, feedback accountability, immutable fix rounds, edit boundaries, and approval before replies.

**Requirements:** F7; thread 3839545745 and the approved repository-wide verbosity audit.

**Files:**
- Modify: `core/agents/skills/review-code/SKILL.md`
- Modify: `core/agents/skills/review-plan/SKILL.md`
- Modify: `core/agents/skills/github-pr-comments/SKILL.md`

- [ ] **Step 1: Capture RED behavior**

Using fresh agents, test multiple PR comments deduplicating to one finding, an incorrect technical comment, late user feedback, no actionable findings, and an existing numbered review round. Save under `.temp/skill-evals/review/red/`. Score source preservation, requirement sub-IDs, technical verification, findings-first severity, next immutable round, `/planning-structure`, edit boundary, reconciliation evidence, and approval before posting.

- [ ] **Step 2: Consolidate each workflow**

Use one ordered workflow and one completion contract per skill. Merge repeated ledger, clarification, quality-gate, escalation, and reconciliation clauses. `review-code` retains `plans/**`-only edits and implementation-evidence boundaries. `review-plan` retains approved plan/spec-only edits. `github-pr-comments` retains exact PR selection, unresolved-thread fetching, reply targeting, and approval. Do not create another shared skill merely to reduce words.

- [ ] **Step 3: Run GREEN and REFACTOR**

Repeat under `.temp/skill-evals/review/green/`. Add only the smallest instruction for an observed regression. A shorter skill that drops a source item, writes outside scope, mutates an old round, or posts without approval fails.

- [ ] **Step 4: Verify and commit**

```bash
codespell core/agents/skills/{review-code,review-plan,github-pr-comments}
rg -F '/planning-structure' core/agents/skills/review-code/SKILL.md
rg -F 'explicit approval' core/agents/skills/{review-code,review-plan,github-pr-comments}/SKILL.md
git add core/agents/skills/review-code core/agents/skills/review-plan core/agents/skills/github-pr-comments
git commit -m "refactor: streamline review workflows"
```

Expected: GREEN scenarios pass and every source requirement stays traceable after finding deduplication.

