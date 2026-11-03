import type { Plugin } from "@opencode-ai/plugin";
import { createMistralGlmFetch, MODEL_ID, PROVIDER_ID } from "./mistral-glm/compatibility";

/** OpenCode V1 adapter for Mistral-hosted GLM 5.3. No logging or extra requests. */
export const MistralGlmPlugin: Plugin = async () => ({
  async config(config) {
    const provider = config.provider?.[PROVIDER_ID];
    if (provider?.npm !== "@ai-sdk/openai-compatible" || !provider.models?.[MODEL_ID]) return;
    provider.options ??= {};
    const original = provider.options.fetch;
    if (original !== undefined && typeof original !== "function") {
      throw new Error("mistral-glm provider.options.fetch must be a function");
    }
    provider.options.fetch = createMistralGlmFetch(
      typeof original === "function" ? (input, init) => original(input, init) : globalThis.fetch,
    );
  },
});
