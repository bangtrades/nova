/**
 * S12-05 · R5 — curriculum-architect output Zod validator tests.
 *
 * Stage-3 counterpart to experimentDesignerValidator.test.ts. The schema
 * at `src/services/skills/validators/curriculumArchitect.ts` is the
 * contract the LLM must hit before the pipeline will accept its lesson
 * plan — it guards the exact invariants the downstream per-atom skill
 * router (Stage 4) depends on:
 *
 *   - strict atom-N id sequence
 *   - strategy ↔ cardType compatibility (no "quiz strategy wants story"
 *     mismatches)
 *   - prerequisite DAG (no self-ref, no forward-ref, no duplicates, no
 *     dangling ids)
 *   - card-type diversity — at least 2 types across 3 atoms, at least
 *     3 across 4+ atoms
 *   - lesson shape — final atom is quiz or voice (comprehension check)
 *   - voice ceiling — at most one voice atom per lesson
 *
 * Every superRefine check in the schema gets at least one failure case
 * here so regressions surface on the first test run.
 */
import { describe, it, expect } from 'vitest';
import { curriculumArchitectOutputSchema } from '@services/skills/validators/curriculumArchitect';

// ---------------------------------------------------------------------------
// Fixture factories — one per difficulty bucket. Each returns a CLEAN
// payload that round-trips through the validator. Individual tests then
// mutate one field to exercise a single invariant in isolation.
// ---------------------------------------------------------------------------

type ConceptAtomOutput = {
  id: string;
  name: string;
  description: string;
  teachingStrategy: string;
  recommendedCardType: string;
  engagementScore: number;
  learningValue: number;
  prerequisites: string[];
};
type DecompositionOutput = {
  atoms: ConceptAtomOutput[];
  rationale: string;
};

/** 3-atom easy decomposition — hook-and-teach arc (narrative → explanation → quiz). */
function makeEasyOutput(
  overrides: Partial<DecompositionOutput> = {}
): DecompositionOutput {
  return {
    atoms: [
      {
        id: 'atom-1',
        name: 'Cats live with people',
        description:
          'A soft scene — a cat on a windowsill watching the rain. Pulls the child into the world of cats.',
        teachingStrategy: 'narrative',
        recommendedCardType: 'story',
        engagementScore: 0.8,
        learningValue: 0.3,
        prerequisites: [],
      },
      {
        id: 'atom-2',
        name: 'Cats are mammals',
        description:
          'Cats have fur, breathe air, and drink milk when they are babies — the marks of a mammal.',
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.5,
        learningValue: 0.8,
        prerequisites: ['atom-1'],
      },
      {
        id: 'atom-3',
        name: 'Is this a cat?',
        description:
          'Two pictures side by side — a cat and a dog. The child picks which one is the cat.',
        teachingStrategy: 'quiz',
        recommendedCardType: 'quiz',
        engagementScore: 0.7,
        learningValue: 0.7,
        prerequisites: ['atom-2'],
      },
    ],
    rationale:
      'Start with a scene the child recognizes so they walk in with a picture already in their head. Then name the defining trait. Close with a check they can pass.',
    ...overrides,
  };
}

/** 4-atom medium — hook-and-teach with an added comparison atom. */
function makeMediumOutput(
  overrides: Partial<DecompositionOutput> = {}
): DecompositionOutput {
  return {
    atoms: [
      {
        id: 'atom-1',
        name: 'A seed in the dark',
        description:
          'A small story — a seed in dark soil waiting for something to wake it up. Sets the stage.',
        teachingStrategy: 'narrative',
        recommendedCardType: 'story',
        engagementScore: 0.8,
        learningValue: 0.4,
        prerequisites: [],
      },
      {
        id: 'atom-2',
        name: 'Seeds need water and warmth',
        description:
          'Explains the two ingredients that wake a seed up — water softens it and warmth tells it to grow.',
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.5,
        learningValue: 0.85,
        prerequisites: ['atom-1'],
      },
      {
        id: 'atom-3',
        name: 'Seed vs. sprout',
        description:
          'Compares a still seed and a sprouted one — same object, two stages, one change.',
        teachingStrategy: 'comparison',
        recommendedCardType: 'concept',
        engagementScore: 0.6,
        learningValue: 0.7,
        prerequisites: ['atom-2'],
      },
      {
        id: 'atom-4',
        name: 'What does a seed need?',
        description:
          'Shows three pictures — a dry rock, a warm puddle, a sunny watered pot — and asks where the seed grows.',
        teachingStrategy: 'quiz',
        recommendedCardType: 'quiz',
        engagementScore: 0.7,
        learningValue: 0.75,
        prerequisites: ['atom-2', 'atom-3'],
      },
    ],
    rationale:
      'A seed feels small and magical to a four-year-old. Lead with the scene, teach the two ingredients that wake it up, let the child see the before-and-after, then probe with a three-choice pick that tests the rule.',
    ...overrides,
  };
}

