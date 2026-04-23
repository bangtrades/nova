/**
 * S12-09 · R4 — Dev Console Author Lesson SSE route tests.
 *
 * The devAuthor route chains `scrape → runPipeline → stream SSE` and
 * is the heart of bang's new content-authoring loop. We can't cheaply
 * spin up a full pipeline-with-mocked-LLM for every test, so this
 * suite deliberately focuses on the *control-flow* surface: Zod
 * validation, ownership checks, SSE header shape, connection seeding.
 * The full pipeline integration (scrape + analyze + decompose + ...)
 * is the Mac-side regression bang walks through in S12-09 R5.
 *
 * Why not mock the entire pipeline? Doing so would require stubbing
 * scraper + LLM + prisma create calls across 5 stages, and the test
 * would mostly be "did my mock match the orchestrator's expectations"
 * rather than "does the route behave correctly". The pieces the
 * orchestrator owns (per-stage emission order, Zod-retry, legacy
 * fallback) already have first-class tests under
 * `decompositionRouter.test.ts`, `voicePersonaRouter.test.ts`, etc.
 * The devAuthor-specific risks are concentrated in the glue layer
 * around `reply.hijack()` + SSE framing + ownership — which is what
 * this file asserts.
 */
import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer, generateTestToken, TEST_USER_ID } from './setup';
import { getPrismaClient } from '@db/client';
import { randomUUID } from 'crypto';

// ---------------------------------------------------------------------------
// Mock `runPipeline` so we don't accidentally hit the real LLM chain.
// Each test queues a specific behavior (happy / throw).
// ---------------------------------------------------------------------------
const mockRunPipeline = vi.fn();
vi.mock('@services/pipeline/pipelineOrchestrator', async () => {
  // Preserve the real `PipelineStageEvent` type export for callers that
  // import it; only stub `runPipeline` itself.
  const actual = await vi.importActual<
    typeof import('@services/pipeline/pipelineOrchestrator')
  >('@services/pipeline/pipelineOrchestrator');
  return {
    ...actual,
    runPipeline: (...args: unknown[]) => mockRunPipeline(...args),
  };
});

let server: FastifyInstance;
let otherUserToken: string;
let ownerUserId: string;
let ownerToken: string;
let ownedChildId: string;
let ownedPathId: string;
let otherUsersChildId: string;
let otherUsersPathId: string;

beforeAll(async () => {
  server = await createTestServer();
  const prisma = getPrismaClient() as any;

  // Owner user + owned child + owned path
  ownerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: ownerUserId,
      email: `owner-${ownerUserId}@test.local`,
      displayName: 'Owner',
    },
  });
  ownerToken = generateTestToken(ownerUserId);

  const child = await prisma.childProfile.create({
    data: {
      userId: ownerUserId,
      name: 'Kiddo',
      birthDate: new Date('2020-01-01'),
      currentStage: 2,
      ianaTimezone: 'America/Los_Angeles',
    },
  });
  ownedChildId = child.id;

  const path = await prisma.learningPath.create({
    data: {
      userId: ownerUserId,
      title: 'Science stage 1',
      icon: '🔬',
    },
  });
  ownedPathId = path.id;

  // A second user with their own child + path — used to verify
  // cross-user ownership checks reject access.
  const strangerUserId = randomUUID();
  await prisma.user.create({
    data: {
      id: strangerUserId,
      email: `stranger-${strangerUserId}@test.local`,
      displayName: 'Stranger',
    },
  });
  otherUserToken = generateTestToken(strangerUserId);

  const strangerChild = await prisma.childProfile.create({
    data: {
      userId: strangerUserId,
      name: 'NotYourKid',
      birthDate: new Date('2019-01-01'),
      currentStage: 1,
      ianaTimezone: 'UTC',
    },
  });
  otherUsersChildId = strangerChild.id;

  const strangerPath = await prisma.learningPath.create({
    data: {
      userId: strangerUserId,
      title: "Stranger's Path",
    },
  });
  otherUsersPathId = strangerPath.id;
});

afterAll(async () => {
  await server.close();
});

// ---------------------------------------------------------------------------
// 1. Zod body validation
// ---------------------------------------------------------------------------

describe('POST /api/v1/dev/author-lesson — body validation', () => {
  it('returns 400 when URL is missing', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        childId: ownedChildId,
        pathId: ownedPathId,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('returns 400 when URL is malformed', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'not-a-url',
        childId: ownedChildId,
        pathId: ownedPathId,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('returns 400 when childId is not a UUID', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/x',
        childId: 'nope',
        pathId: ownedPathId,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('returns 400 when pathId is missing', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/x',
        childId: ownedChildId,
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('returns 400 on unknown body field (strict mode)', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/x',
        childId: ownedChildId,
        pathId: ownedPathId,
        hackField: 'should reject',
      },
    });
    expect(res.statusCode).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// 2. Auth + ownership checks
// ---------------------------------------------------------------------------

describe('POST /api/v1/dev/author-lesson — auth + ownership', () => {
  it('returns 401 with no bearer token', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      payload: {
        url: 'https://example.com/x',
        childId: ownedChildId,
        pathId: ownedPathId,
      },
    });
    expect(res.statusCode).toBe(401);
  });

  it('returns 403 when the caller does not own the child', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/x',
        childId: otherUsersChildId, // owned by stranger, not owner
        pathId: ownedPathId,
      },
    });
    expect(res.statusCode).toBe(403);
    const body = res.json();
    expect(body.message).toMatch(/child/i);
  });

  it('returns 403 when the caller does not own the path', async () => {
    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/x',
        childId: ownedChildId,
        pathId: otherUsersPathId,
      },
    });
    expect(res.statusCode).toBe(403);
    const body = res.json();
    expect(body.message).toMatch(/path/i);
  });
});

