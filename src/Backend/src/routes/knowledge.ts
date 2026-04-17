/**
 * Knowledge Graph routes (Sprint 10 — "The Brain")
 *
 * Read-only views over the curriculum concept graph seeded in
 * src/db/seedKnowledgeGraph.ts. Consumed by the dev-pipeline tab shell
 * ("Knowledge Graph" tab), and later by S10-09 (`curriculum-architect`
 * skill) and S10-02 (concept-mastery tracking) for lookups.
 *
 * Endpoints:
 *   GET /api/v1/knowledge/concepts            → list all concepts
 *   GET /api/v1/knowledge/concepts/:id        → single concept + prereq objects
 *   GET /api/v1/knowledge/domains             → aggregate counts per domain
 *
 * Auth: uses the same userId check as pipeline routes. In dev mode the
 * auth middleware fills in firstUser.id, so these endpoints are reachable
 * from dev-pipeline.html without an explicit JWT.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateParams } from '@middleware/validate';
import { getChildMastery } from '@services/mastery/masteryTracker';

const conceptParamsSchema = z.object({
  id: z.string().min(1),
});

const masteryParamsSchema = z.object({
  childId: z.string().uuid(),
});

type ConceptParams = z.infer<typeof conceptParamsSchema>;
type MasteryParams = z.infer<typeof masteryParamsSchema>;

export async function knowledgeRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /knowledge/concepts — full list, optionally filtered by domain
  fastify.get<{ Querystring: { domain?: string } }>(
    '/concepts',
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { domain } = request.query;
      const prisma = getPrismaClient();

      const concepts = await prisma.concept.findMany({
        where: domain ? { domain } : undefined,
        orderBy: [{ domain: 'asc' }, { sortOrder: 'asc' }],
      });

      return reply.status(200).send({
        data: concepts,
        count: concepts.length,
      });
    }
  );

  // GET /knowledge/domains — aggregate concept counts per domain
  fastify.get('/domains', async (request, reply) => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }

    const prisma = getPrismaClient();
    const grouped = await prisma.concept.groupBy({
      by: ['domain'],
      _count: { _all: true },
      _min: { difficulty: true },
      _max: { difficulty: true },
    });

    const data = grouped.map((g) => ({
      domain: g.domain,
      count: g._count._all,
      minDifficulty: g._min.difficulty,
      maxDifficulty: g._max.difficulty,
    }));

    const total = data.reduce((sum, d) => sum + d.count, 0);

    return reply.status(200).send({ data, total });
  });

  // GET /knowledge/concepts/:id — single concept, prerequisites expanded to objects
  fastify.get<{ Params: ConceptParams }>(
    '/concepts/:id',
    { preHandler: validateParams(conceptParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { id } = request.params;
      const prisma = getPrismaClient();

      const concept = await prisma.concept.findUnique({ where: { id } });
      if (!concept) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'NotFound',
          message: `Concept '${id}' not found`,
        });
      }

      // prerequisites arrives as string[] via JSON middleware — expand to objects
      const prereqIds: string[] = Array.isArray((concept as any).prerequisites)
        ? ((concept as any).prerequisites as string[])
        : [];
      const prereqConcepts = prereqIds.length
        ? await prisma.concept.findMany({
            where: { id: { in: prereqIds } },
            select: { id: true, name: true, domain: true, difficulty: true },
          })
        : [];

      // Also surface the reverse edge: concepts that depend on this one.
      // Prereqs are JSON-text, so we can't query JSON containment in SQLite.
      // Cost is fine — 50 rows, read-mostly, cached by dev tool.
      const allConcepts = await prisma.concept.findMany({
        select: { id: true, name: true, domain: true, difficulty: true, prerequisites: true },
      });
      const dependents = allConcepts
        .filter((c) => {
          const prereqs = Array.isArray((c as any).prerequisites)
            ? ((c as any).prerequisites as string[])
            : [];
          return prereqs.includes(id);
        })
        .map(({ prerequisites: _p, ...rest }) => rest);

      return reply.status(200).send({
        data: {
          ...concept,
          prerequisiteConcepts: prereqConcepts,
          dependentConcepts: dependents,
        },
      });
    }
  );

  // S10-02: GET /knowledge/children/:childId/mastery
  // Per-concept mastery rows for one child, with decay applied on the fly.
  // Access control: caller must own the child (matches the pattern in /progress).
  fastify.get<{ Params: MasteryParams }>(
    '/children/:childId/mastery',
    { preHandler: validateParams(masteryParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const prisma = getPrismaClient();

      // Ownership check
      const child = await prisma.childProfile.findUnique({
        where: { id: childId },
        select: { userId: true },
      });
      if (!child) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'NotFound',
          message: `Child '${childId}' not found`,
        });
      }
      if (child.userId !== request.userId) {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'You do not have permission to view mastery for this child',
        });
      }

      const rows = await getChildMastery(childId);

      // Rollup by domain — useful for dashboards.
      const byDomain: Record<
        string,
        { count: number; avg: number; sum: number; introduced: number }
      > = {};
      for (const r of rows) {
        const d = (byDomain[r.domain] ??= { count: 0, avg: 0, sum: 0, introduced: 0 });
        d.count += 1;
        d.sum += r.effectiveConfidence;
        if (r.firstIntroduced) d.introduced += 1;
      }
      const domainRollup = Object.entries(byDomain).map(([domain, v]) => ({
        domain,
        conceptsTracked: v.count,
        conceptsIntroduced: v.introduced,
        avgEffectiveConfidence: v.count > 0 ? Number((v.sum / v.count).toFixed(3)) : 0,
      }));

      return reply.status(200).send({
        childId,
        data: rows.map((r) => ({
          ...r,
          // Round for nicer JSON payloads without losing meaningful precision.
          confidence: Number(r.confidence.toFixed(3)),
          effectiveConfidence: Number(r.effectiveConfidence.toFixed(3)),
        })),
        domainRollup,
        totalTracked: rows.length,
      });
    }
  );
}
