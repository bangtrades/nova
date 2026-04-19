/**
 * Parent Guidance service (Sprint 10 — S10-04, "The Brain")
 *
 * Per-child parental controls that shape content generation:
 *   - topic focus / topic avoid
 *   - difficulty offset (clamped to [-2, +2])
 *   - content boundaries (disallowed keywords, allowed tags)
 *   - session time limits (daily + single-session minutes)
 *
 * Architecture:
 *   - Pure helpers (clampDifficultyOffset, sanitizeBoundaries, normalizeTopicList,
 *     mergeGuidance) are deterministic, no DB, easy to unit-test.
 *   - DB-facing helpers (getGuidance, upsertGuidance) wrap prisma and return the
 *     parsed, merged view suitable for both the REST layer and the pipeline
 *     prompt builders.
 */
import { getPrismaClient } from '@db/client';

/**
 * Maximum absolute difficulty offset. Parents can nudge content ±2 steps from the
 * model's baseline estimate for the child's age — beyond that and we'd be
 * serving content that's either trivially easy or cognitively out-of-band.
 */
export const MAX_DIFFICULTY_OFFSET = 2;

/**
 * Max length caps on parent-authored inputs. These prevent prompt-injection style
 * payloads from slipping into downstream LLM calls.
 */
const MAX_TOPIC_ENTRY_LEN = 80;
const MAX_TOPIC_LIST_LEN = 32;
const MAX_BOUNDARY_ENTRY_LEN = 80;
const MAX_BOUNDARY_LIST_LEN = 64;

export interface ContentBoundaries {
  /** Keywords the pipeline must filter out (case-insensitive substring match). */
  disallowedKeywords?: string[];
  /** Tags the pipeline may include explicitly (whitelist — empty = any). */
  allowedTags?: string[];
}

export interface ParentGuidanceView {
  childId: string;
  topicFocus: string[];
  topicAvoid: string[];
  difficultyOffset: number;
  contentBoundaries: ContentBoundaries;
  dailySessionLimitMinutes: number | null;
  singleSessionLimitMinutes: number | null;
  updatedByUserId: string;
  createdAt: Date;
  updatedAt: Date;
}

/**
 * Default/zero-state guidance used when no row exists for a child yet.
 * The pipeline is free to call `getGuidanceOrDefault(childId)` and inject
 * it unconditionally — an empty guidance object is a no-op on the prompt.
 */
export function defaultGuidance(childId: string): ParentGuidanceView {
  const now = new Date();
  return {
    childId,
    topicFocus: [],
    topicAvoid: [],
    difficultyOffset: 0,
    contentBoundaries: {},
    dailySessionLimitMinutes: null,
    singleSessionLimitMinutes: null,
    updatedByUserId: '',
    createdAt: now,
    updatedAt: now,
  };
}

// ============================================================================
// Pure helpers — no DB. Safe to unit-test with plain values.
// ============================================================================

/**
 * Clamp a caller-supplied offset into the allowed range [-MAX..+MAX].
 * Accepts any number (including NaN / floats) and returns a safe integer.
 */
export function clampDifficultyOffset(raw: unknown): number {
  const n = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(n)) return 0;
  const rounded = Math.round(n);
  if (rounded > MAX_DIFFICULTY_OFFSET) return MAX_DIFFICULTY_OFFSET;
  if (rounded < -MAX_DIFFICULTY_OFFSET) return -MAX_DIFFICULTY_OFFSET;
  return rounded;
}

/**
 * Normalize a string array — trim, drop empties / non-strings, cap lengths,
 * dedupe case-insensitively, cap list length. Returns a new array.
 */
export function normalizeTopicList(raw: unknown): string[] {
  if (!Array.isArray(raw)) return [];
  const seen = new Set<string>();
  const out: string[] = [];
  for (const entry of raw) {
    if (typeof entry !== 'string') continue;
    const trimmed = entry.trim();
    if (trimmed.length === 0 || trimmed.length > MAX_TOPIC_ENTRY_LEN) continue;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(trimmed);
    if (out.length >= MAX_TOPIC_LIST_LEN) break;
  }
  return out;
}

