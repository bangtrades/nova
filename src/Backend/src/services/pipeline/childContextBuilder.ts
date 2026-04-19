/**
 * ChildContextBuilder — Sprint 10 · S10-12
 *
 * Single-entry assembler that turns a `childId` into the
 * `ChildContext` every S10-era skill consumes. Lives in the pipeline
 * layer (not in skills/) because the pipeline is the only place that
 * owns the DB-side signal fetches; skills stay pure.
 *
 * Responsibilities:
 *   1. Verify ownership (caller's userId must match ChildProfile.userId).
 *   2. Fetch guidance + sessionContext if the orchestrator didn't
 *      already. (S9/S10-04/05 already fetch these once at pipeline
 *      entry — pass them in to avoid a duplicate DB round trip.)
 *   3. Fetch engagement + mastery in parallel. Both are optional — a
 *      cold-start child with zero history still gets a valid context.
 *   4. Compute progressionDelta + effectiveAge.
 *   5. Infer LearningModality from engagement.
 *   6. Assemble `teachingStrategy` for a *default* conceptType
 *      ("abstract"); the per-atom router then calls
 *      `withConceptType()` to rebuild `rankedCardTypes` for each atom's
 *      actual conceptType without re-fetching anything.
 *
 * This module is effectively pure downstream of DB reads — it never
 * calls the LLM, never writes, never mutates. Safe to unit-test with a
 * mocked Prisma client.
 */
import { getPrismaClient } from '@db/client';
import {
  getGuidanceOrDefault,
  defaultGuidance,
  type ParentGuidanceView,
} from '@services/guidance/parentGuidance';
import {
  buildSessionContext,
  type SessionContext,
} from '@services/context/sessionContext';
import {
  getEngagementProfile,
  type EngagementProfileView,
  type RankedCardType,
} from '@services/engagement/engagementProfiler';
import {
  getChildMastery,
  type MasteryRow,
} from '@services/mastery/masteryTracker';
import {
  computeEffectiveAge,
  computeProgressionBreakdown,
  type ProgressionBreakdown,
} from '@services/skills/progression';
import {
  inferModality,
  rankCardTypesFor,
  type ConceptType,
  type LearningModality,
} from '@services/skills/teachingStrategy';
import type {
  ChildContext,
  EngagementSummary,
  MasteryEffective,
  SessionEventCounts,
} from '@services/skills/types';
import { errMsg } from './pipelineUtils';

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/**
 * Inputs to `buildChildContext`. Keep loose on purpose so the
 * orchestrator can pass its already-fetched guidance/sessionContext
 * without forcing a second DB hit. Any `undefined` field triggers a
 * fresh fetch; `null` explicitly skips (e.g. "we tried and it failed,
 * use the zero-state defaults").
 */
export interface BuildChildContextInputs {
  userId: string;
  childId: string;
  /** Pre-fetched guidance (from pipelineOrchestrator) — `null` = skipped, `undefined` = fetch now. */
  guidance?: ParentGuidanceView | null;
  /** Pre-fetched session context — same semantics as `guidance`. */
  sessionContext?: SessionContext | null;
  /** Default conceptType if no atom-specific override. Defaults to 'abstract'. */
  defaultConceptType?: ConceptType;
  /** If true, the builder throws on ownership mismatch instead of returning a zero-state. */
  strict?: boolean;
  /** Override clock for deterministic tests. */
  now?: Date;
}

/**
 * What the builder returns. `ctx` is ready to pass to a skill's
 * `buildPrompt`; `breakdown` is emitted for Dev Console traces; the
 * flags let the caller decide whether to fall back to the legacy
 * generator (e.g. ownership mismatch).
 */
