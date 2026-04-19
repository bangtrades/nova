/**
 * S10-06 Progression (sliding-scale effective age) — unit tests.
 *
 * The progression module is pure. Tests lock each signal in isolation,
 * verify the clamps, and confirm the nearest-with-ties-round-down
 * profile selector. Constants are imported and pinned — if we tune a
 * weight, the diff should make the intent loud.
 */
import { describe, it, expect } from 'vitest';
import {
  computeProgressionBreakdown,
  computeProgressionDelta,
  computeEffectiveAge,
  selectAgeProfile,
  signalsFromContext,
  MASTERY_HIGH_BONUS,
  MASTERY_LOW_PENALTY,
  MASTERY_MIN_ATTEMPTS,
  QUIZ_WIN_RATE_BONUS,
  FLOW_PER_EVENT_BONUS,
  FLOW_EVENT_CAP,
  FRUSTRATION_PENALTY,
  PARENT_OFFSET_MULTIPLIER,
  PROGRESSION_DELTA_MIN,
  PROGRESSION_DELTA_MAX,
  EFFECTIVE_AGE_MIN,
  EFFECTIVE_AGE_MAX,
} from '@services/skills/progression';

describe('computeProgressionDelta — no signals', () => {
  it('returns 0 for empty input', () => {
    expect(computeProgressionDelta({})).toBe(0);
  });

  it('returns 0 when mastery has too few attempts', () => {
    expect(
      computeProgressionDelta({
        mastery: { averageScore: 0.95, totalAttempts: MASTERY_MIN_ATTEMPTS - 1 },
      })
    ).toBe(0);
  });

  it('returns 0 when quiz win rate is missing', () => {
    expect(computeProgressionDelta({ engagement: undefined })).toBe(0);
  });
});

describe('computeProgressionDelta — mastery layer', () => {
  it('applies +MASTERY_HIGH_BONUS when attempts >= threshold and avg > 0.7', () => {
    const d = computeProgressionDelta({
      mastery: { averageScore: 0.85, totalAttempts: 25 },
    });
    expect(d).toBeCloseTo(MASTERY_HIGH_BONUS, 5);
  });

  it('applies -MASTERY_LOW_PENALTY when attempts >= threshold and avg < 0.4', () => {
    const d = computeProgressionDelta({
      mastery: { averageScore: 0.3, totalAttempts: 25 },
    });
    expect(d).toBeCloseTo(-MASTERY_LOW_PENALTY, 5);
  });

  it('is neutral in the mid band 0.4..0.7 regardless of attempts', () => {
    const d = computeProgressionDelta({
      mastery: { averageScore: 0.55, totalAttempts: 50 },
    });
    expect(d).toBe(0);
  });

  it('ignores NaN / Infinity in mastery inputs', () => {
    expect(
      computeProgressionDelta({
        mastery: { averageScore: NaN, totalAttempts: 30 },
      })
    ).toBe(0);
    expect(
      computeProgressionDelta({
        mastery: { averageScore: 0.9, totalAttempts: Infinity },
      })
    ).toBe(0);
  });
});

describe('computeProgressionDelta — quiz win rate layer', () => {
  it('applies +QUIZ_WIN_RATE_BONUS when win rate > 0.8', () => {
    const d = computeProgressionDelta({
      engagement: { recentQuizWinRate: 0.95, preferredCardTypes: [] },
    });
    expect(d).toBeCloseTo(QUIZ_WIN_RATE_BONUS, 5);
  });

  it('is neutral at exactly the threshold', () => {
    const d = computeProgressionDelta({
      engagement: { recentQuizWinRate: 0.8, preferredCardTypes: [] },
    });
    expect(d).toBe(0);
  });

  it('is neutral below threshold', () => {
    const d = computeProgressionDelta({
      engagement: { recentQuizWinRate: 0.5, preferredCardTypes: [] },
    });
    expect(d).toBe(0);
  });
});

