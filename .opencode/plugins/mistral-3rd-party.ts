import type { Plugin } from "@opencode-ai/plugin";
import { createMistral3rdPartyFetch, MODEL_IDS, PROVIDER_ID } from "./mistral-3rd-party/compatibility";

/** OpenCode V1 adapter for Mistral-hosted GLM 5.3, GLM 5.3 Flash and DeepSeek V4.1 Flash. No logging or extra requests. */
export const Mistral3rdPartyPlugin: Plugin = async () => ({
  async config(config) {
    const provider = config.provider?.[PROVIDER_ID];
    if (provider?.npm !== "@ai-sdk/openai-compatible" || !Object.keys(provider.models ?? {}).some((id) => MODEL_IDS.has(id))) return;
    provider.options ??= {};
    const original = provider.options.fetch;
    if (original !== undefined && typeof original !== "function") {
      throw new Error("mistral-3rd-party provider.options.fetch must be a function");
    }
    provider.options.fetch = createMistral3rdPartyFetch(
      typeof original === "function" ? (input, init) => original(input, init) : globalThis.fetch,
    );
  },
});
