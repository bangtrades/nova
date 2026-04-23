/**
 * Voice-persona output schema (Sprint 12 — S12-06).
 *
 * The voice-persona skill returns a JSON object shaped like:
 *   {
 *     title?: string;                  // 2–40 chars, optional card heading
 *     promptText: string;              // 8–180 chars, Dashy's spoken question
 *     expectedResponses: string[];     // 1–5 entries, each 1–30 chars
 *     celebration: string;             // 6–80 chars, Dashy's shared-win line
 *     retryHint: string;               // 6–80 chars, Dashy's soft-reset line
 *     phonetics?: string;              // optional space-separated kebab-syllables
 *     conceptSummary: string;          // 10–280 chars, post-card debrief
 *   }
 *
 * Invariants baked in by `.superRefine(...)`:
 *   1. `promptText`, `celebration`, and `retryHint` MUST contain a
 *      first-person marker — one of {I, me, my, we, us, our, let's}.
 *      Dashy is a character, not a narrator; every line must sound
 *      like her speaking, not a voice-of-god prompt.
 *   2. `promptText` MUST NOT contain voice-of-god instructional
 *      phrases: "you will", "you must", "you should".
 *   3. `celebration` MUST NOT contain voice-of-god praise: "you got"
 *      or "good job". Dashy shares the win; she doesn't grant it.
 *   4. `retryHint` MUST NOT contain hard-correction vocabulary:
 *      "wrong", "incorrect", "no,". Missed voice cards need a soft
 *      reset, never a reprimand.
 *   5. `expectedResponses` are case-insensitively unique after
 *      whitespace-normalization — "kitten" and "Kitten" collapse to
 *      the same key; "a kitten" and "a  kitten" collapse too.
 *   6. `phonetics`, if present, must be a space-separated sequence
 *      of kebab-syllable words (`/^[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*$/`).
 *      This is the shape Dashy's TTS voice expects for clean
 *      articulation of multi-syllable technical words.
 *   7. Every text field must be **substantive** — contain at least
 *      one letter or digit. Emoji-only, punctuation-only, and
 *      whitespace-only strings are rejected.
 *
 * The pipeline orchestrator calls `parse()` on the LLM response and
 * propagates Zod errors up to the retry layer (same retry-on-Zod
 * pattern established in S10-12-R3).
 *
 * ----------------------------------------------------------------------
 * DECISION — difficulty-specific length bounds are NOT enforced here.
 * The difficulty curves (easy ≤80 / medium ≤110 / hard ≤180) are
 * enforced at the *prompt* layer by the per-difficulty Handlebars
 * partial. This validator uses the widest (hard) bound as its hard
 * ceiling. Rationale: the validator sees only the skill's JSON output,
 * not the ChildContext's difficulty — adding a per-difficulty-aware
 * check would require threading `meta.difficultyUsed` into the Zod
 * call site, which breaks the `.parse(json)` contract every other
 * validator in this family uses. Same decision as experiment-designer.
 */
import { z } from 'zod';

/**
 * A label is "substantive" if it contains at least one Unicode letter
 * or digit. Accepts "kitten", "1st", "café", "rocks 🪨"; rejects
 * "🍾", "...", whitespace-only, emoji-only.
 */
const LETTER_OR_DIGIT_RE = /[\p{L}\p{N}]/u;

/**
 * Space-separated kebab-syllable words — the shape Dashy's TTS voice
 * expects: "pho-to-syn-the-sis", "car-a-van", "e-va-po-ra-tion",
 * or multi-word: "warm blood-ed" / "pho-to syn-the-sis".
 */
const PHONETICS_RE = /^[a-z]+(-[a-z]+)*( [a-z]+(-[a-z]+)*)*$/;

/**
 * First-person markers — at least one must appear in every line Dashy
 * speaks. Word-boundary matching so "*information*" doesn't trip on
 * the "i" prefix.
 */
const FIRST_PERSON_PATTERNS: RegExp[] = [
  /\bI\b/, // case-sensitive — standalone "I" pronoun
  /\bme\b/i,
  /\bmy\b/i,
  /\bwe\b/i,
  /\bus\b/i,
  /\bour\b/i,
  /\blet'?s\b/i, // "let's" with or without apostrophe
  /\bi'?m\b/i, // "I'm" / "im" contraction
  /\bi'?ll\b/i, // "I'll"
  /\bi'?ve\b/i, // "I've"
  /\bmine\b/i,
];

function hasFirstPerson(s: string): boolean {
  return FIRST_PERSON_PATTERNS.some((re) => re.test(s));
}

function isSubstantive(s: string): boolean {
  return LETTER_OR_DIGIT_RE.test(s);
}

function normalize(s: string): string {
  return s.trim().toLowerCase().replace(/\s+/g, ' ');
}

/**
 * Case-insensitive substring match (after lowercasing both sides).
 * Used for the banned-phrase checks.
 */
function containsCI(haystack: string, needle: string): boolean {
  return haystack.toLowerCase().includes(needle.toLowerCase());
}

