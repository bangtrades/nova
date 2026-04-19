import { describe, it, expect } from 'vitest';
import {
  mergeCardTypeStats,
  mergeTopicAffinities,
  classifyInteractionStream,
  summarizeBatch,
  rankCardTypePreferences,
  rankTopicAffinities,
  RAPID_QUIT_THRESHOLD_MS,
  FLOW_STREAK_TRIGGER,
  FRUSTRATION_CONSECUTIVE_WRONG,
  type InteractionEvent,
  type CardTypeStats,
  type TopicAffinities,
} from '../src/services/engagement/engagementProfiler';

// ============================================================
// S10-03 — Engagement profiler pure-reducer invariants
//
// These tests exercise the functions that run inside
// ingestInteractions() BEFORE the Prisma upsert. They never
// touch the DB or the encryption key, so they run fast and
// don't require the ENCRYPTION_KEY env var.
// ============================================================

/**
 * Factory for a deterministic InteractionEvent — reduces test boilerplate.
 *
 * NOTE: we use `'key' in overrides` instead of `overrides.key ?? default`
 * because nullish-coalescing silently converts explicit `null` / `false`
 * overrides back to the default (e.g. `evt({ domain: null })` would otherwise
 * become `domain: 'computers'`, invalidating the null-domain skip test).
 */
function evt(overrides: Partial<InteractionEvent> = {}): InteractionEvent {
  return {
    cardId: 'cardId' in overrides ? (overrides.cardId as string) : 'card-1',
    cardType: 'cardType' in overrides ? (overrides.cardType as InteractionEvent['cardType']) : 'quiz',
    conceptId: 'conceptId' in overrides ? (overrides.conceptId as string) : 'comp-01',
    domain: 'domain' in overrides ? (overrides.domain as InteractionEvent['domain']) : 'computers',
    action: 'action' in overrides ? (overrides.action as InteractionEvent['action']) : 'answer',
    durationMs: 'durationMs' in overrides ? (overrides.durationMs as number) : 5000,
    isCorrect: 'isCorrect' in overrides ? (overrides.isCorrect as InteractionEvent['isCorrect']) : true,
    timestamp: overrides.timestamp,
  };
}

// ------------------------------------------------------------
// mergeCardTypeStats
// ------------------------------------------------------------

describe('mergeCardTypeStats (S10-03)', () => {
  it('starts from empty and counts one interaction per known type', () => {
    const stats = mergeCardTypeStats({}, [evt({ cardType: 'quiz', durationMs: 4000 })]);
    expect(stats.quiz).toBeDefined();
    expect(stats.quiz!.count).toBe(1);
    expect(stats.quiz!.totalDurationMs).toBe(4000);
    expect(stats.quiz!.completionCount).toBe(1); // correct quiz answer → completion
  });

  it('does not mutate the input object', () => {
    const prior: CardTypeStats = { quiz: { count: 5, totalDurationMs: 10_000, completionCount: 3 } };
    mergeCardTypeStats(prior, [evt({ cardType: 'quiz' })]);
    expect(prior.quiz!.count).toBe(5);
    expect(prior.quiz!.totalDurationMs).toBe(10_000);
    expect(prior.quiz!.completionCount).toBe(3);
  });

  it('accumulates across calls', () => {
    const first = mergeCardTypeStats({}, [
      evt({ cardType: 'story', durationMs: 3000, action: 'complete', isCorrect: null }),
    ]);
    const second = mergeCardTypeStats(first, [
      evt({ cardType: 'story', durationMs: 2000, action: 'view', isCorrect: null }),
    ]);
    expect(second.story!.count).toBe(2);
    expect(second.story!.totalDurationMs).toBe(5000);
    expect(second.story!.completionCount).toBe(1); // one complete, one view
  });

  it('ignores unknown card types (string fallback)', () => {
    const stats = mergeCardTypeStats({}, [
      evt({ cardType: 'some-future-type' as any, durationMs: 1000 }),
    ]);
    expect(stats).toEqual({});
  });

  it('clamps negative durations to 0', () => {
    const stats = mergeCardTypeStats({}, [evt({ durationMs: -500 })]);
    expect(stats.quiz!.totalDurationMs).toBe(0);
  });

  it('only counts completion for action=complete OR correct quiz answer', () => {
    const stats = mergeCardTypeStats({}, [
      evt({ cardType: 'quiz', action: 'answer', isCorrect: true }),
      evt({ cardType: 'quiz', action: 'answer', isCorrect: false }),
      evt({ cardType: 'quiz', action: 'complete', isCorrect: null }),
      evt({ cardType: 'quiz', action: 'view', isCorrect: null }),
    ]);
    expect(stats.quiz!.count).toBe(4);
    expect(stats.quiz!.completionCount).toBe(2); // correct answer + explicit complete
  });
});

// ------------------------------------------------------------
// mergeTopicAffinities
// ------------------------------------------------------------