/**
 * Normalize a ContentBoundaries object — accept only known keys, coerce values
 * through normalizeTopicList bounds. Unknown keys are silently dropped so the
 * shape cannot be polluted by arbitrary client data.
 */
export function sanitizeBoundaries(raw: unknown): ContentBoundaries {
  if (!raw || typeof raw !== 'object') return {};
  const src = raw as Record<string, unknown>;
  const out: ContentBoundaries = {};
  const normList = (input: unknown): string[] => {
    if (!Array.isArray(input)) return [];
    const seen = new Set<string>();
    const result: string[] = [];
    for (const entry of input) {
      if (typeof entry !== 'string') continue;
      const trimmed = entry.trim();
      if (trimmed.length === 0 || trimmed.length > MAX_BOUNDARY_ENTRY_LEN) continue;
      const key = trimmed.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(trimmed);
      if (result.length >= MAX_BOUNDARY_LIST_LEN) break;
    }
    return result;
  };
  if ('disallowedKeywords' in src) {
    const list = normList(src.disallowedKeywords);
    if (list.length > 0) out.disallowedKeywords = list;
  }
  if ('allowedTags' in src) {
    const list = normList(src.allowedTags);
    if (list.length > 0) out.allowedTags = list;
  }
  return out;
}

/**
 * Coerce a nullable minutes field: accepts number | null | undefined.
 * Negative / non-finite / overflow values become null.
 * 0 is treated as "no limit" and also becomes null so the UI has one
 * canonical "unset" representation.
 */
export function coerceLimitMinutes(raw: unknown): number | null {
  if (raw === null || raw === undefined) return null;
  const n = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(n)) return null;
  const rounded = Math.round(n);
  if (rounded <= 0) return null;
  if (rounded > 24 * 60) return 24 * 60; // cap at 24h so storage is bounded
  return rounded;
}

/**
 * Merge a partial guidance patch onto an existing base. Preserves fields the
 * patch omits, and runs every incoming field through its sanitizer.
 * Used by PUT to produce the new full row, and by tests as the reducer core.
 */
export function mergeGuidance(
  base: ParentGuidanceView,
  patch: Partial<{
    topicFocus: unknown;
    topicAvoid: unknown;
    difficultyOffset: unknown;
    contentBoundaries: unknown;
    dailySessionLimitMinutes: unknown;
    singleSessionLimitMinutes: unknown;
  }>
): Omit<ParentGuidanceView, 'childId' | 'updatedByUserId' | 'createdAt' | 'updatedAt'> {
  return {
    topicFocus:
      'topicFocus' in patch ? normalizeTopicList(patch.topicFocus) : base.topicFocus,
    topicAvoid:
      'topicAvoid' in patch ? normalizeTopicList(patch.topicAvoid) : base.topicAvoid,
    difficultyOffset:
      'difficultyOffset' in patch
        ? clampDifficultyOffset(patch.difficultyOffset)
        : base.difficultyOffset,
    contentBoundaries:
      'contentBoundaries' in patch
        ? sanitizeBoundaries(patch.contentBoundaries)
        : base.contentBoundaries,
    dailySessionLimitMinutes:
      'dailySessionLimitMinutes' in patch
        ? coerceLimitMinutes(patch.dailySessionLimitMinutes)
        : base.dailySessionLimitMinutes,
    singleSessionLimitMinutes:
      'singleSessionLimitMinutes' in patch
        ? coerceLimitMinutes(patch.singleSessionLimitMinutes)
        : base.singleSessionLimitMinutes,
  };
}

// ============================================================================
// Parsing helpers — DB row ↔ view. The prisma middleware auto-parses JSON
// string fields on read, so these functions are defensive: they accept either
// a parsed array/object or a raw JSON string.
// ============================================================================

function parseJsonField<T>(val: unknown, fallback: T): T {
  if (val === null || val === undefined) return fallback;
  if (typeof val === 'string') {
    try {
      return JSON.parse(val) as T;
    } catch {
      return fallback;
    }
  }
  return val as T;
}

