import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateParams } from '@middleware/validate';

const childParamsSchema = z.object({
  childId: z.string().uuid(),
});

type ChildParams = z.infer<typeof childParamsSchema>;

interface AnalyticsResponse {
  totalLessons: number;
  completedLessons: number;
  completionRate: number;
  currentStreak: number;
  longestStreak: number;
  totalTimeMinutes: number;
  weeklyHeatmap: number[];
  badgesEarned: number;
  badgesTotal: number;
  stageProgress: {
    current: string;
    lessonsToNext: number;
  };
  recentActivity: Array<{
    date: string;
    type: string;
    detail: string;
  }>;
}

export default async function analyticsRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /analytics/:childId - Get comprehensive analytics for a child
  fastify.get<{ Params: ChildParams }>(
    '/:childId',
    {
      preHandler: validateParams(childParamsSchema),
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
        const prisma = (fastify as any).prisma;

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
            message: 'You do not have permission to view analytics for this child',
          });
        }

        // Get all learning sessions for this child
        const sessions = await prisma.learningSession.findMany({
          where: { childId },
          select: {
            id: true,
            startedAt: true,
            interactions: {
              select: {
                durationMs: true,
                cardId: true,
                card: {
                  select: {
                    lessonId: true,
                    type: true,
                  },
                },
              },
            },
          },
          orderBy: { startedAt: 'asc' },
        });

        // Get earned badges
        const earnedBadges = await prisma.earnedBadge.findMany({
          where: { childId },
        });

        // Get total badges
        const totalBadges = await prisma.badge.count();

        // Calculate metrics
        const totalLessons = countUniqueLessons(sessions);
        const totalTimeMs = calculateTotalTime(sessions);
        const totalTimeMinutes = Math.round(totalTimeMs / 1000 / 60);
        const currentStreak = calculateCurrentStreak(sessions);
        const longestStreak = calculateLongestStreak(sessions);
        const weeklyHeatmap = calculateWeeklyHeatmap(sessions);
        const recentActivity = getRecentActivity(sessions).slice(0, 10);

        // Calculate completion rate (simplified - based on available lessons)
        let completedLessons = totalLessons;
        let completionRate = 100;

        try {
          const totalAvailableLessons = await prisma.lesson.count({
            where: { publishedAt: { not: null } },
          });

          if (totalAvailableLessons > 0) {
            completionRate = Math.min(100, Math.round((totalLessons / totalAvailableLessons) * 100));
          }
        } catch (error) {
          fastify.log.warn(`Failed to calculate completion rate: ${error}`);
        }

        // Determine stage progress
        const stageProgress = calculateStageProgress(totalLessons);

        const analytics: AnalyticsResponse = {
          totalLessons,
          completedLessons,
          completionRate,
          currentStreak,
          longestStreak,
          totalTimeMinutes,
          weeklyHeatmap,
          badgesEarned: earnedBadges.length,
          badgesTotal: totalBadges,
          stageProgress,
          recentActivity,
        };

        return reply.status(200).send(analytics);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch analytics',
        });
      }
    }
  );
}

/**
 * Count unique lessons completed
 */
function countUniqueLessons(
  sessions: Array<{ interactions: Array<{ card: { lessonId: string } }> }>
): number {
  const uniqueLessons = new Set<string>();

  for (const session of sessions) {
    for (const interaction of session.interactions) {
      uniqueLessons.add(interaction.card.lessonId);
    }
  }

  return uniqueLessons.size;
}

/**
 * Calculate total time spent learning
 */
function calculateTotalTime(
  sessions: Array<{ interactions: Array<{ durationMs: number }> }>
): number {
  let total = 0;

  for (const session of sessions) {
    for (const interaction of session.interactions) {
      total += interaction.durationMs || 0;
    }
  }

  return total;
}

/**
 * Calculate current streak (consecutive days from today backwards)
 */
