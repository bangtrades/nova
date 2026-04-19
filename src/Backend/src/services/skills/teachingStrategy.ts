/**
 * Teaching Strategy Matrix (Sprint 10 — S10-11)
 *
 * A pure, data-driven ranker that answers:
 *
 *   "Given a concept of TYPE X, to be taught to a child whose preferred
 *    learning MODALITY is Y, which card TYPES should we generate, in
 *    what order, taking into account (a) engagement history, (b) current
 *    difficulty offset, and (c) age-appropriate constraints?"
 *
 * This service is intentionally SMALL and PURE — no DB calls, no LLM
 * calls, no side effects. It is the foundation the rest of the SKILL
 * epic builds on:
 *
 *   - S10-06 story-writer   → invoked when `story`   wins the ranking
 *   - S10-07 quiz-maker     → invoked when `quiz`    wins
 *   - S10-08 experiment…    → invoked when `experiment` wins
 *   - S10-09 curriculum…    → calls rankCardTypesFor per planned concept
 *   - S10-10 voice-persona  → applied on top of any card of type `voice`
 *   - S10-12 pipeline       → replaces the "generic prompt" path in Stage 4
 *
 * The matrix itself is opinionated pedagogy, not user-configurable. It
 * encodes the "first-pass intuition" a human curriculum designer would
 * have before looking at any specific child's data. The ranker then
 * layers the child's signals on top.
 *
 * -------------------------------------------------------------------
 * Signal layering (in order):
 *
 *   1. Base cell        — opinionated pedagogy, from MATRIX
 *   2. Engagement boost — card types this child has completed often
 *                          and lingered on (from S10-03 RankedCardType)
 *   3. Difficulty shift — pushes toward `quiz` / `experiment` at high
 *                          offsets; toward `story` / `voice` at low
 *   4. Age gate         — penalizes `experiment` under age 6,
 *                          penalizes long-text `concept` under age 5,
 *                          never disqualifies entirely (allows grown-up
 *                          content when the matrix genuinely demands it)
 *
 * Every layer produces an additive bonus; the final score sorts the
 * cell's card types descending. Ties are broken by the base cell order.
 *
 * -------------------------------------------------------------------
 * Why not store the matrix in the DB?
 *
 * The matrix is product-owned pedagogy. Changing it is a content-policy
 * change, not a per-child configuration. Keeping it in source means it
 * ships atomically with the skills that assume it and is trivially
 * testable. Per-child variation happens in the ranker, not the matrix.
 */

import type { CardTypeKey, RankedCardType } from '@services/engagement/engagementProfiler';

// ------------------------------------------------------------------
// Public types
// ------------------------------------------------------------------

/**
 * The pedagogical shape of the concept being taught.
 *
 * `vocabulary`  — a new word, label, or name (e.g. "algorithm")
 * `abstract`    — a non-physical idea (e.g. "fairness", "infinity")
 * `process`     — a sequence of steps (e.g. "how a bubble sort works")
 * `comparison`  — two or more things contrasted (e.g. "RAM vs disk")
 * `causeEffect` — "X happens because Y" (e.g. "gears slow motors down")
 * `factual`     — a discrete fact (e.g. "the moon is 384,000 km away")
 *
 * Kept deliberately shorter than the 7 TeachingStrategies used inside
 * the conceptDecomposer — this is the child-facing classification of
 * the concept, not the card's storytelling strategy.
 */
export type ConceptType =
  | 'vocabulary'
  | 'abstract'
  | 'process'
  | 'comparison'
  | 'causeEffect'
  | 'factual';

export const CONCEPT_TYPES: readonly ConceptType[] = [
  'vocabulary',
  'abstract',
  'process',
  'comparison',
  'causeEffect',
  'factual',
] as const;

/**
 * The child's preferred input channel. Inferred by the curriculum
 * engine from engagement stats (e.g. "this child completes voice cards
 * 3x more than they complete concept cards → auditory leans auditory").
 */
export type LearningModality = 'visual' | 'auditory' | 'kinesthetic';

export const LEARNING_MODALITIES: readonly LearningModality[] = [
  'visual',
  'auditory',
  'kinesthetic',
] as const;

