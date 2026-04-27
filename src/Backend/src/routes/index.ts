import type { FastifyInstance } from 'fastify';
import { healthRoutes } from './health';
import { authRoutes } from './auth';
import { userRoutes } from './users';
import { childrenRoutes } from './children';
import { lessonRoutes } from './lessons';
import { cardRoutes } from './cards';
import { pathRoutes } from './paths';
import { progressRoutes } from './progress';
import { badgeRoutes } from './badges';
import { oauthRoutes } from './oauth';
import { pipelineRoutes } from './pipeline';
import { providersRoutes } from './providers';
import { syncRoutes } from './sync';
import { webhookRoutes } from './webhooks';
import dashyRoutes from './dashy';
import entitlementRoutes from './entitlements';
import analyticsRoutes from './analytics';
import dataRightsRoutes from './dataRights';
import featureFlagsRoutes from './featureFlags';
import monitoringRoutes from './monitoring';
import privacyRoutes from './privacy';
import { knowledgeRoutes } from './knowledge';
import { engagementRoutes } from './engagement';
import { devConsoleRoutes } from './devConsole';
import { devSkillsRoutes } from './devSkills';
import devAuthorRoutes from './devAuthor';
import { parentGuidanceRoutes } from './parentGuidance';
import { voiceRoutes } from './voice';

export async function registerRoutes(fastify: FastifyInstance): Promise<void> {
  // Webhook routes (no auth required - called by Apple directly)
  await fastify.register(webhookRoutes, { prefix: '/webhooks' });

  // API v1 routes (all nested under /api/v1)
  await fastify.register(
    async (fastify) => {
      // Health check (no auth required)
      await fastify.register(healthRoutes);

      // Auth routes (some public, some require auth)
      await fastify.register(authRoutes, { prefix: '/auth' });

      // User routes (require auth)
      await fastify.register(userRoutes, { prefix: '/users' });

      // Child profile routes (require auth)
      await fastify.register(childrenRoutes, { prefix: '/children' });

      // Learning path routes (require auth)
      await fastify.register(pathRoutes, { prefix: '/paths' });

      // Lesson routes (require auth)
      await fastify.register(lessonRoutes, { prefix: '/lessons' });

      // Card routes (require auth)
      await fastify.register(cardRoutes, { prefix: '/cards' });

      // Progress tracking routes (require auth)
      await fastify.register(progressRoutes, { prefix: '/progress' });

      // Badge routes (require auth)
      await fastify.register(badgeRoutes, { prefix: '/badges' });

      // OAuth routes (require auth) - Sprint 3
      await fastify.register(oauthRoutes, { prefix: '/oauth' });

      // Provider management routes (require auth) - Sprint 3
      await fastify.register(providersRoutes, { prefix: '/providers' });

      // Pipeline routes (require auth) - Sprint 5
      await fastify.register(pipelineRoutes, { prefix: '/pipeline' });

      // Sync routes (require auth) - Sprint 4
      await fastify.register(syncRoutes, { prefix: '/sync' });

      // Dashy conversation routes (require auth) - Sprint 6; renamed S12-07/08
      await fastify.register(dashyRoutes, { prefix: '/dashy' });

      // Entitlement routes (require auth) - Sprint 6
      await fastify.register(entitlementRoutes, { prefix: '/entitlements' });

      // Analytics routes (require auth) - Sprint 6
      await fastify.register(analyticsRoutes, { prefix: '/analytics' });

      // Data rights routes (require auth) - Sprint 6
      await fastify.register(dataRightsRoutes, { prefix: '/children' });

      // Feature flags routes (require auth) - Sprint 7
      await fastify.register(featureFlagsRoutes);

      // Monitoring routes (require auth for /stats) - Sprint 7
      await fastify.register(monitoringRoutes);

      // Privacy & legal routes (no auth required) - Sprint 7
      await fastify.register(privacyRoutes);

      // Knowledge graph routes (require auth) - Sprint 10 (S10-01)
      await fastify.register(knowledgeRoutes, { prefix: '/knowledge' });

      // Engagement profile routes (require auth) - Sprint 10 (S10-03)
      await fastify.register(engagementRoutes, { prefix: '/engagement' });

      // Parent Guidance routes (require auth) - Sprint 10 (S10-04)
      // Nested under /children so URL is /api/v1/children/:childId/guidance
      await fastify.register(parentGuidanceRoutes, { prefix: '/children' });

      // Dev console support routes (require auth) - Sprint 10 side-quest (DC-04)
      await fastify.register(devConsoleRoutes, { prefix: '/dev' });

      // Dev console — Skill Engine routes (require auth) - Sprint 10 (S10-06/07)
      await fastify.register(devSkillsRoutes, { prefix: '/dev' });

      // Dev console — Author Lesson SSE route (require auth) - Sprint 12 (S12-09)
      await fastify.register(devAuthorRoutes, { prefix: '/dev' });

      // Voice TTS proxy routes (require auth) - Sprint 13 (S13-05)
      await fastify.register(voiceRoutes, { prefix: '/voice' });
    },
    { prefix: '/api/v1' }
  );
}
