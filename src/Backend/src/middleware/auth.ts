import type { FastifyRequest, FastifyReply } from 'fastify';
import jwt from 'jsonwebtoken';
import { getConfig } from '@config';
import type { TokenPayload } from '../types/index';
import { tokenBlacklistService } from '@services/tokenBlacklist';

const PUBLIC_ROUTES = [
  '/api/v1/health',
  '/api/v1/auth/apple',
  '/api/v1/auth/refresh',
  '/api/v1/auth/logout',
  '/api/v1/auth/revoke',
];

export async function authMiddleware(
  request: FastifyRequest,
  reply: FastifyReply
): Promise<void> {
  // Strip query string for route matching
  const urlPath = request.url.split('?')[0];

  // Skip auth for public routes
  if (PUBLIC_ROUTES.includes(urlPath)) {
    return;
  }

  const config = getConfig();
  const authHeader = request.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return reply.status(401).send({
      statusCode: 401,
      error: 'Unauthorized',
      message: 'Missing or invalid authorization header',
    });
  }

  const token = authHeader.slice(7);

  try {
    const payload = jwt.verify(token, config.JWT_SECRET) as TokenPayload;

    // Check if token is blacklisted
    // Use jti if available, otherwise use userId + iat combo as unique identifier
    const tokenId = (payload as any).jti || `${payload.userId}-${payload.iat}`;
    if (tokenBlacklistService.isBlacklisted(tokenId)) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Token has been revoked',
      });
    }

    request.userId = payload.userId;
    request.user = { id: payload.userId };
  } catch (error) {
    return reply.status(401).send({
      statusCode: 401,
      error: 'Unauthorized',
      message: 'Invalid or expired token',
    });
  }
}

export function generateAccessToken(userId: string): string {
  const config = getConfig();
  return jwt.sign({ userId }, config.JWT_SECRET, {
    expiresIn: '1h',
  });
}

export function generateRefreshToken(userId: string): string {
  const config = getConfig();
  return jwt.sign({ userId }, config.JWT_REFRESH_SECRET, {
    expiresIn: '7d',
  });
}

export function generateTokenPair(userId: string): { accessToken: string; refreshToken: string } {
  return {
    accessToken: generateAccessToken(userId),
    refreshToken: generateRefreshToken(userId),
  };
}

export function verifyRefreshToken(token: string): TokenPayload | null {
  const config = getConfig();
  try {
    const payload = jwt.verify(token, config.JWT_REFRESH_SECRET) as TokenPayload;
    return payload;
  } catch {
    return null;
  }
}
