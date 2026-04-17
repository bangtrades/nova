/**
 * Mastery Tracker (Sprint 10 / S10-02 — "The Brain")
 *
 * Maintains a per-child, per-concept confidence score derived from quiz
 * results. The rules (S10-02 DoD):
 *
 *   - On correct answer:   confidence = min(1.0, confidence + 0.15)
 *   - On wrong answer:     confidence = max(0.0, confidence - 0.10)
 *   - Weekly decay:        0.02 per 7 calendar days without reinforcement
 *                          (applied lazily on read or before the next update).
 *
 * The pure math (`applyDecay`, `applyDelta`) is exported separately from the
 * Prisma-facing `recordQuizResult` function so tests can exercise the
 * invariants without spinning up a DB.
 *
 * Decay policy:
 *   We apply decay on-write (before compounding the new delta) AND on-read
 *   (when the dashboard / planner queries mastery). Applying it on-write
 *   means two successive correct answers separated by a month don't skip
 *   the intervening decay. Applying it on-read means the displayed score
 *   is always current without a nightly cron.
 *
 *   Importantly: we do NOT persist the decay on read. That would make
 *   reads costly and would introduce racy writes. We persist only on
 *   actual quiz events, where decay is naturally materialized.
 */

import { getPrismaClient } from '@db/client';

// ============================================================
// Tunable constants (S10-02 DoD)
// ============================================================
export const MASTERY_DELTA_CORRECT = 0.15;
export const MASTERY_DELTA_WRONG = -0.10;
export const MASTERY_CAP = 1.0;
export const MASTERY_FLOOR = 0.0;

/** Decay rate: 0.02 confidence per 7 calendar days. */
export const DECAY_RATE_PER_WEEK = 0.02;
export const MS_PER_DAY = 24 * 60 * 60 * 1000;
export const MS_PER_WEEK = 7 * MS_PER_DAY;

// ============================================================
// Pure functions (unit-testable without a DB)
// ============================================================

/** Clamp to [MASTERY_FLOOR, MASTERY_CAP]. */
export function clampConfidence(x: number): number {
  if (Number.isNaN(x)) return MASTERY_FLOOR;
  if (x < MASTERY_FLOOR) return MASTERY_FLOOR;
  if (x > MASTERY_CAP) return MASTERY_CAP;
  return x;
}

/**
 * Compute decayed confidence given a last-tested timestamp.
 *
 * If `lastTested` is null (never tested) or in the future (clock skew),
 * no decay is applied. Decay is continuous — a child who tested 3.5 days
 * ago has decayed by `(3.5 / 7) * 0.02 = 0.01`. Floors at 0.
 *
 * Exported for tests + for the read endpoint to apply on-the-fly.
 */
export function applyDecay(
  confidence: number,
  lastTested: Date | null | undefined,
  now: Date = new Date()
): number {
  if (lastTested == null) return clampConfidence(confidence);
  const elapsedMs = now.getTime() - lastTested.getTime();
  if (elapsedMs <= 0) return clampConfidence(confidence);
  const weeks = elapsedMs / MS_PER_WEEK;
  const decayed = confidence - weeks * DECAY_RATE_PER_WEEK;
  return clampConfidence(decayed);
}

/**
 * Compute the next confidence value given the current value, a quiz
 * outcome, and how much time has elapsed since the last test.
 *
 * Order of operations:
 *   1. Apply decay based on elapsed time since lastTested.
 *   2. Apply the ±delta for the current quiz outcome.
 *   3. Clamp.
 *
 * The pair (old, new) is returned so callers can log deltas if they want.
 */
export function applyDelta(
  currentConfidence: number,
  isCorrect: boolean,
  lastTested: Date | null | undefined,
  now: Date = new Date()
): { prior: number; decayed: number; next: number } {
  const prior = clampConfidence(currentConfidence);
  const decayed = applyDecay(prior, lastTested, now);
  const delta = isCorrect ? MASTERY_DELTA_CORRECT : MASTERY_DELTA_WRONG;
  const next = clampConfidence(decayed + delta);
  return { prior, decayed, next };
}

// ============================================================
// DB-facing API
// ============================================================

/** What the caller gives us — minimum viable data to record one quiz result. */
export interface QuizResultEvent {
  childId: string;
  conceptId: string;
  isCorrect: boolean;
  occurredAt?: Date; // defaults to now(); override for backfill
}