describe('mergeTopicAffinities (S10-03)', () => {
  it('skips events without a domain', () => {
    const aff = mergeTopicAffinities({}, [evt({ domain: null })]);
    expect(aff).toEqual({});
  });

  it('accumulates count and duration per domain', () => {
    const aff = mergeTopicAffinities({}, [
      evt({ domain: 'computers', durationMs: 3000 }),
      evt({ domain: 'computers', durationMs: 2000 }),
      evt({ domain: 'ai', durationMs: 4000 }),
    ]);
    expect(aff.computers!.count).toBe(2);
    expect(aff.computers!.totalDurationMs).toBe(5000);
    expect(aff.ai!.count).toBe(1);
    expect(aff.ai!.totalDurationMs).toBe(4000);
  });

  it('merges with prior affinities without mutating them', () => {
    const prior: TopicAffinities = { robots: { count: 10, totalDurationMs: 30_000 } };
    const next = mergeTopicAffinities(prior, [evt({ domain: 'robots', durationMs: 5000 })]);
    expect(next.robots!.count).toBe(11);
    expect(next.robots!.totalDurationMs).toBe(35_000);
    expect(prior.robots!.count).toBe(10); // not mutated
  });
});

// ------------------------------------------------------------
// classifyInteractionStream
// ------------------------------------------------------------

describe('classifyInteractionStream — streak + flow (S10-03)', () => {
  it('returns zero events on an empty stream', () => {
    const r = classifyInteractionStream([]);
    expect(r).toEqual({
      frustrationEvents: 0,
      flowEvents: 0,
      endingStreak: 0,
      peakStreak: 0,
    });
  });

  it('fires exactly one flow event at the 2→3 correct-streak transition', () => {
    const events = [
      evt({ isCorrect: true }),
      evt({ isCorrect: true }),
      evt({ isCorrect: true }),
    ];
    const r = classifyInteractionStream(events);
    expect(r.flowEvents).toBe(1);
    expect(r.endingStreak).toBe(3);
    expect(r.peakStreak).toBe(3);
  });

  it('does NOT re-fire flow within the same streak run', () => {
    const events = Array.from({ length: 7 }, () => evt({ isCorrect: true }));
    const r = classifyInteractionStream(events);
    expect(r.flowEvents).toBe(1); // only the 2→3 transition counts
    expect(r.endingStreak).toBe(7);
    expect(r.peakStreak).toBe(7);
  });

  it('fires a SECOND flow event when the streak is broken and rebuilt to 3+', () => {
    const events = [
      evt({ isCorrect: true }),
      evt({ isCorrect: true }),
      evt({ isCorrect: true }), // flow #1
      evt({ isCorrect: false }), // streak reset
      evt({ isCorrect: true }),
      evt({ isCorrect: true }),
      evt({ isCorrect: true }), // flow #2
    ];
    const r = classifyInteractionStream(events);
    expect(r.flowEvents).toBe(2);
    expect(r.endingStreak).toBe(3);
  });

  it('honors the initialStreak parameter for cross-batch continuity', () => {
    // Prior state: child already has a 2-correct streak from last sync.
    // One more correct answer should fire the flow event.
    const r = classifyInteractionStream([evt({ isCorrect: true })], 2);
    expect(r.flowEvents).toBe(1);
    expect(r.endingStreak).toBe(3);
  });

  it('never lets peakStreak drop below the initialStreak', () => {
    const r = classifyInteractionStream([evt({ isCorrect: false })], 5);
    expect(r.peakStreak).toBe(5);
    expect(r.endingStreak).toBe(0);
  });
});

describe('classifyInteractionStream — frustration (S10-03)', () => {
  it('does NOT fire frustration on the first wrong answer', () => {
    const r = classifyInteractionStream([evt({ isCorrect: false, conceptId: 'comp-01' })]);
    expect(r.frustrationEvents).toBe(0);
  });

  it('fires frustration on the 2nd consecutive wrong answer on the SAME concept', () => {
    const r = classifyInteractionStream([
      evt({ isCorrect: false, conceptId: 'comp-01' }),
      evt({ isCorrect: false, conceptId: 'comp-01' }),
    ]);
    expect(r.frustrationEvents).toBe(1);
  });

  it('fires one more frustration on EACH additional consecutive wrong on the same concept', () => {
    const r = classifyInteractionStream([
      evt({ isCorrect: false, conceptId: 'comp-01' }),
      evt({ isCorrect: false, conceptId: 'comp-01' }),
      evt({ isCorrect: false, conceptId: 'comp-01' }),
      evt({ isCorrect: false, conceptId: 'comp-01' }),
    ]);
    expect(r.frustrationEvents).toBe(3); // wrong #2, #3, #4 each fire
  });

  it('resets the consecutive-wrong counter when the concept changes', () => {
    const r = classifyInteractionStream([
      evt({ isCorrect: false, conceptId: 'comp-01' }),
      evt({ isCorrect: false, conceptId: 'comp-02' }), // DIFFERENT concept → new streak
      evt({ isCorrect: false, conceptId: 'comp-02' }), // 2nd wrong on comp-02 → 1 event
    ]);
    expect(r.frustrationEvents).toBe(1);
  });

  it('fires rapid-quit frustration on any non-answer action below the threshold', () => {
    const r = classifyInteractionStream([
      evt({
        action: 'view',
        isCorrect: null,
        durationMs: RAPID_QUIT_THRESHOLD_MS - 1,
      }),
    ]);
    expect(r.frustrationEvents).toBe(1);
  });

  it('does NOT fire rapid-quit at or above the threshold', () => {
    const r = classifyInteractionStream([
      evt({ action: 'view', isCorrect: null, durationMs: RAPID_QUIT_THRESHOLD_MS }),
      evt({ action: 'view', isCorrect: null, durationMs: 10_000 }),
    ]);
    expect(r.frustrationEvents).toBe(0);
  });

  it('does NOT fire rapid-quit on an answer action regardless of duration', () => {
    const r = classifyInteractionStream([
      evt({ action: 'answer', isCorrect: true, durationMs: 100 }),
      evt({ action: 'answer', isCorrect: false, conceptId: 'comp-01', durationMs: 200 }),
    ]);
    expect(r.frustrationEvents).toBe(0);
  });
});

