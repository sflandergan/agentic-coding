---
name: agent-review
description: Use when reviewing plans or diffs for this toolkit repo against the shared conventions in AGENTS.md
user-invocable: false
---

# Agent Review — Self-Maintenance

Review plans and diffs against the conventions in `AGENTS.md`.

## Review Checklist

### For plans

- [ ] Spec coverage: every requirement has a task
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

## Output

Present findings ordered by severity with file and line references. If no findings, say so.

Review and report findings without editing files directly. Provide suggested fixes when useful.
