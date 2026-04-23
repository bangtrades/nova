/**
 * Experiment-designer output schema (Sprint 12 — S12-04).
 *
 * The experiment-designer skill returns a JSON object shaped like:
 *   {
 *     title: string;            // 2–60 chars, title-case noun phrase
 *     instructions: string;     // 10–200 chars, 1–2 sentences
 *     dragItems: [              // length ∈ {3, 4, 5} matching difficulty
 *       { id: string, label: string },
 *       ...
 *     ];
 *     dropTargets: [            // length ∈ {2, 2, 3} matching difficulty
 *       { id: string, label: string, acceptsItemIds: string[] },
 *       ...
 *     ];
 *     conceptSummary: string;   // 10–280 chars, post-completion debrief
 *     rationalePerTarget: string[];  // parallel to dropTargets
 *   }
 *
 * Validation rules baked in:
 *   - All kebab-case ids match /^[a-z0-9][a-z0-9-]{0,31}$/.
 *   - dragItems ids are unique within the card.
 *   - dropTargets ids are unique within the card.
 *   - The union of every dropTargets[].acceptsItemIds covers every
 *     dragItems[].id EXACTLY ONCE — no orphans, no dual-assignment.
 *   - Every acceptsItemIds entry references an actual dragItems id.
 *   - Every dropTarget has at least one accepted item.
 *   - Labels within dragItems are unique case-insensitively.
 *   - Labels within dropTargets are unique case-insensitively.
 *   - No label is empty, whitespace-only, or emoji/punctuation-only.
 *   - rationalePerTarget is 1:1 with dropTargets.
 *
 * The pipeline orchestrator calls `parse()` on the LLM response and
 * propagates Zod errors up to the retry layer (same retry-on-Zod
 * pattern established in S10-12-R3).
 */
import { z } from 'zod';

/** kebab-case, 1–32 chars, must start with [a-z0-9]. */
const KEBAB_RE = /^[a-z0-9][a-z0-9-]{0,31}$/;

/** A label is "substantive" if it contains at least one letter or digit. */
const LETTER_OR_DIGIT_RE = /[\p{L}\p{N}]/u;

function normalize(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, ' ');
}

function isSubstantiveLabel(s: string): boolean {
  return LETTER_OR_DIGIT_RE.test(s);
}

const dragItemSchema = z
  .object({
    id: z
      .string()
      .trim()
      .regex(KEBAB_RE, 'id must be kebab-case (lowercase letters, digits, hyphens; 1–32 chars)'),
    label: z
      .string()
      .trim()
      .min(1, 'label must be non-empty')
      .max(30, 'label must be ≤ 30 characters'),
  })
  .strict();

const dropTargetSchema = z
  .object({
    id: z
      .string()
      .trim()
      .regex(KEBAB_RE, 'id must be kebab-case (lowercase letters, digits, hyphens; 1–32 chars)'),
    label: z
      .string()
      .trim()
      .min(1, 'label must be non-empty')
      .max(30, 'label must be ≤ 30 characters'),
    acceptsItemIds: z
      .array(
        z
          .string()
          .trim()
          .regex(KEBAB_RE, 'acceptsItemIds entry must be kebab-case'),
      )
      .min(1, 'every drop target must accept at least one drag item'),
  })
  .strict();

