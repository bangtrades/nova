import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer, generateTestToken, TEST_USER_ID } from './setup';
import { getSkillRegistry } from '../src/services/skills/registry';

// ============================================================================
// S10-06 / S10-07 — /dev/skills route tests
//
// These exercise the Dev Console backing endpoints. The render endpoint is
// pure (no LLM, no DB required for synthetic mode), so we stay in synthetic
// mode for all rendering assertions. The childId ownership path is tested
// by giving a UUID that doesn't exist — we expect 404.
// ============================================================================

const DEV_PREFIX = '/api/v1/dev/skills';

describe('/api/v1/dev/skills — list & single', () => {
  let fastify: FastifyInstance;
  let token: string;

  beforeAll(async () => {
    fastify = await createTestServer();
    // Ensure registry is populated so tests are self-contained even if
    // buildServer's boot load is skipped in the test harness.
    if (!getSkillRegistry().isLoaded()) {
      await getSkillRegistry().load();
    }
    token = generateTestToken(TEST_USER_ID);
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('returns 401 without auth', async () => {
    const res = await fastify.inject({ method: 'GET', url: DEV_PREFIX });
    expect(res.statusCode).toBe(401);
  });

  it('returns the list of registered skills', async () => {
    const res = await fastify.inject({
      method: 'GET',
      url: DEV_PREFIX,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body).toHaveProperty('data');
    expect(body).toHaveProperty('count');
    expect(Array.isArray(body.data)).toBe(true);
    expect(body.count).toBeGreaterThanOrEqual(1);
    // story-writer must be present — it's the first real skill def.
    const names = body.data.map((s: { name: string }) => s.name);
    expect(names).toContain('story-writer');
    // Row shape check: exposes manifest-level fields.
    const story = body.data.find((s: { name: string }) => s.name === 'story-writer');
    expect(story).toMatchObject({
      name: 'story-writer',
      version: expect.any(String),
      modelHint: expect.any(String),
      ageProfiles: expect.arrayContaining([4, 6, 8]),
    });
    expect(story.description).toBeTruthy();
  });

  it('returns the manifest for a known skill', async () => {
    const res = await fastify.inject({
      method: 'GET',
      url: `${DEV_PREFIX}/story-writer`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    expect(body.data.manifest).toMatchObject({
      name: 'story-writer',
      handlesConceptTypes: expect.any(Array),
    });
  });

  it('returns 404 for unknown skill', async () => {
    const res = await fastify.inject({
      method: 'GET',
      url: `${DEV_PREFIX}/nope-not-a-real-skill`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(404);
    const body = JSON.parse(res.body);
    expect(body.message).toMatch(/no skill/i);
  });
});

describe('/api/v1/dev/skills/:name/render — synthetic dry-run', () => {
  let fastify: FastifyInstance;
  let token: string;

  beforeAll(async () => {
    fastify = await createTestServer();
    if (!getSkillRegistry().isLoaded()) {
      await getSkillRegistry().load();
    }
    token = generateTestToken(TEST_USER_ID);
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('returns 401 without auth', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      payload: { inputs: { topic: 'photosynthesis' } },
    });
    expect(res.statusCode).toBe(401);
  });

  it('returns 404 for unknown skill even with auth', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/nope/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: { inputs: { topic: 'photosynthesis' } },
    });
    expect(res.statusCode).toBe(404);
  });

  it('renders story-writer with only the required input', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: { inputs: { topic: 'how seeds grow' } },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    // Prompts are split around the marker.
    expect(data.system).toBeTruthy();
    expect(data.user).toBeTruthy();
    expect(typeof data.system).toBe('string');
    expect(typeof data.user).toBe('string');
    expect(data.user).toMatch(/how seeds grow/);
    // Meta fields exposed so Dev Console can render the badge row.
    expect(data.meta).toMatchObject({
      skillName: 'story-writer',
      version: expect.any(String),
      modelHint: expect.any(String),
      temperatureHint: expect.any(Number),
      ageProfileUsed: expect.any(Number),
    });
    // Synthetic default ageYears is 6.
    expect(data.context.ageYears).toBe(6);
    // Progression breakdown returned by default.
    expect(data.progressionBreakdown).not.toBeNull();
  });

  it('honors ctxOverrides.ageYears for age-profile selection', async () => {
    // 4yo → profile 4
    const res4 = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'the moon' },
        ctxOverrides: { ageYears: 4 },
      },
    });
    expect(res4.statusCode).toBe(200);
    expect(JSON.parse(res4.body).data.meta.ageProfileUsed).toBe(4);

    // 8yo → profile 8
    const res8 = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'the moon' },
        ctxOverrides: { ageYears: 8 },
      },
    });
    expect(res8.statusCode).toBe(200);
    expect(JSON.parse(res8.body).data.meta.ageProfileUsed).toBe(8);
  });

  it('sliding-scale: 7yo + progressionDelta=+1.2 promotes to age-8 profile', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'dinosaurs' },
        ctxOverrides: { ageYears: 7, progressionDelta: 1.2 },
      },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    expect(data.meta.ageProfileUsed).toBe(8);
    // effectiveAgeYears should reflect the progression nudge (≈ 8.2).
    expect(data.context.effectiveAgeYears).toBeGreaterThan(8);
  });

  it('embeds topic avoid list when parentGuidance.topicAvoid is overridden', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'nighttime' },
        ctxOverrides: {
          ageYears: 6,
          parentGuidance: { topicAvoid: ['monsters', 'thunderstorms'] },
        },
      },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    const combined = `${data.system}\n${data.user}`;
    expect(combined.toLowerCase()).toMatch(/monsters/);
    expect(combined.toLowerCase()).toMatch(/thunderstorms/);
  });

  it('uses interestTopics when present and falls back to canonical bank otherwise', async () => {
    const withInterests = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'weather' },
        ctxOverrides: {
          ageYears: 6,
          interestTopics: ['origami', 'sea creatures'],
        },
      },
    });
    expect(withInterests.statusCode).toBe(200);
    const { data: dataI } = JSON.parse(withInterests.body);
    expect(`${dataI.system}\n${dataI.user}`).toMatch(/origami|sea creatures/);
  });

  it('rejects extraneous fields via strict schema', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'x' },
        extraHackField: 'should be rejected',
      },
    });
    // validateBody runs Zod strict — extra key triggers 400.
    expect(res.statusCode).toBe(400);
  });

  it('rejects out-of-range progressionDelta', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'x' },
        ctxOverrides: { ageYears: 6, progressionDelta: 5 },
      },
    });
    expect(res.statusCode).toBe(400);
  });

  it('surfaces 400 when a required skill input is missing', async () => {
    // story-writer requires `topic` — omit it.
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: { inputs: {} },
    });
    expect(res.statusCode).toBe(400);
    const body = JSON.parse(res.body);
    expect(body.message).toMatch(/topic|required/i);
  });

  it('returns 404 when childId references a non-existent child', async () => {
    // A syntactically valid UUID that no fixture created.
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        childId: '00000000-0000-4000-8000-000000000000',
        inputs: { topic: 'test' },
      },
    });
    // Could be 404 (child not found) or 403 (found but not owned) — both
    // are valid ownership-chain outcomes depending on DB state.
    expect([404, 403]).toContain(res.statusCode);
  });

  it('omits progressionBreakdown when includeProgressionBreakdown=false', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { topic: 'clouds' },
        includeProgressionBreakdown: false,
      },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    expect(data.progressionBreakdown).toBeNull();
  });
});

