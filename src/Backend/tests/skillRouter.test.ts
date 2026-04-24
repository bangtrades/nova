/**
 * S10-12 · R6 — skillRouter unit tests.
 *
 * These tests mock `routeRequest` from the LLM provider router so they run
 * with zero network + zero database. The real skill registry (story-writer
 * + quiz-maker from `defs/`) is booted once per suite so we exercise the
 * actual Handlebars prompt assembly and Zod validators.
 *
 * Coverage matrix:
 *   - atom → skill lookup (happy path, unknown card type skip, missing skill skip)
 *   - quiz-maker validator-pass happy path
 *   - quiz-maker validator-fail → retry-pass (closes S9-07 debt)
 *   - quiz-maker validator-fail → retry-fail (skip with retry-failed status)
 *   - quiz-maker json-parse-error → retry-pass
 *   - story-writer no-schema path (raw prose accepted)
 *   - transient LLM error is re-thrown (runStage domain)
 *   - non-transient LLM error is captured in the trace (skip)
 *   - routeAllAtoms threads lastStoryExcerpt from story to subsequent quiz atoms
 */
import { describe, it, expect, beforeAll, vi, beforeEach } from 'vitest';
import { routeAtom, routeAllAtoms } from '@services/pipeline/skillRouter';
import {
  __resetSkillRegistryForTests,
} from '@services/skills/registry';
import { resolveDefsDir } from '@services/skills/loader';
import type { ChildContext } from '@services/skills/types';
import type { ConceptAtom } from '@services/pipeline/conceptDecomposer';
import type { ContentAnalysis } from '@services/pipeline/contentAnalyzer';
import type { LLMResponse } from '@services/llm/types';

// ---------------------------------------------------------------------------
// Mock the LLM provider router. Every test sets its own per-call queue of
// responses via `mockResponses.push(...)`.
// ---------------------------------------------------------------------------

const mockRouteRequest = vi.fn();
vi.mock('@services/llm/providerRouter', () => ({
  routeRequest: (...args: unknown[]) => mockRouteRequest(...args),
}));

// Queue-based stub so one test can script multiple sequential responses
// (first-attempt + retry).
const mockResponses: Array<LLMResponse | Error> = [];

function queueResponse(content: string, usage: Partial<LLMResponse['usage']> = {}): void {
  mockResponses.push({
    content,
    model: 'claude-sonnet',
    provider: 'proxy',
    usage: {
      promptTokens: 100,
      completionTokens: 200,
      totalTokens: 300,
      ...usage,
    },
  });
}

function queueError(err: Error): void {
  mockResponses.push(err);
}

beforeEach(() => {
  mockResponses.length = 0;
  mockRouteRequest.mockReset();
  mockRouteRequest.mockImplementation(async () => {
    const next = mockResponses.shift();
    if (!next) throw new Error('mockRouteRequest called with empty queue');
    if (next instanceof Error) throw next;
    return next;
  });
});

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

function makeCtx(overrides: Partial<ChildContext> = {}): ChildContext {
  return {
    childId: 'child-rt',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-rt',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-rt',
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
    teachingStrategy: {
      conceptType: 'abstract',
      modality: 'visual',
      rankedCardTypes: [],
    },
    difficultyOffset: 0,
    ...overrides,
  };
}

function makeAnalysis(overrides: Partial<ContentAnalysis> = {}): ContentAnalysis {
  return {
    topic: 'Gravity',
    keyConcepts: ['pull', 'weight', 'earth'],
    suggestedStage: 2,
    ageAppropriate: true,
    safetyFlags: [],
    suggestedCardCount: 3,
    summary: 'Everything with mass pulls on everything else.',
    ...overrides,
  };
}

function makeStoryAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-story',
    name: 'things fall down',
    description: 'everyday experience of gravity',
    teachingStrategy: 'narrative',
    recommendedCardType: 'story',
    engagementScore: 0.8,
    learningValue: 0.8,
    prerequisites: [],
    ...overrides,
  };
}

function makeQuizAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-quiz',
    name: 'what pulls the apple down',
    description: 'testing the learner on the concept of gravity',
    teachingStrategy: 'quiz',
    recommendedCardType: 'quiz',
    engagementScore: 0.6,
    learningValue: 0.9,
    prerequisites: [],
    ...overrides,
  };
}