export interface BuildChildContextResult {
  ctx: ChildContext;
  progressionBreakdown: ProgressionBreakdown;
  childOwned: boolean;
  /**
   * Reason the builder degraded to a zero-state context (if any).
   * "ok" means a fully-populated context was returned.
   */
  degradedReason: 'ok' | 'child-not-found' | 'child-not-owned' | 'db-error';
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Main entry point. Always returns a valid ChildContext — on any
 * non-critical failure it degrades to a zero-state context rather than
 * throwing, so the pipeline never dies here. Callers that *need* the
 * hard-fail behavior can pass `strict: true`.
 */
export async function buildChildContext(
  inputs: BuildChildContextInputs
): Promise<BuildChildContextResult> {
  const {
    userId,
    childId,
    defaultConceptType = 'abstract',
    strict = false,
    now = new Date(),
  } = inputs;

  // 1. Ownership check — the only hard-fail path.
  const prisma = getPrismaClient();
  let childRow: { id: string; userId: string; birthDate: Date | null } | null = null;
  try {
    childRow = (await prisma.childProfile.findUnique({
      where: { id: childId },
      select: { id: true, userId: true, birthDate: true },
    })) as { id: string; userId: string; birthDate: Date | null } | null;
  } catch (err) {
    if (strict) throw err;
    console.warn(`[childContextBuilder] childProfile lookup failed: ${errMsg(err)}`);
    return zeroStateResult(childId, defaultConceptType, 'db-error');
  }

  if (!childRow) {
    if (strict) {
      const e = new Error(`Child profile ${childId} not found`) as Error & {
        statusCode?: number;
      };
      e.statusCode = 404;
      throw e;
    }
    return zeroStateResult(childId, defaultConceptType, 'child-not-found');
  }
  if (childRow.userId !== userId) {
    if (strict) {
      const e = new Error(
        `Child profile ${childId} is not owned by the caller`
      ) as Error & { statusCode?: number };
      e.statusCode = 403;
      throw e;
    }
    return zeroStateResult(childId, defaultConceptType, 'child-not-owned');
  }

  // 2. Guidance + session context — prefer pre-fetched from orchestrator.
  // `undefined` ⇒ we need to fetch. `null` ⇒ caller explicitly skipped
  // (e.g. they tried and failed), so use defaults.
  const guidance =
    inputs.guidance === undefined
      ? await safeGetGuidance(childId)
      : inputs.guidance ?? defaultGuidance(childId);

  const sessionContext =
    inputs.sessionContext === undefined
      ? await safeGetSessionContext(childId, now)
      : inputs.sessionContext ?? defaultSessionContext(now);

  // 3. Engagement + mastery in parallel. Both optional — a cold-start
  // child returns null from each and the context degrades gracefully.
  const [engagementRow, masteryRows] = await Promise.all([
    safeGetEngagement(childId),
    safeGetMastery(childId, now),
  ]);

  // 4. Derive summary shapes.
  const engagement = engagementRow ? summarizeEngagement(engagementRow) : undefined;
  const mastery = masteryRows.length > 0 ? summarizeMastery(masteryRows) : undefined;
  const recentSessionEvents = engagementRow
    ? summarizeRecentEvents(engagementRow)
    : undefined;

  // 5. Ageify — birthDate → years, clamped. Fall back to 6 if missing.
  const ageYears = birthDateToAge(childRow.birthDate, now) ?? 6;

  // 6. Progression. `difficultyOffset` comes from guidance (already clamped).
  const difficultyOffset = guidance.difficultyOffset ?? 0;
  const progressionBreakdown = computeProgressionBreakdown({
    mastery,
    engagement,
    recentSessionEvents,
    parentDifficultyOffset: difficultyOffset,
  });
  const progressionDelta = progressionBreakdown.total;
  const effectiveAgeYears = computeEffectiveAge(ageYears, progressionDelta);

  // 7. Modality from engagement. Cold-start returns 'visual'.
  const modality: LearningModality = inferModality(
    engagementRow?.cardTypePreferences
  );

  // 8. Default teachingStrategy at the base conceptType. Per-atom
  // callers will use `withConceptType()` to rebuild rankedCardTypes.
  const rankedCardTypes = rankCardTypesFor(defaultConceptType, modality, {
    engagement: engagementRow?.cardTypePreferences ?? [],
    difficultyOffset,
    ageYears,
  });

  // 9. InterestTopics — for S10-12 we alias `topicFocus` until the
  // "extract interests from parentGoals free text" task lands. Keeps
  // the skill prompt slot non-empty whenever the parent has set
  // preferences.
  const interestTopics = guidance.topicFocus && guidance.topicFocus.length > 0
    ? [...guidance.topicFocus]
    : undefined;

  const ctx: ChildContext = {
    childId,
    ageYears,
    effectiveAgeYears,
    progressionDelta,
    parentGuidance: guidance,
    sessionContext,
    engagement,
    mastery,
    recentSessionEvents,
    interestTopics,
    teachingStrategy: {
      conceptType: defaultConceptType,
      modality,
      rankedCardTypes,
    },
    difficultyOffset,
  };

  return {
    ctx,
    progressionBreakdown,
    childOwned: true,
    degradedReason: 'ok',
  };
}

/**
 * Per-atom helper: return a new ChildContext with `teachingStrategy`
 * recomputed for the given conceptType. Cheap — it only re-runs the
 * pure ranker against the already-loaded engagement + difficulty +
 * age. No DB calls.
 */
export function withConceptType(
  base: ChildContext,
  conceptType: ConceptType
): ChildContext {
  if (conceptType === base.teachingStrategy.conceptType) return base;
  const rankedCardTypes = rankCardTypesFor(
    conceptType,
    base.teachingStrategy.modality,
    {
      engagement: base.engagement?.preferredCardTypes ?? [],
      difficultyOffset: base.difficultyOffset,
      ageYears: base.ageYears,
    }
  );
  return {
    ...base,
    teachingStrategy: {
      ...base.teachingStrategy,
      conceptType,
      rankedCardTypes,
    },
  };
}

// ---------------------------------------------------------------------------
// Safe DB helpers — every one swallows errors and returns a null-ish value,
// so a transient DB blip doesn't kill the pipeline. Errors are logged.
// ---------------------------------------------------------------------------

async function safeGetGuidance(
  childId: string
): Promise<ParentGuidanceView> {
  try {
    return await getGuidanceOrDefault(childId);
  } catch (err) {
    console.warn(
      `[childContextBuilder] getGuidanceOrDefault failed for ${childId}: ${errMsg(err)}`
    );
    return defaultGuidance(childId);
  }
}

async function safeGetSessionContext(
  childId: string,
  now: Date
): Promise<SessionContext> {
  try {
    return await buildSessionContext(childId, now);
  } catch (err) {
    console.warn(
      `[childContextBuilder] buildSessionContext failed for ${childId}: ${errMsg(err)}`
    );
    return defaultSessionContext(now);
  }
}

async function safeGetEngagement(
  childId: string
): Promise<EngagementProfileView | null> {
  try {
    return await getEngagementProfile(childId);
  } catch (err) {
    console.warn(
      `[childContextBuilder] getEngagementProfile failed for ${childId}: ${errMsg(err)}`
    );
    return null;
  }
}

async function safeGetMastery(
  childId: string,
  now: Date
): Promise<MasteryRow[]> {
  try {
    return await getChildMastery(childId, now);
  } catch (err) {
    console.warn(
      `[childContextBuilder] getChildMastery failed for ${childId}: ${errMsg(err)}`
    );
    return [];
  }
}

// ---------------------------------------------------------------------------
// Pure summarizers (exported for tests)
// ---------------------------------------------------------------------------

/**
 * Compress an EngagementProfileView into the narrow shape skills care
 * about. `recentQuizWinRate` is derived from the top-ranked quiz-like
 * card type if present; otherwise 0.
 */
export function summarizeEngagement(
  profile: EngagementProfileView
): EngagementSummary {
  // Quiz-like win rate: the completionRate of whichever engagement
  // slot matches a quiz-ish card. The field is already normalized to
  // 0..1 in S10-03, so no extra math.
  const quizRow = profile.cardTypePreferences.find(
    (r) => r.type === 'quiz'
  );
  const recentQuizWinRate = quizRow?.completionRate ?? 0;

  return {
    recentQuizWinRate,
    preferredCardTypes: profile.cardTypePreferences as RankedCardType[],
  };
}

/**
 * Fold all per-concept mastery rows into the single summary the
 * progression engine wants. Decayed confidence is used for
 * `averageScore` so a child who once mastered everything but hasn't
 * practiced in a month doesn't look like a genius.
 */
export function summarizeMastery(rows: MasteryRow[]): MasteryEffective {
  if (rows.length === 0) {
    return { averageScore: 0, totalAttempts: 0 };
  }
  let weightedSum = 0;
  let attempts = 0;
  for (const r of rows) {
    // Only rows the child has actually attempted contribute to the
    // average. Rows with 0 attempts are "introduced but untested" and
    // would bias the mean toward zero if we counted them.
    if (r.attempts > 0) {
      weightedSum += r.effectiveConfidence * r.attempts;
      attempts += r.attempts;
    }
  }
  const averageScore = attempts > 0 ? weightedSum / attempts : 0;
  return {
    averageScore: round(averageScore),
    totalAttempts: attempts,
  };
}

/**
 * Bridge the all-time event counters on `EngagementProfile` to the
 * "recent-window" shape the progression engine expects. Until S10-13
 * stands up a proper 7d rolling window, we clamp the all-time counts
 * so a long-tenured child with cumulative totals doesn't look like a
 * constant frustration event generator.
 */
export function summarizeRecentEvents(
  profile: EngagementProfileView
): SessionEventCounts {
  // Cap at small bounded values so the progression engine's own
  // thresholds (FLOW_EVENT_CAP=3, FRUSTRATION_EVENT_THRESHOLD=2) still
  // apply reasonably against all-time counts.
  return {
    flow: clamp(profile.flowEventCount, 0, 6),
    frustration: clamp(profile.frustrationEventCount, 0, 6),
    abandon: 0,
  };
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

function birthDateToAge(
  birthDate: Date | null | undefined,
  now: Date
): number | null {
  if (!birthDate) return null;
  const ms = now.getTime() - new Date(birthDate).getTime();
  if (!Number.isFinite(ms) || ms <= 0) return null;
  return Math.max(2, Math.floor(ms / (1000 * 60 * 60 * 24 * 365.25)));
}

function defaultSessionContext(now: Date): SessionContext {
  return {
    ianaTimezone: 'UTC',
    computedAt: now.toISOString(),
    localClock: '',
    localDayOfWeek: '',
    timeOfDay: 'morning',
    currentSessionMinutes: null,
    lessonsCompletedToday: 0,
    currentStreak: 0,
    recentQuizResults: [],
  };
}

function zeroStateResult(
  childId: string,
  conceptType: ConceptType,
  reason: BuildChildContextResult['degradedReason']
): BuildChildContextResult {
  const now = new Date();
  const ageYears = 6;
  const modality: LearningModality = 'visual';
  const rankedCardTypes = rankCardTypesFor(conceptType, modality, {
    engagement: [],
    difficultyOffset: 0,
    ageYears,
  });
  const ctx: ChildContext = {
    childId,
    ageYears,
    effectiveAgeYears: ageYears,
    progressionDelta: 0,
    parentGuidance: defaultGuidance(childId),
    sessionContext: defaultSessionContext(now),
    teachingStrategy: {
      conceptType,
      modality,
      rankedCardTypes,
    },
    difficultyOffset: 0,
  };
  return {
    ctx,
    progressionBreakdown: {
      total: 0,
      masteryContribution: 0,
      quizWinRateContribution: 0,
      flowContribution: 0,
      frustrationContribution: 0,
      parentOffsetContribution: 0,
    },
    childOwned: reason !== 'child-not-owned' && reason !== 'child-not-found',
    degradedReason: reason,
  };
}

function clamp(v: number, lo: number, hi: number): number {
  if (!Number.isFinite(v)) return lo;
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}

function round(v: number): number {
  return Math.round(v * 1000) / 1000;
}
