import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams } from '@middleware/validate';

/**
 * S10-05: validate an IANA timezone via Intl itself. Anything Intl can't
 * parse is not a real zone — no hand-rolled allowlist that falls behind tzdata.
 */
const ianaTimezoneSchema = z
  .string()
  .min(1)
  .max(64)
  .refine(
    (tz) => {
      try {
        // eslint-disable-next-line no-new
        new Intl.DateTimeFormat('en-US', { timeZone: tz });
        return true;
      } catch {
        return false;
      }
    },
    { message: 'Invalid IANA timezone (e.g. use "America/New_York")' }
  );

const createChildSchema = z.object({
  name: z.string().min(1).max(255),
  birthDate: z.string().datetime(),
  avatarUrl: z.string().url().optional(),
  ianaTimezone: ianaTimezoneSchema.optional(),
});

const updateChildSchema = z.object({
  name: z.string().min(1).max(255).optional(),
  birthDate: z.string().datetime().optional(),
  avatarUrl: z.string().url().optional(),
  currentStage: z.number().int().min(1).max(10).optional(),
  ianaTimezone: ianaTimezoneSchema.optional(),
});

const childParamsSchema = z.object({
  id: z.string().uuid(),
});

type CreateChildRequest = z.infer<typeof createChildSchema>;
type UpdateChildRequest = z.infer<typeof updateChildSchema>;
type ChildParams = z.infer<typeof childParamsSchema>;

export async function childrenRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /children - List children for current user
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
      const children = await (prisma as any).childProfile.findMany({
        where: { userId: request.userId },
        select: {
          id: true,
          name: true,
          birthDate: true,
          avatarUrl: true,
          currentStage: true,
          ianaTimezone: true,
          createdAt: true,
          updatedAt: true,
        },
        orderBy: { createdAt: 'asc' },
      });

      return reply.status(200).send({
        data: children,
        total: children.length,
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch children',
      });
    }
  });

  // POST /children - Create child profile
  fastify.post<{ Body: CreateChildRequest }>(
    '/',
    {
      preHandler: validateBody(createChildSchema),
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

        const { name, birthDate, avatarUrl, ianaTimezone } = request.body;
        const prisma = getPrismaClient();

        const child = await (prisma as any).childProfile.create({
          data: {
            userId: request.userId,
            name,
            birthDate: new Date(birthDate),
            avatarUrl,
            currentStage: 1,
            ...(ianaTimezone ? { ianaTimezone } : {}),
          },
          select: {
            id: true,
            name: true,
            birthDate: true,
            avatarUrl: true,
            currentStage: true,
            ianaTimezone: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        return reply.status(201).send(child);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to create child profile',
        });
      }
    }
  );

  // GET /children/:id - Get child by id
  fastify.get<{ Params: ChildParams }>(
    '/:id',
    {
      preHandler: validateParams(childParamsSchema),
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

        const child = await (prisma as any).childProfile.findUnique({
          where: { id },
          select: {
            id: true,
            userId: true,
            name: true,
            birthDate: true,
            avatarUrl: true,
            currentStage: true,
            ianaTimezone: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        if (!child) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Child profile not found',
          });
        }

        // Verify ownership
        if (child.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to access this child profile',
          });
        }

        // Remove userId from response
        const { userId: _, ...childData } = child;
        return reply.status(200).send(childData);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch child profile',
        });
      }
    }
  );

  // PATCH /children/:id - Update child
  fastify.patch<{ Params: ChildParams; Body: UpdateChildRequest }>(
    '/:id',
    {
      preHandler: [validateParams(childParamsSchema), validateBody(updateChildSchema)],
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
        const { name, birthDate, avatarUrl, currentStage, ianaTimezone } = request.body;
        const prisma = getPrismaClient();

        // Verify ownership
        const child = await prisma.childProfile.findUnique({
          where: { id },
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
            message: 'You do not have permission to modify this child profile',
          });
        }

        const updated = await (prisma as any).childProfile.update({
          where: { id },
          data: {
            ...(name && { name }),
            ...(birthDate && { birthDate: new Date(birthDate) }),
            ...(avatarUrl && { avatarUrl }),
            ...(currentStage && { currentStage }),
            ...(ianaTimezone && { ianaTimezone }),
          },
          select: {
            id: true,
            name: true,
            birthDate: true,
            avatarUrl: true,
            currentStage: true,
            ianaTimezone: true,
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
          message: 'Failed to update child profile',
        });
      }
    }
  );

  // DELETE /children/:id - Delete child
  fastify.delete<{ Params: ChildParams }>(
    '/:id',
    {
      preHandler: validateParams(childParamsSchema),
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
        const child = await prisma.childProfile.findUnique({
          where: { id },
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
            message: 'You do not have permission to delete this child profile',
          });
        }

        await prisma.childProfile.delete({
          where: { id },
        });

        return reply.status(204).send();
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to delete child profile',
        });
      }
    }
  );
}
