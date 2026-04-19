/**
 * Engagement Profiler (Sprint 10 / S10-03 — "The Brain")
 *
 * Builds a per-child behavioral profile from the CardInteraction stream. The
 * profile answers five questions for the Grand Architect pipeline (S10-12):
 *
 *   1. How long are this child's sessions on average?
 *   2. Which card types does this child engage with most deeply?
 *   3. Which knowledge-graph domains (topics) does this child gravitate toward?
 *   4. How frequently does this child show frustration signals?
 *   5. How frequently does this child show flow signals?
 *
 * Signal rules (S10-03 DoD):
 *   - Frustration event: a wrong answer that is *the second (or later) wrong
 *     answer in a row on the same concept*, OR an interaction that completes
 *     in < 2000ms without success ("rapid-quit").
 *   - Flow event: a correct answer that *closes a run of 3+ consecutive correct
 *     answers* (streak transitions 2→3). Subsequent correct answers in the same
 *     run do NOT re-fire — one event per run, counted on the triggering answer.
 *
 * Storage policy (COPPA):
 *   - Raw counters (totalSessions, totalInteractions, totalDurationMs, event
 *     counts, streaks) are NOT child-identifying on their own. Stored in the
 *     clear so dashboards can read them cheaply.
 *   - Card-type preferences and topic affinities REVEAL what the child likes
 *     and struggles with. Persisted as AES-256-GCM ciphertext via the existing
 *     `services/oauth/tokenEncryption` helper.
 *
 * Pure / DB split:
 *   All reducers are pure and exported so tests can exercise the aggregation
 *   rules without a DB or encryption key. The DB-facing `ingestInteractions`
 *   wraps them with fetch → decrypt → reduce → encrypt → upsert.
 */

import { getPrismaClient } from '@db/client';
import { getConfig } from '@config';
import { encryptToken, decryptToken } from '@services/oauth/tokenEncryption';

// ============================================================
// Public types
// ============================================================

/** Canonical card types (mirrors src/services/pipeline/cardGenerator.ts CardType). */
export type CardTypeKey = 'story' | 'concept' | 'experiment' | 'quiz' | 'voice';
export const CARD_TYPE_KEYS: readonly CardTypeKey[] = [
  'story',
  'concept',
  'experiment',
  'quiz',
  'voice',
] as const;

/** Knowledge-graph domains (mirrors src/db/seedKnowledgeGraph.ts). */
export type DomainKey = 'computers' | 'robots' | 'ai';

export interface CardTypeStat {
  count: number;           // number of interactions on this card type
  totalDurationMs: number; // cumulative engagement time
  completionCount: number; // interactions with action === 'complete' OR correct quiz answers
}
export type CardTypeStats = Partial<Record<CardTypeKey, CardTypeStat>>;

export interface TopicAffinityStat {
  count: number;
  totalDurationMs: number;
}
export type TopicAffinities = Partial<Record<DomainKey, TopicAffinityStat>>;

/** One raw event flowing into the profiler, enriched with card lookup data. */
export interface InteractionEvent {
  cardId: string;
  cardType: CardTypeKey | string;         // string fallback for unknown types
  conceptId: string | null;
  domain: DomainKey | string | null;      // from Concept.domain, if card has a concept
  action: string;                         // 'answer' | 'view' | 'complete' | 'skip' | ...
  durationMs: number;
  isCorrect: boolean | null;              // present iff action === 'answer'
  timestamp?: Date;
}

/** The per-batch deltas returned from ingestion — exposed for logging / analytics. */
export interface ProfileDelta {
  interactionsApplied: number;
  durationAddedMs: number;
  frustrationEventsAdded: number;
  flowEventsAdded: number;
  finalStreak: number;
  newLongestStreak: number;
}

// ============================================================
// Tunable constants (S10-03 DoD)
// ============================================================

/** A "rapid quit" fires a frustration event when action != 'answer' and duration is below this. */
export const RAPID_QUIT_THRESHOLD_MS = 2000;

/** Flow fires when the streak transitions from this value to this+1. */
export const FLOW_STREAK_TRIGGER = 3;

/** Minimum consecutive wrong answers on the same concept to count as a frustration event. */
export const FRUSTRATION_CONSECUTIVE_WRONG = 2;

// ============================================================
// Pure reducers (unit-testable without a DB)
// ============================================================

function isKnownCardType(s: string): s is CardTypeKey {
  return (CARD_TYPE_KEYS as readonly string[]).includes(s);
}

/**
 * Merge a batch of interactions into an existing CardTypeStats object.
 * Pure — returns a new object, does not mutate the input.
 */
