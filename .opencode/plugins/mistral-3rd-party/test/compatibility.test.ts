import { describe, expect, test } from "bun:test";
import { createMistral3rdPartyFetch, MODEL_IDS } from "../compatibility";
import { Mistral3rdPartyPlugin } from "../../mistral-3rd-party";
import type { Config, PluginInput } from "@opencode-ai/plugin";

const endpoint = "https://api.mistral.ai/v1/chat/completions";
const encoder = new TextEncoder();
const event = (value: unknown) => `data: ${JSON.stringify(value)}\n\n`;
const chunk = (delta: unknown, finish_reason: string | null = null, index = 0) => ({
  choices: [{ index, delta, finish_reason }],
});
const init = (extra: Record<string, unknown> = {}): RequestInit => ({
  method: "POST",
  headers: { "content-type": "application/json", authorization: "Bearer test-key" },
  body: JSON.stringify({ model: "zai-glm-5-3", stream: true, messages: [], ...extra }),
});
function sse(parts: string[], headers: Record<string, string> = {}) {
  return new Response(
    new ReadableStream<Uint8Array>({
      start(controller) {
        for (const part of parts) controller.enqueue(encoder.encode(part));
        controller.close();
      },
    }),
    { headers: { "content-type": "text/event-stream; charset=utf-8", ...headers } },
  );
}
async function normalized(parts: string[]) {
  const response = await createMistral3rdPartyFetch(async () => sse(parts))(endpoint, init());
  return (await response.text())
    .split("\n\n")
    .filter((value) => value.startsWith("data: {"))
    .map((value) => JSON.parse(value.slice(6)));
}

