/**
 * Knowledge Graph Seeder (Sprint 10 / S10-01 — "The Brain")
 *
 * Seeds 50 base concepts across 3 domains (computers, robots, AI).
 *
 * Concept IDs are deterministic slugs (e.g. "comp-01") so prerequisites
 * can reference them statically, and so re-running the seed is idempotent
 * via upsert on id. Prerequisites form a DAG — this module guarantees
 * every referenced prerequisite id also appears as a concept id in the
 * same seed (see validateSeedGraph() + tests).
 *
 * Usage:
 *   npm run db:seed:knowledge       # seed production DB
 *   await seedKnowledgeGraph()      # programmatic (tests)
 */

import { getPrismaClient } from './client';

export interface ConceptSeed {
  id: string;
  name: string;
  domain: 'computers' | 'robots' | 'ai';
  description: string;
  prerequisites: string[]; // referenced concept IDs
  difficulty: number;      // 1-5, rough age-appropriate ordering
  sortOrder: number;
}

// ============================================================
// COMPUTERS (17 concepts)
// Foundational → abstract. Shared prereqs for AI + robotics tracks.
// ============================================================
const COMPUTERS: ConceptSeed[] = [
  { id: 'comp-01', name: 'What a computer is',        domain: 'computers', difficulty: 1, sortOrder:  1, prerequisites: [],                 description: 'A machine that follows instructions to do work with information.' },
  { id: 'comp-02', name: 'Input and output',          domain: 'computers', difficulty: 1, sortOrder:  2, prerequisites: ['comp-01'],        description: 'Things you put into a computer and things it gives back.' },
  { id: 'comp-03', name: 'Keyboard',                  domain: 'computers', difficulty: 1, sortOrder:  3, prerequisites: ['comp-02'],        description: 'An input device with letters and numbers for typing.' },
  { id: 'comp-04', name: 'Mouse',                     domain: 'computers', difficulty: 1, sortOrder:  4, prerequisites: ['comp-02'],        description: 'An input device for pointing and clicking.' },
  { id: 'comp-05', name: 'Screen',                    domain: 'computers', difficulty: 1, sortOrder:  5, prerequisites: ['comp-02'],        description: 'The output where the computer shows you pictures and words.' },
  { id: 'comp-06', name: 'Memory',                    domain: 'computers', difficulty: 2, sortOrder:  6, prerequisites: ['comp-01'],        description: 'A short-term place where the computer holds things it is using right now.' },
  { id: 'comp-07', name: 'Storage',                   domain: 'computers', difficulty: 2, sortOrder:  7, prerequisites: ['comp-06'],        description: 'A long-term place where the computer keeps things for later.' },
  { id: 'comp-08', name: 'Files and folders',         domain: 'computers', difficulty: 2, sortOrder:  8, prerequisites: ['comp-07'],        description: 'How the computer organizes saved things into named boxes.' },
  { id: 'comp-09', name: 'Apps and programs',         domain: 'computers', difficulty: 2, sortOrder:  9, prerequisites: ['comp-01'],        description: 'Sets of instructions the computer can run to do a task.' },
  { id: 'comp-10', name: 'The internet',              domain: 'computers', difficulty: 2, sortOrder: 10, prerequisites: ['comp-09'],        description: 'A giant network that lets computers talk to each other.' },
  { id: 'comp-11', name: 'Websites',                  domain: 'computers', difficulty: 3, sortOrder: 11, prerequisites: ['comp-10'],        description: 'Pages on the internet you can visit.' },
  { id: 'comp-12', name: 'How computers count',       domain: 'computers', difficulty: 3, sortOrder: 12, prerequisites: ['comp-06'],        description: 'Computers count in ones and zeros — this is called binary.' },
  { id: 'comp-13', name: 'Bits and bytes',            domain: 'computers', difficulty: 3, sortOrder: 13, prerequisites: ['comp-12'],        description: 'A bit is one 0 or 1. Eight bits together make a byte.' },
  { id: 'comp-14', name: 'Instructions (code)',       domain: 'computers', difficulty: 3, sortOrder: 14, prerequisites: ['comp-09'],        description: 'The step-by-step recipe that tells a computer what to do.' },
  { id: 'comp-15', name: 'Loops',                     domain: 'computers', difficulty: 4, sortOrder: 15, prerequisites: ['comp-14'],        description: 'An instruction that tells the computer to repeat something.' },
  { id: 'comp-16', name: 'If and else (conditions)',  domain: 'computers', difficulty: 4, sortOrder: 16, prerequisites: ['comp-14'],        description: 'An instruction that lets the computer make a choice.' },
  { id: 'comp-17', name: 'Bugs and debugging',        domain: 'computers', difficulty: 4, sortOrder: 17, prerequisites: ['comp-14'],        description: 'Mistakes in code are called bugs. Fixing them is called debugging.' },
];

