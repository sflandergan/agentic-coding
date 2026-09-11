# Portable Sister Skill Upgrade Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the toolkit's workflow skills with the reusable improvements proven in `bikes-local`, including guarded draft-first publication and a project-owned UI preview adapter, add the `idea`, `ui-design`, and `ui-design-task` workflows, and exclude every bikes-local-specific path, command, label, provider, and domain rule.

**Configuration shape:** Canonical workflow definitions live under `core/agents/skills/<name>/`, OpenCode agent files become permission-aware entry wrappers, and Claude receives relative symlinks to the same canonical skill trees. Authored `git-publish` and `change-request-publish` support skills isolate guarded Git transport from GitHub/GitLab request handling. UI workflows call the stable project-owned `.agents/scripts/ui-design/preview.sh` adapter, while repository-specific loading, verification, preview implementation, presentation paths, business context, and issue labels remain in target-owned scripts, `core/docs/agents/*.md` role templates, or stack overlays rather than reusable skills.

**Configuration surface:** `core/agents/skills/`, `core/opencode/agents/`, `core/docs/agents/`, `core/claude/`, `core/AGENTS.md`, `core/skills-lock.json`, `scripts/init.sh`, `scripts/copy.sh`, `README.md`, and smoke targets under `.temp/`; validate Markdown/frontmatter, JSON, symlinks, Bash syntax, shellcheck, guarded publication behavior, preview-adapter preservation, and both installer modes.

## Approved inputs and docs used

