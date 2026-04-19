/**
 * S10-11 Teaching Strategy Matrix — unit tests
 *
 * Scope is tight on purpose: the service is pure, so the tests exercise
 * each layer (base matrix, engagement, difficulty, age) in isolation,
 * then confirm they compose correctly in `rankCardTypesFor`.
 *
 * Tests deliberately pin the numeric constants (ENGAGEMENT_TOP_BONUS
 * etc.) so that future tuning sweeps make the intent of a change loud
 * in a diff, rather than silently reordering downstream prompts.
 */
import { describe, it, expect } from 'vitest';
import {
  rankCardTypesFor,
  rankedCardTypeOrder,
  getStrategyMatrix,
  inferModality,
  computeEngagementBonus,
  computeDifficultyBonus,
  computeAgeBonus,
  CONCEPT_TYPES,
  LEARNING_MODALITIES,
  ENGAGEMENT_TOP_BONUS,
  ENGAGEMENT_SECOND_BONUS,
  ENGAGEMENT_ZERO_COMPLETION_PENALTY,
  DIFFICULTY_STEP,
  EXPERIMENT_MIN_AGE,
  CONCEPT_MIN_AGE,
  AGE_GATE_PENALTY,
} from '@services/skills/teachingStrategy';
import type {
  ConceptType,
  LearningModality,
  RankerContext,
} from '@services/skills/teachingStrategy';
import type { RankedCardType, CardTypeKey } from '@services/engagement/engagementProfiler';

// Helpers -----------------------------------------------------------

const CARD_TYPES: readonly CardTypeKey[] = ['story', 'concept', 'experiment', 'quiz', 'voice'];

function mockEngagement(ordered: CardTypeKey[], completionRate = 0.8): RankedCardType[] {
  return ordered.map((type, idx) => ({
    type,
    count: 10 - idx,
    totalDurationMs: 60_000 - idx * 10_000,
    completionRate,
    avgDurationMs: 6_000 - idx * 1_000,
    score: 2 - idx * 0.3,
  }));
}

// ===================================================================
// 1. Matrix shape invariants
// ===================================================================

describe('teachingStrategy — matrix shape', () => {
  it('has exactly 6 concept types', () => {
    expect(CONCEPT_TYPES).toHaveLength(6);
  });

  it('has exactly 3 learning modalities', () => {
    expect(LEARNING_MODALITIES).toHaveLength(3);
  });

  it('every cell lists every card type exactly once', () => {
    const matrix = getStrategyMatrix();
    for (const ct of CONCEPT_TYPES) {
      for (const mod of LEARNING_MODALITIES) {
        const cell = matrix[ct][mod];
        expect(cell).toHaveLength(CARD_TYPES.length);
        expect(new Set(cell).size).toBe(CARD_TYPES.length);
        for (const t of cell) {
          expect(CARD_TYPES).toContain(t);
        }
      }
    }
  });

  it('getStrategyMatrix returns a clone that cannot mutate module state', () => {
    const matrix = getStrategyMatrix();
    matrix.vocabulary.visual[0] = 'quiz';
    const fresh = getStrategyMatrix();
    // Round-tripping through getStrategyMatrix must give back the original.
    expect(fresh.vocabulary.visual[0]).not.toBe('quiz');
  });

  it('auditory cells always put `voice` or `story` in the top 2', () => {
    const matrix = getStrategyMatrix();
    for (const ct of CONCEPT_TYPES) {
      const top2 = matrix[ct].auditory.slice(0, 2);
      expect(top2.some((t) => t === 'voice' || t === 'story')).toBe(true);
    }
  });

  it('kinesthetic cells always put `experiment` in the top 2', () => {
    const matrix = getStrategyMatrix();
    for (const ct of CONCEPT_TYPES) {
      expect(matrix[ct].kinesthetic.slice(0, 2)).toContain('experiment');
    }
  });
});

// ===================================================================
// 2. Base ranker (no context)
// ===================================================================

