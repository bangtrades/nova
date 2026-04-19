/**
 * Sliding-scale Effective Age (Sprint 10 — S10-06 supporting module)
 *
 * Computes a signed `progressionDelta ∈ [-1.5, +1.5]` from mastery,
 * engagement, session-event telemetry, and parent difficulty offset.
 * Effective age = chronological age + delta. The skill loader picks
 * the nearest age-profile anchor by effective age; the prompt layer
 * injects a short natural-language nudge derived from the delta.
 *
 * Motivation: we keep **three** age-profile anchors (4 / 6 / 8) as
 * landmarks rather than authoring per-year content. The LLM
 * interpolates between anchors given the modifier nudge.
 *
 * This module is PURE. No DB, no LLM, no I/O. Every signal weight
 * is a module constant so tuning is a one-line change that an A/B
 * sweep can run through `computeProgressionDelta()` in milliseconds.
 */
import type {
  ChildContext,
  EngagementSummary,
  MasteryEffective,
  SessionEventCounts,
} from './types';

// ---------------------------------------------------------------------------
// Tunable constants — all lift one-liners. Intentionally exported so
// tests can pin them (a test that silently adapts to weight changes is
// worse than useless).
// ---------------------------------------------------------------------------

/** Lower bound on the composed delta before clamping. */
export const PROGRESSION_DELTA_MIN = -1.5;
/** Upper bound on the composed delta before clamping. */
export const PROGRESSION_DELTA_MAX = 1.5;

/** Min attempts in the rolling window before mastery signals count. */
export const MASTERY_MIN_ATTEMPTS = 10;

/** Mastery average > this ⇒ high-mastery bonus applies. */
export const MASTERY_HIGH_THRESHOLD = 0.7;
/** Additive bonus for high mastery. */
export const MASTERY_HIGH_BONUS = 0.5;

/** Mastery average < this ⇒ low-mastery penalty applies. */
export const MASTERY_LOW_THRESHOLD = 0.4;
/** Additive penalty for persistently low mastery. */
export const MASTERY_LOW_PENALTY = 0.3;

/** Quiz win rate > this ⇒ apply bonus. */
export const QUIZ_WIN_RATE_THRESHOLD = 0.8;
/** Additive bonus for high quiz win rate. */
export const QUIZ_WIN_RATE_BONUS = 0.3;

/** Per-event contribution for flow events in the 7d window. */
export const FLOW_PER_EVENT_BONUS = 0.1;
/** Hard cap on how many flow events are counted (anti-farming). */
export const FLOW_EVENT_CAP = 3;

/** Frustration events ≥ this count ⇒ apply penalty. */
export const FRUSTRATION_EVENT_THRESHOLD = 2;
/** Additive penalty when frustration threshold hit. */
export const FRUSTRATION_PENALTY = 0.5;

/** Multiplier applied to parent difficulty offset (−2..+2) before adding. */
export const PARENT_OFFSET_MULTIPLIER = 0.4;

/** Lowest effective age we will expose to profile selection. */
export const EFFECTIVE_AGE_MIN = 3;
/** Highest effective age we will expose to profile selection. */
export const EFFECTIVE_AGE_MAX = 14;

// ---------------------------------------------------------------------------
// Public signal shape
// ---------------------------------------------------------------------------

/**
 * Minimal input set for `computeProgressionDelta`. All fields optional so
 * the function degrades gracefully — a cold-start child returns 0.
 */
export interface ProgressionSignals {
  mastery?: MasteryEffective;
  engagement?: EngagementSummary;
  recentSessionEvents?: SessionEventCounts;
  /** -2..+2 (clamped upstream). Multiplied by PARENT_OFFSET_MULTIPLIER. */
  parentDifficultyOffset?: number;
}

/**
 * Per-signal breakdown returned alongside the scalar delta, for the Dev
 * Console Progression readout. Same shape as the ranker's breakdown
 * fields in teachingStrategy, so the UI can reuse styling.
 */
export interface ProgressionBreakdown {
  total: number;
  masteryContribution: number;
  quizWinRateContribution: number;
  flowContribution: number;
  frustrationContribution: number;
  parentOffsetContribution: number;
}

// ---------------------------------------------------------------------------
// Core pure functions
// ---------------------------------------------------------------------------

/**
 * Compute the signed progression delta plus a per-signal breakdown.
 * Stable: same inputs ⇒ same output (no Date.now, no randomness).
 */
