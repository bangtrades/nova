/**
 * Dev Console support routes (Sprint 10 side-quest — DC-04, Progress Inspector)
 *
 * Powers the "Progress Inspector" and "Engagement/Mastery" tabs on
 * public/dev-pipeline.html. The console needs a *stream* of recent
 * /progress/sync responses to verify engagement + mastery wiring
 * during manual QA, but we don't want to add a new DB table for it.
 *
 * Strategy: in-memory ring buffers, keyed by kind. `recordSyncEvent()`
 * and `recordPipelineEvent()` are called by the existing handlers;
 * these endpoints just read the buffers.
 *
 * Ring buffers are bounded (default 50 entries) and reset on process
 * restart — explicitly *not* a durable audit log. COPPA-wise, they
 * hold whatever the caller is already authorized to see; access still
 * requires an authenticated user and is filtered server-side to that
 * user's own rows (we filter on request.userId, never trust the client).
 *
 * Endpoints:
 *   GET  /api/v1/dev/recent-syncs?childId=<uuid>&limit=<n>
 *   GET  /api/v1/dev/recent-pipeline-runs?limit=<n>
 *   GET  /api/v1/dev/session-context/:childId
 *   GET  /api/v1/dev/teaching-strategy
 *   GET  /api/v1/dev/pipeline/trace/:lessonId   (S10-12 · R7)
 *   POST /api/v1/dev/ring-buffers/reset   (dev-only; wipes both buffers)
 *
 * Auth: requires request.userId. In dev mode the auth middleware
 * auto-fills firstUser.id so this works from dev-pipeline.html.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateQuery, validateParams } from '@middleware/validate';
import { getPrismaClient } from '@db/client';
import { buildSessionContext } from '@services/context/sessionContext';
import { getGuidanceOrDefault } from '@services/guidance/parentGuidance';
import {
  buildParentGuidancePreamble,
  buildSessionContextPreamble,
} from '@services/pipeline/promptTemplates';
import {
  CONCEPT_TYPES,
  LEARNING_MODALITIES,
  getStrategyMatrix,
  rankCardTypesFor,
  inferModality,
  type ConceptType,
  type LearningModality,
} from '@services/skills/teachingStrategy';
import { getEngagementProfile } from '@services/engagement/engagementProfiler';

// -----------------------------------------------------------------------
// Ring-buffer primitive
// -----------------------------------------------------------------------

/** One recorded /progress/sync response, as captured by the handler. */
export interface SyncRingEntry {
  id: string;                     // monotonic per-process counter as string
  recordedAt: string;             // ISO timestamp
  userId: string;                 // caller (used for server-side filtering)
  childId: string;
  deviceId: string | null;
  sessionId: string;
  interactionCount: number;
  masteryUpdates: Array<{
    conceptId: string;
    priorConfidence: number;
    nextConfidence: number;
    attempts: number;
    correctCount: number;
    wasFirstIntroduction: boolean;
  }>;
  engagementDelta: {
    interactionsApplied: number;
    durationAddedMs: number;
    frustrationEventsAdded: number;
    flowEventsAdded: number;
    finalStreak: number;
    // ProfileDelta tracks the new longest-streak length (0 when unchanged),
    // not a boolean — keep the type in sync with engagementProfiler.ts.
    newLongestStreak: number;
  } | null;
  newlyEarnedBadgeCount: number;
  durationMs: number;             // wall time the handler took
}

/** One recorded pipeline run, as captured by the pipeline handler. */
export interface PipelineRingEntry {
  id: string;
  recordedAt: string;
  userId: string;
  ingestId: string;
  /**
   * Populated only on successful runs. Null for the `status: 'failed'`
   * path (the orchestrator never got to the point of creating a
   * Lesson). S10-12 · R7 — lets the Dev Console deep-link to
   * `/dev/pipeline/trace/:lessonId`.
   */
  lessonId: string | null;
  url: string;
  title: string | null;
  status: string;
  cardCount: number | null;
  costCents: number | null;
  durationMs: number;
  /**
   * True when Stage 4 went through the skill engine (story-writer /
   * quiz-maker). S10-12 · R7 — used to show a badge in the recent-runs
   * list so operators can tell at a glance whether a run exercised
   * skills or fell back to the legacy path.
   */
  skillEngineUsed: boolean;
}

