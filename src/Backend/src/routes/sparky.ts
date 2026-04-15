import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateBody, validateParams } from '@middleware/validate';
import { processSparkyMessage } from '@services/sparky/conversationEngine';
import { checkUsageLimit, recordUsage } from '@services/entitlement/entitlementEngine';
import { randomUUID } from 'crypto';

const sparkyMessageSchema = z.object({
  childId: z.string().uuid(),
  transcript: z.string().min(1, 'Transcript cannot be empty').max(1000),
  conversationHistory: z
    .array(
      z.object({
        role: z.enum(['user', 'assistant']),
        content: z.string(),
      })
    )
    .optional()
    .default([]),
  providerId: z.string().optional(),
});

const childParamsSchema = z.object({
  childId: z.string().uuid(),
});

type SparkyMessageRequest = z.infer<typeof sparkyMessageSchema>;
type ChildParams = z.infer<typeof childParamsSchema>;

export default async function sparkyRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /sparky/chat - Process a message with Sparky
  fastify.post<{ Body: SparkyMessageRequest }>(
    '/chat',
    {
      preHandler: validateBody(sparkyMessageSchema),
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

        const { childId, transcript, conversationHistory, providerId } = request.body;
        const prisma = (fastify as any).prisma;

        // Verify child ownership
        const child = await prisma.childProfile.findUnique({
          where: { id: childId },
          select: { userId: true },
        });

        if (!child) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Child profile not found',
          });
        }

        if (child.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to chat with this child',
          });
        }

        // Check usage limit for voice chats
        const usageCheck = await checkUsageLimit(request.userId, 'voiceChats');

        if (!usageCheck.isAllowed) {
          return reply.status(429).send({
            statusCode: 429,
            error: 'Too Many Requests',
            message: 'Voice chat limit reached for this month',
            remaining: usageCheck.remaining,
            limit: usageCheck.limit,
          });
        }

        // Record usage
        await recordUsage(request.userId, 'voiceChats');

        // Process the message with Sparky
        const sparkyResponse = await processSparkyMessage(
          childId,
          transcript,
          conversationHistory,
          providerId
        );

        // Generate a conversation ID
        const conversationId = randomUUID();

        // Create conversation record (optional - for analytics)
        try {
          await prisma.sparkyConversation.create({
            data: {
              id: conversationId,
              childId,
              transcript,
              response: sparkyResponse.text,
              emotion: sparkyResponse.emotion,
              followUpQuestions: sparkyResponse.followUpQuestions,
            },
          });
        } catch (dbError) {
          // Log but don't fail if conversation record creation fails
          fastify.log.warn(`Failed to record Sparky conversation: ${dbError}`);
        }

        return reply.status(200).send({
          response: sparkyResponse.text,
          emotion: sparkyResponse.emotion,
          suggestions: sparkyResponse.followUpQuestions,
          conversationId,
        });
      } catch (error) {
        fastify.log.error(error);

        // Check if it's a provider error
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';

        if (errorMessage.includes('provider') || errorMessage.includes('API')) {
          return reply.status(502).send({
            statusCode: 502,
            error: 'Bad Gateway',
            message: 'LLM provider error. Please try again later.',
          });
        }

        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to process Sparky message',
        });
      }
    }
  );
}
