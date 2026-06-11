import type { FastifyInstance } from 'fastify';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { getPrismaClient, toJsonColumn } from '@db/client';
import { validateBody, validateParams, validateQuery } from '@middleware/validate';

const createCardSchema = z.object({
  lessonId: z.string().uuid(),
  type: z.enum(['story', 'concept', 'interactive', 'quiz']),
  content: z.record(z.unknown()),
  voiceScript: z.string().optional(),
  imageUrl: z.string().url().optional(),
  audioUrl: z.string().url().optional(),
  interactionConfig: z.record(z.unknown()).optional(),
});

const updateCardSchema = z.object({
  type: z.enum(['story', 'concept', 'interactive', 'quiz']).optional(),
  content: z.record(z.unknown()).optional(),
  voiceScript: z.string().optional(),
  imageUrl: z.string().url().optional(),
  audioUrl: z.string().url().optional(),
  interactionConfig: z.record(z.unknown()).optional(),
});

const getCardsQuerySchema = z.object({
  lessonId: z.string().uuid(),
});

const reorderCardsSchema = z.object({
  cards: z.array(
    z.object({
      id: z.string().uuid(),
      sortOrder: z.number().int().min(0),
    })
  ),
});

const cardParamsSchema = z.object({
  id: z.string().uuid(),
});

type CreateCardRequest = z.infer<typeof createCardSchema>;
type UpdateCardRequest = z.infer<typeof updateCardSchema>;
type GetCardsQuery = z.infer<typeof getCardsQuerySchema>;
type ReorderCardsRequest = z.infer<typeof reorderCardsSchema>;
type CardParams = z.infer<typeof cardParamsSchema>;

export async function cardRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /cards - Get cards for a lesson
  fastify.get<{ Querystring: GetCardsQuery }>(
    '/',
    {
      preHandler: validateQuery(getCardsQuerySchema),
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

        const { lessonId } = request.query as unknown as GetCardsQuery;
        const prisma = getPrismaClient();

        // Verify lesson ownership
        const lesson = await prisma.lesson.findUnique({
          where: { id: lessonId },
          select: { userId: true },
        });

        if (!lesson) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Lesson not found',
          });
        }

        if (lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to access this lesson',
          });
        }

        const cards = await prisma.card.findMany({
          where: { lessonId },
          select: {
            id: true,
            // S12-12: iOS Card struct requires `lessonId: UUID` (the foreign-
            // key back-reference). Prior select stripped it — same class of
            // bug as the userId-stripping on /lessons + /paths. Surface the
            // field so iOS decode succeeds when FlipbookView fetches cards.
            lessonId: true,
            type: true,
            sortOrder: true,
            content: true,
            voiceScript: true,
            imageUrl: true,
            audioUrl: true,
            interactionConfig: true,
            createdAt: true,
          },
          orderBy: { sortOrder: 'asc' },
        });

        return reply.status(200).send({
          data: cards,
          total: cards.length,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch cards',
        });
      }
    }
  );

  // POST /cards - Create card
  fastify.post<{ Body: CreateCardRequest }>(
    '/',
    {
      preHandler: validateBody(createCardSchema),
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

        const {
          lessonId,
          type,
          content,
          voiceScript,
          imageUrl,
          audioUrl,
          interactionConfig,
        } = request.body;
        const prisma = getPrismaClient();

        // Verify lesson ownership
        const lesson = await prisma.lesson.findUnique({
          where: { id: lessonId },
          select: { userId: true },
        });

        if (!lesson) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Lesson not found',
          });
        }

        if (lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to add cards to this lesson',
          });
        }

        // Get max sortOrder
        const maxCard = await prisma.card.findFirst({
          where: { lessonId },
          orderBy: { sortOrder: 'desc' },
          select: { sortOrder: true },
        });

        const sortOrder = (maxCard?.sortOrder ?? -1) + 1;

        const card = await prisma.card.create({
          data: {
            lessonId,
            type,
            content: toJsonColumn(content),
            voiceScript: voiceScript || null,
            imageUrl: imageUrl || null,
            audioUrl: audioUrl || null,
            interactionConfig: interactionConfig ? toJsonColumn(interactionConfig) : null,
            sortOrder,
          },
          select: {
            id: true,
            type: true,
            sortOrder: true,
            content: true,
            voiceScript: true,
            imageUrl: true,
            audioUrl: true,
            interactionConfig: true,
            createdAt: true,
          },
        });

        return reply.status(201).send(card);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to create card',
        });
      }
    }
  );

  // PATCH /cards/:id - Update card
  fastify.patch<{ Params: CardParams; Body: UpdateCardRequest }>(
    '/:id',
    {
      preHandler: [validateParams(cardParamsSchema), validateBody(updateCardSchema)],
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
        const { type, content, voiceScript, imageUrl, audioUrl, interactionConfig } = request.body;
        const prisma = getPrismaClient();

        // Verify ownership
        const card = await prisma.card.findUnique({
          where: { id },
          select: {
            lesson: {
              select: { userId: true },
            },
          },
        });

        if (!card) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Card not found',
          });
        }

        if (card.lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to modify this card',
          });
        }

        const updateData: Prisma.CardUpdateInput = {};
        if (type) updateData.type = type;
        if (content) updateData.content = toJsonColumn(content);
        if (voiceScript) updateData.voiceScript = voiceScript;
        if (imageUrl) updateData.imageUrl = imageUrl;
        if (audioUrl) updateData.audioUrl = audioUrl;
        if (interactionConfig) updateData.interactionConfig = toJsonColumn(interactionConfig);

        const updated = await prisma.card.update({
          where: { id },
          data: updateData,
          select: {
            id: true,
            type: true,
            sortOrder: true,
            content: true,
            voiceScript: true,
            imageUrl: true,
            audioUrl: true,
            interactionConfig: true,
            createdAt: true,
          },
        });

        return reply.status(200).send(updated);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to update card',
        });
      }
    }
  );

  // POST /cards/reorder - Batch reorder cards
  fastify.post<{ Body: ReorderCardsRequest }>(
    '/reorder',
    {
      preHandler: validateBody(reorderCardsSchema),
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

        const { cards } = request.body;
        const prisma = getPrismaClient();

        // Verify all cards belong to user's lessons
        const userCards = await prisma.card.findMany({
          where: {
            id: { in: cards.map((c) => c.id) },
          },
          select: {
            id: true,
            lesson: {
              select: { userId: true },
            },
          },
        });

        for (const card of userCards) {
          if (card.lesson.userId !== request.userId) {
            return reply.status(403).send({
              statusCode: 403,
              error: 'Forbidden',
              message: 'You do not have permission to modify these cards',
            });
          }
        }

        // Update all cards
        await Promise.all(
          cards.map((card) =>
            prisma.card.update({
              where: { id: card.id },
              data: { sortOrder: card.sortOrder },
            })
          )
        );

        return reply.status(200).send({
          message: 'Cards reordered successfully',
          count: cards.length,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to reorder cards',
        });
      }
    }
  );

  // DELETE /cards/:id - Delete card
  fastify.delete<{ Params: CardParams }>(
    '/:id',
    {
      preHandler: validateParams(cardParamsSchema),
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
        const card = await prisma.card.findUnique({
          where: { id },
          select: {
            lesson: {
              select: { userId: true },
            },
          },
        });

        if (!card) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Card not found',
          });
        }

        if (card.lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to delete this card',
          });
        }

        await prisma.card.delete({
          where: { id },
        });

        return reply.status(204).send();
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to delete card',
        });
      }
    }
  );
}
