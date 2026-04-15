import type { FastifyInstance } from 'fastify';
import { getPrismaClient } from '@db/client';

export async function healthRoutes(fastify: FastifyInstance): Promise<void> {
  fastify.get('/health', async (_request, reply) => {
    try {
      const prisma = getPrismaClient();
      // Test database connection
      await prisma.$queryRaw`SELECT 1`;

      return reply.status(200).send({
        status: 'ok',
        version: '0.1.0',
        timestamp: new Date().toISOString(),
        database: 'connected',
      });
    } catch (error) {
      return reply.status(503).send({
        status: 'error',
        version: '0.1.0',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        message: 'Database connection failed',
      });
    }
  });
}
