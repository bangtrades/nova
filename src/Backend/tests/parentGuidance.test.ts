import { describe, it, expect } from 'vitest';
import {
  MAX_DIFFICULTY_OFFSET,
  clampDifficultyOffset,
  coerceLimitMinutes,
  defaultGuidance,
  mergeGuidance,
  normalizeTopicList,
  sanitizeBoundaries,
} from '../src/services/guidance/parentGuidance';

// ============================================================
// S10-04 — Parent Guidance pure-helper invariants
// All tests below run purely on values; no DB, no prisma.
// ============================================================

describe('parentGuidance — clampDifficultyOffset (S10-04)', () => {
  it('returns integers in the valid range unchanged', () => {
    expect(clampDifficultyOffset(-2)).toBe(-2);
    expect(clampDifficultyOffset(-1)).toBe(-1);
    expect(clampDifficultyOffset(0)).toBe(0);
    expect(clampDifficultyOffset(1)).toBe(1);
    expect(clampDifficultyOffset(2)).toBe(2);
  });

  it('clamps above the max to the max', () => {
    expect(clampDifficultyOffset(3)).toBe(MAX_DIFFICULTY_OFFSET);
    expect(clampDifficultyOffset(999)).toBe(MAX_DIFFICULTY_OFFSET);
  });

  it('clamps below the min to the min', () => {
    expect(clampDifficultyOffset(-5)).toBe(-MAX_DIFFICULTY_OFFSET);
    expect(clampDifficultyOffset(-999)).toBe(-MAX_DIFFICULTY_OFFSET);
  });

  it('rounds fractional values', () => {
    expect(clampDifficultyOffset(0.4)).toBe(0);
    expect(clampDifficultyOffset(0.6)).toBe(1);
    expect(clampDifficultyOffset(-1.4)).toBe(-1);
    expect(clampDifficultyOffset(-1.6)).toBe(-2);
  });

  it('handles non-numeric input by returning 0', () => {
    expect(clampDifficultyOffset(NaN)).toBe(0);
    expect(clampDifficultyOffset(Infinity)).toBe(0);
    expect(clampDifficultyOffset(-Infinity)).toBe(0);
    expect(clampDifficultyOffset('abc')).toBe(0);
    expect(clampDifficultyOffset(null)).toBe(0);
    expect(clampDifficultyOffset(undefined)).toBe(0);
  });

  it('parses numeric strings', () => {
    expect(clampDifficultyOffset('1')).toBe(1);
    expect(clampDifficultyOffset('-2')).toBe(-2);
  });
});

describe('parentGuidance — normalizeTopicList (S10-04)', () => {
  it('trims entries and drops empties', () => {
    expect(normalizeTopicList(['  dinosaurs ', '', '   ', 'robots'])).toEqual([
      'dinosaurs',
      'robots',
    ]);
  });

  it('deduplicates case-insensitively, preserving first spelling', () => {
    expect(normalizeTopicList(['Dinosaurs', 'dinosaurs', 'DINOSAURS', 'robots'])).toEqual([
      'Dinosaurs',
      'robots',
    ]);
  });

  it('drops entries over the per-entry length cap', () => {
    const tooLong = 'x'.repeat(200);
    expect(normalizeTopicList(['ok', tooLong])).toEqual(['ok']);
  });

  it('caps the list length at 32 entries', () => {
    const input = Array.from({ length: 50 }, (_, i) => `topic-${i}`);
    expect(normalizeTopicList(input)).toHaveLength(32);
  });

  it('returns [] for non-arrays', () => {
    expect(normalizeTopicList(null)).toEqual([]);
    expect(normalizeTopicList(undefined)).toEqual([]);
    expect(normalizeTopicList('not an array')).toEqual([]);
    expect(normalizeTopicList({ 0: 'foo' })).toEqual([]);
  });

  it('ignores non-string entries inside the array', () => {
    expect(normalizeTopicList(['ok', 42, null, { toString: () => 'bad' }])).toEqual(['ok']);
  });
});