- GitHub review comments [3838201080](https://github.com/sflandergan/agentic-coding-next/pull/1#discussion_r3838201080) and [3838202487](https://github.com/sflandergan/agentic-coding-next/pull/1#discussion_r3838202487), approved by the user on 2026-08-23. This plan directory has no separate `spec.md`; the existing plan plus those approved comments are the requirements source.
- Repository conventions in `AGENTS.md` and installed-template conventions in `core/AGENTS.md`.
- Workflow placement rules in `core/docs/agents/agent-workflow-extension.md`.
- Current installer behavior in `scripts/init.sh` and `scripts/copy.sh`, including core/stack merges, authored-skill installation, role-doc preservation, and OpenCode wrapper modes.
- Current publication behavior in `scripts/publish-branch.sh` and `core/opencode/agents/{brainstorm,planner,implement,finish}.md`.
- Historical host-neutral publication split from commit `07c0fe1` on `feature/support-claude-implement-and-glab`.
- Current `bikes-local` idea, brainstorm, planner, UI-design, implementation, review, finish, publication, preview-helper, and supporting skill trees as behavioral references.

## Portability decisions

- Use the current `bikes-local` skill trees as behavioral references, not as files to copy blindly.
- Preserve this toolkit's `plans/YYYY-MM-DD-feature-name/spec.md` and `plan.md` artifact convention; do not import bikes-local's split-task `planning-structure` workflow.
- Preserve a host-neutral publication boundary by installing separate authored `git-publish` and `change-request-publish` support skills instead of embedding raw `git push`, `gh`, or `glab` commands in workflow skills. Create new pull/merge requests as draft/work-in-progress by default and preserve an existing request's readiness. Permit retained-head updates only through an explicit mode that validates an open request and matching head, requires a fully qualified `--force-with-lease=refs/heads/<head>:<expected-sha>` plus an explicit destination refspec, and fails on a stale lease without retrying with weaker force. Normal workflow publication must reject protected/default branches and detached HEAD; retained-head mode additionally requires explicit human authorization.
- Do not import `@bikes-local/*` package names, `apps/web/**`, port `4322`, `/tmp/bikes-local`, bikes-local ADR numbers, business-document names, issue labels, preview commands, or provider configuration.
- Do not copy the bikes-local preview implementation. Define `.agents/scripts/ui-design/preview.sh` as a stable target-owned adapter with `start`, bounded `probe`, and ownership-safe idempotent `stop` verbs; a project may implement those verbs directly or delegate them to any custom helper. Grant only those three exact adapter invocations. Require each target repository to provide the adapter and declare readiness/scenario URLs, presentation roots, screenshot location, handoff path, and pre-commit rules in its UI role docs; missing helper or role configuration must fail closed.
- Add only `impeccable` to `core/skills-lock.json`; keep `skills-lock.json` unchanged because this is a downstream-template dependency, not a self-maintenance dependency.
- Do not add pnpm or Maven overlays for the three new workflows. Neither stack identifies a universal UI package, preview command, business-document set, or issue-label taxonomy; those values belong in the installed repository's core role documents.

### Task 1: Canonicalize Workflow Skill Installation

**Files:**
- Rename: `core/agents/skills/workflow-brainstorming/` to `core/agents/skills/brainstorm/`, then replace its workflow entry with `core/claude/skills/brainstorm/SKILL.md`
- Rename: `core/agents/skills/workflow-bug-analysis/` to `core/agents/skills/bugfix/`, then replace its workflow entry with `core/claude/skills/bugfix/SKILL.md`
- Rename: `core/agents/skills/workflow-planning/` to `core/agents/skills/planner/`, then replace its workflow entry with `core/claude/skills/planner/SKILL.md`
- Rename: `core/agents/skills/workflow-implementation/` to `core/agents/skills/implement/`
- Rename: `core/agents/skills/workflow-verification/` to `core/agents/skills/verification-before-completion/`
- Move: `core/claude/skills/finish/` to `core/agents/skills/finish/`
- Move: `core/claude/skills/review-code/` to `core/agents/skills/review-code/`
- Move: `core/claude/skills/review-plan/` to `core/agents/skills/review-plan/`
- Delete after merging: `core/claude/skills/brainstorm/`
- Delete after merging: `core/claude/skills/bugfix/`
- Delete after merging: `core/claude/skills/planner/`
- Create: `core/agents/skills/implement-task/SKILL.md`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Build one canonical skill tree**

Use `git mv` for the five directory renames and the finish/review moves. For brainstorm, bugfix, and planner, retain the renamed authored directory's scripts, licenses, prompts, and companion assets, replace its old helper `SKILL.md` with the matching Claude entry workflow, and then remove the now-empty Claude source directory. Create `implement-task/SKILL.md` as the worker half of the existing implementation workflow so both runtimes invoke the same worker contract.

- [ ] **Step 2: Replace the two installer skill lists with one canonical inventory**

In both scripts, define the canonical authored inventory as:

```text
brainstorm
bugfix
feature-documentation
finish
github-pr-comments
grill-with-docs
implement
implement-task
planner
review-code
review-plan
verification-before-completion
```

Make `init.sh` copy these directories to `.agents/skills/` and create `.claude/skills/<name> -> ../../.agents/skills/<name>` for every entry. Make `copy.sh` apply `add`, `override`, or `skip` once to the canonical `.agents` directory and then reconcile the Claude symlink with `ensure_symlink`; delete its separate real-directory Claude workflow copy section. Keep remote-skill installation after authored-skill staging so remote keys can use the same Claude symlink model.

- [ ] **Step 3: Align frontmatter with the canonical invocation model**

Keep user-facing workflow names invocable and hidden worker/support skills non-user-facing. Every `SKILL.md` must have a lowercase hyphenated `name`, a third-person trigger-first `description`, and `user-invocable: false` only for `implement-task`, `ui-design-task`, `feature-documentation`, `github-pr-comments`, and `verification-before-completion`. Retain `disable-model-invocation: true` on explicit user entry workflows where supported by the sister implementation.

- [ ] **Step 4: Verify the structural migration**

Run:

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
codespell core/agents/skills scripts/init.sh scripts/copy.sh
status=0
while IFS= read -r skill_file; do
  rg -q '^name: [a-z0-9]+(-[a-z0-9]+)*$' "$skill_file" || { printf 'Invalid or missing name: %s\n' "$skill_file" >&2; status=1; }
  rg -q '^description: .+' "$skill_file" || { printf 'Missing description: %s\n' "$skill_file" >&2; status=1; }
done < <(find core/agents/skills -name SKILL.md -print)
test "$status" -eq 0
if find core/claude/skills -mindepth 1 -maxdepth 1 -type d -print -quit | rg -q .; then exit 1; fi
if find core/agents/skills -mindepth 1 -maxdepth 1 -type d -name 'workflow-*' -print -quit | rg -q .; then exit 1; fi
```

Expected: no errors; no real workflow skill directories remain under `core/claude/skills/`; no obsolete `workflow-*` path remains except references intentionally retained in migration documentation.

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills core/claude/skills scripts/init.sh scripts/copy.sh
git commit -m "refactor: unify workflow skill sources"
```

### Task 2: Add Host-Neutral Publication Support

**Files:**
- Create: `core/agents/skills/git-publish/SKILL.md`
- Create: `core/agents/skills/git-publish/scripts/push-branch.sh`
- Create: `core/agents/skills/git-publish/test/push-branch.sh`
- Create: `core/agents/skills/change-request-publish/SKILL.md`
- Create: `core/agents/skills/change-request-publish/scripts/publish-change-request.sh`
- Create: `core/agents/skills/change-request-publish/test/publish-change-request.sh`
- Modify: `core/agents/skills/brainstorm/SKILL.md`
- Modify: `core/agents/skills/planner/SKILL.md`
- Modify: `core/agents/skills/implement/SKILL.md`
- Modify: `core/agents/skills/finish/SKILL.md`
- Modify: `core/opencode/agents/brainstorm.md`
- Modify: `core/opencode/agents/planner.md`
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/finish.md`
- Modify: `core/claude/settings.json`
- Modify: `core/AGENTS.md`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Add guarded Git transport**

Create hidden authored `git-publish` support with `user-invocable: false`. Its `push-branch.sh` must expose exactly two modes:

```text
bash .agents/skills/git-publish/scripts/push-branch.sh
bash .agents/skills/git-publish/scripts/push-branch.sh --update-existing-head <head-branch> <expected-40-character-sha>
```

Normal mode must resolve the current branch and remote default branch, reject detached HEAD plus `main`, `master`, and the resolved default branch, and push only `HEAD:refs/heads/<current-branch>` with upstream tracking. Existing-head mode must require all arguments together, validate the SHA and branch with `git check-ref-format`, reject protected/default destinations, and execute exactly `git push --force-with-lease="refs/heads/$head_branch:$expected_sha" origin "HEAD:refs/heads/$head_branch"`. It must make one attempt and propagate a stale-lease failure without retrying with `--force`, `-f`, an unqualified lease, or another refspec. Keep local-main and detached-HEAD publication out of both modes.

- [ ] **Step 2: Add provider-neutral change-request publication**

Create hidden authored `change-request-publish` support with `user-invocable: false`. `publish-change-request.sh` must detect GitHub or GitLab from `origin`, fail closed for unsupported hosts, resolve the current scoped branch, and call `git-publish` rather than raw `git push`. For a new request, use `gh pr create --fill --draft` or the GitLab CLI's draft/work-in-progress equivalent and print its URL. For an existing open request, print its URL without changing draft/readiness state.

Expose `--update-existing-head <head-branch> <expected-sha>` only for explicit retained-head updates. Before delegating to `git-publish`, query the provider and require one open request whose reported head equals `<head-branch>` and whose current remote SHA equals `<expected-sha>`. Reject closed requests, head mismatches, malformed arguments, protected/default heads, and stale remote state. Expose `--mark-ready <verified-40-character-sha>` as a separate explicit operation: require the current open request head SHA to equal the supplied freshly verified SHA, then call `gh pr ready` or `glab mr update --ready`. Publication must never silently mark an existing request ready.

- [ ] **Step 3: Route workflow publication through the support boundary**

Add both skills to the canonical authored inventory in `scripts/init.sh` and `scripts/copy.sh`, create their relative Claude symlinks through the canonical installer flow, and classify both as hidden support skills. Replace raw push and direct `gh`/`glab` publication instructions and permissions in brainstorm, planner, implement, and finish with least-privilege access to the two support skills and their exact scripts. Preserve each workflow's terminal behavior: idea never publishes; brainstorm and planner publish an artifact only when their workflow contract calls for it; implementation publishes after all task commits and fresh final verification; finish changes readiness only when explicitly requested after its own fresh verification.

Add matching exact helper permissions to `core/claude/settings.json`. Update `core/AGENTS.md` so raw force-push remains forbidden and the only exception is an explicitly authorized retained-head update through `change-request-publish`, with a fully qualified lease and expected SHA. Do not modify pnpm or Maven overlays: core Claude permissions are merged into both stacks, and publication has no stack-specific command.

- [ ] **Step 4: Verify publication safety and installation**

Make the two portable Bash test scripts accept a scratch root below `.temp/`, create local bare remotes and stub `gh`/`glab` executables there, and clean only their named fixture directories. Cover normal scoped push, default-branch and detached-HEAD rejection, new GitHub draft PR, new GitLab draft MR, existing-request idempotency and readiness preservation, explicit ready transition only at the supplied verified SHA, unsupported-host failure, complete retained-head arguments, malformed branch/SHA rejection, closed-request and head-mismatch rejection, exact fully qualified lease/refspec, and a stale lease that performs one failed push without changing the remote.

Run:

```bash
bash -n core/agents/skills/git-publish/scripts/push-branch.sh core/agents/skills/change-request-publish/scripts/publish-change-request.sh core/agents/skills/git-publish/test/push-branch.sh core/agents/skills/change-request-publish/test/publish-change-request.sh scripts/init.sh scripts/copy.sh
shellcheck core/agents/skills/git-publish/scripts/push-branch.sh core/agents/skills/change-request-publish/scripts/publish-change-request.sh core/agents/skills/git-publish/test/push-branch.sh core/agents/skills/change-request-publish/test/publish-change-request.sh scripts/init.sh scripts/copy.sh
codespell core/agents/skills/git-publish core/agents/skills/change-request-publish core/agents/skills/brainstorm/SKILL.md core/agents/skills/planner/SKILL.md core/agents/skills/implement/SKILL.md core/agents/skills/finish/SKILL.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/opencode/agents/implement.md core/opencode/agents/finish.md core/AGENTS.md scripts/init.sh scripts/copy.sh
mkdir -p .temp/publication-smoke
bash core/agents/skills/git-publish/test/push-branch.sh .temp/publication-smoke/git-publish
bash core/agents/skills/change-request-publish/test/publish-change-request.sh .temp/publication-smoke/change-request
if rg -n 'git push|gh pr create|glab mr create' core/agents/skills/{brainstorm,planner,implement,finish}/SKILL.md core/opencode/agents/{brainstorm,planner,implement,finish}.md; then exit 1; fi
rm -rf .temp/publication-smoke
```

Expected: syntax, shellcheck, and spelling pass; both behavioral harnesses pass every guard and provider case; workflow-facing files contain no direct publication command; both support skills are in the authored inventory; no stack overlay or lockfile changes are present.

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills/git-publish core/agents/skills/change-request-publish core/agents/skills/brainstorm/SKILL.md core/agents/skills/planner/SKILL.md core/agents/skills/implement/SKILL.md core/agents/skills/finish/SKILL.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/opencode/agents/implement.md core/opencode/agents/finish.md core/claude/settings.json core/AGENTS.md scripts/init.sh scripts/copy.sh
git commit -m "feat: add guarded change request publication"
```

### Task 3: Upgrade Intake, Brainstorming, and Planning Skills

**Files:**
- Create: `core/agents/skills/idea/SKILL.md`
- Create: `core/agents/skills/idea/agents/openai.yaml`
- Modify: `core/agents/skills/brainstorm/SKILL.md`
- Modify: `core/agents/skills/brainstorm/visual-companion.md`
- Modify: `core/agents/skills/planner/SKILL.md`
- Create: `core/opencode/agents/idea.md`
- Modify: `core/opencode/agents/brainstorm.md`
- Modify: `core/opencode/agents/planner.md`
- Create: `core/docs/agents/idea.md`
- Modify: `core/docs/agents/brainstorm.md`
- Modify: `core/docs/agents/planner.md`

- [ ] **Step 1: Port the generic idea-intake workflow**

Adapt `bikes-local/.agents/skills/idea/SKILL.md` so it performs grounded owner dialogue, duplicate and related-issue discovery, proportional grilling, classification into actionable, later, or rejected outcomes, label-existence validation, exact approval before issue mutation, and a hard stop after the issue or rejection. Replace bikes-local's fixed business document names and label set with the documents and label taxonomy declared by `docs/agents/idea.md`; if the role document does not declare them, the skill must stop and request repository configuration. Keep owner-voice context read-only and keep specs, plans, code, commits, pushes, and PRs out of this workflow.

Create `agents/openai.yaml` with display name `Idea`, a portable one-line description, and `allow_implicit_invocation: false`.

- [ ] **Step 2: Upgrade brainstorm without importing downstream plan layout**

Port the sister skill's explicit argument handling, hard implementation gate, scoped Explore delegation, one-question-at-a-time clarification, two-to-three approach comparison, section-by-section approval, proportional design/domain grilling, placeholder and ambiguity self-review, and UI-design classification. Require exactly one `ui-design: required` or `ui-design: not-required` marker under `## UI Design` in every approved spec. Keep publication timing explicit: save and report the approved spec, and publish it only when the installed brainstorm contract requires publication, using `change-request-publish`; never embed raw push or provider CLI commands and never invoke planning automatically.

Retain the visual companion only as a just-in-time opt-in. Remove LAN, package, absolute-path, and repository-specific command assumptions; resolve companion assets relative to `.agents/skills/brainstorm/`.

- [ ] **Step 3: Upgrade planner while preserving one-file plans**

Port the sister skill's preflight branch check, focused Explore delegation, concrete file mapping, fork resolution, task right-sizing, explicit interfaces, zero unresolved implementation decisions, proportional grilling, and self-review. Keep one `plans/YYYY-MM-DD-feature-name/plan.md` containing checkbox tasks, rather than importing `planning-structure`. Keep each task mapped to one commit and preserve the toolkit's stack-aware verification rules.

- [ ] **Step 4: Make OpenCode files thin wrappers and role docs portable**

Reduce `idea.md`, `brainstorm.md`, and `planner.md` under `core/opencode/agents/` to descriptions, temperatures, least-privilege tool/skill permissions, and an instruction to invoke their canonical skill. In `core/docs/agents/idea.md`, define explicit configuration headings for owner-voice grounding documents, terminology documents, backlog provider, actionable labels, later-state labels, and adversarial lenses without supplying bikes-local values. Update brainstorm and planner role docs to declare their load and verification contracts and the portable `## UI Design` spec marker.

- [ ] **Step 5: Verify**

Run:

```bash
codespell core/agents/skills/idea core/agents/skills/brainstorm core/agents/skills/planner core/opencode/agents/idea.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/docs/agents/idea.md core/docs/agents/brainstorm.md core/docs/agents/planner.md
if rg -n '@bikes-local|apps/web|4322|/tmp/bikes-local|Vision\.md|Business-Concept|Revenue-Model|Risks-and-Assumptions|docs/features/index\.md' core/agents/skills/idea core/agents/skills/brainstorm core/agents/skills/planner core/opencode/agents/idea.md core/docs/agents/idea.md; then exit 1; fi
```

Expected: codespell passes and the portability scan returns no matches.

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/idea core/agents/skills/brainstorm core/agents/skills/planner core/opencode/agents/idea.md core/opencode/agents/brainstorm.md core/opencode/agents/planner.md core/docs/agents/idea.md core/docs/agents/brainstorm.md core/docs/agents/planner.md
git commit -m "feat: upgrade discovery and planning skills"
```

### Task 4: Add the Portable UI Design Workflow

**Files:**
- Create: `core/agents/skills/ui-design/SKILL.md`
- Create: `core/agents/skills/ui-design/agents/openai.yaml`
- Create: `core/agents/skills/ui-design-task/SKILL.md`
- Create: `core/agents/skills/ui-design-task/agents/openai.yaml`
- Create: `core/opencode/agents/ui-design.md`
- Create: `core/opencode/agents/ui-design-task.md`
- Create: `core/docs/agents/ui-design.md`
- Create: `core/docs/agents/ui-design-task.md`
- Modify: `core/skills-lock.json`
- Modify: `core/claude/settings.json`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Port the UI controller contract**

Adapt the current sister `ui-design` skill with these preserved gates: require `ui-design: required`; require an approved spec; run Impeccable Craft for direction; maintain a complete state, responsive, interaction, content, accessibility, simulated-integration, and deferred-work inventory; alternate implementation with explicit human feedback; permit only one bounded rendering check before each handoff; forbid autonomous browser work after handoff; gather screenshot, source-inspection, human-review, and accepted-limitation evidence; return to feedback after any evidence-driven code change; require explicit final approval; write the final handoff only after approval; defer correctness verification; create one final commit; and stop every preview process it started.

Invoke preview lifecycle operations only through the stable target-owned adapter:

```text
bash .agents/scripts/ui-design/preview.sh start
bash .agents/scripts/ui-design/preview.sh probe
bash .agents/scripts/ui-design/preview.sh stop
```

The target may implement those verbs directly or delegate them to another custom helper. Require `start` to be idempotent, `probe` to have a finite internal timeout and return nonzero when not ready, and `stop` to be idempotent and stop only a process whose ownership the adapter proves. The controller must call `stop` after success, failure, or cancellation whenever it called `start`. Load readiness/scenario URLs, source roots, test runner, screenshot location, and handoff path from `docs/agents/ui-design.md`; if the adapter or any required role value is missing, report the exact missing configuration and stop instead of guessing.

- [ ] **Step 2: Port the UI worker contract**

Adapt `ui-design-task` as a hidden, presentation-only worker. Its self-contained packet owns approved direction, exact file ownership, route/state/scenario/viewport context, constraints, deferred behavior, and completion criteria. It may inspect and edit only packet-owned presentation files, may not load the full spec or plan, may not run tests/lint/typecheck/build/browser automation, may not commit or dispatch, and must report `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT`, or `BLOCKED` with implemented work, files, and concerns.

Create both `agents/openai.yaml` files with portable display names/descriptions and `allow_implicit_invocation: false`.

- [ ] **Step 3: Add portable role configuration and wrappers**

Define `core/docs/agents/ui-design.md` with the fixed adapter path, its required `start`/`probe`/`stop` contract, and explicit fields for required guides, readiness URL or URL-generation rule, scenario/viewport inventory source, temporary screenshot location below `.temp/`, final handoff path, whether the target has supplied the adapter, and the repository's pre-commit rule. Keep framework commands, package names, ports, PID/state files, process fingerprints, logs, and timeout implementation inside the target-owned adapter rather than duplicating them in the role doc. Define `ui-design-task.md` with required guides and allowed presentation roots. State that a missing adapter plus blank or example role values are installation-time configuration errors, not permission to infer bikes-local-like defaults.

Create thin OpenCode wrappers. `ui-design` may edit, ask questions, invoke Explore and `ui-design-task`, invoke `ui-design` and `impeccable`, inspect git, run only the three exact preview-adapter commands, capture screenshots, and commit; it must deny the underlying package command, arbitrary `.agents/scripts/**` execution, raw process killing, Playwright test runs, push, destructive branch/worktree actions, and unrestricted mutation. `ui-design-task` must be hidden/subagent-only and deny edits by default. Document that a target repository must add its concrete presentation-root allowlist to the installed `.opencode/agents/ui-design-task.md`; the skill independently enforces packet ownership and the role-doc roots. `copy.sh` add/skip modes preserve that wrapper customization, while override mode reports replacement so the target can review and reapply its allowlist.

- [ ] **Step 4: Install Impeccable and wire both runtimes**

Add the sister repository's `impeccable` entry to `core/skills-lock.json` with source `pbakaus/impeccable`, source type `github`, skill path `.agents/skills/impeccable/SKILL.md`, and computed hash `e07098370ad7fd4605b67d305d8c06623a5c7d7737d2364e30932294ef880ff6`. Add `idea`, `ui-design`, and `ui-design-task` to the canonical authored inventory in both scripts. Add only `Bash(bash .agents/scripts/ui-design/preview.sh start)`, `Bash(bash .agents/scripts/ui-design/preview.sh probe)`, and `Bash(bash .agents/scripts/ui-design/preview.sh stop)` to Claude's preview permissions; do not grant an underlying pnpm/Maven command, application path, port, arbitrary helper glob, raw kill command, or Playwright test permission. Do not create `core/agents/scripts/ui-design/preview.sh`: the implementation is target-owned.

- [ ] **Step 5: Verify**

Run:

```bash
jq empty core/skills-lock.json core/claude/settings.json
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
codespell core/agents/skills/ui-design core/agents/skills/ui-design-task core/opencode/agents/ui-design.md core/opencode/agents/ui-design-task.md core/docs/agents/ui-design.md core/docs/agents/ui-design-task.md core/skills-lock.json core/claude/settings.json scripts/init.sh scripts/copy.sh
if rg -n '@bikes-local|apps/web|4322|/tmp/bikes-local|astro|pnpm --filter' core/agents/skills/ui-design core/agents/skills/ui-design-task core/opencode/agents/ui-design.md core/opencode/agents/ui-design-task.md core/docs/agents/ui-design.md core/docs/agents/ui-design-task.md; then exit 1; fi
```

Create one clean base fixture and clone it for each copy mode, then run:

```bash
mkdir -p .temp/ui-preview-preservation/base/.agents/scripts/ui-design .temp/ui-preview-preservation/base/.opencode/agents
printf '%s\n' '#!/usr/bin/env bash' 'printf "project-preview:%s\\n" "$1"' > .temp/ui-preview-preservation/base/.agents/scripts/ui-design/preview.sh
printf '%s\n' '---' 'description: Project-owned UI worker' '---' 'project marker' > .temp/ui-preview-preservation/base/.opencode/agents/ui-design-task.md
git -C .temp/ui-preview-preservation/base init
git -C .temp/ui-preview-preservation/base add .
git -C .temp/ui-preview-preservation/base -c user.name='Smoke Test' -c user.email='smoke@example.com' commit -m 'test: add project UI customization'
git clone --quiet .temp/ui-preview-preservation/base .temp/ui-preview-preservation/add
git clone --quiet .temp/ui-preview-preservation/base .temp/ui-preview-preservation/override
git clone --quiet .temp/ui-preview-preservation/base .temp/ui-preview-preservation/skip
printf '1\n1\n2\n' | bash scripts/copy.sh .temp/ui-preview-preservation/add
printf '1\n1\n3\n' | bash scripts/copy.sh .temp/ui-preview-preservation/override | tee .temp/ui-preview-preservation/override-output.txt
printf '1\n1\n1\n' | bash scripts/copy.sh .temp/ui-preview-preservation/skip
for mode in add override skip; do
  cmp .temp/ui-preview-preservation/base/.agents/scripts/ui-design/preview.sh ".temp/ui-preview-preservation/$mode/.agents/scripts/ui-design/preview.sh"
done
cmp .temp/ui-preview-preservation/base/.opencode/agents/ui-design-task.md .temp/ui-preview-preservation/add/.opencode/agents/ui-design-task.md
cmp .temp/ui-preview-preservation/base/.opencode/agents/ui-design-task.md .temp/ui-preview-preservation/skip/.opencode/agents/ui-design-task.md
if cmp -s .temp/ui-preview-preservation/base/.opencode/agents/ui-design-task.md .temp/ui-preview-preservation/override/.opencode/agents/ui-design-task.md; then exit 1; fi
rg -q '\.opencode/agents/ui-design-task\.md \(overwritten\)' .temp/ui-preview-preservation/override-output.txt
rm -rf .temp/ui-preview-preservation
```

Expected: syntax, shellcheck, spelling, and the fail-on-match portability scan pass; the exact preview permissions are present in both runtimes; no toolkit-owned adapter implementation exists; all three copy modes preserve the project helper, and wrapper customization follows the selected mode.

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/ui-design core/agents/skills/ui-design-task core/opencode/agents/ui-design.md core/opencode/agents/ui-design-task.md core/docs/agents/ui-design.md core/docs/agents/ui-design-task.md core/skills-lock.json core/claude/settings.json scripts/init.sh scripts/copy.sh
git commit -m "feat: add portable UI design workflows"
```

### Task 5: Upgrade Diagnosis and Implementation Skills

**Files:**
- Modify: `core/agents/skills/bugfix/SKILL.md`
- Modify: `core/agents/skills/bugfix/scripts/create-bug-issue.sh`
- Modify: `core/agents/skills/bugfix/scripts/update-bug-issue.sh`
- Modify: `core/agents/skills/implement/SKILL.md`
- Modify: `core/agents/skills/implement-task/SKILL.md`
- Modify: `core/agents/skills/verification-before-completion/SKILL.md`
- Modify: `core/opencode/agents/bugfix.md`
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/implement-task.md`
- Modify: `core/docs/agents/bugfix.md`
- Modify: `core/docs/agents/implement.md`
- Modify: `core/docs/agents/implement-task.md`

- [ ] **Step 1: Upgrade root-cause analysis**

Port the sister bugfix skill's input classification, reproduction/confirmation step, backward data-flow tracing, boundary inspection, working-example comparison, single-hypothesis discipline, structured evidence issue body, follow-up update flow, and no-fix/no-commit boundary. Read verification commands, logs, data helpers, and debugging tools only from `docs/agents/bugfix.md`; stop when required repo-specific investigation configuration is absent. Keep the existing neutral issue-mutation wrappers and `.temp/` scratch convention rather than the sister repository's paths or helper names.

- [ ] **Step 2: Upgrade controller and worker boundaries**

Port the sister implementation controller's preflight plan review, durable checkbox progress, lean self-contained worker packets, disjoint-file parallelism rule, one primary commit per task, `NEEDS_CONTEXT` correction, three-attempt `BLOCKED` escalation, cannot-verify handling, worker-boundary correction routing, and final reconciliation limited to implementation-completion concerns. Keep holistic branch review in `review-code`. After all task commits and fresh final verification, publication may occur only through `change-request-publish`; never call raw push or a provider CLI, and never use retained-head mode without explicit human authorization.

Make `implement-task` own exactly one plan task, edit only assigned files, run role-defined verification, avoid commits and subdelegation, and return the sister workflow's structured status report. Update `verification-before-completion` to require fresh command output, distinguish failed from unavailable checks, and reject claims based only on worker reports.

- [ ] **Step 3: Thin the wrappers and strengthen role contracts**

Move workflow prose out of the three OpenCode agents and leave permissions plus canonical skill invocation. Update role docs to own repository verification commands, scratch paths, database/log helpers, implementation boundaries, and any worker-specific allowed paths. Preserve the pnpm and Maven verification additions already present in `stacks/*/docs/agents/`. Their headings and installed paths do not change, so this task does not modify stack overlays.

- [ ] **Step 4: Verify**

Run:

```bash
shellcheck core/agents/skills/bugfix/scripts/create-bug-issue.sh core/agents/skills/bugfix/scripts/update-bug-issue.sh
bash -n core/agents/skills/bugfix/scripts/create-bug-issue.sh core/agents/skills/bugfix/scripts/update-bug-issue.sh
codespell core/agents/skills/bugfix core/agents/skills/implement core/agents/skills/implement-task core/agents/skills/verification-before-completion core/opencode/agents/bugfix.md core/opencode/agents/implement.md core/opencode/agents/implement-task.md core/docs/agents/bugfix.md core/docs/agents/implement.md core/docs/agents/implement-task.md
if rg -n '@bikes-local|apps/web|/tmp/bikes-local|pnpm|mvn' core/agents/skills/bugfix core/agents/skills/implement core/agents/skills/implement-task core/agents/skills/verification-before-completion; then exit 1; fi
```

Expected: all checks pass; stack command names appear only in role overlays, not reusable skills.

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills/bugfix core/agents/skills/implement core/agents/skills/implement-task core/agents/skills/verification-before-completion core/opencode/agents/bugfix.md core/opencode/agents/implement.md core/opencode/agents/implement-task.md core/docs/agents/bugfix.md core/docs/agents/implement.md core/docs/agents/implement-task.md
git commit -m "feat: strengthen implementation workflow boundaries"
```

### Task 6: Upgrade Review, Finish, and Supporting Skills

**Files:**
- Modify: `core/agents/skills/review-plan/SKILL.md`
- Modify: `core/agents/skills/review-code/SKILL.md`
- Modify: `core/agents/skills/finish/SKILL.md`
- Modify: `core/agents/skills/feature-documentation/SKILL.md`
- Modify: `core/agents/skills/grill-with-docs/SKILL.md`
- Modify: `core/agents/skills/github-pr-comments/SKILL.md`
- Modify: `core/agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh`
- Modify: `core/agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh`
- Modify: `core/opencode/agents/review-plan.md`
- Modify: `core/opencode/agents/review-code.md`
- Modify: `core/opencode/agents/finish.md`
- Modify: `core/docs/agents/review-plan.md`
- Modify: `core/docs/agents/review-code.md`
- Modify: `core/docs/agents/finish.md`

- [ ] **Step 1: Port review workflow improvements**

Adapt the sister review skills to start from the correct base/head diff, fetch PR feedback through the neutral comment helper, validate external claims against local code, deduplicate and prioritize findings, distinguish blocking correctness issues from optional improvements, preserve existing plan reviews instead of overwriting them, and keep review-code's whole-branch scope separate from implementation reconciliation. Use Explore only for focused repository questions and require explicit approval before posting replies or editing code in a review-only session.

- [ ] **Step 2: Port compact conditional finish documentation**

Change finish from always writing a feature document to independently deciding whether to create, update, merge, rename, remove, or omit a compact capability map. Adapt the sister feature-documentation rules so maps start from changed package/module roots, list stable entry points, include only directly constraining non-obvious ADRs, synchronize the feature index atomically, and never reproduce architecture, schemas, configuration inventories, tests, history, status, or verification logs. Use the toolkit's current `docs/features/README.md` index instead of bikes-local's `docs/features/index.md`.

Keep finish gated on completed implementation and review, role-defined fresh verification, domain reconciliation only when terminology or hard-to-reverse decisions changed, and plan cleanup only after durable outputs are complete. Route any final publication through `change-request-publish`; preserve an existing request's readiness unless the user explicitly asks to mark it ready after fresh verification.

- [ ] **Step 3: Port generic grilling and PR-comment improvements**

Teach `grill-with-docs` to distinguish engineering artifacts from business ideas, place owner-voice grilling output in the calling artifact, and never edit owner-authored business context. Keep glossary and ADR formats inside this authored skill rather than importing bikes-local's additional remote `grilling` and `domain-modeling` dependencies.

Port the PR helper's compact default view of conversation comments and unresolved inline threads, `thread_id` reply targets, `--all`, `--diff-only`, and last-resort `--json` modes, fork-safe `GH_REPO`, outdated-anchor guidance, exact batch approval, and suppressed created-comment response. Preserve neutral repository naming and the rule that only inline threads are replyable by the bundled mutation helper.

- [ ] **Step 4: Verify scripts and prose**

Run:

```bash
shellcheck core/agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh core/agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh
bash -n core/agents/skills/github-pr-comments/scripts/fetch-pr-comments.sh core/agents/skills/github-pr-comments/scripts/reply-to-pr-comment.sh
codespell core/agents/skills/review-plan core/agents/skills/review-code core/agents/skills/finish core/agents/skills/feature-documentation core/agents/skills/grill-with-docs core/agents/skills/github-pr-comments core/opencode/agents/review-plan.md core/opencode/agents/review-code.md core/opencode/agents/finish.md core/docs/agents/review-plan.md core/docs/agents/review-code.md core/docs/agents/finish.md
if rg -n '@bikes-local|apps/web|/tmp/bikes-local|docs/features/index\.md' core/agents/skills/review-plan core/agents/skills/review-code core/agents/skills/finish core/agents/skills/feature-documentation core/agents/skills/grill-with-docs core/agents/skills/github-pr-comments; then exit 1; fi
```

Expected: all checks pass and the portability scan returns no matches.

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills/review-plan core/agents/skills/review-code core/agents/skills/finish core/agents/skills/feature-documentation core/agents/skills/grill-with-docs core/agents/skills/github-pr-comments core/opencode/agents/review-plan.md core/opencode/agents/review-code.md core/opencode/agents/finish.md core/docs/agents/review-plan.md core/docs/agents/review-code.md core/docs/agents/finish.md
git commit -m "feat: refine review and finish workflows"
```

### Task 7: Synchronize Inventories and Smoke-Test Installed Output

**Files:**
- Modify: `README.md`
- Modify: `core/AGENTS.md`
- Modify: `core/claude/README.md`
- Modify: `core/docs/agents/agent-workflow-extension.md`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Update public inventories and architecture documentation**

Document the canonical `.agents/skills` source model, the complete OpenCode agent inventory, the complete Claude symlink inventory, support/worker visibility, `idea -> brainstorm -> optional ui-design -> planner` workflow order, draft-first provider-neutral publication, the explicitly authorized retained-head lease exception, UI-design's preview-first verification exception, and how a target supplies or delegates `.agents/scripts/ui-design/preview.sh`. Document that `copy.sh` preserves this target-owned adapter in every skill mode while wrapper overrides may require reapplying presentation-root permissions. Update the dot-mapping explanation without changing the mapping itself. State that `core/skills-lock.json` gains Impeccable while the repository's self-maintenance `skills-lock.json` does not, and that the two publication skills are authored so neither lockfile tracks them.

- [ ] **Step 2: Add installer regression assertions**

Extend existing init/copy smoke coverage so a fresh pnpm target and a fresh Maven target contain all canonical `.agents/skills` directories, including `git-publish` and `change-request-publish`, relative Claude symlinks, new OpenCode agents, new role docs, exact preview-adapter permissions, and the Impeccable lock entry, but no toolkit-supplied `.agents/scripts/ui-design/preview.sh`. Add an existing-target copy scenario that proves `add` preserves an existing canonical skill, `override` replaces it, `skip` adds nothing, symlink reconciliation never replaces unrelated user content without the selected mode authorizing it, and every mode preserves a target-owned preview adapter.

- [ ] **Step 3: Run the complete repository verification baseline**

Create smoke targets only under `.temp/`, then run:

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh core/agents/skills/bugfix/scripts/*.sh core/agents/skills/github-pr-comments/scripts/*.sh core/agents/skills/git-publish/scripts/*.sh core/agents/skills/git-publish/test/*.sh core/agents/skills/change-request-publish/scripts/*.sh core/agents/skills/change-request-publish/test/*.sh
jq empty opencode.json core/opencode.json core/skills-lock.json skills-lock.json core/claude/settings.json stacks/pnpm/opencode.json stacks/maven/opencode.json stacks/pnpm/claude/settings.json stacks/maven/claude/settings.json
codespell README.md core/AGENTS.md core/claude/README.md core/docs/agents core/agents/skills core/opencode/agents scripts/init.sh scripts/copy.sh
if rg -n '@bikes-local|apps/web|4322|/tmp/bikes-local|@bikes-local/web' README.md core/AGENTS.md core/claude/README.md core/docs/agents core/agents/skills core/opencode/agents scripts/init.sh scripts/copy.sh; then exit 1; fi
```

Run the two fresh installs and assert the complete authored inventory and adapter boundary:

```bash
mkdir -p .temp
printf '1\n1\n.temp/skill-smoke-pnpm\n' | bash scripts/init.sh
printf '2\n1\n.temp/skill-smoke-maven\n' | bash scripts/init.sh
authored_skills='brainstorm bugfix change-request-publish feature-documentation finish git-publish github-pr-comments grill-with-docs idea implement implement-task planner review-code review-plan ui-design ui-design-task verification-before-completion'
for target in .temp/skill-smoke-pnpm .temp/skill-smoke-maven; do
  for skill_name in $authored_skills; do
    test -f "$target/.agents/skills/$skill_name/SKILL.md"
    test "$(readlink "$target/.claude/skills/$skill_name")" = "../../.agents/skills/$skill_name"
  done
  test -f "$target/.opencode/agents/idea.md"
  test -f "$target/.opencode/agents/ui-design.md"
  test -f "$target/.opencode/agents/ui-design-task.md"
  test -f "$target/docs/agents/idea.md"
  test -f "$target/docs/agents/ui-design.md"
  test -f "$target/docs/agents/ui-design-task.md"
  jq -e '.skills.impeccable.source == "pbakaus/impeccable"' "$target/skills-lock.json"
  test ! -e "$target/.agents/scripts/ui-design/preview.sh"
done
```

Create three clean existing-target fixtures with a marker skill, a non-symlink Claude customization, and a target-owned preview adapter; then run the exact copy modes:

```bash
mkdir -p .temp/skill-smoke-copy-base/.agents/skills/brainstorm .temp/skill-smoke-copy-base/.agents/scripts/ui-design .temp/skill-smoke-copy-base/.claude/skills/brainstorm
printf '%s\n' 'project skill marker' > .temp/skill-smoke-copy-base/.agents/skills/brainstorm/SKILL.md
printf '%s\n' 'project Claude marker' > .temp/skill-smoke-copy-base/.claude/skills/brainstorm/KEEP.md
printf '%s\n' '#!/usr/bin/env bash' 'printf "project-preview:%s\\n" "$1"' > .temp/skill-smoke-copy-base/.agents/scripts/ui-design/preview.sh
git -C .temp/skill-smoke-copy-base init
git -C .temp/skill-smoke-copy-base add .
git -C .temp/skill-smoke-copy-base -c user.name='Smoke Test' -c user.email='smoke@example.com' commit -m 'test: add existing customization'
git clone --quiet .temp/skill-smoke-copy-base .temp/skill-smoke-copy-add
git clone --quiet .temp/skill-smoke-copy-base .temp/skill-smoke-copy-override
git clone --quiet .temp/skill-smoke-copy-base .temp/skill-smoke-copy-skip
printf '1\n1\n2\n' | bash scripts/copy.sh .temp/skill-smoke-copy-add
printf '1\n1\n3\n' | bash scripts/copy.sh .temp/skill-smoke-copy-override
printf '1\n1\n1\n' | bash scripts/copy.sh .temp/skill-smoke-copy-skip
rg -q 'project skill marker' .temp/skill-smoke-copy-add/.agents/skills/brainstorm/SKILL.md
rg -q 'project skill marker' .temp/skill-smoke-copy-skip/.agents/skills/brainstorm/SKILL.md
if rg -q 'project skill marker' .temp/skill-smoke-copy-override/.agents/skills/brainstorm/SKILL.md; then exit 1; fi
test -f .temp/skill-smoke-copy-add/.claude/skills/brainstorm/KEEP.md
test -f .temp/skill-smoke-copy-skip/.claude/skills/brainstorm/KEEP.md
test "$(readlink .temp/skill-smoke-copy-override/.claude/skills/brainstorm)" = '../../.agents/skills/brainstorm'
for mode in add override skip; do
  cmp .temp/skill-smoke-copy-base/.agents/scripts/ui-design/preview.sh ".temp/skill-smoke-copy-$mode/.agents/scripts/ui-design/preview.sh"
done
rm -rf .temp/skill-smoke-pnpm .temp/skill-smoke-maven .temp/skill-smoke-copy-base .temp/skill-smoke-copy-add .temp/skill-smoke-copy-override .temp/skill-smoke-copy-skip
```

Expected: all commands pass; README inventories exactly match installed files; core and stack output contain no bikes-local identifiers; both lockfiles remain in their intended scopes; all symlinks resolve.

- [ ] **Step 4: Commit**

```bash
git add README.md core/AGENTS.md core/claude/README.md core/docs/agents/agent-workflow-extension.md scripts/init.sh scripts/copy.sh
git commit -m "docs: document canonical workflow skills"
```
