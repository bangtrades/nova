/**
 * Encode-side contract tests (Jun 10 audit)
 *
 * iOS's APIClient now encodes bodies with `.useDefaultKeys` (camelCase,
 * matching the zod schemas). These tests post the exact body shapes the
 * fixed iOS endpoints produce for the two live kid-path seams and pin
 * that they clear validation (a 400 here = the contract regressed).
 */

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer, generateTestToken } from './setup';

const AUTH = { authorization: `Bearer ${generateTestToken('00000000-0000-4000-8000-000000000099')}` };

const CHILD_ID = '00000000-0000-4000-8000-00000000c41d';

describe('Encode-side contracts — iOS wire bodies clear validation', () => {
  let fastify: FastifyInstance;

  beforeAll(async () => {
    fastify = await createTestServer();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('POST /progress/sync accepts the iOS body (childId + camelCase interactions)', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/progress/sync',
      headers: { 'content-type': 'application/json', ...AUTH },
      payload: JSON.stringify({
        childId: CHILD_ID,
        deviceId: 'ios-test-device',
        interactions: [
          {
            // iOS CardInteraction encodes extra keys (id, sessionId,
            // timestamp) — zod strips unknowns; required keys must pass.
            id: '00000000-0000-4000-8000-000000000001',
            sessionId: '00000000-0000-4000-8000-000000000002',
            cardId: '00000000-0000-4000-8000-000000000003',
            action: 'cardCompleted',
            durationMs: 4200,
            voiceTranscript: 'blue',
          },
        ],
      }),
    });

    // Validation 400 = contract regression. Downstream domain errors
    // (404 unknown child, 403 ownership, 500 no-DB) are fine here.
    expect(response.statusCode).not.toBe(400);
  });

  it('POST /dashy/chat accepts the iOS body (childId + transcript + conversationHistory)', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/dashy/chat',
      headers: { 'content-type': 'application/json', ...AUTH },
      payload: JSON.stringify({
        childId: CHILD_ID,
        transcript: 'Why is the sky blue?',
        conversationHistory: [
          { role: 'user', content: 'Hi Dashy!' },
          { role: 'assistant', content: 'Hi friend! What shall we learn?' },
        ],
      }),
    });

    expect(response.statusCode).not.toBe(400);
  });

  it('POST /dashy/chat still rejects the OLD iOS body shape', async () => {
    // Regression canary: the pre-fix body must keep failing validation —
    // if this starts passing, someone loosened the schema instead of
    // fixing a client.
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/dashy/chat',
      headers: { 'content-type': 'application/json', ...AUTH },
      payload: JSON.stringify({
        message: 'Why is the sky blue?',
        history: [],
        childAge: 4,
      }),
    });

    expect(response.statusCode).toBe(400);
  });
});
