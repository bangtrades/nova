/**
 * Curriculum-architect output schema (Sprint 12 — S12-05).
 *
 * The curriculum-architect skill runs at **Stage 3** of the pipeline
 * (decomposition) — upstream of the per-card skills (story-writer,
 * quiz-maker, experiment-designer). Its JSON response is a full
 * lesson plan:
 *
 *   {
 *     atoms: [
 *       {
 *         id: "atom-1",
 *         name: string,                // 2–60 chars, short noun phrase
 *         description: string,         // 20–280 chars, 1–2 sentences
 *         teachingStrategy: "narrative" | "explanation" | "experiment" |
 *                           "comparison" | "cause_effect" | "quiz" | "voice",
 *         recommendedCardType: "story" | "concept" | "experiment" |
 *                              "quiz" | "voice",
 *         engagementScore: number,     // 0..1
 *         learningValue: number,       // 0..1
 *         prerequisites: string[],     // atom ids (strictly earlier)
 *       },
 *       ...
 *     ];
 *     rationale: string;               // 40–600 chars, lesson-arc narrative
 *   }
 *
 * Validation rules baked in (the invariants an architect must obey):
 *   - atoms.length ∈ [3, 6].
 *   - atoms[i].id === `atom-${i+1}` (strict sequence — no gaps, no
 *     renames). The skillRouter renormalizes upstream if needed, but
 *     the architect should produce clean ids on the first pass.
 *   - atoms[i].teachingStrategy in the seven valid strategies.
 *   - atoms[i].recommendedCardType in the five valid card types.
 *   - strategy / card-type must be *compatible* via the
 *     STRATEGY_TO_CARD_TYPE map — the skill is free to pick either
 *     side and we coerce, but we reject a declared pair that's
 *     nonsensical (e.g. strategy "quiz" claiming cardType "story").
 *   - engagementScore / learningValue ∈ [0, 1].
 *   - prerequisites: every entry matches `atom-N` where N is strictly
 *     less than the current atom's index (no self-reference, no
 *     forward reference, no cycles, no dangling ids).
 *   - Card-type diversity: at least 2 distinct recommendedCardType
 *     values across atoms; at medium (4 atoms) at least 3; at hard
 *     (5+ atoms) at least 3.
 *   - Lesson shape: final atom must be a comprehension check — either
 *     teachingStrategy === "quiz" or teachingStrategy === "voice".
 *   - Voice cards: at most one `voice` atom per lesson (child attention
 *     can't carry two spoken-recall atoms in a single session).
 *   - rationale: 40–600 chars, present and non-empty.
 *
 * The pipeline orchestrator's Stage-3 dispatch (see S12-05 R4) calls
 * `parse()` on the LLM response and, if validation fails, falls back
 * to the legacy heuristic `decomposeConcepts` path — the retry-on-Zod
 * pattern from S10-12-R3 is retained at the skill-router layer but
 * at Stage 3 we also have a permissive legacy fallback so a bad
 * architect response never takes the whole pipeline down.
 */
import { z } from 'zod';

/** Seven valid teaching strategies — matches TeachingStrategy in conceptDecomposer.ts. */
export const VALID_STRATEGIES = [
  'narrative',
  'explanation',
  'experiment',
  'comparison',
  'cause_effect',
  'quiz',
  'voice',
] as const;

/** Five valid card types — matches CardType in cardGenerator.ts. */
export const VALID_CARD_TYPES = ['story', 'concept', 'experiment', 'quiz', 'voice'] as const;

/**
 * Strategy → canonical card type. The architect *may* pick a card type
 * different from this default (e.g. a "comparison" strategy produces a
 * `concept` card either way), but we reject pairings that break the
 * teaching/card-type contract (e.g. a "quiz" strategy claiming a
 * `story` card type).
 */
export const STRATEGY_TO_CARD_TYPE: Record<(typeof VALID_STRATEGIES)[number], (typeof VALID_CARD_TYPES)[number]> = {
  narrative: 'story',
  explanation: 'concept',
  experiment: 'experiment',
  comparison: 'concept',
  cause_effect: 'concept',
  quiz: 'quiz',
  voice: 'voice',
};

/**
 * Compatibility matrix — which card types are permissible for each
 * strategy. A strategy's canonical card type is always permissible;
 * we allow narrative → concept (rare but valid when the "story" is
 * just a vivid scene) to tolerate architect judgment without letting
 * the LLM produce truly incompatible pairings.
 */
const STRATEGY_CARD_TYPE_COMPAT: Record<(typeof VALID_STRATEGIES)[number], ReadonlySet<(typeof VALID_CARD_TYPES)[number]>> = {
  narrative: new Set(['story', 'concept']),
  explanation: new Set(['concept']),
  experiment: new Set(['experiment', 'concept']),
  comparison: new Set(['concept']),
  cause_effect: new Set(['concept']),
  quiz: new Set(['quiz']),
  voice: new Set(['voice']),
};

/** atom id pattern — `atom-N` where N is a positive integer. */
const ATOM_ID_RE = /^atom-([1-9][0-9]*)$/;

