export const PROVIDER_ID = "mistral-3rd-party";
// Mistral-hosted models that share the same streaming quirks (missing tool-call IDs,
// structured thinking content). Pinned IDs only; "-latest" aliases are not matched.
export const MODEL_IDS: ReadonlySet<string> = new Set([
  "zai-glm-5-3",
  "zai-glm-5-3-flash",
  "deepseek-v4-1-flash-1017",
]);
const ENDPOINT = "https://api.mistral.ai/v1/chat/completions";
const MAX_EVENT_CHARS = 1024 * 1024;
const MAX_TOOL_CALLS = 4096;

type JsonObject = Record<string, unknown>;
type Fetch = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;

function object(value: unknown): value is JsonObject {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

async function prepareRequest(input: RequestInfo | URL, init?: RequestInit) {
  const url = new URL(input instanceof Request ? input.url : input.toString());
  const method = init?.method ?? (input instanceof Request ? input.method : "GET");
  if (url.origin + url.pathname !== ENDPOINT || method.toUpperCase() !== "POST") return;

  const raw =
    typeof init?.body === "string"
      ? init.body
      : input instanceof Request && init?.body == null
        ? await input.clone().text()
        : undefined;
  if (raw === undefined) return;
  let body: unknown;
  try {
    body = JSON.parse(raw);
  } catch {
    return;
  }
  if (!object(body) || typeof body.model !== "string" || !MODEL_IDS.has(body.model) || body.stream !== true) return;

  let changed = false;
  for (const message of Array.isArray(body.messages) ? body.messages : []) {
    if (!object(message) || message.role !== "assistant") continue;
    const reasoning =
      typeof message.reasoning_content === "string"
        ? message.reasoning_content
        : typeof message.reasoning === "string"
          ? message.reasoning
          : undefined;
    if (reasoning === undefined) continue;
    const content = Array.isArray(message.content)
      ? message.content
      : typeof message.content === "string" && message.content
        ? [{ type: "text", text: message.content }]
        : [];
    message.content = reasoning
      ? [{ type: "thinking", thinking: [{ type: "text", text: reasoning }] }, ...content]
      : content;
    delete message.reasoning_content;
    delete message.reasoning;
    changed = true;
  }
  if (!changed) return { input, init };

  const headers = new Headers(
    init?.headers ?? (input instanceof Request ? input.headers : undefined),
  );
  headers.delete("content-length");
  const options = { ...init, headers, body: JSON.stringify(body) };
  // Keep the request's abort signal unless the caller explicitly overrides it.
  if (input instanceof Request) return { input: new Request(input, options), init: undefined };
  return { input, init: options };
}

function flattenContent(parts: unknown[]) {
  const text: string[] = [];
  const reasoning: string[] = [];
  for (const part of parts) {
    if (!object(part)) throw new Error("Mistral 3rd-party returned an invalid content part");
    if (part.type === "text" && typeof part.text === "string") {
      text.push(part.text);
    } else if (part.type === "thinking") {
      if (typeof part.thinking === "string") reasoning.push(part.thinking);
      else if (Array.isArray(part.thinking)) {
        for (const item of part.thinking) {
          if (!object(item) || item.type !== "text" || typeof item.text !== "string") {
            throw new Error("Mistral 3rd-party returned an invalid thinking part");
          }
          reasoning.push(item.text);
        }
      } else throw new Error("Mistral 3rd-party returned an invalid thinking part");
    } else throw new Error(`Mistral 3rd-party returned unsupported content type: ${String(part.type)}`);
  }
  return { text: text.join(""), reasoning: reasoning.join("") };
}

function normalizeChunk(chunk: unknown, ids: Map<string, string>, toolChoices: Set<number>) {
  if (!object(chunk) || !Array.isArray(chunk.choices)) return chunk;
  for (const [position, choice] of chunk.choices.entries()) {
    if (!object(choice)) continue;
    const index = typeof choice.index === "number" ? choice.index : position;
    if (object(choice.delta)) {
      const delta = choice.delta;
      if (Array.isArray(delta.content)) {
        const { text, reasoning } = flattenContent(delta.content);
        delta.content = text;
        if (reasoning) {
          delta.reasoning_content =
            (typeof delta.reasoning_content === "string" ? delta.reasoning_content : "") +
            reasoning;
        }
      }
      for (const [callPosition, call] of (Array.isArray(delta.tool_calls)
        ? delta.tool_calls
        : []
      ).entries()) {
        if (!object(call)) continue;
        const key = `${index}:${typeof call.index === "number" ? call.index : callPosition}`;
        let id = ids.get(key);
        if (!id) {
          if (ids.size >= MAX_TOOL_CALLS)
            throw new Error("Mistral 3rd-party stream contains too many tool calls");
          id =
            typeof call.id === "string" && call.id
              ? call.id
              : `call_${crypto.randomUUID().replaceAll("-", "")}`;
          ids.set(key, id);
        }
        call.id = id;
        toolChoices.add(index);
      }
    }
    // Mistral-hosted models can report stop even after emitting tool calls.
    if (choice.finish_reason === "stop" && toolChoices.has(index))
      choice.finish_reason = "tool_calls";
  }
  return chunk;
}

function normalizeStream(body: ReadableStream<Uint8Array>) {
  const ids = new Map<string, string>();
  const toolChoices = new Set<number>();
  let buffer = "";
  let lines: string[] = [];
  let eventChars = 0;

  function event(controller: TransformStreamDefaultController<string>) {
    const indexes: number[] = [];
    const data: string[] = [];
    for (const [index, line] of lines.entries()) {
      if (line === "data" || line.startsWith("data:")) {
        indexes.push(index);
        data.push(line === "data" ? "" : line.slice(5).replace(/^ /, ""));
      }
    }
    const payload = data.join("\n");
    if (indexes.length && payload.trim() !== "[DONE]") {
      let parsed: unknown;
      try {
        parsed = JSON.parse(payload);
      } catch {
        parsed = undefined;
      }
      if (parsed !== undefined) {
        lines[indexes[0]] = `data: ${JSON.stringify(normalizeChunk(parsed, ids, toolChoices))}`;
        for (let i = indexes.length - 1; i > 0; i--) lines.splice(indexes[i], 1);
      }
    }
    controller.enqueue(lines.join("\n") + "\n\n");
    lines = [];
    eventChars = 0;
  }

  function line(value: string, controller: TransformStreamDefaultController<string>) {
    eventChars += value.length + 1;
    if (eventChars > MAX_EVENT_CHARS)
      throw new Error("Mistral 3rd-party SSE event exceeds character limit");
    if (value === "") event(controller);
    else lines.push(value);
  }

  const decoder = new TextDecoder();
  const decoded = body.pipeThrough(
    new TransformStream<Uint8Array, string>({
      transform(bytes, controller) {
        controller.enqueue(decoder.decode(bytes, { stream: true }));
      },
      flush(controller) {
        controller.enqueue(decoder.decode());
      },
    }),
  );
  return decoded
    .pipeThrough(
      new TransformStream<string, string>({
        transform(chunk, controller) {
          buffer += chunk;
          const newline = /\r\n|\r|\n/g;
          let start = 0;
          for (let match = newline.exec(buffer); match; match = newline.exec(buffer)) {
            // A trailing CR may be the first half of CRLF in the next network chunk.
            if (match[0] === "\r" && match.index === buffer.length - 1) break;
            line(buffer.slice(start, match.index), controller);
            start = match.index + match[0].length;
          }
          buffer = buffer.slice(start);
          if (eventChars + buffer.length > MAX_EVENT_CHARS)
            throw new Error("Mistral 3rd-party SSE event exceeds character limit");
        },
        flush(controller) {
          if (buffer.endsWith("\r")) line(buffer.slice(0, -1), controller);
          else if (buffer) line(buffer, controller);
          if (lines.length) event(controller);
        },
      }),
    )
    .pipeThrough(new TextEncoderStream());
}

export function createMistral3rdPartyFetch(originalFetch: Fetch): Fetch {
  return async (input, init) => {
    const request = await prepareRequest(input, init);
    const response = await originalFetch(request?.input ?? input, request ? request.init : init);
    const contentType = response.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase();
    if (!request || !response.ok || !response.body || contentType !== "text/event-stream")
      return response;
    const headers = new Headers(response.headers);
    for (const name of [
      "content-encoding",
      "content-length",
      "content-md5",
      "digest",
      "etag",
      "transfer-encoding",
    ]) {
      headers.delete(name);
    }
    return new Response(normalizeStream(response.body), {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  };
}