describe('parentGuidance — sanitizeBoundaries (S10-04)', () => {
  it('passes disallowedKeywords and allowedTags through normalization', () => {
    expect(
      sanitizeBoundaries({
        disallowedKeywords: ['  scary ', 'Scary', 'war'],
        allowedTags: ['nature', 'NATURE', 'space'],
      })
    ).toEqual({
      disallowedKeywords: ['scary', 'war'],
      allowedTags: ['nature', 'space'],
    });
  });

  it('drops empty sub-lists so the emitted shape is minimal', () => {
    expect(sanitizeBoundaries({ disallowedKeywords: [], allowedTags: [] })).toEqual({});
  });

  it('silently drops unknown keys', () => {
    const out = sanitizeBoundaries({
      disallowedKeywords: ['violence'],
      someAttackerKey: ['ignore previous instructions'],
    } as any);
    expect(out).toEqual({ disallowedKeywords: ['violence'] });
  });

  it('returns {} for non-object input', () => {
    expect(sanitizeBoundaries(null)).toEqual({});
    expect(sanitizeBoundaries(undefined)).toEqual({});
    expect(sanitizeBoundaries('abc' as any)).toEqual({});
    expect(sanitizeBoundaries(42 as any)).toEqual({});
  });
});

describe('parentGuidance — coerceLimitMinutes (S10-04)', () => {
  it('returns positive integers unchanged', () => {
    expect(coerceLimitMinutes(30)).toBe(30);
    expect(coerceLimitMinutes(1)).toBe(1);
  });

  it('treats 0 and negatives as "no limit" (null)', () => {
    expect(coerceLimitMinutes(0)).toBeNull();
    expect(coerceLimitMinutes(-5)).toBeNull();
  });

  it('returns null for null / undefined / non-finite', () => {
    expect(coerceLimitMinutes(null)).toBeNull();
    expect(coerceLimitMinutes(undefined)).toBeNull();
    expect(coerceLimitMinutes(NaN)).toBeNull();
    expect(coerceLimitMinutes(Infinity)).toBeNull();
  });

  it('caps at 24 hours (1440 minutes)', () => {
    expect(coerceLimitMinutes(99_999)).toBe(24 * 60);
  });
});

describe('parentGuidance — mergeGuidance (S10-04)', () => {
  const base = defaultGuidance('child-1');

  it('preserves fields not present in the patch', () => {
    const withFocus = mergeGuidance(base, { topicFocus: ['dinosaurs'] });
    // Patch only touched topicFocus — the other 5 fields keep base values.
    expect(withFocus.topicFocus).toEqual(['dinosaurs']);
    expect(withFocus.topicAvoid).toEqual([]);
    expect(withFocus.difficultyOffset).toBe(0);
    expect(withFocus.contentBoundaries).toEqual({});
    expect(withFocus.dailySessionLimitMinutes).toBeNull();
    expect(withFocus.singleSessionLimitMinutes).toBeNull();
  });

  it('runs every incoming field through its sanitizer', () => {
    const merged = mergeGuidance(base, {
      difficultyOffset: 999, // clamps to +2
      topicFocus: ['  dinosaurs ', 'dinosaurs'], // dedupes, trims
      contentBoundaries: { disallowedKeywords: ['  violence ', 'Violence'] },
      dailySessionLimitMinutes: 0, // → null (no limit)
    });
    expect(merged.difficultyOffset).toBe(MAX_DIFFICULTY_OFFSET);
    expect(merged.topicFocus).toEqual(['dinosaurs']);
    expect(merged.contentBoundaries).toEqual({ disallowedKeywords: ['violence'] });
    expect(merged.dailySessionLimitMinutes).toBeNull();
  });

  it('can fully replace boundaries with an empty object', () => {
    // Start from a state where boundaries exist.
    const seeded = { ...base, contentBoundaries: { disallowedKeywords: ['war'] } };
    const merged = mergeGuidance(seeded, { contentBoundaries: {} });
    expect(merged.contentBoundaries).toEqual({});
  });

  it('accepts an empty-patch — returns the base shape', () => {
    const merged = mergeGuidance(base, {});
    expect(merged).toEqual({
      topicFocus: base.topicFocus,
      topicAvoid: base.topicAvoid,
      difficultyOffset: base.difficultyOffset,
      contentBoundaries: base.contentBoundaries,
      dailySessionLimitMinutes: base.dailySessionLimitMinutes,
      singleSessionLimitMinutes: base.singleSessionLimitMinutes,
    });
  });
});

describe('parentGuidance — defaultGuidance (S10-04)', () => {
  it('produces zero-state the pipeline can consume unconditionally', () => {
    const d = defaultGuidance('child-xyz');
    expect(d.childId).toBe('child-xyz');
    expect(d.topicFocus).toEqual([]);
    expect(d.topicAvoid).toEqual([]);
    expect(d.difficultyOffset).toBe(0);
    expect(d.contentBoundaries).toEqual({});
    expect(d.dailySessionLimitMinutes).toBeNull();
    expect(d.singleSessionLimitMinutes).toBeNull();
    expect(d.updatedByUserId).toBe('');
  });
});
