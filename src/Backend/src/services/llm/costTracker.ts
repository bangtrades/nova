/**
 * LLM Cost Tracker Service
 *
 * Logs every LLM/AI call with model, tokens, and estimated cost.
 * Supports: Claude, GPT-4o, GPT-4o-mini, DALL-E 3, TTS-1.
 * Provides per-user and aggregate cost queries.
 */

import { getPrismaClient } from '@db/client';

// Cost per 1M tokens (in cents USD) — updated April 2026
const TOKEN_COSTS: Record<string, { input: number; output: number }> = {
  'claude-sonnet': { input: 300, output: 1500 },       // $3/$15 per 1M
  'claude-3-5-sonnet': { input: 300, output: 1500 },
  'claude-haiku': { input: 25, output: 125 },
  'gpt-4o': { input: 250, output: 1000 },              // $2.50/$10 per 1M
  'gpt-4o-mini': { input: 15, output: 60 },             // $0.15/$0.60 per 1M
};

// Flat cost per call (in cents USD)
const FLAT_COSTS: Record<string, number> = {
  'dall-e-3': 4,        // $0.04 per image (standard 1024x1024)
  'dall-e-3-hd': 8,     // $0.08 per image (HD)
  'tts-1': 1.5,         // ~$0.015 per 1K chars (avg ~150 words = $0.015)
  'tts-1-hd': 3,        // $0.03 per 1K chars
};

export type CostFeature =
  | 'content_analysis'
  | 'safety_filter'
  | 'concept_decomposition'
  | 'card_generation'
  | 'card_regeneration'
  | 'dashy_chat'
  | 'image_gen'
  | 'tts'
  | 'quality_gate'
  | 'other';

export interface LogUsageParams {
  userId: string;
  provider: string;
  model: string;
  feature: CostFeature;
  promptTokens?: number;
  completionTokens?: number;
  totalTokens?: number;
  metadata?: Record<string, unknown>;
}

/**
 * Calculate cost in cents from token counts and model
 */
function calculateTokenCost(model: string, promptTokens: number, completionTokens: number): number {
  const costs = TOKEN_COSTS[model];
  if (!costs) return 0;

  const inputCost = (promptTokens / 1_000_000) * costs.input;
  const outputCost = (completionTokens / 1_000_000) * costs.output;
  return Math.round((inputCost + outputCost) * 10000) / 10000; // 4 decimal places
}

/**
 * Calculate flat cost for non-token-based models (images, TTS)
 */
function calculateFlatCost(model: string, metadata?: Record<string, unknown>): number {
  const baseCost = FLAT_COSTS[model];
  if (!baseCost) return 0;

  // For TTS, scale by character count if available
  if (model.startsWith('tts-') && metadata?.charCount) {
    const chars = metadata.charCount as number;
    return Math.round((chars / 1000) * baseCost * 10000) / 10000;
  }

  return baseCost;
}

/**
 * Log an LLM/AI usage event with cost calculation
 */
export async function logUsage(params: LogUsageParams): Promise<void> {
  const prisma = getPrismaClient();

  const promptTokens = params.promptTokens ?? 0;
  const completionTokens = params.completionTokens ?? 0;
  const totalTokens = params.totalTokens ?? (promptTokens + completionTokens);

  // Calculate cost
  let costCents: number;
  if (FLAT_COSTS[params.model]) {
    costCents = calculateFlatCost(params.model, params.metadata);
  } else {
    costCents = calculateTokenCost(params.model, promptTokens, completionTokens);
  }

  try {
    await prisma.llmUsageLog.create({
      data: {
        userId: params.userId,
        provider: params.provider,
        model: params.model,
        feature: params.feature,
        promptTokens,
        completionTokens,
        totalTokens,
        costCents,
        metadata: (params.metadata ?? null) as any,
      },
    });
  } catch (error) {
    // Never let cost tracking break the main flow
    console.error('[CostTracker] Failed to log usage:', error);
  }
}

/**
 * Get cost summary for a user within a date range
 */
