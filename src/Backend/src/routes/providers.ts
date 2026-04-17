/**
 * Provider management routes for LLM providers
 *
 * CRUD operations and testing for connected LLM providers
 */

import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams } from '@middleware/validate';
import { routeRequest, getRoutingInfo } from '@services/llm/providerRouter';
import { getProxyUsageInfo } from '@services/llm/proxyProvider';
import type { LLMRequest } from '@services/llm/types';

const providerIdSchema = z.object({
  id: z.string().uuid(),
});

const testProviderSchema = z.object({
  message: z.string().default('Hello'),
});

type ProviderIdParams = z.infer<typeof providerIdSchema>;
type TestProviderRequest = z.infer<typeof testProviderSchema>;

export async function providersRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /providers - List user's connected providers
  fastify.get('/', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const prisma = getPrismaClient();

      // Get all connected providers
      const providers = await prisma.lLMProvider.findMany({
        where: {
          userId: request.userId,
        },
        select: {
          id: true,
          provider: true,
          status: true,
          connectedAt: true,
          tokenExpiresAt: true,
          updatedAt: true,
        },
      });

      // Get subscription tier for rate limit info
      const subscription = await prisma.subscription.findUnique({
        where: { userId: request.userId },
        select: { plan: true },
      });

      const tier = (subscription?.plan as 'free' | 'pro') || 'free';
      const proxyUsage = getProxyUsageInfo(request.userId, tier);

      return reply.status(200).send({
        providers,
        proxyUsage,
        subscriptionTier: tier,
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: error instanceof Error ? error.message : 'Failed to fetch providers',
      });
    }
  });

  // GET /providers/:id - Get provider details
  fastify.get<{ Params: ProviderIdParams }>(
    '/:id',
    {
      preHandler: validateParams(providerIdSchema),
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

        const { id } = request.params;
        const prisma = getPrismaClient();

        // Verify ownership
        const provider = await prisma.lLMProvider.findUnique({
          where: { id },
          select: {
            userId: true,
            provider: true,
            status: true,
            connectedAt: true,
            tokenExpiresAt: true,
            updatedAt: true,
          },
        });

        if (!provider) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Provider not found',
          });
        }

        if (provider.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view this provider',
          });
        }

        const isTokenExpired = provider.tokenExpiresAt
          ? provider.tokenExpiresAt < new Date()
          : false;

        return reply.status(200).send({
          id,
          ...provider,
          tokenExpired: isTokenExpired,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to fetch provider',
        });
      }
    }
  );

  // DELETE /providers/:id - Disconnect provider
  fastify.delete<{ Params: ProviderIdParams }>(
    '/:id',
    {
      preHandler: validateParams(providerIdSchema),
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

        const { id } = request.params;
        const prisma = getPrismaClient();

        // Verify ownership
        const provider = await prisma.lLMProvider.findUnique({
          where: { id },
          select: { userId: true },
        });

        if (!provider) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Provider not found',
          });
        }

        if (provider.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to disconnect this provider',
          });
        }

        // Delete the provider
        await prisma.lLMProvider.delete({
          where: { id },
        });

        return reply.status(204).send();
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to disconnect provider',
        });
      }
    }
  );

  // POST /providers/test - Test an LLM call through the router
  fastify.post<{ Body: TestProviderRequest }>(
    '/test',
    {
      preHandler: validateBody(testProviderSchema),
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

        const { message } = request.body;

        // Build a test LLM request
        const llmRequest: LLMRequest = {
          model: 'gpt-4o-mini',
          messages: [
            {
              role: 'user',
              content: message,
            },
          ],
          temperature: 0.7,
          maxTokens: 150,
        };

        // Route the request
        const response = await routeRequest(request.userId, llmRequest, 'other');

        // Get routing info for context
        const routingInfo = await getRoutingInfo(request.userId);

        return reply.status(200).send({
          message: 'Test request completed successfully',
          response,
          routingInfo,
        });
      } catch (error) {
        fastify.log.error(error);

        // Handle specific error types
        if (error instanceof Error) {
          if (error.message.includes('rate limit') || error.message.includes('Rate limit')) {
            return reply.status(429).send({
              statusCode: 429,
              error: 'Too Many Requests',
              message: error.message,
            });
          }

          if (error.message.includes('not allowed') || error.message.includes('API key')) {
            return reply.status(400).send({
              statusCode: 400,
              error: 'Bad Request',
              message: error.message,
            });
          }
        }

        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to test provider',
        });
      }
    }
  );

  // GET /providers/status/routing - Get routing decision info
  fastify.get('/status/routing', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const routingInfo = await getRoutingInfo(request.userId);

      return reply.status(200).send({
        message: 'Routing information',
        ...routingInfo,
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: error instanceof Error ? error.message : 'Failed to get routing info',
      });
    }
  });
}
