/**
 * Shared types for the LLM provider system
 */

export type ProviderType = 'byok' | 'proxy';

export interface LLMMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface LLMRequest {
  model: string;
  messages: LLMMessage[];
  temperature?: number;
  maxTokens?: number;
}

export interface UsageRecord {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface LLMResponse {
  content: string;
  model: string;
  usage: UsageRecord;
  provider: ProviderType;
  finishReason?: string;
}

export interface LLMError {
  code: string;
  message: string;
  statusCode: number;
  retryable: boolean;
}

/**
 * Rate limit tracking per user per day
 */
export interface DailyUsageRecord {
  userId: string;
  date: string; // YYYY-MM-DD
  requestCount: number;
  tokenCount: number;
  lastRequestAt: Date;
}