export function mergeCardTypeStats(
  current: CardTypeStats,
  events: InteractionEvent[]
): CardTypeStats {
  const next: CardTypeStats = {};
  for (const k of CARD_TYPE_KEYS) {
    const cur = current[k];
    if (cur) next[k] = { ...cur };
  }

  for (const ev of events) {
    if (!isKnownCardType(ev.cardType)) continue;
    const key = ev.cardType;
    const slot = next[key] ?? { count: 0, totalDurationMs: 0, completionCount: 0 };
    slot.count += 1;
    slot.totalDurationMs += Math.max(0, ev.durationMs | 0);
    const completed =
      ev.action === 'complete' || (ev.action === 'answer' && ev.isCorrect === true);
    if (completed) slot.completionCount += 1;
    next[key] = slot;
  }
  return next;
}

/**
 * Merge topic (domain) affinities from a batch. Cards without a domain are skipped.
 *
 * IMPORTANT: this function must never mutate `current` or any slot inside it —
 * callers may hold a reference to the prior snapshot (e.g. ingestInteractions
 * compares pre/post affinities to detect drift). We shallow-clone `current`
 * AND clone each slot before incrementing so the input is preserved byte-for-byte.
 */
export function mergeTopicAffinities(
  current: TopicAffinities,
  events: InteractionEvent[]
): TopicAffinities {
  const next: TopicAffinities = { ...current };
  for (const ev of events) {
    if (!ev.domain) continue;
    const key = ev.domain as DomainKey;
    const existing = next[key];
    // Clone the slot so we never mutate the one stored in `current`.
    const slot = existing
      ? { count: existing.count, totalDurationMs: existing.totalDurationMs }
      : { count: 0, totalDurationMs: 0 };
    slot.count += 1;
    slot.totalDurationMs += Math.max(0, ev.durationMs | 0);
    next[key] = slot;
  }
  return next;
}

/**
 * Walk a sequence of interactions and count frustration / flow events, tracking
 * the rolling streak state.
 *
 * Frustration:
 *   - ANY interaction with action != 'answer' AND durationMs < RAPID_QUIT_THRESHOLD_MS
 *     (likely a kid tapped away — early-quit signal).
 *   - A quiz wrong-answer that is the 2nd+ wrong answer in a row on the SAME concept.
 *
 * Flow:
 *   - Counted once per run of 3+ consecutive correct answers. The event fires
 *     when the streak transitions from 2 to 3; further correct answers in the
 *     same run don't double-count.
 */
export function classifyInteractionStream(
  events: InteractionEvent[],
  initialStreak = 0
): {
  frustrationEvents: number;
  flowEvents: number;
  endingStreak: number;
  peakStreak: number;
} {
  let frustration = 0;
  let flow = 0;
  let streak = Math.max(0, initialStreak | 0);
  let peak = streak;

  let lastWrongConceptId: string | null = null;
  let consecutiveWrongSameConcept = 0;

  for (const ev of events) {
    // Rapid-quit frustration — fires regardless of correctness on non-answer actions.
    if (
      ev.action !== 'answer' &&
      ev.durationMs >= 0 &&
      ev.durationMs < RAPID_QUIT_THRESHOLD_MS
    ) {
      frustration += 1;
    }

    if (ev.action === 'answer' && typeof ev.isCorrect === 'boolean') {
      if (ev.isCorrect) {
        streak += 1;
        if (streak === FLOW_STREAK_TRIGGER) flow += 1;
        if (streak > peak) peak = streak;
        lastWrongConceptId = null;
        consecutiveWrongSameConcept = 0;
      } else {
        // Wrong-answer pathway
        streak = 0;
        if (ev.conceptId && ev.conceptId === lastWrongConceptId) {
          consecutiveWrongSameConcept += 1;
          if (consecutiveWrongSameConcept >= FRUSTRATION_CONSECUTIVE_WRONG) {
            frustration += 1;
          }
        } else {
          lastWrongConceptId = ev.conceptId;
          consecutiveWrongSameConcept = 1;
        }
      }
    }
  }

  return {
    frustrationEvents: frustration,
    flowEvents: flow,
    endingStreak: streak,
    peakStreak: peak,
  };
}

/**
 * Sum duration and completion counters across a batch.
 * Separate from the reducers above so tests can assert each metric in isolation.
 */
export function summarizeBatch(events: InteractionEvent[]): {
  totalDurationMs: number;
  answerCount: number;
  correctCount: number;
} {
  let durMs = 0;
  let answers = 0;
  let correct = 0;
  for (const ev of events) {
    durMs += Math.max(0, ev.durationMs | 0);
    if (ev.action === 'answer') {
      answers += 1;
      if (ev.isCorrect === true) correct += 1;
    }
  }
  return { totalDurationMs: durMs, answerCount: answers, correctCount: correct };
}

// ============================================================
// Ranking helpers (read-side — used by the /engagement endpoint)
// ============================================================