/** 5-atom hard — contrast-pair with experiment and a fork-and-rejoin graph. */
function makeHardOutput(
  overrides: Partial<DecompositionOutput> = {}
): DecompositionOutput {
  return {
    atoms: [
      {
        id: 'atom-1',
        name: 'Mammals and birds — the split',
        description:
          'Names the two classes we will sort between — fur-and-milk versus feathers-and-eggs.',
        teachingStrategy: 'comparison',
        recommendedCardType: 'concept',
        engagementScore: 0.6,
        learningValue: 0.75,
        prerequisites: [],
      },
      {
        id: 'atom-2',
        name: 'What makes a mammal',
        description:
          'Fur, warm blood, and feeds babies with milk — the three locks that identify a mammal.',
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.5,
        learningValue: 0.85,
        prerequisites: ['atom-1'],
      },
      {
        id: 'atom-3',
        name: 'What makes a bird',
        description:
          'Feathers, hard-shelled eggs, and a beak — the three locks that identify a bird.',
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.5,
        learningValue: 0.85,
        prerequisites: ['atom-1'],
      },
      {
        id: 'atom-4',
        name: 'Sort them — bat, eagle, whale, robin',
        description:
          'Four animals drop into two bins by the locks just taught. Rejoin atoms 2 and 3.',
        teachingStrategy: 'experiment',
        recommendedCardType: 'experiment',
        engagementScore: 0.85,
        learningValue: 0.8,
        prerequisites: ['atom-2', 'atom-3'],
      },
      {
        id: 'atom-5',
        name: 'Which one is a mammal?',
        description:
          'A tighter quiz — two near-misses (penguin and dolphin) make the child lean on the actual defining traits.',
        teachingStrategy: 'quiz',
        recommendedCardType: 'quiz',
        engagementScore: 0.7,
        learningValue: 0.85,
        prerequisites: ['atom-4'],
      },
    ],
    rationale:
      'The child already sees cats and birds, but mixes up what makes them different. Pull the pair apart, teach each side on its own, let them sort with hands, then probe with near-misses that force the defining-trait reasoning.',
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Happy paths — one per difficulty.
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — happy paths', () => {
  it('accepts a well-formed 3-atom (easy) decomposition', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(makeEasyOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed 4-atom (medium) decomposition', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(makeMediumOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a well-formed 5-atom (hard) decomposition with fork-and-rejoin', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(makeHardOutput());
    expect(parsed.success).toBe(true);
  });

  it('accepts a 6-atom decomposition (upper bound)', () => {
    const six = makeHardOutput();
    // Insert a sixth atom before the final quiz so the quiz still closes.
    six.atoms.splice(4, 0, {
      id: 'atom-5',
      name: 'Why the locks matter',
      description:
        'Explains why the defining traits are the ones we use — warm blood ties mammals across species, eggs tie birds across species.',
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
      engagementScore: 0.4,
      learningValue: 0.7,
      prerequisites: ['atom-4'],
    });
    six.atoms[5] = { ...six.atoms[5], id: 'atom-6', prerequisites: ['atom-5'] };

    const parsed = curriculumArchitectOutputSchema.safeParse(six);
    expect(parsed.success).toBe(true);
  });

  it('exposes the inferred type — atoms[0].id typed as string', () => {
    const parsed = curriculumArchitectOutputSchema.parse(makeEasyOutput());
    const id: string = parsed.atoms[0].id;
    expect(typeof id).toBe('string');
    expect(parsed.atoms.length).toBeGreaterThanOrEqual(3);
  });
});