describe('computeProgressionDelta — flow / frustration layer', () => {
  it('scales linearly with flow events up to the cap', () => {
    for (let k = 0; k <= FLOW_EVENT_CAP; k++) {
      const d = computeProgressionDelta({
        recentSessionEvents: { flow: k, frustration: 0, abandon: 0 },
      });
      expect(d).toBeCloseTo(k * FLOW_PER_EVENT_BONUS, 5);
    }
  });

  it('caps the flow bonus at FLOW_EVENT_CAP * FLOW_PER_EVENT_BONUS', () => {
    const d = computeProgressionDelta({
      recentSessionEvents: { flow: 99, frustration: 0, abandon: 0 },
    });
    expect(d).toBeCloseTo(FLOW_EVENT_CAP * FLOW_PER_EVENT_BONUS, 5);
  });

  it('applies -FRUSTRATION_PENALTY once frustration >= 2', () => {
    const d = computeProgressionDelta({
      recentSessionEvents: { flow: 0, frustration: 2, abandon: 0 },
    });
    expect(d).toBeCloseTo(-FRUSTRATION_PENALTY, 5);
  });

  it('does not apply frustration penalty at count = 1', () => {
    const d = computeProgressionDelta({
      recentSessionEvents: { flow: 0, frustration: 1, abandon: 0 },
    });
    expect(d).toBe(0);
  });

  it('layers flow and frustration additively', () => {
    // 2 flow events (+0.2) + 2 frustration events (-0.5) = -0.3
    const d = computeProgressionDelta({
      recentSessionEvents: { flow: 2, frustration: 2, abandon: 5 },
    });
    expect(d).toBeCloseTo(2 * FLOW_PER_EVENT_BONUS - FRUSTRATION_PENALTY, 5);
  });
});

describe('computeProgressionDelta — parent offset layer', () => {
  it('multiplies offset by PARENT_OFFSET_MULTIPLIER', () => {
    for (let off = -2; off <= 2; off++) {
      const d = computeProgressionDelta({ parentDifficultyOffset: off });
      expect(d).toBeCloseTo(off * PARENT_OFFSET_MULTIPLIER, 5);
    }
  });

  it('ignores non-finite offsets', () => {
    expect(computeProgressionDelta({ parentDifficultyOffset: NaN })).toBe(0);
  });
});

describe('computeProgressionDelta — clamping', () => {
  it('clamps at PROGRESSION_DELTA_MAX when all signals push positive', () => {
    const d = computeProgressionDelta({
      mastery: { averageScore: 1.0, totalAttempts: 100 },
      engagement: { recentQuizWinRate: 1.0, preferredCardTypes: [] },
      recentSessionEvents: { flow: 10, frustration: 0, abandon: 0 },
      parentDifficultyOffset: 2,
    });
    expect(d).toBeCloseTo(PROGRESSION_DELTA_MAX, 5);
  });

  it('clamps at PROGRESSION_DELTA_MIN when all signals push negative', () => {
    const d = computeProgressionDelta({
      mastery: { averageScore: 0.1, totalAttempts: 100 },
      engagement: { recentQuizWinRate: 0.1, preferredCardTypes: [] },
      recentSessionEvents: { flow: 0, frustration: 10, abandon: 20 },
      parentDifficultyOffset: -2,
    });
    expect(d).toBeCloseTo(PROGRESSION_DELTA_MIN, 5);
  });
});

describe('computeProgressionBreakdown', () => {
  it('returns per-signal contributions that sum to the clamped total', () => {
    const bk = computeProgressionBreakdown({
      mastery: { averageScore: 0.95, totalAttempts: 20 },
      engagement: { recentQuizWinRate: 0.9, preferredCardTypes: [] },
      recentSessionEvents: { flow: 2, frustration: 0, abandon: 0 },
      parentDifficultyOffset: 1,
    });
    expect(bk.masteryContribution).toBeCloseTo(MASTERY_HIGH_BONUS, 5);
    expect(bk.quizWinRateContribution).toBeCloseTo(QUIZ_WIN_RATE_BONUS, 5);
    expect(bk.flowContribution).toBeCloseTo(2 * FLOW_PER_EVENT_BONUS, 5);
    expect(bk.frustrationContribution).toBe(0);
    expect(bk.parentOffsetContribution).toBeCloseTo(PARENT_OFFSET_MULTIPLIER, 5);
    // Total clamps at PROGRESSION_DELTA_MAX (1.5) — raw sum would be 0.5+0.3+0.2+0+0.4 = 1.4 < 1.5
    expect(bk.total).toBeCloseTo(
      MASTERY_HIGH_BONUS + QUIZ_WIN_RATE_BONUS + 2 * FLOW_PER_EVENT_BONUS + PARENT_OFFSET_MULTIPLIER,
      5
    );
  });
});