/** One row of the final ranked output. */
export interface RankedCardTypeRec {
  cardType: CardTypeKey;
  /** Base rank (0 = best, 4 = worst) from the matrix cell alone. */
  baseRank: number;
  /** The final score: higher = better. Starts at (5 - baseRank). */
  score: number;
  /** Engagement-layer bonus applied (can be negative). */
  engagementBonus: number;
  /** Difficulty-layer bonus applied (can be negative). */
  difficultyBonus: number;
  /** Age-layer bonus applied (can be negative). */
  ageBonus: number;
}

/**
 * Inputs to the ranker beyond the matrix coordinates.
 *
 * All fields are optional — the ranker degrades gracefully to the raw
 * matrix when no signals are available. This is important because the
 * first time a child uses Nova they have no engagement history.
 */
export interface RankerContext {
  /** From S10-03 — ranked card-type preferences. Empty for cold-start. */
  engagement?: RankedCardType[];
  /** From S10-04 — parent's difficulty nudge, clamped to [-2, +2]. */
  difficultyOffset?: number;
  /** The child's age in whole years. Typical Nova range: 4..12. */
  ageYears?: number;
}

// ------------------------------------------------------------------
// The matrix (6 × 3)
// ------------------------------------------------------------------

/**
 * Each cell is a CardType priority ranking (best → worst). Every cell
 * lists all 5 card types — there is never an empty cell. The ordering
 * is what a human curriculum designer would suggest if they knew ONLY
 * the concept type and the modality.
 *
 * Mnemonic guide to the cells below:
 *
 *   visual       → favor cards that carry an image (`concept`, `story`,
 *                  `experiment`) before ones that don't (`voice`, `quiz`)
 *   auditory     → favor `voice` + `story`; `quiz` last because quiz
 *                  cards are predominantly read, not heard
 *   kinesthetic  → favor `experiment` first; then `quiz` (answer-choice
 *                  is a motor act); then narrative forms
 *
 * Type-level interactions:
 *   vocabulary   → `concept` (label + image) + `story` (usage in context)
 *   abstract     → `story` first (abstract ideas need narrative scaffolding)
 *   process      → `experiment` + `concept` (steps to follow)
 *   comparison   → `concept` + `quiz` (pick-the-different-one works well)
 *   causeEffect  → `story` + `experiment` (reproducible demonstration)
 *   factual      → `concept` + `quiz` (discrete fact, directly testable)
 */
const MATRIX: Record<ConceptType, Record<LearningModality, CardTypeKey[]>> = {
  vocabulary: {
    visual: ['concept', 'story', 'quiz', 'voice', 'experiment'],
    auditory: ['voice', 'story', 'concept', 'quiz', 'experiment'],
    kinesthetic: ['experiment', 'concept', 'quiz', 'story', 'voice'],
  },
  abstract: {
    visual: ['story', 'concept', 'quiz', 'voice', 'experiment'],
    auditory: ['voice', 'story', 'concept', 'quiz', 'experiment'],
    kinesthetic: ['experiment', 'story', 'concept', 'quiz', 'voice'],
  },
  process: {
    visual: ['concept', 'experiment', 'story', 'quiz', 'voice'],
    auditory: ['voice', 'concept', 'experiment', 'story', 'quiz'],
    kinesthetic: ['experiment', 'concept', 'quiz', 'story', 'voice'],
  },
  comparison: {
    visual: ['concept', 'quiz', 'story', 'experiment', 'voice'],
    auditory: ['voice', 'concept', 'quiz', 'story', 'experiment'],
    kinesthetic: ['experiment', 'quiz', 'concept', 'story', 'voice'],
  },
  causeEffect: {
    visual: ['concept', 'story', 'experiment', 'quiz', 'voice'],
    auditory: ['voice', 'story', 'concept', 'experiment', 'quiz'],
    kinesthetic: ['experiment', 'story', 'concept', 'quiz', 'voice'],
  },
  factual: {
    visual: ['concept', 'quiz', 'story', 'voice', 'experiment'],
    auditory: ['voice', 'concept', 'quiz', 'story', 'experiment'],
    kinesthetic: ['concept', 'experiment', 'quiz', 'story', 'voice'],
  },
};

