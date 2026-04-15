import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer } from './setup';

describe('Health Routes', () => {
  let fastify: FastifyInstance;

  beforeAll(async () => {
    fastify = await createTestServer();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('GET /api/v1/health should return 200 or 503 with status field', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/health',
    });

    // Health returns 200 if DB is connected, 503 if not
    expect([200, 503]).toContain(response.statusCode);

    const body = JSON.parse(response.body);
    expect(body).toHaveProperty('status');
    expect(['ok', 'error']).toContain(body.status);
    expect(body).toHaveProperty('version');
    expect(body.version).toBe('0.1.0');
    expect(body).toHaveProperty('timestamp');
    expect(body).toHaveProperty('database');
  });

  it('GET /api/v1/unknown-route should return 401 or 404', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/unknown-route',
    });

    // May return 401 (auth middleware) or 404 (no route match)
    expect([401, 404]).toContain(response.statusCode);
  });

  it('should not require authentication for health check', async () => {
    const response = await fastify.inject({
      method: 'GET',
      url: '/api/v1/health',
    });

    // Should not return 401 — health is a public route
    expect(response.statusCode).not.toBe(401);
  });
});