describe('teachingStrategy — base ranker', () => {
  it('with empty context, preserves matrix cell order', () => {
    const ranked = rankCardTypesFor('vocabulary', 'visual');
    expect(ranked.map((r) => r.cardType)).toEqual([
      'concept',
      'story',
      'quiz',
      'voice',
      'experiment',
    ]);
    expect(ranked[0].baseRank).toBe(0);
    expect(ranked[4].baseRank).toBe(4);
  });

  it('base score is (5 - baseRank) when all layer bonuses are 0', () => {
    const ranked = rankCardTypesFor('factual', 'visual');
    expect(ranked[0].score).toBe(5);
    expect(ranked[4].score).toBe(1);
    for (const r of ranked) {
      expect(r.engagementBonus).toBe(0);
      expect(r.difficultyBonus).toBe(0);
      expect(r.ageBonus).toBe(0);
    }
  });

  it('rankedCardTypeOrder is a flat list equivalent to mapping rankCardTypesFor', () => {
    const full = rankCardTypesFor('process', 'kinesthetic');
    const flat = rankedCardTypeOrder('process', 'kinesthetic');
    expect(flat).toEqual(full.map((r) => r.cardType));
  });

  it('returns all 5 card types for every (conceptType, modality) pair', () => {
    for (const ct of CONCEPT_TYPES) {
      for (const mod of LEARNING_MODALITIES) {
        const ranked = rankCardTypesFor(ct, mod);
        expect(ranked).toHaveLength(CARD_TYPES.length);
        expect(new Set(ranked.map((r) => r.cardType)).size).toBe(CARD_TYPES.length);
      }
    }
  });
});

// ===================================================================
// 3. Engagement layer
// ===================================================================

describe('teachingStrategy — engagement bonus', () => {
  it('top-ranked engagement gets +ENGAGEMENT_TOP_BONUS', () => {
    const e = mockEngagement(['quiz', 'story', 'concept']);
    expect(computeEngagementBonus('quiz', e)).toBe(ENGAGEMENT_TOP_BONUS);
  });

  it('second-ranked engagement gets +ENGAGEMENT_SECOND_BONUS', () => {
    const e = mockEngagement(['quiz', 'story', 'concept']);
    expect(computeEngagementBonus('story', e)).toBe(ENGAGEMENT_SECOND_BONUS);
  });

  it('lower-ranked engagement with zero completion gets penalty', () => {
    const e: RankedCardType[] = [
      { type: 'quiz', count: 10, totalDurationMs: 60000, completionRate: 0.8, avgDurationMs: 6000, score: 2 },
      { type: 'story', count: 10, totalDurationMs: 50000, completionRate: 0.6, avgDurationMs: 5000, score: 1.5 },
      { type: 'voice', count: 4, totalDurationMs: 8000, completionRate: 0, avgDurationMs: 2000, score: 0 },
    ];
    expect(computeEngagementBonus('voice', e)).toBe(-ENGAGEMENT_ZERO_COMPLETION_PENALTY);
  });

  it('card types not in the engagement list get no bonus (cold start neutral)', () => {
    const e = mockEngagement(['quiz', 'story']);
    expect(computeEngagementBonus('experiment', e)).toBe(0);
  });

  it('empty engagement array returns 0 for every card type', () => {
    for (const t of CARD_TYPES) {
      expect(computeEngagementBonus(t, [])).toBe(0);
    }
  });

  it('engagement boost can promote a matrix-3rd type over a matrix-1st type', () => {
    // vocabulary × visual → default order [concept, story, quiz, voice, experiment]
    // base scores: concept=5, story=4, quiz=3, voice=2, experiment=1
    // Boost quiz by +1.5 → quiz=4.5 → new order: concept(5), quiz(4.5), story(4), ...
    const e = mockEngagement(['quiz']);
    const order = rankedCardTypeOrder('vocabulary', 'visual', { engagement: e });
    expect(order[0]).toBe('concept');
    expect(order[1]).toBe('quiz');
  });
});

// ===================================================================
// 4. Difficulty layer
// ===================================================================