// ---------------------------------------------------------------------------
// 3. SSE stream — headers, framing, connection seed event
// ---------------------------------------------------------------------------

describe('POST /api/v1/dev/author-lesson — SSE stream', () => {
  it('happy path: opens SSE, emits connection + ingest + pipeline events, ends with complete:done', async () => {
    // Stub the orchestrator with a synchronous "successful run" that
    // fires one representative event per stage via the onStageEvent
    // callback and then returns a fake PipelineResult.
    mockRunPipeline.mockImplementationOnce(async (_userId, ingestId, pathId, opts) => {
      const emit = opts.onStageEvent;
      if (emit) {
        emit({ stage: 'scrape', status: 'start' });
        emit({ stage: 'scrape', status: 'done', bytes: 1234, title: 'Photosynthesis' });
        emit({ stage: 'analyze', status: 'start' });
        emit({
          stage: 'analyze',
          status: 'done',
          topic: 'Photosynthesis',
          ageAppropriate: true,
          suggestedStage: 2,
        });
        emit({ stage: 'decompose', status: 'start', source: 'skill-engine' });
        emit({
          stage: 'decompose',
          status: 'done',
          source: 'skill-engine',
          atomCount: 4,
          validatorStatus: 'ok',
          retryCount: 0,
        });
        emit({ stage: 'generate', status: 'start', source: 'skill-engine', atomCount: 4 });
        emit({
          stage: 'generate',
          status: 'done',
          source: 'skill-engine',
          cardCount: 4,
          skippedCount: 0,
          retryOkCount: 1,
          retryFailedCount: 0,
        });
        emit({ stage: 'persist', status: 'start' });
        emit({
          stage: 'persist',
          status: 'done',
          lessonId: 'fake-lesson-id',
          cardCount: 4,
        });
      }
      return {
        ingestId,
        lessonId: 'fake-lesson-id',
        cardCount: 4,
        status: 'completed' as const,
        message: 'ok',
        skillEngineUsed: true,
        skillTraces: [],
      };
    });

    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/photosynthesis',
        childId: ownedChildId,
        pathId: ownedPathId,
      },
    });

    expect(res.statusCode).toBe(200);
    expect(res.headers['content-type']).toMatch(/text\/event-stream/);
    expect(res.headers['cache-control']).toMatch(/no-cache/);

    const body = res.body;
    // SSE frames are `data: <json>\n\n` — split + parse to validate shape
    const frames = body
      .split('\n\n')
      .filter((f) => f.trim().startsWith('data:'))
      .map((f) => JSON.parse(f.trim().slice(5).trim()));

    // Connection seed comes first
    expect(frames[0]).toMatchObject({ stage: 'connection', status: 'open' });
    expect(frames[0].childId).toBe(ownedChildId);
    expect(frames[0].pathId).toBe(ownedPathId);

    // Ingest row created before the pipeline kicks off
    const ingestFrame = frames.find((f) => f.stage === 'ingest');
    expect(ingestFrame).toBeDefined();
    expect(ingestFrame.status).toBe('created');
    expect(typeof ingestFrame.ingestId).toBe('string');

    // All major stages represented
    const stages = frames.map((f) => f.stage);
    expect(stages).toContain('scrape');
    expect(stages).toContain('analyze');
    expect(stages).toContain('decompose');
    expect(stages).toContain('generate');
    expect(stages).toContain('persist');

    // Final terminal event
    const complete = frames[frames.length - 1];
    expect(complete).toMatchObject({
      stage: 'complete',
      status: 'done',
      lessonId: 'fake-lesson-id',
      cardCount: 4,
      pathId: ownedPathId,
      childId: ownedChildId,
      skillEngineUsed: true,
    });
  });

  it('emits complete:failed when the orchestrator throws', async () => {
    mockRunPipeline.mockImplementationOnce(async () => {
      throw new Error('Scrape failed: robots.txt disallowed');
    });

    const res = await server.inject({
      method: 'POST',
      url: '/api/v1/dev/author-lesson',
      headers: { Authorization: `Bearer ${ownerToken}` },
      payload: {
        url: 'https://example.com/blocked',
        childId: ownedChildId,
        pathId: ownedPathId,
      },
    });

    expect(res.statusCode).toBe(200); // SSE was already open, terminal framing only
    const frames = res.body
      .split('\n\n')
      .filter((f) => f.trim().startsWith('data:'))
      .map((f) => JSON.parse(f.trim().slice(5).trim()));

    const complete = frames[frames.length - 1];
    expect(complete.stage).toBe('complete');
    expect(complete.status).toBe('failed');
    expect(complete.error).toMatch(/robots\.txt/);
  });
});
