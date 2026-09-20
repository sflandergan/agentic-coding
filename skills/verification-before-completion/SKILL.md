---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating PRs — run the verification commands and confirm their output before making any success claim.
user-invocable: false
---

# Verification Before Completion

No completion claims without fresh verification evidence. Fresh means run in
this message — earlier runs, cached task status, and worker reports do not count.

## The evidence gate

Before claiming any status or expressing satisfaction:

1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute the full command (fresh, complete).
3. **READ:** Full output; check the exit code; count failures.
4. **VERIFY:** Does the output confirm the claim?
   - If NO: state the actual status with evidence.
   - If YES: state the claim with evidence.
5. **ONLY THEN:** make the claim.

## Claim/evidence table

| Claim | Requires | Not Sufficient |
|-------|----------|----------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, extrapolation |
| Build succeeds | Build command: exit 0 | Linter passing, logs look good |
| Bug fixed | Test original symptom: passes | Code changed, assumed fixed |
| Regression test works | Red-green cycle verified | Test passes once |
| Agent completed | VCS diff shows changes | Agent reports "success" |
| Requirements met | Line-by-line checklist | Tests passing |

## Verification baseline

Use the current plan and relevant role document under `docs/agents/` as the source of
truth for required commands. If the task's role doc defines a `## Verify` section, use
those commands — do not invent commands or fall back to a template.

Distinguish **failed** from **unavailable** checks:
- A check that ran and produced errors is failed — report the errors.
- A command that does not exist in the repository is unavailable — report it as
  unavailable, not as passing or failing.
- Never claim "check passes" based on the absence of the command or the worker's
  statement that it was not run.

## Regression tests (TDD red-green)

Write → run (pass) → revert the fix → run (must fail) → restore → run (pass).
A test that has only ever passed does not prove it guards the regression.

## Agent delegation

When an agent or worker reports success, check the VCS diff and rerun the
relevant checks yourself before accepting the claim.

## When to apply

Run this gate before any success or completion claim, any expression of
satisfaction, committing, PR creation, task completion, moving to the next
task, and delegating to agents.