/**
 * Quiz-maker output schema (Sprint 10 — S10-07).
 *
 * The quiz-maker skill returns a JSON object shaped like:
 *   {
 *     question: string;
 *     options: string[];          // 3, 4, or 5 entries (easy/medium/hard)
 *     correctIndex: number;       // 0-based index into `options`
 *     explanation: string;        // short post-answer debrief
 *     rationalePerOption: string[];   // parallel to `options` — each one
 *                                     // explains *why* that distractor is
 *                                     // wrong or the correct answer is right.
 *   }
 *
 * Validation rules baked in:
 *   - question and explanation must be non-empty after trim
 *   - options length ∈ {3, 4, 5}
 *   - correctIndex must index `options`
 *   - rationalePerOption length must match options length
 *   - no "all of the above" / "none of the above" options (case-insensitive)
 *     — the property-based test in spike §acceptance
 *   - no duplicate options (case-insensitive, whitespace-normalized)
 *
 * The pipeline orchestrator (S10-12) calls `parse()` on the LLM response
 * and propagates Zod errors up to the retry layer. A failed validation
 * means we re-prompt with the error summary, up to N retries.
 */
import { z } from 'zod';

/** Trim + case-normalize for duplicate detection and banned-phrase checks. */
function normalize(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, ' ');
}

/** Phrases forbidden anywhere in an option. Case-insensitive substring match. */
const BANNED_OPTION_PHRASES: readonly string[] = [
  'all of the above',
  'none of the above',
  'both of the above',
  'all the above',
  'none of these',
];

export const quizMakerOutputSchema = z
  .object({
    question: z
      .string()
      .trim()
      .min(1, 'question must be non-empty'),
    options: z
      .array(z.string().trim().min(1, 'option cannot be empty'))
      .min(3, 'options must have 3, 4, or 5 entries')
      .max(5, 'options must have 3, 4, or 5 entries'),
    correctIndex: z.number().int().min(0),
    explanation: z
      .string()
      .trim()
      .min(1, 'explanation must be non-empty'),
    rationalePerOption: z
      .array(z.string().trim().min(1, 'rationale cannot be empty'))
      .min(3)
      .max(5),
  })
  .strict()
  .superRefine((val, ctx) => {
    // options length constraint — the schema caps at 3..5 via min/max, but
    // we want the exact {3,4,5} set (no 3 < n < 4, obviously, but making
    // it explicit against future extension).
    const n = val.options.length;
    if (n !== 3 && n !== 4 && n !== 5) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['options'],
        message: `options must have exactly 3, 4, or 5 entries (got ${n})`,
      });
    }

    // correctIndex must be a valid index into options.
    if (val.correctIndex >= val.options.length) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['correctIndex'],
        message: `correctIndex ${val.correctIndex} out of range for ${val.options.length} options`,
      });
    }

    // rationalePerOption must be 1:1 with options.
    if (val.rationalePerOption.length !== val.options.length) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['rationalePerOption'],
        message: `rationalePerOption length (${val.rationalePerOption.length}) must match options length (${val.options.length})`,
      });
    }

    // Banned-phrase check — property-based invariant from the spike.
    const banned: number[] = [];
    val.options.forEach((opt, i) => {
      const n = normalize(opt);
      for (const phrase of BANNED_OPTION_PHRASES) {
        if (n.includes(phrase)) {
          banned.push(i);
          break;
        }
      }
    });
    if (banned.length > 0) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['options'],
        message: `options cannot contain "all of the above" / "none of the above" or variants (offending indices: ${banned.join(', ')})`,
      });
    }

    // Duplicate detection — after normalization.
    const seen = new Map<string, number>();
    val.options.forEach((opt, i) => {
      const key = normalize(opt);
      if (seen.has(key)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['options', i],
          message: `duplicate option at index ${i} (matches index ${seen.get(key)})`,
        });
      } else {
        seen.set(key, i);
      }
    });
  });

export type QuizMakerOutput = z.infer<typeof quizMakerOutputSchema>;
