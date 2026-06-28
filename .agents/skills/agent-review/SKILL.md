---
name: agent-review
description: Use when reviewing plans or diffs for this toolkit repo against the shared conventions in AGENTS.md
user-invocable: false
---

# Agent Review — Self-Maintenance

Review plans and diffs against the conventions in `AGENTS.md`.

## Review Checklist

### For plans

- [ ] If spec is present, check coverage: every requirement has a task
- [ ] File mapping includes core/stack ripple check
- [ ] Sync invariants addressed (README, lockfiles, dot-mapping)
- [ ] No placeholders (TBD, TODO, "similar to Task N")
- [ ] Verification commands included per task
- [ ] Task boundaries produce one commit each

### For diffs

- [ ] Changes match the approved plan
- [ ] SKILL.md frontmatter has `name` and `description`
- [ ] Agent `.md` has `description` in frontmatter
- [ ] Symlinks in `.claude/skills/` resolve correctly
- [ ] `skills-lock.json` reflects this repo's self-maintenance skills
- [ ] `core/skills-lock.json` reflects target-project template skills
- [ ] README agent/skill lists match actual files
- [ ] Shell scripts pass shellcheck and bash -n
- [ ] No force-push, no branch deletion, no worktree removal
- [ ] Commits are concise, imperative, scoped to one logical change
- [ ] No Co-Authored-By lines

## Review Priorities

1. Bugs, broken scripts, incorrect symlinks
2. Missing sync: README vs files, lockfiles vs installed skills
3. Convention violations from AGENTS.md
4. Unnecessary scope expansion

## PR Comment Review

Use the `/change-request-comments` skill and run:

```bash
bash .agents/skills/change-request-comments/scripts/fetch-comments.sh [<pr>] [--comments-only|--diff-only|--json]
```

Inline comments must be checked against the current diff before accepting or dismissing them. Outdated inline comments may still be valid; verify technical claims before dismissing.

## Required Workflow

Use this standard self-maintenance review workflow unless the user explicitly requests a different scope:

1. Read open PR comments first by using `/change-request-comments`. If the branch has no detectable PR, state that and continue with the local review.
2. Identify whether the review target is a spec/plan or a diff. If multiple candidate plans exist and the user did not state which one to use, ask before continuing the plan-conformance part of the review.
3. Review the target yourself against `AGENTS.md`, repository conventions, sync invariants, and any approved spec or plan.
4. Combine PR comments, user notes, external notes, and your own findings into one deduplicated list of actionable issues.
5. Present suggested fixes as blocking issues and advisory suggestions first. Do not edit files yet.
6. For approved spec/plan review fixes, update the reviewed spec or plan directly under `plans/**`.
7. For approved diff review fixes that need planning or exceed trivial review-scoped changes, write a review-finding implementation plan next to the original plan, for example `plans/<feature-dir>/review-findings.md`. Do not adapt an unrelated implementation plan for new review findings, and do not create a new date-prefixed folder for review findings when an original plan exists.
8. After plan updates or review-finding plan creation, self-review every tracked remark and finding. Map each item to the changed section, review-finding plan section, or intentional unresolved status.
9. Draft exact GitHub replies for resolved PR comments and ask for explicit approval before posting. Approval to edit files or write a plan does not authorize posting GitHub comments.

**Distinction:** Plan review updates the reviewed plan/spec after approval; diff review writes a review-finding implementation plan for `@implement` after approval.

## Output

Present findings ordered by severity with file and line references. If no findings, say so.

Review and report findings without editing files directly. Provide suggested fixes when useful.
