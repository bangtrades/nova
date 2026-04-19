/**
 * Parent Guidance routes (Sprint 10 — S10-04, "The Brain")
 *
 * Per-child parental controls consumed by the pipeline at generation time.
 *
 * Endpoints (nested under the /children prefix for COPPA-style ownership semantics):
 *   GET  /api/v1/children/:childId/guidance   → ParentGuidanceView (or zero-state)
 *   PUT  /api/v1/children/:childId/guidance   → patch-style upsert
 *   DELETE /api/v1/children/:childId/guidance → remove row (parent "reset")
 *
 * Auth: requires request.userId (dev middleware auto-fills firstUser.id).
 * Access control: caller must own the child.
 */
import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { getPrismaClient } from '@db/client';
import { validateParams, validateBody } from '@middleware/validate';
import {
  MAX_DIFFICULTY_OFFSET,
  defaultGuidance,
  deleteGuidance,
  getGuidance,
  upsertGuidance,
} from '@services/guidance/parentGuidance';

const childParamsSchema = z.object({
  childId: z.string().uuid(),
});

type ChildParams = z.infer<typeof childParamsSchema>;

/**
 * PUT body schema. All fields optional so callers can patch one at a time.
 * We use `.passthrough()` nowhere — unknown keys are silently dropped by zod's
 * default behavior, and any misshapen nested objects are further normalized
 * by the service's sanitizers.
 */
const guidanceBodySchema = z
  .object({
    topicFocus: z.array(z.string()).max(64).optional(),
    topicAvoid: z.array(z.string()).max(64).optional(),
    difficultyOffset: z
      .number()
      .int()
      .gte(-MAX_DIFFICULTY_OFFSET)
      .lte(MAX_DIFFICULTY_OFFSET)
      .optional(),
    contentBoundaries: z
      .object({
        disallowedKeywords: z.array(z.string()).max(128).optional(),
        allowedTags: z.array(z.string()).max(128).optional(),
      })
      .optional(),
    dailySessionLimitMinutes: z
      .number()
      .int()
      .min(0)
      .max(24 * 60)
      .nullable()
      .optional(),
    singleSessionLimitMinutes: z
      .number()
      .int()
      .min(0)
      .max(24 * 60)
      .nullable()
      .optional(),
  })
  // Refuse entirely-empty bodies — a no-op request should be a GET, not a PUT.
  .refine((v) => Object.keys(v).length > 0, {
    message: 'At least one guidance field must be provided',
  });

type GuidanceBody = z.infer<typeof guidanceBodySchema>;

async function checkChildOwnership(
  childId: string,
  userId: string
): Promise<
  | { ok: true }
  | { ok: false; status: number; error: string; message: string }
> {
  const prisma = getPrismaClient();
  const child = await prisma.childProfile.findUnique({
    where: { id: childId },
    select: { userId: true },
  });
  if (!child) {
    return {
      ok: false,
      status: 404,
      error: 'NotFound',
      message: `Child '${childId}' not found`,
    };
  }
  if (child.userId !== userId) {
    return {
      ok: false,
      status: 403,
      error: 'Forbidden',
      message: 'You do not have permission to manage guidance for this child',
    };
  }
  return { ok: true };
}

export async function parentGuidanceRoutes(
  fastify: FastifyInstance
): Promise<void> {
  // GET /children/:childId/guidance
  // Returns the stored guidance, or a zero-state payload if none exists.
  fastify.get<{ Params: ChildParams }>(
    '/:childId/guidance',
    { preHandler: validateParams(childParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const ownership = await checkChildOwnership(childId, request.userId);
      if (!ownership.ok) {
        return reply.status(ownership.status).send({
          statusCode: ownership.status,
          error: ownership.error,
          message: ownership.message,
        });
      }

      const view = await getGuidance(childId);
      if (!view) {
        return reply.status(200).send({
          data: { ...defaultGuidance(childId), hasGuidance: false },
        });
      }
      return reply.status(200).send({ data: { ...view, hasGuidance: true } });
    }
  );

  // PUT /children/:childId/guidance
  // Patch-style upsert — any omitted field preserves its existing value.
  fastify.put<{ Params: ChildParams; Body: GuidanceBody }>(
    '/:childId/guidance',
    {
      preHandler: [
        validateParams(childParamsSchema),
        validateBody(guidanceBodySchema),
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

      const { childId } = request.params;
      const ownership = await checkChildOwnership(childId, request.userId);
      if (!ownership.ok) {
        return reply.status(ownership.status).send({
          statusCode: ownership.status,
          error: ownership.error,
          message: ownership.message,
        });
      }

      const view = await upsertGuidance(childId, request.body, request.userId);
      return reply.status(200).send({ data: { ...view, hasGuidance: true } });
    }
  );

  // DELETE /children/:childId/guidance — parent-facing reset. Idempotent.
  fastify.delete<{ Params: ChildParams }>(
    '/:childId/guidance',
    { preHandler: validateParams(childParamsSchema) },
    async (request, reply) => {
      if (!request.userId) {
        return reply.status(401).send({
          statusCode: 401,
          error: 'Unauthorized',
          message: 'Missing authentication token',
        });
      }

      const { childId } = request.params;
      const ownership = await checkChildOwnership(childId, request.userId);
      if (!ownership.ok) {
        return reply.status(ownership.status).send({
          statusCode: ownership.status,
          error: ownership.error,
          message: ownership.message,
        });
      }

      await deleteGuidance(childId);
      return reply.status(204).send();
    }
  );
}
