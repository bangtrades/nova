/**
 * S12-05 · R5 — decompositionRouter dispatch tests (Stage 3).
 *
 * Parallel suite to `experimentDesignerRouter.test.ts`, but for the
 * Stage-3 single-call shape rather than the Stage-4 per-atom fanout.
 * Where skillRouter fans out N calls (one per atom), decompositionRouter
 * makes exactly one curriculum-architect call and returns either:
 *
 *   - `{ kind: 'ok', decomposition, trace }` on validation success, OR
 *   - `{ kind: 'failed', reason, trace }` on any non-transient failure
 *     (the orchestrator then falls back to the legacy heuristic
 *     `decomposeConcepts()` path).
 *
 * What this suite proves end-to-end:
 *
 *   1. routeDecomposition resolves the `curriculum-architect` skill from
 *      the real loaded registry, renders its prompt via buildPrompt, and
 *      invokes routeRequest with the right routing reason
 *      (`concept_decomposition`) + model (`claude-sonnet`).
 *   2. First-attempt happy path → validatorStatus 'ok', retryCount 0,
 *      atomCount reflected in trace, decomposition round-trips through
 *      normalizeDecomposition.
 *   3. Retry-on-Zod pattern (inherited from S10-12-R3) — first attempt
 *      trips a superRefine rule, retry user-turn carries the validator
 *      feedback, retry succeeds → validatorStatus 'retry-ok', retryCount 1,
 *      retry temperature is reduced by 0.1 from the prompt-meta hint.
 *   4. Retry-failed — both attempts fail Zod → kind 'failed', reason
 *      'validation-failed', validatorStatus 'retry-failed'.
 *   5. skill-not-loaded — empty registry short-circuits before any LLM
 *      call; mockRouteRequest never invoked.
 *   6. missing-required-input — analysis lacking topic or summary
 *      short-circuits before any LLM call.
 *   7. Transient LLM errors (timeout / 429 / 5xx) RE-THROW so the outer
 *      runStage can retry. This is the critical contract with the
 *      orchestrator — a true outage must not be silently swallowed into
 *      'failed' and force a legacy fallback.
 *   8. Non-transient LLM errors surface as reason 'llm-error' and let
 *      the orchestrator pick up the legacy path.
 *   9. JSON-parse-error + empty-response branches both land in the
 *      retry machinery (parse errors) or fail fast (empty response).
 *  10. Feature flag matrix — isSkillEngineStage3Enabled() defaults ON;
 *      any of "false"/"0"/"off"/""/"FALSE" disables; anything else is ON.
 */
import { describe, it, expect, beforeAll, vi, beforeEach, afterEach } from 'vitest';
import {
  routeDecomposition,
  isSkillEngineStage3Enabled,
  DECOMPOSITION_SKILL,
} from '@services/pipeline/decompositionRouter';
import { __resetSkillRegistryForTests } from '@services/skills/registry';
import { resolveDefsDir } from '@services/skills/loader';
import type { ChildContext, Skill } from '@services/skills/types';
import type { ContentAnalysis } from '@services/pipeline/contentAnalyzer';
import type { ScrapedContent } from '@services/pipeline/scraper';
import type { LLMResponse } from '@services/llm/types';

// ---------------------------------------------------------------------------
// Mock the LLM provider router so no real network calls fire. Every
// routeRequest call pops from a pre-queued response list; an empty queue
// throws so over-calls are loud.
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
      completionTokens: 420,
      totalTokens: 600,
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
    childId: 'child-arch',
    ageYears: 6,
    effectiveAgeYears: 6,
    progressionDelta: 0,
    parentGuidance: {
      childId: 'child-arch',
      topicFocus: [],
      topicAvoid: [],
      difficultyOffset: 0,
      contentBoundaries: {},
      dailySessionLimitMinutes: null,
      singleSessionLimitMinutes: null,
      updatedByUserId: 'user-arch',
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
      // curriculum-architect is concept-type-agnostic upstream — the
      // lesson spans all concept types — but ChildContext still requires
      // one. Pick 'fact' as a neutral default; the skill routes purely on
      // topic + summary.
      conceptType: 'fact',
      modality: 'visual',
      rankedCardTypes: [],
    },
    difficultyOffset: 0,
    ...overrides,
  };
}

function makeAnalysis(overrides: Partial<ContentAnalysis> = {}): ContentAnalysis {
  return {
    topic: 'How cats see in the dark',
    keyConcepts: ['pupil', 'rods', 'tapetum lucidum'],
    suggestedStage: 2,
    ageAppropriate: true,
    safetyFlags: [],
    suggestedCardCount: 3,
    summary:
      'Cat eyes have big pupils, extra rods, and a mirror layer that reflects light back — that is why they can hunt at dusk.',
    ...overrides,
  };
}

