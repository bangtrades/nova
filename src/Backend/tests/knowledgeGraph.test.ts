import { describe, it, expect } from 'vitest';
import {
  KNOWLEDGE_GRAPH_SEED,
  validateSeedGraph,
  type ConceptSeed,
} from '../src/db/seedKnowledgeGraph';

// ============================================================
// S10-01 — Knowledge graph seed integrity
// ============================================================

describe('knowledgeGraph — seed shape (S10-01)', () => {
  it('contains exactly 50 concepts', () => {
    expect(KNOWLEDGE_GRAPH_SEED).toHaveLength(50);
  });

  it('spans the three committed domains', () => {
    const domains = new Set(KNOWLEDGE_GRAPH_SEED.map((c) => c.domain));
    expect(domains).toEqual(new Set(['computers', 'robots', 'ai']));
  });

  it('has at least 10 concepts in every domain (no degenerate split)', () => {
    const domains: Record<string, number> = {};
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      domains[c.domain] = (domains[c.domain] ?? 0) + 1;
    }
    for (const count of Object.values(domains)) {
      expect(count).toBeGreaterThanOrEqual(10);
    }
  });

  it('assigns every concept a stable slug id (not a uuid)', () => {
    // Slugs are prefix-hyphen-N form: "comp-01", "robo-17", "ai-03".
    // This is deliberate so prerequisites can be declared statically.
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      expect(c.id).toMatch(/^(comp|robo|ai)-\d{2}$/);
    }
  });

  it('gives every concept a non-empty human-readable name and description', () => {
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      expect(c.name.length).toBeGreaterThan(0);
      expect(c.description.length).toBeGreaterThan(0);
    }
  });

  it('has unique concept names inside each domain', () => {
    const byDomain: Record<string, Set<string>> = {};
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      byDomain[c.domain] ??= new Set();
      expect(byDomain[c.domain].has(c.name)).toBe(false);
      byDomain[c.domain].add(c.name);
    }
  });

  it('keeps difficulty in the 1-5 range', () => {
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      expect(c.difficulty).toBeGreaterThanOrEqual(1);
      expect(c.difficulty).toBeLessThanOrEqual(5);
    }
  });
});

describe('knowledgeGraph — prerequisite integrity (S10-01)', () => {
  it('validateSeedGraph() reports zero issues for the committed seed', () => {
    const issues = validateSeedGraph();
    expect(issues).toEqual([]);
  });

  it('flags unknown prerequisite references', () => {
    const bad: ConceptSeed[] = [
      { id: 'comp-01', name: 'A', domain: 'computers', description: 'a', difficulty: 1, sortOrder: 1, prerequisites: [] },
      { id: 'comp-02', name: 'B', domain: 'computers', description: 'b', difficulty: 2, sortOrder: 2, prerequisites: ['does-not-exist'] },
    ];
    const issues = validateSeedGraph(bad);
    expect(issues.some((i) => i.kind === 'unknown-prereq' && i.conceptId === 'comp-02')).toBe(true);
  });

  it('flags duplicate concept IDs', () => {
    const bad: ConceptSeed[] = [
      { id: 'comp-01', name: 'A', domain: 'computers', description: 'a', difficulty: 1, sortOrder: 1, prerequisites: [] },
      { id: 'comp-01', name: 'A again', domain: 'computers', description: 'a', difficulty: 1, sortOrder: 2, prerequisites: [] },
    ];
    const issues = validateSeedGraph(bad);
    expect(issues.some((i) => i.kind === 'duplicate-id')).toBe(true);
  });

  it('flags self-referencing prerequisites', () => {
    const bad: ConceptSeed[] = [
      { id: 'comp-01', name: 'A', domain: 'computers', description: 'a', difficulty: 1, sortOrder: 1, prerequisites: ['comp-01'] },
    ];
    const issues = validateSeedGraph(bad);
    expect(issues.some((i) => i.kind === 'self-prereq' && i.conceptId === 'comp-01')).toBe(true);
  });

  it('flags cycles across multiple concepts', () => {
    const bad: ConceptSeed[] = [
      { id: 'comp-01', name: 'A', domain: 'computers', description: 'a', difficulty: 1, sortOrder: 1, prerequisites: ['comp-02'] },
      { id: 'comp-02', name: 'B', domain: 'computers', description: 'b', difficulty: 1, sortOrder: 2, prerequisites: ['comp-03'] },
      { id: 'comp-03', name: 'C', domain: 'computers', description: 'c', difficulty: 1, sortOrder: 3, prerequisites: ['comp-01'] },
    ];
    const issues = validateSeedGraph(bad);
    expect(issues.some((i) => i.kind === 'cycle')).toBe(true);
  });

  it('foundation concepts (the three domain roots) have zero prerequisites', () => {
    // comp-01, robo-01 are intentional roots. ai-01 depends on comp-01 by design.
    const comp01 = KNOWLEDGE_GRAPH_SEED.find((c) => c.id === 'comp-01')!;
    const robo01 = KNOWLEDGE_GRAPH_SEED.find((c) => c.id === 'robo-01')!;
    expect(comp01.prerequisites).toEqual([]);
    expect(robo01.prerequisites).toEqual([]);
  });
});

describe('knowledgeGraph — cross-domain edges (S10-01)', () => {
  it('ai-01 depends on comp-01 (AI requires the idea of a computer)', () => {
    const ai01 = KNOWLEDGE_GRAPH_SEED.find((c) => c.id === 'ai-01')!;
    expect(ai01.prerequisites).toContain('comp-01');
  });

  it('robo-17 (how robots are programmed) depends on comp-14 (instructions/code)', () => {
    const robo17 = KNOWLEDGE_GRAPH_SEED.find((c) => c.id === 'robo-17')!;
    expect(robo17.prerequisites).toContain('comp-14');
  });

  it('every prerequisite id appears somewhere in the seed', () => {
    const allIds = new Set(KNOWLEDGE_GRAPH_SEED.map((c) => c.id));
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      for (const prereq of c.prerequisites) {
        expect(allIds.has(prereq)).toBe(true);
      }
    }
  });
});

describe('knowledgeGraph — pedagogical ordering (S10-01)', () => {
  it('a concept has difficulty >= max(prereq difficulties)', () => {
    const byId = new Map(KNOWLEDGE_GRAPH_SEED.map((c) => [c.id, c]));
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      for (const prereqId of c.prerequisites) {
        const prereq = byId.get(prereqId);
        if (prereq) {
          expect(c.difficulty).toBeGreaterThanOrEqual(prereq.difficulty);
        }
      }
    }
  });

  it('sortOrder is unique per domain (no ties)', () => {
    const seen: Record<string, Set<number>> = {};
    for (const c of KNOWLEDGE_GRAPH_SEED) {
      seen[c.domain] ??= new Set();
      expect(seen[c.domain].has(c.sortOrder)).toBe(false);
      seen[c.domain].add(c.sortOrder);
    }
  });
});
