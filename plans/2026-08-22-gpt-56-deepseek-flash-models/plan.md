# GPT 5.6 and DeepSeek Flash Model Refresh Implementation Plan

> **For implementation agents:** Execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh both toolkit model profiles so the default OpenCode-Go-only installation has first-class reasoning assignments and the optional OpenAI overlay uses GPT 5.6, while keeping provider selection portable.

**Configuration shape:** The bundled OpenCode-Go profile uses Luna at `xhigh` for idea intake, brainstorming, and holistic reviews; DeepSeek V4 Flash at `max` for planning; and DeepSeek V4 Flash at `high` for the tightly scoped implementation worker. Selecting the OpenAI profile applies one deterministic overlay for high-reasoning workflows, including the newly added idea and UI-design agents, and carries both model and reasoning variant. The OpenCode-Go-only path must not install any `openai/` model reference.

**Configuration surface:** `core/opencode.json`, `core/models-openai.json`, removal of `core/models-openai-brainstorm.json`, model-prompt and merge logic in `scripts/init.sh` and `scripts/copy.sh`, and model documentation in `README.md`; no stack overlay or skill lockfile changes are required, but installed output for both pnpm and Maven must be smoke-tested because both stacks merge over the core model profile.

## Model assignments

| Workflow | Bundled OpenCode-Go profile | OpenAI overlay |
|---|---|---|
| `brainstorm` | `opencode-go/gpt-5.6-luna`, `xhigh` | `openai/gpt-5.6-sol`, `medium` |
| `bugfix` | `opencode-go/kimi-k2.7-code` | `openai/gpt-5.6-luna`, `xhigh` |
| `explore` | `opencode-go/mimo-v2.5` | unchanged |
| `finish` | `opencode-go/mimo-v2.5-pro` | unchanged |
| `idea` | `opencode-go/gpt-5.6-luna`, `xhigh` | `openai/gpt-5.6-sol`, `medium` |
| `implement` | `opencode-go/mimo-v2.5-pro` | unchanged |
| `implement-task` | `opencode-go/deepseek-v4-flash`, `high` | unchanged |
| `planner` | `opencode-go/deepseek-v4-flash`, `max` | `openai/gpt-5.6-luna`, `xhigh` |
| `review-code` | `opencode-go/gpt-5.6-luna`, `xhigh` | `openai/gpt-5.6-sol`, `medium` |
| `review-plan` | `opencode-go/gpt-5.6-luna`, `xhigh` | `openai/gpt-5.6-sol`, `medium` |
| `ui-design` | `opencode-go/qwen3.7-max` | `openai/gpt-5.6-luna`, `xhigh` |
| `ui-design-task` | `opencode-go/mimo-v2.5` | unchanged |

Set the top-level bundled model to `opencode-go/mimo-v2.5-pro` and retain `opencode-go/deepseek-v4-flash` as `small_model`. Do not copy bikes-local's `cline-pass`, Requesty, CommandCode, color assignments, protected filesystem paths, or provider blocks.

### Task 1: Update Bundled and OpenAI Model Profiles

**Files:**
- Modify: `core/opencode.json`
- Modify: `core/models-openai.json`
- Delete: `core/models-openai-brainstorm.json`

- [ ] **Step 1: Apply the bundled profile**

Update `core/opencode.json` to match the bundled column above. Add `idea`, `ui-design`, and `ui-design-task` entries if the skill-upgrade plan has landed; otherwise stop and execute that plan first. In particular, set `idea`, `brainstorm`, `review-code`, and `review-plan` to `opencode-go/gpt-5.6-luna` with `variant: xhigh`, and set `planner` to `opencode-go/deepseek-v4-flash` with `variant: max`. Preserve `implement-task` and `ui-design-task` as subagents. Set `implement-task.variant` to `high`, the top-level `model` to Mimo V2.5 Pro, and `small_model` to DeepSeek V4 Flash. These top-level, small-model, worker, and UI assignments are intentional parts of the complete refresh rather than consequences of the five high-reasoning assignments.

- [ ] **Step 2: Replace GPT 5.5 with the complete GPT 5.6 overlay**

Make `core/models-openai.json` contain only the seven OpenAI-overridden workflows in the table, with their exact `model` and `variant` values. Delete the separate brainstorm overlay because brainstorm is now an intentional part of the OpenAI profile rather than an extra prompt-time choice.

- [ ] **Step 3: Verify JSON and stale model removal**

Run:

```bash
jq empty core/opencode.json core/models-openai.json
opencode models opencode-go | rg -x 'opencode-go/gpt-5\.6-luna'
opencode models opencode-go | rg -x 'opencode-go/deepseek-v4-flash'
jq -e '
  .agent.idea.model == "opencode-go/gpt-5.6-luna" and .agent.idea.variant == "xhigh" and
  .agent.brainstorm.model == "opencode-go/gpt-5.6-luna" and .agent.brainstorm.variant == "xhigh" and
  .agent["review-code"].model == "opencode-go/gpt-5.6-luna" and .agent["review-code"].variant == "xhigh" and
  .agent["review-plan"].model == "opencode-go/gpt-5.6-luna" and .agent["review-plan"].variant == "xhigh" and
  .agent.planner.model == "opencode-go/deepseek-v4-flash" and .agent.planner.variant == "max"
' core/opencode.json
if rg -ni 'gpt-5\.5|models-openai-brainstorm|cline-pass|requesty|commandcode' core/opencode.json core/models-openai.json; then exit 1; fi
```

