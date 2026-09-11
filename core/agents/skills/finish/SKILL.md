---
name: finish
description: Use when an implemented, reviewed feature must be finalized — write durable feature documentation when warranted, reconcile glossary/ADRs, and clean up the working plan.
argument-hint: [feature name or plan dir]
disable-model-invocation: true
---

You are the finishing agent for this repository.
You finalize a feature once it is implemented and reviewed: evaluate each documentation authority independently, write or update compact package-driven feature maps when they materially help extension, reconcile the domain docs, and clean up the working plan.

Feature (if provided): $ARGUMENTS

## Load first

Check git state before doing anything.
Inspect the completed final diff grouped by changed package or feature-module root, the current implementation code for the affected packages, and the completed-plan evidence showing the change was implemented and reviewed.
Then read `docs/agents/finish.md` and follow it — it lists the repository-specific plan paths, feature index, affected maps, guides, glossaries, and ADRs to load.
Its `## Verify` section defines the completion verification commands; if that section is missing, stop and ask the user how to proceed — do not invent commands.

## Subagent usage

Dispatch the Explore subagent when finalization depends on repository investigation: affected packages, package roots, stable entry points, changed routes or jobs, or possible domain-language drift.
Do not write durable docs from weak context; send Explore a focused question instead of guessing.
Do not invoke implementation agents — implementation is already complete and reviewed when finishing starts.

## Finish workflow

Run this ordered workflow from start to finish. Do not skip steps, reorder them, or proceed past a failure.

### Step 1 — Confirm done

Verify the implementation is already complete and reviewed.
Inspect the final diff and completed-plan evidence. Do not finalize work that is not finished.

### Step 2 — Document the change

1. **Group changed files by package or feature-module root.** Start from the completed diff and changed packages; map each changed package to the capabilities it affects, then decide which documentation authority changed: feature maps, architecture guides, context glossaries, or ADRs. Classification is based on the affected capabilities, not a fixed list of changed file paths.
2. **Inspect the index and affected maps.** Read `docs/features/index.md` and the feature maps for the affected capabilities. Then independently evaluate the applicable area guides loaded on demand, the relevant context glossary for terminology only, and relevant accepted or deferred ADRs.
3. **Update or omit feature maps.** Use the `/feature-documentation` skill when a map should be created, updated, merged, renamed, or removed. A feature map exists only when it materially helps extend a named capability or exposes a non-obvious ADR constraint. A compact map contains only a short overview and ownership boundary, a `## Main Packages and Entry Points` list that prefers package or feature-module roots (name an individual file only when it is the stable entry point an engineer should open first), and applicable non-obvious ADR links. Omit the map when the change is maintenance-only unless a surviving map became inaccurate — maintenance-only work still requires map link repair when a surviving map points at moved packages or entry points.
4. **Reconcile the domain docs.** A guide changes when reusable mechanics or cross-feature boundaries change; a glossary changes only when domain terminology changes. Create or update an ADR only when all three conditions hold: changing the decision would be meaningfully costly, the result is surprising without rationale, and genuine alternatives were considered and traded off. If an implemented ADR-worthy decision lacks reliable evidence of alternatives or rationale, stop and ask the owner; never fabricate a retrospective ADR. Keep glossaries as glossaries.
5. **Validate documentation.** Confirm the feature index is synchronized atomically with every map addition, merge, rename, or removal; package and entry-point links resolve; documentation sits in the right authority; and maps contain no dates, branches, PRs, plans, status, tests, or verification history. Repair package/entry-point links after maintenance refactors even when behavior is unchanged.

### Step 3 — Clean up and commit

Delete the entire feature plan directory only after the documentation decisions and validation are complete.
Run `git rm -r plans/<feature-dir>/` from the repository root.
This removes the complete artifact set in one commit-friendly step: `spec.md`, `plan.md`, `tasks/`, and all numbered `review-rounds/<NN>/` directories.
Do not force removal.
If Git refuses because files contain uncommitted changes or for another safety reason, stop and report the failure for user resolution.
Commit the documentation and cleanup if they changed; do not create an empty commit when no owned files changed.

### Step 4 — Ensure freshness

Before verification or publication, confirm the branch is current with its base:

```bash
bash .agents/skills/finish/scripts/ensure-fresh.sh
```

The script fetches the base branch, checks whether HEAD contains the fetched base tip, and rebases when behind. Exit codes:

- `0` — already fresh; proceed to Step 6.
- `3` — the base had moved and a rebase was performed; proceed to Step 5 if conflicts appeared, otherwise Step 6.
- `1` — the rebase failed; proceed to Step 5.
- `2` — the fetch failed; stop and report.

Set `FRESHNESS_BASE` (default `origin/main`) when the base branch is not `main`.

### Step 5 — Resolve rebase conflicts

If the rebase produced conflicts, resolve only straightforward conflicts whose combined intent is unambiguous and whose resolution does not choose new behavior or change test semantics. For each conflicted file:

1. Inspect the conflicting hunks and resolve only when the correct resolution is unambiguous.
2. Stage the resolved paths with `git add <path>`.
3. Run `git rebase --continue`.
4. Repeat until the rebase exits successfully or a new ambiguous conflict appears.

Do not silently choose conflict resolutions, skip hooks, abort another actor's work, or publish from an in-progress rebase.
Report broad or ambiguous conflict and stop. Do not publish the PR.

After the rebase completes successfully, proceed to Step 6.

### Step 6 — Run verification

Before saying anything is complete, fixed, passing, or ready, use the `verification-before-completion` skill.
The concrete commands come from the role doc's `## Verify` section (source of truth: `docs/agents/finish.md`) — run them fresh and read the output.

If a rebase occurred or conflicts were resolved in Step 4 or Step 5, run the complete applicable verification gate.
If verification fails, report and stop; do not mark ready.
If HEAD did not change and the change is docs-only or comment-only, verification may be skipped per the role doc.
If the user requested narrower verification, follow that and state what was not run.

### Step 7 — Publish the change request

Publish the verified commit and mark the PR ready in one guarded step:

```bash
bash .agents/skills/finish/scripts/publish-and-ready.sh
```

The script rechecks freshness first (exit `99` means the base moved and a rebase was performed — rerun the complete applicable verification gate from Step 6, then retry this step). It then publishes through `git-publish` — argument-less first publication when the remote branch is absent, guarded existing-PR mode when the branch is retained — validates the PR identity, and marks the open PR ready with the exact verified SHA.

If any command fails, stop and report; PR readiness was not changed.

Publication boundaries: push only through `bash .agents/skills/git-publish/scripts/publish-branch.sh` or the finish helpers above.
Never use bare `git push`, push to `main`, force-push, delete remote refs, push tags, or push arbitrary refspecs without explicit approval.
Do not create PRs manually, amend commits, delete branches, close comments, or remove worktrees.

### Step 8 — Report

Report the change request URL and stop. Do not claim completion if any step failed.
