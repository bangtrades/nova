import { describe, it, expect } from 'vitest';
import {
  bucketForHour24,
  resolveTimezone,
  sessionMinutesSince,
  getLocalWallClock,
  localStartOfDayUtc,
  buildSessionContextFrom,
  type TimeOfDayBucket,
} from '../src/services/context/sessionContext';

// ============================================================
// S10-05 — Session-aware context engine (DST-safe)
// Pure-reducer tests — no DB. These verify the Intl-backed
// timezone math survives the ugly cases (DST transitions,
// bad zones, clock skew, timezone divergence).
// ============================================================

describe('sessionContext — bucketForHour24 (S10-05)', () => {
  it('maps every valid hour to the documented bucket', () => {
    const expected: Record<number, TimeOfDayBucket> = {
      0: 'night',
      1: 'night',
      2: 'night',
      3: 'night',
      4: 'night',
      5: 'earlyMorning',
      6: 'earlyMorning',
      7: 'earlyMorning',
      8: 'morning',
      9: 'morning',
      10: 'morning',
      11: 'morning',
      12: 'afternoon',
      13: 'afternoon',
      14: 'afternoon',
      15: 'afternoon',
      16: 'afternoon',
      17: 'evening',
      18: 'evening',
      19: 'evening',
      20: 'night',
      21: 'night',
      22: 'night',
      23: 'night',
    };
    for (let h = 0; h <= 23; h++) {
      expect(bucketForHour24(h)).toBe(expected[h]);
    }
  });

  it('defaults to "night" on invalid inputs', () => {
    expect(bucketForHour24(-1)).toBe('night');
    expect(bucketForHour24(24)).toBe('night');
    expect(bucketForHour24(NaN)).toBe('night');
    expect(bucketForHour24(Infinity)).toBe('night');
  });
});

describe('sessionContext — resolveTimezone (S10-05)', () => {
  it('accepts common valid IANA zones', () => {
    expect(resolveTimezone('America/New_York')).toBe('America/New_York');
    expect(resolveTimezone('America/Los_Angeles')).toBe('America/Los_Angeles');
    expect(resolveTimezone('Europe/London')).toBe('Europe/London');
    expect(resolveTimezone('Asia/Tokyo')).toBe('Asia/Tokyo');
    expect(resolveTimezone('UTC')).toBe('UTC');
  });

  it('falls back to UTC on empty / null / undefined', () => {
    expect(resolveTimezone('')).toBe('UTC');
    expect(resolveTimezone('   ')).toBe('UTC');
    expect(resolveTimezone(null)).toBe('UTC');
    expect(resolveTimezone(undefined)).toBe('UTC');
  });

  it('falls back to UTC on obviously invalid inputs', () => {
    expect(resolveTimezone('Mars/Olympus_Mons')).toBe('UTC');
    expect(resolveTimezone('Not_A_Zone')).toBe('UTC');
    expect(resolveTimezone('America/Atlantis')).toBe('UTC');
  });
});

describe('sessionContext — sessionMinutesSince (S10-05)', () => {
  const NOW = new Date('2026-04-17T15:00:00Z');

  it('returns null when no session is active', () => {
    expect(sessionMinutesSince(null, NOW)).toBeNull();
  });

  it('returns 0 for zero elapsed', () => {
    expect(sessionMinutesSince(NOW, NOW)).toBe(0);
  });

  it('computes positive minute deltas correctly', () => {
    const start = new Date(NOW.getTime() - 45 * 60_000);
    expect(sessionMinutesSince(start, NOW)).toBe(45);
  });

  it('clamps negatives (clock skew) to 0', () => {
    const skewedFuture = new Date(NOW.getTime() + 5 * 60_000);
    expect(sessionMinutesSince(skewedFuture, NOW)).toBe(0);
  });

  it('caps at 180 minutes (forgotten-tab guard)', () => {
    const start = new Date(NOW.getTime() - 9 * 60 * 60_000); // 9 hours
    expect(sessionMinutesSince(start, NOW)).toBe(180);
  });
});