export interface RankedCardType {
  type: CardTypeKey;
  count: number;
  totalDurationMs: number;
  completionRate: number;      // completions / count, 0..1
  avgDurationMs: number;       // totalDurationMs / count
  score: number;               // engagement score, used for ranking
}

export interface RankedTopicAffinity {
  domain: DomainKey;
  count: number;
  totalDurationMs: number;
  avgDurationMs: number;
  score: number;
}

/**
 * Engagement score: prefer card types the child completes AND lingers on.
 *   score = completionRate * log10(1 + totalDurationMs / 1000)
 * The log dampens long outliers (one 10-minute story shouldn't dominate).
 */
export function rankCardTypePreferences(stats: CardTypeStats): RankedCardType[] {
  const rows: RankedCardType[] = [];
  for (const key of CARD_TYPE_KEYS) {
    const s = stats[key];
    if (!s || s.count === 0) continue;
    const completionRate = s.completionCount / s.count;
    const avgDurationMs = s.totalDurationMs / s.count;
    const score = completionRate * Math.log10(1 + s.totalDurationMs / 1000);
    rows.push({
      type: key,
      count: s.count,
      totalDurationMs: s.totalDurationMs,
      completionRate: Number(completionRate.toFixed(3)),
      avgDurationMs: Number(avgDurationMs.toFixed(0)),
      score: Number(score.toFixed(4)),
    });
  }
  return rows.sort((a, b) => b.score - a.score);
}

/**
 * Topic affinity score: count-weighted average duration.
 *   score = count * log10(1 + totalDurationMs / 1000)
 * Unlike card-type prefs, we don't know "completion" at domain level — we
 * use raw engagement volume as the signal.
 */
export function rankTopicAffinities(aff: TopicAffinities): RankedTopicAffinity[] {
  const rows: RankedTopicAffinity[] = [];
  for (const [k, s] of Object.entries(aff)) {
    if (!s || s.count === 0) continue;
    const avgDurationMs = s.totalDurationMs / s.count;
    const score = s.count * Math.log10(1 + s.totalDurationMs / 1000);
    rows.push({
      domain: k as DomainKey,
      count: s.count,
      totalDurationMs: s.totalDurationMs,
      avgDurationMs: Number(avgDurationMs.toFixed(0)),
      score: Number(score.toFixed(4)),
    });
  }
  return rows.sort((a, b) => b.score - a.score);
}

// ============================================================
// Encryption helpers (thin wrappers so tests can stub)
// ============================================================

function encryptJSON(value: unknown, key: string): string {
  return encryptToken(JSON.stringify(value), key);
}

function decryptJSON<T>(ciphertext: string | null | undefined, key: string, fallback: T): T {
  if (!ciphertext) return fallback;
  try {
    return JSON.parse(decryptToken(ciphertext, key)) as T;
  } catch {
    // Key rotated / corrupt blob — treat as empty. Caller will re-encrypt on
    // next write. Intentionally not throwing: a decrypt failure here must not
    // poison /progress/sync, the write path callers can't meaningfully recover.
    return fallback;
  }
}

// ============================================================
// DB-facing API
// ============================================================

/**
 * Ingest a batch of interactions for one child, updating the profile in place.
 *
 * Contract:
 *   - Caller has already verified child ownership.
 *   - `events` may be empty — returns a zero-delta without touching the DB.
 *   - Serial per-child: the /progress/sync handler is the only writer and is
 *     already per-request, so we can safely read-modify-write without a tx.
 */
