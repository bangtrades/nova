import path from 'path';
import Fastify from 'fastify';
import fastifyHelmet from '@fastify/helmet';
import fastifyCors from '@fastify/cors';
import fastifyRateLimit from '@fastify/rate-limit';
import fastifySensible from '@fastify/sensible';
import fastifyStatic from '@fastify/static';
import { getConfig } from '@config';
import { getPrismaClient, disconnectPrisma } from '@db/client';
import { authMiddleware } from '@middleware/auth';
import { registerRoutes } from '@routes/index';
import { initializeFlags } from '@services/featureFlags';
import { registerGlobalRateLimiter } from '@middleware/rateLimiter';
import { getSkillRegistry } from '@services/skills/registry';

async function buildServer(): Promise<ReturnType<typeof Fastify>> {
  const config = getConfig();

  const fastify = Fastify({
    logger: {
      level: config.LOG_LEVEL,
      transport: {
        target: 'pino-pretty',
        options: {
          colorize: true,
          singleLine: false,
        },
      },
    },
    // S12-12: case-insensitive route matching. Swift's `UUID.uuidString`
    // returns RFC 4122 form which is UPPERCASE by default, so iOS sends
    // requests like `GET /api/v1/lessons/3BB36244-7C9B.../cards`. Postgres
    // stores UUIDs lowercase and Prisma's where-clause is case-insensitive
    // for UUIDs, but Fastify's router (find-my-way) defaults to
    // `caseSensitive: true`. With case-sensitive routing the uppercase
    // path no longer matches the route registered as `/lessons/:id/cards`
    // — manifests as a 404 even though the route exists and curl works
    // when the param is lowercase. Disabling case sensitivity for the
    // whole server is a no-cost win in dev: every literal segment
    // (`lessons`, `cards`, `paths`, etc.) is lowercase so there's no
    // pre-existing route that depended on case to disambiguate.
    caseSensitive: false,
  });

  // Register plugins
  await fastify.register(fastifyHelmet, {
    contentSecurityPolicy: false, // Will be configured later if needed
  });

  await fastify.register(fastifyCors, {
    origin: (origin, cb) => {
      // In development, allow everything including file:// (null origin)
      if (config.NODE_ENV === 'development') {
        cb(null, true);
        return;
      }
      // In production, restrict to known origins
      const allowed = ['https://nova-app.com', 'https://companion.nova-app.com'];
      cb(null, allowed.includes(origin ?? ''));
    },
    credentials: true,
  });

  await fastify.register(fastifyRateLimit, {
    max: config.NODE_ENV === 'development' ? 1000 : 100,
    timeWindow: '15 minutes',
  });

  await fastify.register(fastifySensible);

  // Register global rate limiter
  await registerGlobalRateLimiter(fastify);

  // Register auth middleware
  fastify.addHook('preHandler', authMiddleware);

  // Register error handler
  fastify.setErrorHandler((error, request, reply) => {
    fastify.log.error(error);

    // Prisma errors
    if (error.name === 'PrismaClientKnownRequestError') {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message: 'Database error occurred',
      });
    }

    // Validation errors are handled by middleware
    if (error.statusCode === 400) {
      return reply.status(400).send({
        statusCode: 400,
        error: 'Bad Request',
        message: error.message,
      });
    }

    // Default error response
    const statusCode = error.statusCode || 500;
    return reply.status(statusCode).send({
      statusCode,
      error: error.name || 'Error',
      message: error.message || 'An unexpected error occurred',
    });
  });

  // In development, serve dev tools from /public
  if (config.NODE_ENV === 'development') {
    await fastify.register(fastifyStatic, {
      root: path.join(__dirname, '..', 'public'),
      prefix: '/dev/',
      decorateReply: false,
    });
  }

  // Register all routes
  await registerRoutes(fastify);

  // Graceful shutdown
  const signals = ['SIGINT', 'SIGTERM'] as const;
  for (const signal of signals) {
    process.on(signal, async () => {
      fastify.log.info(`Received ${signal}, shutting down gracefully`);
      await fastify.close();
      await disconnectPrisma();
      process.exit(0);
    });
  }

  return fastify;
}

async function start(): Promise<void> {
  try {
    const config = getConfig();
    const fastify = await buildServer();

    // Initialize Prisma client
    getPrismaClient();

    // Initialize feature flags
    await initializeFlags();

    // Eager-load the skill registry. A typo in any manifest fails here,
    // at boot, rather than at first invocation. See
    // docs/design-spikes/S10-06-07-skill-loader.md decision #4.
    await getSkillRegistry().load();

    // Start server
    await fastify.listen({ host: config.HOST, port: config.PORT });

    fastify.log.info(`Server is running at http://${config.HOST}:${config.PORT}`);
    fastify.log.info(`Environment: ${config.NODE_ENV}`);
    fastify.log.info('Nova Backend Server v0.1.0');
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Only start if this is the main module
if (require.main === module) {
  start().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}

export { buildServer };