// ============================================================
// ROBOTS (17 concepts)
// Physical parts → sensors → motion → real-world robot kinds.
// Cross-domain edge: robo-17 depends on comp-14 (instructions).
// ============================================================
const ROBOTS: ConceptSeed[] = [
  { id: 'robo-01', name: 'What a robot is',            domain: 'robots', difficulty: 1, sortOrder:  1, prerequisites: [],                            description: 'A machine with a body that can move and do things in the real world.' },
  { id: 'robo-02', name: 'Robots vs animals',          domain: 'robots', difficulty: 1, sortOrder:  2, prerequisites: ['robo-01'],                   description: 'Animals are alive. Robots are built from parts and follow instructions.' },
  { id: 'robo-03', name: 'Robot body parts',           domain: 'robots', difficulty: 1, sortOrder:  3, prerequisites: ['robo-01'],                   description: 'Robots have parts like arms, wheels, cameras, and grippers.' },
  { id: 'robo-04', name: 'Wheels',                     domain: 'robots', difficulty: 1, sortOrder:  4, prerequisites: ['robo-03'],                   description: 'Round parts that let a robot roll on the ground.' },
  { id: 'robo-05', name: 'Arms and grippers',          domain: 'robots', difficulty: 2, sortOrder:  5, prerequisites: ['robo-03'],                   description: 'The parts a robot uses to reach out and pick things up.' },
  { id: 'robo-06', name: 'Sensors',                    domain: 'robots', difficulty: 2, sortOrder:  6, prerequisites: ['robo-01'],                   description: 'Parts that let a robot notice the world around it.' },
  { id: 'robo-07', name: 'Cameras as eyes',            domain: 'robots', difficulty: 2, sortOrder:  7, prerequisites: ['robo-06'],                   description: 'A camera is a sensor that lets the robot see pictures.' },
  { id: 'robo-08', name: 'Microphones as ears',        domain: 'robots', difficulty: 2, sortOrder:  8, prerequisites: ['robo-06'],                   description: 'A microphone is a sensor that lets the robot hear sounds.' },
  { id: 'robo-09', name: 'Touch sensors',              domain: 'robots', difficulty: 2, sortOrder:  9, prerequisites: ['robo-06'],                   description: 'A sensor that tells the robot when it is touching something.' },
  { id: 'robo-10', name: 'Motors',                     domain: 'robots', difficulty: 3, sortOrder: 10, prerequisites: ['robo-04', 'robo-05'],        description: 'The parts that make a robot\u2019s wheels and arms move.' },
  { id: 'robo-11', name: 'Batteries',                  domain: 'robots', difficulty: 2, sortOrder: 11, prerequisites: ['robo-01'],                   description: 'Robots need stored power to run. Batteries hold that power.' },
  { id: 'robo-12', name: 'Remote-control robots',      domain: 'robots', difficulty: 3, sortOrder: 12, prerequisites: ['robo-01'],                   description: 'A robot that a person drives from far away with a controller.' },
  { id: 'robo-13', name: 'Self-driving cars',          domain: 'robots', difficulty: 4, sortOrder: 13, prerequisites: ['robo-06', 'robo-10'],        description: 'A car that uses sensors and motors to drive without a person.' },
  { id: 'robo-14', name: 'Drones',                     domain: 'robots', difficulty: 3, sortOrder: 14, prerequisites: ['robo-10'],                   description: 'A small flying robot with spinning blades.' },
  { id: 'robo-15', name: 'Factory robots',             domain: 'robots', difficulty: 4, sortOrder: 15, prerequisites: ['robo-10'],                   description: 'Big robot arms that build things in factories.' },
  { id: 'robo-16', name: 'Helper robots at home',      domain: 'robots', difficulty: 3, sortOrder: 16, prerequisites: ['robo-06'],                   description: 'Robots that clean floors or do chores at home.' },
  { id: 'robo-17', name: 'How robots are programmed',  domain: 'robots', difficulty: 4, sortOrder: 17, prerequisites: ['robo-01', 'comp-14'],        description: 'People write instructions (code) that tell a robot what to do.' },
];

