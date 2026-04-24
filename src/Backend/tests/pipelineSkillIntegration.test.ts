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
  // S12-10 update: `concept` is now mapped via CARD_TYPE_TO_SKILL to
  // story-writer, so to still exercise the "atom skips, legacy fills
  // the gap" test scenarios we use a synthetic cardType cast through
  // `as any`. The test intent — force a skip + prove the legacy
  // fallback fires on that index — is preserved regardless of which
  // specific cardType triggers the skip.
  return {
    id: 'atom-concept',
    name: 'force as a vector',
    description: 'gravity pulls straight down',
    teachingStrategy: 'explanation',
    recommendedCardType: 'unmapped-future-type' as unknown as 'concept',
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
// Suite — S12-16 cross-skill cardType coverage regression
//
// The S12-10 mid-sprint debug surfaced a structural gap: `curriculum-architect`
// emits atoms with cardTypes drawn from {story, concept, experiment, quiz,
// voice} but `CARD_TYPE_TO_SKILL` was missing the `concept` entry. Every
// concept atom silently returned `skipped: no-skill-mapping` for an entire
// sprint of testing because no integration test ran a full mixed-cardType
// decomposition through per-atom dispatch. The two tests below close that
// gap on both ends:
//
//   1. The `meta` test iterates `CARD_TYPES` and asserts every entry has a
//      mapping in `CARD_TYPE_TO_SKILL` — catches a missing-mapping at the
//      structural level (will fail the moment someone adds a cardType to
//      the schema without wiring its routing).
//   2. The `integration` test builds a 5-atom decomposition with one of
//      each cardType and runs it through `generateCardsWithSkills` with
//      mocked LLM responses. Asserts: zero skipped atoms, zero legacy
//      fallback invocations, every emitted card has its canonical iOS-
//      facing field populated. Catches routing regressions at the
//      end-to-end fan-out level (in case dispatch logic breaks even when
//      the map is complete).
// ---------------------------------------------------------------------------

import { CARD_TYPES, CARD_TYPE_TO_SKILL } from '@services/skills/types';

// Helpers for the three cardTypes the existing fixture set didn't cover.
// `makeConceptAtom` above uses a synthetic `as unknown as 'concept'` cast
// to force a skip — this one uses the real `'concept'` cardType so the
// CARD_TYPE_TO_SKILL.concept → story-writer routing is exercised.
function makeMappedConceptAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-concept-mapped',
    name: 'gravity is invisible',
    description: 'a property of mass-mass interaction children can name',
    teachingStrategy: 'explanation',
    recommendedCardType: 'concept',
    engagementScore: 0.5,
    learningValue: 0.85,
    prerequisites: [],
    ...overrides,
  };
}

function makeExperimentAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-experiment',
    name: 'sort objects by floats vs sinks',
    description: 'apply density intuition to a tactile drag-and-drop',
    teachingStrategy: 'application',
    recommendedCardType: 'experiment',
    engagementScore: 0.85,
    learningValue: 0.8,
    prerequisites: [],
    ...overrides,
  };
}

function makeVoiceAtom(overrides: Partial<ConceptAtom> = {}): ConceptAtom {
  return {
    id: 'atom-voice',
    name: 'name the milk-feeder category',
    description: 'spoken-answer recall of a single vocabulary word',
    teachingStrategy: 'reflection',
    recommendedCardType: 'voice',
    engagementScore: 0.75,
    learningValue: 0.9,
    prerequisites: [],
    ...overrides,
  };
}

// Valid skill outputs mirror what the per-skill router tests
// (experimentDesignerRouter / voicePersonaRouter) queue for their happy
// paths — the canonical "well-formed LLM response" shapes for each
// skill. Lifted as inline fixtures here rather than imported from those
// test files because vitest module-graph doesn't share helpers across
// test files cleanly.
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

// Concept atoms route through story-writer per CARD_TYPE_TO_SKILL.concept
// — the skill produces prose, and `buildCardFromSkillOutput` branches on
// `atom.recommendedCardType === 'concept'` to emit `type: 'concept'`
// with the prose in `content.explanation`. So the "concept output" mock
// is just well-formed prose, same shape as VALID_STORY_PROSE.
const VALID_CONCEPT_PROSE =
  'Gravity is the invisible pull between things that have weight. The Earth ' +
  'has so much weight that everything around it gets pulled toward its center, ' +
  'which is why dropped objects always fall down rather than up or sideways.';

