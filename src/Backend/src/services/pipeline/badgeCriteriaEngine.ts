/**
 * Badge Criteria Engine
 *
 * Evaluates badge criteria for children and awards badges when criteria are met.
 * Supports multiple criteria types:
 * - lesson_completion: Earned when N lessons are completed
 * - experiments_passed: Earned when N experiments are done
 * - days_streak: Earned after N consecutive days of learning
 * - voice_interactions: Earned after N voice interactions
 */

import { getPrismaClient } from '@db/client';
// Badge type inferred from Prisma schema

export interface EvaluatedBadge {
  badgeId: string;
  title: string;
  description?: string;
  icon?: string;
  newlyEarned: boolean;
}

export interface BadgeCriteria {
  type: 'lesson_completion' | 'experiments_passed' | 'days_streak' | 'voice_interactions';
  count?: number;
  days?: number;
}

/**
 * Evaluate all badges for a child and award newly earned ones
 */
export async function evaluateBadges(childId: string): Promise<EvaluatedBadge[]> {
  const prisma = getPrismaClient();

  // Get all badges
  const allBadges = await prisma.badge.findMany({
    select: {
      id: true,
      title: true,
      description: true,
      icon: true,
      criteria: true,
    },
  });

  // Get earned badges for this child
  const earnedBadges = await prisma.earnedBadge.findMany({
    where: { childId },
    select: { badgeId: true },
  });

  const earnedBadgeIds = new Set(earnedBadges.map((eb: { badgeId: string }) => eb.badgeId));

  // Compute child's progress
  const childProgress = await computeChildProgress(childId);

  const evaluatedBadges: EvaluatedBadge[] = [];

  // Evaluate each badge
  for (const badge of allBadges) {
    const isEarned = earnedBadgeIds.has(badge.id);

    if (isEarned) {
      evaluatedBadges.push({
        badgeId: badge.id,
        title: badge.title,
        description: badge.description || undefined,
        icon: badge.icon || undefined,
        newlyEarned: false,
      });
      continue;
    }

    // Check if badge criteria are met
    const criteria = badge.criteria as BadgeCriteria | null;
    if (!criteria) {
      continue;
    }

    const shouldAward = checkBadgeCriteria(criteria, childProgress);

    if (shouldAward) {
      // Create earned badge record
      await prisma.earnedBadge.create({
        data: {
          childId,
          badgeId: badge.id,
        },
      });

      evaluatedBadges.push({
        badgeId: badge.id,
        title: badge.title,
        description: badge.description || undefined,
        icon: badge.icon || undefined,
        newlyEarned: true,
      });
    }
  }

  return evaluatedBadges;
}

/**
 * Compute child progress metrics
 */
async function computeChildProgress(childId: string): Promise<ChildProgress> {
  const prisma = getPrismaClient();

  // Get all learning sessions
  const sessions = await prisma.learningSession.findMany({
    where: { childId },
    select: {
      startedAt: true,
      interactions: {
        select: {
          cardId: true,
          voiceTranscript: true,
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

  // Count unique lessons completed
  const lessonsCompleted = new Set<string>();
  let experimentsCompleted = 0;
  let voiceInteractions = 0;

  for (const session of sessions) {
    for (const interaction of session.interactions) {
      lessonsCompleted.add(interaction.card.lessonId);

      if (interaction.card.type === 'experiment') {
        experimentsCompleted++;
      }

      if (interaction.voiceTranscript) {
        voiceInteractions++;
      }
    }
  }

  // Calculate days streak
  const daysSinceFirstSession = sessions.length > 0 ? getDaysSince(sessions[0].startedAt) : 0;
  const consecutiveDaysOfLearning = calculateConsecutiveDays(sessions);

  return {
    lessonsCompleted: lessonsCompleted.size,
    experimentsCompleted,
    voiceInteractions,
    daysSinceFirstSession,
    consecutiveDaysOfLearning,
  };
}

/**
 * Check if a child meets the criteria for a badge
 */
export interface ChildProgress {
  lessonsCompleted: number;
  experimentsCompleted: number;
  voiceInteractions: number;
  daysSinceFirstSession: number;
  consecutiveDaysOfLearning: number;
}

export function checkBadgeCriteria(criteria: BadgeCriteria, progress: ChildProgress): boolean {
  const { type, count = 0, days = 0 } = criteria;

  switch (type) {
    case 'lesson_completion':
      return progress.lessonsCompleted >= count;

    case 'experiments_passed':
      return progress.experimentsCompleted >= count;

    case 'voice_interactions':
      return progress.voiceInteractions >= count;

    case 'days_streak':
      return progress.consecutiveDaysOfLearning >= days;

    default:
      return false;
  }
}

/**
 * Get number of days since a date
 */
function getDaysSince(date: Date): number {
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  return Math.floor(diff / (1000 * 60 * 60 * 24));
}

/**
 * Calculate consecutive days of learning
 * A day is considered a learning day if there's at least one session
 */
function calculateConsecutiveDays(
  sessions: Array<{
    startedAt: Date;
  }>
): number {
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

  // Count consecutive days from the most recent date
  let consecutive = 0;
  const today = new Date();
  let checkDate = new Date(today);

  // Start from today and work backwards
  for (let i = 0; i < 365; i++) {
    const dateStr = checkDate.toISOString().split('T')[0];

    if (sessionsByDate.has(dateStr)) {
      consecutive++;
    } else {
      // If we've already counted some days and missed one, stop
      if (consecutive > 0) {
        break;
      }
    }

    checkDate.setDate(checkDate.getDate() - 1);
  }

  return consecutive;
}

/**
 * Get badge evaluation for a specific child
 */
export async function getBadgeEvaluationForChild(childId: string): Promise<{
  earnedBadges: EvaluatedBadge[];
  progress: Awaited<ReturnType<typeof computeChildProgress>>;
}> {
  const earnedBadges = await evaluateBadges(childId);
  const progress = await computeChildProgress(childId);

  return {
    earnedBadges,
    progress,
  };
}
