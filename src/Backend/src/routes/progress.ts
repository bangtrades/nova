import type { FastifyInstance } from 'fastify';
import { Prisma } from '@prisma/client';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams, validateQuery } from '@middleware/validate';
import { evaluateBadges } from '@services/pipeline/badgeCriteriaEngine';
import { recordQuizResultsBatch, type QuizResultEvent } from '@services/mastery/masteryTracker';
import {
  ingestInteractionsForSession,
  type InteractionEvent as EngagementInteractionEvent,
  type ProfileDelta as EngagementProfileDelta,
} from '@services/engagement/engagementProfiler';
import { recordSyncEvent } from './devConsole';

const cardInteractionSchema = z.object({
  cardId: z.string().uuid(),
  action: z.string(),
  durationMs: z.number().int().min(0),
  voiceTranscript: z.string().optional(),
  result: z.record(z.unknown()).optional(),
});

const syncProgressSchema = z.object({
  childId: z.string().uuid(),
  deviceId: z.string().optional(),
  interactions: z.array(cardInteractionSchema),
});

const progressParamsSchema = z.object({
  childId: z.string().uuid(),
});

const progressSessionsQuerySchema = z.object({
  page: z.string().pipe(z.coerce.number().int().min(1)).default('1'),
  limit: z.string().pipe(z.coerce.number().int().min(1).max(50)).default('20'),
});

type SyncProgressRequest = z.infer<typeof syncProgressSchema>;
type ProgressParams = z.infer<typeof progressParamsSchema>;
type ProgressSessionsQuery = z.infer<typeof progressSessionsQuerySchema>;

