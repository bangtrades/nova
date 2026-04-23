/**
 * S12-04 · R5 — skillRouter dispatch tests for experiment-designer.
 *
 * Parallel suite to `skillRouter.test.ts` — instead of re-exercising the
 * shared retry / transient-error machinery (which is already covered by
 * the quiz-maker path), this suite proves the three integration points
 * wired in R4:
 *
 *   1. Atoms with `recommendedCardType === 'experiment'` route to the
 *      `experiment-designer` skill via CARD_TYPE_TO_SKILL.
 *   2. `buildSkillInputs('experiment-designer', ...)` derives the right
 *      conceptType via STRATEGY_TO_CONCEPT_TYPE and threads through
 *      topic + lastStoryExcerpt.
 *   3. `buildCardFromSkillOutput('experiment-designer', ...)` turns the
 *      validated JSON into a `GeneratedCard` with `type === 'experiment'`
 *      and the drag-drop payload on `card.content`.
 *
 * Boot the real skill registry once per suite so we exercise the actual
 * Handlebars prompt assembly + Zod validator.
 */
import { describe, it, expect, beforeAll, vi, beforeEach } from 'vitest';
import { routeAtom } from '@services/pipeline/skillRouter';
import { __resetSkillRegistryForTests } from '@services/skills/registry';
import { resolveDefsDir } from '@services/skills/loader';
import type { ChildContext } from '@services/skills/types';
import type { ConceptAtom } from '@services/pipeline/conceptDecomposer';
import type { ContentAnalysis } from '@services/pipeline/contentAnalyzer';
import type { LLMResponse } from '@services/llm/types';

// ---------------------------------------------------------------------------
// Mock the LLM provider router.
// ---------------------------------------------------------------------------

const mockRouteRequest = vi.fn();
vi.mock('@services/llm/providerRouter', () => ({
  routeRequest: (...args: unknown[]) => mockRouteRequest(...args),
}));

const mockResponses: Array<LLMResponse | Error> = [];

function queueResponse(content: string, usage: Partial<LLMResponse['usage']> = {}): void {
  mockResponses.push({
    content,
    model: 'claude-sonnet',
    provider: 'proxy',
    usage: {
      promptTokens: 120,
      completionTokens: 260,
      totalTokens: 380,
      ...usage,
    },
  });
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
    childId: 'child-exp',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-exp',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-exp',
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
      conceptType: 'process',
      modality: 'kinesthetic',
      rankedCardTypes: [],
    },
    difficultyOffset: 0,
    ...overrides,
  };
}

function makeAnalysis(overrides: Partial<ContentAnalysis> = {}): ContentAnalysis {
  return {
    topic: 'States of matter',
    keyConcepts: ['solid', 'liquid', 'gas'],
    suggestedStage: 2,
    ageAppropriate: true,
    safetyFlags: [],
    suggestedCardCount: 3,
    summary:
      'Matter is classified by how its particles move: locked, sliding, or freely spreading.',
    ...overrides,
  };
}

function makeExperimentAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-exp',
    name: 'classifying states of matter',
    description:
      'sort concrete things into solid, liquid, gas buckets by how their particles behave',
    teachingStrategy: 'experiment',
    recommendedCardType: 'experiment',
    engagementScore: 0.7,
    learningValue: 0.85,
    prerequisites: [],
    ...overrides,
  };
}

