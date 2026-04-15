import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import jwt from 'jsonwebtoken';
import { getPrismaClient } from '@db/client';
import { getConfig } from '@config';
import {
  generateTokenPair,
  verifyRefreshToken,
} from '@middleware/auth';
import { validateBody } from '@middleware/validate';
import { tokenBlacklistService } from '@services/tokenBlacklist';
import type { TokenPayload } from '@types';

// Schema definitions
const appleSignInSchema = z.object({
  identityToken: z.string().min(1, 'Identity token is required'),
  appleId: z.string().min(1, 'Apple ID is required'),
  displayName: z.string().optional(),
  email: z.string().email().optional(),
});

const refreshTokenSchema = z.object({
  refreshToken: z.string().min(1, 'Refresh token is required'),
});

const revokeTokenSchema = z.object({
  token: z.string().min(1, 'Token is required'),
});

const authResponseSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  user: z.object({
    id: z.string(),
    displayName: z.string(),
    email: z.string().email().optional(),
  }),
});

type AppleSignInRequest = z.infer<typeof appleSignInSchema>;
type RefreshTokenRequest = z.infer<typeof refreshTokenSchema>;
type RevokeTokenRequest = z.infer<typeof revokeTokenSchema>;
type AuthResponse = z.infer<typeof authResponseSchema>;

export async function authRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /auth/apple - Apple Sign In
  fastify.post<{ Body: AppleSignInRequest }>(
    '/apple',
    {
      preHandler: validateBody(appleSignInSchema),
    },
    async (request, reply) => {
      try {
        const { identityToken, appleId, displayName, email } = request.body;
        const prisma = getPrismaClient();

        // In production, verify identityToken with Apple's servers
        // For now, we'll just use appleId as is
        if (!identityToken) {
          return reply.status(400).send({
            statusCode: 400,
            error: 'Invalid Request',
            message: 'Invalid Apple identity token',
          });
        }

        // Find or create user
        let user = await prisma.user.findUnique({
          where: { appleId },
        });

        if (!user) {
          user = await prisma.user.create({
            data: {
              appleId,
              displayName: displayName || 'Nova Explorer',
              email: email || undefined,
            },
          });

          // Create default subscription
          await prisma.subscription.create({
            data: {
              userId: user.id,
              plan: 'free',
              status: 'active',
            },
          });
        }

        const { accessToken, refreshToken } = generateTokenPair(user.id);

        const response: AuthResponse = {
          accessToken,
          refreshToken,
          user: {
            id: user.id,
            displayName: user.displayName,
            email: user.email || undefined,
          },
        };

        return reply.status(200).send(response);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to sign in with Apple',
        });
      }
    }
  );

  // POST /auth/refresh - Refresh JWT token
  fastify.post<{ Body: RefreshTokenRequest }>(
    '/refresh',
    {
      preHandler: validateBody(refreshTokenSchema),
    },
    async (request, reply) => {
      try {
        const { refreshToken } = request.body;

        const payload = verifyRefreshToken(refreshToken);
        if (!payload) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Invalid or expired refresh token',
          });
        }

        const prisma = getPrismaClient();
        const user = await prisma.user.findUnique({
          where: { id: payload.userId },
        });

        if (!user) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'User not found',
          });
        }

        const { accessToken: newAccessToken, refreshToken: newRefreshToken } =
          generateTokenPair(user.id);

        const response: AuthResponse = {
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          user: {
            id: user.id,
            displayName: user.displayName,
            email: user.email || undefined,
          },
        };

        return reply.status(200).send(response);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to refresh token',
        });
      }
    }
  );

  // POST /auth/logout - Logout (invalidate current token)
  fastify.post('/logout', async (request, reply) => {
    try {
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

        // Create unique token identifier
        const tokenId = (payload as any).jti || `${payload.userId}-${payload.iat}`;

        // Add to blacklist with expiration time from token
        const expiresAt = new Date(payload.exp * 1000);
        tokenBlacklistService.blacklistToken(tokenId, expiresAt);

        return reply.status(200).send({
          message: 'Logged out successfully',
        });
      } catch (error) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Invalid or expired token',
        });
      }
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to logout',
      });
    }
  });

  // POST /auth/revoke - Revoke a specific token
  fastify.post<{ Body: RevokeTokenRequest }>(
    '/revoke',
    {
      preHandler: validateBody(revokeTokenSchema),
    },
    async (request, reply) => {
      try {
        const { token } = request.body;
        const config = getConfig();

        try {
          const payload = jwt.verify(token, config.JWT_SECRET) as TokenPayload;

          // Create unique token identifier
          const tokenId = (payload as any).jti || `${payload.userId}-${payload.iat}`;

          // Add to blacklist with expiration time from token
          const expiresAt = new Date(payload.exp * 1000);
          tokenBlacklistService.blacklistToken(tokenId, expiresAt);

          return reply.status(200).send({
            message: 'Token revoked successfully',
          });
        } catch (error) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Invalid or expired token',
          });
        }
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to revoke token',
        });
      }
    }
  );

  // DELETE /auth/account - Delete user account (COPPA compliance)
  fastify.delete('/account', async (request, reply) => {
    try {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const prisma = getPrismaClient();

      // Cascade delete will handle all related data
      await prisma.user.delete({
        where: { id: request.userId },
      });

      return reply.status(200).send({
        message: 'Account deleted successfully',
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to delete account',
      });
    }
  });
}