describe("Mistral 3rd-party V1 compatibility", () => {
  test("keeps missing IDs stable across fragmented, parallel calls and normalizes stop", async () => {
    const values = await normalized([
      event(
        chunk({
          tool_calls: [
            { index: 0, type: "function", function: { name: "read", arguments: '{"path":' } },
            {
              index: 1,
              id: "server-id",
              type: "function",
              function: { name: "glob", arguments: '{"pattern":' },
            },
          ],
        }),
      ),
      event(
        chunk({
          tool_calls: [
            { index: 0, function: { name: "", arguments: '"README.md"}' } },
            { index: 1, function: { arguments: '"*.ts"}' } },
          ],
        }),
      ),
      event(chunk({}, "stop")),
      "data: [DONE]\n\n",
    ]);
    const first = values[0].choices[0].delta.tool_calls;
    const next = values[1].choices[0].delta.tool_calls;
    expect(first[0].id).toMatch(/^call_[a-f0-9]{32}$/);
    expect(next[0].id).toBe(first[0].id);
    expect(first[1].id).toBe("server-id");
    expect(next[1].id).toBe("server-id");
    expect(first[0].function.arguments + next[0].function.arguments).toBe('{"path":"README.md"}');
    expect(values[2].choices[0].finish_reason).toBe("tool_calls");
  });

  test("isolates IDs by choice and stream, and leaves text finishes intact", async () => {
    const call = { tool_calls: [{ index: 0, function: { name: "read", arguments: "{}" } }] };
    const values = await normalized([
      event(chunk(call)),
      event(chunk(call, null, 1)),
      event(chunk({}, "stop", 2)),
    ]);
    const second = await normalized([event(chunk(call))]);
    expect(values[0].choices[0].delta.tool_calls[0].id).not.toBe(
      values[1].choices[0].delta.tool_calls[0].id,
    );
    expect(values[0].choices[0].delta.tool_calls[0].id).not.toBe(
      second[0].choices[0].delta.tool_calls[0].id,
    );
    expect(values[2].choices[0].finish_reason).toBe("stop");
  });

  test("flattens structured text and thinking without changing arguments or usage", async () => {
    const value = {
      ...chunk({
        content: [
          { type: "thinking", thinking: [{ type: "text", text: "Plan 🛠" }], closed: true },
          { type: "text", text: "Answer" },
        ],
        reasoning_content: "Existing: ",
      }),
      usage: { prompt_tokens: 12, completion_tokens: 3 },
    };
    const [result] = await normalized([event(value)]);
    expect(result.choices[0].delta).toEqual({
      content: "Answer",
      reasoning_content: "Existing: Plan 🛠",
    });
    expect(result.usage).toEqual(value.usage);
  });

  test.each(["\n", "\r\n", "\r"])(
    "parses multiline SSE and split %j boundaries",
    async (newline) => {
      const raw = [
        ": heartbeat",
        "",
        "event: message",
        "id: 12",
        'data: {"choices":',
        'data: [{"index":0,"delta":{"content":[{"type":"thinking","thinking":"Plan"}]}}]}',
        "",
        "data: [DONE]",
        "",
        "",
      ].join(newline);
      // Single-character chunks include the problematic split between CR and LF.
      const response = await createMistral3rdPartyFetch(async () => sse([...raw]))(endpoint, init());
      const output = await response.text();
      expect(output).toContain(": heartbeat\n\n");
      expect(output).toContain("event: message\nid: 12\n");
      expect(output).toContain('"reasoning_content":"Plan"');
      expect(output).toContain("data: [DONE]\n\n");
    },
  );

  test("decodes UTF-8 split within a multibyte character and flushes a final event", async () => {
    const bytes = encoder.encode(
      event(chunk({ content: [{ type: "text", text: "🚲" }] })).trimEnd(),
    );
    const fetch = createMistral3rdPartyFetch(
      async () =>
        new Response(
          new ReadableStream({
            start(controller) {
              for (const byte of bytes) controller.enqueue(new Uint8Array([byte]));
              controller.close();
            },
          }),
          { headers: { "content-type": "text/event-stream" } },
        ),
    );
    expect(await (await fetch(endpoint, init())).text()).toContain('"content":"🚲"');
  });

  test("rewrites reasoning, preserves existing content/tools/credentials, and removes empty reasoning fields", async () => {
    let sent: RequestInit | undefined;
    const messages = [
      {
        role: "assistant",
        reasoning_content: "Plan",
        content: [{ type: "text", text: "Answer" }],
        tool_calls: [{ id: "abc", type: "function" }],
      },
      { role: "assistant", reasoning: "", content: "Done" },
      { role: "user", content: "Question" },
    ];
    const fetch = createMistral3rdPartyFetch(async (_input, options) => {
      sent = options;
      return sse(["data: [DONE]\n\n"]);
    });
    const original = init({ messages });
    await fetch(endpoint, original);
    const body = JSON.parse(sent!.body as string);
    expect(body.messages[0].content).toEqual([
      { type: "thinking", thinking: [{ type: "text", text: "Plan" }] },
      { type: "text", text: "Answer" },
    ]);
    expect(body.messages[0].tool_calls).toEqual(messages[0].tool_calls);
    expect(body.messages[1]).toEqual({
      role: "assistant",
      content: [{ type: "text", text: "Done" }],
    });
    expect(body.messages[2]).toEqual(messages[2]);
    expect(new Headers(sent!.headers).get("authorization")).toBe("Bearer test-key");
    expect(JSON.parse(original.body as string).messages).toEqual(messages);
  });

  test("Request-object rewriting still normalizes responses and propagates cancellation signals", async () => {
    const abort = new AbortController();
    let sent: Request | undefined;
    const fetch = createMistral3rdPartyFetch(async (input) => {
      sent = input as Request;
      return sse([event(chunk({ content: [{ type: "thinking", thinking: "Plan" }] }))]);
    });
    const request = new Request(endpoint, {
      ...init({ messages: [{ role: "assistant", reasoning_content: "Old plan", content: null }] }),
      signal: abort.signal,
    });
    const response = await fetch(request);
    expect(await response.text()).toContain('"reasoning_content":"Plan"');
    expect((await sent!.json()).messages[0].content[0].type).toBe("thinking");
    abort.abort();
    expect(sent!.signal.aborted).toBe(true);
    expect(request.bodyUsed).toBe(false);
  });

  test.each([
    ["https://example.com/v1/chat/completions", {}],
    ["https://api.mistral.ai/v1/models", {}],
    [endpoint, { model: "zai-glm-latest" }],
    [endpoint, { model: "mistral-large-latest" }],
    [endpoint, { stream: false }],
  ])("does not intercept unrelated requests: %s %j", async (url, extra) => {
    const response = sse([event(chunk({ content: [{ type: "text", text: "Unchanged" }] }))]);
    const options = init(extra);
    let sent: RequestInit | undefined;
    const fetch = createMistral3rdPartyFetch(async (_input, value) => {
      sent = value;
      return response;
    });
    expect(await fetch(url as string, options)).toBe(response);
    expect(sent).toBe(options);
  });

  test("passes API errors through and strips stale headers only on transformed responses", async () => {
    const error = new Response('{"error":"rate limited"}', {
      status: 429,
      headers: { "retry-after": "10" },
    });
    expect(await createMistral3rdPartyFetch(async () => error)(endpoint, init())).toBe(error);
    const response = await createMistral3rdPartyFetch(async () =>
      sse(["data: [DONE]\n\n"], {
        "content-length": "100",
        "content-encoding": "gzip",
        etag: "old",
        "x-request-id": "trace",
      }),
    )(endpoint, init());
    expect(response.headers.has("content-length")).toBe(false);
    expect(response.headers.has("content-encoding")).toBe(false);
    expect(response.headers.has("etag")).toBe(false);
    expect(response.headers.get("x-request-id")).toBe("trace");
  });

  test("fails visibly on unsupported content and oversized SSE events", async () => {
    const fetch = createMistral3rdPartyFetch(async () =>
      sse([event(chunk({ content: [{ type: "unknown" }] }))]),
    );
    await expect((await fetch(endpoint, init())).text()).rejects.toThrow(
      "unsupported content type",
    );
    const oversized = createMistral3rdPartyFetch(async () => sse(["data: " + "x".repeat(1024 * 1024)]));
    await expect((await oversized(endpoint, init())).text()).rejects.toThrow("character limit");
  });

  test("bounds tool-call state across a long stream", async () => {
    const parts = Array.from({ length: 4097 }, (_, index) =>
      event(
        chunk({
          tool_calls: [{ index, function: { name: "read", arguments: "{}" } }],
        }),
      ),
    );
    const fetch = createMistral3rdPartyFetch(async () => sse(parts));
    await expect((await fetch(endpoint, init())).text()).rejects.toThrow("too many tool calls");
  });

  test("cancels the upstream stream when the consumer cancels", async () => {
    let cancelled = false;
    const fetch = createMistral3rdPartyFetch(
      async () =>
        new Response(
          new ReadableStream({
            pull(controller) {
              controller.enqueue(encoder.encode(": heartbeat\n\n"));
            },
            cancel() {
              cancelled = true;
            },
          }),
          { headers: { "content-type": "text/event-stream" } },
        ),
    );
    const reader = (await fetch(endpoint, init())).body!.getReader();
    await reader.read();
    await reader.cancel();
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(cancelled).toBe(true);
  });

  test.each([...MODEL_IDS])(
    "fills missing tool-call IDs and rewrites reasoning for %s",
    async (model) => {
      // Shape reported by OpenCode's "Type validation failed" error: no id, empty name.
      const continuation = {
        id: "abc",
        object: "chat.completion.chunk",
        model,
        choices: [
          {
            index: 0,
            delta: {
              tool_calls: [{ function: { name: "", arguments: '{"command": "gh pr view ' }, index: 0 }],
              index: 0,
              content: "",
            },
            finish_reason: null,
          },
        ],
      };
      let sent: RequestInit | undefined;
      const fetch = createMistral3rdPartyFetch(async (_input, options) => {
        sent = options;
        return sse([event(continuation), event(continuation)]);
      });
      const response = await fetch(
        endpoint,
        init({ model, messages: [{ role: "assistant", reasoning_content: "Plan", content: "" }] }),
      );
      const values = (await response.text())
        .split("\n\n")
        .filter((value) => value.startsWith("data: {"))
        .map((value) => JSON.parse(value.slice(6)));
      const [first, second] = values.map((value) => value.choices[0].delta.tool_calls[0].id);
      expect(first).toMatch(/^call_[a-f0-9]{32}$/);
      expect(second).toBe(first);
      expect(JSON.parse(sent!.body as string).messages[0].content).toEqual([
        { type: "thinking", thinking: [{ type: "text", text: "Plan" }] },
      ]);
    },
  );

  test.each([...MODEL_IDS])("plugin wraps only the compatibility provider configured with %s", async (model) => {
    const original = async () => sse(["data: [DONE]\n\n"]);
    const config: Config = {
      provider: {
        "mistral-3rd-party": {
          npm: "@ai-sdk/openai-compatible",
          models: { [model]: {} },
          options: { fetch: original },
        },
        mistral: { options: { fetch: original } },
      },
    };
    const hooks = await Mistral3rdPartyPlugin({} as PluginInput);
    await hooks.config!(config);
    expect(config.provider!["mistral-3rd-party"].options!.fetch).not.toBe(original);
    expect(config.provider!.mistral.options!.fetch).toBe(original);
  });
});
