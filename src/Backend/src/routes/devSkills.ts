/**
 * Dev Console — Skill Engine routes (Sprint 10 — S10-06 / S10-07)
 *
 * These endpoints back the "Skills" tab on `public/dev-pipeline.html`.
 * They are read-only / dry-run surfaces intended for local QA and
 * operator troubleshooting. The render endpoint does NOT call the LLM
 * — it just produces the exact system/user prompts the pipeline would
 * submit, along with the SkillPromptMeta (age profile used, progression
 * delta, difficulty bucket). That's everything the operator needs to
 * verify the sliding-scale behavior without burning LLM credits.
 *
 * Endpoints:
 *   GET  /api/v1/dev/skills                  — list all manifests
 *   GET  /api/v1/dev/skills/:name            — single manifest + file inventory
 *   POST /api/v1/dev/skills/:name/render     — dry-run render (no LLM)
 *   POST /api/v1/dev/skills/:name/reload     — dev-only, reload from disk
 *
 * Auth: requires request.userId. No per-child ownership check on
 * list/render — the skill definitions are not child-scoped and contain
 * no PII. If the caller passes ?childId=<uuid> to render, an ownership
 * check gates the real-context load. In synthetic mode (no childId),
 * any authenticated user can render — this is the primary Dev Console
 * workflow.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { validateBody, validateParams } from '@middleware/validate';
import { getPrismaClient } from '@db/client';
import { getSkillRegistry } from '@services/skills/registry';
import type { ChildContext } from '@services/skills/types';
import {
  computeEffectiveAge,
  computeProgressionBreakdown,
} from '@services/skills/progression';
import { buildSessionContext } from '@services/context/sessionContext';
import {
  defaultGuidance,
  getGuidanceOrDefault,
} from '@services/guidance/parentGuidance';

// -----------------------------------------------------------------------
// Schemas
// -----------------------------------------------------------------------

/**
 * Render request body. Two modes, mixed freely:
 *   - `childId` (+ ownership) loads the child's real session context and
 *     parent guidance as the base.
 *   - `ctxOverrides` lets the operator stomp any field of ChildContext.
 * Renders with the merged context. `inputs` is passed through verbatim.
 */
const renderBodySchema = z
  .object({
    childId: z.string().uuid().optional(),
    // Arbitrary partial ChildContext — the registry's normalizer fills in
    // whatever is missing. We validate the few fields we need to trust.
    ctxOverrides: z
      .object({
        ageYears: z.number().int().min(2).max(18).optional(),
        effectiveAgeYears: z.number().min(2).max(18).optional(),
        progressionDelta: z.number().min(-1.5).max(1.5).optional(),
        difficultyOffset: z.number().int().min(-2).max(2).optional(),
        /**
         * Teaching-strategy dials — let operators flip modality /
         * conceptType to preview how the modalityNote partial branches
         * for a given child. S10-07 — R5.
         */
        modality: z.enum(['visual', 'auditory', 'kinesthetic']).optional(),
        conceptType: z
          .enum([
            'vocabulary',
            'abstract',
            'process',
            'comparison',
            'causeEffect',
            'factual',
          ])
          .optional(),
        interestTopics: z.array(z.string().max(60)).max(20).optional(),
        parentGuidance: z
          .object({
            topicFocus: z.array(z.string()).max(20).optional(),
            topicAvoid: z.array(z.string()).max(20).optional(),
            contentBoundaries: z
              .object({
                disallowedKeywords: z.array(z.string()).max(40).optional(),
                allowedTags: z.array(z.string()).max(40).optional(),
              })
              .optional(),
          })
          .optional(),
        mastery: z
          .object({
            averageScore: z.number().min(0).max(1),
            totalAttempts: z.number().int().min(0),
          })
          .optional(),
        engagement: z
          .object({
            recentQuizWinRate: z.number().min(0).max(1),
            preferredCardTypes: z.array(z.unknown()).optional(),
          })
          .optional(),
        recentSessionEvents: z
          .object({
            flow: z.number().int().min(0),
            frustration: z.number().int().min(0),
            abandon: z.number().int().min(0),
          })
          .optional(),
      })
      .partial()
      .default({}),
    inputs: z.record(z.unknown()).default({}),
    /**
     * When true, the endpoint also returns the progression breakdown the
     * registry computed — handy for the Dev Console "Progression" panel.
     */
    includeProgressionBreakdown: z.boolean().default(true),
  })
  .strict();

type RenderBody = z.infer<typeof renderBodySchema>;

const skillNameParam = z.object({ name: z.string().min(1).max(80) });

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------

/**
 * Build a best-effort ChildContext for the render endpoint. Pure-
 * enough for a dry-run: real session context + real parent guidance
 * when a valid, owned childId is supplied; otherwise a zero-state
 * context that downstream normalization can render against.
 *
 * Separated so tests can poke at it directly.
 */
