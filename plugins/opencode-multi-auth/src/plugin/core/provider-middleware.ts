import type {
  ProviderAdapter,
  ProviderErrorContext,
  ProviderRequestContext,
} from "./provider-adapter";
import {
  parseProviderError as parseProviderErrorByRegistry,
  shouldSanitizePayloadForProvider,
} from "./provider-registry";

export function runProviderRequestMiddleware(
  providerAdapter: ProviderAdapter,
  context: ProviderRequestContext,
  sanitizePayload: () => void,
): void {
  if (!shouldSanitizePayloadForProvider(providerAdapter, context)) {
    return;
  }
  sanitizePayload();
}

export function parseProviderError(
  providerAdapter: ProviderAdapter,
  errorMessage: string,
  context: ProviderErrorContext,
) {
  return parseProviderErrorByRegistry(providerAdapter, errorMessage, context);
}
