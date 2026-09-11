# PR #2 Review Findings — Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Source:** Review of PR #2 (`feature/portable-sister-skill-upgrade`), 2026-08-24. All 29 unresolved inline threads were verified against the current checkout; none was dismissed. This plan implements the approved findings and records the disposition of every tracked remark.

**Goal:** Repair the rename fallout bug, align publication with the owner's revised direction (GitHub-only, self-contained, bats-tested), restore the sister repository's skill references and lockfile entries, enforce the role-doc/agent/skill content boundaries, and correct inventory documentation — without touching stack overlays or the self-maintenance `skills-lock.json`.

**Amended plan decisions** (these reverse explicit decisions in `plan.md`; recorded here as the new requirements source):

1. **GitHub-only publication.** `change-request-publish` drops provider detection and all GitLab/`glab` paths. It becomes self-contained: the guarded retained-head push logic is copied into `publish-change-request.sh` rather than reached into `git-publish` via a relative script path. This resolves inline threads 3839515744 (GitHub only) and 3839332145 (tight coupling) together. `git-publish` remains a separate skill for plain branch publication.
2. **bats-based tests.** The two bespoke bash harnesses are replaced by bats files with shared stub/fixture helpers, per threads 3839308402 and 3839349845. This also retires the shellcheck failures (SC2294/SC2329) in the old harnesses.
3. **Sister-repo skill references restored.** `grill-with-docs` references `/grilling` and the domain-modeling skill; `planner` and `review-code` reference the planning-structure skill; the required remote skills are added to `core/skills-lock.json`, per threads 3839525897, 3839526856, 3839529076, 3839544470, 3839545745, and 3839584644.

**Configuration surface:** `core/opencode/agents/{finish,review-code,review-plan,implement,implement-task}.md`, `core/agents/skills/{change-request-publish,git-publish,grill-with-docs,planner,review-code,ui-design}/`, `core/agents/skills/{change-request-publish,git-publish}/test/`, `core/docs/agents/{brainstorm,bugfix,planner,ui-design,implement,implement-task}.md`, `core/docs/agents/agent-workflow-extension.md`, `core/AGENTS.md`, `core/claude/README.md`, `core/skills-lock.json`, `core/claude/settings.json`, `README.md`; validate with `bash -n`, `shellcheck`, `bats`, `jq`, `codespell`, reference-resolution checks, and the installer smoke suite.

## Remark and finding ledger

Every tracked item maps to a task below or to an explicit unresolved status.

| Item | Disposition |
|---|---|
| 3839283174 `die()` → `exitWithError()` (publish-change-request.sh) | Task 2 |
| 3839345215 `die()` → `exitWithError()` (push-branch.sh) | Task 2 |
| 3839332145 cross-skill coupling | Task 2 (resolved by GitHub-only self-containment) |
| 3839515744 GitHub-only publication | Task 2 |
| 3839308402 bats + stub helper (change-request-publish) | Task 3 |
| 3839349845 bats (git-publish) | Task 3 |
| 3839352179 git-publish SKILL.md describes call sites | Task 2 |
| 3839353024 git-publish SKILL.md missing parameter docs | Task 2 |
| 3839525897 `/grilling` reference (line 7) | Task 4 |
| 3839526856 `/grilling` reference (line 23) | Task 4 |
| 3839529076 domain-modeling reference lost | Task 4 |
| 3839544470 planner misses planning-structure reference | Task 4 |
| 3839545745 review-code misses planning-structure reference | Task 4 |
| 3839584644 lockfile missing grilling + domain-modeling | Task 4 |
| 3839554545 `## The 17 authored skills` → `## Skills` | Task 7 |
| 3839555739 "All 17 authored skills" count removal | Task 7 |
| 3839557821 extension-doc count removal | Task 7 |
| 3839561309 bugfix.md placeholder needs replace-TODO | Task 5 |
| 3839564619 planner.md Spec Contract is skill content | Task 5 |
| 3839566023 implement.md Verify prose is skill content | Task 5 |
| 3839567064 implement-task.md back reference | Task 5 |
| 3839568166 brainstorm.md Spec Contract is skill content | Task 5 |
| 3839568660 brainstorm.md Verification is skill content | Task 5 |
| 3839570812 ui-design.md Verify is skill content | Task 5 |
| 3839573770 finish agent should invoke finish skill | Task 6 |
| 3839576068 implement-task agent role-doc line belongs in skill | Task 6 |
| 3839577648 implement agent role-doc line belongs in skill | Task 6 |
| 3839579683 review-code agent should invoke review-code skill | Task 6 |
| 3839580631 review-plan agent should invoke review-plan skill | Task 6 |
| Finding B1: stale `workflow-verification` permission | Task 1 |
| Finding B2: shellcheck SC2294/SC2329 in old harnesses | Task 3 (harnesses replaced) |
| Finding A5: PR #3 merged into branch (mixed scope) | Unresolved by design — sync-merge `main` before merging PR #2; no code task |
| Finding A6: unprefixed commit messages (`Update …`) | Unresolved — historical commits; no history rewrite |
| Finding A7a: `settings.json` indentation + duplicate force-push ask/deny entries | Task 2 (hygiene while editing permission docs) |
| Finding A7b: `scripts/test-installer.sh` misleading usage error + undocumented | Unresolved — awaits owner decision |