/** What we return — before + after confidence for logging / analytics. */
export interface MasteryUpdate {
  childId: string;
  conceptId: string;
  priorConfidence: number;
  decayedConfidence: number;
  nextConfidence: number;
  attempts: number;
  correctCount: number;
  wasFirstIntroduction: boolean;
}

/**
 * Record one quiz result and update the child's mastery on the linked concept.
 *
 * Idempotency: each call performs an upsert on (childId, conceptId) — a new
 * row is created the first time a child encounters a concept. `attempts`
 * always increments; `correctCount` increments only on correct answers.
 *
 * Safety: this function assumes `childId` and `conceptId` are valid.
 * Caller (the /progress/sync handler) has already verified child ownership
 * and received the conceptId from a Card lookup.
 */
export async function recordQuizResult(
  event: QuizResultEvent
): Promise<MasteryUpdate> {
  const prisma = getPrismaClient();
  const now = event.occurredAt ?? new Date();

  // Fetch existing row (if any) so we can compute next confidence with decay.
  const existing = await prisma.childConcept.findUnique({
    where: {
      childId_conceptId: {
        childId: event.childId,
        conceptId: event.conceptId,
      },
    },
  });

  const priorConfidence = existing?.confidence ?? 0.0;
  const lastTested = existing?.lastTested ?? null;
  const { prior, decayed, next } = applyDelta(
    priorConfidence,
    event.isCorrect,
    lastTested,
    now
  );

  const wasFirstIntroduction = !existing;

  const attempts = (existing?.attempts ?? 0) + 1;
  const correctCount = (existing?.correctCount ?? 0) + (event.isCorrect ? 1 : 0);

  await prisma.childConcept.upsert({
    where: {
      childId_conceptId: {
        childId: event.childId,
        conceptId: event.conceptId,
      },
    },
    create: {
      childId: event.childId,
      conceptId: event.conceptId,
      confidence: next,
      attempts: 1,
      correctCount: event.isCorrect ? 1 : 0,
      lastTested: now,
      firstIntroduced: now,
    },
    update: {
      confidence: next,
      attempts,
      correctCount,
      lastTested: now,
      // firstIntroduced: intentionally not touched on update
    },
  });

  return {
    childId: event.childId,
    conceptId: event.conceptId,
    priorConfidence: prior,
    decayedConfidence: decayed,
    nextConfidence: next,
    attempts,
    correctCount,
    wasFirstIntroduction,
  };
}

/**
 * Batch version — records several quiz results for one child in order.
 * Used by /progress/sync when a device uploads a session's worth of
 * interactions at once.
 *
 * Serial, not parallel — we want later events to see the effect of
 * earlier ones (attempts counter, compounding confidence).
 */
export async function recordQuizResultsBatch(
  events: QuizResultEvent[]
): Promise<MasteryUpdate[]> {
  const results: MasteryUpdate[] = [];
  for (const event of events) {
    results.push(await recordQuizResult(event));
  }
  return results;
}

// ============================================================
// Read side (applies decay on the fly)
// ============================================================

export interface MasteryRow {
  conceptId: string;
  conceptName: string;
  domain: string;
  difficulty: number;
  confidence: number;       // stored (pre-decay)
  effectiveConfidence: number; // decay applied up to `now`
  attempts: number;
  correctCount: number;
  lastTested: Date | null;
  firstIntroduced: Date | null;
}

/**
 * Return all concept-mastery rows for a child, with decay applied on the fly.
 * Rows are joined with the Concept table so callers get concept metadata
 * in one hop (used by the dev-console Knowledge Graph tab, and later by
 * the parent dashboard).
 */
export async function getChildMastery(
  childId: string,
  now: Date = new Date()
): Promise<MasteryRow[]> {
  const prisma = getPrismaClient();

  const rows = await prisma.childConcept.findMany({
    where: { childId },
    include: {
      concept: {
        select: { id: true, name: true, domain: true, difficulty: true },
      },
    },
    orderBy: [{ concept: { domain: 'asc' } }, { concept: { sortOrder: 'asc' } }],
  });

  return rows.map((r) => ({
    conceptId: r.conceptId,
    conceptName: r.concept.name,
    domain: r.concept.domain,
    difficulty: r.concept.difficulty,
    confidence: r.confidence,
    effectiveConfidence: applyDecay(r.confidence, r.lastTested, now),
    attempts: r.attempts,
    correctCount: r.correctCount,
    lastTested: r.lastTested,
    firstIntroduced: r.firstIntroduced,
  }));
}
