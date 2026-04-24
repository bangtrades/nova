import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams, validateQuery } from '@middleware/validate';

const createLessonSchema = z.object({
  pathId: z.string().uuid().optional(),
  title: z.string().min(1).max(255),
  description: z.string().max(1000).optional(),
  thumbnailUrl: z.string().url().optional(),
  difficulty: z.number().int().min(1).max(10).default(1),
  sourceUrl: z.string().url().optional(),
});

const updateLessonSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  description: z.string().max(1000).optional(),
  thumbnailUrl: z.string().url().optional(),
  difficulty: z.number().int().min(1).max(10).optional(),
  sourceUrl: z.string().url().optional(),
});

const listLessonsQuerySchema = z.object({
  pathId: z.string().uuid().optional(),
  status: z.enum(['draft', 'published']).optional(),
  page: z.string().pipe(z.coerce.number().int().min(1)).default('1'),
  limit: z.string().pipe(z.coerce.number().int().min(1).max(100)).default('20'),
});

const lessonParamsSchema = z.object({
  id: z.string().uuid(),
});

type CreateLessonRequest = z.infer<typeof createLessonSchema>;
type UpdateLessonRequest = z.infer<typeof updateLessonSchema>;
type ListLessonsQuery = z.infer<typeof listLessonsQuerySchema>;
type LessonParams = z.infer<typeof lessonParamsSchema>;

