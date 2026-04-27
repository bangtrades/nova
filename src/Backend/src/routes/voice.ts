/**
 * S13-05 — Voice TTS proxy route.
 *
 * Why this exists: the iOS NovaKids binary must NOT carry an OPENAI_API_KEY.
 * Embedding the key in a kid-facing app is a leak vector — App Store review
 * caches the IPA, anyone with `strings` against the binary can lift it, and
 * key rotation forces a rebuild + resubmit. Backend proxy is the standard
 * pattern: kid's existing Bearer token authorizes /voice/tts the same way
 * it authorizes /lessons.
 *
 * The proxy adds three things on top of plain forwarding:
 *
 *   1. **Hash-keyed in-memory LRU cache.** Same (voice|model|text) tuple
 *      from any user returns the cached MP3 in <1ms. The voice picker's
 *      sample sentences hit cache from request #2 onward across all
 *      kids — kid-1 generates "Hi! I'm Nova!", kid-2 hears it instantly.
 *
 *   2. **Per-user request budget tracked via existing logUsage** — same
 *      cost-tracking machinery the asset pipeline uses. A single user
 *      pegging the proxy lights up the same dashboard as runaway image
 *      generation.
 *
 *   3. **Voice + model allow-list** — Zod-validated. Prevents kids
 *      from sending arbitrary strings to OpenAI by mutating the iOS
 *      payload (defense-in-depth even though our own client wouldn't).
 *
 * Cost shape (for budgeting): tts-1 is $0.015 per 1k characters. A
 * typical lesson card narration is ~200 chars. Six lessons × 8 cards ×
 * 4 voices = 192 unique generations × 200 chars = 38.4k chars =
 * $0.58 to pre-cache the entire S13 catalog under all 4 voices.
 * Touch-test scale economics — kid demo costs less than a coffee.
 */

import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import crypto from 'crypto';
import { validateBody } from '@middleware/validate';
import { generateTTSAudio, TTSGeneratorError } from '@services/assets/ttsGenerator';
import { getConfig } from '@config';
import { logUsage } from '@services/llm/costTracker';

// Allowed voice + model values mirror the OpenAI TTS API.
const ALLOWED_VOICES = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'] as const;
const ALLOWED_MODELS = ['tts-1', 'tts-1-hd'] as const;

// Cache config — kept conservative for in-process memory.
// 192 lesson clips × ~50KB ≈ 10MB; 500-entry cap leaves plenty of headroom
// for picker samples + ad-hoc Oracle Voice tab generations.
const CACHE_MAX_ENTRIES = 500;
const CACHE_MAX_BYTES = 50 * 1024 * 1024; // 50MB ceiling

interface CacheEntry {
  audio: Buffer;
  voice: string;
  model: string;
  textPreview: string; // First 60 chars, for Oracle Voice tab introspection.
  createdAt: number;
  hits: number;
  bytes: number;
}

// Module-level cache. Process-lifetime only; survives no restarts. That's
// fine — first request after a restart re-pays $0.003. Sandbox mode keeps
// debugging deterministic.
const audioCache = new Map<string, CacheEntry>();
let cacheTotalBytes = 0;

// Per-voice latency tracking for the Oracle Voice tab. Rolling window
// of last 50 generations per voice, p50/p95 computed on demand.
const latencyByVoice: Record<string, number[]> = {};

const ttsRequestSchema = z.object({
  text: z.string().min(1).max(4096),
  voice: z.enum(ALLOWED_VOICES).default('nova'),
  model: z.enum(ALLOWED_MODELS).default('tts-1'),
});

type TTSRequest = z.infer<typeof ttsRequestSchema>;

/**
 * Compute the cache key for a TTS request.
 *
 * SHA-256 over `voice|model|text`. Hex-encoded. 64 chars. Collision-resistant
 * for any realistic kid-app scale. Includes voice + model so the same text
 * with two different voices is two cache entries (correct).
 */
function cacheKey(voice: string, model: string, text: string): string {
  return crypto
    .createHash('sha256')
    .update(`${voice}|${model}|${text}`)
    .digest('hex');
}

/**
 * Evict oldest entries until we're under both the count and byte ceilings.
 * Map iteration order is insertion order in V8, so iterating gives oldest-first.
 */
function evictIfNeeded(): void {
  while (
    audioCache.size >= CACHE_MAX_ENTRIES ||
    cacheTotalBytes >= CACHE_MAX_BYTES
  ) {
    const oldestKey = audioCache.keys().next().value;
    if (oldestKey === undefined) break;
    const entry = audioCache.get(oldestKey);
    if (entry) cacheTotalBytes -= entry.bytes;
    audioCache.delete(oldestKey);
  }
}