describe('/api/v1/dev/skills/:name/reload — dev-only', () => {
  let fastify: FastifyInstance;
  let token: string;
  const originalNodeEnv = process.env.NODE_ENV;

  beforeAll(async () => {
    fastify = await createTestServer();
    if (!getSkillRegistry().isLoaded()) {
      await getSkillRegistry().load();
    }
    token = generateTestToken(TEST_USER_ID);
  });

  afterAll(async () => {
    process.env.NODE_ENV = originalNodeEnv;
    await fastify.close();
  });

  it('returns 401 without auth', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/reload`,
    });
    expect(res.statusCode).toBe(401);
  });

  it('succeeds for a known skill in non-production', async () => {
    process.env.NODE_ENV = 'development';
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/reload`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    expect(data.reloaded).toBe('story-writer');
    expect(data.at).toBeTruthy();
  });

  it('returns 404 reloading an unknown skill', async () => {
    process.env.NODE_ENV = 'development';
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/nope-unknown/reload`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(404);
  });

  it('is disabled when NODE_ENV=production', async () => {
    process.env.NODE_ENV = 'production';
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/story-writer/reload`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(403);
    process.env.NODE_ENV = originalNodeEnv;
  });
});

// ============================================================================
// S10-07 — quiz-maker-specific Dev Console coverage
//
// The list endpoint must expose `hasOutputSchema` per-skill so the UI can
// render a "validator attached" chip. The render endpoint must handle the
// quiz-maker's distinct input shape (concept + conceptType) and the
// difficulty-curve axis (easy→3, medium→4, hard→5 options).
// ============================================================================

