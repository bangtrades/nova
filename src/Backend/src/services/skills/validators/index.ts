/**
 * Skill Output Validators — central static registry (Sprint 10 — S10-07).
 *
 * Spike decision #3: every skill *may* ship a per-skill Zod schema that
 * the pipeline orchestrator uses to validate the LLM response before
 * persistence.
 *
 * We keep the schemas in one statically-imported index instead of
 * co-locating them next to each skill's prompt. Reasons:
 *
 *   1. Vitest / tsx / compiled-node all handle static imports the same
 *      way — no dynamic `require()` quirks across harnesses.
 *   2. Content authors still edit the prompt + MD partials under
 *      `defs/<skill>/`; engineers own the Zod contract here.
 *   3. The loader can resolve a validator synchronously with zero
 *      filesystem calls, so boot stays deterministic.
 *
 * Skills without an entry in `SKILL_OUTPUT_SCHEMAS` (like `story-writer`,
 * whose output is free-form prose) simply expose `outputSchema =
 * undefined` on the `Skill` interface. Consumers must tolerate that.
 */
import type { z } from 'zod';
import { quizMakerOutputSchema } from './quizMaker';

/**
 * Name-keyed map. Add new skills alongside their schema file as they
 * come online. The keys MUST match `manifest.name`.
 */
export const SKILL_OUTPUT_SCHEMAS: Record<string, z.ZodTypeAny> = {
  'quiz-maker': quizMakerOutputSchema,
};

/** Re-exports so the rest of the backend can import individual schemas. */
export { quizMakerOutputSchema } from './quizMaker';