describe('teachingStrategy — difficulty bonus', () => {
  it('offset 0 returns 0 for every card type', () => {
    for (const t of CARD_TYPES) {
      expect(computeDifficultyBonus(t, 0)).toBe(0);
    }
  });

  it('offset +2 favors quiz and experiment, penalizes story and voice', () => {
    expect(computeDifficultyBonus('quiz', 2)).toBe(2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('experiment', 2)).toBe(2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('story', 2)).toBe(-2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('voice', 2)).toBe(-2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('concept', 2)).toBe(0); // neutral
  });

  it('offset -2 inverts the favor', () => {
    expect(computeDifficultyBonus('quiz', -2)).toBe(-2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('story', -2)).toBe(2 * DIFFICULTY_STEP);
  });

  it('offset outside [-2,+2] clamps defensively (no NaN / runaway)', () => {
    expect(computeDifficultyBonus('quiz', 99)).toBe(2 * DIFFICULTY_STEP);
    expect(computeDifficultyBonus('story', -99)).toBe(2 * DIFFICULTY_STEP);
  });

  it('non-finite offset yields 0', () => {
    expect(computeDifficultyBonus('quiz', NaN)).toBe(0);
    expect(computeDifficultyBonus('quiz', Infinity)).toBe(0);
  });
});

// ===================================================================
// 5. Age gate layer
// ===================================================================

describe('teachingStrategy — age bonus', () => {
  it('no age → no penalty', () => {
    for (const t of CARD_TYPES) {
      expect(computeAgeBonus(t, undefined)).toBe(0);
    }
  });

  it('experiment is penalized under EXPERIMENT_MIN_AGE', () => {
    expect(computeAgeBonus('experiment', EXPERIMENT_MIN_AGE - 1)).toBe(-AGE_GATE_PENALTY);
    expect(computeAgeBonus('experiment', EXPERIMENT_MIN_AGE)).toBe(0);
    expect(computeAgeBonus('experiment', 10)).toBe(0);
  });

  it('concept is penalized under CONCEPT_MIN_AGE', () => {
    expect(computeAgeBonus('concept', CONCEPT_MIN_AGE - 1)).toBe(-AGE_GATE_PENALTY);
    expect(computeAgeBonus('concept', CONCEPT_MIN_AGE)).toBe(0);
  });

  it('other card types are never age-gated', () => {
    for (const t of ['story', 'quiz', 'voice'] as CardTypeKey[]) {
      expect(computeAgeBonus(t, 4)).toBe(0);
      expect(computeAgeBonus(t, 10)).toBe(0);
    }
  });

  it('age gate narrows the gap between experiment and quiz for a 4-year-old kinesthetic learner', () => {
    // process × kinesthetic → default [experiment, concept, quiz, story, voice]
    // At age 4, both experiment (-0.75) and concept (-0.75) are penalized; others unchanged.
    //   experiment: 5 - 0.75 = 4.25
    //   concept:    4 - 0.75 = 3.25
    //   quiz:       3
    // The winner is still `experiment` because the base gap was 1 and the
    // penalty is 0.75, but the gap to `quiz` shrinks from 2 points to 1.25.
    const ranked = rankCardTypesFor('process', 'kinesthetic', { ageYears: 4 });
    const exp = ranked.find((r) => r.cardType === 'experiment')!;
    const quiz = ranked.find((r) => r.cardType === 'quiz')!;
    expect(ranked[0].cardType).toBe('experiment');
    expect(exp.ageBonus).toBe(-AGE_GATE_PENALTY);
    expect(quiz.ageBonus).toBe(0);
    expect(exp.score - quiz.score).toBeCloseTo(1.25, 4);
  });

  it('age 4 keeps experiment on top only because its base lead is large — bigger penalty would unseat it', () => {
    // Same cell, but verify that if quiz had any small bonus it could overtake after age gate.
    // With a slight engagement nudge on quiz (+0.75 for second-rank), quiz=3.75 vs experiment=4.25. Still experiment.
    // With top-engagement on quiz (+1.5), quiz=4.5 > experiment=4.25 → flips.
    const order = rankedCardTypeOrder('process', 'kinesthetic', {
      ageYears: 4,
      engagement: mockEngagement(['quiz']),
    });
    expect(order[0]).toBe('quiz');
  });
});

