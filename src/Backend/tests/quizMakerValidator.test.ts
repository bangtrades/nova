/**
 * S10-07 — quiz-maker output Zod validator tests.
 *
 * The schema lives in `src/services/skills/validators/quizMaker.ts` and is
 * the sole enforcement point for the format contract the LLM must
 * satisfy. If it accepts malformed output, bad quizzes reach the child;
 * if it rejects valid output, the retry loop burns LLM credits. So we
 * exercise both the happy paths and the exact invariants from the
 * S10-06-07 design spike.
 *
 * Invariants covered:
 *   - options length ∈ {3, 4, 5}
 *   - correctIndex is a valid index
 *   - rationalePerOption is 1:1 with options
 *   - no "all of the above" / "none of the above" variants
 *   - no duplicate options (case-insensitive)
 *   - strict mode — no extra top-level fields
 */
import { describe, it, expect } from 'vitest';
import { quizMakerOutputSchema } from '@services/skills/validators/quizMaker';

function makeValidOutput(
  overrides: Partial<{
    question: string;
    options: string[];
    correctIndex: number;
    explanation: string;
    rationalePerOption: string[];
  }> = {}
) {
  return {
    question: 'When Maya let go of the balloon, what did it do?',
    options: ['Floated up', 'Fell down', 'Rolled away'],
    correctIndex: 0,
    explanation:
      'Balloons filled with helium are lighter than air, so they rise when released.',
    rationalePerOption: [
      'Correct — helium is lighter than air.',
      'Gravity pulls heavy things down, but helium is lighter than air.',
      'Balloons do not roll — they move up or drift sideways.',
    ],
    ...overrides,
  };
}

describe('quizMakerOutputSchema — happy paths', () => {
  it('accepts a well-formed easy (3-option) quiz', () => {
    const parsed = quizMakerOutputSchema.safeParse(makeValidOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed medium (4-option) quiz', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['Floated up', 'Fell down', 'Rolled away', 'Split in half'],
        rationalePerOption: [
          'Correct — helium is lighter than air.',
          'Heavy things fall, but this balloon is lighter than air.',
          'Balloons do not roll — they move up or drift.',
          'A balloon does not split on its own when released.',
        ],
      })
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed hard (5-option) quiz', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: [
          'Floated up',
          'Fell down',
          'Rolled away',
          'Split in half',
          'Stayed still in the air',
        ],
        rationalePerOption: [
          'Correct — helium is lighter than air.',
          'Heavy things fall, but this balloon is lighter than air.',
          'Balloons do not roll — they move up or drift.',
          'A balloon does not split on its own when released.',
          'Nothing stays perfectly still — air pushes up or gravity pulls down.',
        ],
      })
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts correctIndex pointing at the last option', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        correctIndex: 2,
        options: ['Fell down', 'Rolled away', 'Floated up'],
        rationalePerOption: [
          'Heavy things fall, but this balloon is lighter than air.',
          'Balloons do not roll — they move up or drift.',
          'Correct — helium is lighter than air.',
        ],
      })
    );
    expect(parsed.success).toBe(true);
  });
});

describe('quizMakerOutputSchema — option-count invariant', () => {
  it('rejects 2 options (too few)', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['Floated up', 'Fell down'],
        rationalePerOption: ['a', 'b'],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects 6 options (too many)', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['a', 'b', 'c', 'd', 'e', 'f'],
        rationalePerOption: ['1', '2', '3', '4', '5', '6'],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

describe('quizMakerOutputSchema — correctIndex invariant', () => {
  it('rejects correctIndex out of range', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({ correctIndex: 5 })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => i.path.includes('correctIndex'))).toBe(
        true
      );
    }
  });

  it('rejects negative correctIndex', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({ correctIndex: -1 })
    );
    expect(parsed.success).toBe(false);
  });
});

describe('quizMakerOutputSchema — rationalePerOption invariant', () => {
  it('rejects mismatched rationale length', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        rationalePerOption: ['only', 'two'],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects empty rationale strings', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        rationalePerOption: ['ok', '', 'ok'],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

describe('quizMakerOutputSchema — banned-phrase invariant (the spike property)', () => {
  const BANNED_PHRASES = [
    'All of the above',
    'None of the above',
    'all of the above',
    'Both of the above',
    'NONE OF THE ABOVE',
    'all the above',
    'None of these',
  ];

  for (const phrase of BANNED_PHRASES) {
    it(`rejects options containing "${phrase}"`, () => {
      const parsed = quizMakerOutputSchema.safeParse(
        makeValidOutput({
          options: ['Floated up', 'Fell down', phrase],
          rationalePerOption: ['1', '2', '3'],
        })
      );
      expect(parsed.success).toBe(false);
      if (!parsed.success) {
        expect(
          parsed.error.issues.some((i) =>
            i.message.toLowerCase().includes('all of the above')
          )
        ).toBe(true);
      }
    });
  }

  it('accepts options that merely mention "above" in a benign context', () => {
    // "Above the clouds" is a legitimate concrete option — not banned.
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['Above the clouds', 'Below the clouds', 'Inside the clouds'],
        rationalePerOption: ['a', 'b', 'c'],
      })
    );
    expect(parsed.success).toBe(true);
  });
});

describe('quizMakerOutputSchema — duplicate detection', () => {
  it('rejects exact-match duplicate options', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['Floated up', 'Floated up', 'Rolled away'],
        rationalePerOption: ['1', '2', '3'],
      })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects whitespace/case-only duplicate options', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({
        options: ['Floated up', 'floated  up', 'Rolled away'],
        rationalePerOption: ['1', '2', '3'],
      })
    );
    expect(parsed.success).toBe(false);
  });
});

describe('quizMakerOutputSchema — strict / base invariants', () => {
  it('rejects empty question', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({ question: '  ' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects empty explanation', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({ explanation: '' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects extra top-level fields (.strict)', () => {
    const parsed = quizMakerOutputSchema.safeParse({
      ...makeValidOutput(),
      mischief: 'extra',
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects non-integer correctIndex', () => {
    const parsed = quizMakerOutputSchema.safeParse(
      makeValidOutput({ correctIndex: 1.5 })
    );
    expect(parsed.success).toBe(false);
  });
});