// Stable, explicit guarantee: every cell lists every card type exactly once.
// This assertion runs at module load and throws loudly if the matrix is ever
// edited wrong. Cheaper than a unit test catching it later.
(function validateMatrix(): void {
  const expected: CardTypeKey[] = ['story', 'concept', 'experiment', 'quiz', 'voice'];
  for (const ct of CONCEPT_TYPES) {
    for (const mod of LEARNING_MODALITIES) {
      const cell = MATRIX[ct][mod];
      if (cell.length !== expected.length) {
        throw new Error(`[teachingStrategy] matrix[${ct}][${mod}] wrong length ${cell.length}`);
      }
      const seen = new Set<string>();
      for (const t of cell) {
        if (!expected.includes(t)) {
          throw new Error(`[teachingStrategy] matrix[${ct}][${mod}] unknown type "${t}"`);
        }
        if (seen.has(t)) {
          throw new Error(`[teachingStrategy] matrix[${ct}][${mod}] duplicate "${t}"`);
        }
        seen.add(t);
      }
    }
  }
})();

// ------------------------------------------------------------------
// Tunable constants (intentionally small; easy to sweep via tests)
// ------------------------------------------------------------------

/** The top-ranked engagement card type gets +THIS added to its score. */
export const ENGAGEMENT_TOP_BONUS = 1.5;
/** The 2nd-ranked engagement card type gets +THIS. */
export const ENGAGEMENT_SECOND_BONUS = 0.75;
/** Bottom engagement card types that the child has NEVER completed get -THIS. */
export const ENGAGEMENT_ZERO_COMPLETION_PENALTY = 0.5;

/** Magnitude of the per-step difficulty shift. offset=+1 applies +1*STEP. */
export const DIFFICULTY_STEP = 0.4;
/** At high difficulty we push toward these types. */
const DIFFICULTY_HARD_FAVOR: CardTypeKey[] = ['quiz', 'experiment'];
/** At low difficulty we push toward these types. */
const DIFFICULTY_EASY_FAVOR: CardTypeKey[] = ['story', 'voice'];

/** Under this age, `experiment` cards are penalized for motor-skill reasons. */
export const EXPERIMENT_MIN_AGE = 6;
/** Under this age, long-text `concept` cards are penalized (child may not be reading yet). */
export const CONCEPT_MIN_AGE = 5;
/** Magnitude of the age penalty (additive, negative). */
export const AGE_GATE_PENALTY = 0.75;

// ------------------------------------------------------------------
// Pure ranker
// ------------------------------------------------------------------

/**
 * Rank the 5 card types for a given concept-type × modality cell, taking
 * the child's engagement, difficulty, and age into account.
 *
 * @returns A stable sort: higher score first; ties broken by lower baseRank.
 */
export function rankCardTypesFor(
  conceptType: ConceptType,
  modality: LearningModality,
  ctx: RankerContext = {}
): RankedCardTypeRec[] {
  const baseCell = MATRIX[conceptType][modality];

  const rows: RankedCardTypeRec[] = baseCell.map((cardType, idx) => {
    const baseRank = idx;
    // Base score: 5 for the best in the cell, 1 for the worst. Leaves room
    // for the layers below to reorder without going negative in the common case.
    const base = 5 - baseRank;
    const engagementBonus = computeEngagementBonus(cardType, ctx.engagement ?? []);
    const difficultyBonus = computeDifficultyBonus(cardType, ctx.difficultyOffset ?? 0);
    const ageBonus = computeAgeBonus(cardType, ctx.ageYears);
    const score = base + engagementBonus + difficultyBonus + ageBonus;
    return {
      cardType,
      baseRank,
      engagementBonus: round(engagementBonus),
      difficultyBonus: round(difficultyBonus),
      ageBonus: round(ageBonus),
      score: round(score),
    };
  });

  // Stable sort: primary = score desc, tiebreaker = baseRank asc.
  rows.sort((a, b) => {
    if (b.score !== a.score) return b.score - a.score;
    return a.baseRank - b.baseRank;
  });

  return rows;
}

/**
 * Convenience: flat list of card types in ranked order, no metadata.
 * Used by the pipeline orchestrator when it only needs the winner.
 */
