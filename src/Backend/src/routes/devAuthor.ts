/**
 * Dev Console — Author Lesson SSE route (S12-09).
 *
 * Entry point for bang's "author a lesson from a URL" workflow from the
 * Dev Console. Chains the content scrape + the full pipeline
 * (`runPipeline`) together behind a single Server-Sent Events channel
 * so the browser can render per-stage pills lighting up as the pipeline
 * progresses.
 *
 * Why SSE instead of polling?
 *   - The pipeline takes 15–45s end-to-end. Polling would need tight
 *     intervals to feel live, and every poll costs an auth roundtrip +
 *     a full pipeline-trace deserialization.
 *   - SSE is one-way (server → client) which matches the shape here
 *     exactly — the client fires one POST, then reads events.
 *   - Fastify's `reply.raw` gives direct Node HTTP access without
 *     fighting the framework's JSON-serialization assumptions.
 *   - WebSocket considered and rejected — bidirectional flow isn't
 *     needed, and WS adds deploy complexity behind reverse proxies
 *     that SSE (plain HTTP) sidesteps.
 *
 * Contract:
 *   POST /api/v1/dev/author-lesson
 *     Body: { url, childId, pathId, title?, description? }
 *     Response headers: text/event-stream
 *     Events: one `data: {JSON}\n\n` per PipelineStageEvent plus a final
 *             { stage: 'complete', ... } payload with lesson + path ids.
 *
 * Auth: standard `request.userId` bearer flow — same as every other
 * `/api/v1/dev/*` route.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { randomUUID } from 'crypto';
import { validateBody } from '@middleware/validate';
import { getPrismaClient } from '@db/client';
import {
  runPipeline,
  type PipelineStageEvent,
} from '@services/pipeline/pipelineOrchestrator';

const authorLessonBodySchema = z
  .object({
    /** URL to scrape + analyze + decompose + generate. */
    url: z.string().url(),
    /** Child whose context drives the skill-engine path (age, guidance, session). */
    childId: z.string().uuid(),
    /** Parent-scoped learning path the created lesson attaches to. */
    pathId: z.string().uuid(),
    /** Optional overrides. Omitted → scrape title + analyzer summary used. */
    title: z.string().min(1).max(255).optional(),
    description: z.string().max(1000).optional(),
    /** Skip the quality gate for faster dev iteration. Default false. */
    skipQualityGate: z.boolean().optional().default(false),
  })
  .strict();

type AuthorLessonBody = z.infer<typeof authorLessonBodySchema>;

/**
 * Frame a PipelineStageEvent (or custom event) as an SSE `data:` chunk.
 * Newline-separated to mark end-of-event per spec.
 */
function sseFrame(event: PipelineStageEvent | Record<string, unknown>): string {
  return `data: ${JSON.stringify(event)}\n\n`;
}

