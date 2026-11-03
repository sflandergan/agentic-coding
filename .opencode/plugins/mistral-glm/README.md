# Mistral GLM 5.3 compatibility (OpenCode V1)

The project-local `../mistral-glm.ts` plugin is automatically discovered on restart.
It wraps only the `mistral-glm` provider configured in the root `opencode.json`.
Requests must be streaming POSTs for the exact `zai-glm-5-3` model at
`https://api.mistral.ai/v1/chat/completions` to be transformed.

## Setup

Restart OpenCode, run `/connect`, choose **Mistral GLM 5.3 (V1 compatibility)**,
and enter your Mistral API key. Alternatively, provide `MISTRAL_API_KEY` in the
environment of the OpenCode process. An existing connection to the built-in
`mistral` provider is a separate connection and is not automatically reused.

Select `mistral-glm/zai-glm-5-3` in `/models`. This is also the configured build
agent and project default. The existing small-model selection remains available
for title generation.

## Behavior

- Replays assistant `reasoning_content` as Mistral thinking content while retaining
  existing text/content arrays and tool calls. Empty reasoning fields are removed.
- Converts streamed text/thinking arrays into text and `reasoning_content`.
- Assigns stable tool-call IDs by choice and call index, scoped to each response.
- Maps `stop` to `tool_calls` only for choices that emitted tool calls.
- Parses complete SSE events, including split UTF-8, CRLF/CR/LF, multiline data,
  comments, and final events without a blank-line terminator.
- Preserves abort signals and stream cancellation, and removes stale response
  headers. HTTP errors and unrelated requests pass through unchanged.
- Limits each SSE event to 1,048,576 characters and each stream to 4,096 tool
  calls. Unsupported content types fail visibly instead of being dropped.

The dedicated provider avoids V1's built-in Mistral message-normalization path,
which can bypass the configured interleaved reasoning replay. Its
`interleaved.field: reasoning_content` setting is important for multi-turn tool
loops with older versions of the compatible SDK.

This code does not log prompts or credentials, make additional network requests,
or download remote plugin code. It is a V1-specific adapter; remove it when moving
to V2's native Mistral support. Model IDs are deliberately pinned rather than
following `zai-glm-latest`.

## Verification

From the repository root:

```sh
pnpm exec bun test ./.opencode/plugins/mistral-glm/test
pnpm exec tsc --noEmit --strict --skipLibCheck --target es2022 --module esnext --moduleResolution bundler --lib es2022,dom,dom.iterable .opencode/plugins/mistral-glm.ts
opencode debug config
```

The tests use synthetic Mistral streams and do not consume API credits. For a live
check after connecting, start a new session and ask GLM to read `package.json` and
report the package name. Follow up with another read to exercise reasoning replay.

Protocol reference: [OpenCode issue #43199](https://github.com/anomalyco/opencode/issues/43199).