---

### Task 1: Fix the finish agent's stale skill permission

**Files:**
- Modify: `core/opencode/agents/finish.md`

- [ ] **Step 1:** In the `skill:` permission block, replace `"workflow-verification": allow` with `"verification-before-completion": allow`. No other frontmatter change.

- [ ] **Step 2: Verify**

```bash
if rg -n 'workflow-verification' core/ README.md; then exit 1; fi
rg -q '"verification-before-completion": allow' core/opencode/agents/finish.md
```

- [ ] **Step 3: Commit**

```bash
git add core/opencode/agents/finish.md
git commit -m "fix: point finish agent at renamed verification skill"
```

### Task 2: GitHub-only, self-contained change-request publication

**Files:**
- Modify: `core/agents/skills/change-request-publish/scripts/publish-change-request.sh`
- Modify: `core/agents/skills/change-request-publish/test/publish-change-request.sh`
- Modify: `core/agents/skills/git-publish/scripts/push-branch.sh`
- Modify: `core/agents/skills/git-publish/SKILL.md`
- Modify: `core/agents/skills/change-request-publish/SKILL.md`
- Modify: `core/AGENTS.md`
- Modify: `core/docs/agents/agent-workflow-extension.md`
- Modify: `core/claude/README.md`
- Modify: `core/claude/settings.json`
- Modify: `README.md`
- Modify: `core/opencode/agents/finish.md`, `core/opencode/agents/implement.md`, `core/opencode/agents/review-code.md`, `core/opencode/agents/review-plan.md` (only where they mention GitLab/`glab`/provider neutrality)

- [ ] **Step 1: Strip provider detection and GitLab paths from the script**

Remove `detect_provider`'s GitLab branch and every `glab` invocation. The script operates on GitHub only: fail closed when origin is not a GitHub host. Drop the `GIT_PUBLISH_SCRIPT` variable and the `exec` delegation; for `--update-existing-head`, copy the guarded push from `push-branch.sh` (branch-name validation, SHA validation, protected/default-branch rejection, detached-HEAD rejection, exactly one `git push --force-with-lease="refs/heads/$head_branch:$expected_sha" origin "HEAD:refs/heads/$head_branch"`, no weaker-force fallback, no retry). Rename `die` to `exitWithError` in this script and in `push-branch.sh`.

- [ ] **Step 2: Rewrite the two SKILL.md files**

`change-request-publish/SKILL.md`: describe GitHub pull-request publication (draft creation, idempotent URL printing, `--mark-ready <verified-sha>`, `--update-existing-head <head-branch> <expected-sha>`), removing "provider-neutral" and MR wording. `git-publish/SKILL.md`: describe what the skill does (guarded branch publication, protected-branch rejection, lease-safe retained-head update semantics) instead of who calls it, and document both modes' parameters and guards explicitly.