describe('computeEffectiveAge', () => {
  it('adds delta to age', () => {
    expect(computeEffectiveAge(6, 0.5)).toBe(6.5);
    expect(computeEffectiveAge(7, -0.3)).toBe(6.7);
  });

  it('clamps below EFFECTIVE_AGE_MIN', () => {
    expect(computeEffectiveAge(2, -1.5)).toBe(EFFECTIVE_AGE_MIN);
  });

  it('clamps above EFFECTIVE_AGE_MAX', () => {
    expect(computeEffectiveAge(14, 1.5)).toBe(EFFECTIVE_AGE_MAX);
  });

  it('handles non-finite inputs gracefully', () => {
    // NaN age → treated as 0 then clamped to EFFECTIVE_AGE_MIN
    expect(computeEffectiveAge(NaN, 0)).toBe(EFFECTIVE_AGE_MIN);
    // Infinity delta → clamped to EFFECTIVE_AGE_MAX
    expect(computeEffectiveAge(8, Infinity)).toBe(EFFECTIVE_AGE_MAX);
  });
});

describe('selectAgeProfile', () => {
  const ANCHORS = [4, 6, 8] as const;

  it('picks the exact anchor when effective age is on one', () => {
    expect(selectAgeProfile(ANCHORS, 4)).toBe(4);
    expect(selectAgeProfile(ANCHORS, 6)).toBe(6);
    expect(selectAgeProfile(ANCHORS, 8)).toBe(8);
  });

  it('picks the nearest anchor for in-range values', () => {
    expect(selectAgeProfile(ANCHORS, 5.1)).toBe(6); // distance 0.9 vs 1.1
    expect(selectAgeProfile(ANCHORS, 6.8)).toBe(6);
    expect(selectAgeProfile(ANCHORS, 7.2)).toBe(8);
  });

  it('breaks ties toward the lower anchor (round down — err toward simpler)', () => {
    expect(selectAgeProfile(ANCHORS, 5)).toBe(4); // equidistant to 4 and 6 ⇒ 4
    expect(selectAgeProfile(ANCHORS, 7)).toBe(6); // equidistant to 6 and 8 ⇒ 6
  });

  it('clamps below the lowest anchor', () => {
    expect(selectAgeProfile(ANCHORS, 2)).toBe(4);
  });

  it('clamps above the highest anchor', () => {
    expect(selectAgeProfile(ANCHORS, 12)).toBe(8);
  });

  it('throws on empty anchor list', () => {
    expect(() => selectAgeProfile([], 6)).toThrow(/no anchors/);
  });
});

describe('signalsFromContext', () => {
  it('forwards the expected fields', () => {
    const signals = signalsFromContext({
      mastery: { averageScore: 0.8, totalAttempts: 20 },
      engagement: { recentQuizWinRate: 0.9, preferredCardTypes: [] },
      recentSessionEvents: { flow: 1, frustration: 0, abandon: 0 },
      difficultyOffset: 1,
    });
    expect(signals.mastery?.averageScore).toBe(0.8);
    expect(signals.engagement?.recentQuizWinRate).toBe(0.9);
    expect(signals.recentSessionEvents?.flow).toBe(1);
    expect(signals.parentDifficultyOffset).toBe(1);
  });

  it('passes through missing fields as undefined', () => {
    const signals = signalsFromContext({});
    expect(signals.mastery).toBeUndefined();
    expect(signals.engagement).toBeUndefined();
    expect(signals.recentSessionEvents).toBeUndefined();
    expect(signals.parentDifficultyOffset).toBeUndefined();
  });
});