Expected: JSON validation and exact bundled-profile assertions pass, both OpenCode-Go model identifiers are available, and the stale/provider-specific scan returns no matches. The `max` and `xhigh` variants are additionally proven in installed-output smoke tests in Task 3.

- [ ] **Step 4: Commit**

```bash
git add core/opencode.json core/models-openai.json core/models-openai-brainstorm.json
git commit -m "chore: refresh workflow model profiles"
```

### Task 2: Simplify Model Selection and Preserve Variants

**Files:**
- Modify: `scripts/init.sh`
- Modify: `scripts/copy.sh`

- [ ] **Step 1: Remove the brainstorm follow-up prompt**

Delete `OPENAI_BRAINSTORM`, its prompt, conditional patch-file selection, and its summary output from both scripts. Keep the two choices `opencode-go only` and `opencode-go + OpenAI`; the latter always merges `core/models-openai.json`.

- [ ] **Step 2: Merge complete model-profile fields safely**

When `copy.sh` is authorized to override models, merge the staged `model`, optional `variant`, and existing `mode` for each staged agent without overwriting permissions, prompts, colors, or unrelated agent configuration in the target. This must carry the bundled Luna `xhigh` and planner `max` variants as well as every OpenAI overlay variant. Remove a stale target `variant` only when the staged profile intentionally provides no variant for an agent whose model is being replaced; retain subagent `mode` from the staged worker entries. Keep the non-override merge behavior unchanged so existing target model choices win.

- [ ] **Step 3: Verify scripts**

Run:

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
codespell scripts/init.sh scripts/copy.sh
if rg -n 'OPENAI_BRAINSTORM|models-openai-brainstorm|gpt-5\.5' scripts/init.sh scripts/copy.sh; then exit 1; fi
```

Expected: syntax, shellcheck, and spelling pass; the stale-selection scan returns no matches.

- [ ] **Step 4: Commit**

```bash
git add scripts/init.sh scripts/copy.sh
git commit -m "refactor: simplify OpenAI model selection"
```

### Task 3: Document and Smoke-Test Model Selection

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update model documentation**

Remove the OpenAI brainstorm follow-up from Quick Start and replace the GPT 5.5 rationale with the exact table above. Explain the profiles separately: bundled OpenCode-Go Luna at `xhigh` handles idea intake, brainstorming, and holistic code/plan reviews; bundled DeepSeek V4 Flash at `max` handles planning and at `high` handles bounded implementation tasks; Mimo handles frequent exploration and UI slices; and Mimo Pro handles controller/default work. For the optional OpenAI overlay, explain that Sol handles open-ended ideation and holistic reviews while Luna at `xhigh` handles investigation, planning, and UI orchestration. State that neither profile configures a third-party provider router and that the OpenCode-Go-only selection contains no `openai/` model references.

- [ ] **Step 2: Smoke-test both selection paths**

Run the default OpenCode-Go-only path for both stacks and the optional OpenAI path for one stack:

```bash
mkdir -p .temp
printf '1\n1\n.temp/model-smoke-pnpm-go\n' | bash scripts/init.sh
printf '2\n1\n.temp/model-smoke-maven-go\n' | bash scripts/init.sh
printf '1\n2\n.temp/model-smoke-pnpm-openai\n' | bash scripts/init.sh

for config in .temp/model-smoke-pnpm-go/opencode.json .temp/model-smoke-maven-go/opencode.json; do
  jq -e '
    .model == "opencode-go/mimo-v2.5-pro" and
    .small_model == "opencode-go/deepseek-v4-flash" and
    .agent.idea.model == "opencode-go/gpt-5.6-luna" and .agent.idea.variant == "xhigh" and
    .agent.brainstorm.model == "opencode-go/gpt-5.6-luna" and .agent.brainstorm.variant == "xhigh" and
    .agent.bugfix.model == "opencode-go/kimi-k2.7-code" and
    .agent.explore.model == "opencode-go/mimo-v2.5" and
    .agent.finish.model == "opencode-go/mimo-v2.5-pro" and
    .agent.implement.model == "opencode-go/mimo-v2.5-pro" and
    .agent["review-code"].model == "opencode-go/gpt-5.6-luna" and .agent["review-code"].variant == "xhigh" and
    .agent["review-plan"].model == "opencode-go/gpt-5.6-luna" and .agent["review-plan"].variant == "xhigh" and
    .agent.planner.model == "opencode-go/deepseek-v4-flash" and .agent.planner.variant == "max" and
    .agent["implement-task"].model == "opencode-go/deepseek-v4-flash" and
    .agent["implement-task"].variant == "high" and .agent["implement-task"].mode == "subagent" and
    .agent["ui-design"].model == "opencode-go/qwen3.7-max" and
    .agent["ui-design-task"].model == "opencode-go/mimo-v2.5" and .agent["ui-design-task"].mode == "subagent" and
    ([.. | strings | select(startswith("openai/"))] | length == 0)
  ' "$config"