- [ ] **Step 3: Prune GitLab cases from the existing harness**

Delete the GitLab fixture cases from `test/publish-change-request.sh` so the suite stays green until Task 3 replaces it. Add a case asserting the unsupported-host failure for a non-GitHub origin URL.

- [ ] **Step 4: Synchronize documentation**

Update `core/AGENTS.md` (permissions paragraph: drop `glab mr create`), `core/docs/agents/agent-workflow-extension.md` (retitle the publication section to GitHub draft-first publication; drop MR wording), `core/claude/README.md` (support-skills table row and shared-skills list), and `README.md` (hidden-skills table row). Sweep the four OpenCode agents for `glab`/GitLab/provider-neutral phrasing. While editing `core/claude/settings.json`: fix the line-45 indentation glitch and remove the duplicate `git push --force` / `git push -f` entries from the `ask` list (they are already denied).

- [ ] **Step 5: Verify**

```bash
bash -n core/agents/skills/change-request-publish/scripts/publish-change-request.sh core/agents/skills/git-publish/scripts/push-branch.sh core/agents/skills/change-request-publish/test/publish-change-request.sh
shellcheck core/agents/skills/change-request-publish/scripts/publish-change-request.sh core/agents/skills/git-publish/scripts/push-branch.sh
codespell core/agents/skills/change-request-publish core/agents/skills/git-publish core/AGENTS.md core/docs/agents/agent-workflow-extension.md core/claude/README.md README.md
mkdir -p .temp/review-findings-smoke
bash core/agents/skills/change-request-publish/test/publish-change-request.sh .temp/review-findings-smoke/change-request
rm -rf .temp/review-findings-smoke
if rg -in 'glab|gitlab|provider-neutral' core/agents/skills/change-request-publish core/agents/skills/git-publish core/AGENTS.md core/docs/agents/agent-workflow-extension.md core/claude/README.md README.md core/opencode/agents stacks/; then exit 1; fi
if rg -q 'GIT_PUBLISH_SCRIPT' core/agents/skills/change-request-publish/scripts/publish-change-request.sh; then exit 1; fi
```

Expected: harness passes all remaining cases including the new unsupported-host case; no GitLab or provider-neutral wording remains in core, README, or stack overlays (verified clean at plan time — stack settings are additive overlays with no publication entries); no cross-skill script reference remains.

- [ ] **Step 6: Commit**

```bash
git add core/agents/skills/change-request-publish core/agents/skills/git-publish core/AGENTS.md core/docs/agents/agent-workflow-extension.md core/claude/README.md core/claude/settings.json README.md core/opencode/agents
git commit -m "feat: make change request publication GitHub-only and self-contained"
```

### Task 3: Migrate publication tests to bats

**Files:**
- Create: `core/agents/skills/git-publish/test/push-branch.bats`
- Create: `core/agents/skills/git-publish/test/helpers/stubs.bash`
- Create: `core/agents/skills/change-request-publish/test/publish-change-request.bats`
- Create: `core/agents/skills/change-request-publish/test/helpers/stubs.bash`
- Delete: `core/agents/skills/git-publish/test/push-branch.sh`
- Delete: `core/agents/skills/change-request-publish/test/publish-change-request.sh`

- [ ] **Step 1: Extract shared fixtures and stubs into helper files**

Move the bare-remote initialization, scoped-branch setup, and stub `gh` executable builders into `test/helpers/stubs.bash` per skill, loaded from the `.bats` files with `load 'helpers/stubs'`. All scratch state stays under a caller-supplied root below `.temp/`; teardown removes only named fixture directories.

- [ ] **Step 2: Port every case to bats**

Preserve full coverage parity with the old harnesses, minus the removed GitLab cases: normal scoped push; default-branch, master, and detached-HEAD rejection (both modes); new draft PR creation; existing-request idempotent URL printing; readiness preservation; `--mark-ready` success at the supplied verified SHA, wrong-SHA rejection, and malformed-SHA rejection; unsupported-host failure; complete/malformed retained-head arguments; closed-request and head-mismatch rejection; exact fully qualified lease and refspec; stale lease performing exactly one failed push with the remote unchanged.

