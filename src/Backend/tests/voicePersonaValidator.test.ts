/**
 * S12-06 · R5 — voice-persona output Zod validator tests.
 *
 * Mirror of experimentDesignerValidator.test.ts — the schema lives at
 * `src/services/skills/validators/voicePersona.ts` and is the sole
 * enforcement point for the Dashy-voice + spoken-answer contract the
 * LLM must satisfy. Because the iOS VoiceCardView reads directly off
 * this shape AND the TTS narrator speaks these lines aloud to a child,
 * every crack in the validator is audible as an in-character break:
 * a missed first-person marker means Dashy suddenly sounds like a
 * narrator; a banned voice-of-god phrase ("you got it!") means Dashy
 * suddenly turns into an adult watching the app.
 *
 * Every superRefine check gets at least one failure case so regressions
 * surface immediately. The Dashy-voice gates (first-person markers +
 * banned instructional/praise/correction phrases) are the heart of the
 * single-sourced-truth for her character — if they drift, S12-17's
 * voice-consistency audit will be the second line of defense, but
 * these tests are the first.
 *
 * Invariants covered:
 *   1. promptText contains a first-person marker (I/me/my/we/us/our/let's).
 *   2. promptText does not contain voice-of-god instructions ("you will"
 *      / "you must" / "you should").
 *   3. celebration contains a first-person marker.
 *   4. celebration does not contain voice-of-god praise ("you got" /
 *      "good job").
 *   5. retryHint contains a first-person marker.
 *   6. retryHint does not contain hard corrections ("wrong" /
 *      "incorrect" / "no,").
 *   7. expectedResponses are case-insensitively unique after
 *      whitespace-normalization.
 *   8. phonetics shape is space-separated kebab-syllables.
 *   9. Every text field is substantive (contains ≥1 letter/digit).
 *   - Plus base invariants: strict mode, all field bounds,
 *     expectedResponses cardinality 1–5.
 */
import { describe, it, expect } from 'vitest';
import { voicePersonaOutputSchema } from '@services/skills/validators/voicePersona';

// ---------------------------------------------------------------------------
// Fixture factories — one per difficulty bucket. Each returns a CLEAN,
// valid payload that round-trips through the validator. Individual tests
// then clobber one field to exercise a single invariant.
// ---------------------------------------------------------------------------

type VoiceOutput = {
  title?: string;
  promptText: string;
  expectedResponses: string[];
  celebration: string;
  retryHint: string;
  phonetics?: string;
  conceptSummary: string;
};

function makeEasyOutput(overrides: Partial<VoiceOutput> = {}): VoiceOutput {
  return {
    title: 'Baby cat',
    promptText: "I'm trying to remember what we call a baby cat — can you tell me?",
    expectedResponses: ['kitten', 'a kitten'],
    celebration: "Yes! We've got it!",
    retryHint: "Hmm, let me picture it again — I was thinking of a furry little animal.",
    conceptSummary: 'The word for a baby cat is kitten — the child practiced saying it aloud.',
    ...overrides,
  };
}

function makeMediumOutput(overrides: Partial<VoiceOutput> = {}): VoiceOutput {
  return {
    title: 'Mammal word',
    promptText:
      "I learned a word today for an animal that gives milk to its babies — but I can't remember it. Do you?",
    expectedResponses: ['mammal', 'a mammal', 'mammals'],
    celebration: "Yes! I was hoping you'd remember that word.",
    retryHint: "Hmm, that's not the one I meant — I was picturing a milk-feeder.",
    conceptSummary:
      'A mammal is an animal that feeds milk to its babies — the child named the category aloud.',
    ...overrides,
  };
}