done

jq -e '
  .model == "opencode-go/mimo-v2.5-pro" and
  .small_model == "opencode-go/deepseek-v4-flash" and
  .agent.idea.model == "openai/gpt-5.6-sol" and .agent.idea.variant == "medium" and
  .agent.brainstorm.model == "openai/gpt-5.6-sol" and .agent.brainstorm.variant == "medium" and
  .agent.bugfix.model == "openai/gpt-5.6-luna" and .agent.bugfix.variant == "xhigh" and
  .agent.explore.model == "opencode-go/mimo-v2.5" and
  .agent.finish.model == "opencode-go/mimo-v2.5-pro" and
  .agent.implement.model == "opencode-go/mimo-v2.5-pro" and
  .agent["implement-task"].model == "opencode-go/deepseek-v4-flash" and
  .agent["implement-task"].variant == "high" and .agent["implement-task"].mode == "subagent" and
  .agent.planner.model == "openai/gpt-5.6-luna" and .agent.planner.variant == "xhigh" and
  .agent["review-code"].model == "openai/gpt-5.6-sol" and .agent["review-code"].variant == "medium" and
  .agent["review-plan"].model == "openai/gpt-5.6-sol" and .agent["review-plan"].variant == "medium" and
  .agent["ui-design"].model == "openai/gpt-5.6-luna" and .agent["ui-design"].variant == "xhigh" and
  .agent["ui-design-task"].model == "opencode-go/mimo-v2.5" and .agent["ui-design-task"].mode == "subagent"
' .temp/model-smoke-pnpm-openai/opencode.json
```

Create a clean existing-target fixture with stale variants and unrelated customization, then exercise `copy.sh`'s OpenCode-Go model override:

```bash
mkdir -p .temp/model-smoke-copy
git -C .temp/model-smoke-copy init
cat > .temp/model-smoke-copy/opencode.json <<'JSON'
{
  "model": "custom/top",
  "small_model": "custom/small",
  "agent": {
    "brainstorm": {
      "model": "custom/brainstorm",
      "variant": "stale",
      "prompt": "keep-brainstorm",
      "color": "#123456",
      "permission": { "edit": "deny" }
    },
    "explore": {
      "model": "custom/explore",
      "variant": "stale",
      "prompt": "keep-explore"
    },
    "unrelated": {
      "model": "custom/unrelated",
      "prompt": "keep-unrelated"
    }
  },
  "permission": { "bash": { "*": "deny" } }
}
JSON
git -C .temp/model-smoke-copy add opencode.json
git -C .temp/model-smoke-copy -c user.name='Smoke Test' -c user.email='smoke@example.com' commit -m 'test: add model fixture'
printf '1\n1\ny\n1\n' | bash scripts/copy.sh .temp/model-smoke-copy

jq -e '
  .agent.brainstorm.model == "opencode-go/gpt-5.6-luna" and
  .agent.brainstorm.variant == "xhigh" and
  .agent.brainstorm.prompt == "keep-brainstorm" and
  .agent.brainstorm.color == "#123456" and
  .agent.brainstorm.permission.edit == "deny" and
  .agent.planner.model == "opencode-go/deepseek-v4-flash" and
  .agent.planner.variant == "max" and
  .agent.explore.model == "opencode-go/mimo-v2.5" and
  (.agent.explore | has("variant") | not) and
  .agent.explore.prompt == "keep-explore" and
  .agent["implement-task"].mode == "subagent" and
  .agent.unrelated.model == "custom/unrelated" and
  .agent.unrelated.prompt == "keep-unrelated" and
  .permission.bash["*"] == "deny"
' .temp/model-smoke-copy/opencode.json
```

Expected: both OpenCode-Go-only stack installs contain every bundled assignment and no `openai/` reference; the OpenAI install contains every overlay assignment and variant; and the existing-target override changes only model-profile fields, removes the stale Explore variant, retains worker mode, and preserves all unrelated customization.

- [ ] **Step 3: Run final validation**

Run:

```bash
bash -n scripts/init.sh scripts/copy.sh
shellcheck scripts/init.sh scripts/copy.sh
jq empty core/opencode.json core/models-openai.json
codespell README.md scripts/init.sh scripts/copy.sh core/opencode.json core/models-openai.json
if rg -ni 'gpt-5\.5|models-openai-brainstorm|OpenAI brainstorm override|cline-pass|requesty|commandcode' README.md scripts/init.sh scripts/copy.sh core; then exit 1; fi
rm -rf .temp/model-smoke-pnpm-go .temp/model-smoke-maven-go .temp/model-smoke-pnpm-openai .temp/model-smoke-copy
```

Expected: all checks pass; the stale/provider-specific scan returns no matches; smoke targets show deterministic bundled and OpenAI profiles. Remove only the named model smoke directories below `.temp/` after inspection.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: explain refreshed model profiles"
```
