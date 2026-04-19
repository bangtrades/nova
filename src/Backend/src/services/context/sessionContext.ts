/**
 * Session-aware context engine (Sprint 10 — S10-05, "The Brain")
 *
 * Injects kid-relevant situational context into every LLM prompt so the model
 * can calibrate tone, pacing, and scope to what's actually happening right
 * now for this specific child.
 *
 * Five context channels:
 *   1. Time of day (DST-safe, via IANA timezone on the child)
 *   2. Current session duration in minutes (bounded — we don't fatigue the kid)
 *   3. Recent quiz results (last-N correct/incorrect, momentum signal)
 *   4. Lessons completed today
 *   5. Current answer streak (from the EngagementProfile)
 *
 * DST safety is the entire point of doing timezones properly here. Examples:
 *   - 2:30am March 9 2025 in America/New_York does NOT exist (spring forward).
 *   - 1:30am November 2 2025 in America/New_York happens TWICE (fall back).
 *   - A child in Los Angeles and a child in New York can be in totally
 *     different "morning/afternoon" buckets at the same UTC instant.
 *
 * We never hand-roll offset math. Intl.DateTimeFormat with an IANA zone
 * handles every one of those edge cases correctly. The bucket boundaries
 * are defined in wall-clock hours, which is what matters for a child's
 * lived day.
 */
import { getPrismaClient } from '@db/client';

// ============================================================================
// Types
// ============================================================================

/** Wall-clock time-of-day buckets. Boundaries are inclusive-start, exclusive-end. */
export type TimeOfDayBucket =
  | 'earlyMorning' // 05:00–08:00 — quiet start, simple warm-ups
  | 'morning' //      08:00–12:00 — peak attention, new material
  | 'afternoon' //    12:00–17:00 — mid-energy, review / reinforcement
  | 'evening' //      17:00–20:00 — wind-down, storytelling tone
  | 'night' //        20:00–05:00 — short, calm, low-stimulation
  ;

export interface SessionContext {
  /** IANA zone name, echoed back so consumers can diagnose issues. */
  ianaTimezone: string;
  /** ISO timestamp of when this context was computed (UTC). */
  computedAt: string;
  /** The child's local wall-clock time, e.g. "14:37". Empty on bad timezone. */
  localClock: string;
  /** Day of week in the child's locale, e.g. "Friday". */
  localDayOfWeek: string;
  /** Which bucket we landed in. */
  timeOfDay: TimeOfDayBucket;
  /** Minutes elapsed in the current session, or null if no active session. */
  currentSessionMinutes: number | null;
  /** Lessons the child completed in their local day (midnight-to-now). */
  lessonsCompletedToday: number;
  /** Current consecutive-correct streak from the engagement profile. */
  currentStreak: number;
  /** Recent quiz results — newest first, bounded by RECENT_RESULTS_LIMIT. */
  recentQuizResults: RecentQuizResult[];
}

export interface RecentQuizResult {
  /** 'correct' | 'incorrect' — collapsed from CardInteraction.result.correct */
  outcome: 'correct' | 'incorrect';
  /** Minutes the child spent on the card. */
  durationMinutes: number;
  /** ISO timestamp of when the interaction happened. */
  at: string;
}

/**
 * Inputs used by the pure reducer. Lets tests exercise the bucket/streak logic
 * without a database.
 */
export interface SessionContextInputs {
  /** IANA timezone for the child. Falls back to "UTC" if blank/invalid. */
  ianaTimezone: string;
  /** "Now" — a Date value in UTC. Pure callers pass their own for determinism. */
  now: Date;
  /** When the current session started; null if no session is active. */
  sessionStartedAt: Date | null;
  /** Lessons the child completed in their local day. */
  lessonsCompletedToday: number;
  /** Engagement profile current streak (0 if none). */
  currentStreak: number;
  /** Recent quiz results (already ordered newest-first). */
  recentQuizResults: RecentQuizResult[];
}

// ============================================================================
// Constants
// ============================================================================

const RECENT_RESULTS_LIMIT = 10;
/** Max session minutes we report. We cap so a forgotten tab doesn't poison the prompt. */
const MAX_REPORTED_SESSION_MINUTES = 180;

// ============================================================================
// Pure helpers
// ============================================================================

/**
 * Validate an IANA timezone string using Intl's own parser. This is the
 * canonical "is this a zone the runtime knows about?" check on Node 20+.
 * Returns the input on success, falls back to "UTC" otherwise.
 */
export function resolveTimezone(raw: string | null | undefined): string {
  const candidate = (raw ?? '').trim();
  if (candidate.length === 0) return 'UTC';
  try {
    // Any invalid zone throws RangeError. Valid zones also accept "utc" etc.,
    // which Intl will canonicalize in the resolvedOptions.
    new Intl.DateTimeFormat('en-US', { timeZone: candidate });
    return candidate;
  } catch {
    return 'UTC';
  }
}