export async function buildDevRenderContext(
  userId: string,
  body: RenderBody
): Promise<{ ctx: ChildContext; childIdResolved: string | null; childOwned: boolean | null }> {
  const overrides = body.ctxOverrides ?? {};
  let childIdResolved: string | null = null;
  let childOwned: boolean | null = null;

  // Base: zero-state synthetic child.
  let base: ChildContext = {
    childId: body.childId ?? 'synthetic-child',
    ageYears: overrides.ageYears ?? 6,
    effectiveAgeYears:
      overrides.effectiveAgeYears ??
      computeEffectiveAge(overrides.ageYears ?? 6, overrides.progressionDelta ?? 0),
    progressionDelta: overrides.progressionDelta ?? 0,
    parentGuidance: {
      ...defaultGuidance(body.childId ?? 'synthetic-child'),
      topicFocus: overrides.parentGuidance?.topicFocus ?? [],
      topicAvoid: overrides.parentGuidance?.topicAvoid ?? [],
      contentBoundaries: {
        disallowedKeywords:
          overrides.parentGuidance?.contentBoundaries?.disallowedKeywords ?? [],
        allowedTags:
          overrides.parentGuidance?.contentBoundaries?.allowedTags ?? [],
      },
    },
    sessionContext: {
      ianaTimezone: 'UTC',
      computedAt: new Date().toISOString(),
      localClock: '',
      localDayOfWeek: '',
      timeOfDay: 'morning',
      currentSessionMinutes: null,
      lessonsCompletedToday: 0,
      currentStreak: 0,
      recentQuizResults: [],
    },
    interestTopics: overrides.interestTopics ?? [],
    teachingStrategy: {
      conceptType: overrides.conceptType ?? 'abstract',
      modality: overrides.modality ?? 'auditory',
      rankedCardTypes: [],
    },
    difficultyOffset: overrides.difficultyOffset ?? 0,
    mastery: overrides.mastery as ChildContext['mastery'],
    engagement: overrides.engagement as ChildContext['engagement'],
    recentSessionEvents: overrides.recentSessionEvents,
  };

  // If a real childId was passed, verify ownership then layer real
  // session context + guidance. Overrides still win on top.
  if (body.childId) {
    const prisma = getPrismaClient();
    const child = await prisma.childProfile.findUnique({
      where: { id: body.childId },
      select: { id: true, userId: true, birthDate: true },
    });
    if (!child) {
      const err = new Error('Child profile not found') as Error & {
        statusCode?: number;
      };
      err.statusCode = 404;
      throw err;
    }
    childIdResolved = child.id;
    childOwned = child.userId === userId;
    if (!childOwned) {
      const err = new Error(
        'You do not have permission to render prompts for this child'
      ) as Error & { statusCode?: number };
      err.statusCode = 403;
      throw err;
    }

    const [sessionContext, guidance] = await Promise.all([
      buildSessionContext(child.id),
      getGuidanceOrDefault(child.id),
    ]);

    // Derive chronological age from birthDate if the caller didn't
    // override it — keeps the "render as if this real kid asked" path
    // honest to the profile gate.
    const realAge =
      overrides.ageYears ??
      (child.birthDate
        ? Math.max(
            2,
            Math.floor(
              (Date.now() - new Date(child.birthDate).getTime()) /
                (1000 * 60 * 60 * 24 * 365.25)
            )
          )
        : base.ageYears);

    base = {
      ...base,
      childId: child.id,
      ageYears: realAge,
      effectiveAgeYears:
        overrides.effectiveAgeYears ??
        computeEffectiveAge(realAge, overrides.progressionDelta ?? 0),
      parentGuidance: {
        ...guidance,
        // Overrides win on top so operators can experiment.
        topicFocus: overrides.parentGuidance?.topicFocus ?? guidance.topicFocus,
        topicAvoid: overrides.parentGuidance?.topicAvoid ?? guidance.topicAvoid,
        contentBoundaries: {
          disallowedKeywords:
            overrides.parentGuidance?.contentBoundaries?.disallowedKeywords ??
            guidance.contentBoundaries?.disallowedKeywords ??
            [],
          allowedTags:
            overrides.parentGuidance?.contentBoundaries?.allowedTags ??
            guidance.contentBoundaries?.allowedTags ??
            [],
        },
      },
      sessionContext,
      difficultyOffset:
        overrides.difficultyOffset ?? guidance.difficultyOffset ?? 0,
    };
  }

  return { ctx: base, childIdResolved, childOwned };
}

// -----------------------------------------------------------------------
// Routes
// -----------------------------------------------------------------------

