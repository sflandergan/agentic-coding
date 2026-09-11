# Task 01: Unify Git Publication

**Objective:** Atomically replace split publication with the latest sister `git-publish`, port the dependent finish helpers, and migrate every runtime and documentation reference in the same commit.

**Requirements:** F1 and publication-dependent part of F2; threads 3839283174, 3839308402, 3839332145, 3839345215, 3839349845, 3839352179, 3839353024, 3903441038, 3903459328, 3907429376.

**Files:**
- Modify: `core/agents/skills/git-publish/SKILL.md`
- Rename: `core/agents/skills/git-publish/scripts/push-branch.sh` → `core/agents/skills/git-publish/scripts/publish-branch.sh`
- Rename: `core/agents/skills/git-publish/test/push-branch.bats` → `core/agents/skills/git-publish/test/publish-branch.bats`
- Rename and modify: `core/agents/skills/git-publish/test/helpers/stubs.bash` → `stubs.sh`
- Delete: `core/agents/skills/change-request-publish/`
- Modify: `core/agents/skills/finish/SKILL.md`
- Create: `core/agents/skills/finish/scripts/ensure-fresh.sh`
- Create: `core/agents/skills/finish/scripts/mark-pr-ready.sh`
- Create: `core/agents/skills/finish/scripts/publish-and-ready.sh`
- Create: `core/agents/skills/finish/test/readiness.bats`
- Create: `core/agents/skills/finish/test/helpers/stubs.sh`
- Modify: `core/agents/skills/brainstorm/SKILL.md`
- Modify: `core/agents/skills/implement/SKILL.md`
- Modify: `core/agents/skills/review-code/SKILL.md`
- Modify: `core/agents/skills/review-plan/SKILL.md`
- Modify: `core/opencode/agents/brainstorm.md`
- Modify: `core/opencode/agents/finish.md`
- Modify: `core/opencode/agents/implement.md`
- Modify: `core/opencode/agents/review-code.md`
- Modify: `core/opencode/agents/review-plan.md`
- Modify: `core/claude/settings.json`
- Modify: `core/AGENTS.md`
- Modify: `core/docs/agents/agent-workflow-extension.md`
- Modify: `README.md`
- Modify: `core/claude/README.md`
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`
- Modify: `scripts/test-installer.sh`

- [ ] **Step 1: Establish RED cases**

Add Bats cases for: default mode pushes before PR lookup; existing open PR prints its URL; absent PR creates `gh pr create --fill --draft`; detached/protected branches fail; exact mode requires `--existing-pr <number> --expected-head <40-hex-sha> --head-branch <branch>` together; it validates the named PR's state, branch, and SHA; it performs one fully qualified lease update; stale lease never retries; unknown/mixed flags fail. Run the suite and record the missing sister behaviors as failures.

- [ ] **Step 2: Port the sister implementation**

Use `git -C ../bikes-local show origin/main:.agents/skills/git-publish/scripts/publish-branch.sh` as the behavioral source. Keep its function-based short orchestration and exact-PR mode. Retain this toolkit's dynamic protected-branch guard (`main`, `master`, resolved `origin/HEAD`). Default mode pushes before `gh pr list`; exact mode calls `gh pr view <number>`, validates identity/state/SHA, and makes exactly one fully-qualified lease update. Make the skill description trigger-only and begin `Use when`.

- [ ] **Step 3: Make fixture cleanup fail closed**

Reject unset/empty scratch roots, `/`, the workspace root, and paths outside `$PWD/.temp/`. `new_fixture` returns immediately on failed validation, assigns `FIXTURE_DIR` afterward, and rejects an empty name. `teardown` removes only a nonempty fixture proven below the validated root.

- [ ] **Step 4: Port the dependent finish helpers before removing compatibility**

Port `ensure-fresh.sh`, `mark-pr-ready.sh`, `publish-and-ready.sh`, and the readiness Bats suite from `../bikes-local` `origin/main`. Preserve exit 99 when rebase requires fresh verification. Bind repository owner/name, base, head, PR number, URL, and verified SHA. Use default `publish-branch.sh` only when the remote head is absent and its exact existing-PR mode otherwise. Update `finish/SKILL.md` in this task to invoke these helpers, so it never depends on a deleted `--mark-ready` mode.

- [ ] **Step 5: Migrate every reference and remove the superseded skill**

Replace callers and permissions with `bash .agents/skills/git-publish/scripts/publish-branch.sh` and the new finish helpers. Remove `change-request-publish` from authored/hidden inventories and installer assertions. Update Git conventions, workflow documentation, README tables, and Claude/OpenCode permissions. Run `git rm -r core/agents/skills/change-request-publish`. Do not add a `pull-request-publish` alias; the later user decision selects unified `git-publish`.

- [ ] **Step 6: Verify the atomic migration and commit**

```bash
bash -n core/agents/skills/git-publish/scripts/publish-branch.sh core/agents/skills/finish/scripts/*.sh scripts/init.sh scripts/copy.sh scripts/test-installer.sh
shellcheck core/agents/skills/git-publish/scripts/publish-branch.sh core/agents/skills/git-publish/test/helpers/stubs.sh core/agents/skills/finish/scripts/*.sh core/agents/skills/finish/test/helpers/stubs.sh scripts/init.sh scripts/copy.sh scripts/test-installer.sh
SCRATCH="$PWD/.temp/bats" bats core/agents/skills/git-publish/test/publish-branch.bats
SCRATCH="$PWD/.temp/bats" bats core/agents/skills/finish/test/readiness.bats
if rg -n 'change-request-publish|publish-change-request\.sh|push-branch\.sh' README.md core scripts; then exit 1; fi
codespell README.md core/agents/skills/git-publish core/agents/skills/finish core/docs/agents/agent-workflow-extension.md core/claude/README.md scripts
git add -A README.md core scripts
git commit -m "refactor: unify GitHub publication"
```

Expected: all checks pass; the old skill and every old name are absent; every caller resolves in this commit; both cleanup helpers reject `/` and the workspace root.
