import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { getConfig } from '@config';
import { validateBody, validateParams, validateQuery } from '@middleware/validate';
import {
  generateCodeVerifier,
  getAuthorizationUrl,
  exchangeCodeForTokens,
  refreshAccessToken,
  revokeToken,
} from '@services/oauth/openaiOAuth';
import { encryptToken, decryptToken } from '@services/oauth/tokenEncryption';
import { oauthStateManager } from '@services/oauth/oauthStateManager';
import { randomBytes } from 'crypto';

const oauthAuthorizeSchema = z.object({
  provider: z.enum(['openai']),
});

const oauthCallbackSchema = z.object({
  code: z.string(),
  state: z.string(),
  error: z.string().optional(),
  error_description: z.string().optional(),
});

const oauthDisconnectSchema = z.object({
  provider: z.enum(['openai']),
});

const oauthStatusSchema = z.object({
  provider: z.enum(['openai']),
});

const oauthRefreshSchema = z.object({
  provider: z.enum(['openai']),
});

type OAuthAuthorizeRequest = z.infer<typeof oauthAuthorizeSchema>;
type OAuthCallbackRequest = z.infer<typeof oauthCallbackSchema>;
type OAuthDisconnectRequest = z.infer<typeof oauthDisconnectSchema>;
type OAuthStatusRequest = z.infer<typeof oauthStatusSchema>;
type OAuthRefreshRequest = z.infer<typeof oauthRefreshSchema>;