function makeScraped(overrides: Partial<ScrapedContent> = {}): ScrapedContent {
  return {
    url: 'https://example.test/cat-eyes',
    title: 'Why Cats See So Well at Night',
    content:
      'A cat hunting at dusk uses eyes tuned for low light. Its pupils open wide, its retina is packed with rods, and a reflective layer behind the retina bounces light back for a second pass — the tapetum lucidum, the reason cat eyes glow in a flashlight beam.',
    excerpt: 'A cat hunting at dusk uses eyes tuned for low light.',
    siteName: 'example.test',
    byline: 'Test Author',
    length: 280,
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Valid decompositions the LLM "returns" — any of these passes the
// curriculumArchitectOutputSchema on the first parse.
// ---------------------------------------------------------------------------

const VALID_EASY_JSON = JSON.stringify({
  atoms: [
    {
      id: 'atom-1',
      name: 'Cats hunt at dusk',
      description:
        'A scene — a cat stalking through tall grass in fading light. Pulls the child into the setting where cat eyes shine.',
      teachingStrategy: 'narrative',
      recommendedCardType: 'story',
      engagementScore: 0.8,
      learningValue: 0.35,
      prerequisites: [],
    },
    {
      id: 'atom-2',
      name: 'Big pupils let in more light',
      description:
        'Cats have pupils that can open very wide — that lets a lot of light in so they can still see when it is almost dark.',
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
      engagementScore: 0.55,
      learningValue: 0.85,
      prerequisites: ['atom-1'],
    },
    {
      id: 'atom-3',
      name: 'Why do cat eyes glow?',
      description:
        'Two pictures — a cat eye in daylight and in a flashlight. The child picks which one has the mirror layer showing.',
      teachingStrategy: 'quiz',
      recommendedCardType: 'quiz',
      engagementScore: 0.75,
      learningValue: 0.7,
      prerequisites: ['atom-2'],
    },
  ],
  rationale:
    'Start with the hunting scene so the child already cares about cat eyes. Teach one defining fact (big pupils) cleanly. Close with a check that pushes the mirror idea without drowning them in vocabulary.',
});

// ---------------------------------------------------------------------------
// Invalid decompositions the LLM "returns" — these should trip the
// superRefine rules and force the retry path.
// ---------------------------------------------------------------------------

// Breaks card-type diversity — all four atoms are 'concept' type.
const INVALID_DIVERSITY_JSON = JSON.stringify({
  atoms: [
    {
      id: 'atom-1',
      name: 'Cat eyes overview',
      description:
        'The parts that make cat eyes different — pupils, rods, and a reflective layer behind.',
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
      engagementScore: 0.6,
      learningValue: 0.75,
      prerequisites: [],
    },
    {
      id: 'atom-2',
      name: 'Pupil size',
      description:
        'Big pupils let more light in — useful at dusk, painful in sun, so cats squint to adjust.',
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
      engagementScore: 0.55,
      learningValue: 0.8,
      prerequisites: ['atom-1'],
    },
    {
      id: 'atom-3',
      name: 'Mirror layer',
      description:
        'Behind the retina sits a mirror-like layer that sends light back for a second pass — the reason cat eyes glow.',
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
      engagementScore: 0.6,
      learningValue: 0.85,
      prerequisites: ['atom-2'],
    },
    {
      id: 'atom-4',
      name: 'Why the glow?',
      description:
        'Two pictures — a cat eye in flashlight and a dog eye in flashlight. The child picks which one has the mirror.',
      teachingStrategy: 'quiz',
      recommendedCardType: 'concept', // WRONG — quiz strategy demands quiz card
      engagementScore: 0.7,
      learningValue: 0.75,
      prerequisites: ['atom-3'],
    },
  ],
  rationale:
    'Four concept atoms with a quiz-labeled tail masquerading as a concept card — rejected by the strategy↔cardType compat rule and by card-type diversity.',
});

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

describe('routeDecomposition — curriculum-architect dispatch', () => {
  beforeAll(async () => {
    // Boot the real skill registry once per suite. This loads the
    // curriculum-architect def bundle + its Zod validator from the
    // filesystem so we exercise the actual Handlebars render path — not
    // a stub.
    const reg = __resetSkillRegistryForTests(resolveDefsDir());
    await reg.load();
  });

  // ---- 1. Happy path ---------------------------------------------------

  it('returns kind=ok with validatorStatus=ok on first-attempt success', async () => {
    queueResponse(VALID_EASY_JSON);

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.skillName).toBe(DECOMPOSITION_SKILL);
      expect(result.trace.validatorStatus).toBe('ok');
      expect(result.trace.retryCount).toBe(0);
      expect(result.trace.atomCount).toBe(3);
      expect(result.trace.modality).toBe('visual');
      expect(result.trace.effectiveAgeYears).toBe(6);
      expect(result.trace.ageProfileUsed).toBeDefined();
      expect(result.trace.difficultyUsed).toBeDefined();
      expect(result.trace.tokens?.total).toBe(600);

      expect(result.decomposition.atoms).toHaveLength(3);
      expect(result.decomposition.atoms[0]!.id).toBe('atom-1');
      expect(result.decomposition.atoms[0]!.teachingStrategy).toBe('narrative');
      expect(result.decomposition.atoms[2]!.recommendedCardType).toBe('quiz');
      expect(result.decomposition.rationale).toMatch(/hunting/);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });

  it('calls routeRequest with the concept_decomposition routing reason and claude-sonnet', async () => {
    queueResponse(VALID_EASY_JSON);

    await routeDecomposition({
      userId: 'user-42',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    const [userIdArg, requestArg, routingReasonArg] = mockRouteRequest.mock.calls[0]!;
    expect(userIdArg).toBe('user-42');
    expect((requestArg as { model: string }).model).toBe('claude-sonnet');
    expect((requestArg as { maxTokens: number }).maxTokens).toBe(1400);
    expect(routingReasonArg).toBe('concept_decomposition');
  });

  it('threads topic, summary, keyConcepts, and source excerpt into the rendered user prompt', async () => {
    queueResponse(VALID_EASY_JSON);

    await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis({ topic: 'How cats see in the dark' }),
      scraped: makeScraped({ title: 'Why Cats See So Well at Night' }),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    // Topic + title should both appear; the sourceExcerpt is prefixed
    // with `Title: <scraped.title>` in the router.
    expect(userTurn.content).toMatch(/How cats see in the dark/);
    expect(userTurn.content).toMatch(/Why Cats See So Well at Night/);
    // Key concepts flow through — at least one of them should survive
    // the Handlebars render.
    expect(userTurn.content.toLowerCase()).toMatch(/pupil|rods|tapetum/);
  });

  it('renders parent topicAvoid boundaries into the system prompt', async () => {
    queueResponse(VALID_EASY_JSON);

    await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx({
        parentGuidance: {
          childId: 'child-arch',
          topicFocus: [],
          topicAvoid: ['predators', 'hunting'],
          difficultyOffset: 0,
          contentBoundaries: {},
          dailySessionLimitMinutes: null,
          singleSessionLimitMinutes: null,
          updatedByUserId: 'user-arch',
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      }),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const systemTurn = call.messages.find((m) => m.role === 'system')!;
    expect(systemTurn.content.toLowerCase()).toMatch(/predators/);
    expect(systemTurn.content.toLowerCase()).toMatch(/hunting/);
  });

  it('truncates an oversized source excerpt at ~2500 chars', async () => {
    queueResponse(VALID_EASY_JSON);

    const giant = 'word '.repeat(1000); // ~5000 chars
    await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped({ content: giant }),
    });

    const call = mockRouteRequest.mock.calls[0]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const userTurn = call.messages.find((m) => m.role === 'user')!;
    // The excerpt branch appends '…' when truncation fires. Don't assert
    // on exact length — the Handlebars template wraps it — but the
    // ellipsis only shows up when the source-excerpt truncation path ran.
    expect(userTurn.content).toContain('…');
  });

  // ---- 2. Retry-on-Zod ------------------------------------------------

  it('retries once on validator failure then succeeds → retry-ok', async () => {
    queueResponse(INVALID_DIVERSITY_JSON);
    queueResponse(VALID_EASY_JSON);

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
      // Combined tokens from both attempts.
      expect(result.trace.tokens?.total).toBe(1200);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);

    // The retry user turn should carry the pretty-printed Zod error —
    // the router appends a feedback block with "rejected by the output
    // validator" framing.
    const retryCall = mockRouteRequest.mock.calls[1]![1] as {
      messages: Array<{ role: string; content: string }>;
    };
    const retryUser = retryCall.messages.find((m) => m.role === 'user')!;
    expect(retryUser.content).toMatch(/rejected by the output validator/i);
    // At least one of the rule keywords should surface — diversity,
    // card type, or strategy — so the model knows what to fix.
    expect(retryUser.content.toLowerCase()).toMatch(
      /diversity|card type|strategy|incompatible/
    );
  });

  it('reduces temperature by 0.1 on the retry call', async () => {
    queueResponse(INVALID_DIVERSITY_JSON);
    queueResponse(VALID_EASY_JSON);

    await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    const firstTemp = (mockRouteRequest.mock.calls[0]![1] as { temperature: number })
      .temperature;
    const retryTemp = (mockRouteRequest.mock.calls[1]![1] as { temperature: number })
      .temperature;
    // S10-12-R3's pattern: second attempt drops temperature by 0.1 so
    // the model is less chaotic on the correction pass. Floor at 0.
    expect(retryTemp).toBeCloseTo(Math.max(0, firstTemp - 0.1), 6);
  });

  it('returns kind=failed with retry-failed when both attempts fail validation', async () => {
    queueResponse(INVALID_DIVERSITY_JSON);
    queueResponse(INVALID_DIVERSITY_JSON);

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('validation-failed');
      expect(result.trace.validatorStatus).toBe('retry-failed');
      expect(result.trace.retryCount).toBe(1);
      expect(result.trace.atomCount).toBe(0);
      expect(result.trace.error).toBeDefined();
      expect(result.trace.failureReason).toBe('validation-failed');
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  // ---- 3. JSON parse failures (also retry-eligible) --------------------

  it('retries on JSON-parse-error, succeeds on second attempt', async () => {
    // No JSON object at all — trips the `no JSON object found` branch,
    // which is in the retryable set.
    queueResponse('Sorry, I cannot respond in JSON right now.');
    queueResponse(VALID_EASY_JSON);

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('ok');
    if (result.kind === 'ok') {
      expect(result.trace.validatorStatus).toBe('retry-ok');
      expect(result.trace.retryCount).toBe(1);
    }
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  it('returns json-parse-error as the failure reason when both attempts cannot be parsed', async () => {
    queueResponse('not json at all');
    queueResponse('still not json');

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('json-parse-error');
      expect(result.trace.validatorStatus).toBe('retry-failed');
      expect(result.trace.retryCount).toBe(1);
    }
  });

  // ---- 4. Short-circuit failure modes ---------------------------------

  it('returns kind=failed reason=skill-not-loaded when the registry lacks curriculum-architect', async () => {
    const emptyRegistry = {
      has: (_name: string) => false,
      get: (name: string): Skill => {
        throw new Error(`skill "${name}" not found in test registry`);
      },
    };

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
      registry: emptyRegistry,
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('skill-not-loaded');
      expect(result.trace.validatorStatus).toBe('skipped');
      expect(result.trace.promptMeta).toBeNull();
      expect(result.trace.atomCount).toBe(0);
    }
    // Never calls the LLM when the skill is missing.
    expect(mockRouteRequest).not.toHaveBeenCalled();
  });

  it('returns kind=failed reason=missing-required-input when analysis.topic is empty', async () => {
    // The router guards `!analysis.topic || !analysis.summary` — an empty
    // string trips the same branch as a missing field. ContentAnalysis
    // comes from an LLM upstream, so the runtime check is the real
    // defence (the type system only protects the compile-time surface).
    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis({ topic: '' }),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('missing-required-input');
      expect(result.trace.validatorStatus).toBe('skipped');
    }
    expect(mockRouteRequest).not.toHaveBeenCalled();
  });

  it('returns kind=failed reason=missing-required-input when analysis.summary is empty', async () => {
    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis({ summary: '' }),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('missing-required-input');
    }
    expect(mockRouteRequest).not.toHaveBeenCalled();
  });

  // ---- 5. LLM-level errors --------------------------------------------

  it('re-throws transient LLM errors (timeout) so the outer runStage can retry', async () => {
    // This is the critical contract with the orchestrator — a true
    // outage must NOT collapse into reason 'llm-error' + legacy
    // fallback. The outer runStage's retry loop is the only layer with
    // jitter/backoff budget.
    queueError(new Error('fetch failed: request timed out after 45000ms'));

    await expect(
      routeDecomposition({
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
        scraped: makeScraped(),
      })
    ).rejects.toThrow(/timed out/i);
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });

  it('re-throws transient 429 rate-limit errors', async () => {
    queueError(new Error('Upstream responded 429 rate limit exceeded'));

    await expect(
      routeDecomposition({
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
        scraped: makeScraped(),
      })
    ).rejects.toThrow(/429|rate limit/i);
  });

  it('re-throws transient 503 upstream-unavailable errors', async () => {
    queueError(new Error('Provider returned 503 service unavailable'));

    await expect(
      routeDecomposition({
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
        scraped: makeScraped(),
      })
    ).rejects.toThrow(/503/);
  });

  it('captures non-transient LLM errors as reason=llm-error', async () => {
    // A hard logic error from the provider — not retryable under our
    // transient classifier. Should surface as a clean 'failed' so the
    // orchestrator falls back to the legacy path.
    queueError(new Error('Upstream responded 400: malformed request payload'));

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('llm-error');
      expect(result.trace.error).toMatch(/400/);
    }
  });

  it('re-throws a transient error that surfaces on the retry attempt as well', async () => {
    // First attempt fails validation (retry-eligible), retry attempt
    // then throws transiently — that SECOND transient should still
    // propagate out so the runStage wrapper can handle it.
    queueResponse(INVALID_DIVERSITY_JSON);
    queueError(new Error('fetch failed: ETIMEDOUT'));

    await expect(
      routeDecomposition({
        userId: 'u1',
        baseContext: makeCtx(),
        analysis: makeAnalysis(),
        scraped: makeScraped(),
      })
    ).rejects.toThrow(/ETIMEDOUT|timed out/i);
    expect(mockRouteRequest).toHaveBeenCalledTimes(2);
  });

  // ---- 6. Empty-response handling -------------------------------------

  it('returns reason=empty-response on a whitespace-only LLM reply', async () => {
    queueResponse('   \n\t  ');

    const result = await routeDecomposition({
      userId: 'u1',
      baseContext: makeCtx(),
      analysis: makeAnalysis(),
      scraped: makeScraped(),
    });

    expect(result.kind).toBe('failed');
    if (result.kind === 'failed') {
      expect(result.reason).toBe('empty-response');
    }
    // Empty-response is NOT in the retryable set — single shot only.
    expect(mockRouteRequest).toHaveBeenCalledTimes(1);
  });
});

