/**
 * S10-12 · R6 — childContextBuilder unit tests.
 *
 * Scope kept to the pure helpers — `withConceptType`, `summarizeEngagement`,
 * `summarizeMastery`, `summarizeRecentEvents`. The main `buildChildContext`
 * entry point is exercised indirectly through `skillRouter.test.ts` and the
 * pipeline-integration smoke in `pipelineSkillIntegration.test.ts`; here we
 * lock down the behavior of the small, dependency-free transformations so
 * any regression surfaces loud and early.
 */
import { describe, it, expect } from 'vitest';
import {
  withConceptType,
  summarizeEngagement,
  summarizeMastery,
  summarizeRecentEvents,
} from '@services/pipeline/childContextBuilder';
import type { ChildContext } from '@services/skills/types';
import type { EngagementProfileView } from '@services/engagement/engagementProfiler';
import type { MasteryRow } from '@services/mastery/masteryTracker';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

function makeCtx(overrides: Partial<ChildContext> = {}): ChildContext {
  return {
    childId: 'child-1',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-1',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-1',
      createdAt: new Date(),
      updatedAt: new Date(),
    },
    sessionContext: {
      ianaTimezone: 'America/Los_Angeles',
      computedAt: new Date().toISOString(),
      localClock: '10:00',
      localDayOfWeek: 'Monday',
      timeOfDay: 'morning',
      currentSessionMinutes: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    },
    interestTopics: undefined,
    teachingStrategy: {
      conceptType: 'abstract',
      modality: 'visual',
      rankedCardTypes: [
        { type: 'story', count: 10, totalDurationMs: 20_000, completionRate: 0.9, avgDurationMs: 2000, score: 0.9 },
        { type: 'concept', count: 4, totalDurationMs: 5_000, completionRate: 0.7, avgDurationMs: 1250, score: 0.7 },
      ],
    },
    difficultyOffset: 0,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// withConceptType
// ---------------------------------------------------------------------------

describe('withConceptType', () => {
  it('returns the same instance when conceptType is unchanged (no-op)', () => {
    const base = makeCtx();
    const result = withConceptType(base, 'abstract');
    expect(result).toBe(base);
  });

  it('rebuilds teachingStrategy when conceptType changes', () => {
    const base = makeCtx({
      teachingStrategy: {
        conceptType: 'abstract',
        modality: 'auditory',
        rankedCardTypes: [],
      },
    });
    const result = withConceptType(base, 'factual');
    expect(result).not.toBe(base);
    expect(result.teachingStrategy.conceptType).toBe('factual');
    expect(result.teachingStrategy.modality).toBe('auditory'); // preserved
    expect(result.teachingStrategy.rankedCardTypes.length).toBeGreaterThan(0);
    expect(result.teachingStrategy.rankedCardTypes[0].cardType).toBeTruthy();
  });

  it('preserves every non-teachingStrategy field verbatim', () => {
    const base = makeCtx({
      ageYears: 7,
      effectiveAgeYears: 7.5,
      progressionDelta: 0.5,
      interestTopics: ['dinosaurs'],
      difficultyOffset: 1,
    });
    const result = withConceptType(base, 'process');
    expect(result.ageYears).toBe(base.ageYears);
    expect(result.effectiveAgeYears).toBe(base.effectiveAgeYears);
    expect(result.progressionDelta).toBe(base.progressionDelta);
    expect(result.interestTopics).toEqual(base.interestTopics);
    expect(result.difficultyOffset).toBe(base.difficultyOffset);
    expect(result.parentGuidance).toBe(base.parentGuidance);
    expect(result.sessionContext).toBe(base.sessionContext);
  });

  it('produces different ranked card types for different conceptTypes (visual modality)', () => {
    const base = makeCtx({
      teachingStrategy: {
        conceptType: 'abstract',
        modality: 'visual',
        rankedCardTypes: [],
      },
    });
    // abstract[visual] = ['story', 'concept', …]
    // factual[visual]  = ['concept', 'quiz', …]
    const abstract = withConceptType(base, 'abstract');
    const factual = withConceptType(base, 'factual');
    const abstractOrder = abstract.teachingStrategy.rankedCardTypes.map(
      (r) => r.cardType
    );
    const factualOrder = factual.teachingStrategy.rankedCardTypes.map(
      (r) => r.cardType
    );
    expect(abstractOrder).not.toEqual(factualOrder);
    // Sanity: every returned record has a cardType (not undefined).
    for (const t of abstractOrder) expect(t).toBeTruthy();
    for (const t of factualOrder) expect(t).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// summarizeEngagement
// ---------------------------------------------------------------------------

describe('summarizeEngagement', () => {
  function profile(
    overrides: Partial<EngagementProfileView> = {}
  ): EngagementProfileView {
    return {
      childId: 'child-1',
      totalSessions: 10,
      totalInteractions: 50,
      totalDurationMs: 100_000,
      avgInteractionMs: 2000,
      frustrationEventCount: 0,
      flowEventCount: 0,
      currentStreak: 0,
      longestStreak: 0,
      cardTypePreferences: [],
      topicAffinities: [],
      lastInteractionAt: null,
      lastComputedAt: new Date(),
      ...overrides,
    };
  }

  it('extracts quiz completionRate as recentQuizWinRate', () => {
    const out = summarizeEngagement(
      profile({
        cardTypePreferences: [
          { type: 'quiz', count: 8, totalDurationMs: 20_000, completionRate: 0.75, avgDurationMs: 2500, score: 0.8 },
          { type: 'story', count: 10, totalDurationMs: 30_000, completionRate: 0.95, avgDurationMs: 3000, score: 0.9 },
        ],
      })
    );
    expect(out.recentQuizWinRate).toBe(0.75);
    expect(out.preferredCardTypes).toHaveLength(2);
  });

  it('defaults recentQuizWinRate to 0 when no quiz row exists', () => {
    const out = summarizeEngagement(
      profile({
        cardTypePreferences: [
          { type: 'story', count: 10, totalDurationMs: 30_000, completionRate: 0.9, avgDurationMs: 3000, score: 0.9 },
        ],
      })
    );
    expect(out.recentQuizWinRate).toBe(0);
    expect(out.preferredCardTypes).toHaveLength(1);
  });

  it('passes through cardTypePreferences unchanged', () => {
    const prefs = [
      { type: 'story' as const, count: 10, totalDurationMs: 30_000, completionRate: 0.9, avgDurationMs: 3000, score: 0.9 },
    ];
    const out = summarizeEngagement(profile({ cardTypePreferences: prefs }));
    expect(out.preferredCardTypes).toEqual(prefs);
  });
});

// ---------------------------------------------------------------------------
// summarizeMastery
// ---------------------------------------------------------------------------

describe('summarizeMastery', () => {
  function row(overrides: Partial<MasteryRow> = {}): MasteryRow {
    return {
      conceptId: 'c1',
      conceptName: 'test',
      domain: 'science',
      difficulty: 1,
      confidence: 0.5,
      effectiveConfidence: 0.5,
      attempts: 1,
      correctCount: 0,
      lastTested: null,
      firstIntroduced: null,
      ...overrides,
    };
  }

  it('returns zero-state for an empty row set', () => {
    expect(summarizeMastery([])).toEqual({ averageScore: 0, totalAttempts: 0 });
  });

  it('weights effectiveConfidence by attempts', () => {
    // Row A: confidence 0.8, 4 attempts — contributes 3.2
    // Row B: confidence 0.2, 1 attempt  — contributes 0.2
    // Total weighted: 3.4 / 5 = 0.68
    const out = summarizeMastery([
      row({ effectiveConfidence: 0.8, attempts: 4 }),
      row({ effectiveConfidence: 0.2, attempts: 1 }),
    ]);
    expect(out.totalAttempts).toBe(5);
    expect(out.averageScore).toBeCloseTo(0.68, 2);
  });

  it('ignores rows with zero attempts (introduced but untested)', () => {
    const out = summarizeMastery([
      row({ effectiveConfidence: 0.9, attempts: 2 }),
      row({ effectiveConfidence: 0.0, attempts: 0 }),
    ]);
    expect(out.totalAttempts).toBe(2);
    expect(out.averageScore).toBeCloseTo(0.9, 2);
  });

  it('returns zero averageScore when all rows have zero attempts', () => {
    const out = summarizeMastery([
      row({ effectiveConfidence: 0.9, attempts: 0 }),
      row({ effectiveConfidence: 0.5, attempts: 0 }),
    ]);
    expect(out).toEqual({ averageScore: 0, totalAttempts: 0 });
  });
});

// ---------------------------------------------------------------------------
// summarizeRecentEvents
// ---------------------------------------------------------------------------

describe('summarizeRecentEvents', () => {
  function profile(
    overrides: Partial<EngagementProfileView> = {}
  ): EngagementProfileView {
    return {
      childId: 'child-1',
      totalSessions: 0,
      totalInteractions: 0,
      totalDurationMs: 0,
      avgInteractionMs: 0,
      frustrationEventCount: 0,
      flowEventCount: 0,
      currentStreak: 0,
      longestStreak: 0,
      cardTypePreferences: [],
      topicAffinities: [],
      lastInteractionAt: null,
      lastComputedAt: new Date(),
      ...overrides,
    };
  }

  it('passes through counts when below the cap', () => {
    const out = summarizeRecentEvents(
      profile({ flowEventCount: 3, frustrationEventCount: 1 })
    );
    expect(out).toEqual({ flow: 3, frustration: 1, abandon: 0 });
  });

  it('clamps flow events at 6', () => {
    const out = summarizeRecentEvents(
      profile({ flowEventCount: 999, frustrationEventCount: 0 })
    );
    expect(out.flow).toBe(6);
  });

  it('clamps frustration events at 6', () => {
    const out = summarizeRecentEvents(
      profile({ flowEventCount: 0, frustrationEventCount: 42 })
    );
    expect(out.frustration).toBe(6);
  });

  it('always returns abandon=0 until the 7d window lands (S10-13)', () => {
    const out = summarizeRecentEvents(
      profile({ flowEventCount: 5, frustrationEventCount: 5 })
    );
    expect(out.abandon).toBe(0);
  });
});