describe('sessionContext — getLocalWallClock DST edge cases (S10-05)', () => {
  // Spring-forward in America/New_York 2025: 02:00 EST → 03:00 EDT on March 9.
  // At 2025-03-09 06:30 UTC, wall clock in NYC is 02:30 EST? Actually no — EST is
  // UTC-5, so 06:30 UTC = 01:30 EST BEFORE the transition. After 07:00 UTC the
  // zone switches to EDT (UTC-4), so 07:30 UTC = 03:30 EDT.
  it('spring-forward: 2025-03-09 06:30 UTC reads as 01:30 local in NYC (pre-transition)', () => {
    const utc = new Date('2025-03-09T06:30:00Z');
    const wc = getLocalWallClock(utc, 'America/New_York');
    expect(wc.clock).toBe('01:30');
    expect(wc.hour24).toBe(1);
    expect(wc.weekday).toBe('Sunday');
  });

  it('spring-forward: 2025-03-09 07:30 UTC reads as 03:30 local in NYC (post-transition)', () => {
    const utc = new Date('2025-03-09T07:30:00Z');
    const wc = getLocalWallClock(utc, 'America/New_York');
    // After spring-forward the zone is EDT (UTC-4), so 07:30 UTC = 03:30 local.
    expect(wc.clock).toBe('03:30');
    expect(wc.hour24).toBe(3);
  });

  // Fall-back in America/New_York 2025: 02:00 EDT → 01:00 EST on Nov 2.
  // 1:30am happens TWICE — once at 05:30 UTC (EDT) and once at 06:30 UTC (EST).
  it('fall-back: 2025-11-02 05:30 UTC reads as 01:30 local (first 1:30am, still EDT)', () => {
    const utc = new Date('2025-11-02T05:30:00Z');
    const wc = getLocalWallClock(utc, 'America/New_York');
    expect(wc.clock).toBe('01:30');
    expect(wc.hour24).toBe(1);
  });

  it('fall-back: 2025-11-02 06:30 UTC reads as 01:30 local again (second 1:30am, now EST)', () => {
    const utc = new Date('2025-11-02T06:30:00Z');
    const wc = getLocalWallClock(utc, 'America/New_York');
    // Same wall-clock reading, different UTC instant — Intl handles this correctly.
    expect(wc.clock).toBe('01:30');
    expect(wc.hour24).toBe(1);
  });

  it('both 1:30am readings fall into the same night bucket', () => {
    const firstUtc = new Date('2025-11-02T05:30:00Z');
    const secondUtc = new Date('2025-11-02T06:30:00Z');
    const b1 = bucketForHour24(getLocalWallClock(firstUtc, 'America/New_York').hour24);
    const b2 = bucketForHour24(getLocalWallClock(secondUtc, 'America/New_York').hour24);
    expect(b1).toBe('night');
    expect(b2).toBe('night');
  });
});

describe('sessionContext — timezone divergence (S10-05)', () => {
  it('same UTC instant lands in different buckets for Pacific vs Eastern', () => {
    // 2026-04-17 18:00 UTC = 14:00 EDT in NYC (afternoon), 11:00 PDT in LA (morning).
    const utc = new Date('2026-04-17T18:00:00Z');
    const nyWc = getLocalWallClock(utc, 'America/New_York');
    const laWc = getLocalWallClock(utc, 'America/Los_Angeles');
    expect(nyWc.hour24).toBe(14);
    expect(laWc.hour24).toBe(11);
    expect(bucketForHour24(nyWc.hour24)).toBe('afternoon');
    expect(bucketForHour24(laWc.hour24)).toBe('morning');
  });

  it('UTC evening is early morning in Tokyo (next day)', () => {
    // 2026-04-17 22:00 UTC = 07:00 next-day in Tokyo (earlyMorning bucket).
    const utc = new Date('2026-04-17T22:00:00Z');
    const tokyoWc = getLocalWallClock(utc, 'Asia/Tokyo');
    expect(tokyoWc.hour24).toBe(7);
    expect(bucketForHour24(tokyoWc.hour24)).toBe('earlyMorning');
  });
});

describe('sessionContext — localStartOfDayUtc (S10-05)', () => {
  it('returns the UTC instant for local midnight in NYC (post-DST)', () => {
    // 2026-04-17 18:00 UTC → local midnight (April 17) in NYC is 04:00 UTC.
    const utc = new Date('2026-04-17T18:00:00Z');
    const midnight = localStartOfDayUtc(utc, 'America/New_York');
    // 04:00 UTC = 00:00 EDT on April 17.
    expect(midnight.toISOString()).toBe('2026-04-17T04:00:00.000Z');
  });

  it('returns the UTC instant for local midnight in LA', () => {
    const utc = new Date('2026-04-17T18:00:00Z');
    const midnight = localStartOfDayUtc(utc, 'America/Los_Angeles');
    // 07:00 UTC = 00:00 PDT on April 17.
    expect(midnight.toISOString()).toBe('2026-04-17T07:00:00.000Z');
  });

  it('returns the UTC instant unchanged for UTC zone', () => {
    const utc = new Date('2026-04-17T18:00:00Z');
    const midnight = localStartOfDayUtc(utc, 'UTC');
    expect(midnight.toISOString()).toBe('2026-04-17T00:00:00.000Z');
  });

  it('handles bad zone by falling back to UTC midnight', () => {
    const utc = new Date('2026-04-17T18:00:00Z');
    const midnight = localStartOfDayUtc(utc, 'Mars/Olympus_Mons');
    expect(midnight.toISOString()).toBe('2026-04-17T00:00:00.000Z');
  });
});

