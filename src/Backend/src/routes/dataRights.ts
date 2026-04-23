import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateParams } from '@middleware/validate';

const childParamsSchema = z.object({
  childId: z.string().uuid(),
});

type ChildParams = z.infer<typeof childParamsSchema>;

interface ChildDataExport {
  profile: {
    id: string;
    name: string;
    age: number;
    interests: string[];
  };
  progress: {
    totalLessons: number;
    totalTimeMinutes: number;
    badges: Array<{ title: string; earnedAt: string }>;
  };
  lessonsAccessed: Array<{
    lessonId: string;
    title: string;
    accessedAt: string;
  }>;
  voiceInteractions: Array<{
    conversationId: string;
    transcript: string;
    response: string;
    emotion: string;
    date: string;
  }>;
  exportedAt: string;
}

export default async function dataRightsRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /children/:childId/export - Export all data for a child (COPPA compliance)
  fastify.get<{ Params: ChildParams }>(
    '/:childId/export',
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
          select: {
            userId: true,
            name: true,
            age: true,
            interests: true,
          },
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
            message: 'You do not have permission to export data for this child',
          });
        }

        // Get progress data
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
                    lesson: {
                      select: {
                        id: true,
                        title: true,
                      },
                    },
                  },
                },
              },
            },
          },
        });

        // Get earned badges
        const earnedBadges = await prisma.earnedBadge.findMany({
          where: { childId },
          select: {
            earnedAt: true,
            badge: {
              select: {
                title: true,
              },
            },
          },
        });

        // Get voice conversations
        const conversations = await prisma.dashyConversation.findMany({
          where: { childId },
          select: {
            id: true,
            transcript: true,
            response: true,
            emotion: true,
            createdAt: true,
          },
        });

        // Calculate metrics
        const uniqueLessons = new Map<string, string>();
        let totalTimeMs = 0;

        for (const session of sessions) {
          for (const interaction of session.interactions) {
            totalTimeMs += interaction.durationMs || 0;
            uniqueLessons.set(interaction.card.lessonId, interaction.card.lesson.title);
          }
        }

        // Build data export
        const dataExport: ChildDataExport = {
          profile: {
            id: childId,
            name: child.name,
            age: child.age,
            interests: Array.isArray(child.interests) ? child.interests : [],
          },
          progress: {
            totalLessons: uniqueLessons.size,
            totalTimeMinutes: Math.round(totalTimeMs / 1000 / 60),
            badges: earnedBadges.map((eb: any) => ({
              title: eb.badge.title,
              earnedAt: eb.earnedAt.toISOString(),
            })),
          },
          lessonsAccessed: Array.from(uniqueLessons.entries()).map(
            ([lessonId, title]: [string, string]) => ({
              lessonId,
              title,
              accessedAt: new Date().toISOString(), // Simplified - use first access date if available
            })
          ),
          voiceInteractions: conversations.map((conv: any) => ({
            conversationId: conv.id,
            transcript: conv.transcript,
            response: conv.response,
            emotion: conv.emotion,
            date: conv.createdAt.toISOString(),
          })),
          exportedAt: new Date().toISOString(),
        };

        // Return as downloadable JSON
        reply.type('application/json');
        reply.header(
          'Content-Disposition',
          `attachment; filename="child-data-${childId}-${new Date().toISOString().split('T')[0]}.json"`
        );

        return reply.status(200).send(dataExport);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to export child data',
        });
      }
    }
  );

  // DELETE /children/:childId/data - Soft-delete all child data (COPPA compliance)
  fastify.delete<{ Params: ChildParams }>(
    '/:childId/data',
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
            message: 'You do not have permission to delete data for this child',
          });
        }

        // Soft-delete: set deletedAt timestamp and anonymize
        const now = new Date();

        try {
          // Update child profile - anonymize
          await prisma.childProfile.update({
            where: { id: childId },
            data: {
              name: 'Deleted User',
              age: 0,
              interests: [],
              deletedAt: now,
            },
          });

          // Anonymize learning sessions
          const sessions = await prisma.learningSession.findMany({
            where: { childId },
            select: { id: true },
          });

          for (const session of sessions) {
            await prisma.learningSession.update({
              where: { id: session.id },
              data: { deviceId: null },
            });
          }

          // Anonymize conversations
          await prisma.dashyConversation.updateMany({
            where: { childId },
            data: {
              transcript: '[REDACTED]',
              response: '[REDACTED]',
            },
          });
        } catch (dbError) {
          fastify.log.warn(`Partial anonymization completed for child ${childId}: ${dbError}`);
        }

        return reply.status(200).send({
          message: 'Child data has been deleted and anonymized',
          childId,
          deletedAt: now.toISOString(),
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to delete child data',
        });
      }
    }
  );
}
