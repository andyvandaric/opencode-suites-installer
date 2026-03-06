import { detectErrorType } from "../../recovery";
import type { ProviderAdapter } from "../../core/provider-adapter";

function isOpenAiFamilyModel(model: string): boolean {
  const lower = model.toLowerCase();
  return (
    lower.includes("openai") ||
    lower.includes("gpt") ||
    lower.startsWith("o1") ||
    lower.startsWith("o3") ||
    lower.startsWith("o4")
  );
}

export function createOpenAiProviderAdapter(): ProviderAdapter {
  return {
    id: "openai",
    matchesModel: isOpenAiFamilyModel,
    shouldSanitizeAntigravityPayload() {
      return false;
    },
    parseProviderError(errorMessage) {
      return detectErrorType(errorMessage);
    },
  };
}
