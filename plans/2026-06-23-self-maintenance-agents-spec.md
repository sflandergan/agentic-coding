# Self-Maintenance Agents & Skills — Design

**Date:** 2026-06-23
**Status:** Draft (pending user review)

## 1. Purpose & Scope

A small, self-hosted agent + skill set that operates on **this toolkit repo itself**, not on target repos.

The `core/*` and `stacks/*` trees are **templates** installed into other repos by `init.sh`/`copy.sh`. This design adds separate tooling — inspired by those templates but deliberately lighter — for maintaining this repo.

The entire maintenance surface here is:

- Markdown templates under `core/` and `stacks/`
- `README.md`
- `skills-lock.json` and `core/skills-lock.json`
- The two bash scripts: `scripts/init.sh` (~325 lines), `scripts/copy.sh` (~618 lines)

There is no application code, no DDD contexts, and no test suite. The heavyweight TDD/DDD machinery in the templates does not fit markdown + bash, so it is intentionally omitted.

## 2. Layout (mirrors the template wiring, trimmed)

```
AGENTS.md                 shared repo conventions, loaded every session (was: toolkit-conventions skill)
CLAUDE.md                 one line: @AGENTS.md  (so Claude Code inherits the same conventions)
.opencode/agents/         plan.md  implement.md  implement-task.md  review.md
.agents/skills/           agent-planning/        agent-implementation/
                          agent-verification/    agent-review/
                          writing-skills/   (remote-installed)
.claude/skills/<name>  →  ../../.agents/skills/<name>   (symlinks, so Claude Code sees them)
opencode.json             model + agent config for the 4 agents
skills-lock.json          provenance for the remote writing-skills install
.gitignore                .temp/   (+ keep .claude/settings.local.json local)
```

Wiring rationale (verified against the existing scripts):

- **Shared conventions are ambient, not a skill.** The repo knowledge every agent needs lives in a root `AGENTS.md` (OpenCode loads it every session) plus a `CLAUDE.md` whose entire content is `@AGENTS.md` (so Claude Code inherits the same text). This replaces the former `toolkit-conventions` skill — no skill to "load first," no per-agent `skill:` whitelist entry for it.
- OpenCode reads skills directly from `.agents/skills/<name>/SKILL.md`.
- Each skill is symlinked into `.claude/skills/<name>` (`ln -s ../../.agents/skills/<name>`) so Claude Code also sees it — the same symlink model `copy.sh` uses for authored skills.
- OpenCode agents live in `.opencode/agents/*.md` and whitelist skills via their `skill:` permission block.
- Models are assigned in a root `opencode.json`.

## 3. Agents (thin → delegate to skills)

All agents inherit the shared conventions ambiently via `AGENTS.md`/`CLAUDE.md`, so the `skill:` whitelists below list only the task-specific skills.

| Agent | Mode | Loads skills | Role |
|---|---|---|---|
| `plan` | primary | `agent-planning` (+ `writing-skills` when the change touches a skill) | Writes a lightweight plan to `plans/YYYY-MM-DD-*/plan.md`. No code. |
| `implement` | primary | `agent-implementation` + `agent-verification` | Controller. Dispatches a fresh `implement-task` per task; reviews each worker diff; runs verification; branch + PR. |
| `implement-task` | subagent (hidden) | `agent-implementation` + `agent-verification` | Executes exactly one task, commits, self-reviews. No push/PR. |
| `review` | primary | `agent-review` + `agent-verification` | Single agent covering **both** plan-review and diff-review for this small repo. |

Permission blocks reuse the templates' git-safety guards:

- `deny` on `git branch -d`/`-D` and `git worktree remove`
- No bare or force push; no push to `main`
- Push only via `git push origin $(git rev-parse --abbrev-ref HEAD)`

## 4. Skills (the maintained intelligence)

Shared repo knowledge (the former `toolkit-conventions`) now lives in **`AGENTS.md`** rather than a skill — see §2. It carries:

- The `opencode/`→`.opencode/`, `claude/`→`.claude/`, `agents/`→`.agents/`, `docs/`→`docs/` dot-mapping.
- **Core + stacks dual-maintenance**: a change to a core template often needs the matching `stacks/*` overlay updated too.
- Sync invariants: README agent/skill lists, `skills-lock.json`, and the dot-mapping table must stay consistent with the actual files.
- SKILL.md frontmatter conventions and the `.agents → .claude` symlink model.
- The `.temp/` scratch rule (never `/tmp`; clean up after).

The task-specific skills:

- **`agent-planning`** — lightweight plan structure for markdown + bash: map affected files (including core/stack ripple), bite-sized tasks, no rigid TDD, verification commands per task.
- **`agent-implementation`** — controller orchestration + the single-task worker contract (status/report format, `git mv`/`git rm`, one focused commit per task).
- **`agent-verification`** — the "done" gate:
  - `shellcheck` + `bash -n` on changed scripts.
  - Smoke-run `init.sh`/`copy.sh` against a throwaway target dir under `.temp/`.
  - Consistency checks: README lists ↔ actual files ↔ `skills-lock.json` ↔ dot-mapping.
- **`agent-review`** — review checklist for plans and diffs against the conventions in `AGENTS.md`.
- **`writing-skills`** — **remote-installed via `npx skills add`** (the find-skills approach the scripts use), tracked in `skills-lock.json`, committed into `.agents/skills/writing-skills/`. Sourced from **obra/superpowers** (key `writing-skills`, source `obra/superpowers`, sourceType `github`). Used both for authoring the **template** skills under `core/agents/skills/*` and this repo's own skills.

## 5. Models (root `opencode.json`, trimmed from the template profile)

| Agent | Model |
|---|---|
| `plan` | `opencode-go/mimo-v2.5-pro` |
| `implement` | `opencode-go/mimo-v2.5-pro` |
| `implement-task` | `opencode-go/mimo-v2.5` (subagent) |
| `review` | `opencode-go/kimi-k2.7-code` |

Default build and planning agents should be disabled.
Plan and Review should only be allowed to edit plans/*.
Implement and Implement task may edit all files.
Check which shell permissions are necessary for implementation and verification.
Other settings inherit OpenCode defaults. Adjustable.

## 6. writing-skills source — DECIDED: obra/superpowers

Switch to **obra/superpowers `writing-skills`**. `core/skills-lock.json` currently tracks `write-a-skill` from `mattpocock/skills`; that entry is **replaced** one-for-one:

```json
"writing-skills": {
  "source": "obra/superpowers",
  "sourceType": "github"
}
```

This is the shape the scripts already feed to `npx skills add "$src" --skill "$key"` (init.sh:280, copy.sh:563), so no script change is needed — only the lockfile entry. Because the swap is in `core/skills-lock.json`, it also changes what `init.sh`/`copy.sh` install into target repos.

Implementation guard: before committing the lockfile change, verify `npx skills add obra/superpowers --skill writing-skills` actually resolves. If it cannot, revisit (the old `mattpocock/skills` `write-a-skill` was the proven fallback).

## 7. Caveats

- **`.gitignore`**: add one with `.temp/` so smoke runs never dirty the working tree (there is no `.gitignore` today).
- **Dogfooding risk**: running `copy.sh` *on this repo* would overwrite `.opencode/` with templates. Agent names differ (`plan`/`review` vs template `planner`/`review-code`), so overlap is only partial — noted in the conventions skill, not guarded against in code.

## 8. Decisions Locked During Brainstorming

- Thin agents → reusable skills (logic lives in skills).
- Skills in `.agents/skills/`; agents in `.opencode/agents/`.
- Verification = shellcheck + script smoke run + consistency checks (no new test framework).
- writing-skills installed via the find-skills / `npx skills add` approach, not hand-vendored.
- Roster: `plan`, `implement`, `implement-task`, `review` (single review; no brainstorm/bugfix/finish).
- Shared conventions live in `AGENTS.md` + a `CLAUDE.md` (`@AGENTS.md`), not a `toolkit-conventions` skill.
- Skill prefix is `agent-*` (not `toolkit-*`).
- writing-skills sourced from `obra/superpowers` (replacing `mattpocock/skills` `write-a-skill` in `core/skills-lock.json`).
