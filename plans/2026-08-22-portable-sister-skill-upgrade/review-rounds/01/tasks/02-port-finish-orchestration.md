# Task 02: Refine Finish Orchestration

**Objective:** Compact finish's artifact cleanup and feature-index guidance without changing the strict helper-driven sequence established by Task 01.

**Requirements:** Remaining F2 prose findings; threads 3907439270 and 3907455757.

**Files:**
- Modify: `core/agents/skills/finish/SKILL.md`

- [ ] **Step 1: Capture the behavior baseline**

Using a fresh agent, exercise cleanup with both legacy root artifacts and numbered review rounds, followed by a feature-index update. Save the transcript below `.temp/skill-evals/finish/red/` and record whether the agent removes the complete artifact set, targets `docs/features/index.md`, and retains the helper-driven freshness/verification/publication order.

- [ ] **Step 2: Compact without weakening gates**

Replace legacy-structure wording with one positive cleanup instruction covering `spec.md`, `plan.md`, `tasks/`, and all numbered `review-rounds/<NN>/` artifacts. Point feature documentation to `docs/features/index.md`. Preserve the exact sequence and exit-99 re-verification behavior from Task 01.

- [ ] **Step 3: Run GREEN**

Repeat the baseline scenario under `.temp/skill-evals/finish/green/`. The task fails if cleanup misses an artifact, the feature index is wrong, or helper/verification order changes.

- [ ] **Step 4: Verify and commit**

```bash
SCRATCH="$PWD/.temp/bats" bats core/agents/skills/finish/test/readiness.bats
codespell core/agents/skills/finish
git add core/agents/skills/finish
git commit -m "refactor: clarify finish artifact cleanup"
```

Expected: GREEN and Bats tests pass; the skill names the complete artifact set and `docs/features/index.md`; helper ordering is unchanged.