function rowToView(row: {
  childId: string;
  topicFocus: unknown;
  topicAvoid: unknown;
  difficultyOffset: number;
  contentBoundaries: unknown;
  dailySessionLimitMinutes: number | null;
  singleSessionLimitMinutes: number | null;
  updatedByUserId: string;
  createdAt: Date;
  updatedAt: Date;
}): ParentGuidanceView {
  return {
    childId: row.childId,
    topicFocus: normalizeTopicList(parseJsonField<string[]>(row.topicFocus, [])),
    topicAvoid: normalizeTopicList(parseJsonField<string[]>(row.topicAvoid, [])),
    difficultyOffset: clampDifficultyOffset(row.difficultyOffset),
    contentBoundaries: sanitizeBoundaries(
      parseJsonField<ContentBoundaries>(row.contentBoundaries, {})
    ),
    dailySessionLimitMinutes: row.dailySessionLimitMinutes,
    singleSessionLimitMinutes: row.singleSessionLimitMinutes,
    updatedByUserId: row.updatedByUserId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

// ============================================================================
// DB-facing helpers
// ============================================================================

/** Fetch the child's guidance row. Returns null if none exists. */
export async function getGuidance(
  childId: string
): Promise<ParentGuidanceView | null> {
  const prisma = getPrismaClient();
  const row = await (prisma as any).parentGuidance.findUnique({
    where: { childId },
  });
  if (!row) return null;
  return rowToView(row);
}

/**
 * Fetch the child's guidance row, or return the zero-state default. The
 * pipeline uses this so the prompt builders can unconditionally call
 * `buildParentGuidancePreamble(guidance)` without null-checks.
 */
export async function getGuidanceOrDefault(
  childId: string
): Promise<ParentGuidanceView> {
  const existing = await getGuidance(childId);
  return existing ?? defaultGuidance(childId);
}

/**
 * Upsert the child's guidance row. Accepts a partial patch and merges it over
 * the existing row (or defaults). Runs every field through the sanitizers.
 *
 * `updatedByUserId` is the calling parent's id — used as an audit trail on who
 * last touched this child's guidance.
 */
export async function upsertGuidance(
  childId: string,
  patch: Partial<{
    topicFocus: unknown;
    topicAvoid: unknown;
    difficultyOffset: unknown;
    contentBoundaries: unknown;
    dailySessionLimitMinutes: unknown;
    singleSessionLimitMinutes: unknown;
  }>,
  updatedByUserId: string
): Promise<ParentGuidanceView> {
  const prisma = getPrismaClient();
  const existing = await getGuidance(childId);
  const base = existing ?? defaultGuidance(childId);
  const merged = mergeGuidance(base, patch);

  // The prisma JSON middleware will auto-stringify array / object fields on
  // write. See db/client.ts JSON_STRING_FIELDS['parentGuidance'].
  const row = await (prisma as any).parentGuidance.upsert({
    where: { childId },
    create: {
      childId,
      topicFocus: merged.topicFocus,
      topicAvoid: merged.topicAvoid,
      difficultyOffset: merged.difficultyOffset,
      contentBoundaries: merged.contentBoundaries,
      dailySessionLimitMinutes: merged.dailySessionLimitMinutes,
      singleSessionLimitMinutes: merged.singleSessionLimitMinutes,
      updatedByUserId,
    },
    update: {
      topicFocus: merged.topicFocus,
      topicAvoid: merged.topicAvoid,
      difficultyOffset: merged.difficultyOffset,
      contentBoundaries: merged.contentBoundaries,
      dailySessionLimitMinutes: merged.dailySessionLimitMinutes,
      singleSessionLimitMinutes: merged.singleSessionLimitMinutes,
      updatedByUserId,
    },
  });

  return rowToView(row);
}

/** Delete a child's guidance row. Used by data-rights endpoints. */
export async function deleteGuidance(childId: string): Promise<void> {
  const prisma = getPrismaClient();
  await (prisma as any).parentGuidance.deleteMany({ where: { childId } });
}