export function computeProgressionBreakdown(
  signals: ProgressionSignals
): ProgressionBreakdown {
  let mastery = 0;
  let quiz = 0;
  let flow = 0;
  let frustration = 0;
  let parent = 0;

  // Mastery — only counts when the child has enough attempts for a
  // signal to be reliable. High mastery earns a bonus; low mastery
  // earns a smaller penalty (we're more cautious about penalizing).
  if (signals.mastery) {
    const { averageScore, totalAttempts } = signals.mastery;
    if (
      Number.isFinite(averageScore) &&
      Number.isFinite(totalAttempts) &&
      totalAttempts >= MASTERY_MIN_ATTEMPTS
    ) {
      if (averageScore > MASTERY_HIGH_THRESHOLD) {
        mastery = MASTERY_HIGH_BONUS;
      } else if (averageScore < MASTERY_LOW_THRESHOLD) {
        mastery = -MASTERY_LOW_PENALTY;
      }
    }
  }

  // Quiz win rate — a fast-response signal, applies as soon as the
  // 14d window has enough data (left to the engagement builder).
  if (signals.engagement && Number.isFinite(signals.engagement.recentQuizWinRate)) {
    if (signals.engagement.recentQuizWinRate > QUIZ_WIN_RATE_THRESHOLD) {
      quiz = QUIZ_WIN_RATE_BONUS;
    }
  }

  // Session-event layering. Flow events compound linearly up to the
  // cap; frustration is threshold-based (a single off day shouldn't
  // penalize — two+ says something real). Abandon events don't
  // contribute here; they feed the engagement profile indirectly.
  if (signals.recentSessionEvents) {
    const flowCount = Math.max(
      0,
      Math.min(
        FLOW_EVENT_CAP,
        Math.floor(signals.recentSessionEvents.flow ?? 0)
      )
    );
    flow = flowCount * FLOW_PER_EVENT_BONUS;
    const frustrationCount = Math.max(0, signals.recentSessionEvents.frustration ?? 0);
    if (frustrationCount >= FRUSTRATION_EVENT_THRESHOLD) {
      frustration = -FRUSTRATION_PENALTY;
    }
  }

  // Parent offset — the only manual knob. Linear: ±2 ⇒ ±0.8.
  if (
    typeof signals.parentDifficultyOffset === 'number' &&
    Number.isFinite(signals.parentDifficultyOffset)
  ) {
    parent = signals.parentDifficultyOffset * PARENT_OFFSET_MULTIPLIER;
  }

  const raw = mastery + quiz + flow + frustration + parent;
  const total = clamp(raw, PROGRESSION_DELTA_MIN, PROGRESSION_DELTA_MAX);

  return {
    total: round(total),
    masteryContribution: round(mastery),
    quizWinRateContribution: round(quiz),
    flowContribution: round(flow),
    frustrationContribution: round(frustration),
    parentOffsetContribution: round(parent),
  };
}

/**
 * Scalar-only convenience. Equivalent to `computeProgressionBreakdown(...).total`.
 */
export function computeProgressionDelta(signals: ProgressionSignals): number {
  return computeProgressionBreakdown(signals).total;
}

/**
 * Chronological → effective age. Clamped to a physically plausible
 * range so the profile selector can never be handed a nonsense anchor.
 */
export function computeEffectiveAge(
  ageYears: number,
  delta: number
): number {
  // Treat NaN as "unknown" ⇒ 0 contribution. Infinity propagates so the
  // clamp can pin to the correct extreme (callers passing ±Infinity
  // probably mean "push as far as you can").
  const safeAge = Number.isNaN(ageYears) ? 0 : ageYears;
  const safeDelta = Number.isNaN(delta) ? 0 : delta;
  const raw = safeAge + safeDelta;
  return round(clamp(raw, EFFECTIVE_AGE_MIN, EFFECTIVE_AGE_MAX));
}

/**
 * Pick the nearest anchor in `anchors` to `effectiveAge`. Ties round
 * *down* (err toward simpler). Out-of-range effective ages clamp to
 * the first/last anchor before the nearest-search runs.
 *
 * Anchors are caller-provided (per-skill from the manifest) so
 * quiz-maker can stay on 4/6/8 while a future skill could pick
 * different landmarks.
 */
export function selectAgeProfile(
  anchors: readonly number[],
  effectiveAge: number
): number {
  if (!anchors || anchors.length === 0) {
    throw new Error('selectAgeProfile: no anchors provided');
  }
  const sorted = [...anchors].sort((a, b) => a - b);
  const low = sorted[0]!;
  const high = sorted[sorted.length - 1]!;
  const clamped = clamp(Number.isFinite(effectiveAge) ? effectiveAge : low, low, high);

  let best = sorted[0]!;
  let bestDist = Math.abs(best - clamped);
  for (let i = 1; i < sorted.length; i++) {
    const a = sorted[i]!;
    const d = Math.abs(a - clamped);
    if (d < bestDist) {
      best = a;
      bestDist = d;
    } else if (d === bestDist && a < best) {
      // Tie ⇒ round toward the simpler (lower) anchor.
      best = a;
    }
  }
  return best;
}

/**
 * Convenience: extract progression-relevant signals from a ChildContext.
 * Used by `buildChildContext()` in S10-12 and by the Dev Console.
 */
export function signalsFromContext(ctx: Pick<
  ChildContext,
  'mastery' | 'engagement' | 'recentSessionEvents' | 'difficultyOffset'
>): ProgressionSignals {
  return {
    mastery: ctx.mastery,
    engagement: ctx.engagement,
    recentSessionEvents: ctx.recentSessionEvents,
    parentDifficultyOffset: ctx.difficultyOffset,
  };
}

// ---------------------------------------------------------------------------
// Small private helpers
// ---------------------------------------------------------------------------

function clamp(v: number, lo: number, hi: number): number {
  if (Number.isNaN(v)) return lo;
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

function round(v: number): number {
  // 3-decimal place rounding keeps JSON dumps readable without
  // introducing user-visible precision drift in tests.
  return Math.round(v * 1000) / 1000;
}