// ------------------------------------------------------------
// summarizeBatch
// ------------------------------------------------------------

describe('summarizeBatch (S10-03)', () => {
  it('sums duration and tallies answers/correctness', () => {
    const r = summarizeBatch([
      evt({ action: 'answer', isCorrect: true, durationMs: 1000 }),
      evt({ action: 'answer', isCorrect: false, durationMs: 2000 }),
      evt({ action: 'view', isCorrect: null, durationMs: 3000 }),
    ]);
    expect(r.totalDurationMs).toBe(6000);
    expect(r.answerCount).toBe(2);
    expect(r.correctCount).toBe(1);
  });

  it('treats negative durations as zero', () => {
    const r = summarizeBatch([evt({ durationMs: -100 }), evt({ durationMs: 500 })]);
    expect(r.totalDurationMs).toBe(500);
  });
});

// ------------------------------------------------------------
// rankCardTypePreferences
// ------------------------------------------------------------

describe('rankCardTypePreferences (S10-03)', () => {
  it('returns an empty array for empty stats', () => {
    expect(rankCardTypePreferences({})).toEqual([]);
  });

  it('skips card types with count=0', () => {
    const ranked = rankCardTypePreferences({
      story: { count: 0, totalDurationMs: 0, completionCount: 0 },
    });
    expect(ranked).toEqual([]);
  });

  it('ranks card types by completion * log10(1 + durationSec) descending', () => {
    const stats: CardTypeStats = {
      story: { count: 10, totalDurationMs: 300_000, completionCount: 8 },
      quiz: { count: 10, totalDurationMs: 30_000, completionCount: 9 },
      voice: { count: 5, totalDurationMs: 100_000, completionCount: 1 },
    };
    const ranked = rankCardTypePreferences(stats);
    expect(ranked[0].type).toBe('story'); // high completion + high duration wins
    expect(ranked[ranked.length - 1].type).toBe('voice'); // low completion = low score
    // Scores sorted descending
    for (let i = 0; i < ranked.length - 1; i++) {
      expect(ranked[i].score).toBeGreaterThanOrEqual(ranked[i + 1].score);
    }
  });

  it('reports completion rate and avg duration rounded sensibly', () => {
    const ranked = rankCardTypePreferences({
      quiz: { count: 4, totalDurationMs: 10_000, completionCount: 3 },
    });
    expect(ranked[0].completionRate).toBe(0.75);
    expect(ranked[0].avgDurationMs).toBe(2500);
  });
});

// ------------------------------------------------------------
// rankTopicAffinities
// ------------------------------------------------------------

describe('rankTopicAffinities (S10-03)', () => {
  it('returns an empty array for empty affinities', () => {
    expect(rankTopicAffinities({})).toEqual([]);
  });

  it('ranks domains by count * log10(1 + durationSec) descending', () => {
    const aff: TopicAffinities = {
      computers: { count: 20, totalDurationMs: 60_000 },
      ai: { count: 3, totalDurationMs: 300_000 },
      robots: { count: 5, totalDurationMs: 15_000 },
    };
    const ranked = rankTopicAffinities(aff);
    expect(ranked.length).toBe(3);
    // High count + decent duration wins
    expect(ranked[0].domain).toBe('computers');
    // Scores sorted descending
    for (let i = 0; i < ranked.length - 1; i++) {
      expect(ranked[i].score).toBeGreaterThanOrEqual(ranked[i + 1].score);
    }
  });
});

// ------------------------------------------------------------
// Tunable constants — guard against silent drift
// ------------------------------------------------------------

describe('engagement tunables (S10-03) — lock the DoD values', () => {
  it('RAPID_QUIT_THRESHOLD_MS matches the spec (2000ms)', () => {
    expect(RAPID_QUIT_THRESHOLD_MS).toBe(2000);
  });
  it('FLOW_STREAK_TRIGGER matches the spec (3)', () => {
    expect(FLOW_STREAK_TRIGGER).toBe(3);
  });
  it('FRUSTRATION_CONSECUTIVE_WRONG matches the spec (2)', () => {
    expect(FRUSTRATION_CONSECUTIVE_WRONG).toBe(2);
  });
});