const RING_MAX_DEFAULT = 50;

class RingBuffer<T extends { id: string }> {
  private buf: T[] = [];
  private seq = 0;
  constructor(private readonly max: number = RING_MAX_DEFAULT) {}

  push(entry: Omit<T, 'id'>): T {
    this.seq += 1;
    const withId = { ...entry, id: String(this.seq) } as T;
    this.buf.push(withId);
    if (this.buf.length > this.max) {
      this.buf.splice(0, this.buf.length - this.max);
    }
    return withId;
  }

  /** Most-recent-first snapshot. */
  snapshot(): T[] {
    return this.buf.slice().reverse();
  }

  reset(): void {
    this.buf = [];
    this.seq = 0;
  }

  get size(): number {
    return this.buf.length;
  }
}

const syncRing = new RingBuffer<SyncRingEntry>(RING_MAX_DEFAULT);
const pipelineRing = new RingBuffer<PipelineRingEntry>(RING_MAX_DEFAULT);

// -----------------------------------------------------------------------
// Public recorders — called from the handlers that produce these events.
// Keeping them exported (rather than route-local) lets progress.ts and
// pipeline.ts push into the same buffer that devConsoleRoutes reads.
// -----------------------------------------------------------------------

export function recordSyncEvent(entry: Omit<SyncRingEntry, 'id' | 'recordedAt'>): SyncRingEntry {
  return syncRing.push({ ...entry, recordedAt: new Date().toISOString() } as Omit<
    SyncRingEntry,
    'id'
  >);
}

export function recordPipelineEvent(
  entry: Omit<PipelineRingEntry, 'id' | 'recordedAt'>
): PipelineRingEntry {
  return pipelineRing.push({ ...entry, recordedAt: new Date().toISOString() } as Omit<
    PipelineRingEntry,
    'id'
  >);
}

/** Test-only helper — clears both rings. */
export function __resetRingBuffersForTests(): void {
  syncRing.reset();
  pipelineRing.reset();
}

// -----------------------------------------------------------------------
// Schemas
// -----------------------------------------------------------------------

const recentSyncsQuerySchema = z.object({
  childId: z.string().uuid().optional(),
  limit: z.string().pipe(z.coerce.number().int().min(1).max(200)).default('50'),
});
const recentPipelineQuerySchema = z.object({
  limit: z.string().pipe(z.coerce.number().int().min(1).max(200)).default('50'),
});

type RecentSyncsQuery = z.infer<typeof recentSyncsQuerySchema>;
type RecentPipelineQuery = z.infer<typeof recentPipelineQuerySchema>;

// -----------------------------------------------------------------------
// Routes
// -----------------------------------------------------------------------