const VALID_QUIZ_JSON = JSON.stringify({
  question: 'What pulls the apple toward the ground?',
  options: ['Gravity', 'The wind', 'The sun'],
  correctIndex: 0,
  explanation: 'Gravity is the force that pulls things with mass toward each other.',
  rationalePerOption: [
    'Correct — gravity is the invisible pull from Earth.',
    'Wind can push things sideways but does not pull down.',
    'The sun is far away and does not pull apples on Earth.',
  ],
});

// ---------------------------------------------------------------------------
// Suite — boot the real skill registry once (reads defs from disk).
// ---------------------------------------------------------------------------

describe('skillRouter — routeAtom', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  // -------------------------------------------------------------------------
  // Skill lookup paths
  // -------------------------------------------------------------------------

  it('skips atoms whose cardType has no skill mapping (defensive guard)', async () => {
    // S12-10 update: concept + voice + experiment are all mapped now,
    // so we cast a synthetic non-mapped string to exercise the router's
    // defensive guard. Protects us when curriculum-architect emits a
    // future cardType we haven't wired yet.
    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeStoryAtom({
        recommendedCardType: 'unmapped-future-type' as unknown as 'story',
      }),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('no-skill-mapping');
      expect(result.trace.validatorStatus).toBe('skipped');
      expect(result.trace.retryCount).toBe(0);
      expect(result.trace.skillName).toBeNull();
    }
    expect(mockRouteRequest).not.toHaveBeenCalled();
  });

  it('skips with skill-not-loaded when a custom registry says the skill is missing', async () => {
    const stubReg = {
      has: () => false,
      get: () => {
        throw new Error('should not reach');
      },
    };
    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeStoryAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
      registry: stubReg,
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('skill-not-loaded');
      expect(result.trace.skillName).toBe('story-writer');
    }
    expect(mockRouteRequest).not.toHaveBeenCalled();
  });

  // -------------------------------------------------------------------------
  // Happy-path quiz-maker
  // -------------------------------------------------------------------------

  it('routes a quiz atom through quiz-maker and returns a validated card', async () => {
    queueResponse(VALID_QUIZ_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeQuizAtom(),
      atomIndex: 1,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.card.type).toBe('quiz');
      expect(result.card.content.text).toBe(
        'What pulls the apple toward the ground?'
      );
      expect(result.card.content.options).toHaveLength(3);
      expect(result.card.content.correctIndex).toBe(0);
      expect(result.card.sortOrder).toBe(1);
      expect(result.card.voiceScript).toContain('What pulls the apple');
      expect(result.card.voiceScript).toContain('Gravity is the force');
      expect(result.trace.validatorStatus).toBe('ok');
      expect(result.trace.retryCount).toBe(0);
      expect(result.trace.skillName).toBe('quiz-maker');
      expect(result.trace.tokens?.total).toBe(300);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });

  // -------------------------------------------------------------------------
  // Retry-on-validation-failure (closes S9-07 carried debt)
  // -------------------------------------------------------------------------

  it('retries on Zod validation failure, succeeds on second attempt, marks retry-ok', async () => {
    // First response: options length out of range (2 < 3) — Zod will reject.
    queueResponse(
      JSON.stringify({
        question: 'Too few options?',
        options: ['A', 'B'],
        correctIndex: 0,
        explanation: 'First attempt is broken.',
        rationalePerOption: ['a', 'b'],
      })
    );
    // Second response: well-formed.
    queueResponse(VALID_QUIZ_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeQuizAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
      expect(result.trace.tokens?.total).toBe(600); // 300 + 300
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
    // Retry user turn should carry the validator feedback.
    const retryCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const retryUser = retryCall.messages.find((m) => m.role === 'user')!;
    expect(retryUser.content).toMatch(/previous attempt was rejected/i);
    expect(retryUser.content).toMatch(/options/);
  });

  it('lowers retry temperature by 0.1 relative to first attempt', async () => {
    queueResponse(
      JSON.stringify({
        question: 'Still broken?',
        options: ['only-one'],
        correctIndex: 0,
        explanation: 'nope',
        rationalePerOption: ['x'],
      })
    );
    queueResponse(VALID_QUIZ_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeQuizAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    const firstCall = mockRouteRequest.mock.calls[0]![1] as { temperature: number };
    const retryCall = mockRouteRequest.mock.calls[1]![1] as { temperature: number };
    expect(retryCall.temperature).toBeCloseTo(firstCall.temperature - 0.1, 5);
    expect(retryCall.temperature).toBeGreaterThanOrEqual(0);
  });

  it('captures retry-failed when second attempt also fails validation', async () => {
    queueResponse(
      JSON.stringify({
        question: 'Try 1',
        options: ['A'],
        correctIndex: 0,
        explanation: 'bad',
        rationalePerOption: ['x'],
      })
    );
    queueResponse(
      JSON.stringify({
        question: 'Try 2',
        options: ['A', 'B'],
        correctIndex: 0,
        explanation: 'still bad',
        rationalePerOption: ['x', 'y'],
      })
    );

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeQuizAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('validation-failed');
      expect(result.trace.validatorStatus).toBe('retry-failed');
      expect(result.trace.retryCount).toBe(1);
      expect(result.trace.error).toMatch(/options/);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  it('retries on JSON-parse error and succeeds when retry is clean', async () => {
    // Garbage response: no JSON object at all.
    queueResponse('sorry, I cannot answer that today.');
    queueResponse(VALID_QUIZ_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeQuizAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
    }
  });

  // -------------------------------------------------------------------------
  // story-writer (no-schema path)
  // -------------------------------------------------------------------------

  it('accepts raw prose for story-writer (no outputSchema) on first attempt', async () => {
    const story =
      'Long, long ago a tiny apple hung from a branch. The apple felt a gentle pull. It was gravity!';
    queueResponse(story);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeStoryAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.card.type).toBe('story');
      expect(result.card.content.text).toBe(story);
      expect(result.card.content.title).toBe('things fall down');
      expect(result.card.voiceScript).toBe(story);
      expect(result.trace.skillName).toBe('story-writer');
      expect(result.trace.validatorStatus).toBe('ok');
    }
  });

  it('skips with empty-response when LLM returns blank content', async () => {
    queueResponse('   \n\n   ');

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeStoryAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('empty-response');
    }
  });

  // -------------------------------------------------------------------------
  // Transient vs non-transient LLM errors
  // -------------------------------------------------------------------------

  it('re-throws transient LLM errors so runStage can retry', async () => {
    queueError(new Error('request timeout exceeded'));

    await expect(
      routeAtom({
        userId: 'u1',
        baseContext: makeCtx(),
        atom: makeStoryAtom(),
        atomIndex: 0,
        analysis: makeAnalysis(),
      })
    ).rejects.toThrow(/timeout/);
  });

  it('captures non-transient LLM errors in the trace (skip, no retry)', async () => {
    queueError(new Error('400 invalid api key'));

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeStoryAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('llm-error');
      expect(result.trace.error).toMatch(/invalid api key/);
    }
  });
});

