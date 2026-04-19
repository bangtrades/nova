/**
 * S10-12 · R6 — pipelineSkillIntegration tests.
 *
 * Integration-grade coverage for `generateCardsWithSkills` — the adapter
 * that stitches skillRouter's per-atom output back into the flat
 * `GeneratedCard[]` contract the rest of the pipeline speaks, plus the
 * `isSkillEngineStage4Enabled` feature flag helper.
 *
 * These tests deliberately sit one level above `skillRouter.test.ts`:
 * they boot the real registry and the real skillRouter code, mock only
 * the LLM boundary (`routeRequest`), and verify the adapter's three
 * merge behaviors:
 *
 *   1. Every atom routes successfully → legacy path is NEVER invoked
 *      (saves a full LLM round-trip in the happy case).
 *   2. Some atoms skip (e.g. unmapped card types like `concept`) → legacy
 *      is invoked exactly once and the adapter cherry-picks legacy
 *      cards at the skipped atom indices.
 *   3. Legacy fallback itself fails → we ship whatever the skill engine
 *      produced rather than nothing (partial > empty).
 *
 * Plus a tight flag-suite for `isSkillEngineStage4Enabled` covering the
 * string values documented in the orchestrator.
 */
import {
  describe,
  it,
  expect,
  beforeAll,
  beforeEach,
  afterEach,
  vi,
} from 'vitest';
import {
  generateCardsWithSkills,
  isSkillEngineStage4Enabled,
  type GeneratedCard,
} from '@services/pipeline/cardGenerator';
import { __resetSkillRegistryForTests } from '@services/skills/registry';
import { resolveDefsDir } from '@services/skills/loader';
import type { ChildContext } from '@services/skills/types';
import type {
  ConceptAtom,
  ConceptDecomposition,
} from '@services/pipeline/conceptDecomposer';
import type { ContentAnalysis } from '@services/pipeline/contentAnalyzer';
import type { ScrapedContent } from '@services/pipeline/scraper';
import type { LLMResponse } from '@services/llm/types';

// ---------------------------------------------------------------------------
// Mock the LLM provider router — the single boundary between skill engine
// code and the rest of the world. All routing (skill + legacy) funnels
// through `routeRequest`, so a single mock covers both paths.
// ---------------------------------------------------------------------------

const mockRouteRequest = vi.fn();
vi.mock('@services/llm/providerRouter', () => ({
  routeRequest: (...args: unknown[]) => mockRouteRequest(...args),
}));

type QueueItem = LLMResponse | Error;
const mockResponses: QueueItem[] = [];

