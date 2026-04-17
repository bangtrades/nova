/**
 * Pipeline utilities — stage timeout + bounded retry (S9-10 hardening).
 *
 * Extracted from the orchestrator so unit tests can exercise timeout + retry
 * semantics without spinning up an LLM mock. The orchestrator imports
 * `runStage` and wraps every LLM-facing call with it.
 */

export interface RunStageOptions {
  stageTimeoutMs: number;
  maxAttempts: number;
  retryBackoffMs: number;
}

export const DEFAULT_STAGE_OPTIONS: RunStageOptions = {
  stageTimeoutMs: 45_000,
  maxAttempts: 2,
  retryBackoffMs: 750,
};

/**
 * Run an async stage with a hard timeout and bounded retry.
 *
 * - Retries only on **transient** errors (timeout / network / 429 / 5xx).
 * - Validation / logic errors short-circuit immediately.
 * - Backoff is linear: `retryBackoffMs * attempt`.
 */
export async function runStage<T>(
  name: string,
  fn: () => Promise<T>,
  options: Partial<RunStageOptions> = {}
): Promise<T> {
  const opts = { ...DEFAULT_STAGE_OPTIONS, ...options };
  let lastError: unknown;

  for (let attempt = 1; attempt <= opts.maxAttempts; attempt++) {
    try {
      return await withTimeout(fn(), opts.stageTimeoutMs, `${name} stage timed out`);
    } catch (err) {
      lastError = err;
      if (attempt >= opts.maxAttempts || !isTransient(err)) break;
      // eslint-disable-next-line no-console
      console.warn(
        `[Pipeline] Stage "${name}" attempt ${attempt} failed (transient: ${errMsg(err)}), retrying...`
      );
      await sleep(opts.retryBackoffMs * attempt);
    }
  }

  throw lastError instanceof Error ? lastError : new Error(String(lastError));
}

/**
 * Wrap a promise with a timeout. If the inner promise doesn't settle within
 * `ms`, reject with a timeout error instead.
 */
export function withTimeout<T>(promise: Promise<T>, ms: number, message: string): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(
      () => reject(new Error(`${message} after ${ms}ms`)),
      ms
    );
    promise.then(
      (v) => {
        clearTimeout(timer);
        resolve(v);
      },
      (e) => {
        clearTimeout(timer);
        reject(e);
      }
    );
  });
}

/**
 * Classify an error as transient (worth retrying) vs. logic/validation.
 */
export function isTransient(err: unknown): boolean {
  const msg = errMsg(err).toLowerCase();
  return (
    msg.includes('timed out') ||
    msg.includes('timeout') ||
    msg.includes('econnreset') ||
    msg.includes('etimedout') ||
    msg.includes('fetch failed') ||
    msg.includes('rate limit') ||
    msg.includes('429') ||
    msg.includes('502') ||
    msg.includes('503') ||
    msg.includes('504')
  );
}

export function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