export default async function devAuthorRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /dev/author-lesson — SSE-streaming pipeline runner
  fastify.post<{ Body: AuthorLessonBody }>(
    '/author-lesson',
    {
      preHandler: validateBody(authorLessonBodySchema),
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const userId = request.userId;
      const { url, childId, pathId, title, description, skipQualityGate } = request.body;
      const prisma = getPrismaClient() as any;

      // Ownership pre-checks BEFORE opening the SSE channel. If we fail
      // auth after switching to text/event-stream, the browser's
      // EventSource has to reconnect — cleaner to bail with a plain
      // JSON 4xx while we can.
      const [child, path] = await Promise.all([
        prisma.childProfile.findUnique({
          where: { id: childId },
          select: { userId: true },
        }),
        prisma.learningPath.findUnique({
          where: { id: pathId },
          select: { userId: true },
        }),
      ]);

      if (!child || child.userId !== userId) {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Child not owned by caller',
        });
      }
      if (!path || path.userId !== userId) {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Path not owned by caller',
        });
      }

      // Set up SSE headers on the raw Node response. Fastify's reply
      // layer fights `text/event-stream` unless we bypass it via
      // `reply.hijack()` + `reply.raw`. `reply.hijack()` tells Fastify
      // "I'm handling the response myself"; without it, the framework
      // will auto-close the connection on handler return.
      reply.hijack();
      reply.raw.setHeader('Content-Type', 'text/event-stream');
      reply.raw.setHeader('Cache-Control', 'no-cache, no-transform');
      reply.raw.setHeader('Connection', 'keep-alive');
      reply.raw.setHeader('X-Accel-Buffering', 'no'); // defeat nginx buffering
      reply.raw.flushHeaders?.();

      // Seed event — gives the client a confirmed connection + echoes
      // back the path/child ids so the frontend can cross-check.
      reply.raw.write(
        sseFrame({
          stage: 'connection',
          status: 'open',
          childId,
          pathId,
          url,
        })
      );

      // Create the UrlIngest row that `runPipeline` expects. This is
      // the same shape `POST /pipeline/ingest` produces, minus the
      // scrape step — the orchestrator will run the scrape itself and
      // emit the stage event.
      let ingestId: string;
      try {
        const ingest = await prisma.urlIngest.create({
          data: {
            id: randomUUID(),
            userId,
            url,
            status: 'pending',
          },
          select: { id: true },
        });
        ingestId = ingest.id;
        reply.raw.write(
          sseFrame({
            stage: 'ingest',
            status: 'created',
            ingestId,
          })
        );
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        reply.raw.write(
          sseFrame({
            stage: 'ingest',
            status: 'failed',
            error: msg,
          })
        );
        reply.raw.end();
        return;
      }

      // Bridge the orchestrator's stage events into the SSE stream.
      // `emit` inside the orchestrator swallows handler errors so a
      // disconnected client can't crash the pipeline — but we still
      // gate writes on the socket's writable state to avoid the
      // "write after end" warning noise on an aborted connection.
      const onStageEvent = (event: PipelineStageEvent): void => {
        if (!reply.raw.writable) return;
        reply.raw.write(sseFrame(event));
      };

      // Run the full pipeline. Inline any unexpected throw as a final
      // failure event so the client always sees *some* terminal state
      // and can close its EventSource instead of waiting forever.
      try {
        const result = await runPipeline(userId, ingestId, pathId, {
          childId,
          skipQualityGate,
          onStageEvent,
        });

        // Pipeline done — patch title/description overrides if the
        // caller passed them, then emit the final "complete" event with
        // the persisted lesson + card count + path linkage.
        if ((title || description) && result.lessonId) {
          try {
            const updates: Record<string, unknown> = {};
            if (title) updates.title = title;
            if (description) updates.description = description;
            await prisma.lesson.update({
              where: { id: result.lessonId },
              data: updates,
            });
          } catch (updateErr) {
            // Non-fatal — the lesson is already saved with the
            // scraped title + analyzer summary. Log but keep going.
            const msg =
              updateErr instanceof Error ? updateErr.message : String(updateErr);
            console.warn(`[DevAuthor] Title/description override failed: ${msg}`);
          }
        }

        if (reply.raw.writable) {
          reply.raw.write(
            sseFrame({
              stage: 'complete',
              status: 'done',
              lessonId: result.lessonId,
              cardCount: result.cardCount,
              pathId,
              childId,
              skillEngineUsed: result.skillEngineUsed ?? false,
              skillTraces: result.skillTraces?.length ?? 0,
              skillSkippedAtoms: result.skillSkippedAtoms?.length ?? 0,
              qualityScore: result.qualityScore,
            })
          );
        }
      } catch (err) {
        const msg = err instanceof Error ? err.message : String(err);
        if (reply.raw.writable) {
          reply.raw.write(
            sseFrame({
              stage: 'complete',
              status: 'failed',
              error: msg,
            })
          );
        }
        // Don't rethrow — we're past Fastify's error handler boundary
        // (reply.hijack()) so a throw would crash the process.
        console.error(`[DevAuthor] Pipeline failed for ingest ${ingestId}: ${msg}`);
      } finally {
        reply.raw.end();
      }
    }
  );
}
