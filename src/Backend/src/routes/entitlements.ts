import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateParams } from '@middleware/validate';
import {
  resolveTier,
  checkUsageLimit,
  getUsageSummary,
} from '@services/entitlement/entitlementEngine';

const featureParamsSchema = z.object({
  feature: z.string().min(1),
});

type FeatureParams = z.infer<typeof featureParamsSchema>;

export default async function entitlementRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /entitlements - Get current user's tier and usage summary
  fastify.get(
    '/',
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const tierInfo = await resolveTier(request.userId);
        const usageSummary = await getUsageSummary(request.userId);

        return reply.status(200).send({
          tier: tierInfo.tier,
          limits: tierInfo.limits,
          expiresAt: tierInfo.expiresAt,
          usage: usageSummary.features,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch entitlement information',
        });
      }
    }
  );

  // GET /entitlements/check/:feature - Check if specific feature is available
  fastify.get<{ Params: FeatureParams }>(
    '/check/:feature',
    {
      preHandler: validateParams(featureParamsSchema),
    },
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const { feature } = request.params;

        // Validate that feature is a known feature
        const validFeatures = ['lessons', 'aiGenerations', 'voiceChats', 'children'];

        if (!validFeatures.includes(feature)) {
          return reply.status(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: `Unknown feature: ${feature}. Valid features are: ${validFeatures.join(', ')}`,
          });
        }

        const usageCheck = await checkUsageLimit(request.userId, feature);

        return reply.status(200).send({
          feature,
          isAllowed: usageCheck.isAllowed,
          currentUsage: usageCheck.currentUsage,
          limit: usageCheck.limit,
          remaining: usageCheck.remaining,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to check feature entitlement',
        });
      }
    }
  );
}
