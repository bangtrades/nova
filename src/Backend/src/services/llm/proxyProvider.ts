/**
 * Proxy provider using the platform's own OpenAI API key
 *
 * Provides LLM access to users based on their subscription tier:
 * - Free users: gpt-4o-mini only (limited usage)
 * - Pro users: gpt-4o allowed (increased usage limit)
 */

import { getConfig } from '@config';
import type { LLMRequest, LLMResponse } from './types';
import { chatCompletion, OpenAIProviderError } from './openaiProvider';

/**
 * In-memory daily usage tracker
 * Production would use database or Redis
 */
interface UsageEntry {
  requestCount: number;
  tokenCount: number;
  timestamp: Date;
}

const dailyUsage = new Map<string, UsageEntry>();

/**
 * Reset daily usage at midnight
 */
function resetDailyUsageIfNeeded(): void {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const lastResetKey = '__lastReset';
  const lastReset = dailyUsage.get(lastResetKey);

  if (!lastReset || lastReset.timestamp.toISOString().split('T')[0] !== today) {
    dailyUsage.clear();
    dailyUsage.set(lastResetKey, { requestCount: 0, tokenCount: 0, timestamp: now });
  }
}

/**
 * Get user's daily usage
 */
function getDailyUsage(userId: string): { requestCount: number; tokenCount: number } {
  resetDailyUsageIfNeeded();
  const entry = dailyUsage.get(userId);
  return {
    requestCount: entry?.requestCount ?? 0,
    tokenCount: entry?.tokenCount ?? 0,
  };
}

/**
 * Update user's daily usage
 */
function updateDailyUsage(userId: string, requestCount: number, tokenCount: number): void {
  resetDailyUsageIfNeeded();
  const current = getDailyUsage(userId);
  dailyUsage.set(userId, {
    requestCount: current.requestCount + requestCount,
    tokenCount: current.tokenCount + tokenCount,
    timestamp: new Date(),
  });
}

/**
 * Validates if a model is allowed for a subscription tier
 * @param model - The requested model
 * @param tier - The user's subscription tier
 * @returns true if allowed, false otherwise
 */
function isModelAllowed(model: string, tier: 'free' | 'pro'): boolean {
  const freeAllowed = ['gpt-4o-mini'];
  const proAllowed = ['gpt-4o', 'gpt-4o-mini'];

  const allowedModels = tier === 'pro' ? proAllowed : freeAllowed;
  return allowedModels.includes(model);
}

/**
 * Check if user has exceeded their daily rate limit
 */
function hasExceededRateLimit(
  userId: string,
  tier: 'free' | 'pro'
): { exceeded: boolean; limit: number; current: number } {
  const limits = {
    free: 10, // 10 requests per day
    pro: 100, // 100 requests per day
  };

  const usage = getDailyUsage(userId);
  const limit = limits[tier];

  return {
    exceeded: usage.requestCount >= limit,
    limit,
    current: usage.requestCount,
  };
}

/**
 * Process a chat completion through the proxy with subscription checks
 */
export async function chatCompletionProxy(
  userId: string,
  tier: 'free' | 'pro',
  request: LLMRequest
): Promise<LLMResponse> {
  const config = getConfig();

  if (!config.OPENAI_API_KEY) {
    throw new Error('Proxy provider OPENAI_API_KEY not configured');
  }

  // Validate model is allowed for tier
  if (!isModelAllowed(request.model, tier)) {
    const allowed = tier === 'pro' ? 'gpt-4o, gpt-4o-mini' : 'gpt-4o-mini';
    throw new Error(`Model '${request.model}' not allowed for ${tier} tier. Allowed: ${allowed}`);
  }

  // Check rate limit
  const rateLimit = hasExceededRateLimit(userId, tier);
  if (rateLimit.exceeded) {
    const error = new Error(`Daily request limit exceeded (${rateLimit.current}/${rateLimit.limit})`);
    (error as any).code = 'rate_limit_exceeded';
    (error as any).statusCode = 429;
    throw error;
  }

  // Call OpenAI with platform's API key
  const response = await chatCompletion(config.OPENAI_API_KEY, request);

  // Track usage
  updateDailyUsage(userId, 1, response.usage.totalTokens);

  return {
    ...response,
    provider: 'proxy',
  };
}

/**
 * Get usage information for a user
 */
export function getProxyUsageInfo(
  userId: string,
  tier: 'free' | 'pro'
): {
  current: number;
  limit: number;
  remaining: number;
  resetAt: string;
} {
  const limits = {
    free: 10,
    pro: 100,
  };

  const usage = getDailyUsage(userId);
  const limit = limits[tier];
  const remaining = Math.max(0, limit - usage.requestCount);

  // Calculate reset time (midnight UTC)
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(0, 0, 0, 0);

  return {
    current: usage.requestCount,
    limit,
    remaining,
    resetAt: tomorrow.toISOString(),
  };
}
