/**
 * Skill Engine — shared types (Sprint 10 — S10-06 / S10-07 / S10-12)
 *
 * Defines the contract between:
 *   - `registry.ts` / `loader.ts`   (boot-time machinery)
 *   - individual skills in `defs/*` (content-owned MD + manifest.json)
 *   - `buildChildContext()`          (assembles ChildContext — S10-12)
 *   - the Grand Architect pipeline   (consumes `buildPrompt(...)`)
 *
 * Keeping the types here — not inside registry.ts — avoids a circular
 * import once the Dev Console routes also need to introspect skills.
 *
 * Design decisions (locked in docs/design-spikes/S10-06-07-skill-loader.md):
 *   1. Handlebars.js for templating (triple-stache disabled)
 *   2. Sliding-scale effective age via progressionDelta ∈ [-1.5, +1.5]
 *   3. Per-skill Zod output validators
 *   4. Eager boot-time loader
 *   5. Manifest modelHint is advisory; costRouter has final authority
 *   6. interestTopics extracted from parentGoals at guidance-save time
 */
import { z } from 'zod';
import type {
  ConceptType,
  LearningModality,
  RankedCardTypeRec,
} from './teachingStrategy';
import type { RankedCardType } from '@services/engagement/engagementProfiler';
import type { ParentGuidanceView } from '@services/guidance/parentGuidance';
import type { SessionContext } from '@services/context/sessionContext';

// ---------------------------------------------------------------------------
// Manifest (the only JSON file per skill; everything else is Markdown)
// ---------------------------------------------------------------------------

/**
 * Zod schema for `defs/<name>/manifest.json`.
 *
 * The loader validates every manifest at boot. A typo here surfaces
 * immediately as a startup failure, not at first-invocation time — which
 * is the entire point of the eager loader decision (#4).
 */
export const SkillManifestSchema = z
  .object({
    /** Skill name — must match the directory name under defs/. */
    name: z.string().min(1),
    /** Semver-like string — used to invalidate downstream caches. */
    version: z.string().min(1),
    /** Human-readable one-liner for the Dev Console list endpoint. */
    description: z.string().min(1),
    /**
     * Which model tier the skill is *designed* for. Advisory — costRouter
     * has final authority (cold-start overrides, daily caps, A/B routing).
     */
    modelHint: z.enum(['flash', 'pro']),
    /** Sampling temperature the skill author thinks is appropriate. */
    temperatureHint: z.number().min(0).max(1),
    /**
     * Inputs the skill expects *on top of* ChildContext. Validated by
     * `registry.invoke()` before the skill sees them — the skill itself
     * can treat them as already-sanitized.
     */
    inputs: z
      .object({
        requires: z.array(z.string()).default([]),
        optional: z.array(z.string()).default([]),
      })
      .default({ requires: [], optional: [] }),
    /** Which age profile files live under `age-profiles/`. */
    ageProfiles: z.array(z.number().int().min(3).max(14)).optional(),
    /** Which difficulty-curve files live under `difficulty-curves/`. */
    difficulties: z.array(z.enum(['easy', 'medium', 'hard'])).optional(),
    /**
     * Which ConceptTypes this skill claims to handle. Used by the S10-12
     * router so we don't invoke story-writer on a lookup-style concept.
     * Empty = "any" (wildcard).
     */
    handlesConceptTypes: z
      .array(
        z.enum([
          'vocabulary',
          'abstract',
          'process',
          'comparison',
          'causeEffect',
          'factual',
        ])
      )
      .default([]),
  })
  .strict();

export type SkillManifest = z.infer<typeof SkillManifestSchema>;

// ---------------------------------------------------------------------------
// ChildContext — single input every skill consumes
// ---------------------------------------------------------------------------

/**
 * Minimal mastery summary skills care about. The pipeline integrator
 * (S10-12) builds this from `MasteryTracker` output.
 */
export interface MasteryEffective {
  averageScore: number;  // 0..1 — rolling mean confidence
  totalAttempts: number; // sum across all concepts in window
}

/**
 * Compressed engagement summary skills care about. Broader than the full
 * profile — just the signals progression uses.
 */
export interface EngagementSummary {
  recentQuizWinRate: number; // 0..1 — correct/total in last 14d
  preferredCardTypes: RankedCardType[]; // from S10-03
}

/**
 * Counts of session-event telemetry in a rolling window (typically 7d).
 * Sourced from SessionEvent rows (S10-05).
 */
export interface SessionEventCounts {
  flow: number;
  frustration: number;
  abandon: number;
}

/**
 * The single context object every skill consumes. Assembled by
 * `buildChildContext()` in S10-12 from a single DB read pass.
 *
 * Skills that don't need a field simply ignore it. Never mutate — caller
 * owns the reference.
 */