export const voicePersonaOutputSchema = z
  .object({
    title: z
      .string()
      .trim()
      .min(2, 'title must be at least 2 characters')
      .max(40, 'title must be ≤ 40 characters')
      .optional(),
    promptText: z
      .string()
      .trim()
      .min(8, 'promptText must be at least 8 characters')
      .max(180, 'promptText must be ≤ 180 characters'),
    expectedResponses: z
      .array(
        z
          .string()
          .trim()
          .min(1, 'expectedResponse must be non-empty')
          .max(30, 'expectedResponse must be ≤ 30 characters'),
      )
      .min(1, 'expectedResponses must have at least 1 entry')
      .max(5, 'expectedResponses must have at most 5 entries'),
    celebration: z
      .string()
      .trim()
      .min(6, 'celebration must be at least 6 characters')
      .max(80, 'celebration must be ≤ 80 characters'),
    retryHint: z
      .string()
      .trim()
      .min(6, 'retryHint must be at least 6 characters')
      .max(80, 'retryHint must be ≤ 80 characters'),
    phonetics: z
      .string()
      .trim()
      .min(1)
      .max(120)
      .optional(),
    conceptSummary: z
      .string()
      .trim()
      .min(10, 'conceptSummary must be at least 10 characters')
      .max(280, 'conceptSummary must be ≤ 280 characters'),
  })
  .strict()
  .superRefine((val, ctx) => {
    // ----- 1. First-person gate on promptText --------------------------
    if (!hasFirstPerson(val.promptText)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['promptText'],
        message:
          'promptText must contain a first-person marker (I / me / my / we / us / our / let\'s) — Dashy is a character, not a narrator',
      });
    }

    // ----- 2. Voice-of-god instructional phrases banned in promptText -
    const GOD_VOICE_PHRASES = ['you will', 'you must', 'you should'];
    for (const phrase of GOD_VOICE_PHRASES) {
      if (containsCI(val.promptText, phrase)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['promptText'],
          message: `promptText must not contain voice-of-god phrase "${phrase}" — Dashy invites, she never instructs`,
        });
      }
    }

    // ----- 3. First-person gate on celebration -------------------------
    if (!hasFirstPerson(val.celebration)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['celebration'],
        message:
          'celebration must contain a first-person marker — Dashy shares the win, she never grants it from above',
      });
    }

    // ----- 4. Voice-of-god praise banned in celebration ----------------
    const GOD_PRAISE_PHRASES = ['you got', 'good job'];
    for (const phrase of GOD_PRAISE_PHRASES) {
      if (containsCI(val.celebration, phrase)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['celebration'],
          message: `celebration must not contain voice-of-god praise "${phrase}" — Dashy shares the moment, she doesn't grade the child`,
        });
      }
    }

    // ----- 5. First-person gate on retryHint ---------------------------
    if (!hasFirstPerson(val.retryHint)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['retryHint'],
        message:
          'retryHint must contain a first-person marker — Dashy resets softly, admits uncertainty first, never speaks voice-of-god',
      });
    }

    // ----- 6. Hard-correction vocabulary banned in retryHint -----------
    const HARD_CORRECTIONS = ['wrong', 'incorrect', 'no,'];
    for (const phrase of HARD_CORRECTIONS) {
      if (containsCI(val.retryHint, phrase)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['retryHint'],
          message: `retryHint must not contain hard-correction "${phrase}" — voice-mode misses get a soft reset, never a reprimand`,
        });
      }
    }

    // ----- 7. expectedResponses case-insensitive uniqueness ------------
    const seen = new Map<string, number>();
    val.expectedResponses.forEach((resp, i) => {
      const key = normalize(resp);
      if (seen.has(key)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['expectedResponses', i],
          message: `duplicate expectedResponse "${resp}" (matches index ${seen.get(key)} after normalization)`,
        });
      } else {
        seen.set(key, i);
      }
    });

    // ----- 8. expectedResponses must be substantive --------------------
    val.expectedResponses.forEach((resp, i) => {
      if (!isSubstantive(resp)) {
        ctx.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['expectedResponses', i],
          message: `expectedResponse "${resp}" is emoji/punctuation-only — must contain a letter or digit`,
        });
      }
    });

    // ----- 9. phonetics shape ------------------------------------------
    if (val.phonetics !== undefined && !PHONETICS_RE.test(val.phonetics)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['phonetics'],
        message: `phonetics must be space-separated kebab-syllable groups (e.g. "pho-to-syn-the-sis", "car-a-van") — got "${val.phonetics}"`,
      });
    }

    // ----- 10. Every string field must be substantive ------------------
    if (val.title !== undefined && !isSubstantive(val.title)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['title'],
        message: `title "${val.title}" is emoji/punctuation-only — must contain a letter or digit`,
      });
    }
    if (!isSubstantive(val.promptText)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['promptText'],
        message: 'promptText is emoji/punctuation-only — must contain a letter or digit',
      });
    }
    if (!isSubstantive(val.celebration)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['celebration'],
        message: 'celebration is emoji/punctuation-only — must contain a letter or digit',
      });
    }
    if (!isSubstantive(val.retryHint)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['retryHint'],
        message: 'retryHint is emoji/punctuation-only — must contain a letter or digit',
      });
    }
    if (!isSubstantive(val.conceptSummary)) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['conceptSummary'],
        message: 'conceptSummary is emoji/punctuation-only — must contain a letter or digit',
      });
    }
  });

export type VoicePersonaOutput = z.infer<typeof voicePersonaOutputSchema>;
