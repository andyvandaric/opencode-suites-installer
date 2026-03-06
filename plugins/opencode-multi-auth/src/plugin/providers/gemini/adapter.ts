import { detectErrorType } from "../../recovery";
import type { ProviderAdapter } from "../../core/provider-adapter";

function isGeminiFamilyModel(model: string): boolean {
  const lower = model.toLowerCase();
  return lower.includes("gemini") || lower.includes("learnlm") || lower.includes("imagen");
}

export function createGeminiProviderAdapter(): ProviderAdapter {
  return {
    id: "gemini",
    matchesModel: isGeminiFamilyModel,
    shouldSanitizeAntigravityPayload(context) {
      const lower = context.effectiveModel.toLowerCase();
      return (
        !context.isClaude &&
        (lower.includes("gemini-3") || lower.includes("gemini-experimental"))
      );
    },
    parseProviderError(errorMessage) {
      return detectErrorType(errorMessage);
    },
  };
}
