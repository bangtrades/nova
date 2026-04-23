/**
 * S12-06 · R5 — skillRouter dispatch tests for voice-persona.
 *
 * Parallel suite to `experimentDesignerRouter.test.ts` — instead of
 * re-exercising the shared retry / transient-error machinery (already
 * covered by the quiz-maker + experiment-designer paths), this suite
 * proves the integration points wired in R4:
 *
 *   1. Atoms with `recommendedCardType === 'voice'` route to the
 *      `voice-persona` skill via CARD_TYPE_TO_SKILL (not the legacy
 *      voice path in cardGenerator.ts anymore).
 *   2. `buildSkillInputs('voice-persona', ...)` derives conceptType
 *      from the atom's teachingStrategy and threads topic +
 *      lastStoryExcerpt through.
 *   3. `buildCardFromSkillOutput('voice-persona', ...)` emits a
 *      `GeneratedCard` with `type === 'voice'`, camelCase
 *      `promptText` + `expectedResponses` on `content` matching the
 *      iOS `Card.CardContent` shape, and
 *      `voiceScript = promptText + ' ' + celebration`.
 *   4. SKILL_MAX_TOKENS sets the voice-persona ceiling at 700.
 *   5. SKILL_TO_MODEL routes voice-persona to claude-sonnet.
 *
 * Boot the real skill registry once per suite so we exercise the
 * actual Handlebars prompt assembly + Zod validator.
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
      promptTokens: 180,
      completionTokens: 220,
      totalTokens: 400,
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
    childId: 'child-voice',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-voice',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-voice',
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
    interestTopics: [],
    teachingStrategy: {
      conceptType: 'factual',
      modality: 'auditory',
      rankedCardTypes: [],
    },
    difficultyOffset: 0,
    ...overrides,
  };
}

function makeAnalysis(overrides: Partial<ContentAnalysis> = {}): ContentAnalysis {
  return {
    topic: 'Mammals',
    keyConcepts: ['mammal', 'warm-blooded', 'milk'],
    suggestedStage: 2,
    ageAppropriate: true,
    safetyFlags: [],
    suggestedCardCount: 3,
    summary:
      'Mammals are warm-blooded animals that feed milk to their babies. Dogs, humans, whales are mammals.',
    ...overrides,
  };
}

function makeVoiceAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-voice',
    name: 'the word for an animal that feeds milk to its babies',
    description:
      'recall the category-word "mammal" aloud from a definition-clue prompt',
    teachingStrategy: 'voice',
    recommendedCardType: 'voice',
    engagementScore: 0.75,
    learningValue: 0.8,
    prerequisites: [],
    ...overrides,
  };
}

// A well-formed voice-persona output that passes every superRefine rule.
const VALID_VOICE_JSON = JSON.stringify({
  title: 'Mammal word',
  promptText:
    "I learned a word today for an animal that gives milk to its babies — but I can't remember it. Do you?",
  expectedResponses: ['mammal', 'a mammal', 'mammals'],
  celebration: "Yes! I was hoping you'd remember — it was stuck in my head.",
  retryHint: "Hmm, not the one I meant — I was picturing a milk-feeder.",
  conceptSummary:
    'A mammal is an animal that feeds milk to its babies — the child named the category aloud.',
});

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('skillRouter — voice-persona dispatch', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  it('routes an atom with recommendedCardType="voice" to voice-persona (not the legacy voice path)', async () => {
    queueResponse(VALID_VOICE_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 3,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.skillName).toBe('voice-persona');
      expect(result.trace.validatorStatus).toBe('ok');
      expect(result.trace.retryCount).toBe(0);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });

  it('builds a GeneratedCard with type=voice and the Dashy payload on content', async () => {
    queueResponse(VALID_VOICE_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 3,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      const card = result.card;
      expect(card.type).toBe('voice');
      expect(card.sortOrder).toBe(3);

      // iOS VoiceCardView decodes card.content.promptText +
      // expectedResponses directly — camelCase all the way through.
      expect(card.content.title).toBe('Mammal word');
      expect(card.content.promptText).toMatch(/I learned a word/);
      expect(card.content.expectedResponses).toEqual(['mammal', 'a mammal', 'mammals']);
      expect(card.content.celebration).toMatch(/Yes!/);
      expect(card.content.retryHint).toMatch(/not the one I meant/);

      // Voice script = promptText + celebration. The retryHint is NOT
      // part of the default voiceScript because it only fires on a
      // miss — iPad reads it on-demand from content.retryHint.
      expect(card.voiceScript).toContain('I learned a word');
      expect(card.voiceScript).toContain('stuck in my head');
      expect(card.voiceScript).not.toContain('picturing a milk-feeder'); // retryHint absent
    }
  });

  it('threads the analysis.topic into the rendered user prompt', async () => {
    queueResponse(VALID_VOICE_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 0,
      analysis: makeAnalysis({ topic: 'Mammals' }),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    expect(userTurn.content).toMatch(/Mammals/);
  });

  it('passes lastStoryExcerpt so Dashy can reference shared context', async () => {
    queueResponse(VALID_VOICE_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
      lastStoryExcerpt:
        'Once there was a furry animal that carried its babies in a pouch...',
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    expect(userTurn.content).toMatch(/pouch/);
  });

  it('calls the LLM with claude-sonnet and maxTokens=700', async () => {
    queueResponse(VALID_VOICE_JSON);

    await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    const firstCall = mockRouteRequest.mock.calls[0]![1] as {
      model: string;
      maxTokens: number;
    };
    expect(firstCall.model).toBe('claude-sonnet');
    expect(firstCall.maxTokens).toBe(700);
  });

  it('retries on validator failure then succeeds (shared S9-07 retry path)', async () => {
    // First response: voice-of-god phrase in promptText — fails the
    // first-person-only / no-instructional superRefine.
    queueResponse(
      JSON.stringify({
        title: 'Mammal word',
        promptText: "You will know this — what do we call an animal that gives milk?",
        expectedResponses: ['mammal', 'a mammal'],
        celebration: "We got it! Nice one.",
        retryHint: "Hmm, let me think again.",
        conceptSummary:
          'A mammal is an animal that feeds milk to its babies — the child named the category aloud.',
      }),
    );
    queueResponse(VALID_VOICE_JSON);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
      atomIndex: 0,
      analysis: makeAnalysis(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);

    // Retry user turn carries the validator feedback — the voice-of-god
    // rejection should appear in the retry prompt so the model sees
    // what to fix.
    const retryCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const retryUser = retryCall.messages.find((m) => m.role === 'user')!;
    expect(retryUser.content.toLowerCase()).toMatch(/you will|voice-of-god|reject|first-person/);
  });

  it('captures retry-failed when the second attempt also fails the schema', async () => {
    // Both attempts have "good job" in celebration — banned voice-of-god
    // praise. Validator fails twice; router returns skipped with the
    // validation-failed reason.
    const badPayload = JSON.stringify({
      promptText: "I wonder — what's the word for a baby cat?",
      expectedResponses: ['kitten'],
      celebration: "Good job! We got it.",
      retryHint: "Hmm, let me think again.",
      conceptSummary: 'The word is kitten — the child said it aloud.',
    });
    queueResponse(badPayload);
    queueResponse(badPayload);

    const result = await routeAtom({
      userId: 'u1',
      baseContext: makeCtx(),
      atom: makeVoiceAtom(),
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