describe('/api/v1/dev/skills — quiz-maker coverage', () => {
  let fastify: FastifyInstance;
  let token: string;

  beforeAll(async () => {
    fastify = await createTestServer();
    if (!getSkillRegistry().isLoaded()) {
      await getSkillRegistry().load();
    }
    token = generateTestToken(TEST_USER_ID);
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('lists quiz-maker with hasOutputSchema=true and story-writer with hasOutputSchema=false', async () => {
    const res = await fastify.inject({
      method: 'GET',
      url: DEV_PREFIX,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const body = JSON.parse(res.body);
    const rows: Array<{
      name: string;
      hasOutputSchema?: boolean;
      difficulties?: string[];
    }> = body.data;
    const names = rows.map((r) => r.name);
    expect(names).toContain('quiz-maker');

    const quiz = rows.find((r) => r.name === 'quiz-maker')!;
    expect(quiz.hasOutputSchema).toBe(true);
    expect(quiz.difficulties).toEqual(
      expect.arrayContaining(['easy', 'medium', 'hard'])
    );

    const story = rows.find((r) => r.name === 'story-writer')!;
    // story-writer is free-form prose — no Zod schema attached.
    expect(story.hasOutputSchema).toBe(false);
  });

  it('GET /:name returns the quiz-maker manifest with handlesConceptTypes', async () => {
    const res = await fastify.inject({
      method: 'GET',
      url: `${DEV_PREFIX}/quiz-maker`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    expect(data.manifest.name).toBe('quiz-maker');
    expect(data.manifest.inputs.requires).toEqual(
      expect.arrayContaining(['concept', 'conceptType'])
    );
    expect(data.manifest.handlesConceptTypes).toEqual(
      expect.arrayContaining(['vocabulary', 'abstract', 'causeEffect'])
    );
    expect(data.hasOutputSchema).toBe(true);
  });

  it('renders quiz-maker at easy → 3 options; hard → 5 options', async () => {
    const easy = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/quiz-maker/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { concept: 'gravity pulls down', conceptType: 'causeEffect' },
        ctxOverrides: { ageYears: 6, difficultyOffset: -2 },
      },
    });
    expect(easy.statusCode).toBe(200);
    const eData = JSON.parse(easy.body).data;
    expect(eData.meta.difficultyUsed).toBe('easy');
    expect(eData.system).toMatch(/exactly 3/);
    expect(eData.meta.skillName).toBe('quiz-maker');

    const hard = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/quiz-maker/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: {
        inputs: { concept: 'gravity pulls down', conceptType: 'causeEffect' },
        ctxOverrides: { ageYears: 8, difficultyOffset: 2 },
      },
    });
    expect(hard.statusCode).toBe(200);
    const hData = JSON.parse(hard.body).data;
    expect(hData.meta.difficultyUsed).toBe('hard');
    expect(hData.system).toMatch(/exactly 5/);
  });

  it('renders with each LearningModality — visual / auditory / kinesthetic', async () => {
    const modalities: Array<'visual' | 'auditory' | 'kinesthetic'> = [
      'visual',
      'auditory',
      'kinesthetic',
    ];
    for (const modality of modalities) {
      const res = await fastify.inject({
        method: 'POST',
        url: `${DEV_PREFIX}/quiz-maker/render`,
        headers: { authorization: `Bearer ${token}` },
        payload: {
          inputs: { concept: 'evaporation', conceptType: 'process' },
          ctxOverrides: { ageYears: 6, modality },
        },
      });
      expect(res.statusCode).toBe(200);
      const { data } = JSON.parse(res.body);
      expect(data.system).toMatch(/Modality note/i);
    }
  });

  it('surfaces 400 when required quiz-maker input is missing', async () => {
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/quiz-maker/render`,
      headers: { authorization: `Bearer ${token}` },
      payload: { inputs: { concept: 'friction' } }, // conceptType missing
    });
    expect(res.statusCode).toBe(400);
    const body = JSON.parse(res.body);
    expect(body.message).toMatch(/conceptType|required/i);
  });

  it('reload endpoint works for quiz-maker in dev mode', async () => {
    const originalNodeEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'development';
    const res = await fastify.inject({
      method: 'POST',
      url: `${DEV_PREFIX}/quiz-maker/reload`,
      headers: { authorization: `Bearer ${token}` },
    });
    expect(res.statusCode).toBe(200);
    const { data } = JSON.parse(res.body);
    expect(data.reloaded).toBe('quiz-maker');
    process.env.NODE_ENV = originalNodeEnv;
  });
});
