import { describe, it, expect } from 'vitest';
import { normalizeDecomposition } from '../src/services/pipeline/conceptDecomposer';
import type { ContentAnalysis } from '../src/services/pipeline/contentAnalyzer';

const mockAnalysis: ContentAnalysis = {
  topic: 'Dinosaurs',
  keyConcepts: ['T-Rex', 'fossils', 'extinction'],
  suggestedStage: 2,
  ageAppropriate: true,
  safetyFlags: [],
  suggestedCardCount: 6,
  summary: 'Dinosaurs were big reptiles that lived long ago.',
};

describe('conceptDecomposer — normalizeDecomposition (S9-06)', () => {
  it('accepts a well-formed LLM response with 4 atoms', () => {
    const raw = {
      atoms: [
        {
          id: 'a-1',
          name: 'What dinosaurs were',
          description: 'Big reptiles that lived millions of years ago.',
          teachingStrategy: 'narrative',
          recommendedCardType: 'story',
          engagementScore: 0.9,
          learningValue: 0.8,
          prerequisites: [],
        },
        {
          id: 'a-2',
          name: 'T-Rex',
          description: 'A very big, very toothy dinosaur.',
          teachingStrategy: 'explanation',
          recommendedCardType: 'concept',
          engagementScore: 0.95,
          learningValue: 0.7,
          prerequisites: ['a-1'],
        },
        {
          id: 'a-3',
          name: 'Fossils',
          description: 'How we know dinosaurs existed.',
          teachingStrategy: 'experiment',
          recommendedCardType: 'experiment',
          engagementScore: 0.7,
          learningValue: 0.9,
          prerequisites: ['a-1'],
        },
        {
          id: 'a-4',
          name: 'Why they disappeared',
          description: 'Earth changed and most dinosaurs died out.',
          teachingStrategy: 'cause_effect',
          recommendedCardType: 'concept',
          engagementScore: 0.8,
          learningValue: 0.95,
          prerequisites: ['a-1', 'a-3'],
        },
      ],
      rationale: 'foundational → specific → evidence → outcome',
    };

    const result = normalizeDecomposition(raw, mockAnalysis);

    expect(result.atoms).toHaveLength(4);
    expect(result.rationale).toContain('foundational');

    // IDs are re-keyed to atom-1..atom-N
    expect(result.atoms.map((a) => a.id)).toEqual(['atom-1', 'atom-2', 'atom-3', 'atom-4']);

    // Prerequisites are re-keyed too
    expect(result.atoms[1].prerequisites).toEqual(['atom-1']);
    expect(result.atoms[3].prerequisites).toEqual(['atom-1', 'atom-3']);

    // Scores stay clamped 0..1
    result.atoms.forEach((a) => {
      expect(a.engagementScore).toBeGreaterThanOrEqual(0);
      expect(a.engagementScore).toBeLessThanOrEqual(1);
      expect(a.learningValue).toBeGreaterThanOrEqual(0);
      expect(a.learningValue).toBeLessThanOrEqual(1);
    });
  });

  it('clamps to at most 6 atoms', () => {
    const raw = {
      atoms: Array.from({ length: 9 }, (_, i) => ({
        id: `x-${i}`,
        name: `Atom ${i}`,
        description: 'desc',
        teachingStrategy: 'explanation',
        recommendedCardType: 'concept',
        engagementScore: 0.7,
        learningValue: 0.7,
        prerequisites: [],
      })),
    };

    const result = normalizeDecomposition(raw, mockAnalysis);
    expect(result.atoms.length).toBeLessThanOrEqual(6);
  });

  it('fills to at least 3 atoms from keyConcepts when LLM under-delivers', () => {
    const raw = {
      atoms: [
        {
          id: 'x',
          name: 'Only atom',
          description: 'd',
          teachingStrategy: 'explanation',
          recommendedCardType: 'concept',
          engagementScore: 0.5,
          learningValue: 0.5,
        },
      ],
    };

    const result = normalizeDecomposition(raw, mockAnalysis);
    expect(result.atoms.length).toBeGreaterThanOrEqual(3);
    expect(result.atoms[0].name).toBe('Only atom');
    // Fill comes from keyConcepts
    expect(result.atoms.slice(1).map((a) => a.name)).toEqual(
      expect.arrayContaining(['T-Rex', 'fossils'])
    );
  });

  it('synthesizes atoms when keyConcepts is also empty', () => {
    const sparseAnalysis = { ...mockAnalysis, keyConcepts: [] };
    const raw = { atoms: [] };
    const result = normalizeDecomposition(raw, sparseAnalysis);

    expect(result.atoms.length).toBeGreaterThanOrEqual(3);
    result.atoms.forEach((a) => {
      expect(a.name).toBeTruthy();
      expect(a.description).toBeTruthy();
    });
  });

  it('coerces invalid teaching strategies to explanation', () => {
    const raw = {
      atoms: [
        {
          id: '1',
          name: 'A',
          description: 'desc',
          teachingStrategy: 'bogus_strategy',
          recommendedCardType: 'concept',
          engagementScore: 0.5,
          learningValue: 0.5,
        },
        {
          id: '2',
          name: 'B',
          description: 'desc',
          teachingStrategy: 'narrative',
          recommendedCardType: 'not_a_card',
          engagementScore: 0.5,
          learningValue: 0.5,
        },
        {
          id: '3',
          name: 'C',
          description: 'desc',
          teachingStrategy: 'quiz',
          recommendedCardType: 'quiz',
          engagementScore: 0.5,
          learningValue: 0.5,
        },
      ],
    };

    const result = normalizeDecomposition(raw, mockAnalysis);
    // bogus strategy coerced to 'explanation' → maps to 'concept' card type
    expect(result.atoms[0].teachingStrategy).toBe('explanation');
    expect(result.atoms[0].recommendedCardType).toBe('concept');
    // invalid card type falls back to strategy-derived type
    expect(result.atoms[1].teachingStrategy).toBe('narrative');
    expect(result.atoms[1].recommendedCardType).toBe('story');
  });

  it('drops atoms missing a name', () => {
    const raw = {
      atoms: [
        { id: '1', name: '', description: 'x', teachingStrategy: 'explanation', recommendedCardType: 'concept' },
        { id: '2', name: 'Valid', description: 'y', teachingStrategy: 'narrative', recommendedCardType: 'story' },
      ],
    };
    const result = normalizeDecomposition(raw, mockAnalysis);
    // The unnamed one drops; then we backfill to reach 3
    expect(result.atoms.map((a) => a.name)).toContain('Valid');
    expect(result.atoms.length).toBeGreaterThanOrEqual(3);
  });

  it('strips prerequisites that don\'t match any atom after re-keying', () => {
    const raw = {
      atoms: [
        { id: 'a', name: 'A', description: 'd', teachingStrategy: 'narrative', recommendedCardType: 'story' },
        { id: 'b', name: 'B', description: 'd', teachingStrategy: 'explanation', recommendedCardType: 'concept', prerequisites: ['a', 'ghost'] },
        { id: 'c', name: 'C', description: 'd', teachingStrategy: 'quiz', recommendedCardType: 'quiz', prerequisites: ['b'] },
      ],
    };
    const result = normalizeDecomposition(raw, mockAnalysis);
    expect(result.atoms[1].prerequisites).toEqual(['atom-1']);
    expect(result.atoms[2].prerequisites).toEqual(['atom-2']);
  });
});
