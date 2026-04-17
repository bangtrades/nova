/**
 * LLM Provider Router
 *
 * Central service that routes LLM requests to the appropriate provider:
 * 1. BYOK (Bring Your Own Key) - User's own OpenAI API key via OAuth
 * 2. Proxy - Platform's OpenAI API key with subscription-based rate limits
 *
 * Routing decision:
 * 1. Check if user has a connected BYOK provider with valid (non-expired) token
 * 2. If yes -> decrypt token and use BYOK provider (unlimited)
 * 3. If no -> check subscription tier and use proxy provider with rate limits
 */

import { getPrismaClient } from '@db/client';
import type { LLMRequest, LLMResponse } from './types';
import { chatCompletion } from './openaiProvider';
import { chatCompletionProxy } from './proxyProvider';
import { claudeCompletion } from './anthropicProvider';
import { decryptToken } from '../oauth/tokenEncryption';
import { getConfig } from '@config';
import { logUsage, type CostFeature } from './costTracker';

export interface RoutingResult {
  provider: 'byok' | 'proxy';
  response: LLMResponse;
}

/**
 * Routes an LLM request to the appropriate provider
 * @param userId - User making the request
 * @param request - LLM request payload
 * @param feature - What pipeline stage this call serves (for cost tracking)
 */
export async function routeRequest(
  userId: string,
  request: LLMRequest,
  feature: CostFeature = 'other'
): Promise<LLMResponse> {
  const prisma = getPrismaClient();
  const config = getConfig();

  // Route Claude models directly to Anthropic API (server-side key)
  if (request.model.startsWith('claude')) {
    if (config.ANTHROPIC_API_KEY) {
      try {
        const response = await claudeCompletion(config.ANTHROPIC_API_KEY, request);
        // Log cost
        logUsage({
          userId,
          provider: 'anthropic',
          model: request.model,
          feature,
          promptTokens: response.usage.promptTokens,
          completionTokens: response.usage.completionTokens,
          totalTokens: response.usage.totalTokens,
        });
        return response;
      } catch (error) {
        // If Claude fails (network, rate limit, etc.), fall through to OpenAI
        console.warn(`Claude provider failed, falling back to OpenAI:`, error);
      }
    } else {
      console.warn('ANTHROPIC_API_KEY not configured — falling back to OpenAI for Claude model request');
    }
    // Remap to OpenAI equivalent for fallback
    request = { ...request, model: 'gpt-4o-mini' };
  }

  // Check for connected BYOK provider with valid token
  const provider = await prisma.lLMProvider.findUnique({
    where: {
      userId_provider: {
        userId,
        provider: 'openai',
      },
    },
  });

  // If user has BYOK provider and token is not expired, use it
  if (provider && provider.status === 'active') {
    const isTokenExpired = provider.tokenExpiresAt ? provider.tokenExpiresAt < new Date() : false;

    if (!isTokenExpired) {
      // Decrypt the access token
      const decryptedToken = decryptToken(
        provider.accessTokenEncrypted.toString(),
        config.ENCRYPTION_KEY
      );

      // Use BYOK provider (no rate limits)
      try {
        const response = await chatCompletion(decryptedToken, request);
        // Log cost (BYOK — user's own key, but still track for analytics)
        logUsage({
          userId,
          provider: 'openai-byok',
          model: request.model,
          feature,
          promptTokens: response.usage.promptTokens,
          completionTokens: response.usage.completionTokens,
          totalTokens: response.usage.totalTokens,
        });
        return {
          ...response,
          provider: 'byok',
        };
      } catch (error) {
        // If BYOK fails, fall through to proxy
        console.warn(`BYOK provider failed for user ${userId}, falling back to proxy:`, error);
      }
    }
  }

  // Fall back to proxy provider based on subscription tier
  const subscription = await prisma.subscription.findUnique({
    where: { userId },
  });

  const tier = (subscription?.plan as 'free' | 'pro') || 'free';

  // Use proxy provider with subscription-based rate limiting
  const response = await chatCompletionProxy(userId, tier, request);

  // Log cost
  logUsage({
    userId,
    provider: 'openai',
    model: request.model,
    feature,
    promptTokens: response.usage.promptTokens,
    completionTokens: response.usage.completionTokens,
    totalTokens: response.usage.totalTokens,
  });

  return response;
}

/**
 * Get detailed routing information for a user
 * Useful for debugging and UI display
 */
export async function getRoutingInfo(userId: string): Promise<{
  hasByokProvider: boolean;
  byokTokenExpired: boolean;
  subscriptionTier: string;
  willUseByok: boolean;
}> {
  const prisma = getPrismaClient();

  const provider = await prisma.lLMProvider.findUnique({
    where: {
      userId_provider: {
        userId,
        provider: 'openai',
      },
    },
    select: {
      status: true,
      tokenExpiresAt: true,
    },
  });

  const subscription = await prisma.subscription.findUnique({
    where: { userId },
    select: { plan: true },
  });

  const hasByokProvider = provider?.status === 'active' && !!provider;
  const byokTokenExpired = provider?.tokenExpiresAt ? provider.tokenExpiresAt < new Date() : true;
  const willUseByok = hasByokProvider && !byokTokenExpired;
  const subscriptionTier = subscription?.plan || 'free';

  return {
    hasByokProvider,
    byokTokenExpired,
    subscriptionTier,
    willUseByok,
  };
}