// ============================================================
// AI (16 concepts)
// Abstract ideas → recognition → generation → ethics.
// Cross-domain edge: ai-01 depends on comp-01 (computers).
// ============================================================
const AI: ConceptSeed[] = [
  { id: 'ai-01', name: 'What is AI',                  domain: 'ai', difficulty: 2, sortOrder:  1, prerequisites: ['comp-01'],            description: 'AI stands for Artificial Intelligence — computers that can do things that seem smart.' },
  { id: 'ai-02', name: 'Smart vs not smart',          domain: 'ai', difficulty: 2, sortOrder:  2, prerequisites: ['ai-01'],              description: 'A calculator is not smart. An AI that can chat with you is smarter.' },
  { id: 'ai-03', name: 'Learning by examples',        domain: 'ai', difficulty: 3, sortOrder:  3, prerequisites: ['ai-01'],              description: 'AI gets better at a task by seeing lots of examples of it.' },
  { id: 'ai-04', name: 'Training data',               domain: 'ai', difficulty: 3, sortOrder:  4, prerequisites: ['ai-03'],              description: 'The examples we show an AI are called training data.' },
  { id: 'ai-05', name: 'Pattern recognition',         domain: 'ai', difficulty: 3, sortOrder:  5, prerequisites: ['ai-03'],              description: 'AI gets good at spotting patterns — things that look similar.' },
  { id: 'ai-06', name: 'Picture recognition',         domain: 'ai', difficulty: 3, sortOrder:  6, prerequisites: ['ai-05'],              description: 'An AI that can tell a cat from a dog in a photo.' },
  { id: 'ai-07', name: 'Speech recognition',          domain: 'ai', difficulty: 3, sortOrder:  7, prerequisites: ['ai-05'],              description: 'An AI that can turn your spoken words into text.' },
  { id: 'ai-08', name: 'Chatbots',                    domain: 'ai', difficulty: 3, sortOrder:  8, prerequisites: ['ai-07'],              description: 'An AI you can type to or talk to, and it answers back.' },
  { id: 'ai-09', name: 'AI that reads',               domain: 'ai', difficulty: 4, sortOrder:  9, prerequisites: ['ai-03'],              description: 'An AI that can read a story and tell you what it is about.' },
  { id: 'ai-10', name: 'AI that draws pictures',      domain: 'ai', difficulty: 4, sortOrder: 10, prerequisites: ['ai-04'],              description: 'An AI you can ask to draw a picture just by describing it.' },
  { id: 'ai-11', name: 'AI that makes music',         domain: 'ai', difficulty: 4, sortOrder: 11, prerequisites: ['ai-04'],              description: 'An AI that can make up new songs by learning from lots of music.' },
  { id: 'ai-12', name: 'AI playing games',            domain: 'ai', difficulty: 4, sortOrder: 12, prerequisites: ['ai-03'],              description: 'AIs can learn to play games like chess very well.' },
  { id: 'ai-13', name: 'AI mistakes',                 domain: 'ai', difficulty: 4, sortOrder: 13, prerequisites: ['ai-03'],              description: 'AI can be wrong. It only knows what it has seen before.' },
  { id: 'ai-14', name: 'AI fairness',                 domain: 'ai', difficulty: 5, sortOrder: 14, prerequisites: ['ai-13'],              description: 'AI should treat everyone the same way no matter who they are.' },
  { id: 'ai-15', name: 'AI and jobs',                 domain: 'ai', difficulty: 5, sortOrder: 15, prerequisites: ['ai-01'],              description: 'AI can help people do their jobs faster, and sometimes do new jobs.' },
  { id: 'ai-16', name: 'AI safety',                   domain: 'ai', difficulty: 5, sortOrder: 16, prerequisites: ['ai-01', 'ai-13'],     description: 'We build AI carefully so it helps people and does not cause harm.' },
];

export const KNOWLEDGE_GRAPH_SEED: ConceptSeed[] = [
  ...COMPUTERS,
  ...ROBOTS,
  ...AI,
];

// ============================================================
// Validation
// ============================================================
export interface SeedValidationIssue {
  kind: 'duplicate-id' | 'unknown-prereq' | 'self-prereq' | 'cycle';
  conceptId: string;
  detail: string;
}

/**
 * Validates structural integrity of the in-memory seed.
 * Catches: duplicate IDs, prereqs pointing at non-existent concepts,
 * self-prereqs, and cycles. Returns [] when the graph is clean.
 */