function calculateCurrentStreak(sessions: Array<{ startedAt: Date }>): number {
  if (sessions.length === 0) {
    return 0;
  }

  // Group sessions by date
  const sessionsByDate = new Map<string, boolean>();

  for (const session of sessions) {
    const date = session.startedAt.toISOString().split('T')[0];
    sessionsByDate.set(date, true);
  }

  // Count consecutive days from today backwards
  let consecutive = 0;
  const today = new Date();
  let checkDate = new Date(today);

  for (let i = 0; i < 365; i++) {
    const dateStr = checkDate.toISOString().split('T')[0];

    if (sessionsByDate.has(dateStr)) {
      consecutive++;
    } else if (consecutive > 0) {
      // Stop if we hit a gap after counting some days
      break;
    }

    checkDate.setDate(checkDate.getDate() - 1);
  }

  return consecutive;
}

/**
 * Calculate longest streak across all history
 */
function calculateLongestStreak(sessions: Array<{ startedAt: Date }>): number {
  if (sessions.length === 0) {
    return 0;
  }

  // Group sessions by date
  const sessionsByDate = new Map<string, boolean>();

  for (const session of sessions) {
    const date = session.startedAt.toISOString().split('T')[0];
    sessionsByDate.set(date, true);
  }

  // Get sorted dates
  const sortedDates = Array.from(sessionsByDate.keys()).sort();

  if (sortedDates.length === 0) {
    return 0;
  }

  // Find longest consecutive sequence
  let maxStreak = 1;
  let currentStreak = 1;

  for (let i = 1; i < sortedDates.length; i++) {
    const prevDate = new Date(sortedDates[i - 1]);
    const currDate = new Date(sortedDates[i]);

    const dayDiff =
      (currDate.getTime() - prevDate.getTime()) / (1000 * 60 * 60 * 24);

    if (dayDiff === 1) {
      currentStreak++;
      maxStreak = Math.max(maxStreak, currentStreak);
    } else {
      currentStreak = 1;
    }
  }

  return maxStreak;
}

/**
 * Calculate weekly heatmap (activity count for last 7 days)
 */
function calculateWeeklyHeatmap(sessions: Array<{ startedAt: Date }>): number[] {
  const heatmap: number[] = Array(7).fill(0);

  for (const session of sessions) {
    const dayOfWeek = session.startedAt.getDay();
    heatmap[dayOfWeek]++;
  }

  return heatmap;
}

/**
 * Get recent activity
 */
function getRecentActivity(
  sessions: Array<{
    startedAt: Date;
    interactions: Array<{ card: { type: string } }>;
  }>
): Array<{ date: string; type: string; detail: string }> {
  const activities: Array<{ date: string; type: string; detail: string }> = [];

  for (const session of sessions) {
    const date = session.startedAt.toISOString().split('T')[0];

    for (const interaction of session.interactions) {
      activities.push({
        date,
        type: interaction.card.type || 'learning',
        detail: `Completed a ${interaction.card.type || 'lesson'}`,
      });
    }
  }

  return activities.sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
}

/**
 * Calculate stage progress based on lessons completed
 */
function calculateStageProgress(lessonsCompleted: number): {
  current: string;
  lessonsToNext: number;
} {
  const stages = [
    { name: 'Beginner', threshold: 0 },
    { name: 'Explorer', threshold: 5 },
    { name: 'Adventurer', threshold: 10 },
    { name: 'Expert', threshold: 20 },
    { name: 'Master', threshold: 50 },
  ];

  let currentStage = stages[0];

  for (let i = stages.length - 1; i >= 0; i--) {
    if (lessonsCompleted >= stages[i].threshold) {
      currentStage = stages[i];
      break;
    }
  }

  const nextStageIndex = stages.findIndex((s: any) => s.name === currentStage.name) + 1;
  const nextThreshold = nextStageIndex < stages.length ? stages[nextStageIndex].threshold : Infinity;
  const lessonsToNext = Math.max(0, nextThreshold - lessonsCompleted);

  return {
    current: currentStage.name,
    lessonsToNext,
  };
}
