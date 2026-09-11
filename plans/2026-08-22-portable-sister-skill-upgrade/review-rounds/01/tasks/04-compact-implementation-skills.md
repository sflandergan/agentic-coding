# Task 04: Compact Implementation Skills

**Objective:** Shorten implementation guidance while preserving task isolation, verification, review gates, and worker reporting.

**Requirements:** F4; threads 3908712515 and 3908728824.

**Files:**
- Modify: `core/agents/skills/implement/SKILL.md`
- Modify: `core/agents/skills/implement-task/SKILL.md`
- Modify: `core/agents/skills/verification-before-completion/SKILL.md`

- [ ] **Step 1: Capture RED behavior**

Using fresh agents, run: a one-task plan with an obvious local lookup; a task needing cross-module tracing; a worker tempted to edit an unassigned file; a failed test followed by a completion claim; and a controller receiving an unverified success report. Save transcripts below `.temp/skill-evals/implementation/red/` and record rationalizations and pass/fail.

- [ ] **Step 2: Compact to procedures**

Remove `Why subagents` and other rationale. State the Explore decision positively: investigate directly for bounded facts available in assigned context; use Explore for repository-wide tracing or uncertain boundaries; the worker implements its assigned task itself. Merge repeated task-scope and verification clauses. Reduce verification guidance to its five-step evidence gate, claim/evidence table, unavailable-vs-failed distinction, and regression RED/GREEN rule; remove moralizing language, repeated red flags, rationalization tables, and duplicate examples.

- [ ] **Step 3: Run GREEN and REFACTOR**

Repeat the scenarios under `.temp/skill-evals/implementation/green/`. Pass only if direct work versus Explore is correct, worker scope holds, failed/unavailable checks are accurate, and no success claim precedes fresh evidence. Add only the smallest positive instruction needed for an observed failure.

- [ ] **Step 4: Verify and commit**

```bash
codespell core/agents/skills/{implement,implement-task,verification-before-completion}
rg -n '^description: Use when ' core/agents/skills/{implement,implement-task,verification-before-completion}/SKILL.md
git add core/agents/skills/implement core/agents/skills/implement-task core/agents/skills/verification-before-completion
git commit -m "refactor: focus implementation skill contracts"
```

Expected: all descriptions match, GREEN scenarios pass, and task isolation/evidence gates remain explicit.

