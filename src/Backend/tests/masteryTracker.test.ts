import { describe, it, expect } from 'vitest';
import {
  applyDecay,
  applyDelta,
  clampConfidence,
  MASTERY_CAP,
  MASTERY_FLOOR,
  MASTERY_DELTA_CORRECT,
  MASTERY_DELTA_WRONG,
  DECAY_RATE_PER_WEEK,
  MS_PER_DAY,
  MS_PER_WEEK,
} from '../src/services/mastery/masteryTracker';

// ============================================================
// S10-02 — Mastery tracker pure-math invariants
// Do not require a DB — these exercise the functions that run
// inside recordQuizResult() before the upsert.
// ============================================================

const NOW = new Date('2026-04-16T12:00:00Z');

describe('masteryTracker — clampConfidence (S10-02)', () => {
  it('returns the value unchanged inside [0, 1]', () => {
    expect(clampConfidence(0)).toBe(0);
    expect(clampConfidence(0.5)).toBe(0.5);
    expect(clampConfidence(1)).toBe(1);
  });

  it('clamps negatives to the floor', () => {
    expect(clampConfidence(-0.3)).toBe(MASTERY_FLOOR);
  });

  it('clamps values above 1 to the cap', () => {
    expect(clampConfidence(1.7)).toBe(MASTERY_CAP);
  });

  it('maps NaN to the floor, not to NaN', () => {
    expect(clampConfidence(Number.NaN)).toBe(MASTERY_FLOOR);
  });
});

describe('masteryTracker — applyDelta bounds (S10-02)', () => {
  it('a correct answer adds +0.15', () => {
    const r = applyDelta(0.40, true, NOW, NOW);
    expect(r.next).toBeCloseTo(0.40 + MASTERY_DELTA_CORRECT, 5);
  });

  it('a wrong answer subtracts 0.10', () => {
    const r = applyDelta(0.40, false, NOW, NOW);
    expect(r.next).toBeCloseTo(0.40 + MASTERY_DELTA_WRONG, 5);
  });

  it('never exceeds 1.0 on correct from near-cap', () => {
    const r = applyDelta(0.95, true, NOW, NOW);
    expect(r.next).toBe(MASTERY_CAP);
  });

  it('never goes below 0.0 on wrong from near-floor', () => {
    const r = applyDelta(0.05, false, NOW, NOW);
    expect(r.next).toBe(MASTERY_FLOOR);
  });

  it('returns the trio (prior, decayed, next) so callers can log deltas', () => {
    const r = applyDelta(0.5, true, NOW, NOW);
    expect(r).toHaveProperty('prior');
    expect(r).toHaveProperty('decayed');
    expect(r).toHaveProperty('next');
  });
});

describe('masteryTracker — applyDecay (S10-02)', () => {
  it('applies no decay when lastTested is null (first introduction)', () => {
    expect(applyDecay(0.50, null, NOW)).toBeCloseTo(0.50, 5);
  });

  it('applies no decay when lastTested is in the future (clock skew)', () => {
    const future = new Date(NOW.getTime() + 3 * MS_PER_DAY);
    expect(applyDecay(0.50, future, NOW)).toBeCloseTo(0.50, 5);
  });

  it('decays exactly 0.02 after 7 days without reinforcement', () => {
    const weekAgo = new Date(NOW.getTime() - MS_PER_WEEK);
    expect(applyDecay(0.50, weekAgo, NOW)).toBeCloseTo(0.50 - DECAY_RATE_PER_WEEK, 5);
  });

  it('decays proportionally for fractional weeks', () => {
    // 3.5 days ago = half a week = -0.01
    const halfWeekAgo = new Date(NOW.getTime() - MS_PER_WEEK / 2);
    expect(applyDecay(0.50, halfWeekAgo, NOW)).toBeCloseTo(0.50 - DECAY_RATE_PER_WEEK / 2, 5);
  });

  it('cannot decay below zero (100 weeks of silence still clamps)', () => {
    const ancient = new Date(NOW.getTime() - 100 * MS_PER_WEEK);
    expect(applyDecay(0.30, ancient, NOW)).toBe(MASTERY_FLOOR);
  });
});

describe('masteryTracker — decay + delta composition (S10-02)', () => {
  it('applies decay BEFORE the correct delta (not after)', () => {
    // Prior = 0.50, last tested 1 week ago, correct answer.
    // Decay → 0.48, then +0.15 → 0.63
    const weekAgo = new Date(NOW.getTime() - MS_PER_WEEK);
    const r = applyDelta(0.50, true, weekAgo, NOW);
    expect(r.decayed).toBeCloseTo(0.48, 5);
    expect(r.next).toBeCloseTo(0.63, 5);
  });

  it('applies decay BEFORE the wrong delta (not after)', () => {
    // Prior = 0.50, last tested 1 week ago, wrong answer.
    // Decay → 0.48, then -0.10 → 0.38
    const weekAgo = new Date(NOW.getTime() - MS_PER_WEEK);
    const r = applyDelta(0.50, false, weekAgo, NOW);
    expect(r.decayed).toBeCloseTo(0.48, 5);
    expect(r.next).toBeCloseTo(0.38, 5);
  });

  it('two successive correct answers with no decay in between cap at 1.0', () => {
    // 0.90 → +0.15 → 1.00 (capped) → +0.15 → 1.00 (still capped)
    const r1 = applyDelta(0.90, true, NOW, NOW);
    expect(r1.next).toBe(MASTERY_CAP);
    const r2 = applyDelta(r1.next, true, NOW, NOW);
    expect(r2.next).toBe(MASTERY_CAP);
  });

  it('long silence + wrong answer still floors at 0', () => {
    const monthsAgo = new Date(NOW.getTime() - 20 * MS_PER_WEEK);
    const r = applyDelta(0.10, false, monthsAgo, NOW);
    expect(r.next).toBe(MASTERY_FLOOR);
  });

  it('monotonic property — correct answer never lowers next below decayed-prior', () => {
    // Regardless of decay, a correct answer should produce a value >= the
    // post-decay value (because delta is positive).
    const weekAgo = new Date(NOW.getTime() - MS_PER_WEEK);
    const r = applyDelta(0.3, true, weekAgo, NOW);
    expect(r.next).toBeGreaterThanOrEqual(r.decayed);
  });

  it('monotonic property — wrong answer never raises next above decayed-prior', () => {
    const weekAgo = new Date(NOW.getTime() - MS_PER_WEEK);
    const r = applyDelta(0.3, false, weekAgo, NOW);
    expect(r.next).toBeLessThanOrEqual(r.decayed);
  });
});

describe('masteryTracker — constant sanity (S10-02)', () => {
  it('honors the S10-02 DoD numbers exactly', () => {
    // Named so future refactors don't quietly drift the rule.
    expect(MASTERY_DELTA_CORRECT).toBe(0.15);
    expect(MASTERY_DELTA_WRONG).toBe(-0.10);
    expect(DECAY_RATE_PER_WEEK).toBe(0.02);
    expect(MASTERY_CAP).toBe(1.0);
    expect(MASTERY_FLOOR).toBe(0.0);
    expect(MS_PER_WEEK).toBe(7 * 24 * 60 * 60 * 1000);
  });
});