// ---------------------------------------------------------------------------
// Invariant 1 — strict atom-N id sequence.
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — atom id sequence', () => {
  it('rejects a decomposition missing atom-1', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(
      makeEasyOutput({
        atoms: makeEasyOutput().atoms.map((a, i) => ({
          ...a,
          // Shift every id by 1 so the sequence is atom-2 / atom-3 / atom-4
          id: `atom-${i + 2}`,
        })),
      })
    );
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('sequence must be contiguous')
        )
      ).toBe(true);
    }
  });

  it('rejects a gap in the sequence (atom-1, atom-2, atom-4)', () => {
    const out = makeEasyOutput();
    out.atoms[2] = { ...out.atoms[2], id: 'atom-4' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects an out-of-order id (atom-1, atom-3, atom-2)', () => {
    const out = makeEasyOutput();
    out.atoms[1] = { ...out.atoms[1], id: 'atom-3' };
    out.atoms[2] = { ...out.atoms[2], id: 'atom-2' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects a non-"atom-N" id format (uuid / name)', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], id: 'first-atom' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Invariant 2 — strategy ↔ cardType compatibility.
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — strategy ↔ cardType compatibility', () => {
  it('rejects a "quiz" strategy claiming a "story" card type', () => {
    const out = makeEasyOutput();
    out.atoms[2] = {
      ...out.atoms[2],
      teachingStrategy: 'quiz',
      recommendedCardType: 'story',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('incompatible')
        )
      ).toBe(true);
    }
  });

  it('rejects an "experiment" strategy claiming a "quiz" card type', () => {
    const out = makeHardOutput();
    out.atoms[3] = {
      ...out.atoms[3],
      teachingStrategy: 'experiment',
      recommendedCardType: 'quiz',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('accepts narrative → concept (the rare but valid vivid-scene case)', () => {
    const out = makeEasyOutput();
    out.atoms[0] = {
      ...out.atoms[0],
      teachingStrategy: 'narrative',
      recommendedCardType: 'concept',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(true);
  });

  it('rejects unknown strategy values (e.g. "lecture")', () => {
    const out = makeEasyOutput();
    out.atoms[1] = { ...out.atoms[1], teachingStrategy: 'lecture' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects unknown cardType values (e.g. "poem")', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], recommendedCardType: 'poem' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Invariant 3 — prerequisite DAG (no self-ref, no forward-ref, no dup, no dangling).
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — prerequisite DAG', () => {
  it('rejects self-reference (atom-2 lists atom-2 as a prerequisite)', () => {
    const out = makeEasyOutput();
    out.atoms[1] = { ...out.atoms[1], prerequisites: ['atom-2'] };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('cannot list itself')
        )
      ).toBe(true);
    }
  });

  it('rejects forward reference (atom-1 claims atom-2 as a prerequisite)', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], prerequisites: ['atom-2'] };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('must precede')
        )
      ).toBe(true);
    }
  });

  it('rejects duplicate prerequisite entries (atom-3 lists atom-1 twice)', () => {
    const out = makeEasyOutput();
    out.atoms[2] = { ...out.atoms[2], prerequisites: ['atom-1', 'atom-1'] };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('duplicated')
        )
      ).toBe(true);
    }
  });

  it('rejects dangling prerequisite (references an atom id not in the set)', () => {
    const out = makeEasyOutput();
    out.atoms[2] = { ...out.atoms[2], prerequisites: ['atom-99'] };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('does not reference')
        )
      ).toBe(true);
    }
  });

  it('accepts an empty prerequisites array on any atom', () => {
    const out = makeEasyOutput();
    out.atoms[1] = { ...out.atoms[1], prerequisites: [] };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(true);
  });

  it('accepts fork-and-rejoin — atom-4 depends on both atom-2 and atom-3', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(makeHardOutput());
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 4 — card-type diversity.
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — card-type diversity', () => {
  it('rejects 3 atoms with only 1 distinct card type', () => {
    const out = makeEasyOutput();
    out.atoms = out.atoms.map((a) => ({
      ...a,
      teachingStrategy: 'quiz',
      recommendedCardType: 'quiz',
    }));
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('diversity too low')
        )
      ).toBe(true);
    }
  });

  it('rejects 4 atoms with only 2 distinct card types', () => {
    // 4 atoms with just concept + quiz — need 3 distinct types at size ≥ 4.
    const out = makeMediumOutput({
      atoms: [
        {
          id: 'atom-1',
          name: 'Seeds need warmth',
          description:
            'Explains that warmth is one of the two ingredients a seed needs to wake up.',
          teachingStrategy: 'explanation',
          recommendedCardType: 'concept',
          engagementScore: 0.5,
          learningValue: 0.8,
          prerequisites: [],
        },
        {
          id: 'atom-2',
          name: 'Seeds need water',
          description:
            'Water softens the seed coat so the new plant can push its way out.',
          teachingStrategy: 'explanation',
          recommendedCardType: 'concept',
          engagementScore: 0.5,
          learningValue: 0.8,
          prerequisites: ['atom-1'],
        },
        {
          id: 'atom-3',
          name: 'Warm or cold? Wet or dry?',
          description:
            'Compares four corners of the matrix so the child sees which one wakes a seed.',
          teachingStrategy: 'comparison',
          recommendedCardType: 'concept',
          engagementScore: 0.6,
          learningValue: 0.75,
          prerequisites: ['atom-2'],
        },
        {
          id: 'atom-4',
          name: 'Which pot wakes the seed?',
          description:
            'Three pictures — a dry rock, a warm puddle, a sunny watered pot — pick the one that grows.',
          teachingStrategy: 'quiz',
          recommendedCardType: 'quiz',
          engagementScore: 0.7,
          learningValue: 0.8,
          prerequisites: ['atom-3'],
        },
      ],
    });
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('accepts 4 atoms with 3 distinct card types (story, concept, quiz)', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(makeMediumOutput());
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 5 — lesson shape (final atom is quiz or voice).
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — lesson shape', () => {
  it('rejects a decomposition whose final atom is an explanation', () => {
    const out = makeEasyOutput();
    out.atoms[2] = {
      ...out.atoms[2],
      teachingStrategy: 'explanation',
      recommendedCardType: 'concept',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('final atom must be a comprehension check')
        )
      ).toBe(true);
    }
  });

  it('rejects a decomposition whose final atom is a narrative', () => {
    const out = makeEasyOutput();
    out.atoms[2] = {
      ...out.atoms[2],
      teachingStrategy: 'narrative',
      recommendedCardType: 'story',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('accepts a decomposition whose final atom is a voice check', () => {
    const out = makeHardOutput();
    // Keep only one voice atom and ensure it's the last. Also restore
    // diversity — swap atom-5 in place.
    out.atoms[4] = {
      ...out.atoms[4],
      name: 'Say the word',
      description:
        'Child speaks the classifying word aloud — locks the vocabulary through voice.',
      teachingStrategy: 'voice',
      recommendedCardType: 'voice',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Invariant 6 — voice ceiling (≤ 1 voice atom per lesson).
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — voice ceiling', () => {
  it('rejects two voice atoms in the same lesson', () => {
    const out = makeHardOutput();
    // Replace atom-3 with a voice atom so we end up with two voices in
    // the same decomposition (atom-3 + atom-5). Keep card-type diversity
    // satisfied: concept + experiment + voice + quiz + voice = 4 distinct.
    out.atoms[2] = {
      ...out.atoms[2],
      name: 'Say the bird word',
      description:
        'Child says a bird-class word aloud to anchor the vocabulary.',
      teachingStrategy: 'voice',
      recommendedCardType: 'voice',
    };
    out.atoms[4] = {
      ...out.atoms[4],
      name: 'Say the mammal word',
      description:
        'Child says the mammal-class word aloud, completing the symmetric pair.',
      teachingStrategy: 'voice',
      recommendedCardType: 'voice',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
    if (!parsed.success) {
      expect(
        parsed.error.issues.some((i) =>
          i.message.toLowerCase().includes('at most one voice atom')
        )
      ).toBe(true);
    }
  });

  it('accepts a single voice atom in the closing slot', () => {
    const out = makeHardOutput();
    out.atoms[4] = {
      ...out.atoms[4],
      name: 'Say the word',
      description:
        'Child names the classifying trait aloud, anchoring the vocab learned above.',
      teachingStrategy: 'voice',
      recommendedCardType: 'voice',
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Base invariants — bounds and strict mode.
// ---------------------------------------------------------------------------

describe('curriculumArchitectOutputSchema — base invariants', () => {
  it('rejects fewer than 3 atoms', () => {
    const out = makeEasyOutput();
    out.atoms = out.atoms.slice(0, 2);
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects more than 6 atoms', () => {
    const out = makeHardOutput();
    // Duplicate the last atom twice to push length past the ceiling.
    out.atoms.push(
      { ...out.atoms[4], id: 'atom-6', prerequisites: ['atom-5'] },
      { ...out.atoms[4], id: 'atom-7', prerequisites: ['atom-6'] }
    );
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects atom name shorter than 2 chars', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], name: 'A' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects atom name longer than 60 chars', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], name: 'N'.repeat(61) };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects atom description shorter than 20 chars', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], description: 'too brief' };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects atom description longer than 280 chars', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], description: 'd'.repeat(281) };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects engagementScore out of [0,1]', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], engagementScore: 1.5 };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects negative learningValue', () => {
    const out = makeEasyOutput();
    out.atoms[0] = { ...out.atoms[0], learningValue: -0.1 };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });

  it('rejects rationale shorter than 40 chars', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(
      makeEasyOutput({ rationale: 'nope' })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects rationale longer than 600 chars', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse(
      makeEasyOutput({ rationale: 'r'.repeat(601) })
    );
    expect(parsed.success).toBe(false);
  });

  it('rejects extra top-level fields (strict mode)', () => {
    const parsed = curriculumArchitectOutputSchema.safeParse({
      ...makeEasyOutput(),
      mischief: 'extra-key',
    });
    expect(parsed.success).toBe(false);
  });

  it('rejects extra fields inside an atom (strict nested)', () => {
    const out = makeEasyOutput();
    out.atoms[0] = {
      ...out.atoms[0],
      // @ts-expect-error — intentionally extra field for strict test
      score: 0.9,
    };
    const parsed = curriculumArchitectOutputSchema.safeParse(out);
    expect(parsed.success).toBe(false);
  });
});