/**
 * Record a generation latency sample for the given voice. Keeps the
 * last 50 samples per voice for the Oracle Voice tab's latency chart.
 */
function recordLatency(voice: string, ms: number): void {
  if (!latencyByVoice[voice]) latencyByVoice[voice] = [];
  const arr = latencyByVoice[voice];
  arr.push(ms);
  if (arr.length > 50) arr.shift();
}

/**
 * Compute p50 / p95 over the rolling latency samples for a voice.
 * Returns null fields if no samples yet.
 */
function latencyStats(voice: string): {
  count: number;
  p50: number | null;
  p95: number | null;
} {
  const samples = latencyByVoice[voice];
  if (!samples || samples.length === 0) {
    return { count: 0, p50: null, p95: null };
  }
  const sorted = [...samples].sort((a, b) => a - b);
  const p50 = sorted[Math.floor(sorted.length * 0.5)];
  const p95 = sorted[Math.floor(sorted.length * 0.95)] ?? sorted[sorted.length - 1];
  return { count: samples.length, p50, p95 };
}

export async function voiceRoutes(fastify: FastifyInstance): Promise<void> {
  /**
   * POST /voice/tts
   *
   * Body: { text, voice?, model? } — voice/model default to nova/tts-1.
   * Auth: standard Bearer token (request.userId set by global authenticate hook).
   *
   * Response 200: audio/mpeg stream (MP3 bytes).
   * Headers:
   *   - X-Voice-Cache: HIT | MISS — for client-side latency observability.
   *   - X-Voice-Latency-Ms: <number> — generation latency on MISS, 0 on HIT.
   *   - X-Voice-Used: <voice name> — echoes resolved voice (helpful when client sent default).
   *
   * Errors mirror OpenAI status codes: 401 unauthorized (server-side OPENAI_API_KEY
   * missing), 429 rate-limited, 5xx upstream, 400 bad input.
   */
  fastify.post<{ Body: TTSRequest }>(
    '/tts',
    {
      preHandler: validateBody(ttsRequestSchema),
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { text, voice, model } = request.body;
      const cleanText = text.trim();
      const key = cacheKey(voice, model, cleanText);

      // Cache hit fast path — return cached MP3 immediately.
      const cached = audioCache.get(key);
      if (cached) {
        cached.hits += 1;
        // Touch order for LRU — re-insert moves to most-recent position.
        audioCache.delete(key);
        audioCache.set(key, cached);

        return reply
          .header('Content-Type', 'audio/mpeg')
          .header('Content-Length', cached.bytes.toString())
          .header('X-Voice-Cache', 'HIT')
          .header('X-Voice-Latency-Ms', '0')
          .header('X-Voice-Used', cached.voice)
          .send(cached.audio);
      }

      // Cache miss — generate via OpenAI.
      const apiKey = getConfig().OPENAI_API_KEY;
      if (!apiKey) {
        return reply.status(503).send({
          statusCode: 503,
          error: 'Service Unavailable',
          message: 'TTS service is not configured (server missing OPENAI_API_KEY)',
        });
      }

      const startedAt = Date.now();
      try {
        const audio = await generateTTSAudio(apiKey, cleanText, voice, model);
        const latencyMs = Date.now() - startedAt;

        // Record latency stats (Oracle Voice tab chart).
        recordLatency(voice, latencyMs);

        // Insert into cache (evicting if needed).
        evictIfNeeded();
        const entry: CacheEntry = {
          audio,
          voice,
          model,
          textPreview: cleanText.slice(0, 60),
          createdAt: Date.now(),
          hits: 0,
          bytes: audio.length,
        };
        audioCache.set(key, entry);
        cacheTotalBytes += entry.bytes;

        // Cost tracking (mirrors asset-pipeline pattern). $0.015 per 1k chars
        // for tts-1; tts-1-hd is $0.030 per 1k chars but we don't ship -hd
        // by default so this is mostly tts-1.
        logUsage({
          userId: request.userId,
          provider: 'openai',
          model,
          feature: 'tts',
          metadata: { charCount: cleanText.length, voice, latencyMs, source: 'voice-proxy' },
        });

        return reply
          .header('Content-Type', 'audio/mpeg')
          .header('Content-Length', audio.length.toString())
          .header('X-Voice-Cache', 'MISS')
          .header('X-Voice-Latency-Ms', latencyMs.toString())
          .header('X-Voice-Used', voice)
          .send(audio);
      } catch (err) {
        // Mirror OpenAI status codes back to the iOS client so it can fall
        // back to AVSpeech on transient failures.
        if (err instanceof TTSGeneratorError) {
          return reply.status(err.statusCode).send({
            statusCode: err.statusCode,
            error: err.code,
            message: err.message,
            retryable: err.retryable,
          });
        }
        request.log.error({ err }, 'voice/tts unexpected error');
        return reply.status(500).send({
          statusCode: 500,
          error: 'Internal Server Error',
          message: 'TTS generation failed',
        });
      }
    }
  );

  /**
   * GET /voice/voices
   *
   * Returns the four kid-facing voice personas the iOS picker shows. Each
   * row carries: id (OpenAI voice slug), displayName (kid-friendly), tagline,
   * sampleText (the line the picker plays on tap), and the recommended
   * topics for persona-aware selection (S13-11 stretch).
   *
   * Why surfaced from backend: lets bang tweak voice copy without an iOS
   * rebuild, and keeps a single source of truth shared by the iOS picker
   * and the Oracle Voice tab.
   */
  fastify.get('/voices', async (_request, reply) => {
    return reply.send({
      success: true,
      voices: [
        {
          id: 'nova',
          displayName: 'Nova',
          tagline: 'Bright + bouncy',
          sampleText: "Hi! I'm Nova! Let's learn something amazing today!",
          recommendedTopics: ['general', 'science', 'space', 'animals'],
          color: '#FF8A3D', // novaOrange
        },
        {
          id: 'fable',
          displayName: 'Pip',
          tagline: 'British storyteller',
          sampleText:
            "Hello, little explorer. I'm Pip, and I have ever such a wonderful story to share with you.",
          recommendedTopics: ['stories', 'history', 'literature', 'fairy-tales'],
          color: '#7C5CFF', // novaPurple
        },
        {
          id: 'onyx',
          displayName: 'Captain Boom',
          tagline: 'Brave + bold',
          sampleText:
            "Greetings, adventurer! Captain Boom here. Ready to go on an amazing journey?",
          recommendedTopics: ['adventure', 'space', 'heroes', 'engineering'],
          color: '#1B6EF3', // novaBlue
        },
        {
          id: 'shimmer',
          displayName: 'Sunny',
          tagline: 'Warm + gentle',
          sampleText:
            "Hi sweetheart. I'm Sunny. We're going to have such a nice time learning together.",
          recommendedTopics: ['nature', 'feelings', 'animals', 'food'],
          color: '#FFD23F', // sun
        },
      ],
    });
  });

  /**
   * GET /voice/stats
   *
   * Oracle Voice tab data feed. Returns:
   *   - cache: { entries, totalBytes, hitRate } (hits/(hits+misses) over recent activity)
   *   - latency: per-voice { count, p50, p95 } in ms
   *   - recent: last 10 cache entries (voice, model, textPreview, hits)
   *
   * Auth: same Bearer token as everything else; intentionally surfaces no
   * user-specific data — pure server health introspection.
   */
  fastify.get('/stats', async (request, reply) => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }

    let totalHits = 0;
    let totalEntries = 0;
    const recent: Array<{
      voice: string;
      model: string;
      textPreview: string;
      hits: number;
      ageSeconds: number;
    }> = [];

    const entries = Array.from(audioCache.entries());
    // Iterate newest-first by reversing (Map is oldest-first).
    for (let i = entries.length - 1; i >= 0; i--) {
      const [, entry] = entries[i];
      totalEntries += 1;
      totalHits += entry.hits;
      if (recent.length < 10) {
        recent.push({
          voice: entry.voice,
          model: entry.model,
          textPreview: entry.textPreview,
          hits: entry.hits,
          ageSeconds: Math.floor((Date.now() - entry.createdAt) / 1000),
        });
      }
    }

    const latency: Record<string, { count: number; p50: number | null; p95: number | null }> = {};
    for (const v of ALLOWED_VOICES) latency[v] = latencyStats(v);

    return reply.send({
      success: true,
      cache: {
        entries: totalEntries,
        totalBytes: cacheTotalBytes,
        totalHits,
        // hitRate is across-server-lifetime, computed against (hits + misses).
        // misses = entries (each entry started as a miss); for a long-lived
        // server this gives a meaningful hit rate.
        hitRate: totalEntries === 0 ? 0 : totalHits / (totalHits + totalEntries),
        maxEntries: CACHE_MAX_ENTRIES,
        maxBytes: CACHE_MAX_BYTES,
      },
      latency,
      recent,
    });
  });

  /**
   * POST /voice/cache/clear
   *
   * Oracle affordance: drop the entire TTS cache. Useful when bang regenerates
   * a lesson with a tweaked voice persona and wants to re-listen against fresh
   * audio. Returns the count of entries cleared.
   */
  fastify.post('/cache/clear', async (request, reply) => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }
    const cleared = audioCache.size;
    audioCache.clear();
    cacheTotalBytes = 0;
    return reply.send({ success: true, cleared });
  });
}

export default voiceRoutes;
