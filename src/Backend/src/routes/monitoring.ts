/**
 * System Monitoring Routes (NOVA-301)
 *
 * GET /api/v1/monitoring/health - Extended health check
 * GET /api/v1/monitoring/stats - System statistics (auth required)
 */

import type { FastifyInstance, FastifyRequest } from 'fastify';

// In-memory metrics counters
interface Metrics {
  requestCount: number;
  errorCount: number;
  startedAt: number;
  activeUsers: Set<string>;
  lastReset: number;
}

const metrics: Metrics = {
  requestCount: 0,
  errorCount: 0,
  startedAt: Date.now(),
  activeUsers: new Set(),
  lastReset: Date.now(),
};

/**
 * Increment request counter
 */
export function incrementRequestCount(): void {
  metrics.requestCount += 1;
}

/**
 * Increment error counter
 */
export function incrementErrorCount(): void {
  metrics.errorCount += 1;
}

/**
 * Track active user
 */
export function trackActiveUser(userId: string): void {
  metrics.activeUsers.add(userId);
}

/**
 * Get metrics snapshot
 */
export function getMetrics(): Metrics {
  return {
    ...metrics,
    activeUsers: new Set(metrics.activeUsers), // Return a copy
  };
}

/**
 * Reset metrics (useful for testing)
 */
export function resetMetrics(): void {
  metrics.requestCount = 0;
  metrics.errorCount = 0;
  metrics.activeUsers.clear();
  metrics.lastReset = Date.now();
}

export default async function monitoringRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /monitoring/health - Extended health check (no auth)
  fastify.get('/monitoring/health', async (request, reply) => {
    try {
      const prisma = (fastify as any).prisma;

      // Test database connection
      await (prisma as any).$queryRaw`SELECT 1`;

      // Get memory usage
      const memoryUsage = process.memoryUsage();
      const uptime = process.uptime();

      const snapshot = getMetrics();

      return reply.status(200).send({
        status: 'ok',
        version: '0.1.0',
        timestamp: new Date().toISOString(),
        database: 'connected',
        uptime,
        memory: {
          heapUsed: Math.round(memoryUsage.heapUsed / 1024 / 1024), // MB
          heapTotal: Math.round(memoryUsage.heapTotal / 1024 / 1024),
          rss: Math.round(memoryUsage.rss / 1024 / 1024),
          external: Math.round(memoryUsage.external / 1024 / 1024),
        },
        requestCount: snapshot.requestCount,
        errorCount: snapshot.errorCount,
        activeUsers: snapshot.activeUsers.size,
      });
    } catch (error) {
      fastify.log.error(`Health check error: ${error}`);
      return reply.status(503).send({
        status: 'error',
        version: '0.1.0',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        message: 'Database connection failed',
      });
    }
  });

  // GET /monitoring/stats - Detailed statistics (auth required)
  fastify.get('/monitoring/stats', async (request: FastifyRequest, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Authentication required',
        });
      }

      const prisma = (fastify as any).prisma;

      // Check if user is admin (hardcoded for now)
      const ADMIN_USERS = ['admin@nova-app.com'];
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

      // Count active users in last 24 hours
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
      const activeUsers24h = await prisma.learningSession.findMany({
        where: {
          startedAt: { gte: oneDayAgo },
        },
        distinct: ['childId'],
        select: { childId: true },
      });

      // Count lessons created in last 24 hours
      const lessonsCreated24h = await prisma.lesson.findMany({
        where: {
          publishedAt: { gte: oneDayAgo },
        },
        select: { id: true },
      });

      // Count pipeline runs in last 24 hours (if pipeline jobs table exists)
      let pipelineRuns24h = 0;
      try {
        const runs = await (prisma as any).$queryRaw`
          SELECT COUNT(*) as count FROM "PipelineJob"
          WHERE "createdAt" >= ${oneDayAgo}
        `;
        if (Array.isArray(runs) && runs.length > 0) {
          pipelineRuns24h = Number((runs[0] as any).count) || 0;
        }
      } catch {
        // Table may not exist, that's okay
        pipelineRuns24h = 0;
      }

      const snapshot = getMetrics();
      const errorRate =
        snapshot.requestCount > 0
          ? ((snapshot.errorCount / snapshot.requestCount) * 100).toFixed(2)
          : '0.00';

      return reply.status(200).send({
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        requests: {
          total: snapshot.requestCount,
          errors: snapshot.errorCount,
          errorRate: `${errorRate}%`,
        },
        users: {
          active24h: activeUsers24h.length,
          currentlyActive: snapshot.activeUsers.size,
        },
        content: {
          lessonsCreated24h: lessonsCreated24h.length,
          pipelineRuns24h,
        },
      });
    } catch (error) {
      fastify.log.error(`Stats error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch statistics',
      });
    }
  });
}