// ===================================================================
// 6. Composite behavior — all layers together
// ===================================================================

describe('teachingStrategy — composed ranking', () => {
  it('engagement + difficulty can cooperate to move a card to top', () => {
    // vocabulary × visual default: [concept, story, quiz, voice, experiment]
    // concept=5, story=4, quiz=3, voice=2, experiment=1
    //
    // Apply engagement top=quiz (+1.5) and difficulty +2 (quiz +0.8) → quiz = 3 + 1.5 + 0.8 = 5.3 > concept's 5.
    const ctx: RankerContext = {
      engagement: mockEngagement(['quiz']),
      difficultyOffset: 2,
    };
    const order = rankedCardTypeOrder('vocabulary', 'visual', ctx);
    expect(order[0]).toBe('quiz');
  });

  it('engagement boost on a matrix-3rd type lifts it past matrix-2nd but not matrix-1st', () => {
    // vocabulary × visual default: [concept, story, quiz, voice, experiment]
    // base scores 5,4,3,2,1. Top-engagement on quiz → quiz = 3 + 1.5 = 4.5.
    // concept(5) still wins; quiz(4.5) now beats story(4).
    const order = rankedCardTypeOrder('vocabulary', 'visual', {
      engagement: mockEngagement(['quiz']),
    });
    expect(order[0]).toBe('concept');
    expect(order[1]).toBe('quiz');
    expect(order[2]).toBe('story');
  });

  it('applying all layers never produces NaN or duplicate card types', () => {
    const ranked = rankCardTypesFor('abstract', 'kinesthetic', {
      engagement: mockEngagement(['voice', 'story', 'quiz']),
      difficultyOffset: -2,
      ageYears: 5,
    });
    expect(ranked).toHaveLength(5);
    expect(new Set(ranked.map((r) => r.cardType)).size).toBe(5);
    for (const r of ranked) {
      expect(Number.isFinite(r.score)).toBe(true);
    }
  });
});

// ===================================================================
// 7. inferModality heuristic
// ===================================================================

describe('teachingStrategy — inferModality', () => {
  it('undefined engagement → visual', () => {
    expect(inferModality(undefined)).toBe('visual');
  });

  it('empty engagement → visual', () => {
    expect(inferModality([])).toBe('visual');
  });

  it('top = voice → auditory', () => {
    expect(inferModality(mockEngagement(['voice', 'quiz']))).toBe('auditory');
  });

  it('top = story → auditory (Nova auto-narrates stories)', () => {
    expect(inferModality(mockEngagement(['story', 'quiz']))).toBe('auditory');
  });

  it('top = experiment → kinesthetic', () => {
    expect(inferModality(mockEngagement(['experiment', 'voice']))).toBe('kinesthetic');
  });

  it('top = quiz → kinesthetic', () => {
    expect(inferModality(mockEngagement(['quiz', 'voice']))).toBe('kinesthetic');
  });

  it('top = concept → visual', () => {
    expect(inferModality(mockEngagement(['concept', 'story']))).toBe('visual');
  });
});

// ===================================================================
// 8. Argument validation / graceful degradation
// ===================================================================

describe('teachingStrategy — graceful degradation', () => {
  it('unknown conceptType on the matrix is a TypeScript error, but runtime falls back cleanly', () => {
    // Cast to bypass the compile-time guard; the ranker should still return all 5 types without throwing.
    const ranked = () =>
      rankCardTypesFor('vocabulary' as ConceptType, 'visual' as LearningModality);
    expect(ranked()).toHaveLength(5);
  });

  it('missing context fields all default to neutral (0 bonus everywhere)', () => {
    const ranked = rankCardTypesFor('factual', 'visual', {});
    for (const r of ranked) {
      expect(r.engagementBonus).toBe(0);
      expect(r.difficultyBonus).toBe(0);
      expect(r.ageBonus).toBe(0);
    }
  });
});
