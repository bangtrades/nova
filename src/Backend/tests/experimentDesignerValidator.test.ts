/**
 * S12-04 · R5 — experiment-designer output Zod validator tests.
 *
 * Mirror of quizMakerValidator.test.ts — the schema lives at
 * `src/services/skills/validators/experimentDesigner.ts` and is the sole
 * enforcement point for the drag-drop contract the LLM must satisfy.
 * Because the iOS `ExperimentCardView` renders directly off this shape,
 * any crack in the validator is visible UI glitch — mis-matched
 * acceptsItemIds strand items on the play surface, duplicate ids break
 * drag state, over-long labels clip on a child's thumb tile.
 *
 * Every superRefine check in the schema gets at least one failure case
 * here so regressions surface immediately.
 *
 * Invariants covered:
 *   1. Difficulty-matrix counts: (3,2) easy, (4,2) medium, (5,3) hard.
 *   2. rationalePerTarget is 1:1 with dropTargets.
 *   3. dragItems.id is unique within a card.
 *   4. dropTargets.id is unique within a card.
 *   5. Referential integrity — every acceptsItemIds entry references
 *      an actual dragItem, and every dragItem is accepted by exactly
 *      one target (no orphan, no dual-assignment).
 *   6. dragItem labels are unique case-insensitively.
 *   7. dropTarget labels are unique case-insensitively.
 *   8. No label is emoji-only or whitespace-only.
 *   - Plus base invariants: strict mode, title bounds, kebab-case ids,
 *     label bounds, acceptsItemIds non-empty.
 */
import { describe, it, expect } from 'vitest';
import { experimentDesignerOutputSchema } from '@services/skills/validators/experimentDesigner';

// ---------------------------------------------------------------------------
// Fixture factories — one per difficulty bucket. Each returns a
// CLEAN, valid payload that round-trips through the validator. Individual
// tests then clobber one field to exercise a single invariant.
// ---------------------------------------------------------------------------

type ExperimentOutput = {
  title: string;
  instructions: string;
  dragItems: Array<{ id: string; label: string }>;
  dropTargets: Array<{ id: string; label: string; acceptsItemIds: string[] }>;
  conceptSummary: string;
  rationalePerTarget: string[];
};