export function validateSeedGraph(
  seed: ConceptSeed[] = KNOWLEDGE_GRAPH_SEED
): SeedValidationIssue[] {
  const issues: SeedValidationIssue[] = [];
  const byId = new Map<string, ConceptSeed>();

  // Duplicate IDs
  for (const concept of seed) {
    if (byId.has(concept.id)) {
      issues.push({
        kind: 'duplicate-id',
        conceptId: concept.id,
        detail: `Concept id "${concept.id}" appears more than once in the seed.`,
      });
    }
    byId.set(concept.id, concept);
  }

  // Unknown / self prereqs
  for (const concept of seed) {
    for (const prereqId of concept.prerequisites) {
      if (prereqId === concept.id) {
        issues.push({
          kind: 'self-prereq',
          conceptId: concept.id,
          detail: `Concept "${concept.id}" lists itself as a prerequisite.`,
        });
        continue;
      }
      if (!byId.has(prereqId)) {
        issues.push({
          kind: 'unknown-prereq',
          conceptId: concept.id,
          detail: `Concept "${concept.id}" references unknown prerequisite "${prereqId}".`,
        });
      }
    }
  }

  // Cycle detection via DFS with 3-color marking
  const WHITE = 0; const GRAY = 1; const BLACK = 2;
  const color = new Map<string, number>();
  for (const c of seed) color.set(c.id, WHITE);

  const visit = (id: string, path: string[]): void => {
    if (color.get(id) === GRAY) {
      issues.push({
        kind: 'cycle',
        conceptId: id,
        detail: `Cycle detected: ${[...path, id].join(' -> ')}`,
      });
      return;
    }
    if (color.get(id) === BLACK) return;
    color.set(id, GRAY);
    const node = byId.get(id);
    if (node) {
      for (const prereqId of node.prerequisites) {
        if (byId.has(prereqId)) {
          visit(prereqId, [...path, id]);
        }
      }
    }
    color.set(id, BLACK);
  };

  for (const c of seed) {
    if (color.get(c.id) === WHITE) visit(c.id, []);
  }

  return issues;
}

// ============================================================
// Seeding
// ============================================================

/**
 * Idempotently upserts the full knowledge graph. Safe to re-run.
 * Validates before writing — throws on structural issues.
 */
export async function seedKnowledgeGraph(): Promise<{ created: number; updated: number }> {
  const issues = validateSeedGraph();
  if (issues.length > 0) {
    const lines = issues.map((i) => `  [${i.kind}] ${i.detail}`).join('\n');
    throw new Error(`Knowledge graph seed is invalid:\n${lines}`);
  }

  const prisma = getPrismaClient();
  let created = 0;
  let updated = 0;

  for (const concept of KNOWLEDGE_GRAPH_SEED) {
    // The `prerequisites` field is typed `string` in Prisma but the middleware
    // in client.ts auto-stringifies when we pass a JS array, so passing an
    // array here is correct at runtime. We cast through `unknown` to appease
    // the typecheck without touching the shared Prisma debt.
    const prereqPayload = concept.prerequisites as unknown as string;

    const existing = await prisma.concept.findUnique({ where: { id: concept.id } });

    await prisma.concept.upsert({
      where: { id: concept.id },
      create: {
        id: concept.id,
        name: concept.name,
        domain: concept.domain,
        description: concept.description,
        prerequisites: prereqPayload,
        difficulty: concept.difficulty,
        sortOrder: concept.sortOrder,
      },
      update: {
        name: concept.name,
        domain: concept.domain,
        description: concept.description,
        prerequisites: prereqPayload,
        difficulty: concept.difficulty,
        sortOrder: concept.sortOrder,
      },
    });

    if (existing) updated++;
    else created++;
  }

  return { created, updated };
}

// CLI entrypoint: `tsx src/db/seedKnowledgeGraph.ts`
// (process.argv check instead of import.meta — tsconfig targets CJS, where
// import.meta is a compile error; behavior under tsx is identical.)
if (process.argv[1]?.endsWith('seedKnowledgeGraph.ts')) {
  seedKnowledgeGraph()
    .then(({ created, updated }) => {
      // eslint-disable-next-line no-console
      console.log(
        `Knowledge graph seeded: ${created} created, ${updated} updated ` +
          `(${KNOWLEDGE_GRAPH_SEED.length} total across computers/robots/ai)`
      );
      process.exit(0);
    })
    .catch((err) => {
      // eslint-disable-next-line no-console
      console.error('Knowledge graph seed failed:', err);
      process.exit(1);
    });
}