export async function getUserCostSummary(
  userId: string,
  startDate?: Date,
  endDate?: Date
): Promise<{
  totalCostCents: number;
  totalTokens: number;
  callCount: number;
  byModel: Record<string, { calls: number; tokens: number; costCents: number }>;
  byFeature: Record<string, { calls: number; tokens: number; costCents: number }>;
}> {
  const prisma = getPrismaClient();

  const where: any = { userId };
  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = startDate;
    if (endDate) where.createdAt.lte = endDate;
  }

  const logs = await prisma.llmUsageLog.findMany({ where });

  const byModel: Record<string, { calls: number; tokens: number; costCents: number }> = {};
  const byFeature: Record<string, { calls: number; tokens: number; costCents: number }> = {};
  let totalCostCents = 0;
  let totalTokens = 0;

  for (const log of logs) {
    totalCostCents += log.costCents;
    totalTokens += log.totalTokens;

    // Aggregate by model
    if (!byModel[log.model]) byModel[log.model] = { calls: 0, tokens: 0, costCents: 0 };
    byModel[log.model].calls += 1;
    byModel[log.model].tokens += log.totalTokens;
    byModel[log.model].costCents += log.costCents;

    // Aggregate by feature
    if (!byFeature[log.feature]) byFeature[log.feature] = { calls: 0, tokens: 0, costCents: 0 };
    byFeature[log.feature].calls += 1;
    byFeature[log.feature].tokens += log.totalTokens;
    byFeature[log.feature].costCents += log.costCents;
  }

  return {
    totalCostCents: Math.round(totalCostCents * 100) / 100,
    totalTokens,
    callCount: logs.length,
    byModel,
    byFeature,
  };
}

/**
 * Get aggregate cost summary across all users (admin)
 */
export async function getAggregateCostSummary(
  startDate?: Date,
  endDate?: Date
): Promise<{
  totalCostCents: number;
  totalTokens: number;
  callCount: number;
  byUser: Record<string, { calls: number; costCents: number }>;
  byModel: Record<string, { calls: number; tokens: number; costCents: number }>;
  byFeature: Record<string, { calls: number; tokens: number; costCents: number }>;
  dailyCosts: Record<string, number>;
}> {
  const prisma = getPrismaClient();

  const where: any = {};
  if (startDate || endDate) {
    where.createdAt = {};
    if (startDate) where.createdAt.gte = startDate;
    if (endDate) where.createdAt.lte = endDate;
  }

  const logs = await prisma.llmUsageLog.findMany({ where });

  const byUser: Record<string, { calls: number; costCents: number }> = {};
  const byModel: Record<string, { calls: number; tokens: number; costCents: number }> = {};
  const byFeature: Record<string, { calls: number; tokens: number; costCents: number }> = {};
  const dailyCosts: Record<string, number> = {};
  let totalCostCents = 0;
  let totalTokens = 0;

  for (const log of logs) {
    totalCostCents += log.costCents;
    totalTokens += log.totalTokens;

    // By user
    if (!byUser[log.userId]) byUser[log.userId] = { calls: 0, costCents: 0 };
    byUser[log.userId].calls += 1;
    byUser[log.userId].costCents += log.costCents;

    // By model
    if (!byModel[log.model]) byModel[log.model] = { calls: 0, tokens: 0, costCents: 0 };
    byModel[log.model].calls += 1;
    byModel[log.model].tokens += log.totalTokens;
    byModel[log.model].costCents += log.costCents;

    // By feature
    if (!byFeature[log.feature]) byFeature[log.feature] = { calls: 0, tokens: 0, costCents: 0 };
    byFeature[log.feature].calls += 1;
    byFeature[log.feature].tokens += log.totalTokens;
    byFeature[log.feature].costCents += log.costCents;

    // Daily
    const day = log.createdAt.toISOString().split('T')[0];
    dailyCosts[day] = (dailyCosts[day] ?? 0) + log.costCents;
  }

  return {
    totalCostCents: Math.round(totalCostCents * 100) / 100,
    totalTokens,
    callCount: logs.length,
    byUser,
    byModel,
    byFeature,
    dailyCosts,
  };
}
