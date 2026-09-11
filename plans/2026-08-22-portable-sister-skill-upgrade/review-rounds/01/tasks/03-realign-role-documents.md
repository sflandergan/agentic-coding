# Task 03: Realign Role Documents

**Objective:** Put reusable workflow policy in agent/skill contracts and leave role docs with repository-specific inputs, commands, paths, and configuration.

**Requirements:** F3; threads 3839561309, 3839564619, 3839566023, 3839567064, 3839568166, 3839568660, 3839570812, 3839576068, 3839577648, 3987573858, 3987579081, 3987582414, 3987590539, 3987600379, 3987605962.

**Files:**
- Modify: `core/AGENTS.md`
- Modify: `core/docs/agents/{bugfix,brainstorm,implement,implement-task,planner,ui-design}.md`
- Modify: `core/opencode/agents/{implement,implement-task}.md`

- [ ] **Step 1: Relocate general rules**

Place project-wide allowed-path, scratch, commit, protected-branch, and preservation rules in `core/AGENTS.md` once. Keep controller/worker orchestration in skills. Thin OpenCode files to runtime metadata, permissions, and canonical skill invocation; remove copied workflow prose and back-references.

- [ ] **Step 2: Retain repository configuration only**

`bugfix.md` keeps architecture/log/area sources, investigation locations, and reproduction commands. Implementation roles keep exact project verification and prerequisites. `planner.md` keeps load sources and stack commands. `brainstorm.md` keeps repository/domain inputs. `ui-design.md` keeps adapter implementation path, URLs, scenario/viewports, source roots, screenshot/handoff paths, and pre-commit command; adapter lifecycle belongs in the skill.

- [ ] **Step 3: Keep placeholders explicit**

Use HTML comments beginning `TODO: Replace ...` only for values an installer cannot know. Do not leave executable-looking `<package-manager>` commands outside comments.

- [ ] **Step 4: Verify and commit**

```bash
codespell core/AGENTS.md core/docs/agents core/opencode/agents
if rg -n 'Allowed paths|Git conventions|Scratch paths|After writing the plan, self-review|The adapter contract' core/docs/agents/{implement-task,planner,ui-design}.md; then exit 1; fi
git add core/AGENTS.md core/docs/agents core/opencode/agents
git commit -m "refactor: separate role configuration from workflow policy"
```

Expected: spelling passes and the ownership scan has no matches.
