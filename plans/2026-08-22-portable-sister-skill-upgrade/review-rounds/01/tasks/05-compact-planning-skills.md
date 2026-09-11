# Task 05: Compact Planning Skills

**Objective:** Remove planning exposition while preserving the proven artifact shape, zero-open-question gate, and skill references.

**Requirements:** F5; threads 3839525897, 3839526856, 3839529076, 3908745421, 3987488046.

**Files:**
- Modify: `core/agents/skills/brainstorm/SKILL.md`
- Modify: `core/agents/skills/planner/SKILL.md`
- Modify: `core/agents/skills/planning-structure/SKILL.md`

- [ ] **Step 1: Capture RED behavior**

Using fresh agents, test an ambiguous feature, repository-answerable path question, genuine owner decision, multi-task plan, and review-fix round. Save under `.temp/skill-evals/planning/red/`. Score direct/Explore/user-question choice; zero forks; correct task links and immutable review round; self-contained task; retained `/grilling`, domain-modeling, and `/planning-structure` references.

- [ ] **Step 2: Compact with contract preservation**

In `planner`, replace persona/rationale, repeated file-structure advice, duplicated granularity lists, and repeated placeholder reminders with one ordered workflow and checklist. Use exactly `Follow `/planning-structure` for directory layout, file names, numbering, and slug rules.` In `brainstorm`, retain approval/artifact gates, remove repeated negative implementation boundaries, and put optional visual detail behind its companion reference. In `planning-structure`, delete `What this skill does NOT own`; otherwise retain both layouts, numbering, links, and self-containment.

- [ ] **Step 3: Run GREEN and REFACTOR**

Repeat the same scenarios under `.temp/skill-evals/planning/green/`. Treat any lost gate as a regression. Add only the smallest instruction needed for an observed failure.

- [ ] **Step 4: Verify and commit**

```bash
codespell core/agents/skills/{brainstorm,planner,planning-structure}
rg -F 'Follow `/planning-structure` for directory layout, file names, numbering, and slug rules.' core/agents/skills/planner/SKILL.md
rg -F 'review-rounds/<NN>/plan.md' core/agents/skills/planning-structure/SKILL.md
if rg -n '^## What this skill does NOT own' core/agents/skills/planning-structure/SKILL.md; then exit 1; fi
git add core/agents/skills/brainstorm core/agents/skills/planner core/agents/skills/planning-structure
git commit -m "refactor: tighten planning skill guidance"
```

Expected: checks and GREEN scenarios pass; exact artifact contracts remain.

