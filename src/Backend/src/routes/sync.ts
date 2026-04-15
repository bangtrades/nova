/**
 * Sync Endpoint
 *
 * Efficient sync of lessons and cards updated since a given timestamp.
 * Supports pagination and 304 Not Modified responses.
 */

import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateQuery } from '@middleware/validate';

const syncQuerySchema = z.object({
  since: z.string().datetime().optional(),
  limit: z.string().pipe(z.coerce.number().int().min(1).max(500)).default('100'),
  offset: z.string().pipe(z.coerce.number().int().min(0)).default('0'),
});

type SyncQuery = z.infer<typeof syncQuerySchema>;

export interface SyncedLesson {
  id: string;
  title: string;
  description?: string;
  difficulty: number;
  sourceUrl?: string;
  publishedAt?: string;
  updatedAt: string;
  cards: Array<{
    id: string;
    type: string;
    content: Record<string, unknown>;
    voiceScript?: string;
    sortOrder: number;
  }>;
}

export interface SyncedPath {
  id: string;
  title: string;
  description?: string;
  stage: number;
  sortOrder: number;
  updatedAt: string;
}

export interface SyncResponse {
  lessons: SyncedLesson[];
  paths: SyncedPath[];
  syncedAt: string;
  hasMore: boolean;
  offset: number;
  limit: number;
  total: number;
}

export async function syncRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /sync - Sync lessons and paths updated since timestamp
  fastify.get<{ Querystring: SyncQuery }>(
    '/',
    {
      preHandler: validateQuery(syncQuerySchema),
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

        const { since, limit, offset } = request.query as unknown as SyncQuery;
        const prisma = getPrismaClient();

        // If no 'since' provided, use start of time
        const sinceDatetime = since ? new Date(since) : new Date(0);

        // Get updated lessons for this user
        const [lessons, lessonCount] = await Promise.all([
          prisma.lesson.findMany({
            where: {
              userId: request.userId,
              updatedAt: {
                gte: sinceDatetime,
              },
            },
            select: {
              id: true,
              title: true,
              description: true,
              difficulty: true,
              sourceUrl: true,
              publishedAt: true,
              updatedAt: true,
              cards: {
                select: {
                  id: true,
                  type: true,
                  content: true,
                  voiceScript: true,
                  sortOrder: true,
                },
                orderBy: { sortOrder: 'asc' },
              },
            },
            orderBy: { updatedAt: 'desc' },
            skip: offset,
            take: limit,
          }),
          prisma.lesson.count({
            where: {
              userId: request.userId,
              updatedAt: {
                gte: sinceDatetime,
              },
            },
          }),
        ]);

        // Get updated paths for this user
        const [paths, pathCount] = await Promise.all([
          prisma.learningPath.findMany({
            where: {
              userId: request.userId,
              updatedAt: {
                gte: sinceDatetime,
              },
            },
            select: {
              id: true,
              title: true,
              description: true,
              stage: true,
              sortOrder: true,
              updatedAt: true,
            },
            orderBy: { updatedAt: 'desc' },
            skip: offset,
            take: limit,
          }),
          prisma.learningPath.count({
            where: {
              userId: request.userId,
              updatedAt: {
                gte: sinceDatetime,
              },
            },
          }),
        ]);

        // Check if there are more results
        const totalCount = Math.max(lessonCount, pathCount);
        const hasMore = offset + limit < totalCount;

        const syncedAt = new Date().toISOString();

        // If no changes since the provided timestamp, return 304
        if (offset === 0 && lessons.length === 0 && paths.length === 0 && since) {
          return reply.status(304).send();
        }

        // Return sync response
        return reply.status(200).send({
          lessons: lessons.map((lesson: any) => ({
            id: lesson.id,
            title: lesson.title,
            description: lesson.description || undefined,
            difficulty: lesson.difficulty,
            sourceUrl: lesson.sourceUrl || undefined,
            publishedAt: lesson.publishedAt?.toISOString(),
            updatedAt: lesson.updatedAt.toISOString(),
            cards: lesson.cards.map((card: any) => ({
              id: card.id,
              type: card.type,
              content: card.content as Record<string, unknown>,
              voiceScript: card.voiceScript || undefined,
              sortOrder: card.sortOrder,
            })),
          })),
          paths: paths.map((path: any) => ({
            id: path.id,
            title: path.title,
            description: path.description || undefined,
            stage: path.stage,
            sortOrder: path.sortOrder,
            updatedAt: path.updatedAt.toISOString(),
          })),
          syncedAt,
          hasMore,
          offset,
          limit,
          total: totalCount,
        } as SyncResponse);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to sync data',
        });
      }
    }
  );
}
