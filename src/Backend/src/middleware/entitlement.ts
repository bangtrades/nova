/**
 * Subscription-aware entitlement middleware
 *
 * Guards routes based on subscription tier and caches subscription lookups
 * for performance (5-minute cache).
 */

import type { FastifyRequest, FastifyReply } from 'fastify';
import { getPrismaClient } from '@db/client';

type SubscriptionTier = 'free' | 'pro' | 'byok';

interface CachedSubscription {
  tier: SubscriptionTier;
  expiresAt: Date;
}

/**
 * Simple in-memory cache for subscription lookups
 * In production, this would use Redis
 */
const subscriptionCache = new Map<string, CachedSubscription>();

const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

/**
 * Get cached subscription or fetch from database
 */
async function getSubscriptionTier(userId: string): Promise<SubscriptionTier> {
  // Check cache first
  const cached = subscriptionCache.get(userId);
  if (cached && cached.expiresAt > new Date()) {
    return cached.tier;
  }

  // Fetch from database
  const prisma = getPrismaClient();
  const subscription = await prisma.subscription.findUnique({
    where: { userId },
    select: { plan: true },
  });

  const tier = (subscription?.plan as SubscriptionTier) || 'free';

  // Cache the result
  subscriptionCache.set(userId, {
    tier,
    expiresAt: new Date(Date.now() + CACHE_TTL_MS),
  });

  return tier;
}

/**
 * Invalidate subscription cache for a user
 * Useful when subscription is updated
 */
export function invalidateSubscriptionCache(userId: string): void {
  subscriptionCache.delete(userId);
}

/**
 * Create an entitlement middleware that requires a minimum subscription tier
 * @param minTier - The minimum required tier: 'free', 'pro', or 'byok'
 * @returns A Fastify preHandler middleware
 */
export function requireSubscription(minTier: SubscriptionTier) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }

    try {
      const userTier = await getSubscriptionTier(request.userId);

      // Tier hierarchy: free < pro < byok
      const tierHierarchy: Record<SubscriptionTier, number> = {
        free: 0,
        pro: 1,
        byok: 2,
      };

      const userTierLevel = tierHierarchy[userTier];
      const requiredTierLevel = tierHierarchy[minTier];

      if (userTierLevel < requiredTierLevel) {
        const tierNames: Record<SubscriptionTier, string> = {
          free: 'Free',
          pro: 'Pro',
          byok: 'Bring Your Own Key',
        };

        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: `This feature requires ${tierNames[minTier]} subscription`,
          currentTier: tierNames[userTier],
          requiredTier: tierNames[minTier],
          upgradeUrl: '/api/v1/subscription/upgrade',
        });
      }

      // Attach tier to request for downstream handlers
      (request as any).subscriptionTier = userTier;
    } catch (error) {
      console.error('Failed to check subscription tier:', error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to verify subscription',
      });
    }
  };
}

/**
 * Get the subscription tier from a request (set by middleware)
 */
export function getRequestSubscriptionTier(request: FastifyRequest): SubscriptionTier {
  return (request as any).subscriptionTier || 'free';
}