export function rankedCardTypeOrder(
  conceptType: ConceptType,
  modality: LearningModality,
  ctx: RankerContext = {}
): CardTypeKey[] {
  return rankCardTypesFor(conceptType, modality, ctx).map((r) => r.cardType);
}

/**
 * Introspection helper (used by the Dev Console Strategy tab). Returns
 * the raw matrix so the UI can render all 18 cells without re-walking
 * the API.
 */
export function getStrategyMatrix(): Record<ConceptType, Record<LearningModality, CardTypeKey[]>> {
  // Shallow clone so callers can't mutate module state.
  const out: Record<string, Record<string, CardTypeKey[]>> = {};
  for (const ct of CONCEPT_TYPES) {
    out[ct] = {};
    for (const mod of LEARNING_MODALITIES) {
      out[ct][mod] = [...MATRIX[ct][mod]];
    }
  }
  return out as Record<ConceptType, Record<LearningModality, CardTypeKey[]>>;
}

/**
 * Infer the child's most-likely LearningModality from their engagement
 * profile. This is a heuristic — if the signal is weak (cold-start or
 * mixed data) it returns 'visual' as a neutral default.
 *
 * Mapping (from their top-ranked card type):
 *   voice                 → auditory
 *   story                 → auditory  (Nova auto-narrates stories)
 *   experiment            → kinesthetic
 *   quiz                  → kinesthetic (answer-choice is a motor act)
 *   concept               → visual
 *   no engagement yet     → visual   (neutral default)
 */
export function inferModality(
  engagement: RankedCardType[] | undefined
): LearningModality {
  if (!engagement || engagement.length === 0) return 'visual';
  const top = engagement[0].type;
  switch (top) {
    case 'voice':
    case 'story':
      return 'auditory';
    case 'experiment':
    case 'quiz':
      return 'kinesthetic';
    case 'concept':
    default:
      return 'visual';
  }
}

// ------------------------------------------------------------------
// Layer helpers (exported for unit testing)
// ------------------------------------------------------------------

export function computeEngagementBonus(
  cardType: CardTypeKey,
  engagement: RankedCardType[]
): number {
  if (!engagement || engagement.length === 0) return 0;

  // The engagement array is already sorted by score desc in S10-03.
  const idx = engagement.findIndex((e) => e.type === cardType);
  if (idx === 0) return ENGAGEMENT_TOP_BONUS;
  if (idx === 1) return ENGAGEMENT_SECOND_BONUS;

  // If the child has interacted with this type but never completed it, penalize.
  if (idx > 1) {
    const row = engagement[idx];
    if (row.completionRate === 0) {
      return -ENGAGEMENT_ZERO_COMPLETION_PENALTY;
    }
  }
  return 0;
}

export function computeDifficultyBonus(
  cardType: CardTypeKey,
  offset: number
): number {
  if (!Number.isFinite(offset) || offset === 0) return 0;
  // Clamp defensively — guidance layer should already have done this, but
  // the ranker mustn't blow up if someone wires it differently later.
  const clamped = Math.max(-2, Math.min(2, offset));
  const magnitude = Math.abs(clamped) * DIFFICULTY_STEP;
  const favor = clamped > 0 ? DIFFICULTY_HARD_FAVOR : DIFFICULTY_EASY_FAVOR;
  const penalize = clamped > 0 ? DIFFICULTY_EASY_FAVOR : DIFFICULTY_HARD_FAVOR;
  if (favor.includes(cardType)) return magnitude;
  if (penalize.includes(cardType)) return -magnitude;
  return 0;
}

export function computeAgeBonus(cardType: CardTypeKey, ageYears: number | undefined): number {
  if (ageYears === undefined || !Number.isFinite(ageYears)) return 0;
  if (cardType === 'experiment' && ageYears < EXPERIMENT_MIN_AGE) return -AGE_GATE_PENALTY;
  if (cardType === 'concept' && ageYears < CONCEPT_MIN_AGE) return -AGE_GATE_PENALTY;
  return 0;
}

// ------------------------------------------------------------------
// Internal
// ------------------------------------------------------------------

function round(n: number): number {
  return Math.round(n * 10000) / 10000;
}