// ---------------------------------------------------------------------------
// routeAllAtoms — integration-ish: multiple atoms in sequence.
// ---------------------------------------------------------------------------

describe('skillRouter — routeAllAtoms', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('runs atoms sequentially and threads story excerpt to later quiz atoms', async () => {
    const story =
      'Once a small apple hung from a tree. Gravity gently whispered, "come down." The apple fell.';
    queueResponse(story); // story atom
    queueResponse(VALID_QUIZ_JSON); // quiz atom

    const out = await routeAllAtoms(
      [makeStoryAtom(), makeQuizAtom()],
      {
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
      }
    );

    expect(out.results).toHaveLength(2);
    expect(out.skipped).toHaveLength(0);
    expect(out.traces).toHaveLength(2);
    expect(out.results[0].kind).toBe('ok');
    expect(out.results[1].kind).toBe('ok');

    // The quiz user prompt should contain the story excerpt because
    // lastStoryExcerpt was threaded through.
    const quizCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const quizUser = quizCall.messages.find((m) => m.role === 'user')!;
    expect(quizUser.content).toMatch(/apple|gravity|tree/i);
  });

  it('records every atom in traces (including skipped ones) and preserves order', async () => {
    queueResponse(VALID_QUIZ_JSON);

    const out = await routeAllAtoms(
      [
        // S12-10: synthetic unmapped cardType to force the skip path.
        makeStoryAtom({
          recommendedCardType: 'unmapped-future-type' as unknown as 'story',
        }),
        makeQuizAtom(),
      ],
      {
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
      }
    );

    expect(out.traces).toHaveLength(2);
    expect(out.traces[0].skipReason).toBe('no-skill-mapping');
    expect(out.traces[1].validatorStatus).toBe('ok');
    expect(out.skipped).toEqual([
      { atomId: 'atom-story', reason: 'no-skill-mapping' },
    ]);
  });

  it('aborts the loop if a transient LLM error surfaces mid-run', async () => {
    queueResponse('first story');
    queueError(new Error('upstream 503 service unavailable'));

    await expect(
      routeAllAtoms([makeStoryAtom(), makeQuizAtom()], {
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
      })
    ).rejects.toThrow(/503|service unavailable/i);
  });
});