function queueResponse(
  content: string,
  usage: Partial<LLMResponse['usage']> = {}
): void {
  mockResponses.push({
    content,
    model: 'claude-sonnet',
    provider: 'proxy',
    usage: {
      promptTokens: 80,
      completionTokens: 120,
      totalTokens: 200,
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
// Fixtures
// ---------------------------------------------------------------------------

function makeCtx(overrides: Partial<ChildContext> = {}): ChildContext {
  return {
    childId: 'child-int',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-int',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-int',
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

function makeScraped(overrides: Partial<ScrapedContent> = {}): ScrapedContent {
  return {
    url: 'https://example.com/gravity',
    title: 'Gravity for Kids',
    content: 'Gravity is the invisible pull that keeps us on the ground.',
    excerpt: 'Invisible pull.',
    siteName: 'Example',
    byline: '',
    length: 60,
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

function makeConceptAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  // `concept` is NOT in CARD_TYPE_TO_SKILL (S10-12) — routing this atom
  // produces a `no-skill-mapping` skip, forcing the legacy path.
  return {
    id: 'atom-concept',
    name: 'force as a vector',
    description: 'gravity pulls straight down',
    teachingStrategy: 'explanation',
    recommendedCardType: 'concept',
    engagementScore: 0.5,
    learningValue: 0.9,
    prerequisites: [],
    ...overrides,
  };
}

function makeDecomposition(atoms: ConceptAtom[]): ConceptDecomposition {
  return {
    atoms,
    rationale: 'test rationale',
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

const VALID_STORY_PROSE =
  'Once upon a time, an apple hung from a branch. The apple let go and ' +
  'traveled straight down until it landed on the soft grass below. That ' +
  'invisible tug, the one that called the apple home, is what we call ' +
  'gravity.';

/**
 * A well-formed legacy-generator JSON array with 3 cards: a story, a
 * concept (the one the skill engine CAN'T handle yet), and a trailing
 * quiz wrap-up. Matches validateAndNormalizeCard's shape expectations.
 */
function legacyThreeCardArray(): string {
  return JSON.stringify([
    {
      type: 'story',
      content: {
        text: 'LEGACY story text about apples falling.',
        title: 'Apples Fall',
      },
      voiceScript: 'LEGACY story narration.',
    },
    {
      type: 'concept',
      content: {
        title: 'Force',
        text: 'LEGACY concept text about force direction.',
      },
      voiceScript: 'LEGACY concept narration.',
    },
    {
      type: 'quiz',
      content: {
        text: 'LEGACY wrap-up quiz question?',
        options: ['A', 'B', 'C'],
        correctIndex: 1,
      },
      voiceScript: 'LEGACY quiz narration.',
    },
  ]);
}

// ---------------------------------------------------------------------------
// Suite — generateCardsWithSkills
// ---------------------------------------------------------------------------

describe('generateCardsWithSkills — skill-engine orchestration', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  // -------------------------------------------------------------------------
  // Happy path — every atom routes, legacy never runs
  // -------------------------------------------------------------------------

  it('produces a card per atom without invoking the legacy path when every atom routes', async () => {
    // Two atoms: one story, one quiz. Both map to skills.
    const atoms = [makeStoryAtom(), makeQuizAtom()];
    // Queue the TWO skill responses in atom order.
    queueResponse(VALID_STORY_PROSE);
    queueResponse(VALID_QUIZ_JSON);

    const result = await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    expect(result.cards).toHaveLength(2);
    expect(result.cards[0].type).toBe('story');
    expect(result.cards[1].type).toBe('quiz');
    expect(result.cards[0].sortOrder).toBe(0);
    expect(result.cards[1].sortOrder).toBe(1);
    expect(result.skipped).toEqual([]);
    expect(result.usedLegacyFallback).toBe(false);
    expect(result.traces).toHaveLength(2);
    expect(result.traces[0].validatorStatus).toBe('ok');
    expect(result.traces[1].validatorStatus).toBe('ok');

    // Exactly 2 LLM calls — one per atom. No legacy round-trip.
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  it('threads lastStoryExcerpt from the preceding story atom into the quiz user prompt', async () => {
    const atoms = [makeStoryAtom(), makeQuizAtom()];
    queueResponse(VALID_STORY_PROSE);
    queueResponse(VALID_QUIZ_JSON);

    await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    // Second call is the quiz; its user turn should reference the story.
    const quizCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const quizUser = quizCall.messages.find((m) => m.role === 'user')!;
    // The story prose begins with "Once upon a time, an apple" — that
    // phrase should surface inside the quiz-maker user prompt.
    expect(quizUser.content).toMatch(/Once upon a time, an apple/);
  });

  // -------------------------------------------------------------------------
  // Mixed path — a `concept` atom skips, legacy runs once and fills the gap
  // -------------------------------------------------------------------------

  it('invokes legacy exactly once when any atom skips, and cherry-picks legacy cards at skipped indices', async () => {
    const atoms = [
      makeStoryAtom({ id: 'atom-s' }),
      makeConceptAtom({ id: 'atom-c' }), // will skip — no mapping
      makeQuizAtom({ id: 'atom-q' }),
    ];

    // Skill-engine queue: story + quiz only (concept is skipped before
    // any LLM call is made, so it doesn't consume a response).
    queueResponse(VALID_STORY_PROSE); // story-writer call
    queueResponse(VALID_QUIZ_JSON); // quiz-maker call
    // Legacy fallback call (after skill engine finishes with skips).
    queueResponse(legacyThreeCardArray());

    const result = await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    // 3 cards — positional.
    expect(result.cards).toHaveLength(3);
    expect(result.cards[0].sortOrder).toBe(0);
    expect(result.cards[1].sortOrder).toBe(1);
    expect(result.cards[2].sortOrder).toBe(2);

    // Position 0: skill-produced story. `content.title` comes from the
    // atom's `name` field in buildCardFromSkillOutput.
    expect(result.cards[0].type).toBe('story');
    expect(result.cards[0].content.title).toBe('things fall down');
    expect(result.cards[0].content.text).not.toMatch(/LEGACY/);

    // Position 1: legacy-produced concept (index 1 in the legacy array).
    expect(result.cards[1].type).toBe('concept');
    expect(result.cards[1].content.text).toMatch(/LEGACY/);

    // Position 2: skill-produced quiz.
    expect(result.cards[2].type).toBe('quiz');
    expect(result.cards[2].content.text).toBe(
      'What pulls the apple toward the ground?'
    );
    expect(result.cards[2].content.text).not.toMatch(/LEGACY/);

    // Skip marker surfaced for Dev Console.
    expect(result.skipped).toHaveLength(1);
    expect(result.skipped[0]).toEqual({
      atomId: 'atom-c',
      reason: 'no-skill-mapping',
    });
    expect(result.usedLegacyFallback).toBe(true);

    // 3 LLM calls total: 2 skill + 1 legacy.
    expect(mockRouteRequest).toHaveBeenCalledTimes(3);
  });

  it('includes a trace for every atom in the decomposition, success or skip', async () => {
    const atoms = [makeStoryAtom(), makeConceptAtom(), makeQuizAtom()];
    queueResponse(VALID_STORY_PROSE);
    queueResponse(VALID_QUIZ_JSON);
    queueResponse(legacyThreeCardArray());

    const result = await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    expect(result.traces).toHaveLength(3);
    expect(result.traces.map((t) => t.atomId)).toEqual([
      'atom-story',
      'atom-concept',
      'atom-quiz',
    ]);
    // Skipped atom surfaces its reason + skipped status.
    const conceptTrace = result.traces[1];
    expect(conceptTrace.validatorStatus).toBe('skipped');
    expect(conceptTrace.skillName).toBeNull();
    expect(conceptTrace.skipReason).toBe('no-skill-mapping');
    // Story + quiz come through green.
    expect(result.traces[0].validatorStatus).toBe('ok');
    expect(result.traces[0].skillName).toBe('story-writer');
    expect(result.traces[2].validatorStatus).toBe('ok');
    expect(result.traces[2].skillName).toBe('quiz-maker');
  });

  // -------------------------------------------------------------------------
  // Legacy fallback itself fails — partial delivery path
  // -------------------------------------------------------------------------

  it('ships the partial skill-engine output when the legacy fallback throws', async () => {
    const atoms = [
      makeStoryAtom({ id: 'a-s' }),
      makeConceptAtom({ id: 'a-c' }), // skip
    ];
    queueResponse(VALID_STORY_PROSE);
    // Legacy call blows up — the adapter should swallow and proceed.
    queueError(new Error('legacy went boom'));

    const result = await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    // Only the story survived — the concept slot is left empty rather
    // than blocking the whole run.
    expect(result.cards).toHaveLength(1);
    expect(result.cards[0].type).toBe('story');
    expect(result.cards[0].sortOrder).toBe(0);

    // Skipped list still reflects the concept atom.
    expect(result.skipped).toHaveLength(1);
    expect(result.skipped[0].reason).toBe('no-skill-mapping');

    // The adapter attempted the legacy call but it failed — we report
    // legacy "not used" because no legacy cards made it into the output.
    expect(result.usedLegacyFallback).toBe(false);

    // 2 LLM calls: story (OK) + legacy (threw).
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  // -------------------------------------------------------------------------
  // Retry accounting still works through the adapter
  // -------------------------------------------------------------------------

  it('surfaces skillRouter retry-ok traces unchanged through the adapter', async () => {
    const atoms = [makeQuizAtom()];
    // First quiz attempt malformed (options too short) → Zod reject.
    queueResponse(
      JSON.stringify({
        question: 'Bad first try?',
        options: ['A', 'B'],
        correctIndex: 0,
        explanation: 'nope',
        rationalePerOption: ['a', 'b'],
      })
    );
    // Retry succeeds.
    queueResponse(VALID_QUIZ_JSON);

    const result = await generateCardsWithSkills(
      'u-int',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    expect(result.cards).toHaveLength(1);
    expect(result.traces[0].validatorStatus).toBe('retry-ok');
    expect(result.traces[0].retryCount).toBe(1);
    expect(result.usedLegacyFallback).toBe(false);
    // 2 calls: first attempt + retry. No legacy.
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });
});

// ---------------------------------------------------------------------------
// Suite — isSkillEngineStage4Enabled flag
// ---------------------------------------------------------------------------

describe('isSkillEngineStage4Enabled — feature flag', () => {
  // Save and restore the env var so tests don't leak between runs.
  const savedEnv = process.env.SKILL_ENGINE_STAGE4;

  afterEach(() => {
    if (savedEnv === undefined) {
      delete process.env.SKILL_ENGINE_STAGE4;
    } else {
      process.env.SKILL_ENGINE_STAGE4 = savedEnv;
    }
  });

  it('defaults to ENABLED when env var is unset', () => {
    delete process.env.SKILL_ENGINE_STAGE4;
    expect(isSkillEngineStage4Enabled()).toBe(true);
  });

  it('is ENABLED for "true"', () => {
    process.env.SKILL_ENGINE_STAGE4 = 'true';
    expect(isSkillEngineStage4Enabled()).toBe(true);
  });

  it('is ENABLED for "1"', () => {
    process.env.SKILL_ENGINE_STAGE4 = '1';
    expect(isSkillEngineStage4Enabled()).toBe(true);
  });

  it('is ENABLED for "on"', () => {
    process.env.SKILL_ENGINE_STAGE4 = 'on';
    expect(isSkillEngineStage4Enabled()).toBe(true);
  });

  it('is DISABLED for "false" (case-insensitive)', () => {
    process.env.SKILL_ENGINE_STAGE4 = 'false';
    expect(isSkillEngineStage4Enabled()).toBe(false);
    process.env.SKILL_ENGINE_STAGE4 = 'FALSE';
    expect(isSkillEngineStage4Enabled()).toBe(false);
    process.env.SKILL_ENGINE_STAGE4 = 'False';
    expect(isSkillEngineStage4Enabled()).toBe(false);
  });

  it('is DISABLED for "0"', () => {
    process.env.SKILL_ENGINE_STAGE4 = '0';
    expect(isSkillEngineStage4Enabled()).toBe(false);
  });

  it('is DISABLED for "off" (case-insensitive)', () => {
    process.env.SKILL_ENGINE_STAGE4 = 'off';
    expect(isSkillEngineStage4Enabled()).toBe(false);
    process.env.SKILL_ENGINE_STAGE4 = 'OFF';
    expect(isSkillEngineStage4Enabled()).toBe(false);
  });

  it('is DISABLED for empty string (explicit disable)', () => {
    process.env.SKILL_ENGINE_STAGE4 = '';
    expect(isSkillEngineStage4Enabled()).toBe(false);
  });

  it('trims whitespace before evaluating', () => {
    process.env.SKILL_ENGINE_STAGE4 = '  false  ';
    expect(isSkillEngineStage4Enabled()).toBe(false);
    process.env.SKILL_ENGINE_STAGE4 = '  true  ';
    expect(isSkillEngineStage4Enabled()).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Silence the noisy console.warn from legacy-fallback-failed branch. Tests
// that specifically want to assert on it can still spy manually.
// ---------------------------------------------------------------------------

vi.spyOn(console, 'warn').mockImplementation(() => void 0);
// Keep a reference so lints don't flag an unused import. (Also a tidy
// place to hang future span assertions.)
export const __touch: GeneratedCard | null = null;
