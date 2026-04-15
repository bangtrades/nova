import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody } from '@middleware/validate';

const updateUserSchema = z.object({
  displayName: z.string().min(1).max(255).optional(),
  email: z.string().email().optional(),
});

type UpdateUserRequest = z.infer<typeof updateUserSchema>;

export async function userRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /users/me - Get current user profile
  fastify.get('/me', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const prisma = getPrismaClient();
      const user = await prisma.user.findUnique({
        where: { id: request.userId },
        select: {
          id: true,
          displayName: true,
          email: true,
          appleId: true,
          createdAt: true,
          updatedAt: true,
        },
      });

      if (!user) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: 'User not found',
        });
      }

      return reply.status(200).send(user);
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch user profile',
      });
    }
  });

  // PATCH /users/me - Update user profile
  fastify.patch<{ Body: UpdateUserRequest }>(
    '/me',
    {
      preHandler: validateBody(updateUserSchema),
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

        const { displayName, email } = request.body;
        const prisma = getPrismaClient();

        // Check if email already exists
        if (email) {
          const existingUser = await prisma.user.findUnique({
            where: { email },
          });
          if (existingUser && existingUser.id !== request.userId) {
            return reply.status(409).send({
              statusCode: 409,
              error: 'Conflict',
              message: 'Email already in use',
            });
          }
        }

        const user = await prisma.user.update({
          where: { id: request.userId },
          data: {
            ...(displayName && { displayName }),
            ...(email && { email }),
          },
          select: {
            id: true,
            displayName: true,
            email: true,
            appleId: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        return reply.status(200).send(user);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to update user profile',
        });
      }
    }
  );
}
