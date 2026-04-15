import type { FastifyInstance } from 'fastify';
import jwt from 'jsonwebtoken';
import { buildServer } from '../src/server';
import type { TokenPayload } from '../src/types';

export async function createTestServer(): Promise<FastifyInstance> {
  const fastify = await buildServer();
  return fastify;
}

// Must match the JWT_SECRET / JWT_REFRESH_SECRET in .env
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-key-change-in-production-to-something-secure-and-long';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret-key-change-in-production-to-something-secure';

export function generateTestToken(userId: string, options?: { expiresIn?: string }): string {
  return jwt.sign(
    { userId },
    JWT_SECRET,
    options || { expiresIn: '1h' }
  );
}

export function generateTestRefreshToken(userId: string): string {
  return jwt.sign(
    { userId },
    JWT_REFRESH_SECRET,
    { expiresIn: '7d' }
  );
}

export function verifyTestToken(token: string): TokenPayload | null {
  try {
    const payload = jwt.verify(token, JWT_SECRET) as TokenPayload;
    return payload;
  } catch {
    return null;
  }
}

export const TEST_USER_ID = 'test-user-uuid-123';
export const TEST_CHILD_ID = 'test-child-uuid-456';
