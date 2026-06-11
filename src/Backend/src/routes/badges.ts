import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient, fromJsonColumn } from '@db/client';
import { validateParams } from '@middleware/validate';

const badgeParamsSchema = z.object({
  childId: z.string().uuid(),
});

type BadgeParams = z.infer<typeof badgeParamsSchema>;

export async function badgeRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /badges - List all available badges
  fastify.get('/', async (request, reply) => {
    try {
      const prisma = getPrismaClient();
      const badges = await prisma.badge.findMany({
        select: {
          id: true,
          title: true,
          description: true,
          icon: true,
          criteria: true,
        },
      });

      return reply.status(200).send({
        data: badges,
        total: badges.length,
      });
    } catch (error) {
      fastify.log.error(error);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch badges',
      });
    }
  });

  // GET /badges/earned/:childId - List earned badges for child
  fastify.get<{ Params: BadgeParams }>(
    '/earned/:childId',
    {
      preHandler: validateParams(badgeParamsSchema),
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
            message: 'You do not have permission to view this child badges',
          });
        }

        const earnedBadges = await prisma.earnedBadge.findMany({
          where: { childId },
          select: {
            id: true,
            earnedAt: true,
            badge: {
              select: {
                id: true,
                title: true,
                description: true,
                icon: true,
              },
            },
          },
          orderBy: { earnedAt: 'desc' },
        });

        return reply.status(200).send({
          data: earnedBadges.map((eb: typeof earnedBadges[number]) => ({
            id: eb.badge.id,
            title: eb.badge.title,
            description: eb.badge.description,
            icon: eb.badge.icon,
            earnedAt: eb.earnedAt,
          })),
          total: earnedBadges.length,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch earned badges',
        });
      }
    }
  );

  // POST /badges/check/:childId - Check and award new badges
  fastify.post<{ Params: BadgeParams }>(
    '/check/:childId',
    {
      preHandler: validateParams(badgeParamsSchema),
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
            message: 'You do not have permission to check badges for this child',
          });
        }

        // Get badge criteria and child progress
        const allBadges = await prisma.badge.findMany({
          select: {
            id: true,
            title: true,
            criteria: true,
          },
        });

        const earnedBadgeIds = await prisma.earnedBadge.findMany({
          where: { childId },
          select: { badgeId: true },
        });

        const earnedIds = new Set(earnedBadgeIds.map((eb: typeof earnedBadgeIds[number]) => eb.badgeId));

        // Check lesson completion count
        const lessonSessions = await prisma.learningSession.findMany({
          where: { childId },
          select: {
            interactions: {
              select: {
                card: {
                  select: {
                    lesson: {
                      select: { id: true },
                    },
                  },
                },
              },
            },
          },
        });

        const uniqueLessons = new Set<string>();
        for (const session of lessonSessions) {
          for (const interaction of session.interactions) {
            uniqueLessons.add(interaction.card.lesson.id);
          }
        }

        const lessonsCompleted = uniqueLessons.size;

        const newlyEarned: Array<{ id: string; title: string }> = [];

        // Evaluate each badge
        for (const badge of allBadges) {
          if (earnedIds.has(badge.id)) {
            continue; // Already earned
          }

          const criteria = fromJsonColumn<Record<string, unknown>>(badge.criteria);
          let shouldAward = false;

          if (criteria.type === 'lesson_completion') {
            const requiredCount = criteria.count as number;
            if (lessonsCompleted >= requiredCount) {
              shouldAward = true;
            }
          } else if (criteria.type === 'correct_answers') {
            // Would need to count correct answers from interactions
            // For now, simplified logic
            shouldAward = false;
          }

          if (shouldAward) {
            await prisma.earnedBadge.create({
              data: {
                childId,
                badgeId: badge.id,
              },
            });
            newlyEarned.push({
              id: badge.id,
              title: badge.title,
            });
          }
        }

        return reply.status(200).send({
          message: 'Badge check completed',
          newlyEarned,
          newlyEarnedCount: newlyEarned.length,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to check badges',
        });
      }
    }
  );
}
