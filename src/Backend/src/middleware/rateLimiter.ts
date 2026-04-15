/**
 * Rate Limiting Middleware (NOVA-305)
 *
 * Token bucket algorithm with:
 * - Per-IP and per-user rate limiting
 * - Configurable limits per route
 * - In-memory store with TTL cleanup
 */

import type { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify';

interface TokenBucket {
  tokens: number;
  lastRefill: number;
  expiresAt: number;
}

interface RateLimiterOptions {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Max requests per window
  keyGenerator?: (request: FastifyRequest) => string;
}

// In-memory store for token buckets
const buckets = new Map<string, TokenBucket>();

// Cleanup interval: clear expired buckets every 5 minutes
const CLEANUP_INTERVAL = 5 * 60 * 1000;

setInterval(() => {
  const now = Date.now();
  const keysToDelete: string[] = [];

  buckets.forEach((bucket, key) => {
    if (bucket.expiresAt < now) {
      keysToDelete.push(key);
    }
  });

  keysToDelete.forEach((key) => {
    buckets.delete(key);
  });

  if (keysToDelete.length > 0) {
    console.log(`Rate limiter: Cleaned up ${keysToDelete.length} expired buckets`);
  }
}, CLEANUP_INTERVAL);

/**
 * Get or create a token bucket for a key
 */
function getOrCreateBucket(key: string, windowMs: number, maxRequests: number): TokenBucket {
  let bucket = buckets.get(key);

  if (!bucket) {
    bucket = {
      tokens: maxRequests,
      lastRefill: Date.now(),
      expiresAt: Date.now() + windowMs * 2, // Keep in memory for 2x window
    };
    buckets.set(key, bucket);
    return bucket;
  }

  // Refill tokens based on time elapsed
  const now = Date.now();
  const timePassed = now - bucket.lastRefill;
  const tokensToAdd = (timePassed / windowMs) * maxRequests;

  bucket.tokens = Math.min(maxRequests, bucket.tokens + tokensToAdd);
  bucket.lastRefill = now;
  bucket.expiresAt = now + windowMs * 2;

  return bucket;
}

/**
 * Default key generator: use client IP
 */
function defaultKeyGenerator(request: FastifyRequest): string {
  return request.ip || 'unknown';
}

/**
 * Create a rate limiter middleware with custom options
 */
export function createRateLimiter(options: RateLimiterOptions) {
  const { windowMs, maxRequests, keyGenerator = defaultKeyGenerator } = options;

  return async (request: FastifyRequest, reply: FastifyReply) => {
    const key = keyGenerator(request);
    const bucket = getOrCreateBucket(key, windowMs, maxRequests);

    if (bucket.tokens >= 1) {
      bucket.tokens -= 1;
      return;
    }

    // Rate limit exceeded
    const retryAfter = Math.ceil((1 - bucket.tokens) * (windowMs / maxRequests) / 1000);

    return reply.status(429).header('Retry-After', retryAfter).send({
      statusCode: 429,
      error: 'Too Many Requests',
      message: `Rate limit exceeded. Retry after ${retryAfter} seconds.`,
      retryAfter,
    });
  };
}

/**
 * Global rate limiter: 100 requests per minute per IP
 */
export const globalRateLimiter = createRateLimiter({
  windowMs: 60 * 1000, // 1 minute
  maxRequests: 100, // 100 requests per minute
});

/**
 * Route-specific rate limiters
 */

// /sparky/chat: 30 req/min per user
export const sparkyRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  maxRequests: 30,
  keyGenerator: (request: FastifyRequest) => {
    // Use userId if authenticated, fallback to IP
    return request.userId || request.ip || 'unknown';
  },
});

// /pipeline: 10 req/min per user
export const pipelineRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  maxRequests: 10,
  keyGenerator: (request: FastifyRequest) => {
    return request.userId || request.ip || 'unknown';
  },
});

// /auth: 20 req/min per IP
export const authRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  maxRequests: 20,
  keyGenerator: (request: FastifyRequest) => {
    return request.ip || 'unknown';
  },
});

/**
 * Register rate limiter as server-level preHandler
 * Should be called from server initialization
 */
export async function registerGlobalRateLimiter(fastify: FastifyInstance): Promise<void> {
  fastify.addHook('preHandler', globalRateLimiter);
  console.log('Global rate limiter registered');
}