export async function ingestInteractions(
  childId: string,
  events: InteractionEvent[]
): Promise<ProfileDelta> {
  if (events.length === 0) {
    return {
      interactionsApplied: 0,
      durationAddedMs: 0,
      frustrationEventsAdded: 0,
      flowEventsAdded: 0,
      finalStreak: 0,
      newLongestStreak: 0,
    };
  }

  const prisma = getPrismaClient();
  const config = getConfig();
  const key = config.ENCRYPTION_KEY;

  const existing = await prisma.engagementProfile.findUnique({
    where: { childId },
  });

  const priorCardTypeStats = decryptJSON<CardTypeStats>(
    existing?.cardTypeStatsEncrypted ?? null,
    key,
    {}
  );
  const priorTopicAffinities = decryptJSON<TopicAffinities>(
    existing?.topicAffinitiesEncrypted ?? null,
    key,
    {}
  );

  const nextCardTypeStats = mergeCardTypeStats(priorCardTypeStats, events);
  const nextTopicAffinities = mergeTopicAffinities(priorTopicAffinities, events);
  const { frustrationEvents, flowEvents, endingStreak, peakStreak } =
    classifyInteractionStream(events, existing?.currentStreak ?? 0);
  const batchSummary = summarizeBatch(events);

  const now = new Date();
  const newLongestStreak = Math.max(existing?.longestStreak ?? 0, peakStreak);
  const nextTotalSessions =
    (existing?.totalSessions ?? 0) + (existing ? 0 : 1); // first ingest creates profile + counts one session
  // NB: session accounting is refined by the /progress/sync caller which passes
  // the session count explicitly (see ingestInteractionsForSession).

  const encryptedCardTypeStats = encryptJSON(nextCardTypeStats, key);
  const encryptedTopicAffinities = encryptJSON(nextTopicAffinities, key);

  await prisma.engagementProfile.upsert({
    where: { childId },
    create: {
      childId,
      totalSessions: nextTotalSessions,
      totalInteractions: events.length,
      totalDurationMs: batchSummary.totalDurationMs,
      frustrationEventCount: frustrationEvents,
      flowEventCount: flowEvents,
      currentStreak: endingStreak,
      longestStreak: newLongestStreak,
      cardTypeStatsEncrypted: encryptedCardTypeStats,
      topicAffinitiesEncrypted: encryptedTopicAffinities,
      lastInteractionAt: now,
      lastComputedAt: now,
    },
    update: {
      totalInteractions: { increment: events.length },
      totalDurationMs: { increment: batchSummary.totalDurationMs },
      frustrationEventCount: { increment: frustrationEvents },
      flowEventCount: { increment: flowEvents },
      currentStreak: endingStreak,
      longestStreak: newLongestStreak,
      cardTypeStatsEncrypted: encryptedCardTypeStats,
      topicAffinitiesEncrypted: encryptedTopicAffinities,
      lastInteractionAt: now,
      lastComputedAt: now,
    },
  });

  return {
    interactionsApplied: events.length,
    durationAddedMs: batchSummary.totalDurationMs,
    frustrationEventsAdded: frustrationEvents,
    flowEventsAdded: flowEvents,
    finalStreak: endingStreak,
    newLongestStreak,
  };
}

/**
 * Same as `ingestInteractions` but also increments the session counter by 1.
 * /progress/sync calls THIS variant because each sync is by definition one
 * session from the device's perspective.
 */
export async function ingestInteractionsForSession(
  childId: string,
  events: InteractionEvent[]
): Promise<ProfileDelta> {
  const delta = await ingestInteractions(childId, events);
  // Increment session counter once per sync. Do this in a tiny follow-up
  // update — safer than trying to fold it into the upsert above because the
  // upsert's `create` already writes `totalSessions: 1` for a fresh profile.
  const prisma = getPrismaClient();
  const row = await prisma.engagementProfile.findUnique({
    where: { childId },
    select: { createdAt: true, updatedAt: true, totalSessions: true },
  });
  if (row && row.createdAt.getTime() !== row.updatedAt.getTime()) {
    // Not the freshly-created row: bump sessions.
    await prisma.engagementProfile.update({
      where: { childId },
      data: { totalSessions: { increment: 1 } },
    });
  }
  return delta;
}

// ============================================================
// Read side
// ============================================================

export interface EngagementProfileView {
  childId: string;
  totalSessions: number;
  totalInteractions: number;
  totalDurationMs: number;
  avgInteractionMs: number;
  frustrationEventCount: number;
  flowEventCount: number;
  currentStreak: number;
  longestStreak: number;
  cardTypePreferences: RankedCardType[];
  topicAffinities: RankedTopicAffinity[];
  lastInteractionAt: Date | null;
  lastComputedAt: Date;
}

/** Fetch + decrypt an engagement profile for one child, or return null. */
export async function getEngagementProfile(
  childId: string
): Promise<EngagementProfileView | null> {
  const prisma = getPrismaClient();
  const config = getConfig();
  const row = await prisma.engagementProfile.findUnique({ where: { childId } });
  if (!row) return null;

  const cardTypeStats = decryptJSON<CardTypeStats>(
    row.cardTypeStatsEncrypted,
    config.ENCRYPTION_KEY,
    {}
  );
  const topicAffinities = decryptJSON<TopicAffinities>(
    row.topicAffinitiesEncrypted,
    config.ENCRYPTION_KEY,
    {}
  );

  const avgInteractionMs =
    row.totalInteractions > 0 ? row.totalDurationMs / row.totalInteractions : 0;

  return {
    childId: row.childId,
    totalSessions: row.totalSessions,
    totalInteractions: row.totalInteractions,
    totalDurationMs: row.totalDurationMs,
    avgInteractionMs: Number(avgInteractionMs.toFixed(0)),
    frustrationEventCount: row.frustrationEventCount,
    flowEventCount: row.flowEventCount,
    currentStreak: row.currentStreak,
    longestStreak: row.longestStreak,
    cardTypePreferences: rankCardTypePreferences(cardTypeStats),
    topicAffinities: rankTopicAffinities(topicAffinities),
    lastInteractionAt: row.lastInteractionAt,
    lastComputedAt: row.lastComputedAt,
  };
}