// A well-formed experiment-designer output that passes every superRefine
// rule. Easy difficulty: (3 items, 2 targets).
const VALID_EXPERIMENT_JSON = JSON.stringify({
  title: 'Sort by Floating',
  instructions: 'Drag each object onto the bin that matches what it does in water.',
  dragItems: [
    { id: 'cork', label: 'Cork' },
    { id: 'rock', label: 'Rock' },
    { id: 'apple', label: 'Apple' },
  ],
  dropTargets: [
    { id: 'floats', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
    { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
  ],
  conceptSummary:
    'Objects less dense than water float; denser objects sink. Shape and trapped air matter too.',
  rationalePerTarget: [
    'Cork and apples are lighter than the water they push out, so they ride on top.',
    'A rock is denser than water, so it falls through and settles at the bottom.',
  ],
});

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('skillRouter — experiment-designer dispatch', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('routes an atom with recommendedCardType="experiment" to experiment-designer', async () => {
    queueResponse(VALID_EXPERIMENT_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom(),
      atomIndex: 2,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.skillName).toBe('experiment-designer');
      expect(result.trace.validatorStatus).toBe('ok');
      expect(result.trace.retryCount).toBe(0);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });

  it('builds a GeneratedCard with type=experiment and the drag-drop payload on content', async () => {
    queueResponse(VALID_EXPERIMENT_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom(),
      atomIndex: 2,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      const card = result.card;
      expect(card.type).toBe('experiment');
      expect(card.sortOrder).toBe(2);

      // The drag-drop shape is carried through on content — camelCase on
      // the backend, remapped to snake_case by the iOS transformer.
      expect(card.content.title).toBe('Sort by Floating');
      expect(card.content.instructions).toMatch(/Drag each object/);
      expect(card.content.dragItems).toHaveLength(3);
      expect(card.content.dragItems?.[0]).toEqual({ id: 'cork', label: 'Cork' });
      expect(card.content.dropTargets).toHaveLength(2);
      expect(card.content.dropTargets?.[0].acceptsItemIds).toEqual(['cork', 'apple']);

      // Voice script = instructions + conceptSummary so the narrator
      // reads both without leaking the classification on the way in.
      expect(card.voiceScript).toContain('Drag each object');
      expect(card.voiceScript).toContain('less dense than water');
    }
  });

  it('derives conceptType=process from teachingStrategy=experiment in the user prompt', async () => {
    queueResponse(VALID_EXPERIMENT_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom({ teachingStrategy: 'experiment' }),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    // The conceptType got rendered into the user turn — it's populated
    // from STRATEGY_TO_CONCEPT_TYPE mapping (experiment → process).
    expect(userTurn.content.toLowerCase()).toContain('process');
  });

  it('threads the analysis.topic into the rendered prompt', async () => {
    queueResponse(VALID_EXPERIMENT_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom(),
      atomIndex: 0,
      analysis: makeAnalysis({ topic: 'States of matter' }),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    expect(userTurn.content).toMatch(/States of matter/);
  });

  it('renders parent topicAvoid boundaries into the system prompt', async () => {
    queueResponse(VALID_EXPERIMENT_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx({
        parentGuidance: {
          childId: 'child-exp',
          topicFocus: [],
          topicAvoid: ['fire', 'sharp things'],
          difficultyOffset: 0,
          contentBoundaries: {},
          dailySessionLimitMinutes: null,
          singleSessionLimitMinutes: null,
          updatedByUserId: 'user-exp',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      atom: makeExperimentAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const systemTurn = call.messages.find((m) => m.role === 'system')!;
    expect(systemTurn.content).toMatch(/fire/);
    expect(systemTurn.content).toMatch(/sharp things/);
  });

  it('retries on validator failure then succeeds (uses the shared S9-07 retry path)', async () => {
    // First response: orphan drag item (apple) — passes the base parse
    // but fails the referential-integrity superRefine.
    queueResponse(
      JSON.stringify({
        title: 'Sort by Floating',
        instructions: 'Drag each object onto the right bin.',
        dragItems: [
          { id: 'cork', label: 'Cork' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' }, // never referenced
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
        conceptSummary:
          'Objects less dense than water float; denser objects sink.',
        rationalePerTarget: [
          'Cork is lighter than water.',
          'Rock is denser than water.',
        ],
      })
    );
    // Second response: valid.
    queueResponse(VALID_EXPERIMENT_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);

    // Retry user turn carries the validator feedback — the orphan
    // message should appear in the retry prompt so the model sees what
    // to fix.
    const retryCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const retryUser = retryCall.messages.find((m) => m.role === 'user')!;
    expect(retryUser.content.toLowerCase()).toMatch(/orphan|apple|reject/);
  });

  it('captures retry-failed when the second attempt also fails the schema', async () => {
    const badPayload = JSON.stringify({
      title: 'Bad sort',
      instructions: 'Drag stuff somewhere today.',
      dragItems: [
        { id: 'a', label: 'A' },
        { id: 'b', label: 'B' },
      ], // too few
      dropTargets: [
        { id: 'x', label: 'X', acceptsItemIds: ['a'] },
        { id: 'y', label: 'Y', acceptsItemIds: ['b'] },
      ],
      conceptSummary: 'Broken on purpose for testing.',
      rationalePerTarget: ['r1', 'r2'],
    });
    queueResponse(badPayload);
    queueResponse(badPayload);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeExperimentAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('skipped');
    if (result.kind === 'skipped') {
      expect(result.reason).toBe('validation-failed');
      expect(result.trace.validatorStatus).toBe('retry-failed');
      expect(result.trace.retryCount).toBe(1);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });
});