- [ ] **Step 3: Verify**

Prerequisite: bats-core installed (`brew install bats-core`).

```bash
rm -rf .temp/review-findings-bats && mkdir -p .temp/review-findings-bats
SCRATCH="$PWD/.temp/review-findings-bats" bats core/agents/skills/git-publish/test/push-branch.bats
SCRATCH="$PWD/.temp/review-findings-bats" bats core/agents/skills/change-request-publish/test/publish-change-request.bats
shellcheck core/agents/skills/git-publish/test/helpers/stubs.bash core/agents/skills/change-request-publish/test/helpers/stubs.bash
bash -n core/agents/skills/git-publish/test/push-branch.bats core/agents/skills/change-request-publish/test/publish-change-request.bats
rm -rf .temp/review-findings-bats
if find core/agents/skills/*/test -name '*.sh' | rg -q 'publish-change-request|push-branch'; then exit 1; fi
```

Expected: all bats cases pass; shellcheck exits 0 on every remaining script (finding B2 retired with the old harnesses).

- [ ] **Step 4: Commit**

```bash
git add core/agents/skills/git-publish/test core/agents/skills/change-request-publish/test
git commit -m "test: migrate publication harnesses to bats with shared stubs"
```

### Task 4: Restore sister-repo skill references and lockfile entries

**Files:**
- Modify: `core/agents/skills/grill-with-docs/SKILL.md`
- Modify: `core/agents/skills/planner/SKILL.md`
- Modify: `core/agents/skills/review-code/SKILL.md`
- Modify: `core/skills-lock.json`
- Modify: `README.md` (lockfile-scope sentence)
- Modify: `core/claude/README.md` (remote-skills list)

- [ ] **Step 1: Restore the grilling and domain-modeling references**

In `grill-with-docs/SKILL.md` line 7, use: `Run a /grilling session about the artifact at hand.` On line 23, use: `- **Business ideas and other non-engineering artifacts**: run the /grilling`. In the engineering-artifacts bullet (line 20 area), restore the domain-modeling skill reference so engineering-artifact sessions invoke domain modeling the way the sister repo does.

- [ ] **Step 2: Restore the planning-structure reference**

Add the planning-structure skill reference to `planner/SKILL.md` and `review-code/SKILL.md` at the same positions and wording the sister repository uses (Load-first section), so both workflows load the planning-structure skill like the sister repo.

- [ ] **Step 3: Install the referenced remote skills**

Copy the `grilling` and `domain-modeling` entries (source, sourceType, skillPath, computedHash) from the sister repository's `skills-lock.json` into `core/skills-lock.json`. If the planning-structure skill is remote in the sister repo, add its entry the same way; if it is authored there, vendor it under `core/agents/skills/planning-structure/` following the authored-skill conventions (frontmatter `name`/`description`, installer inventory addition in `scripts/init.sh` and `scripts/copy.sh`, Claude symlink via the canonical flow, and additions to the skill lists in `README.md` and `core/claude/README.md`). Update the lockfile-scope sentences that enumerate tracked skills: root `README.md` ("Currently tracks `context7-cli`, `impeccable` …, and `writing-skills`") and the remote-skills list in `core/claude/README.md`. Do not modify the self-maintenance `skills-lock.json`.

- [ ] **Step 4: Verify**

```bash
jq empty core/skills-lock.json
rg -q '/grilling' core/agents/skills/grill-with-docs/SKILL.md
rg -qi 'domain-modeling' core/agents/skills/grill-with-docs/SKILL.md
rg -q 'planning-structure' core/agents/skills/planner/SKILL.md
rg -q 'planning-structure' core/agents/skills/review-code/SKILL.md
for entry in grilling domain-modeling; do
  jq -e --arg k "$entry" '.skills[$k].source' core/skills-lock.json >/dev/null || { echo "Missing lockfile entry: $entry" >&2; exit 1; }
done
status=0
for skill_dir in core/agents/skills/*/; do
  name="$(basename "$skill_dir")"
  refs="$(rg -o '/[a-z0-9]+(-[a-z0-9]+)*' "$skill_dir/SKILL.md" 2>/dev/null | sort -u | sed 's|^/||')"
  for ref in $refs; do
    if ! test -d "core/agents/skills/$ref" && ! jq -e --arg r "$ref" '.skills[$r]' core/skills-lock.json >/dev/null 2>&1; then
      printf 'Unresolved skill reference /%s (from %s)\n' "$ref" "$name" >&2
      status=1
    fi
  done
done
test "$status" -eq 0
codespell core/agents/skills/grill-with-docs core/agents/skills/planner core/agents/skills/review-code core/skills-lock.json README.md core/claude/README.md
```

