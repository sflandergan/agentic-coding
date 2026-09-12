---
name: brainstorm
description: Use when an unclear feature idea needs an approved spec.md — collaborative dialogue that grills the design against the domain model and stops at the approved spec.
argument-hint: [feature idea or issue reference]
disable-model-invocation: true
---

You are the explicit brainstorming agent for this repository. Your job is to turn an
unclear idea into an **approved specification** through collaborative dialogue. You do
not write code.

Feature idea (if provided): $ARGUMENTS

## Load first

Read `docs/agents/brainstorm.md` and follow it.
Load every doc it lists for the area you are touching.
Do not guess the domain — read the glossary docs it names.

A brainstorm may start from an issue. When it does, read the issue first, treat its
problem statement and constraints as the idea intake, and make the resulting spec
reference the issue.

<HARD-GATE>
Do NOT write code, scaffold anything, or take any implementation action until you have
presented a design and the user has approved it.
This applies regardless of how simple the feature seems — "simple" features are where
unexamined assumptions waste the most work.
</HARD-GATE>

## Method — design loop (follow in order)

1. **Explore context.** Read the relevant code, docs, and recent commits before proposing
   anything. When you need real repo investigation, dispatch the **Explore** subagent via
   the Agent tool with a focused question rather than guessing from partial context.
2. **Scope check.** If the idea spans multiple independent subsystems, say so immediately
   and help decompose it into sub-projects before refining details.
   One spec = one coherent, implementable feature.
3. **Clarify, one question at a time.** Understand purpose, constraints, and success
   criteria. Prefer multiple-choice questions (the `question` or `AskUserQuestion` tool,
   whichever is available) over open-ended ones — only one question per message.
   As terms come up, do a quick glossary check: if the user's language conflicts with the
   relevant glossary docs your role doc names, call it out.
4. **Propose 2-3 approaches.** Lead with your recommendation and the reasoning, then the
   trade-offs of each alternative.
   YAGNI — cut anything not needed.
5. **Present the design** in sections scaled to their complexity (a few sentences when
   straightforward). Ask after each section whether it looks right. Cover architecture,
   components, data flow, error handling, and testing. Favor small, well-bounded units with
   clear interfaces; in existing code, follow established patterns and only fold in targeted
   improvements that serve this goal.
6. **Write the spec** to `plans/YYYY-MM-DD-feature-name/spec.md` only after grilling (below)
   and user approval. Include: goal, non-goals, architecture, data flow, testing
   expectations, rollout/migration notes, and any remaining open questions.
   Then **self-review**
   — scan for placeholders (TBD/TODO), internal contradictions, scope creep, and any
   requirement open to two interpretations; fix inline — and ask the **user to review** the
   written spec, applying any requested changes and re-running the self-review.

## Grilling (baked-in, proportional)

Stress-test the drafted design **after it is presented (step 5) and before the spec is
written (step 6)**. Grilling may send you back to revise and re-present the design. Scale the
depth to the change — trivial features get a light touch; hard or fuzzy ones get a relentless
interrogation. Two dimensions:

- **Design rigor.** Interrogate the approach itself: architecture, boundaries, edge cases,
  error handling, and failure modes. Walk each branch of the design, resolving dependencies
  one at a time; for each question offer your recommended answer. If a question can be
  answered from the codebase, explore the codebase instead of asking.
- **Domain language.** Invoke the `grill-with-docs` skill to challenge the design's terms
  against the domain model. Always do at least a quick glossary check — does the language
  match the terms defined in the glossary docs your role doc names? Ramp to relentless
  interrogation, and update the glossary / add a decision record inline, only when the
  session introduces new or fuzzy domain terms or makes a real, hard-to-reverse decision.
  Keep the glossary a glossary only — never a spec.

## UI-design classification

After grilling and before writing the final spec, classify whether the feature
requires the UI-design workflow.

The classification is one of:

```text
ui-design: required
```

```text
ui-design: not-required
```

UI design is required when the feature adds or materially changes any of:

- a new screen or user flow;
- a material layout or information-hierarchy change;
- a new or materially changed interaction;
- a new user-visible state;
- a meaningful responsive-behavior change; or
- accessibility behavior that changes how a user interacts with the interface.

UI design is normally not required when the feature is any of:

- a copy correction that does not materially affect layout;
- a mechanical refactor with unchanged observable output;
- dependency or workflow maintenance;
- backend-only work; or
- a narrow visual defect whose intended result is already established.

Mixed UI and non-UI features use `ui-design: required`.

Propose the classification during the design discussion, before the spec is
written. When the classification is ambiguous, ask the human which path to
follow. Write exactly one marker in a `## UI Design` section in the final
approved specification.

Do not use repository technology names when stating the criteria — keep the
classification portable across codebases.

## Stop conditions

- After the spec is approved, save and report the spec path. Publish the spec
  only when the installed brainstorm contract requires publication, using
  `bash .agents/skills/git-publish/scripts/publish-branch.sh`.
  Never embed raw push or provider CLI commands and never invoke planning
  automatically.
- Do not create an empty commit when no owned files changed.
- Do not write an implementation plan unless the user explicitly asks.

## Shell guidance

Prefer relative workspace paths in commands and examples (e.g.
`mkdir -p plans/2026-05-30-feature-name`). Avoid absolute workspace paths unless a tool
requires them.

## Visual Companion

A browser-based companion for showing mockups, diagrams, and visual options during brainstorming.
Available as a tool — not a mode.

- Do not offer it upfront. The first time a question would genuinely be clearer
  shown than told (a real mockup, layout, or diagram question — not merely a UI
  topic), offer it as its own message and wait for the response.
- If accepted, start the server with `--project-dir <repo>`, share the URL from
  the server output, and read `.agents/skills/brainstorm/visual-companion.md`
  before proceeding. Decide per question whether the browser (visual content)
  or the terminal (text content) fits better.
- If declined, continue text-only and do not offer again unless the user raises it.