function makeHardOutput(overrides: Partial<VoiceOutput> = {}): VoiceOutput {
  return {
    title: 'How plants eat',
    promptText:
      "I was thinking about how plants make their own food using sunlight and water and air. There's a big science word for that — I'm blanking on it. Can you remind me?",
    expectedResponses: [
      'photosynthesis',
      'fo-to-sin-thesis',
      'plants make food',
      'photo synthesis',
    ],
    celebration: "Yes! I knew you'd have it. Tricky one to say too.",
    retryHint: "Close — not the one I meant. It starts with 'photo-'.",
    phonetics: 'pho-to-syn-the-sis',
    conceptSummary:
      'Photosynthesis is how plants turn sunlight, water, and air into food — the child produced the term aloud from context.',
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Happy paths — one per difficulty.
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — happy paths', () => {
  it('accepts a well-formed easy payload (2 expected responses, short prompt)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(makeEasyOutput());
    if (!parsed.success) {
      // Surface validator errors cleanly when this regression fires.
      console.error(parsed.error.issues);
    }
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed medium payload (3 expected responses, context clue)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(makeMediumOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed hard payload (4 expected responses + phonetics)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(makeHardOutput());
    expect(parsed.success).toBe(true);
  });

  it('exposes the inferred type — expectedResponses + Dashy lines typed correctly', () => {
    const parsed = voicePersonaOutputSchema.parse(makeEasyOutput());
    const first: string = parsed.expectedResponses[0];
    const celebration: string = parsed.celebration;
    expect(typeof first).toBe('string');
    expect(typeof celebration).toBe('string');
  });

  it('accepts a payload without optional title', () => {
    const { title, ...rest } = makeEasyOutput();
    expect(title).toBeDefined(); // sanity check that we dropped a real field
    const parsed = voicePersonaOutputSchema.safeParse(rest);
    expect(parsed.success).toBe(true);
  });

  it('accepts a payload without optional phonetics', () => {
    const parsed = voicePersonaOutputSchema.safeParse(makeMediumOutput());
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 1 — promptText first-person gate
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — first-person gate on promptText', () => {
  it('rejects promptText without any first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        promptText: 'What is the word for a baby cat? Tell the answer aloud.',
      }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /first-person marker/i.test(i.message))).toBe(
        true,
      );
    }
  });

  it('accepts promptText with "I" as the first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: 'I wonder what we call a baby cat — do you know?' }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts promptText with "let\'s" as the first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: "Let's try to remember — what's a baby cat called?" }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts promptText with "we" as the first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: 'What do we call a baby cat again?' }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts promptText with "I\'m" contraction', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: "I'm blanking — what's a baby cat called?" }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 2 — voice-of-god instructional phrases banned in promptText
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — voice-of-god gate on promptText', () => {
  it('rejects promptText containing "you will"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        promptText: "I wonder — you will know this one. What's a baby cat called?",
      }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /you will/i.test(i.message))).toBe(true);
    }
  });

  it('rejects promptText containing "you must"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        promptText: "Let's see — you must know the word for a baby cat.",
      }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects promptText containing "you should"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        promptText: "I wonder — you should be able to tell me what a baby cat is called.",
      }),
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts promptText with benign "you" but no voice-of-god phrase', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        promptText: "I wonder — can you tell me what a baby cat is called?",
      }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 3 — celebration first-person gate
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — first-person gate on celebration', () => {
  it('rejects celebration without any first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: 'That is exactly right! Well said.' }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /first-person marker/i.test(i.message))).toBe(
        true,
      );
    }
  });

  it('accepts celebration with "we" (shared win)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "Yes! We've got it!" }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts celebration with "I" (shared feeling)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "Yes! I knew you'd remember." }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 4 — voice-of-god praise banned in celebration
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — voice-of-god praise gate on celebration', () => {
  it('rejects celebration containing "you got"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "Yes! You got it! I love that!" }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /you got/i.test(i.message))).toBe(true);
    }
  });

  it('rejects celebration containing "good job"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "Good job! We really got there." }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects celebration containing "Good Job" (case-insensitive)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "Oh, Good Job! I'm proud of us." }),
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Invariant 5 — retryHint first-person gate
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — first-person gate on retryHint', () => {
  it('rejects retryHint without any first-person marker', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: 'Try thinking about a furry little animal.' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts retryHint with "let me" (softening)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: "Hmm, let me try again — a furry baby cat is called what?" }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 6 — hard-correction vocabulary banned in retryHint
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — hard-correction gate on retryHint', () => {
  it('rejects retryHint containing "wrong"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: "Hmm, I think that's wrong — let's think again." }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /wrong/i.test(i.message))).toBe(true);
    }
  });

  it('rejects retryHint containing "incorrect"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: "Hmm, that's incorrect — let me think." }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects retryHint containing "no,"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: "No, I was picturing a furry little animal." }),
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts retryHint with soft-reset language', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ retryHint: "Hmm, that's not the one I was picturing — let me think..." }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 7 — expectedResponses case-insensitive uniqueness
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — expectedResponses uniqueness', () => {
  it('rejects duplicate expectedResponses (case-insensitive)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['kitten', 'Kitten'] }),
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(parsed.error.issues.some((i) => /duplicate expectedResponse/i.test(i.message))).toBe(
        true,
      );
    }
  });

  it('rejects duplicate expectedResponses (whitespace-normalized)', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['a kitten', 'a  kitten'] }),
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts distinct but closely-related expectedResponses', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['kitten', 'a kitten', 'baby cat'] }),
    );
    expect(parsed.success).toBe(true);
  });

  it('rejects expectedResponses with more than 5 entries', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['a', 'b', 'c', 'd', 'e', 'f'] }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects empty expectedResponses array', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: [] }),
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Invariant 8 — phonetics shape
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — phonetics kebab-syllable shape', () => {
  it('accepts single kebab-syllable word', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'pho-to-syn-the-sis' }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts space-separated kebab-syllable words', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'warm blood-ed' }),
    );
    expect(parsed.success).toBe(true);
  });

  it('rejects phonetics with uppercase letters', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'Pho-to-syn-the-sis' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects phonetics with digits', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'word1-word2' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects phonetics with trailing hyphen', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'pho-to-' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects phonetics with underscores', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeMediumOutput({ phonetics: 'pho_to_syn' }),
    );
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Invariant 9 — substantive labels (letter-or-digit)
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — substantive text gate', () => {
  it('rejects promptText that is emoji/punctuation-only', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: '🤔🤔🤔🤔🤔🤔🤔🤔🤔' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects expectedResponse that is emoji-only', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['🐱', 'kitten'] }),
    );
    expect(parsed.success).toBe(false);
  });

  it('accepts expectedResponse with a digit (e.g. "8 legs")', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({
        expectedResponses: ['eight', '8', '8 legs'],
      }),
    );
    expect(parsed.success).toBe(true);
  });

  it('accepts labels with unicode letters like "café"', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['café', 'coffee shop'] }),
    );
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Base bounds — strict mode + field length limits
// ---------------------------------------------------------------------------

describe('voicePersonaOutputSchema — base bounds', () => {
  it('rejects unknown fields (strict mode)', () => {
    const parsed = voicePersonaOutputSchema.safeParse({
      ...makeEasyOutput(),
      extraField: 'should be rejected',
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects promptText shorter than 8 chars', () => {
    // "I wonder" is exactly 8 chars — right at the min(8) inclusive
    // boundary — so it's valid length. To prove the lower bound,
    // drop one character.
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: 'I wond?' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects promptText longer than 180 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ promptText: 'I wonder ' + 'x'.repeat(180) }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects celebration shorter than 6 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: "I!" }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects celebration longer than 80 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ celebration: 'I love this! ' + 'x'.repeat(100) }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects conceptSummary longer than 280 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ conceptSummary: 'x'.repeat(300) }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects title shorter than 2 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ title: 'x' }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects title longer than 40 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ title: 'x'.repeat(50) }),
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects expectedResponse entry longer than 30 chars', () => {
    const parsed = voicePersonaOutputSchema.safeParse(
      makeEasyOutput({ expectedResponses: ['x'.repeat(40)] }),
    );
    expect(parsed.success).toBe(false);
  });
});