/**
 * Extract the wall-clock HH:MM and weekday for a UTC instant in a given zone.
 * Uses Intl.DateTimeFormat — handles DST transitions correctly because Intl
 * reaches into the IANA tzdata under the hood (never hand-rolled offsets).
 *
 * On DST spring-forward: the wall-clock simply jumps — a UTC instant from the
 * pre-transition second reads as the earlier hour, the next UTC instant reads
 * as the post-transition hour. `Intl` never produces a non-existent wall-clock.
 *
 * On DST fall-back: two distinct UTC instants produce the same wall-clock
 * 1:30am reading. That's fine — the bucket for both is the same, which is the
 * right answer for "where is the child in their day?"
 */
export function getLocalWallClock(
  now: Date,
  ianaTimezone: string
): { clock: string; weekday: string; hour24: number } {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: ianaTimezone,
    weekday: 'long',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  });
  const parts = fmt.formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  let hour = get('hour');
  // Intl in hour12:false mode emits "24" for midnight on some locales ("24:00");
  // normalise to "00" so downstream comparisons stay simple.
  if (hour === '24') hour = '00';
  const minute = get('minute');
  const weekday = get('weekday');
  const hour24 = Number.parseInt(hour, 10);
  return {
    clock: `${hour}:${minute}`,
    weekday,
    hour24: Number.isFinite(hour24) ? hour24 : 0,
  };
}

/**
 * Pure bucket assignment given an hour-of-day in 24h form.
 * Separated so tests can sweep 0..23 without touching Intl.
 */
export function bucketForHour24(hour: number): TimeOfDayBucket {
  if (!Number.isFinite(hour) || hour < 0 || hour > 23) return 'night';
  if (hour >= 5 && hour < 8) return 'earlyMorning';
  if (hour >= 8 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 20) return 'evening';
  return 'night'; // 20–04 inclusive
}

/**
 * Compute minutes elapsed since `start`, bounded to [0, MAX_REPORTED_SESSION_MINUTES].
 * Negative values (clock skew) clamp to 0 — we never report a negative duration.
 */
export function sessionMinutesSince(
  start: Date | null,
  now: Date
): number | null {
  if (!start) return null;
  const diffMs = now.getTime() - start.getTime();
  if (!Number.isFinite(diffMs)) return null;
  const minutes = Math.floor(diffMs / 60_000);
  if (minutes < 0) return 0;
  if (minutes > MAX_REPORTED_SESSION_MINUTES) return MAX_REPORTED_SESSION_MINUTES;
  return minutes;
}

/**
 * The pure reducer core. No DB, no Date.now — takes inputs, returns the
 * SessionContext. Tests use this to exercise DST edge cases directly.
 */
export function buildSessionContextFrom(inputs: SessionContextInputs): SessionContext {
  const tz = resolveTimezone(inputs.ianaTimezone);
  const { clock, weekday, hour24 } = getLocalWallClock(inputs.now, tz);
  return {
    ianaTimezone: tz,
    computedAt: inputs.now.toISOString(),
    localClock: clock,
    localDayOfWeek: weekday,
    timeOfDay: bucketForHour24(hour24),
    currentSessionMinutes: sessionMinutesSince(inputs.sessionStartedAt, inputs.now),
    lessonsCompletedToday: Math.max(0, Math.floor(inputs.lessonsCompletedToday || 0)),
    currentStreak: Math.max(0, Math.floor(inputs.currentStreak || 0)),
    recentQuizResults: inputs.recentQuizResults.slice(0, RECENT_RESULTS_LIMIT),
  };
}

// ============================================================================
// DB-facing helpers
// ============================================================================

/**
 * Compute the start of the child's LOCAL day as a UTC Date. We need this to
 * count "lessons completed today" against the child's wall-clock day, not the
 * server's UTC day.
 *
 * Approach: format the UTC instant into the zone, extract year/month/day,
 * then construct the UTC instant that represents local-midnight. Because
 * DST shifts typically happen at 2am (not midnight), local-midnight exists
 * on every day of the year — no spring-forward gap at this boundary.
 */