describe('sessionContext — buildSessionContextFrom (S10-05 reducer)', () => {
  const NOW = new Date('2026-04-17T18:00:00Z'); // 14:00 EDT / 11:00 PDT

  it('produces a zero-state context with no session / no streak', () => {
    const ctx = buildSessionContextFrom({
      ianaTimezone: 'America/New_York',
      now: NOW,
      sessionStartedAt: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    });
    expect(ctx.ianaTimezone).toBe('America/New_York');
    expect(ctx.localClock).toBe('14:00');
    expect(ctx.timeOfDay).toBe('afternoon');
    expect(ctx.currentSessionMinutes).toBeNull();
    expect(ctx.lessonsCompletedToday).toBe(0);
    expect(ctx.currentStreak).toBe(0);
    expect(ctx.recentQuizResults).toEqual([]);
  });

  it('echoes an active-session duration', () => {
    const start = new Date(NOW.getTime() - 12 * 60_000);
    const ctx = buildSessionContextFrom({
      ianaTimezone: 'America/New_York',
      now: NOW,
      sessionStartedAt: start,
      lessonsCompletedToday: 2,
      currentStreak: 5,
      recentQuizResults: [
        { outcome: 'correct', durationMinutes: 1, at: '2026-04-17T17:45:00Z' },
        { outcome: 'correct', durationMinutes: 2, at: '2026-04-17T17:40:00Z' },
      ],
    });
    expect(ctx.currentSessionMinutes).toBe(12);
    expect(ctx.lessonsCompletedToday).toBe(2);
    expect(ctx.currentStreak).toBe(5);
    expect(ctx.recentQuizResults).toHaveLength(2);
  });

  it('clamps negative counts and excessive recent results', () => {
    const many = Array.from({ length: 25 }, (_, i) => ({
      outcome: 'correct' as const,
      durationMinutes: 1,
      at: new Date(NOW.getTime() - i * 60_000).toISOString(),
    }));
    const ctx = buildSessionContextFrom({
      ianaTimezone: 'America/New_York',
      now: NOW,
      sessionStartedAt: null,
      lessonsCompletedToday: -5,
      currentStreak: -1,
      recentQuizResults: many,
    });
    expect(ctx.lessonsCompletedToday).toBe(0);
    expect(ctx.currentStreak).toBe(0);
    expect(ctx.recentQuizResults).toHaveLength(10);
  });

  it('routes invalid timezone through resolveTimezone → UTC', () => {
    const ctx = buildSessionContextFrom({
      ianaTimezone: 'Mars/Olympus_Mons',
      now: NOW,
      sessionStartedAt: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    });
    expect(ctx.ianaTimezone).toBe('UTC');
    expect(ctx.localClock).toBe('18:00');
    expect(ctx.timeOfDay).toBe('evening');
  });

  it('returns a consistent shape across DST spring-forward', () => {
    // 2025-03-09 06:30 UTC (pre-transition in NYC — 01:30 local)
    // and 07:30 UTC (post-transition — 03:30 local). Both valid.
    const preShift = new Date('2025-03-09T06:30:00Z');
    const postShift = new Date('2025-03-09T07:30:00Z');
    const pre = buildSessionContextFrom({
      ianaTimezone: 'America/New_York',
      now: preShift,
      sessionStartedAt: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    });
    const post = buildSessionContextFrom({
      ianaTimezone: 'America/New_York',
      now: postShift,
      sessionStartedAt: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    });
    expect(pre.localClock).toBe('01:30');
    expect(post.localClock).toBe('03:30');
    // 02:30 never gets emitted on that date — Intl simply never produces it.
    expect(pre.timeOfDay).toBe('night');
    expect(post.timeOfDay).toBe('night');
  });
});
