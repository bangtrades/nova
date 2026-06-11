/**
 * S14-VOX follow-up tests (Slice D, 2026-06-10)
 *
 * Covers the VOX-FU backend trio:
 *  - VOX-01: PUBLIC_BASE_URL env var drives dev-mode asset URLs
 *  - VOX-03: empty-body POST with `Content-Type: application/json`
 *            no longer rejected by the JSON parser
 *  - VOX-04: POST /lessons/:id/unpublish route exists
 */

import { describe, it, expect, beforeAll, afterAll, vi } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { createTestServer } from './setup';

// Set BEFORE the first getConfig() call — something in the server import
// chain calls getConfig() at import time and the parsed env is cached at
// module scope, so a plain top-level assignment runs too late (static
// imports execute first). vi.hoisted runs ahead of the import graph.
vi.hoisted(() => {
  process.env.PUBLIC_BASE_URL = 'http://192.168.7.50:3000';
});

describe('VOX-01 — PUBLIC_BASE_URL in dev-mode asset URLs', () => {
  // The local fallback genuinely writes to public/assets/ — clean up the
  // artifact so test runs don't leave untracked files in the repo.
  afterAll(async () => {
    const { unlink } = await import('node:fs/promises');
    const { join } = await import('node:path');
    await unlink(join(__dirname, '..', 'public', 'assets', 'vox01-test.mp3')).catch(() => {});
  });

  it('bakes PUBLIC_BASE_URL into the local-fallback asset URL', async () => {
    // Dynamic import so the env override above is definitely live first.
    const { uploadToR2 } = await import('../src/services/assets/assetUploader');
    const url = await uploadToR2(Buffer.from('fake audio'), 'vox01-test.mp3', 'audio/mpeg');

    expect(url).toBe('http://192.168.7.50:3000/dev/assets/vox01-test.mp3');
    expect(url).not.toContain('localhost');
  });
});

describe('VOX-03 + VOX-04 — wire behavior', () => {
  let fastify: FastifyInstance;

  beforeAll(async () => {
    fastify = await createTestServer();
  });

  afterAll(async () => {
    await fastify.close();
  });

  it('VOX-03: empty-body POST with JSON content-type is not rejected by the parser', async () => {
    // Pre-fix, Fastify's stock parser rejected this shape outright with
    // FST_ERR_CTP_EMPTY_JSON_BODY (400 "Body cannot be empty...") before
    // auth or the handler ever ran. Post-fix the request reaches the
    // route, so the response is anything downstream (401/403/404/500
    // depending on DB/auth state) — but never the parser 400.
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/lessons/00000000-0000-4000-8000-000000000000/publish',
      headers: { 'content-type': 'application/json' },
      // no payload — the case iOS URLSession and bare curl produce
    });

    expect(response.statusCode).not.toBe(400);
  });

  it('VOX-03: malformed JSON still rejected with 400', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/lessons/00000000-0000-4000-8000-000000000000/publish',
      headers: { 'content-type': 'application/json' },
      payload: '{not json',
    });

    expect(response.statusCode).toBe(400);
  });

  it('VOX-02: POST /auth/dev-bypass mints a real token pair outside production', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/auth/dev-bypass',
      headers: { 'content-type': 'application/json' },
      // no body — also exercises the VOX-03 parser on a fresh route
    });

    // With a live dev DB: 200 + tokens for the deterministic dev user.
    // Without a DB (bare CI): 500 from the prisma call. Never a router
    // 404 — that would mean the route isn't registered.
    if (response.statusCode === 200) {
      const body = JSON.parse(response.body);
      expect(body.accessToken).toBeTruthy();
      expect(body.refreshToken).toBeTruthy();
      expect(body.user.displayName).toBe('Dev Tester');
    } else {
      expect(response.statusCode).toBe(500);
    }
  });

  it('VOX-04: unpublish route is registered (no router 404)', async () => {
    const response = await fastify.inject({
      method: 'POST',
      url: '/api/v1/lessons/00000000-0000-4000-8000-000000000000/unpublish',
      headers: { 'content-type': 'application/json' },
    });

    // A missing ROUTE gives Fastify's default 404 ("Route POST:... not
    // found"). A registered route gives a domain response: 401 (no
    // user), 403, 404 with "Lesson not found", or 500 (no DB in CI).
    if (response.statusCode === 404) {
      const body = JSON.parse(response.body);
      expect(body.message).toBe('Lesson not found');
    } else {
      expect([200, 401, 403, 500]).toContain(response.statusCode);
    }
  });
});
