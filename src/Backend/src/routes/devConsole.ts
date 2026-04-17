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
 *   POST /api/v1/dev/ring-buffers/reset   (dev-only; wipes both buffers)
 *
 * Auth: requires request.userId. In dev mode the auth middleware
 * auto-fills firstUser.id so this works from dev-pipeline.html.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateQuery } from '@middleware/validate';

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
  url: string;
  title: string | null;
  status: string;
  cardCount: number | null;
  costCents: number | null;
  durationMs: number;
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
