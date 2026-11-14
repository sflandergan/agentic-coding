# Mistral 3rd-party compatibility (OpenCode V1)

The plugin is automatically discovered on restart: project-local at `../mistral-3rd-party.ts`, or global in the OpenCode `plugins/` directory.
It wraps only the `mistral-3rd-party` provider configured in the root `opencode.json`.
Requests must be streaming POSTs for one of the pinned models (`zai-glm-5-3`,
`zai-glm-5-3-flash`, `deepseek-v4-1-flash-1017`; see `MODEL_IDS` in
`compatibility.ts`) at `https://api.mistral.ai/v1/chat/completions` to be transformed.

## Setup

Restart OpenCode, run `/connect`, choose **Mistral 3rd-party (V1 compatibility)**,
and enter your Mistral API key. Alternatively, provide `MISTRAL_API_KEY` in the
environment of the OpenCode process. An existing connection to the built-in
`mistral` provider is a separate connection and is not automatically reused.

Select `mistral-3rd-party/zai-glm-5-3`, `mistral-3rd-party/zai-glm-5-3-flash` or
`mistral-3rd-party/deepseek-v4-1-flash-1017` in `/models`. Do not use the built-in
`mistral/...` entries for these models: they bypass the plugin and fail with
`Type validation failed ... tool_calls[0].id` errors. `zai-glm-5-3` is also the
configured build agent and project default. The existing small-model selection remains available
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
following `zai-glm-latest`. To cover another Mistral-hosted model with the same
symptoms, add it to `MODEL_IDS` and to the `mistral-3rd-party` provider in `opencode.json`.

## Verification

From the repository root:

```sh
cd .opencode && bun test ./plugins/mistral-3rd-party/test
opencode debug config
```

The tests use synthetic Mistral streams and do not consume API credits. For a live
check after connecting, start a new session and ask GLM to read `package.json` and
report the package name. Follow up with another read to exercise reasoning replay.

Protocol reference: [OpenCode issue #43199](https://github.com/anomalyco/opencode/issues/43199).
