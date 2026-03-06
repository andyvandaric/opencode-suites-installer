import type { HeaderStyle } from "../../constants";
import type { RecoveryErrorType } from "../recovery/types";

export type ProviderId = "gemini" | "openai" | "generic";

export interface ProviderRequestContext {
  effectiveModel: string;
  requestedModel?: string;
  headerStyle: HeaderStyle;
  isStreaming: boolean;
  isWrappedRequest: boolean;
  isClaude: boolean;
  isClaudeThinking: boolean;
  signatureSessionKey?: string;
}

export interface ProviderErrorContext {
  effectiveModel?: string;
  requestedModel?: string;
  endpoint?: string;
  status?: number;
}

export interface ProviderAdapter {
  id: ProviderId;
  matchesModel(model: string): boolean;
  shouldSanitizeAntigravityPayload?(context: ProviderRequestContext): boolean;
  parseProviderError?(errorMessage: string, context: ProviderErrorContext): RecoveryErrorType;
}