Expected: lockfile parses; every `/skill` reference inside authored SKILL.md files resolves to an authored directory or a lockfile entry; spelling passes.

- [ ] **Step 5: Commit**

```bash
git add core/agents/skills/grill-with-docs core/agents/skills/planner core/agents/skills/review-code core/skills-lock.json README.md core/claude/README.md
git commit -m "feat: restore sister-repo grilling, domain-modeling, and planning-structure references"
```

(Extend the `git add` paths with `scripts/init.sh scripts/copy.sh core/agents/skills/planning-structure` in the vendored-authoring case.)

### Task 5: Enforce role-doc content boundaries

**Files:**
- Modify: `core/docs/agents/brainstorm.md`
- Modify: `core/docs/agents/bugfix.md`
- Modify: `core/docs/agents/planner.md`
- Modify: `core/docs/agents/ui-design.md`
- Modify: `core/docs/agents/implement.md`
- Modify: `core/docs/agents/implement-task.md`
- Modify: `core/agents/skills/ui-design/SKILL.md` (only if the Verify prose moved from the role doc is not already in the skill)

- [ ] **Step 1: Remove skill-owned sections from role docs**

Role docs keep only Load lists, Area Docs placeholders, and repository-specific configuration. Delete `## Spec Contract` and `## Verification` from `brainstorm.md` (lines 14-41) and `## Spec Contract` from `planner.md` (lines 19-24) — the skills already own the `## UI Design` marker contract and self-review gates. In `ui-design.md`, move the `## Verify` prose (lines 9-13) into `core/agents/skills/ui-design/SKILL.md` if absent there, and keep the adapter commands plus Required fields in the role doc.

- [ ] **Step 2: Trim implement role docs to commands and configuration**

`implement.md` `## Verify` keeps only the command block (drop "Run focused package tests while iterating." and "Before completion, run the full verification baseline:" — timing rules live in the implement skill). Delete the back-reference sentence at `implement-task.md` line 20. In `bugfix.md`, add an explicit replacement TODO directly above the placeholder commands: instruct targets to replace `<package-manager>` with their package manager.

- [ ] **Step 3: Verify**

```bash
codespell core/docs/agents
if rg -n 'Spec Contract|follow the UI-design preflight procedure|The controller owns the root baseline' core/docs/agents/brainstorm.md core/docs/agents/planner.md core/docs/agents/implement-task.md; then exit 1; fi
rg -q 'Replace .*package-manager|replace `<package-manager>`' core/docs/agents/bugfix.md
rg -q 'design feedback, not evidence' core/agents/skills/ui-design/SKILL.md
```

Expected: role docs contain no workflow/self-review prose; the moved UI-design Verify prose exists in the skill; the placeholder TODO is present.

- [ ] **Step 4: Commit**

```bash
git add core/docs/agents core/agents/skills/ui-design/SKILL.md
git commit -m "docs: restrict role docs to loading contracts and repo configuration"
```

### Task 6: Slim OpenCode workflow agents to skill invocations