export async function devConsoleRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /dev/recent-syncs
  fastify.get<{ Querystring: RecentSyncsQuery }>(
    '/recent-syncs',
    { preHandler: validateQuery(recentSyncsQuerySchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId, limit } = request.query as unknown as RecentSyncsQuery;

      // Snapshot, filter to caller's own rows, optionally by childId, then cap.
      const rows = syncRing
        .snapshot()
        .filter((e) => e.userId === request.userId)
        .filter((e) => (childId ? e.childId === childId : true))
        .slice(0, limit);

      return reply.status(200).send({
        data: rows,
        count: rows.length,
        bufferSize: syncRing.size,
        bufferMax: RING_MAX_DEFAULT,
      });
    }
  );

  // GET /dev/recent-pipeline-runs
  fastify.get<{ Querystring: RecentPipelineQuery }>(
    '/recent-pipeline-runs',
    { preHandler: validateQuery(recentPipelineQuerySchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { limit } = request.query as unknown as RecentPipelineQuery;

      const rows = pipelineRing
        .snapshot()
        .filter((e) => e.userId === request.userId)
        .slice(0, limit);

      return reply.status(200).send({
        data: rows,
        count: rows.length,
        bufferSize: pipelineRing.size,
        bufferMax: RING_MAX_DEFAULT,
      });
    }
  );

  // GET /dev/session-context/:childId — live diagnostic view of the
  // SessionContext + Guidance that the pipeline prompts would see right now.
  // Lets us verify DST / timezone behavior and guidance wiring from the browser
  // without spinning up a full pipeline run.
  fastify.get<{ Params: { childId: string } }>(
    '/session-context/:childId',
    {
      preHandler: validateParams(z.object({ childId: z.string().uuid() })),
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const prisma = getPrismaClient();
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
          message: 'You do not have permission to access this child profile',
        });
      }

      try {
        const [sessionContext, guidance] = await Promise.all([
          buildSessionContext(childId),
          getGuidanceOrDefault(childId),
        ]);
        const preamble =
          buildParentGuidancePreamble(guidance) +
          buildSessionContextPreamble(sessionContext);
        return reply.status(200).send({
          data: {
            sessionContext,
            guidance,
            preamble,
            preambleChars: preamble.length,
          },
        });
      } catch (err) {
        fastify.log.error({ err }, 'session-context diagnostic failed');
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: err instanceof Error ? err.message : 'Unknown',
        });
      }
    }
  );

  // GET /dev/teaching-strategy — S10-11 introspection surface.
  //
  // Without ?childId, returns the raw 6×3 matrix (neutral ranker output
  // per cell). With ?childId, layers the child's engagement + age
  // + inferred modality on top so the operator can see the actual
  // ranking the pipeline would use for that child.
  //
  // Optional query params for the Dev Console sandbox:
  //   conceptType, modality  — override the focus cell
  //   difficultyOffset       — override the difficulty layer
  //   ageYears               — override age gate
  //   engagementOverride=<type>  — pretend the top engagement is this card type
  fastify.get<{
    Querystring: {
      childId?: string;
      conceptType?: string;
      modality?: string;
      difficultyOffset?: string;
      ageYears?: string;
      engagementOverride?: string;
    };
  }>(
    '/teaching-strategy',
    {
      preHandler: validateQuery(
        z.object({
          childId: z.string().uuid().optional(),
          conceptType: z.string().optional(),
          modality: z.enum(['visual', 'auditory', 'kinesthetic']).optional(),
          difficultyOffset: z
            .string()
            .pipe(z.coerce.number().int().min(-2).max(2))
            .optional(),
          ageYears: z.string().pipe(z.coerce.number().int().min(2).max(18)).optional(),
          engagementOverride: z
            .enum(['story', 'concept', 'experiment', 'quiz', 'voice'])
            .optional(),
        })
      ),
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const q = request.query as {
        childId?: string;
        conceptType?: string;
        modality?: LearningModality;
        difficultyOffset?: number;
        ageYears?: number;
        engagementOverride?: 'story' | 'concept' | 'experiment' | 'quiz' | 'voice';
      };

      // Base matrix — always returned for rendering the grid.
      const matrix = getStrategyMatrix();

      // Gather child-scoped signals if a valid childId was passed.
      let childContext:
        | {
            childId: string;
            ageYears?: number;
            inferredModality: LearningModality;
            engagement: Array<{ type: string; score: number; completionRate: number }>;
          }
        | null = null;

      if (q.childId) {
        const prisma = getPrismaClient();
        const child = await prisma.childProfile.findUnique({
          where: { id: q.childId },
          select: { userId: true, birthDate: true },
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
            message: 'You do not have permission to access this child profile',
          });
        }

        const profile = await getEngagementProfile(q.childId);
        const engagement = profile?.cardTypePreferences ?? [];
        const ageYears =
          child.birthDate instanceof Date
            ? Math.floor(
                (Date.now() - child.birthDate.getTime()) / (365.25 * 24 * 60 * 60 * 1000)
              )
            : undefined;
        childContext = {
          childId: q.childId,
          ageYears,
          inferredModality: inferModality(engagement),
          engagement: engagement.map((e) => ({
            type: e.type,
            score: e.score,
            completionRate: e.completionRate,
          })),
        };
      }

      // Resolve the focus cell (what the UI is asking to preview).
      const conceptType: ConceptType =
        (q.conceptType as ConceptType) &&
        (CONCEPT_TYPES as readonly string[]).includes(q.conceptType as string)
          ? (q.conceptType as ConceptType)
          : 'vocabulary';
      const modality: LearningModality =
        q.modality ?? childContext?.inferredModality ?? 'visual';

      // Build a synthetic engagement array if the operator overrode it.
      const syntheticEngagement =
        q.engagementOverride !== undefined
          ? [
              {
                type: q.engagementOverride,
                count: 10,
                totalDurationMs: 60_000,
                completionRate: 0.8,
                avgDurationMs: 6_000,
                score: 2,
              },
            ]
          : undefined;

      const engagementForRanker =
        syntheticEngagement ??
        (childContext
          ? childContext.engagement.map((e) => ({
              type: e.type as 'story' | 'concept' | 'experiment' | 'quiz' | 'voice',
              count: 1,
              totalDurationMs: 1,
              completionRate: e.completionRate,
              avgDurationMs: 1,
              score: e.score,
            }))
          : undefined);

      const focusRanking = rankCardTypesFor(conceptType, modality, {
        engagement: engagementForRanker,
        difficultyOffset: q.difficultyOffset,
        ageYears: q.ageYears ?? childContext?.ageYears,
      });

      return reply.status(200).send({
        data: {
          matrix,
          conceptTypes: CONCEPT_TYPES,
          modalities: LEARNING_MODALITIES,
          focus: {
            conceptType,
            modality,
            difficultyOffset: q.difficultyOffset ?? 0,
            ageYears: q.ageYears ?? childContext?.ageYears ?? null,
            engagementOverride: q.engagementOverride ?? null,
            ranking: focusRanking,
          },
          childContext,
        },
      });
    }
  );

  // GET /dev/pipeline/trace/:lessonId — S10-12 · R7
  //
  // Returns the per-atom skill-engine trace for a completed lesson. The
  // trace was stashed on `Lesson.aiAnalysis.skillEngine` during Stage
  // 4 persistence (see pipelineOrchestrator R5 edit). When the skill
  // engine didn't run for this lesson (flag off, no childId, or pre-
  // S10-12 lesson) the response still returns 200 with
  // `skillEngine: null` so the UI can render an informative empty state
  // instead of a raw 404.
  //
  // Auth: requires request.userId. Returns 403 if the lesson belongs
  // to a different user — we never leak cross-user data.
  fastify.get<{ Params: { lessonId: string } }>(
    '/pipeline/trace/:lessonId',
    {
      preHandler: validateParams(z.object({ lessonId: z.string().uuid() })),
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { lessonId } = request.params;
      const prisma = getPrismaClient();
      const lesson = await prisma.lesson.findUnique({
        where: { id: lessonId },
        select: {
          id: true,
          userId: true,
          title: true,
          status: true,
          aiAnalysis: true,
          createdAt: true,
        },
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
          message: 'You do not have permission to view this lesson trace',
        });
      }

      // aiAnalysis is a JSON blob stored as a string (SQLite compat).
      let parsed: Record<string, unknown> | null = null;
      let parseError: string | null = null;
      if (lesson.aiAnalysis) {
        try {
          parsed =
            typeof lesson.aiAnalysis === 'string'
              ? (JSON.parse(lesson.aiAnalysis) as Record<string, unknown>)
              : (lesson.aiAnalysis as unknown as Record<string, unknown>);
        } catch (err) {
          parseError = err instanceof Error ? err.message : 'Unknown parse error';
        }
      }

      const skillEngine = parsed && 'skillEngine' in parsed ? parsed.skillEngine : null;
      const decomposition = parsed && 'decomposition' in parsed ? parsed.decomposition : null;

      return reply.status(200).send({
        data: {
          lessonId: lesson.id,
          title: lesson.title,
          status: lesson.status,
          createdAt: lesson.createdAt.toISOString(),
          skillEngine,
          /**
           * The decomposition is useful for the UI to cross-reference
           * each trace row against the atom's recommendedCardType /
           * teachingStrategy. Cheap to include here and saves a second
           * round-trip.
           */
          decomposition,
          parseError,
        },
      });
    }
  );

  // POST /dev/ring-buffers/reset — wipes both buffers. Useful when
  // driving end-to-end scenarios from the dev console and wanting a
  // clean starting state. Scoped to authenticated users only; still
  // harmless because these are in-memory.
  fastify.post('/ring-buffers/reset', async (request, reply) => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }
    syncRing.reset();
    pipelineRing.reset();
    return reply.status(200).send({
      data: { reset: true, timestamp: new Date().toISOString() },
    });
  });
}

// -----------------------------------------------------------------------
// Exports for unit testing / debugging
// -----------------------------------------------------------------------

export const __ringBuffersForTests = { syncRing, pipelineRing };
export default devConsoleRoutes;
