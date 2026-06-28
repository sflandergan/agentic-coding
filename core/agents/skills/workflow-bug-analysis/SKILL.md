---
name: workflow-bug-analysis
description: Systematic bug investigation methodology — classify input, reproduce, trace code paths, inspect logs, form hypotheses, and produce a structured tracker issue.
user-invocable: false
---

# Bugfix Analysis

Systematic investigation methodology for bug reports. The calling agent uses this skill to trace a bug from symptom to root cause and produce a structured tracker issue.

## Investigation Steps

### 1. Classify the input

Determine the input type and extract key signals:

- **Log/error input**: stack trace, error message, HTTP status code. Extract: error message, stack trace frames, timestamps, affected module.
- **Behavior description**: unexpected output, missing data, wrong calculation. Extract: expected vs. actual behavior, affected feature, reproduction hints.

### 2. Reproduce or confirm

Run the relevant test or code path to confirm the symptom exists:

- Use the project's test commands (e.g. `pnpm test`, `pnpm test:integration`, or targeted test commands).
- If no existing test covers the bug, add a temporary reproduction test or log statement, run it, and report the result.
- Temporary working-tree changes must not be committed.

### 3. Trace the code path

Use `@explore` to map the affected code. Start from the error location or the described behavior and trace backwards to the root cause. Pay attention to:

- Architecture boundaries between packages
- Database queries and repository layers
- Service dependencies and injection
- Job orchestration and batch processing

Do not continue investigation from weak context — launch one or more explore subagents with focused questions. Multiple explore subagents may run in parallel when their questions are independent.

### 4. Inspect logs

When the bug involves runtime behavior, inspect the relevant logs. See `docs/agents/bugfix.md` for project-specific log locations and conventions.

- Look for error and warning entries near the reported symptom time.
- Match log levels to the project's conventions.

### 5. Form a hypothesis

Based on gathered evidence, state:

- What you believe the root cause is
- Why the evidence supports this conclusion
- What alternative explanations were considered and ruled out

### 6. Write the issue body

Structure findings into the issue template and save to `.temp/<slug>-issue-body.md`:

```markdown
## Symptom

<What the user sees or what the log reports>

## Evidence

### Logs (if applicable)

<Relevant log excerpts with timestamps>

### Code Path

<Files and line ranges traced during investigation>

## Suspected Root Cause

<The agent's analysis of where the bug lives and why>

## Affected Files

- `path/to/file.ts` — <what's wrong>
- ...

## Reproduction

<Steps to reproduce, if identified>
```

### 7. Create the issue

First, check for duplicate issues:

```bash
bash .agents/skills/issue-tracker/scripts/find-duplicate-issues.sh \
  --title "Concise bug summary"
```

If duplicates exist, link to them in the issue body. Then create the issue:

```bash
bash .agents/skills/issue-tracker/scripts/create-issue.sh \
  --title "Concise bug summary" \
  --body-file .temp/<slug>-issue-body.md \
  --labels "bug"
```

The script prints the created issue URL. Report this URL to the user.

## Follow-up Evidence

If the user provides additional evidence after the issue is created:

1. Update the issue body file in `.temp/`
2. Use `issue-tracker/scripts/update-issue.sh` to push the update:
   ```bash
   bash .agents/skills/issue-tracker/scripts/update-issue.sh \
     --issue <number> \
     --body-file .temp/<slug>-issue-body-updated.md
   ```
3. Report the updated issue URL
