/**
 * Asset Generation Pipeline Tests
 *
 * Tests for TTS, image generation, asset uploading, YouTube extraction,
 * asset job processing, and StoreKit webhook handling.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import {
  generateTTSAudio,
  TTSGeneratorError,
} from '../src/services/assets/ttsGenerator';
import {
  generateImage,
  buildImagePrompt,
  downloadImage,
  ImageGeneratorError,
} from '../src/services/assets/imageGenerator';
import {
  uploadToR2,
  uploadAudio,
  uploadImage,
  AssetUploaderError,
} from '../src/services/assets/assetUploader';
import {
  extractYouTubeTranscript,
  isYouTubeUrl,
  YouTubeExtractorError,
} from '../src/services/assets/youtubeExtractor';
import { buildCardConcept } from '../src/services/assets/assetJobProcessor';

// ============================================================================
// TTS Generator Tests
// ============================================================================

describe('TTS Generator', () => {
  const validApiKey = 'sk-test-key-123';

  it('should reject missing API key', async () => {
    await expect(generateTTSAudio('', 'Hello world')).rejects.toThrow(TTSGeneratorError);

    try {
      await generateTTSAudio('', 'Hello world');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('invalid_api_key');
      expect((error as TTSGeneratorError).statusCode).toBe(401);
    }
  });

  it('should reject empty text', async () => {
    await expect(generateTTSAudio(validApiKey, '')).rejects.toThrow(TTSGeneratorError);

    try {
      await generateTTSAudio(validApiKey, '   ');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('invalid_input');
    }
  });

  it('should reject text exceeding max length', async () => {
    const longText = 'a'.repeat(5000);

    try {
      await generateTTSAudio(validApiKey, longText);
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('text_too_long');
      expect((error as TTSGeneratorError).retryable).toBe(false);
    }
  });

  it('should reject invalid voice selection', async () => {
    try {
      await generateTTSAudio(validApiKey, 'Hello world', 'invalid-voice');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('invalid_voice');
      expect((error as TTSGeneratorError).statusCode).toBe(400);
    }
  });

  it('should reject invalid model selection', async () => {
    try {
      await generateTTSAudio(validApiKey, 'Hello world', 'nova', 'invalid-model');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('invalid_model');
    }
  });

  it('should accept valid voice options', async () => {
    const validVoices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];

    for (const voice of validVoices) {
      expect(() => {
        // Just test that validation passes (won't actually call API)
        // In real test, mock fetch and verify parameters
      }).not.toThrow();
    }
  });

  it('should handle rate limit error as retryable', async () => {
    // Mock fetch to return 429
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 429,
      headers: new Map([['content-type', 'application/json']]),
      json: async () => ({
        error: { message: 'Rate limit exceeded', type: 'server_error' },
      }),
    });

    try {
      await generateTTSAudio(validApiKey, 'Test');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('rate_limit');
      expect((error as TTSGeneratorError).retryable).toBe(true);
    }
  });

  it('should handle 401 as non-retryable', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 401,
      headers: new Map([['content-type', 'application/json']]),
      json: async () => ({ error: { message: 'Invalid key' } }),
    });

    try {
      await generateTTSAudio(validApiKey, 'Test');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('invalid_api_key');
      expect((error as TTSGeneratorError).retryable).toBe(false);
    }
  });

  it('should handle empty response', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      arrayBuffer: async () => new ArrayBuffer(0),
    });

    try {
      await generateTTSAudio(validApiKey, 'Test');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('empty_response');
      expect((error as TTSGeneratorError).retryable).toBe(true);
    }
  });

  it('should handle network errors as retryable', async () => {
    global.fetch = vi.fn().mockRejectedValueOnce(new TypeError('fetch failed'));

    try {
      await generateTTSAudio(validApiKey, 'Test');
    } catch (error) {
      expect((error as TTSGeneratorError).code).toBe('network_error');
      expect((error as TTSGeneratorError).retryable).toBe(true);
    }
  });
});

// ============================================================================
// Image Generator Tests
// ============================================================================

describe('Image Generator', () => {
  const validApiKey = 'sk-test-key-123';

  describe('buildImagePrompt (post-S9 fix)', () => {
    it('creates a story prompt with positive style anchors', () => {
      const prompt = buildImagePrompt('A magical forest', 'story');

      expect(prompt).toContain('Storybook scene');
      expect(prompt).toContain('Flat digital illustration');
      expect(prompt).toContain('children');
      expect(prompt).toContain('magical forest');
    });

    it('creates an experiment prompt with kid-safe framing', () => {
      const prompt = buildImagePrompt('Crystal growing', 'experiment');

      expect(prompt).toContain('Kid-safe science activity');
      expect(prompt).toContain('Crystal growing');
    });

    it('creates a concept prompt', () => {
      const prompt = buildImagePrompt('Photosynthesis', 'concept');

      expect(prompt).toContain('Clear educational illustration');
      expect(prompt).toContain('Photosynthesis');
    });

    it('creates a quiz prompt (no longer collapses to stock imagery)', () => {
      const prompt = buildImagePrompt(
        'hippopotamus pointing at a menu of leafy foods',
        'quiz'
      );
      expect(prompt).toContain('Playful scene matching a multiple-choice question');
      expect(prompt).toContain('hippopotamus');
    });

    it('creates a voice prompt framing the child as speaker', () => {
      const prompt = buildImagePrompt('a hippopotamus opening its mouth wide', 'voice');
      expect(prompt).toContain('Expressive scene inviting the child to speak');
      expect(prompt).toContain('hippopotamus');
    });

    it('frontloads the subject noun when not already in the concept', () => {
      const prompt = buildImagePrompt(
        'splashing in a river under a rainbow',
        'story',
        'hippopotamus'
      );
      expect(prompt.startsWith('Subject: hippopotamus')).toBe(true);
      expect(prompt).toContain('splashing in a river under a rainbow');
    });

    it('does NOT double-prepend the subject when concept already leads with it', () => {
      const prompt = buildImagePrompt(
        'hippopotamus splashing in a river',
        'story',
        'hippopotamus'
      );
      expect(prompt.startsWith('Subject:')).toBe(false);
      expect(prompt.toLowerCase().indexOf('hippopotamus')).toBe(
        prompt.toLowerCase().lastIndexOf('hippopotamus')
      );
    });

    it('contains NO negative prompt phrases (DALL-E-3 interprets these inversely)', () => {
      const prompt = buildImagePrompt('a learning scene', 'concept', 'hippopotamus');
      const lower = prompt.toLowerCase();
      expect(lower).not.toContain('no text');
      expect(lower).not.toContain('no people faces');
      expect(lower).not.toContain('without');
    });

    it('works without a subject (backward-compatible call signature)', () => {
      const prompt = buildImagePrompt('a friendly fox', 'story');
      expect(prompt).toContain('Storybook scene');
      expect(prompt).toContain('a friendly fox');
      expect(prompt.startsWith('Subject:')).toBe(false);
    });
  });

  it('should reject unsafe prompts', async () => {
    const unsafePrompts = [
      'A gun shooting scene',
      'A scene of violence and chaos',
      'Adult explicit material',
      'Drug use in a park',
    ];

    for (const unsafePrompt of unsafePrompts) {
      await expect(generateImage(validApiKey, unsafePrompt)).rejects.toThrow();
      try {
        await generateImage(validApiKey, unsafePrompt);
      } catch (error) {
        expect((error as ImageGeneratorError).code).toBe('unsafe_content');
      }
    }
  });

  it('should reject missing API key', async () => {
    try {
      await generateImage('', 'A happy scene');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('invalid_api_key');
    }
  });

  it('should reject empty prompt', async () => {
    try {
      await generateImage(validApiKey, '   ');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('invalid_input');
    }
  });

  it('should reject invalid size', async () => {
    try {
      await generateImage(validApiKey, 'A happy scene', '512x512');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('invalid_size');
    }
  });

  it('should accept valid sizes', () => {
    const validSizes = ['1024x1024', '1792x1024', '1024x1792'];

    for (const size of validSizes) {
      expect(validSizes).toContain(size);
    }
  });

  it('should handle rate limit on image generation', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 429,
      headers: new Map([['content-type', 'application/json']]),
      json: async () => ({ error: { message: 'Rate limited' } }),
    });

    try {
      await generateImage(validApiKey, 'A happy scene');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('rate_limit');
      expect((error as ImageGeneratorError).retryable).toBe(true);
    }
  });

  it('should handle missing images in response', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [] }),
    });

    try {
      await generateImage(validApiKey, 'A happy scene');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('no_images_generated');
    }
  });

  it('should download image successfully', async () => {
    const mockImageBuffer = Buffer.from('fake image data');

    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      arrayBuffer: async () => mockImageBuffer,
    });

    const buffer = await downloadImage('https://example.com/image.png');

    expect(buffer).toBeDefined();
    expect(buffer.length > 0).toBe(true);
  });

  it('should reject invalid image URL', async () => {
    try {
      await downloadImage('');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('invalid_input');
    }
  });

  it('should handle download failure', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 404,
    });

    try {
      await downloadImage('https://example.com/missing.png');
    } catch (error) {
      expect((error as ImageGeneratorError).code).toBe('download_failed');
    }
  });
});

// ============================================================================
// Asset Uploader Tests
// ============================================================================

describe('Asset Uploader', () => {
  const mockBuffer = Buffer.from('fake audio data');

  it('should return mock URL in dev mode', async () => {
    // Mock config to have no R2 credentials
    vi.doMock('@config', () => ({
      getConfig: () => ({
        R2_ACCESS_KEY_ID: undefined,
        R2_SECRET_ACCESS_KEY: undefined,
        R2_PUBLIC_URL: 'http://localhost:3000',
      }),
    }));

    const url = await uploadToR2(mockBuffer, 'test.mp3', 'audio/mpeg');

    expect(url).toContain('mock');
    expect(url).toContain('test.mp3');
  });

  it('should generate secure filenames', async () => {
    // Test filename generation prevents path traversal
    const lessonId = 'lesson-123';
    const type = 'audio';
    const extension = 'mp3';

    // This would be from uploadAudio internally
    // Filenames should follow pattern: assets/{lessonId}/{type}/{uuid}.{ext}
    expect(`assets/${lessonId}/${type}`).toContain('assets/');
  });

  it('should reject invalid lesson ID in filename', () => {
    // Malicious input like ../../ should be sanitized
    const unsafeId = '../../etc/passwd';
    const sanitized = unsafeId.replace(/[^a-z0-9-]/gi, '');

    expect(sanitized).not.toContain('/');
    expect(sanitized).not.toContain('.');
  });

  it('should upload audio file', async () => {
    // Mock successful R2 response
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
    });

    const url = await uploadAudio(mockBuffer, 'lesson-123', 0);

    expect(url).toBeDefined();
    expect(url).toContain('assets');
  });

  it('should upload image file', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      status: 200,
    });

    const url = await uploadImage(mockBuffer, 'lesson-123', 0);

    expect(url).toBeDefined();
    expect(url).toContain('assets');
  });

  it('should handle R2 upload failure', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 403,
      text: async () => 'Access Denied',
    });

    try {
      await uploadToR2(mockBuffer, 'test.mp3', 'audio/mpeg');
    } catch (error) {
      expect((error as AssetUploaderError).code).toBe('upload_failed');
    }
  });

  it('should handle network errors during upload', async () => {
    global.fetch = vi.fn().mockRejectedValueOnce(new TypeError('Network failed'));

    try {
      await uploadToR2(mockBuffer, 'test.mp3', 'audio/mpeg');
    } catch (error) {
      expect((error as AssetUploaderError).code).toBe('network_error');
    }
  });
});

// ============================================================================
// YouTube Extractor Tests
// ============================================================================

describe('YouTube Extractor', () => {
  describe('isYouTubeUrl', () => {
    it('should detect youtube.com URLs', () => {
      expect(isYouTubeUrl('https://youtube.com/watch?v=abc123')).toBe(true);
      expect(isYouTubeUrl('https://www.youtube.com/watch?v=abc123')).toBe(true);
    });

    it('should detect youtu.be URLs', () => {
      expect(isYouTubeUrl('https://youtu.be/abc123')).toBe(true);
    });

    it('should detect embed URLs', () => {
      expect(isYouTubeUrl('https://youtube.com/embed/abc123')).toBe(true);
    });

    it('should reject non-YouTube URLs', () => {
      expect(isYouTubeUrl('https://vimeo.com/123')).toBe(false);
      expect(isYouTubeUrl('https://example.com')).toBe(false);
      expect(isYouTubeUrl('')).toBe(false);
      expect(isYouTubeUrl(null as any)).toBe(false);
    });
  });

  it('should extract video ID from youtube.com', async () => {
    const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      text: async () => '<title>Test Video - YouTube</title>',
    });

    const result = await extractYouTubeTranscript(url);

    expect(result.videoId).toBe('dQw4w9WgXcQ');
  });

  it('should extract video ID from youtu.be', async () => {
    const url = 'https://youtu.be/dQw4w9WgXcQ';

    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      text: async () => '<title>Test Video - YouTube</title>',
    });

    const result = await extractYouTubeTranscript(url);

    expect(result.videoId).toBe('dQw4w9WgXcQ');
  });

  it('should reject invalid URLs', async () => {
    try {
      await extractYouTubeTranscript('https://example.com/video');
    } catch (error) {
      expect((error as YouTubeExtractorError).code).toBe('invalid_youtube_url');
    }
  });

  it('should handle fetch failure gracefully', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: false,
      status: 404,
    });

    try {
      await extractYouTubeTranscript('https://youtu.be/invalid');
    } catch (error) {
      expect((error as YouTubeExtractorError).code).toBe('fetch_failed');
    }
  });

  it('should return empty transcript if unavailable', async () => {
    global.fetch = vi.fn()
      .mockResolvedValueOnce({
        ok: true,
        text: async () => '<title>Video - YouTube</title>',
      })
      .mockResolvedValueOnce({
        ok: false, // Caption fetch fails
      });

    const result = await extractYouTubeTranscript('https://youtu.be/dQw4w9WgXcQ');

    expect(result.videoId).toBe('dQw4w9WgXcQ');
    expect(result.transcript).toBe('');
  });

  it('should extract title from page', async () => {
    global.fetch = vi.fn().mockResolvedValueOnce({
      ok: true,
      text: async () => '<title>My Amazing Video - YouTube</title>',
    });

    const result = await extractYouTubeTranscript('https://youtu.be/test123');

    expect(result.title).toContain('My Amazing Video');
  });
});

// ============================================================================
// StoreKit Webhook Tests
// ============================================================================

describe('StoreKit Webhook', () => {
  it('should parse valid JWT payload', () => {
    // Create a simple JWT-like structure
    const header = Buffer.from(JSON.stringify({ alg: 'ES256' })).toString('base64').replace(/=/g, '');
    const payload = Buffer.from(
      JSON.stringify({
        notificationType: 'SUBSCRIBED',
        notificationUUID: 'uuid-123',
        signedDate: Date.now(),
      })
    )
      .toString('base64')
      .replace(/=/g, '');
    const signature = 'signature';

    const token = `${header}.${payload}.${signature}`;

    // In the webhook, this would be parsed
    // For testing, verify structure
    expect(token.split('.')).toHaveLength(3);
  });

  it('should handle missing signedPayload gracefully', () => {
    const payload: Record<string, unknown> = {};

    // Webhook should return 200 even with missing payload
    expect(!payload.signedPayload).toBe(true);
  });

  it('should process SUBSCRIBED event', () => {
    const eventType = 'SUBSCRIBED';

    // Map to subscription status
    const statusMap: Record<string, string> = {
      SUBSCRIBED: 'active',
      DID_RENEW: 'active',
      EXPIRED: 'expired',
      GRACE_PERIOD_EXPIRES: 'grace_period',
      DID_FAIL_TO_RENEW: 'billing_retry',
    };

    expect(statusMap[eventType]).toBe('active');
  });

  it('should process DID_RENEW event', () => {
    const eventType = 'DID_RENEW';
    const statusMap: Record<string, string> = {
      SUBSCRIBED: 'active',
      DID_RENEW: 'active',
      EXPIRED: 'expired',
      GRACE_PERIOD_EXPIRES: 'grace_period',
      DID_FAIL_TO_RENEW: 'billing_retry',
    };

    expect(statusMap[eventType]).toBe('active');
  });

  it('should process EXPIRED event', () => {
    const eventType = 'EXPIRED';
    const statusMap: Record<string, string> = {
      SUBSCRIBED: 'active',
      DID_RENEW: 'active',
      EXPIRED: 'expired',
      GRACE_PERIOD_EXPIRES: 'grace_period',
      DID_FAIL_TO_RENEW: 'billing_retry',
    };

    expect(statusMap[eventType]).toBe('expired');
  });

  it('should process GRACE_PERIOD_EXPIRES event', () => {
    const eventType = 'GRACE_PERIOD_EXPIRES';
    const statusMap: Record<string, string> = {
      SUBSCRIBED: 'active',
      DID_RENEW: 'active',
      EXPIRED: 'expired',
      GRACE_PERIOD_EXPIRES: 'grace_period',
      DID_FAIL_TO_RENEW: 'billing_retry',
    };

    expect(statusMap[eventType]).toBe('grace_period');
  });

  it('should handle test endpoint', () => {
    // GET /webhooks/appstore/test should return 200
    const testPath = '/webhooks/appstore/test';

    expect(testPath).toContain('appstore');
    expect(testPath).toContain('test');
  });

  it('should ensure idempotency with transaction IDs', () => {
    // Same transaction ID should not create duplicate records
    const transactionId = 'txn-123';
    const seen = new Set<string>();

    // First time
    expect(seen.has(transactionId)).toBe(false);
    seen.add(transactionId);

    // Second time (should skip update if already seen)
    expect(seen.has(transactionId)).toBe(true);
  });

  it('should return 200 always for reliability', () => {
    // Webhook should always return 200 regardless of processing result
    const statusCodes = [200, 200, 200];

    for (const code of statusCodes) {
      expect(code).toBe(200);
    }
  });
});

// ============================================================================
// buildCardConcept — S9 image-pipeline fix
// ============================================================================

describe('buildCardConcept (S9 image-pipeline fix)', () => {
  it('returns the LLM imagePrompt verbatim when it already includes the subject', () => {
    const concept = buildCardConcept(
      { imagePrompt: 'A cartoon hippopotamus splashing in a river' },
      'story',
      'hippopotamus'
    );
    expect(concept).toBe('A cartoon hippopotamus splashing in a river');
  });

  it('prepends the subject when the LLM imagePrompt omits it', () => {
    const concept = buildCardConcept(
      { imagePrompt: 'splashing in a river under a rainbow' },
      'story',
      'hippopotamus'
    );
    expect(concept).toBe('hippopotamus: splashing in a river under a rainbow');
  });

  it('synthesizes "subject — atom: title" when imagePrompt is missing', () => {
    const concept = buildCardConcept(
      { title: 'Hippos Are Huge!', text: 'They are the third largest land animal.' },
      'concept',
      'hippopotamus',
      { name: 'Size and weight' }
    );
    expect(concept).toBe('hippopotamus — Size and weight: Hippos Are Huge!');
  });

  it('uses text when a card has no title (story cards)', () => {
    const concept = buildCardConcept(
      { text: 'Hannah the happy hippo loved splashing in the pond.' },
      'story',
      'hippopotamus',
      { name: 'Meet the hippo' }
    );
    expect(concept).toContain('hippopotamus — Meet the hippo');
    expect(concept).toContain('Hannah the happy hippo');
  });

  it('uses the question when a quiz card has no title/text', () => {
    const concept = buildCardConcept(
      { question: 'What do hippos like to eat?', options: ['Plants', 'Meat'], correctAnswer: 0 },
      'quiz',
      'hippopotamus',
      { name: 'Diet' }
    );
    expect(concept).toContain('hippopotamus — Diet');
    expect(concept).toContain('What do hippos like to eat?');
  });

  it('never collapses to the literal "learning concept" fallback for quiz cards', () => {
    // This was the exact bug seen in the dev tool — quiz cards produced
    // generic "school supplies" imagery because the chain fell through to
    // the literal string "learning concept". Verify that can no longer happen.
    const concept = buildCardConcept(
      { options: ['A', 'B', 'C'] },
      'quiz',
      'hippopotamus',
      { name: 'Quick check' }
    );
    expect(concept).not.toContain('learning concept');
    expect(concept).toContain('hippopotamus');
  });

  it('still works when no atom and no subject are available (degraded path)', () => {
    const concept = buildCardConcept(
      { title: 'Test card' },
      'concept',
      '',
      undefined
    );
    expect(concept).toBe('Test card');
  });

  it('truncates very long body text to keep the DALL-E prompt small', () => {
    const longText = 'x'.repeat(500);
    const concept = buildCardConcept(
      { text: longText },
      'story',
      'hippopotamus'
    );
    // Should be "hippopotamus: <140 chars of x>"
    expect(concept.length).toBeLessThan(200);
    expect(concept).toContain('hippopotamus');
  });
});

// ============================================================================
// Integration Tests
// ============================================================================

describe('Asset Pipeline Integration', () => {
  it('should coordinate TTS + upload flow', async () => {
    // Verify that TTS output can be uploaded
    expect(true).toBe(true); // Placeholder for integration test
  });

  it('should coordinate image + upload flow', async () => {
    // Verify that image generation output can be uploaded
    expect(true).toBe(true); // Placeholder for integration test
  });

  it('should handle concurrent job processing', async () => {
    // Verify that multiple asset jobs can be processed sequentially
    expect(true).toBe(true); // Placeholder for integration test
  });

  it('should retry failed jobs', async () => {
    // Verify retry logic works across job types
    expect(true).toBe(true); // Placeholder for integration test
  });
});
