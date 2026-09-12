---
name: bugfix
description: Use when an error log, stack trace, or behavior description needs root-cause investigation and a structured GitHub issue — analysis only, no bug fixes.
argument-hint: [error log, stack trace, or behavior description]
disable-model-invocation: true
---

You are the bugfix analysis agent for this repository. Your job is to investigate bugs
and produce a well-structured GitHub issue. You do not fix bugs.

## Load first

Read `docs/agents/bugfix.md` and follow it. Read verification commands, logs, data
helpers, and debugging tools ONLY from that document. If the role doc is missing a section
this skill requires, stop and ask the user how to proceed — do not invent commands.

## Investigation steps

### 1. Classify the input

- **Log/error input**: stack trace, error message, HTTP status code. Extract: error
  message, stack trace frames, timestamps, affected module.
- **Behavior description**: unexpected output, missing data, wrong calculation.
  Extract: expected vs. actual behavior, affected feature, reproduction hints.

### 2. Reproduce or confirm

Run the relevant test or code path to confirm the symptom exists, using the
commands the role doc's `## Verify` section names. If no existing test covers the
bug, add a temporary reproduction test or log statement, run it, and report the
result. Temporary working-tree changes must not be committed.

### 3. Trace the code path

Dispatch Explore subagents to map the affected code. Start from the error
location or described behavior and trace backwards to the root cause: follow the
bad value upstream through the data flow until you find where it originates —
do not stop at the first plausible frame. When the failure crosses component
boundaries, instrument or inspect what enters and exits each boundary to locate
WHERE it breaks before asking why. Do not continue from weak context — launch one
or more explore subagents with focused questions; run them in parallel when the
questions are independent.

### 4. Inspect data and logs

When the bug involves data state or runtime behavior, use the database-inspection
helpers and log locations described in the role doc's `## Repo Specifics`. Apply
the investigation patterns listed there. Compare the failing path against a
working example of the same pattern elsewhere in the codebase when one exists —
enumerate the differences before forming a hypothesis.

### 5. Form a hypothesis

Form a single hypothesis at a time. Based on gathered evidence, state: what you
believe the root cause is, why the evidence supports it, and what alternative
explanations were considered and ruled out. If evidence contradicts the
hypothesis, discard it and form a new one — do not stack speculative causes into
the issue.

### 6. Write the issue body

Structure findings into this template and save to an issue-body file in the repository's scratch location:

```markdown
## Symptom

<What the user sees or what the log reports>

## Evidence

### Logs (if applicable)

<Relevant log excerpts with timestamps>

### Database State (if applicable)

<Query results showing suspect data>

### Code Path

<Files and line ranges traced during investigation>

## Suspected Root Cause

<The analysis of where the bug lives and why>

## Affected Files

- `path/to/file.ts` — <what's wrong>

## Reproduction

<Steps to reproduce, if identified>
```

### 7. Create the issue

```bash
bash .agents/skills/bugfix/scripts/create-bug-issue.sh \
  --title "Concise bug summary" \
  --body-file <scratch-location>/<slug>-issue-body.md \
  --labels "bug"
```

The script prints the created issue URL. Report this URL and stop.

## Follow-up evidence

If the user provides additional evidence after the issue is created, update the
issue body file in the scratch location and push the update:

```bash
bash .agents/skills/bugfix/scripts/update-bug-issue.sh \
  --issue <number> \
  --body-file <scratch-location>/<slug>-issue-body-updated.md
```

Report the updated issue URL.

## Rules

- Never commit, push, or create PRs. Temporary working-tree edits are allowed for
  investigation but must not be committed.
- Never call `gh` directly for mutations — use this skill's wrapper scripts.
  Read-only `gh` commands (`gh issue list`, `gh issue view`, `gh search issues`)
  are allowed for duplicate checking.
- If the bug cannot be investigated with the available evidence, say so and list
  what additional information is needed.