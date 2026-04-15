/**
 * Entitlement Engine
 *
 * Manages subscription tiers and feature usage tracking.
 * Supports three tiers: free, pro, and byok (bring your own key).
 */

import { getPrismaClient } from '@db/client';

export type SubscriptionTier = 'free' | 'pro' | 'byok';

export interface TierLimits {
  lessons: number; // -1 = unlimited
  aiGenerations: number;
  voiceChats: number;
  children: number;
}

export const TIER_LIMITS: Record<SubscriptionTier, TierLimits> = {
  free: {
    lessons: 3,
    aiGenerations: 0,
    voiceChats: 0,
    children: 1,
  },
  pro: {
    lessons: -1,
    aiGenerations: 50,
    voiceChats: 100,
    children: 5,
  },
  byok: {
    lessons: -1,
    aiGenerations: -1,
    voiceChats: -1,
    children: 5,
  },
};

export interface TierInfo {
  tier: SubscriptionTier;
  limits: TierLimits;
  expiresAt?: Date;
}

export interface UsageCheckResult {
  isAllowed: boolean;
  currentUsage: number;
  limit: number;
  remaining: number;
}

export interface UsageSummary {
  tier: SubscriptionTier;
  features: Record<
    string,
    {
      usage: number;
      limit: number;
      remaining: number;
      resetDate?: Date;
    }
  >;
}

/**
 * Resolve the subscription tier for a user
 */
export async function resolveTier(userId: string): Promise<TierInfo> {
  const prisma = (getPrismaClient() as any);

  try {
    const subscription = await prisma.subscription.findUnique({
      where: { userId },
      select: {
        plan: true,
        expiresAt: true,
      },
    });

    if (!subscription) {
      // Default to free tier
      return {
        tier: 'free',
        limits: TIER_LIMITS.free,
      };
    }

    const tier = (subscription.plan as SubscriptionTier) || 'free';

    // Check if subscription has expired
    if (subscription.expiresAt && subscription.expiresAt < new Date()) {
      return {
        tier: 'free',
        limits: TIER_LIMITS.free,
      };
    }

    return {
      tier,
      limits: TIER_LIMITS[tier],
      expiresAt: subscription.expiresAt,
    };
  } catch (error) {
    console.error(`Error resolving tier for user ${userId}:`, error);
    return {
      tier: 'free',
      limits: TIER_LIMITS.free,
    };
  }
}

/**
 * Check if a user can use a specific feature
 */
export async function checkUsageLimit(
  userId: string,
  feature: string
): Promise<UsageCheckResult> {
  const tierInfo = await resolveTier(userId);
  const limits = tierInfo.limits;

  // Get the limit for this feature
  const limit = (limits as any)[feature];

  if (limit === undefined) {
    throw new Error(`Unknown feature: ${feature}`);
  }

  // Unlimited features always pass
  if (limit === -1) {
    return {
      isAllowed: true,
      currentUsage: 0,
      limit: -1,
      remaining: -1,
    };
  }

  // Get current usage for this month
  const prisma = (getPrismaClient() as any);
  const currentUsage = await getCurrentMonthUsage(userId, feature);

  const remaining = Math.max(0, limit - currentUsage);

  return {
    isAllowed: currentUsage < limit,
    currentUsage,
    limit,
    remaining,
  };
}

/**
 * Record usage of a feature for a user
 */
export async function recordUsage(userId: string, feature: string): Promise<void> {
  const prisma = (getPrismaClient() as any);

  try {
    // Get current month range
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    // Upsert usage record for this month
    const usageKey = `${userId}-${feature}-${monthStart.getFullYear()}-${monthStart.getMonth()}`;

    // Try to find existing record
    const existing = await prisma.usageRecord.findFirst({
      where: {
        userId,
        feature,
        recordedAt: {
          gte: monthStart,
          lte: monthEnd,
        },
      },
    });

    if (existing) {
      // Increment existing record
      await prisma.usageRecord.update({
        where: { id: existing.id },
        data: {
          count: { increment: 1 },
        },
      });
    } else {
      // Create new record
      await prisma.usageRecord.create({
        data: {
          userId,
          feature,
          count: 1,
          recordedAt: now,
        },
      });
    }
  } catch (error) {
    console.error(`Error recording usage for user ${userId}, feature ${feature}:`, error);
    // Non-critical, don't throw
  }
}

/**
 * Get usage summary for a user in the current month
 */
export async function getUsageSummary(userId: string): Promise<UsageSummary> {
  const tierInfo = await resolveTier(userId);
  const limits = tierInfo.limits;

  // Calculate month start/end
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

  // Get all usage records for this month
  const prisma = (getPrismaClient() as any);

  try {
    const usageRecords = await prisma.usageRecord.findMany({
      where: {
        userId,
        recordedAt: {
          gte: monthStart,
          lte: monthEnd,
        },
      },
    });

    // Build usage summary
    const features: Record<string, any> = {};

    const featureNames = ['lessons', 'aiGenerations', 'voiceChats', 'children'] as const;

    for (const featureName of featureNames) {
      const limit = (limits as any)[featureName];
      const usageRecord = usageRecords.find((r: any) => r.feature === featureName);
      const currentUsage = usageRecord?.count || 0;

      features[featureName] = {
        usage: currentUsage,
        limit,
        remaining: limit === -1 ? -1 : Math.max(0, limit - currentUsage),
        resetDate: new Date(monthEnd.getFullYear(), monthEnd.getMonth() + 1, 1),
      };
    }

    return {
      tier: tierInfo.tier,
      features,
    };
  } catch (error) {
    console.error(`Error getting usage summary for user ${userId}:`, error);

    // Return default summary on error
    const features: Record<string, any> = {};
    const featureNames = ['lessons', 'aiGenerations', 'voiceChats', 'children'] as const;

    for (const featureName of featureNames) {
      const limit = (limits as any)[featureName];
      features[featureName] = {
        usage: 0,
        limit,
        remaining: limit === -1 ? -1 : limit,
        resetDate: new Date(monthEnd.getFullYear(), monthEnd.getMonth() + 1, 1),
      };
    }

    return {
      tier: tierInfo.tier,
      features,
    };
  }
}

/**
 * Get current month usage count for a feature
 */
async function getCurrentMonthUsage(userId: string, feature: string): Promise<number> {
  const prisma = (getPrismaClient() as any);

  try {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    const record = await prisma.usageRecord.findFirst({
      where: {
        userId,
        feature,
        recordedAt: {
          gte: monthStart,
          lte: monthEnd,
        },
      },
    });

    return record?.count || 0;
  } catch (error) {
    console.error(
      `Error getting current month usage for user ${userId}, feature ${feature}:`,
      error
    );
    return 0;
  }
}