const conceptAtomSchema = z
  .object({
    id: z
      .string()
      .trim()
      .regex(ATOM_ID_RE, 'id must match pattern "atom-N" (N = 1..)'),
    name: z
      .string()
      .trim()
      .min(2, 'name must be at least 2 characters')
      .max(60, 'name must be ≤ 60 characters'),
    description: z
      .string()
      .trim()
      .min(20, 'description must be at least 20 characters')
      .max(280, 'description must be ≤ 280 characters'),
    teachingStrategy: z.enum(VALID_STRATEGIES),
    recommendedCardType: z.enum(VALID_CARD_TYPES),
    engagementScore: z
      .number()
      .min(0, 'engagementScore must be ≥ 0')
      .max(1, 'engagementScore must be ≤ 1'),
    learningValue: z
      .number()
      .min(0, 'learningValue must be ≥ 0')
      .max(1, 'learningValue must be ≤ 1'),
    prerequisites: z.array(z.string().trim().regex(ATOM_ID_RE, 'prerequisite must match pattern "atom-N"')),
  })
  .strict();

export const curriculumArchitectOutputSchema = z
  .object({
    atoms: z
      .array(conceptAtomSchema)
      .min(3, 'atoms must have between 3 and 6 entries')
      .max(6, 'atoms must have between 3 and 6 entries'),
    rationale: z
      .string()
      .trim()
      .min(40, 'rationale must be at least 40 characters')
      .max(600, 'rationale must be ≤ 600 characters'),
  })
  .strict()
  .superRefine((val, ctx) => {
    const atoms = val.atoms;
    const n = atoms.length;

    // ----- 1. Strict id sequence — atom-1, atom-2, ..., atom-N ----------
    atoms.forEach((atom, i) => {
      const expectedId = `atom-${i + 1}`;
      if (atom.id !== expectedId) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['atoms', i, 'id'],
          message: `atom id "${atom.id}" at index ${i} must be "${expectedId}" — sequence must be contiguous and in order`,
        });
      }
    });

    // ----- 2. Strategy ↔ card type compatibility ------------------------
    atoms.forEach((atom, i) => {
      const allowed = STRATEGY_CARD_TYPE_COMPAT[atom.teachingStrategy];
      if (!allowed.has(atom.recommendedCardType)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['atoms', i, 'recommendedCardType'],
          message: `strategy "${atom.teachingStrategy}" is incompatible with card type "${atom.recommendedCardType}" — allowed: ${Array.from(allowed).join(', ')}`,
        });
      }
    });

    // ----- 3. Prerequisite DAG — no self-ref, no forward-ref, no dup ----
    const atomIdToIndex = new Map<string, number>();
    atoms.forEach((atom, i) => atomIdToIndex.set(atom.id, i));

    atoms.forEach((atom, i) => {
      const seen = new Set<string>();
      atom.prerequisites.forEach((prereq, pi) => {
        if (prereq === atom.id) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['atoms', i, 'prerequisites', pi],
            message: `atom "${atom.id}" cannot list itself as a prerequisite`,
          });
          return;
        }
        if (seen.has(prereq)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['atoms', i, 'prerequisites', pi],
            message: `prerequisite "${prereq}" is duplicated in atom "${atom.id}"`,
          });
          return;
        }
        seen.add(prereq);

        const prereqIndex = atomIdToIndex.get(prereq);
        if (prereqIndex === undefined) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['atoms', i, 'prerequisites', pi],
            message: `prerequisite "${prereq}" does not reference any atom in this decomposition`,
          });
          return;
        }
        if (prereqIndex >= i) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['atoms', i, 'prerequisites', pi],
            message: `prerequisite "${prereq}" (index ${prereqIndex}) must precede atom "${atom.id}" (index ${i}) — no forward or self references`,
          });
        }
      });
    });

    // ----- 4. Card-type diversity --------------------------------------
    const cardTypeSet = new Set(atoms.map((a) => a.recommendedCardType));
    const minTypes = n >= 4 ? 3 : 2;
    if (cardTypeSet.size < minTypes) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['atoms'],
        message: `card-type diversity too low — ${n} atoms produced ${cardTypeSet.size} distinct card types (${Array.from(cardTypeSet).join(', ')}); need at least ${minTypes}`,
      });
    }

    // ----- 5. Lesson shape — last atom is a comprehension check ---------
    const last = atoms[n - 1]!;
    if (last.teachingStrategy !== 'quiz' && last.teachingStrategy !== 'voice') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['atoms', n - 1, 'teachingStrategy'],
        message: `final atom must be a comprehension check — teachingStrategy must be "quiz" or "voice", got "${last.teachingStrategy}"`,
      });
    }

    // ----- 6. Voice-card ceiling — at most one voice atom per lesson ----
    const voiceCount = atoms.filter((a) => a.teachingStrategy === 'voice').length;
    if (voiceCount > 1) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['atoms'],
        message: `at most one voice atom per lesson — found ${voiceCount}`,
      });
    }
  });

export type CurriculumArchitectOutput = z.infer<typeof curriculumArchitectOutputSchema>;