describe('cross-skill cardType coverage (S12-16)', () => {
  beforeAll(async () => {
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  // -------------------------------------------------------------------------
  // Meta — every cardType in the schema has a routing entry
  // -------------------------------------------------------------------------

  it('every CardType in CARD_TYPES has a non-empty mapping in CARD_TYPE_TO_SKILL', () => {
    // Catches the S12-10 concept-skip class of bug at the structural
    // level: if someone adds a new cardType to the schema without
    // wiring its routing, this fails before any iPad ever sees the
    // bug.
    for (const cardType of CARD_TYPES) {
      const skillName = CARD_TYPE_TO_SKILL[cardType];
      expect(skillName, `CARD_TYPE_TO_SKILL is missing entry for "${cardType}"`).toBeDefined();
      expect(typeof skillName).toBe('string');
      expect(skillName!.length).toBeGreaterThan(0);
    }
  });

  it('CARD_TYPE_TO_SKILL has no orphan keys outside the CARD_TYPES enum', () => {
    // Inverse of the previous test — catches the case where a cardType
    // was renamed in CARD_TYPES but a stale entry survives in the map.
    const knownTypes = new Set<string>(CARD_TYPES);
    for (const key of Object.keys(CARD_TYPE_TO_SKILL)) {
      expect(knownTypes.has(key), `CARD_TYPE_TO_SKILL has orphan key "${key}" not in CARD_TYPES`).toBe(true);
    }
  });

  // -------------------------------------------------------------------------
  // Integration — all 5 cardTypes route through routeAllAtoms cleanly
  // -------------------------------------------------------------------------

  it('routes a 5-atom decomposition (one per cardType) through generateCardsWithSkills with zero skips and no legacy fallback', async () => {
    // One atom of each cardType, in the natural opener→middle→closer
    // order a real curriculum-architect output might emit.
    const atoms = [
      makeStoryAtom({ id: 'atom-1-story' }),
      makeMappedConceptAtom({ id: 'atom-2-concept' }),
      makeExperimentAtom({ id: 'atom-3-experiment' }),
      makeQuizAtom({ id: 'atom-4-quiz' }),
      makeVoiceAtom({ id: 'atom-5-voice' }),
    ];

    // Queue valid LLM responses in atom order. story + concept both
    // route through story-writer and consume prose; experiment + quiz
    // + voice consume their respective JSON fixtures.
    queueResponse(VALID_STORY_PROSE);
    queueResponse(VALID_CONCEPT_PROSE);
    queueResponse(VALID_EXPERIMENT_JSON);
    queueResponse(VALID_QUIZ_JSON);
    queueResponse(VALID_VOICE_JSON);

    const result = await generateCardsWithSkills(
      'u-cross',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    // Top-level invariants — zero skips, no legacy round-trip, one card
    // per atom in atom-order.
    expect(
      result.skipped,
      `expected zero skipped atoms but got: ${JSON.stringify(result.skipped)}`
    ).toEqual([]);
    expect(result.usedLegacyFallback).toBe(false);
    expect(result.cards).toHaveLength(5);
    expect(mockRouteRequest).toHaveBeenCalledTimes(5);

    // Every trace recorded `validatorStatus: 'ok'` — no Zod retry fired
    // anywhere along the chain.
    for (const trace of result.traces) {
      expect(trace.validatorStatus, `trace validator status for ${trace.atomId}`).toBe('ok');
    }

    // Per-card type assertions — each card matches its atom's
    // recommendedCardType AND carries the canonical iOS-facing content
    // field for that type. This is the field-name-drift gate that
    // S12-10 patched in cardGenerator.normalizeCard's double-write:
    // if the iOS-facing field disappears for any cardType, this fails.
    expect(result.cards[0].type).toBe('story');
    expect((result.cards[0].content as { narrativeText?: string }).narrativeText).toBeTruthy();

    expect(result.cards[1].type).toBe('concept');
    expect((result.cards[1].content as { explanation?: string }).explanation).toBeTruthy();

    expect(result.cards[2].type).toBe('experiment');
    expect(
      (result.cards[2].content as { dragItems?: unknown[] }).dragItems
    ).toBeTruthy();

    expect(result.cards[3].type).toBe('quiz');
    expect(
      (result.cards[3].content as { options?: unknown[] }).options
    ).toBeTruthy();

    expect(result.cards[4].type).toBe('voice');
    expect((result.cards[4].content as { promptText?: string }).promptText).toBeTruthy();
  });

  it('produces a per-atom AtomTrace with the correct skill name for every cardType', async () => {
    // Pipeline-tab observability check — the Dev Console renders one
    // row per atom keyed on (skill, validatorStatus). If any cardType's
    // trace surfaces empty/null skill name (which is what `skipped`
    // legacy-fallback rows show), the Pipeline tab can't distinguish
    // "skill ran successfully" from "atom fell through to legacy" and
    // the regression-test sweep this test exists to satisfy is broken.
    const atoms = [
      makeStoryAtom({ id: 't-story' }),
      makeMappedConceptAtom({ id: 't-concept' }),
      makeExperimentAtom({ id: 't-experiment' }),
      makeQuizAtom({ id: 't-quiz' }),
      makeVoiceAtom({ id: 't-voice' }),
    ];
    queueResponse(VALID_STORY_PROSE);
    queueResponse(VALID_CONCEPT_PROSE);
    queueResponse(VALID_EXPERIMENT_JSON);
    queueResponse(VALID_QUIZ_JSON);
    queueResponse(VALID_VOICE_JSON);

    const result = await generateCardsWithSkills(
      'u-cross',
      makeAnalysis(),
      makeScraped(),
      makeDecomposition(atoms),
      makeCtx()
    );

    expect(result.traces).toHaveLength(5);
    const expected: Array<[string, string]> = [
      ['t-story', 'story-writer'],
      ['t-concept', 'story-writer'], // shares story-writer per CARD_TYPE_TO_SKILL.concept
      ['t-experiment', 'experiment-designer'],
      ['t-quiz', 'quiz-maker'],
      ['t-voice', 'voice-persona'],
    ];
    for (let i = 0; i < expected.length; i++) {
      const [atomId, skillName] = expected[i];
      expect(result.traces[i].atomId, `trace[${i}] atomId`).toBe(atomId);
      expect(result.traces[i].skillName, `trace[${i}] skill name`).toBe(skillName);
      expect(result.traces[i].validatorStatus).toBe('ok');
    }
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
