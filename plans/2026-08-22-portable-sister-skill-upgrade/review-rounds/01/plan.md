# PR 2 Review Fix Plan — Round 01

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring PR #2 in line with the current `bikes-local` publication workflow, resolve all 43 open review threads, and compact authored skills without weakening proven workflow gates.

**Architecture:** One `git-publish` skill owns branch push, draft PR discovery/creation, and exact retained-head updates. `finish` retains its strict sequence but delegates deterministic freshness and readiness mechanics to tested scripts. General policy lives in `core/AGENTS.md`; role documents hold repository-specific inputs and commands. Skill prose is reduced using trigger-first, progressive-disclosure guidance, with RED/GREEN behavior evaluations protecting each edited workflow.

**Tech Stack:** Markdown skill templates, Bash, Bats, `gh`, Git, installer smoke scripts, `codespell`, `shellcheck`.

## Review context

- Pull request: PR #2, `feature/portable-sister-skill-upgrade` into `main`.
- Sister reference: `/Users/sflandergan/dev/repositories/bikes-local` at `origin/main`, especially `.agents/skills/git-publish/` and `.agents/skills/finish/`.
- Guidance: repository `AGENTS.md`, `/agent-review`, `/github-pr-comments`, `/writing-skills`, its Anthropic companion, and [OpenAI's Codex skill guide](https://developers.openai.com/codex/skills).
- User decisions: replace `change-request-publish` with the sister repository's unified `git-publish`; preserve the exactness that makes `finish` and `planning-structure` effective; compact explanation and duplication, not behavioral contracts.

## Approved findings

| ID | Finding | Severity | Fix task |
|---|---|---:|---|
| F1 | Split publication has duplicated logic, ambiguous ownership, long orchestration, unsafe Bats cleanup, and no sister-style exact-PR mode. | P1 | [Task 01](tasks/01-unify-git-publication.md) |
| F2 | `finish` duplicates freshness/readiness mechanics in prose and trails the sister's tested orchestration, cleanup, and feature-index behavior. | P1 | [Task 01](tasks/01-unify-git-publication.md), [Task 02](tasks/02-port-finish-orchestration.md) |
| F3 | General workflow rules remain in role templates and OpenCode wrappers instead of shared agent/skill contracts. | P2 | [Task 03](tasks/03-realign-role-documents.md) |
| F4 | `implement` explains rationale and mixes delegation guidance; worker and verification contracts repeat policy. | P2 | [Task 04](tasks/04-compact-implementation-skills.md) |
| F5 | Planning skills contain avoidable explanation or negative ownership text, but their exact artifact and decision gates must remain. | P2 | [Task 05](tasks/05-compact-planning-skills.md) |
| F6 | `ui-design` repeats controller/worker constraints and mixes reusable adapter behavior with repository configuration. | P2 | [Task 06](tasks/06-compact-ui-skills.md) |
| F7 | Review workflows repeat policy across priorities, escalation, quality gates, and completion. | P2 | [Task 07](tasks/07-compact-review-skills.md) |
| F8 | Discovery metadata and inventories are inconsistent, and `writing-skills` declares an unavailable TDD prerequisite. | P2 | [Task 08](tasks/08-align-skill-metadata-and-inventory.md) |

## Skill-writing decisions

- Keep strict ordered procedures for fragile operations. Preserve `finish`'s freshness → verification → publication → readiness order and `planning-structure`'s layout, numbering, links, and self-containment contract.
- Remove rationale, motivational language, duplicated prohibitions, and workflow summaries from descriptions. Descriptions begin `Use when ...` and state triggers only.
- Prefer positive recipes. Retain prohibitions only for observed failure modes or destructive actions.
- Put deterministic Git/GitHub checks in scripts; keep judgment, approvals, and sequencing in skills.
- Use progressive disclosure for optional or long reference material.
- Do not use word count as the acceptance criterion. Require materially shorter prose with unchanged behavior in RED/GREEN scenarios.

## Task overview

| Task | Objective | Verification |
|---|---|---|
| 01 | Atomically replace split publication, port finish helpers, and migrate all references | Publication and finish Bats, Bash syntax, shellcheck, reference scan |
| 02 | Compact finish artifact cleanup and feature-index guidance | Behavior scenario, content assertions |
| 03 | Restore role/agent ownership boundaries | Content assertions, codespell |
| 04 | Compact implementation and verification skills | RED/GREEN scenarios, codespell |
| 05 | Compact planning while preserving artifact contracts | RED/GREEN scenarios, structure assertions |
| 06 | Compact UI controller/worker and separate adapter configuration | RED/GREEN scenarios, assertions |
| 07 | Compact code/plan review workflows | RED/GREEN scenarios, ledger assertions |
| 08 | Normalize metadata, dependency locks, inventories, and installer tests | Frontmatter, JSON, smoke, symlinks |

## Feedback ledger and disposition

Quotes are the root comments of all 43 unresolved PR #2 threads fetched on 2026-09-11.

| Thread | Exact feedback | Finding / task |
|---:|---|---|
| 3839283174 | “Horrible name, replace it with `suggestion exitWithError() {`” | F1 / 01; obsolete helper is replaced. |
| 3839308402 | “I’d move the stubs out in a helper file and use bats for testing” | F1 / 01. |
| 3839332145 | “This is tightly coupling two skills. Either orchestrate on skill level or copy that logic over” | F1 / 01; superseded by approved single-skill design. |
| 3839345215 | “Rename this to `suggestion exitWithError() {`” | F1 / 01. |
| 3839349845 | “Use bats for testing.” | F1 / 01. |
| 3839352179 | “For the skill it is irrelevant how it is called. It should properly describe what to do instead” | F1 / 01 and F8 / 08. |
| 3839353024 | “This missed explanation about parameters” | F1 / 01. |
| 3839525897 | “This lost the skill reference `suggestion Run a /grilling session about the artifact at hand.`” | F5 / 05; preserve restored reference. |
| 3839526856 | “`suggestion - **Business ideas and other non-engineering artifacts**: run the /grilling`” | F5 / 05; preserve restored reference. |
| 3839529076 | “This lost the domain modeling skill reference” | F5 / 05; preserve restored reference. |
| 3839545745 | “This is not matching the sister repo. It misses the planning structure skill reference” | F7 / 07; preserve restored reference. |
| 3839554545 | “Remove the numbers `suggestion ## Skills`” | F8 / 08. |
| 3839555739 | “`suggestion All authored skills are symlinked from `.agents/skills/`:`” | F8 / 08. |
| 3839557821 | “`suggestion All authored skills under `.agents/skills/` are symlinked into `.claude/skills/<name>` → `../../.agents/skills/<name>`. There are no "real" skill directories under `.claude/skills/` — every skill is accessed via symlink. This means:`” | F8 / 08. |
| 3839561309 | “This should have a todo to replace this” | F3 / 03. |
| 3839564619 | “This is skill not project repository content” | F3 / 03. |
| 3839566023 | “This should solely focus on the verification commands, rest is skill instructions” | F3 / 03. |
| 3839567064 | “Remove the back references” | F3 / 03. |
| 3839568166 | “This is skill not project repository content” | F3 / 03. |
| 3839568660 | “This is skill not project repository content” | F3 / 03. |
| 3839570812 | “This is skill not project repository content” | F3 / 03. |
| 3839576068 | “This belongs to the skill. Not here” | F3 / 03. |
| 3839577648 | “This is skill and not agent content” | F3 / 03. |
| 3903441038 | “This is quite long ‘main’ logic. I’d prefer introducing more functions and have a rather short orchestration” | F1 / 01. |
| 3903459328 | “Now that we are GitHub only, this can be pull-request-publish. Same with helper scripts” | F1 / 01; superseded by later user choice of unified `git-publish`. |
| 3907429376 | “We have a script for this in the sister skill” | F2 / 01. |
| 3907439270 | “Remove the legacy structure `suggestion This removes `spec.md`, `plan.md`, `tasks/` and all numbered `review-rounds/<NN>/` artifacts in one commit-friendly step.`” | F2 / 02. |
| 3907455757 | “The sister skill points to an feature index. I think that is the correct reference” | F2 / 02. |
| 3908712515 | “I'm not sure if this is really relevant anymore. I'd stick to the workflow and not the why” | F4 / 04. |
| 3908728824 | “This is a bit of a mixture. I'd write when to use explore instead of doing things yourself and when to not use it but performing task your self” | F4 / 04. |
| 3908745421 | “`suggestion Follow `/planning-structure` for directory layout, file names, numbering, and slug rules.`” | F5 / 05. |
| 3987488046 | “Is this really relevant information for an agent or can we drop this nowadays!” | F5 / 05. |
| 3987509189 | “Is this really necessary information or should we drop it?” | F6 / 06. |
| 3987521038 | “Doesn’t this kind of duplicate the previous passage?” | F6 / 06. |
| 3987525367 | “That’s unnecessary slop right?” | F6 / 06. |
| 3987535876 | “Im not a big fan of descriptions what not do. I think the skill should give the direction what to do and not unnecessary boundaries” | F6 / 06. |
| 3987549259 | “I have the feeling this is a candidate for compaction” | F6 / 06. |
| 3987573858 | “This is mixing general skill workflow with repository specifics. Only thing that belongs here is the technology specific commands and bug analysis instructions like log location or similar” | F3 / 03. |
| 3987579081 | “These belong to the general AGENTS.md” | F3 / 03. |
| 3987582414 | “Same here. General agents.md” | F3 / 03. |
| 3987590539 | “This is not repo specific but general skill guidance” | F3 / 03. |
| 3987600379 | “This is mixing specifics with general skill guidance. The adapter is part of the skill. The adapter implementation is repo specific” | F3 / 03 and F6 / 06. |
| 3987605962 | “As said, rather general skill guidance” | F3 / 03 and F6 / 06. |

The words `TODO` and `<package-manager>` in Task 03 are intentional literal template markers required by thread 3839561309, not unresolved plan placeholders.

## Verification baseline

```bash
bash -n scripts/init.sh scripts/copy.sh scripts/test-installer.sh core/agents/skills/git-publish/scripts/publish-branch.sh core/agents/skills/finish/scripts/*.sh
shellcheck scripts/init.sh scripts/copy.sh scripts/test-installer.sh core/agents/skills/git-publish/scripts/publish-branch.sh core/agents/skills/finish/scripts/*.sh
SCRATCH="$PWD/.temp/bats" bats core/agents/skills/git-publish/test/publish-branch.bats
SCRATCH="$PWD/.temp/bats" bats core/agents/skills/finish/test/readiness.bats
bash scripts/test-installer.sh
codespell README.md core scripts plans/2026-08-22-portable-sister-skill-upgrade/review-rounds/01
jq empty skills-lock.json core/skills-lock.json core/claude/settings.json
```

Expected: every command exits 0; all Bats cases pass; installer smoke has no failed assertion; symlinks and inventories agree with the authored tree.
