import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateBody, validateParams, validateQuery } from '@middleware/validate';
import { runPipeline } from '@services/pipeline/pipelineOrchestrator';
import { scrapeUrl } from '@services/pipeline/scraper';

const ingestUrlSchema = z.object({
  url: z.string().url(),
});

const generateCardsSchema = z.object({
  ingestId: z.string().uuid(),
  pathId: z.string().uuid().optional(),
});

const assetJobParamsSchema = z.object({
  lessonId: z.string().uuid(),
});

const ingestParamsSchema = z.object({
  id: z.string().uuid(),
});

const statusParamsSchema = z.object({
  ingestId: z.string().uuid(),
});

type IngestUrlRequest = z.infer<typeof ingestUrlSchema>;
type GenerateCardsRequest = z.infer<typeof generateCardsSchema>;
type AssetJobParams = z.infer<typeof assetJobParamsSchema>;
type IngestParams = z.infer<typeof ingestParamsSchema>;
type StatusParams = z.infer<typeof statusParamsSchema>;

export async function pipelineRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /pipeline/ingest - Ingest and scrape URL
  fastify.post<{ Body: IngestUrlRequest }>(
    '/ingest',
    {
      preHandler: validateBody(ingestUrlSchema),
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

        const { url } = request.body;
        const prisma = getPrismaClient();

        // Create URL ingest record
        const ingest = await prisma.urlIngest.create({
          data: {
            userId: request.userId,
            url,
            status: 'pending',
          },
          select: {
            id: true,
            url: true,
            status: true,
            createdAt: true,
          },
        });

        // Attempt to scrape immediately
        try {
          const scraped = await scrapeUrl(url);

          // Update ingest with raw content
          const updated = await prisma.urlIngest.update({
            where: { id: ingest.id },
            data: {
              rawContent: scraped.content,
              status: 'scraped',
            },
            select: {
              id: true,
              url: true,
              status: true,
              rawContent: true,
              createdAt: true,
              updatedAt: true,
            },
          });

          return reply.status(201).send(updated);
        } catch (scrapeError) {
          // If scraping fails, return the ingest record anyway
          fastify.log.warn(`Scrape failed: ${scrapeError}`);

          return reply.status(201).send({
            ...ingest,
            status: 'failed',
            error: scrapeError instanceof Error ? scrapeError.message : 'Scrape failed',
          });
        }
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to ingest URL',
        });
      }
    }
  );

  // GET /pipeline/ingest/:id - Get ingest status and analysis
  fastify.get<{ Params: IngestParams }>(
    '/ingest/:id',
    {
      preHandler: validateParams(ingestParamsSchema),
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

        const { id } = request.params;
        const prisma = getPrismaClient();

        const ingest = await prisma.urlIngest.findUnique({
          where: { id },
          select: {
            id: true,
            userId: true,
            url: true,
            rawContent: true,
            aiAnalysis: true,
            status: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        if (!ingest) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Ingest not found',
          });
        }

        if (ingest.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view this ingest',
          });
        }

        const { userId: _, ...ingestData } = ingest;
        return reply.status(200).send(ingestData);
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch ingest status',
        });
      }
    }
  );

  // POST /pipeline/generate - Run full pipeline from ingest to lesson
  fastify.post<{ Body: GenerateCardsRequest }>(
    '/generate',
    {
      preHandler: validateBody(generateCardsSchema),
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

        const { ingestId, pathId } = request.body;
        const prisma = getPrismaClient();

        // Verify ingest ownership
        const ingest = await prisma.urlIngest.findUnique({
          where: { id: ingestId },
          select: { userId: true },
        });

        if (!ingest) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Ingest not found',
          });
        }

        if (ingest.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to generate from this ingest',
          });
        }

        // Run the full pipeline
        try {
          const result = await runPipeline(request.userId, ingestId, pathId);

          return reply.status(200).send({
            ingestId: result.ingestId,
            lessonId: result.lessonId,
            cardCount: result.cardCount,
            status: result.status,
            message: result.message,
          });
        } catch (pipelineError) {
          fastify.log.error(`Pipeline error: ${pipelineError}`);
          return reply.status(400).send({
            statusCode: 400,
            error: 'Pipeline Error',
            message: pipelineError instanceof Error ? pipelineError.message : 'Pipeline execution failed',
          });
        }
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to generate cards',
        });
      }
    }
  );

  // POST /pipeline/assets/:lessonId - Trigger asset generation
  fastify.post<{ Params: AssetJobParams }>(
    '/assets/:lessonId',
    {
      preHandler: validateParams(assetJobParamsSchema),
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

        const { lessonId } = request.params;
        const prisma = getPrismaClient();
        const config = await import('@config').then((m) => m.getConfig());

        // Verify lesson ownership
        const lesson = await prisma.lesson.findUnique({
          where: { id: lessonId },
          select: { userId: true },
        });

        if (!lesson) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Lesson not found',
          });
        }

        if (lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to generate assets for this lesson',
          });
        }

        // Get user's OpenAI API key
        const user = await prisma.user.findUnique({
          where: { id: request.userId },
          include: {
            llmProviders: {
              where: { provider: 'openai', status: 'active' },
            },
          },
        });

        if (!user || !user.llmProviders || user.llmProviders.length === 0) {
          // Use proxy key if available
          if (!config.OPENAI_API_KEY) {
            return reply.status(400).send({
              statusCode: 400,
              error: 'Bad Request',
              message: 'OpenAI API key is required to generate assets',
            });
          }
        }

        // Import asset processor
        const { processLessonAssets } = await import('@services/assets/assetJobProcessor');

        // Process assets asynchronously (fire and forget)
        const apiKey = config.OPENAI_API_KEY || '';
        processLessonAssets(lessonId, apiKey)
          .then(() => {
            fastify.log.info(`Asset generation completed for lesson ${lessonId}`);
          })
          .catch((error) => {
            fastify.log.error(`Asset generation failed for lesson ${lessonId}: ${error}`);
          });

        // Return status immediately
        const status = await import('@services/assets/assetJobProcessor').then((m) =>
          m.getAssetJobStatus(lessonId)
        );

        return reply.status(202).send({
          lessonId,
          status: 'processing',
          ...status,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to trigger asset generation',
        });
      }
    }
  );

  // GET /pipeline/assets/:lessonId/status - Get asset generation status
  fastify.get<{ Params: AssetJobParams }>(
    '/assets/:lessonId/status',
    {
      preHandler: validateParams(assetJobParamsSchema),
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

        const { lessonId } = request.params;
        const prisma = getPrismaClient();

        // Verify lesson ownership
        const lesson = await prisma.lesson.findUnique({
          where: { id: lessonId },
          select: { userId: true },
        });

        if (!lesson) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Lesson not found',
          });
        }

        if (lesson.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view asset status for this lesson',
          });
        }

        // Get asset job status
        const { getAssetJobStatus } = await import('@services/assets/assetJobProcessor');
        const status = await getAssetJobStatus(lessonId);

        return reply.status(200).send({
          lessonId,
          ...status,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch asset status',
        });
      }
    }
  );

  // GET /pipeline/status/:ingestId - Get pipeline status
  fastify.get<{ Params: StatusParams }>(
    '/status/:ingestId',
    {
      preHandler: validateParams(statusParamsSchema),
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

        const { ingestId } = request.params;
        const prisma = getPrismaClient();

        const ingest = await prisma.urlIngest.findUnique({
          where: { id: ingestId },
          select: {
            userId: true,
            status: true,
            rawContent: true,
            aiAnalysis: true,
            createdAt: true,
            updatedAt: true,
          },
        });

        if (!ingest) {
          return reply.status(404).send({
            statusCode: 404,
            error: 'Not Found',
            message: 'Ingest not found',
          });
        }

        if (ingest.userId !== request.userId) {
          return reply.status(403).send({
            statusCode: 403,
            error: 'Forbidden',
            message: 'You do not have permission to view this ingest status',
          });
        }

        // Map status to step progress
        const statusMap: Record<string, { step: number; completed: string[] }> = {
          pending: { step: 0, completed: [] },
          scraped: { step: 1, completed: ['scrape'] },
          analyzing: { step: 2, completed: ['scrape', 'analyze'] },
          generating: { step: 3, completed: ['scrape', 'analyze', 'generate'] },
          completed: { step: 4, completed: ['scrape', 'analyze', 'generate', 'save'] },
          failed: { step: 0, completed: [] },
        };

        const statusInfo = statusMap[ingest.status] || statusMap.pending;

        return reply.status(200).send({
          ingestId,
          status: ingest.status,
          progress: statusInfo.step,
          completedSteps: statusInfo.completed,
          hasRawContent: !!ingest.rawContent,
          hasAnalysis: !!ingest.aiAnalysis,
          createdAt: ingest.createdAt,
          updatedAt: ingest.updatedAt,
        });
      } catch (error) {
        fastify.log.error(error);
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'Failed to fetch pipeline status',
        });
      }
    }
  );
}