export async function progressRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /progress/sync - Sync progress data
  fastify.post<{ Body: SyncProgressRequest }>(
    '/sync',
    {
      preHandler: validateBody(syncProgressSchema),
    },
    async (request, reply) => {
      const syncStartedAt = Date.now();
      try {
        if (!request.userId) {
          return reply.status(401).send({
            statusCode: 401,
            error: 'Unauthorized',
            message: 'Missing authentication token',
          });
        }

        const { childId, deviceId, interactions } = request.body;
        const prisma = getPrismaClient();

        // Verify child ownership
        const child = await prisma.childProfile.findUnique({
          where: { id: childId },
          select: { userId: true },
        });

        if (!child) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Child profile not found',
          });
        }

        if (child.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to sync progress for this child',
          });
        }

        // Create learning session
        const session = await prisma.learningSession.create({
          data: {
            childId,
            deviceId: deviceId || null,
          },
        });

        // Create all interactions
        const createdInteractions = await Promise.all(
          interactions.map((interaction) =>
            prisma.cardInteraction.create({
              data: {
                sessionId: session.id,
                cardId: interaction.cardId,
                action: interaction.action,
                durationMs: interaction.durationMs,
                voiceTranscript: interaction.voiceTranscript || null,
                result: (interaction.result as Prisma.InputJsonValue) ?? Prisma.JsonNull,
              },
            })
          )
        );

        // Fetch card metadata once — reused by both the mastery path (S10-02)
        // and the engagement path (S10-03). Includes concept.domain so the
        // profiler can build topic affinities without a second query.
        const uniqueCardIds = [...new Set(interactions.map((i) => i.cardId))];
        const cards = uniqueCardIds.length > 0
          ? await prisma.card.findMany({
              where: { id: { in: uniqueCardIds } },
              select: {
                id: true,
                type: true,
                conceptId: true,
                concept: { select: { domain: true } },
              },
            })
          : [];
        const cardById = new Map(cards.map((c) => [c.id, c]));

        // S10-02: Update per-concept mastery from quiz results.
        // A quiz result is any interaction where:
        //   - action === 'answer'
        //   - result.correct is a boolean
        //   - the card has a conceptId (mastery-bearing cards only)
        // Non-quiz interactions (views, story completions, sparky chats) are ignored.
        const quizInteractions = interactions.filter(
          (i) => i.action === 'answer' && typeof i.result?.correct === 'boolean'
        );
        let masteryUpdates: Awaited<ReturnType<typeof recordQuizResultsBatch>> = [];
        if (quizInteractions.length > 0) {
          const events: QuizResultEvent[] = quizInteractions
            .map((i) => {
              const card = cardById.get(i.cardId);
              if (!card?.conceptId) return null;
              return {
                childId,
                conceptId: card.conceptId,
                isCorrect: i.result?.correct === true,
              };
            })
            .filter((e): e is QuizResultEvent => e !== null);

          if (events.length > 0) {
            masteryUpdates = await recordQuizResultsBatch(events);
          }
        }

        // S10-03: Ingest ALL interactions into the per-child engagement
        // profile. Unlike mastery (quiz-only), engagement signals come from
        // every interaction type — views, completions, skips, quiz answers.
        let engagementDelta: EngagementProfileDelta | null = null;
        if (interactions.length > 0) {
          const engagementEvents: EngagementInteractionEvent[] = interactions.map((i) => {
            const card = cardById.get(i.cardId);
            const isAnswer = i.action === 'answer' && typeof i.result?.correct === 'boolean';
            return {
              cardId: i.cardId,
              cardType: card?.type ?? 'unknown',
              conceptId: card?.conceptId ?? null,
              domain: card?.concept?.domain ?? null,
              action: i.action,
              durationMs: i.durationMs,
              isCorrect: isAnswer ? (i.result?.correct as boolean) : null,
            };
          });
          engagementDelta = await ingestInteractionsForSession(childId, engagementEvents);
        }

        // Evaluate badges after progress is recorded
        const earnedBadges = await evaluateBadges(childId);
        const newlyEarned = earnedBadges.filter((badge) => badge.newlyEarned);

        // DC-04: capture this sync in the dev-console ring buffer so the
        // Progress Inspector tab can live-tail what the handler did.
        // Safe to call unconditionally — the recorder is in-memory only.
        recordSyncEvent({
          userId: request.userId,
          childId,
          deviceId: deviceId ?? null,
          sessionId: session.id,
          interactionCount: createdInteractions.length,
          masteryUpdates: masteryUpdates.map((m) => ({
            conceptId: m.conceptId,
            priorConfidence: Number(m.priorConfidence.toFixed(3)),
            nextConfidence: Number(m.nextConfidence.toFixed(3)),
            attempts: m.attempts,
            correctCount: m.correctCount,
            wasFirstIntroduction: m.wasFirstIntroduction,
          })),
          engagementDelta: engagementDelta
            ? {
                interactionsApplied: engagementDelta.interactionsApplied,
                durationAddedMs: engagementDelta.durationAddedMs,
                frustrationEventsAdded: engagementDelta.frustrationEventsAdded,
                flowEventsAdded: engagementDelta.flowEventsAdded,
                finalStreak: engagementDelta.finalStreak,
                newLongestStreak: engagementDelta.newLongestStreak,
              }
            : null,
          newlyEarnedBadgeCount: newlyEarned.length,
          durationMs: Date.now() - syncStartedAt,
        });

        return reply.status(201).send({
          sessionId: session.id,
          interactionCount: createdInteractions.length,
          masteryUpdates: masteryUpdates.map((m) => ({
            conceptId: m.conceptId,
            priorConfidence: Number(m.priorConfidence.toFixed(3)),
            nextConfidence: Number(m.nextConfidence.toFixed(3)),
            attempts: m.attempts,
            correctCount: m.correctCount,
            wasFirstIntroduction: m.wasFirstIntroduction,
          })),
          engagementDelta: engagementDelta
            ? {
                interactionsApplied: engagementDelta.interactionsApplied,
                durationAddedMs: engagementDelta.durationAddedMs,
                frustrationEventsAdded: engagementDelta.frustrationEventsAdded,
                flowEventsAdded: engagementDelta.flowEventsAdded,
                finalStreak: engagementDelta.finalStreak,
                newLongestStreak: engagementDelta.newLongestStreak,
              }
            : null,
          newlyEarnedBadges: newlyEarned.map((badge) => ({
            badgeId: badge.badgeId,
            title: badge.title,
            description: badge.description,
            icon: badge.icon,
          })),
          message: 'Progress synced successfully',
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to sync progress',
        });
      }
    }
  );

  // GET /progress/:childId - Get progress summary
  fastify.get<{ Params: ProgressParams }>(
    '/:childId',
    {
      preHandler: validateParams(progressParamsSchema),
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

        const { childId } = request.params;
        const prisma = getPrismaClient();

        // Verify child ownership
        const child = await prisma.childProfile.findUnique({
          where: { id: childId },
          select: { userId: true },
        });

        if (!child) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Child profile not found',
          });
        }

        if (child.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view this child progress',
          });
        }

        // Get progress data
        const sessions = await prisma.learningSession.findMany({
          where: { childId },
          select: {
            id: true,
            startedAt: true,
            endedAt: true,
            interactions: {
              select: {
                durationMs: true,
              },
            },
          },
        });

        const earnedBadges = await prisma.earnedBadge.findMany({
          where: { childId },
          select: {
            badge: {
              select: {
                id: true,
                title: true,
                description: true,
                icon: true,
              },
            },
            earnedAt: true,
          },
        });

        type EarnedBadgeRow = typeof earnedBadges[number];

        const totalTime = sessions.reduce(
          (sum: number, session: typeof sessions[number]) =>
            sum +
            session.interactions.reduce((interactionSum: number, interaction: typeof session.interactions[number]) => {
              return interactionSum + (interaction.durationMs || 0);
            }, 0),
          0
        );

        const sessionsCompleted = sessions.length;
        const currentStreak = sessions.length > 0 ? 1 : 0; // Simplified streak

        return reply.status(200).send({
          childId,
          sessionsCompleted,
          totalTimeMs: totalTime,
          totalTimeMinutes: Math.round(totalTime / 1000 / 60),
          badgesEarned: earnedBadges.length,
          currentStreak,
          badges: earnedBadges.map((eb: EarnedBadgeRow) => ({
            id: eb.badge.id,
            title: eb.badge.title,
            description: eb.badge.description,
            icon: eb.badge.icon,
            earnedAt: eb.earnedAt,
          })),
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch progress summary',
        });
      }
    }
  );

  // GET /progress/:childId/sessions - Get paginated session history
  fastify.get<{ Params: ProgressParams; Querystring: ProgressSessionsQuery }>(
    '/:childId/sessions',
    {
      preHandler: [
        validateParams(progressParamsSchema),
        validateQuery(progressSessionsQuerySchema),
      ],
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

        const { childId } = request.params;
        const { page, limit } = request.query as unknown as ProgressSessionsQuery;
        const prisma = getPrismaClient();

        // Verify child ownership
        const child = await prisma.childProfile.findUnique({
          where: { id: childId },
          select: { userId: true },
        });

        if (!child) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Child profile not found',
          });
        }

        if (child.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view this child sessions',
          });
        }

        const skip = (page - 1) * limit;

        const [sessions, total] = await Promise.all([
          prisma.learningSession.findMany({
            where: { childId },
            select: {
              id: true,
              startedAt: true,
              endedAt: true,
              deviceId: true,
              interactions: {
                select: {
                  id: true,
                  cardId: true,
                  action: true,
                  durationMs: true,
                  timestamp: true,
                },
              },
            },
            orderBy: { startedAt: 'desc' },
            skip,
            take: limit,
          }),
          prisma.learningSession.count({
            where: { childId },
          }),
        ]);

        const totalPages = Math.ceil(total / limit);

        return reply.status(200).send({
          data: sessions.map((session: typeof sessions[number]) => ({
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            deviceId: session.deviceId,
            interactionCount: session.interactions.length,
            interactions: session.interactions,
          })),
          total,
          page,
          limit,
          totalPages,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch session history',
        });
      }
    }
  );
}
