# Agent Workflow Extension Guide

Use this guide when changing coding assistant workflows, agents, or reusable skills.

## Boundaries

- `docs/agents/*.md` files are role loading/reference contracts. Keep them focused on which repository docs an agent must load for a workflow. Do not put detailed executable workflow behavior there.
- `.opencode/agents/*.md` files define OpenCode agent behavior, permissions, default workflow, escalation rules, and tool usage.
- `.claude/skills/*/SKILL.md` files define Claude skill behavior for the matching workflow.
- `.agents/skills/*` files provide reusable mechanics shared by workflows. They may describe how to use bundled scripts or helpers, but they should not own role-level orchestration for review-plan, review-code, planner, implement, or finish workflows.

## Change-request comment workflow boundary

- The `change-request-comments` skill owns reading change-request comments, classifying comment target types, obtaining exact IDs, and posting approved replies through project scripts.
- Provider-specific mechanics (`github-pr-comments`, `gitlab-mr-comments`, `gh`, `glab`) belong only in provider skills or neutral integration skills, never in generic workflow skills or agent instructions.
- Review agents own deciding what the comments mean, validating technical claims, combining them with independent review findings, suggesting fixes, and requesting approval before edits or replies.

## Default placement rules

- If the change says what a role should do by default, update the matching `.opencode/agents/*.md` and `.claude/skills/*/SKILL.md` files.
- If the change says which docs a role must load, update the matching `docs/agents/*.md` file.
- If the change says how to run a shared helper script or avoid helper-specific mistakes, update the matching `.agents/skills/*` file.
- If a workflow change affects both OpenCode and Claude, update both definitions in the same plan and verify they remain aligned.

## Agent and skill references

- **OpenCode.** Agents are invoked with `@agentname` in the `task` tool (e.g., `@explore`). A workflow agent may dispatch `@explore`, but should not name other workflow agents (e.g., `@brainstorm`, `@planner`) in its body — cross-workflow hand-offs are the user's responsibility.
- **Claude Code.** Skills are invoked by the user with `/skillname`. Subagents are dispatched via the Agent tool by name with a leading `@` (e.g., `@explore`). A workflow skill should not name other workflow skills (e.g., `/brainstorm`, `/planner`) or OpenCode agents (e.g., `@implement`) in its body.
- **Shared skills** (under `.agents/skills/`) provide reusable mechanics — wrappers, scripts, methodology — and may be referenced by /name because they are not workflow orchestration.
