import { detectErrorType } from "../recovery";
import { createGeminiProviderAdapter } from "../providers/gemini";
import { createOpenAiProviderAdapter } from "../providers/openai";
import type {
  ProviderAdapter,
  ProviderErrorContext,
  ProviderRequestContext,
} from "./provider-adapter";

const DEFAULT_PROVIDER_ADAPTER: ProviderAdapter = {
  id: "generic",
  matchesModel() {
    return true;
  },
  shouldSanitizeAntigravityPayload() {
    return false;
  },
  parseProviderError(errorMessage) {
    return detectErrorType(errorMessage);
  },
};

const REGISTERED_PROVIDERS: ProviderAdapter[] = [
  createGeminiProviderAdapter(),
  createOpenAiProviderAdapter(),
];

export function getProviderAdapter(model: string): ProviderAdapter {
  for (const provider of REGISTERED_PROVIDERS) {
    if (provider.matchesModel(model)) {
      return provider;
    }
  }
  return DEFAULT_PROVIDER_ADAPTER;
}

export function shouldSanitizePayloadForProvider(
  providerAdapter: ProviderAdapter,
  context: ProviderRequestContext,
): boolean {
  return providerAdapter.shouldSanitizeAntigravityPayload?.(context) === true;
}

export function parseProviderError(
  providerAdapter: ProviderAdapter,
  errorMessage: string,
  context: ProviderErrorContext,
) {
  return providerAdapter.parseProviderError?.(errorMessage, context) ?? detectErrorType(errorMessage);
}