// ---------------------------------------------------------------------------
// Feature flag — isSkillEngineStage3Enabled
// ---------------------------------------------------------------------------

describe('isSkillEngineStage3Enabled — feature flag matrix', () => {
  const originalEnv = process.env.SKILL_ENGINE_STAGE3;

  afterEach(() => {
    if (originalEnv === undefined) {
      delete process.env.SKILL_ENGINE_STAGE3;
    } else {
      process.env.SKILL_ENGINE_STAGE3 = originalEnv;
    }
  });

  it('defaults ON when the env var is unset', () => {
    delete process.env.SKILL_ENGINE_STAGE3;
    expect(isSkillEngineStage3Enabled()).toBe(true);
  });

  it('treats "true" as ON', () => {
    process.env.SKILL_ENGINE_STAGE3 = 'true';
    expect(isSkillEngineStage3Enabled()).toBe(true);
  });

  it('treats "1" / "on" / arbitrary truthy strings as ON', () => {
    process.env.SKILL_ENGINE_STAGE3 = '1';
    expect(isSkillEngineStage3Enabled()).toBe(true);
    process.env.SKILL_ENGINE_STAGE3 = 'on';
    expect(isSkillEngineStage3Enabled()).toBe(true);
    process.env.SKILL_ENGINE_STAGE3 = 'yes';
    expect(isSkillEngineStage3Enabled()).toBe(true);
  });

  it('treats "false" / "0" / "off" as OFF (case-insensitive)', () => {
    for (const raw of ['false', 'FALSE', 'False', '0', 'off', 'OFF']) {
      process.env.SKILL_ENGINE_STAGE3 = raw;
      expect(isSkillEngineStage3Enabled()).toBe(false);
    }
  });

  it('treats an empty string as OFF (ambiguous setting → safe default)', () => {
    // An operator who sets `SKILL_ENGINE_STAGE3=` (no value) likely
    // meant to disable. Better to be explicit and route to the legacy
    // heuristic than to silently default-on when the var is literally
    // present but empty.
    process.env.SKILL_ENGINE_STAGE3 = '';
    expect(isSkillEngineStage3Enabled()).toBe(false);
  });

  it('trims whitespace before classifying', () => {
    process.env.SKILL_ENGINE_STAGE3 = '  false  ';
    expect(isSkillEngineStage3Enabled()).toBe(false);
    process.env.SKILL_ENGINE_STAGE3 = '  true  ';
    expect(isSkillEngineStage3Enabled()).toBe(true);
  });
});