export function localStartOfDayUtc(now: Date, ianaTimezone: string): Date {
  const tz = resolveTimezone(ianaTimezone);
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  });
  const parts = fmt.formatToParts(now);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  const yyyy = Number(get('year'));
  const mm = Number(get('month'));
  const dd = Number(get('day'));

  // Compute the zone's offset-from-UTC at local-midnight of (yyyy-mm-dd).
  // We binary search by constructing a candidate UTC midnight, then
  // reading it back through Intl to see if it lands on the right date.
  // For almost all zones this converges in one iteration; the exception
  // is ambiguous-wall-clock cases which don't apply to midnight on any
  // real-world IANA zone.
  const candidateUtc = new Date(Date.UTC(yyyy, mm - 1, dd, 0, 0, 0));
  const readBack = fmt.formatToParts(candidateUtc);
  const readBackDay = Number(readBack.find((p) => p.type === 'day')?.value ?? '0');
  const readBackMonth = Number(readBack.find((p) => p.type === 'month')?.value ?? '0');
  const readBackYear = Number(readBack.find((p) => p.type === 'year')?.value ?? '0');
  const readBackHour = Number(readBack.find((p) => p.type === 'hour')?.value ?? '0');

  // Offset in minutes the zone is ahead of UTC at local-midnight.
  // If readBackDay already equals dd AND hour is 0, we already have local midnight.
  if (readBackYear === yyyy && readBackMonth === mm && readBackDay === dd && readBackHour === 0) {
    return candidateUtc;
  }
  // Otherwise compute the hours the candidate is ahead/behind local-midnight
  // and shift. E.g. in America/New_York, `new Date(Date.UTC(2025, 2, 9))` reads
  // as March 8 19:00 local — five hours before local midnight of March 9.
  const targetLocalMs = Date.UTC(yyyy, mm - 1, dd, 0, 0, 0);
  const readBackLocalMs = Date.UTC(
    readBackYear,
    readBackMonth - 1,
    readBackDay,
    readBackHour,
    Number(readBack.find((p) => p.type === 'minute')?.value ?? '0'),
    Number(readBack.find((p) => p.type === 'second')?.value ?? '0')
  );
  const offsetMs = targetLocalMs - readBackLocalMs;
  return new Date(candidateUtc.getTime() + offsetMs);
}

/**
 * Load the live session context for a child. Composes:
 *   - ChildProfile.ianaTimezone
 *   - Active LearningSession (endedAt IS NULL, most recent)
 *   - Lessons completed since local midnight (via CardInteraction stream is
 *     too noisy — we count distinct lessons that had any interaction today)
 *   - EngagementProfile.currentStreak
 *   - Recent CardInteraction results (card type linked to Card — only quiz-like
 *     interactions with a result.correct boolean count)
 */
export async function buildSessionContext(
  childId: string,
  now: Date = new Date()
): Promise<SessionContext> {
  const prisma = getPrismaClient();

  // Pull child's tz up front — everything downstream depends on it.
  // `(prisma as any)` guards against a stale generated client in the sandbox;
  // once `prisma generate` runs on the Mac, the typed client includes the
  // `ianaTimezone` field from the S10-05 migration.
  const child = await (prisma as any).childProfile.findUnique({
    where: { id: childId },
    select: { ianaTimezone: true },
  });
  const tz = resolveTimezone(child?.ianaTimezone ?? 'UTC');
  const localMidnight = localStartOfDayUtc(now, tz);

  // Most recent open session (if any) for "current session minutes".
  const activeSession = await prisma.learningSession.findFirst({
    where: { childId, endedAt: null },
    orderBy: { startedAt: 'desc' },
    select: { startedAt: true },
  });

  // Lessons completed today: count distinct lessons the child interacted with
  // since local midnight. A cheap proxy for "lessons touched today" — we'll
  // refine in S10-06 when the lesson-completion event lands on the write side.
  const todayInteractions = await prisma.cardInteraction.findMany({
    where: {
      session: { childId },
      timestamp: { gte: localMidnight, lte: now },
    },
    select: { card: { select: { lessonId: true } } },
  });
  const lessonsCompletedToday = new Set(
    todayInteractions.map((i) => i.card.lessonId)
  ).size;

  // Current streak from engagement profile — zero-state if none.
  const engagement = await (prisma as any).engagementProfile.findUnique({
    where: { childId },
    select: { currentStreak: true },
  });
  const currentStreak = engagement?.currentStreak ?? 0;

  // Recent quiz results — last 10 interactions that have a `result.correct`.
  const recentInteractions = await prisma.cardInteraction.findMany({
    where: { session: { childId }, action: 'answer' },
    orderBy: { timestamp: 'desc' },
    take: 40, // oversample, then filter for the ones with a parseable result
    select: { result: true, durationMs: true, timestamp: true },
  });

  const recentQuizResults: RecentQuizResult[] = [];
  for (const row of recentInteractions) {
    if (recentQuizResults.length >= RECENT_RESULTS_LIMIT) break;
    const parsed = safeParseResult(row.result);
    if (parsed === null) continue;
    recentQuizResults.push({
      outcome: parsed.correct ? 'correct' : 'incorrect',
      durationMinutes: Math.max(0, Math.round(row.durationMs / 60_000)),
      at: row.timestamp.toISOString(),
    });
  }

  return buildSessionContextFrom({
    ianaTimezone: tz,
    now,
    sessionStartedAt: activeSession?.startedAt ?? null,
    lessonsCompletedToday,
    currentStreak,
    recentQuizResults,
  });
}

/**
 * Tolerant `result` parser — CardInteraction.result may be a parsed object
 * (via the JSON middleware) or a raw JSON string or null. Returns null if we
 * can't extract a `.correct` boolean.
 */
function safeParseResult(raw: unknown): { correct: boolean } | null {
  if (raw === null || raw === undefined) return null;
  let obj: unknown = raw;
  if (typeof raw === 'string') {
    try {
      obj = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!obj || typeof obj !== 'object') return null;
  const correct = (obj as { correct?: unknown }).correct;
  if (typeof correct !== 'boolean') return null;
  return { correct };
}