export const experimentDesignerOutputSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(2, 'title must be at least 2 characters')
      .max(60, 'title must be ≤ 60 characters'),
    instructions: z
      .string()
      .trim()
      .min(10, 'instructions must be at least 10 characters')
      .max(200, 'instructions must be ≤ 200 characters'),
    dragItems: z
      .array(dragItemSchema)
      .min(3, 'dragItems must have 3, 4, or 5 entries')
      .max(5, 'dragItems must have 3, 4, or 5 entries'),
    dropTargets: z
      .array(dropTargetSchema)
      .min(2, 'dropTargets must have 2 or 3 entries')
      .max(3, 'dropTargets must have 2 or 3 entries'),
    conceptSummary: z
      .string()
      .trim()
      .min(10, 'conceptSummary must be at least 10 characters')
      .max(280, 'conceptSummary must be ≤ 280 characters'),
    rationalePerTarget: z
      .array(z.string().trim().min(1, 'rationale cannot be empty'))
      .min(2)
      .max(3),
  })
  .strict()
  .superRefine((val, ctx) => {
    // ----- 1. Length invariants match the difficulty matrix --------------
    // Accepted pairs: (3,2) easy, (4,2) medium, (5,3) hard.
    const di = val.dragItems.length;
    const dt = val.dropTargets.length;
    const valid = (di === 3 && dt === 2) || (di === 4 && dt === 2) || (di === 5 && dt === 3);
    if (!valid) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['dragItems'],
        message: `dragItems/dropTargets counts must be (3,2) easy, (4,2) medium, or (5,3) hard — got (${di},${dt})`,
      });
    }

    // ----- 2. rationalePerTarget parallel to dropTargets -----------------
    if (val.rationalePerTarget.length !== val.dropTargets.length) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['rationalePerTarget'],
        message: `rationalePerTarget length (${val.rationalePerTarget.length}) must match dropTargets length (${val.dropTargets.length})`,
      });
    }

    // ----- 3. dragItems.id uniqueness ------------------------------------
    const dragSeen = new Map<string, number>();
    val.dragItems.forEach((item, i) => {
      if (dragSeen.has(item.id)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dragItems', i, 'id'],
          message: `duplicate dragItem id "${item.id}" (also at index ${dragSeen.get(item.id)})`,
        });
      } else {
        dragSeen.set(item.id, i);
      }
    });

    // ----- 4. dropTargets.id uniqueness ----------------------------------
    const targetSeen = new Map<string, number>();
    val.dropTargets.forEach((target, i) => {
      if (targetSeen.has(target.id)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dropTargets', i, 'id'],
          message: `duplicate dropTarget id "${target.id}" (also at index ${targetSeen.get(target.id)})`,
        });
      } else {
        targetSeen.set(target.id, i);
      }
    });

    // ----- 5. Referential integrity — every acceptsItemIds entry references
    //         an actual dragItems id, and every dragItem is accepted by
    //         exactly ONE target (no orphans, no dual assignment) ----------
    const dragIdSet = new Set(val.dragItems.map((it) => it.id));
    const acceptedCount = new Map<string, number>(); // dragItem id -> count of targets claiming it

    val.dropTargets.forEach((target, ti) => {
      target.acceptsItemIds.forEach((itemId, ai) => {
        if (!dragIdSet.has(itemId)) {
          ctx.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['dropTargets', ti, 'acceptsItemIds', ai],
            message: `acceptsItemIds entry "${itemId}" does not match any dragItem id`,
          });
        } else {
          acceptedCount.set(itemId, (acceptedCount.get(itemId) ?? 0) + 1);
        }
      });
    });

    // Orphan check — every dragItem must be accepted by at least one target.
    val.dragItems.forEach((item, i) => {
      const count = acceptedCount.get(item.id) ?? 0;
      if (count === 0) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dragItems', i, 'id'],
          message: `dragItem "${item.id}" is orphaned — no dropTarget accepts it`,
        });
      } else if (count > 1) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dragItems', i, 'id'],
          message: `dragItem "${item.id}" is accepted by ${count} dropTargets — must be exactly one`,
        });
      }
    });

    // ----- 6. Label uniqueness within dragItems (case-insensitive) -------
    const dragLabelSeen = new Map<string, number>();
    val.dragItems.forEach((item, i) => {
      const key = normalize(item.label);
      if (dragLabelSeen.has(key)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dragItems', i, 'label'],
          message: `duplicate dragItem label "${item.label}" (matches index ${dragLabelSeen.get(key)})`,
        });
      } else {
        dragLabelSeen.set(key, i);
      }
    });

    // ----- 7. Label uniqueness within dropTargets (case-insensitive) -----
    const targetLabelSeen = new Map<string, number>();
    val.dropTargets.forEach((target, i) => {
      const key = normalize(target.label);
      if (targetLabelSeen.has(key)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dropTargets', i, 'label'],
          message: `duplicate dropTarget label "${target.label}" (matches index ${targetLabelSeen.get(key)})`,
        });
      } else {
        targetLabelSeen.set(key, i);
      }
    });

    // ----- 8. Labels must be substantive (contain at least one letter/digit)
    val.dragItems.forEach((item, i) => {
      if (!isSubstantiveLabel(item.label)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dragItems', i, 'label'],
          message: `dragItem label "${item.label}" is emoji/punctuation-only — must contain a letter or digit`,
        });
      }
    });
    val.dropTargets.forEach((target, i) => {
      if (!isSubstantiveLabel(target.label)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['dropTargets', i, 'label'],
          message: `dropTarget label "${target.label}" is emoji/punctuation-only — must contain a letter or digit`,
        });
      }
    });
  });

export type ExperimentDesignerOutput = z.infer<typeof experimentDesignerOutputSchema>;
