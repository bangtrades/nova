import { describe, it, expect } from 'vitest';
import { normalizeReport } from '../src/services/pipeline/qualityGate';

describe('qualityGate — normalizeReport (S9-09)', () => {
  it('accepts a well-formed reviewer response', () => {
    const raw = {
      overallPass: true,
      overallScore: 0.88,
      flow: { score: 0.9, notes: 'Nice progression' },
      completeness: { score: 0.85, notes: 'Covers the topic' },
      engagement: { score: 0.9, notes: 'Good variety' },
      cards: [
        { index: 0, score: 0.9, pass: true, issues: [], shouldRegenerate: false, regenerationGuidance: '' },
        { index: 1, score: 0.8, pass: true, issues: [], shouldRegenerate: false, regenerationGuidance: '' },
      ],
    };

    const report = normalizeReport(raw, 2);
    expect(report.overallPass).toBe(true);
    expect(report.overallScore).toBe(0.88);
    expect(report.cards).toHaveLength(2);
    expect(report.cards[0].pass).toBe(true);
    expect(report.flow.notes).toBe('Nice progression');
  });

  it('fills in missing per-card reviews with pass-through defaults', () => {
    const raw = {
      overallPass: true,
      overallScore: 0.8,
      cards: [{ index: 0, score: 0.9, pass: true, issues: [], shouldRegenerate: false }],
    };

    const report = normalizeReport(raw, 3);
    expect(report.cards).toHaveLength(3);
    expect(report.cards[1].pass).toBe(true);
    expect(report.cards[1].shouldRegenerate).toBe(false);
    expect(report.cards[2].shouldRegenerate).toBe(false);
  });

  it('marks overallPass false when score < 0.6', () => {
    const raw = {
      overallPass: true, // reviewer contradicts itself
      overallScore: 0.3,
      cards: [],
    };
    const report = normalizeReport(raw, 1);
    expect(report.overallPass).toBe(false);
  });

  it('clamps all scores to 0..1 and rounds to 2dp', () => {
    const raw = {
      overallScore: 1.7,
      flow: { score: -0.3 },
      completeness: { score: 0.867 },
      engagement: { score: 99 },
      cards: [{ index: 0, score: 2, pass: true }],
    };
    const report = normalizeReport(raw, 1);
    expect(report.overallScore).toBeLessThanOrEqual(1);
    expect(report.flow.score).toBe(0);
    expect(report.completeness.score).toBeCloseTo(0.87, 2);
    expect(report.engagement.score).toBe(1);
    expect(report.cards[0].score).toBe(1);
  });

  it('preserves regeneration flags and guidance on flagged cards', () => {
    const raw = {
      overallPass: false,
      overallScore: 0.5,
      cards: [
        {
          index: 0,
          score: 0.4,
          pass: false,
          issues: ['factually wrong', 'vocabulary too advanced'],
          shouldRegenerate: true,
          regenerationGuidance: 'Use simpler words, correct the date.',
        },
      ],
    };

    const report = normalizeReport(raw, 1);
    expect(report.cards[0].shouldRegenerate).toBe(true);
    expect(report.cards[0].issues).toEqual(['factually wrong', 'vocabulary too advanced']);
    expect(report.cards[0].regenerationGuidance).toContain('simpler words');
  });

  it('handles empty / malformed reviewer output gracefully', () => {
    const report = normalizeReport({}, 2);
    expect(report.cards).toHaveLength(2);
    // sub-scores default to 0.8 pass-through
    expect(report.flow.score).toBe(0.8);
    expect(report.cards.every((c) => !c.shouldRegenerate)).toBe(true);
  });

  it('computes overallScore from sub-scores when not provided', () => {
    const raw = {
      flow: { score: 0.9 },
      completeness: { score: 0.6 },
      engagement: { score: 0.9 },
    };
    const report = normalizeReport(raw, 1);
    // (0.9 + 0.6 + 0.9) / 3 = 0.8
    expect(report.overallScore).toBeCloseTo(0.8, 1);
  });
});