function makeEasyOutput(overrides: Partial<ExperimentOutput> = {}): ExperimentOutput {
  return {
    title: 'Sort by Floating',
    instructions: 'Drag each object onto the bin that matches what it does in water.',
    dragItems: [
      { id: 'cork', label: 'Cork' },
      { id: 'rock', label: 'Rock' },
      { id: 'apple', label: 'Apple' },
    ],
    dropTargets: [
      { id: 'floats', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
      { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
    ],
    conceptSummary:
      'Objects less dense than water float; denser objects sink. Shape and trapped air matter too.',
    rationalePerTarget: [
      'Cork and apples are lighter than the water they push out, so they ride on top.',
      'A rock is denser than water, so it falls through and settles at the bottom.',
    ],
    ...overrides,
  };
}

function makeMediumOutput(overrides: Partial<ExperimentOutput> = {}): ExperimentOutput {
  return {
    title: 'Living or Not Living',
    instructions: 'Drop each thing into living or not-living. Tricky ones test your rules.',
    dragItems: [
      { id: 'dog', label: 'Dog' },
      { id: 'tree', label: 'Tree' },
      { id: 'rock', label: 'Rock' },
      { id: 'robot', label: 'Robot' },
    ],
    dropTargets: [
      { id: 'living', label: 'Living', acceptsItemIds: ['dog', 'tree'] },
      { id: 'not-living', label: 'Not living', acceptsItemIds: ['rock', 'robot'] },
    ],
    conceptSummary:
      'Living things grow, use energy, and can reproduce. Robots move and respond, but they never grow on their own.',
    rationalePerTarget: [
      'Dogs and trees take in energy, grow, and reproduce — the defining living marks.',
      'Rocks never grew, and robots only follow programs; neither shows the living pattern.',
    ],
    ...overrides,
  };
}

function makeHardOutput(overrides: Partial<ExperimentOutput> = {}): ExperimentOutput {
  return {
    title: 'Sort by State of Matter',
    instructions:
      'Drop each item into solid, liquid, or gas. Some sit on the boundary — think about what the particles are doing.',
    dragItems: [
      { id: 'ice-cube', label: 'Ice cube' },
      { id: 'milk', label: 'Milk' },
      { id: 'steam', label: 'Steam' },
      { id: 'sand', label: 'Sand' },
      { id: 'helium', label: 'Helium' },
    ],
    dropTargets: [
      { id: 'solid', label: 'Solid', acceptsItemIds: ['ice-cube', 'sand'] },
      { id: 'liquid', label: 'Liquid', acceptsItemIds: ['milk'] },
      { id: 'gas', label: 'Gas', acceptsItemIds: ['steam', 'helium'] },
    ],
    conceptSummary:
      'Solids hold shape, liquids flow and fill the bottom of a container, gases spread everywhere. The same water can be all three.',
    rationalePerTarget: [
      'Ice and sand hold their shape — the particles are locked in place.',
      'Milk flows to fit the container and has a flat top — liquid particles slide past each other.',
      'Steam and helium fill any room they can reach — gas particles move freely in all directions.',
    ],
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Happy paths — one per difficulty.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — happy paths', () => {
  it('accepts a well-formed easy (3,2) payload', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(makeEasyOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed medium (4,2) payload', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(makeMediumOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed hard (5,3) payload', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(makeHardOutput());
    expect(parsed.success).toBe(true);
  });

  it('exposes the inferred type — dragItems + dropTargets typed correctly', () => {
    const parsed = experimentDesignerOutputSchema.parse(makeEasyOutput());
    // A small type-level check — if `dragItems[0].id` isn't `string`, tsc fails.
    const id: string = parsed.dragItems[0].id;
    const accepts: string[] = parsed.dropTargets[0].acceptsItemIds;
    expect(typeof id).toBe('string');
    expect(Array.isArray(accepts)).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Difficulty-matrix invariant — (3,2) easy, (4,2) medium, (5,3) hard only.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — difficulty-matrix invariant', () => {
  it('rejects (3,3) — easy count with hard bin count', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
          { id: 'maybe', label: 'Maybe', acceptsItemIds: ['apple'] },
        ],
        rationalePerTarget: ['a', 'b', 'c'],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('counts must be')
        )
      ).toBe(true);
    }
  });

  it('rejects (4,3) — medium items with hard bins', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeMediumOutput({
        dropTargets: [
          { id: 'a', label: 'A', acceptsItemIds: ['dog'] },
          { id: 'b', label: 'B', acceptsItemIds: ['tree'] },
          { id: 'c', label: 'C', acceptsItemIds: ['rock', 'robot'] },
        ],
        rationalePerTarget: ['r1', 'r2', 'r3'],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects 2 drag items (below the minimum floor)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork', label: 'Cork' },
          { id: 'rock', label: 'Rock' },
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects 6 drag items (above the maximum ceiling)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeHardOutput({
        dragItems: [
          ...makeHardOutput().dragItems,
          { id: 'oil', label: 'Oil' },
        ],
        dropTargets: [
          { id: 'solid', label: 'Solid', acceptsItemIds: ['ice-cube', 'sand'] },
          { id: 'liquid', label: 'Liquid', acceptsItemIds: ['milk', 'oil'] },
          { id: 'gas', label: 'Gas', acceptsItemIds: ['steam', 'helium'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// rationalePerTarget parallel-to-dropTargets invariant.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — rationalePerTarget parity', () => {
  it('rejects rationalePerTarget length ≠ dropTargets length', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        rationalePerTarget: ['only one rationale'],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) => i.path.includes('rationalePerTarget'))
      ).toBe(true);
    }
  });

  it('rejects empty rationale string', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        rationalePerTarget: ['ok', ''],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Duplicate-id invariants — drag items and drop targets both rejected.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — id uniqueness', () => {
  it('rejects duplicate dragItem ids', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork', label: 'Cork' },
          { id: 'cork', label: 'Cork Two' },
          { id: 'rock', label: 'Rock' },
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) => i.message.toLowerCase().includes('duplicate'))
      ).toBe(true);
    }
  });

  it('rejects duplicate dropTarget ids', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'bin', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
          { id: 'bin', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// kebab-case id regex.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — id format (kebab-case)', () => {
  it('rejects UPPERCASE ids', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'Cork', label: 'Cork' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects ids with spaces', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'ice cube', label: 'Ice cube' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects ids starting with a hyphen', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: '-cork', label: 'Cork' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects ids over 32 characters', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'a'.repeat(33), label: 'Cork' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Referential integrity — every item belongs to exactly one target.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — referential integrity', () => {
  it('rejects orphan drag items (no target accepts them)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        // apple is in dragItems but NO target accepts it.
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) => i.message.toLowerCase().includes('orphan'))
      ).toBe(true);
    }
  });

  it('rejects dual-assignment (item accepted by two targets)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
          // rock is fine, but apple already claimed by "floats"
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock', 'apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          /accepted by \d+ dropTargets/.test(i.message)
        )
      ).toBe(true);
    }
  });

  it('rejects acceptsItemIds referencing a non-existent dragItem id', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork', 'apple'] },
          // 'stone' is not in dragItems — only 'rock' is.
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['stone'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('does not match any dragitem')
        )
      ).toBe(true);
    }
  });

  it('rejects empty acceptsItemIds (target with no accepted items)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: [] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['cork', 'rock', 'apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Label uniqueness — case-insensitive, for both drag items and drop targets.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — label uniqueness', () => {
  it('rejects duplicate dragItem labels (case-insensitive)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork-1', label: 'Cork' },
          { id: 'cork-2', label: 'cork' },
          { id: 'apple', label: 'Apple' },
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork-1', 'cork-2'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('duplicate dragitem label')
        )
      ).toBe(true);
    }
  });

  it('rejects duplicate dropTarget labels (case-insensitive)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'a', label: 'Floats', acceptsItemIds: ['cork'] },
          { id: 'b', label: 'floats', acceptsItemIds: ['rock', 'apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects whitespace-only label differences as duplicates', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork-1', label: 'Cork' },
          { id: 'cork-2', label: '  cork  ' },
          { id: 'apple', label: 'Apple' },
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['cork-1', 'cork-2'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Substantive-label invariant — emoji / punctuation only rejected.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — substantive labels', () => {
  it('rejects emoji-only dragItem label', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork', label: '🍾' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('emoji')
        )
      ).toBe(true);
    }
  });

  it('rejects punctuation-only dropTarget label', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dropTargets: [
          { id: 'a', label: '...', acceptsItemIds: ['cork'] },
          { id: 'b', label: 'Sinks', acceptsItemIds: ['rock', 'apple'] },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts label with a digit (e.g., "1st step")', () => {
    // Note: we override BOTH dragItems and dropTargets together because the
    // default fixture's dropTargets reference "cork", which disappears when
    // we swap in the digit-bearing item. Keep referential integrity intact
    // so the ONLY thing this test exercises is the substantive-label path.
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'first', label: '1st' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
        dropTargets: [
          { id: 'floats', label: 'Floats', acceptsItemIds: ['first', 'apple'] },
          { id: 'sinks', label: 'Sinks', acceptsItemIds: ['rock'] },
        ],
      })
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Base-level invariants — title bounds, label bounds, strict mode.
// ---------------------------------------------------------------------------

describe('experimentDesignerOutputSchema — base invariants', () => {
  it('rejects title shorter than 2 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ title: 'A' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects title longer than 60 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ title: 'T'.repeat(61) })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects instructions shorter than 10 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ instructions: 'too short' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects instructions longer than 200 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ instructions: 'x'.repeat(201) })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects label longer than 30 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          { id: 'cork', label: 'Cork that is way too long to fit on a child thumb chip' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects conceptSummary shorter than 10 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ conceptSummary: 'nope' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects conceptSummary longer than 280 chars', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({ conceptSummary: 'c'.repeat(281) })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects extra top-level fields (strict mode)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse({
      ...makeEasyOutput(),
      mischief: 'extra-key',
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects extra fields inside a dragItem (strict nested)', () => {
    const parsed = experimentDesignerOutputSchema.safeParse(
      makeEasyOutput({
        dragItems: [
          // @ts-expect-error — intentionally extra field for strict test
          { id: 'cork', label: 'Cork', emoji: '🍾' },
          { id: 'rock', label: 'Rock' },
          { id: 'apple', label: 'Apple' },
        ],
      })
    );
    expect(parsed.success).toBe(false);
  });
});