export async function oauthRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /oauth/openai/authorize - Initiate OpenAI OAuth flow
  fastify.get<{ Querystring: OAuthAuthorizeRequest }>(
    '/openai/authorize',
    {
      preHandler: validateQuery(oauthAuthorizeSchema),
    },
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        // Generate PKCE code verifier and state
        const codeVerifier = generateCodeVerifier();
        const state = randomBytes(32).toString('hex');

        // Store state and verifier temporarily
        oauthStateManager.storeState(state, codeVerifier);

        // Generate authorization URL
        const authorizationUrl = getAuthorizationUrl(state, codeVerifier);

        return reply.status(200).send({
          authorizationUrl,
          message: 'Redirect to authorizationUrl to continue OAuth flow',
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to initiate OAuth flow',
        });
      }
    }
  );

  // GET /oauth/openai/callback - OAuth callback handler
  fastify.get<{ Querystring: OAuthCallbackRequest }>(
    '/openai/callback',
    {
      preHandler: validateQuery(oauthCallbackSchema),
    },
    async (request, reply) => {
      try {
        const { code, state, error, error_description } = request.query;

        // Handle OAuth errors from OpenAI
        if (error) {
          fastify.log.warn(`OAuth error from OpenAI: ${error} - ${error_description}`);
          return reply.status(400).send({
            statusCode: 400,
            error: 'OAuth Error',
            message: error_description || error,
          });
        }

        if (!code || !state) {
          return reply.status(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: 'Missing code or state parameter',
          });
        }

        // Retrieve and verify state
        const codeVerifier = oauthStateManager.consumeState(state);
        if (!codeVerifier) {
          return reply.status(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: 'Invalid or expired state parameter',
          });
        }

        // Exchange code for tokens
        const tokens = await exchangeCodeForTokens(code, codeVerifier);

        // Get user ID from header or JWT
        const userId = request.userId;
        if (!userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'User information not found',
          });
        }

        // Encrypt tokens before storage
        const config = getConfig();
        const encryptedAccessToken = encryptToken(tokens.accessToken, config.ENCRYPTION_KEY);
        const encryptedRefreshToken = tokens.refreshToken
          ? encryptToken(tokens.refreshToken, config.ENCRYPTION_KEY)
          : null;

        // Calculate token expiry
        const tokenExpiresAt = new Date(Date.now() + tokens.expiresIn * 1000);

        // Store or update LLM provider record
        const prisma = getPrismaClient();
        const provider = await prisma.lLMProvider.upsert({
          where: {
            userId_provider: {
              userId,
              provider: 'openai',
            },
          },
          create: {
            userId,
            provider: 'openai',
            accessTokenEncrypted: Buffer.from(encryptedAccessToken),
            refreshTokenEncrypted: encryptedRefreshToken
              ? Buffer.from(encryptedRefreshToken)
              : null,
            tokenExpiresAt,
            status: 'active',
          },
          update: {
            accessTokenEncrypted: Buffer.from(encryptedAccessToken),
            refreshTokenEncrypted: encryptedRefreshToken
              ? Buffer.from(encryptedRefreshToken)
              : null,
            tokenExpiresAt,
            status: 'active',
            updatedAt: new Date(),
          },
          select: {
            id: true,
            provider: true,
            status: true,
            connectedAt: true,
            tokenExpiresAt: true,
          },
        });

        return reply.status(200).send({
          message: 'OpenAI OAuth connected successfully',
          provider,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to process OAuth callback',
        });
      }
    }
  );

  // POST /oauth/openai/disconnect - Revoke and disconnect OpenAI OAuth
  fastify.post<{ Body: OAuthDisconnectRequest }>(
    '/openai/disconnect',
    {
      preHandler: validateBody(oauthDisconnectSchema),
    },
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const prisma = getPrismaClient();
        const config = getConfig();

        // Retrieve the provider record to get the token for revocation
        const provider = await prisma.lLMProvider.findUnique({
          where: {
            userId_provider: {
              userId: request.userId,
              provider: 'openai',
            },
          },
        });

        if (!provider) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'OpenAI provider not connected',
          });
        }

        // Decrypt and revoke the access token
        try {
          const decryptedAccessToken = decryptToken(
            provider.accessTokenEncrypted.toString(),
            config.ENCRYPTION_KEY
          );
          await revokeToken(decryptedAccessToken);
        } catch (revocationError) {
          // Log the error but continue with deletion
          const errorMsg =
            revocationError instanceof Error ? revocationError.message : String(revocationError);
          fastify.log.warn({ revocationError: errorMsg }, 'Failed to revoke token at OpenAI');
        }

        // Delete the provider record
        await prisma.lLMProvider.delete({
          where: {
            userId_provider: {
              userId: request.userId,
              provider: 'openai',
            },
          },
        });

        return reply.status(200).send({
          message: 'OpenAI provider disconnected successfully',
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to disconnect provider',
        });
      }
    }
  );

  // GET /oauth/openai/status - Get OpenAI OAuth connection status
  fastify.get<{ Querystring: OAuthStatusRequest }>(
    '/openai/status',
    {
      preHandler: validateQuery(oauthStatusSchema),
    },
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const prisma = getPrismaClient();
        const provider = await prisma.lLMProvider.findUnique({
          where: {
            userId_provider: {
              userId: request.userId,
              provider: 'openai',
            },
          },
          select: {
            id: true,
            provider: true,
            status: true,
            connectedAt: true,
            tokenExpiresAt: true,
            updatedAt: true,
          },
        });

        if (!provider) {
          return reply.status(200).send({
            connected: false,
            message: 'OpenAI provider not connected',
          });
        }

        const isTokenExpired = provider.tokenExpiresAt ? provider.tokenExpiresAt < new Date() : false;

        return reply.status(200).send({
          connected: true,
          provider,
          tokenExpired: isTokenExpired,
          message: isTokenExpired ? 'Token has expired' : 'Provider is connected',
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to get provider status',
        });
      }
    }
  );

  // POST /oauth/openai/refresh - Manually trigger token refresh
  fastify.post<{ Body: OAuthRefreshRequest }>(
    '/openai/refresh',
    {
      preHandler: validateBody(oauthRefreshSchema),
    },
    async (request, reply) => {
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const prisma = getPrismaClient();
        const config = getConfig();

        // Retrieve the provider record
        const provider = await prisma.lLMProvider.findUnique({
          where: {
            userId_provider: {
              userId: request.userId,
              provider: 'openai',
            },
          },
        });

        if (!provider) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'OpenAI provider not connected',
          });
        }

        if (!provider.refreshTokenEncrypted) {
          return reply.status(400).send({
            statusCode: 400,
            error: 'Bad Request',
            message: 'No refresh token available for this provider',
          });
        }

        // Decrypt refresh token
        const decryptedRefreshToken = decryptToken(
          provider.refreshTokenEncrypted.toString(),
          config.ENCRYPTION_KEY
        );

        // Refresh the token
        const newTokens = await refreshAccessToken(decryptedRefreshToken);

        // Encrypt new tokens
        const encryptedAccessToken = encryptToken(newTokens.accessToken, config.ENCRYPTION_KEY);
        const encryptedRefreshToken = newTokens.refreshToken
          ? encryptToken(newTokens.refreshToken, config.ENCRYPTION_KEY)
          : null;

        // Update the provider record
        const tokenExpiresAt = new Date(Date.now() + newTokens.expiresIn * 1000);
        const updatedProvider = await prisma.lLMProvider.update({
          where: {
            userId_provider: {
              userId: request.userId,
              provider: 'openai',
            },
          },
          data: {
            accessTokenEncrypted: Buffer.from(encryptedAccessToken),
            refreshTokenEncrypted: encryptedRefreshToken
              ? Buffer.from(encryptedRefreshToken)
              : null,
            tokenExpiresAt,
            updatedAt: new Date(),
          },
          select: {
            id: true,
            provider: true,
            status: true,
            connectedAt: true,
            tokenExpiresAt: true,
            updatedAt: true,
          },
        });

        return reply.status(200).send({
          message: 'Token refreshed successfully',
          provider: updatedProvider,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: error instanceof Error ? error.message : 'Failed to refresh token',
        });
      }
    }
  );
}