**Files:**
- Modify: `core/opencode/agents/finish.md`
- Modify: `core/opencode/agents/review-code.md`
- Modify: `core/opencode/agents/review-plan.md`
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/implement-task.md`
- Modify: `core/agents/skills/{finish,review-code,review-plan,implement,implement-task}/SKILL.md` (absorb dropped agent prose)

- [ ] **Step 1: Reduce the three fat agents to wrapper form**

Follow the existing thin-wrapper model (`core/opencode/agents/ui-design.md` body: identity line plus "Invoke the `/ui-design` skill and follow it exactly."). Reduce `finish.md`, `review-code.md`, and `review-plan.md` bodies to the identity line and the skill-invocation instruction; keep frontmatter (description, mode, temperature, permissions) unchanged except where Task 2 already edited publication wording. Before deleting each agent's workflow prose, diff it against the matching SKILL.md and absorb anything the skill does not already carry (escalation rules, review-round mechanics, publication steps) into the skill.

- [ ] **Step 2: Move role-doc load instructions into the skills**

Remove the "Load `docs/agents/…`" lines from `implement.md` (line 76) and `implement-task.md` (line 71); ensure each corresponding SKILL.md instructs loading its role doc (the planner and review-code skills already do this under "Load first").

- [ ] **Step 3: Verify**

```bash
codespell core/opencode/agents core/agents/skills/finish core/agents/skills/review-code core/agents/skills/review-plan core/agents/skills/implement core/agents/skills/implement-task
for agent in finish review-code review-plan implement implement-task; do
  body_lines=$(awk 'f{print} /^---$/{c++; if(c==2){f=1}}' "core/opencode/agents/$agent.md" | wc -l | tr -d ' ')
  test "$body_lines" -le 10 || { echo "Agent body too long: $agent ($body_lines lines)"; exit 1; }
  rg -q 'Invoke the' "core/opencode/agents/$agent.md"
done
for skill in finish review-code review-plan implement implement-task; do
  rg -q 'docs/agents' "core/agents/skills/$skill/SKILL.md"
done
```

Expected: every workflow agent body is a ≤10-line wrapper invoking its skill; each skill carries the role-doc load instruction; spelling passes.

- [ ] **Step 4: Commit**

```bash
git add core/opencode/agents core/agents/skills/finish core/agents/skills/review-code core/agents/skills/review-plan core/agents/skills/implement core/agents/skills/implement-task
git commit -m "refactor: reduce workflow agents to canonical skill invocations"
```

### Task 7: Correct inventory documentation

**Files:**
- Modify: `core/claude/README.md`
- Modify: `core/docs/agents/agent-workflow-extension.md`
- Modify: `README.md`

- [ ] **Step 1: Remove hardcoded counts**

`core/claude/README.md` line 8 becomes `## Skills`; line 100 becomes `All authored skills are symlinked from `.agents/skills/`:`. `agent-workflow-extension.md` line 69 drops "All 17". Root `README.md`: drop the numeric counts at lines 115, 123, 127, 141, 145, 174, and 182 (keep the lists and tables themselves).

- [ ] **Step 2: Fix the frontmatter claims**

Root `README.md` line 145 and `core/claude/README.md` line 14: state that user-facing skills are marked `disable-model-invocation: true` while hidden support and worker skills are marked `user-invocable: false`.

- [ ] **Step 3: Run the consolidated verification baseline**

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh scripts/test-installer.sh $(find core/agents/skills -name '*.sh' -not -path '*/test/*') core/agents/skills/*/test/helpers/stubs.bash
jq empty opencode.json core/opencode.json core/skills-lock.json skills-lock.json core/claude/settings.json stacks/pnpm/opencode.json stacks/maven/opencode.json stacks/pnpm/claude/settings.json stacks/maven/claude/settings.json
codespell README.md core
if rg -n 'workflow-verification|glab|provider-neutral|17 authored|All 17' README.md core/ --glob '!plans/**'; then exit 1; fi
mkdir -p .temp/review-findings-install && bash scripts/test-installer.sh .temp/review-findings-install; rm -rf .temp/review-findings-install
```

Expected: syntax, shellcheck, JSON, spelling, and the installer suite (101 assertions) all pass; no stale names, GitLab remnants, or hardcoded counts remain anywhere under `README.md` or `core/`.

- [ ] **Step 4: Commit**

```bash
git add README.md core/claude/README.md core/docs/agents/agent-workflow-extension.md
git commit -m "docs: drop hardcoded inventory counts and fix frontmatter claims"
```
