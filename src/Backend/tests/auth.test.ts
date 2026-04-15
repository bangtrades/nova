import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer, generateTestToken, verifyTestToken, TEST_USER_ID } from './setup';

describe('Auth Routes', () => {
  let fastify: FastifyInstance;

  beforeAll(async () => {
    fastify = await createTestServer();
  });

  afterAll(async () => {
    await fastify.close();
  });

  describe('Authentication Middleware', () => {
    it('should reject requests without authorization header', async () => {
      const response = await fastify.inject({
        method: 'GET',
        url: '/api/v1/users/me',
      });

      expect(response.statusCode).toBe(401);

      const body = JSON.parse(response.body);
      expect(body.error).toBe('Unauthorized');
    });

    it('should reject requests with invalid token', async () => {
      const response = await fastify.inject({
        method: 'GET',
        url: '/api/v1/users/me',
        headers: {
          authorization: 'Bearer invalid-token-here',
        },
      });

      expect(response.statusCode).toBe(401);

      const body = JSON.parse(response.body);
      expect(body.error).toBe('Unauthorized');
      expect(body.message).toContain('Invalid or expired token');
    });

    it('should accept valid JWT token', async () => {
      const token = generateTestToken(TEST_USER_ID);

      // Verify token is valid
      const decoded = verifyTestToken(token);
      expect(decoded).not.toBeNull();
      expect(decoded?.userId).toBe(TEST_USER_ID);
    });

    it('should allow requests with valid bearer token past auth middleware', async () => {
      const token = generateTestToken(TEST_USER_ID);

      const response = await fastify.inject({
        method: 'GET',
        url: '/api/v1/users/me',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      // Should not return 401 — token is valid, auth middleware should pass.
      // May return 404 (user not in DB) or 500 (DB unreachable) — both are fine,
      // they prove the request got past the auth layer.
      expect(response.statusCode).not.toBe(401);
    });
  });

  describe('Auth Endpoints', () => {
    it('POST /api/v1/auth/logout should return 200', async () => {
      const token = generateTestToken(TEST_USER_ID);

      const response = await fastify.inject({
        method: 'POST',
        url: '/api/v1/auth/logout',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      expect(response.statusCode).toBe(200);

      const body = JSON.parse(response.body);
      expect(body.message).toBe('Logged out successfully');
    });

    it('should reject requests with blacklisted token after logout', async () => {
      const token = generateTestToken(TEST_USER_ID);

      // First, logout to blacklist the token
      const logoutResponse = await fastify.inject({
        method: 'POST',
        url: '/api/v1/auth/logout',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      expect(logoutResponse.statusCode).toBe(200);

      // Now try to use the same token to access a protected route
      const protectedResponse = await fastify.inject({
        method: 'GET',
        url: '/api/v1/users/me',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      // Should be rejected with 401 because token is blacklisted
      expect(protectedResponse.statusCode).toBe(401);

      const body = JSON.parse(protectedResponse.body);
      expect(body.error).toBe('Unauthorized');
      expect(body.message).toContain('revoked');
    });

    it('POST /api/v1/auth/revoke should revoke a token', async () => {
      const token = generateTestToken(TEST_USER_ID);

      // Revoke the token
      const revokeResponse = await fastify.inject({
        method: 'POST',
        url: '/api/v1/auth/revoke',
        headers: {
          'Content-Type': 'application/json',
        },
        payload: {
          token,
        },
      });

      expect(revokeResponse.statusCode).toBe(200);

      const body = JSON.parse(revokeResponse.body);
      expect(body.message).toBe('Token revoked successfully');

      // Now try to use the same token to access a protected route
      const protectedResponse = await fastify.inject({
        method: 'GET',
        url: '/api/v1/users/me',
        headers: {
          authorization: `Bearer ${token}`,
        },
      });

      // Should be rejected with 401 because token is revoked
      expect(protectedResponse.statusCode).toBe(401);

      const responseBody = JSON.parse(protectedResponse.body);
      expect(responseBody.error).toBe('Unauthorized');
      expect(responseBody.message).toContain('revoked');
    });
  });
});
