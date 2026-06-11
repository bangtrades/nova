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
    // requests like `GET /api/v1/lessons/3BB36244-7C9B.../cards`.
    // Fastify's router defaults to caseSensitive=true; this disables it
    // so route matching works regardless of UUID case in the path.
    // (Doesn't fix Prisma lookup — that's the preValidation hook below.)
    caseSensitive: false,
  });

  // ---------------------------------------------------------------------
  // S14-VOX-03: Empty-body JSON tolerance
  //
  // Fastify's stock JSON parser rejects a request that declares
  // `Content-Type: application/json` but ships no body
  // (FST_ERR_CTP_EMPTY_JSON_BODY → 400). Several routes are action
  // endpoints with no payload (`POST /lessons/:id/publish`,
  // `/unpublish`, pipeline retriggers), and both iOS URLSession and
  // plain `curl -X POST -H 'content-type: application/json'` hit the
  // rejection — forcing the `-d '{}'` workaround. This replacement
  // parser treats an empty/whitespace body as `undefined` (same as no
  // body at all) and otherwise parses JSON normally, returning the
  // same 400 shape on malformed payloads.
  // ---------------------------------------------------------------------
  fastify.addContentTypeParser(
    'application/json',
    { parseAs: 'string' },
    (_request, body, done) => {
      if (typeof body !== 'string' || body.trim() === '') {
        done(null, undefined);
        return;
      }
      try {
        done(null, JSON.parse(body));
      } catch (err) {
        const error = err as Error & { statusCode?: number };
        error.statusCode = 400;
        done(error, undefined);
      }
    }
  );

  // ---------------------------------------------------------------------
  // S12-12: Global UUID-param case normalization
  //
  // Why this exists: every model in `schema.prisma` declares its `id` as
  // `String @default(uuid())` rather than the native `@db.Uuid`. Postgres
  // stores those values exactly as inserted — Prisma's `uuid()` helper
  // emits lowercase, so every row's id is canonical lowercase. But
  // `prisma.lesson.findUnique({ where: { id: '3BB36244-...' } })` does
  // a literal string match (id is typed String, not Uuid), so an
  // uppercase id from the wire returns null even though the row exists.
  //
  // The systemic fix: at the wire boundary, lowercase any path param
  // whose value matches the canonical UUID shape. One hook, every
  // existing and future route covered. Body params are NOT touched
  // (Zod schemas already normalize bodies via .uuid() validator), and
  // non-UUID path params are left alone (the regex test ensures we
  // only mutate values we're confident are UUIDs).
  //
  // Hook phase: `preValidation` — runs after routing populates
  // request.params but BEFORE per-route validateParams Zod schemas
  // execute. This way the lowercased value is what every downstream
  // step (validation, handler, Prisma query) sees.
  //
  // Reverse-side note: the right long-term fix is migrating every
  // `id String` column to `id String @db.Uuid` (or even native uuid)
  // so Prisma's where-clause does the case-insensitive comparison
  // automatically. Tracked as S13+ schema-cleanup follow-up — too
  // wide a change to land mid-touch-test.
  // ---------------------------------------------------------------------
  const UUID_RE = /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
  fastify.addHook('preValidation', async (request) => {
    const params = request.params as Record<string, unknown> | undefined;
    if (!params) return;
    for (const key of Object.keys(params)) {
      const value = params[key];
      if (typeof value === 'string' && UUID_RE.test(value)) {
        params[key] = value.toLowerCase();
      }
    }
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
