import { describe, it, expect, vi } from 'vitest';
import {
  runStage,
  withTimeout,
  isTransient,
  errMsg,
  sleep,
  DEFAULT_STAGE_OPTIONS,
} from '../src/services/pipeline/pipelineUtils';

describe('pipelineUtils — withTimeout (S9-10)', () => {
  it('resolves when the inner promise beats the timeout', async () => {
    const p = withTimeout(Promise.resolve('ok'), 50, 'stage');
    await expect(p).resolves.toBe('ok');
  });

  it('rejects with a timeout error when the inner promise is slow', async () => {
    const slow = new Promise<string>((resolve) => setTimeout(() => resolve('late'), 50));
    await expect(withTimeout(slow, 10, 'slow stage')).rejects.toThrow(/slow stage.*after 10ms/);
  });

  it('propagates inner rejections verbatim', async () => {
    const err = new Error('boom');
    await expect(withTimeout(Promise.reject(err), 50, 'stage')).rejects.toBe(err);
  });
});

describe('pipelineUtils — isTransient (S9-10)', () => {
  it('flags timeout-related messages as transient', () => {
    expect(isTransient(new Error('stage timed out after 1000ms'))).toBe(true);
    expect(isTransient(new Error('ETIMEDOUT while connecting'))).toBe(true);
  });

  it('flags network errors as transient', () => {
    expect(isTransient(new Error('ECONNRESET'))).toBe(true);
    expect(isTransient(new Error('fetch failed'))).toBe(true);
  });

  it('flags HTTP 429 / 5xx responses as transient', () => {
    expect(isTransient(new Error('HTTP 429 rate limit exceeded'))).toBe(true);
    expect(isTransient(new Error('upstream returned 502 Bad Gateway'))).toBe(true);
    expect(isTransient(new Error('503 Service Unavailable'))).toBe(true);
    expect(isTransient(new Error('504 Gateway Timeout'))).toBe(true);
  });

  it('does NOT flag logic / validation errors as transient', () => {
    expect(isTransient(new Error('Invalid input: missing field `topic`'))).toBe(false);
    expect(isTransient(new Error('Unauthorized'))).toBe(false);
    expect(isTransient(new Error('schema validation failed'))).toBe(false);
  });

  it('is case-insensitive on the message', () => {
    expect(isTransient(new Error('Request Timed Out'))).toBe(true);
    expect(isTransient(new Error('FETCH FAILED'))).toBe(true);
  });
});

describe('pipelineUtils — runStage (S9-10)', () => {
  it('returns successfully on the first attempt', async () => {
    const fn = vi.fn().mockResolvedValue(42);
    const result = await runStage('happy', fn, { maxAttempts: 3, retryBackoffMs: 1 });
    expect(result).toBe(42);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('retries transient errors up to maxAttempts', async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error('503 Service Unavailable'))
      .mockResolvedValueOnce('recovered');

    const result = await runStage('retry-ok', fn, {
      maxAttempts: 2,
      retryBackoffMs: 1,
      stageTimeoutMs: 1000,
    });
    expect(result).toBe('recovered');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('does NOT retry non-transient errors', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('Invalid JSON from model'));
    await expect(
      runStage('no-retry', fn, { maxAttempts: 3, retryBackoffMs: 1, stageTimeoutMs: 1000 })
    ).rejects.toThrow(/Invalid JSON/);
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it('gives up after maxAttempts even on transient errors', async () => {
    const fn = vi.fn().mockRejectedValue(new Error('fetch failed'));
    await expect(
      runStage('exhausted', fn, { maxAttempts: 3, retryBackoffMs: 1, stageTimeoutMs: 1000 })
    ).rejects.toThrow(/fetch failed/);
    expect(fn).toHaveBeenCalledTimes(3);
  });

  it('enforces the per-stage timeout and retries it (timeout is transient)', async () => {
    let calls = 0;
    const fn = vi.fn().mockImplementation(() => {
      calls++;
      if (calls === 1) {
        // first call never resolves until after timeout
        return new Promise((resolve) => setTimeout(() => resolve('late'), 200));
      }
      return Promise.resolve('fast');
    });

    const result = await runStage('timeout-retry', fn, {
      maxAttempts: 2,
      retryBackoffMs: 1,
      stageTimeoutMs: 20,
    });
    expect(result).toBe('fast');
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it('wraps non-Error rejections in Error', async () => {
    const fn = vi.fn().mockRejectedValue('string-error');
    await expect(
      runStage('wrap', fn, { maxAttempts: 1, retryBackoffMs: 1, stageTimeoutMs: 1000 })
    ).rejects.toBeInstanceOf(Error);
  });

  it('uses DEFAULT_STAGE_OPTIONS when none provided', async () => {
    // Just verify the defaults are sane and the call works
    const fn = vi.fn().mockResolvedValue('default-ok');
    const result = await runStage('defaults', fn);
    expect(result).toBe('default-ok');
    expect(DEFAULT_STAGE_OPTIONS.maxAttempts).toBeGreaterThanOrEqual(1);
    expect(DEFAULT_STAGE_OPTIONS.stageTimeoutMs).toBeGreaterThan(0);
    expect(DEFAULT_STAGE_OPTIONS.retryBackoffMs).toBeGreaterThanOrEqual(0);
  });
});

describe('pipelineUtils — errMsg + sleep helpers (S9-10)', () => {
  it('errMsg extracts message from Error instances', () => {
    expect(errMsg(new Error('hello'))).toBe('hello');
  });

  it('errMsg stringifies non-Error values', () => {
    expect(errMsg('raw string')).toBe('raw string');
    expect(errMsg(42)).toBe('42');
    expect(errMsg(null)).toBe('null');
  });

  it('sleep resolves after roughly the requested interval', async () => {
    const start = Date.now();
    await sleep(15);
    const elapsed = Date.now() - start;
    // Allow generous slack for CI jitter
    expect(elapsed).toBeGreaterThanOrEqual(10);
  });
});
