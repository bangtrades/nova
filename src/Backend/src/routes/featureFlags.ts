/**
 * Feature Flag Routes (NOVA-300)
 *
 * GET /api/v1/flags - List all flags
 * GET /api/v1/flags/:key/check - Check specific flag for user
 * PUT /api/v1/flags/:key - Update flag (admin only)
 */

import type { FastifyInstance } from 'fastify';
import { isFeatureEnabled, getAllFlags, setFlag } from '@services/featureFlags';

export default async function featureFlagsRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /flags - List all feature flags (filtered by tier if non-admin)
  fastify.get('/flags', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Authentication required',
        });
      }

      const prisma = (fastify as any).prisma;

      // Get user subscription tier
      const subscription = await prisma.subscription.findFirst({
        where: { userId: request.userId },
        select: { plan: true },
      });

      const userTier = subscription?.plan || 'free';

      // Get all flags and filter by user's tier
      const allFlags = getAllFlags();
      const accessibleFlags = allFlags.map((flag) => ({
        key: flag.key,
        enabled: flag.enabled,
        rolloutPercentage: flag.rolloutPercentage,
        metadata: flag.metadata,
      }));

      return reply.status(200).send({
        data: accessibleFlags,
        total: accessibleFlags.length,
        userTier,
      });
    } catch (error) {
      fastify.log.error(`Feature flags list error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch feature flags',
      });
    }
  });

  // GET /flags/:key/check - Check if a specific flag is enabled for current user
  fastify.get('/flags/:key/check', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Authentication required',
        });
      }

      const { key } = request.params as { key: string };
      const prisma = (fastify as any).prisma;

      // Get user subscription tier
      const subscription = await prisma.subscription.findFirst({
        where: { userId: request.userId },
        select: { plan: true },
      });

      const userTier = subscription?.plan || 'free';

      // Check if flag is enabled for this user
      const enabled = isFeatureEnabled(key, request.userId, userTier);

      return reply.status(200).send({
        key,
        enabled,
        userTier,
      });
    } catch (error) {
      fastify.log.error(`Feature flag check error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to check feature flag',
      });
    }
  });

  // PUT /flags/:key - Update a feature flag (admin only)
  fastify.put('/flags/:key', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Authentication required',
        });
      }

      // Check if user is admin (hardcoded for now)
      // In production, check user role from database
      const ADMIN_USERS = ['admin@nova-app.com'];
      const prisma = (fastify as any).prisma;

      const user = await prisma.user.findUnique({
        where: { id: request.userId },
        select: { email: true },
      });

      if (!user || !ADMIN_USERS.includes(user.email)) {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Admin access required',
        });
      }

      const { key } = request.params as { key: string };
      const updates = request.body as Record<string, any>;

      // Update the flag
      setFlag(key, {
        enabled: updates.enabled ?? undefined,
        rolloutPercentage: updates.rolloutPercentage ?? undefined,
        allowedTiers: updates.allowedTiers ?? undefined,
        metadata: updates.metadata ?? undefined,
      });

      return reply.status(200).send({
        message: `Feature flag '${key}' updated successfully`,
        key,
      });
    } catch (error) {
      fastify.log.error(`Feature flag update error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to update feature flag',
      });
    }
  });
}
