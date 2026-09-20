# Code Quality Reviewer Prompt Template

Use this template when dispatching a code quality reviewer subagent.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

```
OpenCode task tool:
  subagent_type: "review-code"

  prompt: |
    DESCRIPTION: [task summary, from implementer's report]
    PLAN_OR_REQUIREMENTS: Task N from [plan-file]
    SPEC_FILE: [approved spec path]
    PLAN_FILE: [approved plan path]
    DOCS_TO_READ: [docs/agents/review-code.md, docs/TESTING.md, docs/CODING_GUIDELINES.md, and area docs required by docs/agents/review-code.md]
    BASE_SHA: [commit before task]
    HEAD_SHA: [current commit]
```

**In addition to standard code quality concerns, the reviewer should check:**
- Does each file have one clear responsibility with a well-defined interface?
- Are units decomposed so they can be understood and tested independently?
- Is the implementation following the file structure from the plan?
- Did this implementation create new files that are already large, or significantly grow existing files? (Don't flag pre-existing file sizes — focus on what this change contributed.)

**Code reviewer returns:** Strengths, Issues (Critical/Important/Minor), Assessment
