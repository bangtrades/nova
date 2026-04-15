import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams } from '@middleware/validate';

const createPathSchema = z.object({
  title: z.string().min(1).max(255),
  description: z.string().max(1000).optional(),
  color: z.string().regex(/^#[0-9A-F]{6}$/i).optional(),
  icon: z.string().max(10).optional(),
  stage: z.number().int().min(1).max(10).default(1),
  isPremium: z.boolean().default(false),
});

const updatePathSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  description: z.string().max(1000).optional(),
  color: z.string().regex(/^#[0-9A-F]{6}$/i).optional(),
  icon: z.string().max(10).optional(),
  stage: z.number().int().min(1).max(10).optional(),
  isPremium: z.boolean().optional(),
});

const reorderPathsSchema = z.object({
  paths: z.array(
    z.object({
      id: z.string().uuid(),
      sortOrder: z.number().int().min(0),
    })
  ),
});

const pathParamsSchema = z.object({
  id: z.string().uuid(),
});

type CreatePathRequest = z.infer<typeof createPathSchema>;
type UpdatePathRequest = z.infer<typeof updatePathSchema>;
type ReorderPathsRequest = z.infer<typeof reorderPathsSchema>;
type PathParams = z.infer<typeof pathParamsSchema>;

export async function pathRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /paths - List learning paths for current user
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
      const paths = await prisma.learningPath.findMany({
        where: { userId: request.userId },
        select: {
          id: true,
          title: true,
          description: true,
          color: true,
          icon: true,
          sortOrder: true,
          stage: true,
          isPremium: true,
          createdAt: true,
          updatedAt: true,
          lessons: {
            select: {
              id: true,
            },
          },
        },
        orderBy: { sortOrder: 'asc' },
      });

      const pathsWithLessonCount = paths.map((path: typeof paths[number]) => {
        const { lessons, ...rest } = path;
        return {
          ...rest,
          lessonCount: lessons.length,
        };
      });

      return reply.status(200).send({
        data: pathsWithLessonCount,
        total: pathsWithLessonCount.length,
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch learning paths',
      });
    }
  });

  // POST /paths - Create learning path
  fastify.post<{ Body: CreatePathRequest }>(
    '/',
    {
      preHandler: validateBody(createPathSchema),
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

        const { title, description, color, icon, stage, isPremium } = request.body;
        const prisma = getPrismaClient();

        // Get max sortOrder
        const maxPath = await prisma.learningPath.findFirst({
          where: { userId: request.userId },
          orderBy: { sortOrder: 'desc' },
          select: { sortOrder: true },
        });

        const sortOrder = (maxPath?.sortOrder ?? -1) + 1;

        const path = await prisma.learningPath.create({
          data: {
            userId: request.userId,
            title,
            description: description || null,
            color: color || null,
            icon: icon || null,
            sortOrder,
            stage,
            isPremium,
          },
          select: {
            id: true,
            title: true,
            description: true,
            color: true,
            icon: true,
            sortOrder: true,
            stage: true,
            isPremium: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        return reply.status(201).send(path);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to create learning path',
        });
      }
    }
  );

  // GET /paths/:id - Get learning path by id
  fastify.get<{ Params: PathParams }>(
    '/:id',
    {
      preHandler: validateParams(pathParamsSchema),
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

        const path = await prisma.learningPath.findUnique({
          where: { id },
          select: {
            id: true,
            userId: true,
            title: true,
            description: true,
            color: true,
            icon: true,
            sortOrder: true,
            stage: true,
            isPremium: true,
            createdAt: true,
            updatedAt: true,
            lessons: {
              select: {
                id: true,
                title: true,
                status: true,
              },
              orderBy: { sortOrder: 'asc' },
            },
          },
        });

        if (!path) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Learning path not found',
          });
        }

        if (path.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to access this learning path',
          });
        }

        const { userId: _, ...pathData } = path;
        return reply.status(200).send(pathData);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch learning path',
        });
      }
    }
  );

  // PATCH /paths/:id - Update learning path
  fastify.patch<{ Params: PathParams; Body: UpdatePathRequest }>(
    '/:id',
    {
      preHandler: [validateParams(pathParamsSchema), validateBody(updatePathSchema)],
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
        const { title, description, color, icon, stage, isPremium } = request.body;
        const prisma = getPrismaClient();

        // Verify ownership
        const path = await prisma.learningPath.findUnique({
          where: { id },
          select: { userId: true },
        });

        if (!path) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Learning path not found',
          });
        }

        if (path.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to modify this learning path',
          });
        }

        const updated = await prisma.learningPath.update({
          where: { id },
          data: {
            ...(title && { title }),
            ...(description && { description }),
            ...(color && { color }),
            ...(icon && { icon }),
            ...(stage && { stage }),
            ...(isPremium !== undefined && { isPremium }),
          },
          select: {
            id: true,
            title: true,
            description: true,
            color: true,
            icon: true,
            sortOrder: true,
            stage: true,
            isPremium: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        return reply.status(200).send(updated);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to update learning path',
        });
      }
    }
  );

  // POST /paths/reorder - Reorder learning paths
  fastify.post<{ Body: ReorderPathsRequest }>(
    '/reorder',
    {
      preHandler: validateBody(reorderPathsSchema),
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

        const { paths } = request.body;
        const prisma = getPrismaClient();

        // Verify all paths belong to user
        const userPaths = await prisma.learningPath.findMany({
          where: {
            id: { in: paths.map((p) => p.id) },
          },
          select: { userId: true },
        });

        for (const userPath of userPaths) {
          if (userPath.userId !== request.userId) {
            return reply.status(403).send({
              statusCode: 403,
              error: 'Forbidden',
              message: 'You do not have permission to modify these paths',
            });
          }
        }

        // Update all paths
        await Promise.all(
          paths.map((path) =>
            prisma.learningPath.update({
              where: { id: path.id },
              data: { sortOrder: path.sortOrder },
            })
          )
        );

        return reply.status(200).send({
          message: 'Learning paths reordered successfully',
          count: paths.length,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to reorder learning paths',
        });
      }
    }
  );

  // DELETE /paths/:id - Delete learning path
  fastify.delete<{ Params: PathParams }>(
    '/:id',
    {
      preHandler: validateParams(pathParamsSchema),
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
        const path = await prisma.learningPath.findUnique({
          where: { id },
          select: { userId: true },
        });

        if (!path) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Learning path not found',
          });
        }

        if (path.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to delete this learning path',
          });
        }

        await prisma.learningPath.delete({
          where: { id },
        });

        return reply.status(204).send();
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to delete learning path',
        });
      }
    }
  );
}