export interface ChildContext {
  childId: string;
  /** Chronological age in whole years — from birthDate. Used for legal / content gates. */
  ageYears: number;
  /** Continuous effective age = ageYears + progressionDelta. Used for profile selection. */
  effectiveAgeYears: number;
  /** Signed slide from chronological age, clamped to [-1.5, +1.5]. See progression.ts. */
  progressionDelta: number;
  /** S10-04 output — parent's stated goals, avoid list, offset, content boundaries. */
  parentGuidance: ParentGuidanceView;
  /** S10-05 output — timezone-aware session state. */
  sessionContext: SessionContext;
  /** S10-03 output. Optional for cold-start (no history). */
  engagement?: EngagementSummary;
  /** Aggregated mastery window. Optional for cold-start. */
  mastery?: MasteryEffective;
  /** Session-event counts in a rolling 7d window. Optional. */
  recentSessionEvents?: SessionEventCounts;
  /**
   * Extracted interest topics from `ParentGuidance.parentGoals` free text
   * (decision #6). Optional — empty during cold-start.
   */
  interestTopics?: string[];
  /** Teaching strategy view — what card types to try, in what order. */
  teachingStrategy: {
    conceptType: ConceptType;
    modality: LearningModality;
    rankedCardTypes: RankedCardTypeRec[];
  };
  /** Parent-driven difficulty nudge -2..+2. Passed through to skills. */
  difficultyOffset?: number;
}

// ---------------------------------------------------------------------------
// Skill contract
// ---------------------------------------------------------------------------

/**
 * Metadata the registry emits with every prompt it builds. Preserves the
 * observability story (what age profile was actually picked? which
 * difficulty bucket? which temperature hint?) without forcing the caller
 * to re-derive from the manifest.
 */
export interface SkillPromptMeta {
  skillName: string;
  version: string;
  /** The anchor age profile selected by `selectAgeProfile(effectiveAgeYears)`. */
  ageProfileUsed?: number;
  /** The difficulty curve selected by the `difficultyOffset` mapping. */
  difficultyUsed?: 'easy' | 'medium' | 'hard';
  /** Echoed from manifest — costRouter may still override. */
  modelHint: 'flash' | 'pro';
  /** Echoed from manifest — LLM caller may still override. */
  temperatureHint: number;
  /** Echoed for observability. Lets the Dev Console display the modifier chosen. */
  progressionDelta: number;
  /** Echoed effective age for ranker traces / JSON dumps. */
  effectiveAgeYears: number;
}

/**
 * The registry-facing skill object. Produced by the loader; consumed by
 * the pipeline orchestrator. Pure — does NOT call the LLM.
 *
 * `outputSchema` is populated when the skill ships a co-located
 * `validators.ts` (or `.js`) exporting a default Zod schema (spike
 * decision #3). The pipeline orchestrator (S10-12) uses it to validate
 * the LLM response before DB persistence; skills without a validator
 * fall through to a permissive downstream parse.
 */
export interface Skill {
  readonly manifest: SkillManifest;
  /** Optional per-skill Zod schema for LLM-output validation. */
  readonly outputSchema?: z.ZodTypeAny;
  buildPrompt(input: BuildPromptInput): BuildPromptOutput;
}

export interface BuildPromptInput {
  ctx: ChildContext;
  inputs: Record<string, unknown>;
}

export interface BuildPromptOutput {
  system: string;
  user: string;
  meta: SkillPromptMeta;
}

/**
 * Registry surface area exposed to the rest of the backend.
 *
 * `load()` is called once at server boot. `reload()` is only used by the
 * Dev Console hot-reload endpoint.
 */
export interface SkillRegistry {
  load(): Promise<void>;
  isLoaded(): boolean;
  list(): Skill[];
  get(name: string): Skill;
  has(name: string): boolean;
  reload(name?: string): Promise<void>;
}

// ---------------------------------------------------------------------------
// Built-in mapping: ranked card type → skill name
// ---------------------------------------------------------------------------

/**
 * The pipeline orchestrator (S10-12) walks the ranked list produced by
 * `rankCardTypesFor(...)` and invokes the matching skill. Maintained here
 * so card types never hard-code skill names directly.
 *
 * `experiment`, `voice`, and `concept` become wired in S10-08 / S10-09 /
 * S10-10. The map is allowed to be partial until then.
 */
export const CARD_TYPE_TO_SKILL: Partial<
  Record<'story' | 'concept' | 'experiment' | 'quiz' | 'voice', string>
> = {
  story: 'story-writer',
  // S12-10 — concept atoms route through story-writer too. The skill
  // produces free-form prose which is exactly what a concept card
  // needs — an explanation. `buildCardFromSkillOutput` branches on
  // the atom's `recommendedCardType` to emit `type: 'concept'` with
  // the prose in `content.explanation` (where ConceptCardView reads
  // from) instead of the default story shape. Deferred: a purpose-
  // built `concept-explainer` skill is out of scope — when it lands
  // in S13+, just point this entry at that skill's name.
  concept: 'story-writer',
  quiz: 'quiz-maker',
  experiment: 'experiment-designer',
  voice: 'voice-persona',
};