export async function devSkillsRoutes(fastify: FastifyInstance): Promise<void> {
  // Ensure registry is loaded lazily — in production index.ts will call
  // registry.load() at boot; this fallback is for tests and repl sessions.
  async function ensureLoaded(): Promise<void> {
    const reg = getSkillRegistry();
    if (!reg.isLoaded()) await reg.load();
  }

  // GET /dev/skills — list every registered skill's manifest.
  fastify.get('/skills', async (request, reply) => {
    if (!request.userId) {
      return reply.status(401).send({
        statusCode: 401,
        error: 'Unauthorized',
        message: 'Missing authentication token',
      });
    }
    await ensureLoaded();
    const reg = getSkillRegistry();
    const rows = reg.list().map((s) => ({
      name: s.manifest.name,
      version: s.manifest.version,
      description: s.manifest.description,
      modelHint: s.manifest.modelHint,
      temperatureHint: s.manifest.temperatureHint,
      ageProfiles: s.manifest.ageProfiles ?? [],
      difficulties: s.manifest.difficulties ?? [],
      handlesConceptTypes: s.manifest.handlesConceptTypes ?? [],
      inputs: s.manifest.inputs,
      hasOutputSchema: Boolean(s.outputSchema),
    }));
    return reply.status(200).send({ data: rows, count: rows.length });
  });

  // GET /dev/skills/:name — single manifest (same shape as list row).
  fastify.get<{ Params: { name: string } }>(
    '/skills/:name',
    { preHandler: validateParams(skillNameParam) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }
      await ensureLoaded();
      const reg = getSkillRegistry();
      if (!reg.has(request.params.name)) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `No skill named "${request.params.name}"`,
        });
      }
      const skill = reg.get(request.params.name);
      return reply.status(200).send({
        data: {
          manifest: skill.manifest,
          hasOutputSchema: Boolean(skill.outputSchema),
        },
      });
    }
  );

  // POST /dev/skills/:name/render — dry-run render, no LLM call.
  fastify.post<{ Params: { name: string }; Body: RenderBody }>(
    '/skills/:name/render',
    {
      preHandler: [
        validateParams(skillNameParam),
        validateBody(renderBodySchema),
      ],
    },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }
      await ensureLoaded();
      const reg = getSkillRegistry();
      if (!reg.has(request.params.name)) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `No skill named "${request.params.name}"`,
        });
      }

      try {
        const { ctx, childIdResolved, childOwned } = await buildDevRenderContext(
          request.userId,
          request.body
        );

        const skill = reg.get(request.params.name);
        const out = skill.buildPrompt({ ctx, inputs: request.body.inputs });

        const breakdown = request.body.includeProgressionBreakdown
          ? computeProgressionBreakdown({
              mastery: ctx.mastery,
              engagement: ctx.engagement,
              recentSessionEvents: ctx.recentSessionEvents,
              parentDifficultyOffset: ctx.difficultyOffset,
            })
          : null;

        return reply.status(200).send({
          data: {
            system: out.system,
            user: out.user,
            meta: out.meta,
            progressionBreakdown: breakdown,
            context: {
              childId: childIdResolved,
              childOwned,
              ageYears: ctx.ageYears,
              effectiveAgeYears: ctx.effectiveAgeYears,
              progressionDelta: ctx.progressionDelta,
              difficultyOffset: ctx.difficultyOffset,
            },
          },
        });
      } catch (err) {
        const status = (err as { statusCode?: number })?.statusCode;
        if (status === 404 || status === 403) {
          return reply.status(status).send({
            statusCode: status,
            error: status === 404 ? 'Not Found' : 'Forbidden',
            message: err instanceof Error ? err.message : 'Error',
          });
        }
        fastify.log.error({ err }, 'dev/skills render failed');
        return reply.status(400).send({
          statusCode: 400,
          error: 'Bad Request',
          message: err instanceof Error ? err.message : 'Render failed',
        });
      }
    }
  );

  // POST /dev/skills/:name/reload — dev-only hot-reload.
  //
  // In production we rely on server restart; in dev this lets the
  // operator edit a prompt.md on disk and see the change without a
  // full restart. We gate behind NODE_ENV=development (or DEV mode
  // implied by NOVA_SKILLS_DEFS_DIR env).
  fastify.post<{ Params: { name: string } }>(
    '/skills/:name/reload',
    { preHandler: validateParams(skillNameParam) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }
      if (process.env.NODE_ENV === 'production') {
        return reply.status(403).send({
          statusCode: 403,
          error: 'Forbidden',
          message: 'Skill reload is disabled in production',
        });
      }
      await ensureLoaded();
      const reg = getSkillRegistry();
      if (!reg.has(request.params.name)) {
        return reply.status(404).send({
          statusCode: 404,
          error: 'Not Found',
          message: `No skill named "${request.params.name}"`,
        });
      }
      try {
        await reg.reload(request.params.name);
        return reply.status(200).send({
          data: { reloaded: request.params.name, at: new Date().toISOString() },
        });
      } catch (err) {
        fastify.log.error({ err }, 'dev/skills reload failed');
        return reply.status(400).send({
          statusCode: 400,
          error: 'Bad Request',
          message: err instanceof Error ? err.message : 'Reload failed',
        });
      }
    }
  );
}
