# Task 06: Compact UI Skills

**Objective:** Express UI work as a positive lifecycle and separate reusable controller/worker behavior from repository adapter values.

**Requirements:** F6 and UI portion of F3; threads 3987509189, 3987521038, 3987525367, 3987535876, 3987549259, 3987600379, 3987605962.

**Files:**
- Modify: `core/agents/skills/{ui-design,ui-design-task}/SKILL.md`
- Modify: `core/docs/agents/{ui-design,ui-design-task}.md`

- [ ] **Step 1: Capture RED behavior**

Using fresh agents, test missing adapter configuration, an approved required UI spec, worker presentation edits, bounded probing, evidence-driven changes after handoff, and final cleanup. Save under `.temp/skill-evals/ui/red/`. Score fail-closed configuration, worker scope, bounded render check, return to feedback after source changes, approval, handoff completeness, and ownership-safe stop.

- [ ] **Step 2: Separate contract from configuration**

Keep reusable `start`/`probe`/`stop` semantics and lifecycle in `ui-design`. Keep only target adapter path, readiness/scenario sources, viewports, source roots, screenshot/handoff paths, and commands in the role docs. Remove duplicate adapter/lifecycle prose there.

- [ ] **Step 3: Compact controller and worker**

Replace repeated negative sections with one positive ordered controller flow and worker output contract. The controller supplies owned files, state/scenario, and requested change; the worker edits that presentation scope and reports files/evidence. Keep destructive or correctness prohibitions once only when pressure tests prove them necessary.

- [ ] **Step 4: Run GREEN, verify, and commit**

```bash
codespell core/agents/skills/{ui-design,ui-design-task} core/docs/agents/{ui-design,ui-design-task}.md
rg -n '^description: Use when ' core/agents/skills/{ui-design,ui-design-task}/SKILL.md
if rg -n 'The adapter contract:' core/docs/agents/ui-design.md; then exit 1; fi
git add core/agents/skills/ui-design core/agents/skills/ui-design-task core/docs/agents/ui-design.md core/docs/agents/ui-design-task.md
git commit -m "refactor: compact UI design workflow"
```

Expected: GREEN scenarios pass; reusable behavior appears once in skills and target values once in role docs.