export async function lessonRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /lessons - List lessons with filtering and pagination
  fastify.get<{ Querystring: ListLessonsQuery }>(
    '/',
    {
      preHandler: validateQuery(listLessonsQuerySchema),
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

        // S11-19: the list endpoint is a GET, so the validated pagination +
        // filter values live on `request.query` (not `request.params`, which
        // carry URL path segments). Reading `.params` here was silently
        // coercing to `undefined` and defaulting every list call to page 1
        // with no filter applied — fine by accident, but wrong in principle
        // and guaranteed to break the first time someone passes `?path_id=`.
        const { pathId, status, page, limit } = request.query as unknown as ListLessonsQuery;
        const prisma = getPrismaClient();
        const skip = (page - 1) * limit;

        const where = {
          userId: request.userId,
          ...(pathId && { pathId }),
          ...(status && { status }),
        };

        const [lessons, total] = await Promise.all([
          prisma.lesson.findMany({
            where,
            select: {
              id: true,
              // S12-10: surface pathId + a cheap card count so the Dev
              // Console's Content Browser can bucket + badge lessons
              // without a second round-trip per row.
              pathId: true,
              title: true,
              description: true,
              thumbnailUrl: true,
              difficulty: true,
              status: true,
              sortOrder: true,
              createdAt: true,
              publishedAt: true,
              // S12-10 R3: surface sourceUrl on the list payload so the
              // Content Browser's Re-seed action can pre-fill the Author
              // tab without a per-row detail fetch. Pipeline-seeded
              // lessons always have this (pipelineOrchestrator persists
              // `sourceUrl: ingest.url`); manually-POSTed lessons may
              // have it null, which the frontend handles by disabling
              // the Re-seed button for that row.
              sourceUrl: true,
              _count: { select: { cards: true } },
            },
            orderBy: { sortOrder: 'asc' },
            skip,
            take: limit,
          }),
          prisma.lesson.count({ where }),
        ]);

        const totalPages = Math.ceil(total / limit);

        // S12-10 — unwrap Prisma's `_count.cards` aggregate into a flat
        // `cardCount` field so the frontend doesn't need to know about the
        // `_count` indirection. The Dev Console Content Browser reads this
        // field to render per-lesson card-count badges.
        const shaped = lessons.map((l: any) => {
          const cardCount = l._count?.cards ?? 0;
          // Drop the internal `_count` shape from the wire response — it
          // leaks Prisma-specific naming that clients shouldn't see.
          const { _count, ...rest } = l;
          return { ...rest, cardCount };
        });

        return reply.status(200).send({
          data: shaped,
          total,
          page,
          limit,
          totalPages,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch lessons',
        });
      }
    }
  );

  // POST /lessons - Create lesson
  fastify.post<{ Body: CreateLessonRequest }>(
    '/',
    {
      preHandler: validateBody(createLessonSchema),
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

        const { pathId, title, description, thumbnailUrl, difficulty, sourceUrl } = request.body;
        const prisma = getPrismaClient();

        // Verify path ownership if pathId is provided
        if (pathId) {
          const path = await prisma.learningPath.findUnique({
            where: { id: pathId },
            select: { userId: true },
          });
          if (!path || path.userId !== request.userId) {
            return reply.status(403).send({
              statusCode: 403,
              error: 'Forbidden',
              message: 'You do not have permission to use this learning path',
            });
          }
        }

        const lesson = await prisma.lesson.create({
          data: {
            pathId: pathId || null,
            userId: request.userId,
            title,
            description: description || null,
            thumbnailUrl: thumbnailUrl || null,
            difficulty,
            sourceUrl: sourceUrl || null,
            status: 'draft',
            sortOrder: 0,
          },
          select: {
            id: true,
            title: true,
            description: true,
            thumbnailUrl: true,
            difficulty: true,
            status: true,
            sortOrder: true,
            createdAt: true,
            publishedAt: true,
          },
        });

        return reply.status(201).send(lesson);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to create lesson',
        });
      }
    }
  );

  // GET /lessons/:id - Get lesson with cards
  fastify.get<{ Params: LessonParams }>(
    '/:id',
    {
      preHandler: validateParams(lessonParamsSchema),
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

        const lesson = await prisma.lesson.findUnique({
          where: { id },
          select: {
            id: true,
            userId: true,
            title: true,
            description: true,
            thumbnailUrl: true,
            difficulty: true,
            sourceUrl: true,
            status: true,
            sortOrder: true,
            createdAt: true,
            publishedAt: true,
            cards: {
              select: {
                id: true,
                type: true,
                content: true,
                voiceScript: true,
                imageUrl: true,
                audioUrl: true,
                sortOrder: true,
                createdAt: true,
              },
              orderBy: { sortOrder: 'asc' },
            },
          },
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

        const { userId: _, ...lessonData } = lesson;
        return reply.status(200).send(lessonData);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch lesson',
        });
      }
    }
  );

  // PATCH /lessons/:id - Update lesson
  fastify.patch<{ Params: LessonParams; Body: UpdateLessonRequest }>(
    '/:id',
    {
      preHandler: [validateParams(lessonParamsSchema), validateBody(updateLessonSchema)],
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
        const { title, description, thumbnailUrl, difficulty, sourceUrl } = request.body;
        const prisma = getPrismaClient();

        // Verify ownership
        const lesson = await prisma.lesson.findUnique({
          where: { id },
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
            message: 'You do not have permission to modify this lesson',
          });
        }

        const updated = await prisma.lesson.update({
          where: { id },
          data: {
            ...(title && { title }),
            ...(description && { description }),
            ...(thumbnailUrl && { thumbnailUrl }),
            ...(difficulty && { difficulty }),
            ...(sourceUrl && { sourceUrl }),
          },
          select: {
            id: true,
            title: true,
            description: true,
            thumbnailUrl: true,
            difficulty: true,
            status: true,
            sortOrder: true,
            createdAt: true,
            publishedAt: true,
          },
        });

        return reply.status(200).send(updated);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to update lesson',
        });
      }
    }
  );

  // POST /lessons/:id/publish - Publish lesson
  fastify.post<{ Params: LessonParams }>(
    '/:id/publish',
    {
      preHandler: validateParams(lessonParamsSchema),
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
        const lesson = await prisma.lesson.findUnique({
          where: { id },
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
            message: 'You do not have permission to publish this lesson',
          });
        }

        const published = await prisma.lesson.update({
          where: { id },
          data: {
            status: 'published',
            publishedAt: new Date(),
          },
          select: {
            id: true,
            title: true,
            description: true,
            thumbnailUrl: true,
            difficulty: true,
            status: true,
            sortOrder: true,
            createdAt: true,
            publishedAt: true,
          },
        });

        return reply.status(200).send(published);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to publish lesson',
        });
      }
    }
  );

  // DELETE /lessons/:id - Delete lesson
  fastify.delete<{ Params: LessonParams }>(
    '/:id',
    {
      preHandler: validateParams(lessonParamsSchema),
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
        const lesson = await prisma.lesson.findUnique({
          where: { id },
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
            message: 'You do not have permission to delete this lesson',
          });
        }

        await prisma.lesson.delete({
          where: { id },
        });

        return reply.status(204).send();
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to delete lesson',
        });
      }
    }
  );
}
