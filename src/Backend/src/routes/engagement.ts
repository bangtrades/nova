/**
 * Engagement Profile routes (Sprint 10 — S10-03, "The Brain")
 *
 * Read-side access to the per-child behavioral profile produced by
 * services/engagement/engagementProfiler.ts. The write side is driven
 * from /progress/sync — no write endpoint here (yet).
 *
 * Endpoints:
 *   GET /api/v1/engagement/children/:childId        → EngagementProfileView
 *   GET /api/v1/engagement/children/:childId/raw    → debugging: raw row + decrypted blobs
 *
 * Auth: requires request.userId (dev middleware auto-fills firstUser.id).
 * Access control: caller must own the child — same pattern as /progress.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { getConfig } from '@config';
import { validateParams } from '@middleware/validate';
import {
  getEngagementProfile,
  rankCardTypePreferences,
  rankTopicAffinities,
  type CardTypeStats,
  type TopicAffinities,
} from '@services/engagement/engagementProfiler';
import { decryptToken } from '@services/oauth/tokenEncryption';

const childParamsSchema = z.object({
  childId: z.string().uuid(),
});

type ChildParams = z.infer<typeof childParamsSchema>;

async function checkChildOwnership(
  childId: string,
  userId: string
): Promise<{ ok: true } | { ok: false; status: number; error: string; message: string }> {
  const prisma = getPrismaClient();
  const child = await prisma.childProfile.findUnique({
    where: { id: childId },
    select: { userId: true },
  });
  if (!child) {
    return {
      ok: false,
      status: 404,
      error: 'NotFound',
      message: `Child '${childId}' not found`,
    };
  }
  if (child.userId !== userId) {
    return {
      ok: false,
      status: 403,
      error: 'Forbidden',
      message: 'You do not have permission to view engagement data for this child',
    };
  }
  return { ok: true };
}

function decryptOrEmpty<T>(blob: string | null | undefined, key: string, fallback: T): T {
  if (!blob) return fallback;
  try {
    return JSON.parse(decryptToken(blob, key)) as T;
  } catch {
    return fallback;
  }
}

export async function engagementRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /engagement/children/:childId — rendered view (decrypted + ranked)
  fastify.get<{ Params: ChildParams }>(
    '/children/:childId',
    { preHandler: validateParams(childParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const ownership = await checkChildOwnership(childId, request.userId);
      if (!ownership.ok) {
        return reply.status(ownership.status).send({
          statusCode: ownership.status,
          error: ownership.error,
          message: ownership.message,
        });
      }

      const view = await getEngagementProfile(childId);
      if (!view) {
        // No profile yet — return a zero-state payload so the dev console
        // has something consistent to render.
        return reply.status(200).send({
          data: {
            childId,
            totalSessions: 0,
            totalInteractions: 0,
            totalDurationMs: 0,
            avgInteractionMs: 0,
            frustrationEventCount: 0,
            flowEventCount: 0,
            currentStreak: 0,
            longestStreak: 0,
            cardTypePreferences: [],
            topicAffinities: [],
            lastInteractionAt: null,
            lastComputedAt: null,
            hasProfile: false,
          },
        });
      }

      return reply.status(200).send({
        data: { ...view, hasProfile: true },
      });
    }
  );

  // GET /engagement/children/:childId/raw — debugging view. Ships the raw
  // decrypted card-type stats + topic affinity objects alongside the
  // ranked view, so the dev console can render lower-level detail tables.
  fastify.get<{ Params: ChildParams }>(
    '/children/:childId/raw',
    { preHandler: validateParams(childParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const ownership = await checkChildOwnership(childId, request.userId);
      if (!ownership.ok) {
        return reply.status(ownership.status).send({
          statusCode: ownership.status,
          error: ownership.error,
          message: ownership.message,
        });
      }

      const prisma = getPrismaClient();
      const row = await prisma.engagementProfile.findUnique({ where: { childId } });
      if (!row) {
        return reply.status(200).send({
          data: null,
          hasProfile: false,
        });
      }

      const key = getConfig().ENCRYPTION_KEY;
      const cardTypeStats = decryptOrEmpty<CardTypeStats>(
        row.cardTypeStatsEncrypted,
        key,
        {}
      );
      const topicAffinities = decryptOrEmpty<TopicAffinities>(
        row.topicAffinitiesEncrypted,
        key,
        {}
      );

      return reply.status(200).send({
        data: {
          childId: row.childId,
          counters: {
            totalSessions: row.totalSessions,
            totalInteractions: row.totalInteractions,
            totalDurationMs: row.totalDurationMs,
            frustrationEventCount: row.frustrationEventCount,
            flowEventCount: row.flowEventCount,
            currentStreak: row.currentStreak,
            longestStreak: row.longestStreak,
          },
          cardTypeStats,
          topicAffinities,
          rankedCardTypes: rankCardTypePreferences(cardTypeStats),
          rankedTopics: rankTopicAffinities(topicAffinities),
          timestamps: {
            lastInteractionAt: row.lastInteractionAt,
            lastComputedAt: row.lastComputedAt,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          },
        },
        hasProfile: true,
      });
    }
  );
}
