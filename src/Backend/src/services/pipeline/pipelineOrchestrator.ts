/**
 * Pipeline Orchestrator Service
 *
 * Orchestrates the Grand Architect content pipeline:
 *   Stage 1: Scrape URL
 *   Stage 2: Analyze content (topic + age + safety)
 *   Stage 3: Decompose into concept atoms        (S9-06)
 *   Stage 4: Generate cards per atom
 *   Stage 5: Orchestrate assets (images + TTS)   — fire-and-forget after save
 *   Stage 6: Quality gate + selective regen      (S9-09)
 *
 * S9-10 (in-process job hardening): the orchestrator wraps every LLM-facing
 * stage in a timeout + bounded retry, so a single slow or flaky call can't
 * hang the whole pipeline. The shared helpers (`runStage`, `withTimeout`,
 * `isTransient`) live in `pipelineUtils.ts` so they can be unit-tested
 * without spinning up an LLM mock. A full BullMQ/Redis job queue is deferred
 * to the deployment sprint — per the Sprint 9 plan.
 */

import { getPrismaClient, toJsonColumn } from '@db/client';
import { scrapeUrl } from './scraper';
import { analyzeContent } from './contentAnalyzer';
import { decomposeConcepts, type ConceptDecomposition } from './conceptDecomposer';
import {
  generateCards,
  generateCardsWithSkills,
  isSkillEngineStage4Enabled,
  type GeneratedCard,
} from './cardGenerator';
import { runQualityGate, type QualityReport } from './qualityGate';
import { processLessonAssets } from '../assets/assetJobProcessor';
import { getConfig } from '@config';
import { runStage, errMsg, type RunStageOptions } from './pipelineUtils';
import {
  getGuidanceOrDefault,
  type ParentGuidanceView,
} from '@services/guidance/parentGuidance';
import {
  buildSessionContext,
  type SessionContext,
} from '@services/context/sessionContext';
import { buildChildContext } from './childContextBuilder';
import type { ChildContext } from '@services/skills/types';
import type { AtomTrace, SkipReason } from './skillRouter';
import {
  routeDecomposition,
  isSkillEngineStage3Enabled,
  type DecompositionTrace,
} from './decompositionRouter';
import type { Prisma } from '@prisma/client';

export interface PipelineResult {
  ingestId: string;
  lessonId: string;
  cardCount: number;
  status: 'completed' | 'partial';
  message: string;
  regeneratedCardIndexes?: number[];
  qualityScore?: number;
  /** S10-12 · R5 — whether the skill engine ran at Stage 4. */
  skillEngineUsed?: boolean;
  /** Atoms the skill engine couldn't handle (mapping missing / validator failed). */
  skillSkippedAtoms?: Array<{ atomId: string; reason: SkipReason }>;
  /** Full per-atom trace for Dev Console (R7). Present only when skill engine ran. */
  skillTraces?: AtomTrace[];
  /**
   * S12-05 — curriculum-architect trace from Stage 3, present whenever the
   * Stage-3 skill engine path was attempted (success OR controlled failure).
   * Absent when the skill engine was skipped outright (no childContext, flag
   * off, or missing analysis fields).
   */
  decompositionTrace?: DecompositionTrace;
}

export interface PipelineStepResult {
  status:
    | 'scraped'
    | 'analyzing'
    | 'decomposing'
    | 'generating'
    | 'quality_gate'
    | 'completed'
    | 'failed';
  error?: string;
}

// Default timeouts (ms) for each LLM-facing stage.
//
// S12-10 bump — the Stage-4 generate stage loops through every decomposition
// atom and fires a serial LLM call per atom. A 6-atom decomposition × ~5–10s
// per LLM round-trip puts the generate stage at 30–60s just for network
// time, plus validation + potential Zod retry. Previously this was masked
// because `concept` atoms skipped instantly (no LLM call), so a typical
// decomposition only made 2–3 real calls and finished inside the 45s
// budget. After the S12-10 concept→story-writer routing fix, ALL atoms
// make real LLM calls — the 45s ceiling is too tight. Bumping to 120s
// per stage + 300s full-pipeline budget gives head-room for 6-atom
// decompositions with one retry-on-Zod cycle, which is the realistic
// worst case. If throughput becomes a real concern, parallelize the
// per-atom loop in `generateCardsWithSkills` (Promise.all over the atoms)
// in a follow-up — atom generation is independent so fan-out is safe.
const DEFAULTS = {
  stageTimeoutMs: 120_000,
  pipelineTimeoutMs: 300_000,
  maxAttempts: 2, // one retry on transient failure
  retryBackoffMs: 750,
} as const;

/**
 * S12-09 — structured event stream a caller can subscribe to. The Dev
 * Console's Author Lesson tab wires this to SSE (`reply.raw.write('data:
 * {json}\n\n')`) so the user sees per-stage pills light up as the
 * pipeline progresses. Keeping the events as a discriminated union
 * (stage + status) means the frontend can ship one switch-based
 * renderer without having to sniff property shapes.
 */
export type PipelineStageEvent =
  | { stage: 'scrape'; status: 'start' }
  | { stage: 'scrape'; status: 'done'; bytes: number; title: string }
  | { stage: 'scrape'; status: 'failed'; error: string }
  | { stage: 'analyze'; status: 'start' }
  | { stage: 'analyze'; status: 'done'; topic: string; ageAppropriate: boolean; suggestedStage: number }
  | { stage: 'analyze'; status: 'failed'; error: string }
  | { stage: 'analyze'; status: 'blocked'; reason: string } // age-inappropriate content
  | { stage: 'decompose'; status: 'start'; source: 'skill-engine' | 'legacy' }
  | { stage: 'decompose'; status: 'done'; source: 'skill-engine' | 'legacy'; atomCount: number; validatorStatus?: string; retryCount?: number }
  | { stage: 'decompose'; status: 'failed'; source: 'skill-engine' | 'legacy'; error: string }
  | { stage: 'generate'; status: 'start'; source: 'skill-engine' | 'legacy'; atomCount: number }
  | { stage: 'generate'; status: 'done'; source: 'skill-engine' | 'legacy'; cardCount: number; skippedCount?: number; retryOkCount?: number; retryFailedCount?: number }
  | { stage: 'generate'; status: 'failed'; source: 'skill-engine' | 'legacy'; error: string }
  | { stage: 'quality'; status: 'start' }
  | { stage: 'quality'; status: 'done'; regeneratedCount: number; overallScore?: number }
  | { stage: 'quality'; status: 'failed'; error: string }
  | { stage: 'persist'; status: 'start' }
  | { stage: 'persist'; status: 'done'; lessonId: string; cardCount: number }
  | { stage: 'pipeline'; status: 'done'; lessonId: string; cardCount: number; elapsedMs: number }
  | { stage: 'pipeline'; status: 'failed'; error: string };

export interface PipelineOptions {
  stageTimeoutMs?: number;
  pipelineTimeoutMs?: number;
  maxAttempts?: number;
  skipQualityGate?: boolean;
  /**
   * S10-04 / S10-05: when set, the orchestrator pulls the child's parent
   * guidance + session context and injects them into every LLM prompt.
   * Without a childId the pipeline behaves as before (generic prompts).
   */
  childId?: string;
  /**
   * S12-09 — optional callback invoked at every stage boundary. The Dev
   * Console Author Lesson tab uses this to drive SSE output. The
   * callback is synchronous + fire-and-forget from the orchestrator's
   * perspective — if the caller's handler throws, the error is swallowed
   * so a broken SSE connection can't crash the pipeline mid-run.
   */
  onStageEvent?: (event: PipelineStageEvent) => void;
}

/** Internal: emit helper that swallows callback errors (SSE disconnect shouldn't kill the pipeline). */
function emit(opts: PipelineOptions, event: PipelineStageEvent): void {
  if (!opts.onStageEvent) return;
  try {
    opts.onStageEvent(event);
  } catch (err) {
    // Swallow — a broken SSE connection or a buggy listener must not
    // take down the pipeline. The orchestrator's state machine is the
    // source of truth; event streaming is advisory.
    console.warn(`[Pipeline] onStageEvent handler threw: ${errMsg(err)}`);
  }
}

/**
 * Run the full content pipeline for an existing UrlIngest row.
 */
export async function runPipeline(
  userId: string,
  ingestId: string,
  pathId?: string,
  options: PipelineOptions = {}
): Promise<PipelineResult> {
  const prisma = getPrismaClient();
  const opts = { ...DEFAULTS, ...options };
  const stageOpts: Partial<RunStageOptions> = {
    stageTimeoutMs: opts.stageTimeoutMs,
    maxAttempts: opts.maxAttempts,
    retryBackoffMs: opts.retryBackoffMs,
  };

  const pipelineStart = Date.now();

  try {
    const ingest = await prisma.urlIngest.findUnique({ where: { id: ingestId } });
    if (!ingest) throw new Error('Ingest not found');
    if (ingest.userId !== userId) throw new Error('Unauthorized');

    // S10-04 / S10-05: fetch parent guidance + session context once up-front so
    // every downstream LLM stage sees the same view. Failures here must NEVER
    // take down the pipeline — a missing guidance row or a timezone lookup
    // error degrades to "no preamble", which is the existing Sprint 9 behavior.
    let guidance: ParentGuidanceView | null = null;
    let sessionContext: SessionContext | null = null;
    let childContext: ChildContext | null = null;
    if (opts.childId) {
      try {
        // Verify the caller actually owns the child before we read its profile.
        const child = await prisma.childProfile.findUnique({
          where: { id: opts.childId },
          select: { userId: true },
        });
        if (child?.userId === userId) {
          guidance = await getGuidanceOrDefault(opts.childId);
          sessionContext = await buildSessionContext(opts.childId);
        } else if (child) {
          console.warn(
            `[Pipeline] childId=${opts.childId} not owned by userId=${userId} — skipping guidance/context`
          );
        } else {
          console.warn(`[Pipeline] childId=${opts.childId} not found — skipping guidance/context`);
        }
      } catch (err) {
        console.warn(`[Pipeline] Failed to load guidance/context: ${errMsg(err)}`);
      }

      // S10-12 · R5 — assemble the ChildContext the skill engine wants.
      // Pass the already-loaded guidance/sessionContext to avoid a duplicate
      // DB hit. A build failure here must never kill the pipeline; we just
      // skip the skill path and fall back to the legacy generator.
      try {
        const built = await buildChildContext({
          userId,
          childId: opts.childId,
          guidance,
          sessionContext,
          strict: false,
        });
        if (built.degradedReason === 'ok' && built.childOwned) {
          childContext = built.ctx;
        } else {
          console.warn(
            `[Pipeline] childContextBuilder degraded: ${built.degradedReason} — skill engine disabled for this run`
          );
        }
      } catch (err) {
        console.warn(`[Pipeline] Failed to build child context: ${errMsg(err)}`);
      }
    }

    // Stage 1: Scrape ────────────────────────────────────────────────────
    emit(opts, { stage: 'scrape', status: 'start' });
    const scraped = await runStage('scrape', () => scrapeUrl(ingest.url), stageOpts).catch(
      async (err) => {
        await updateIngestStatus(ingestId, 'failed');
        emit(opts, { stage: 'scrape', status: 'failed', error: errMsg(err) });
        throw new Error(`Scrape failed: ${errMsg(err)}`);
      }
    );
    emit(opts, {
      stage: 'scrape',
      status: 'done',
      bytes: scraped.content.length,
      title: scraped.title,
    });

    await prisma.urlIngest.update({
      where: { id: ingestId },
      data: { rawContent: scraped.content, status: 'scraped' },
    });

    // Stage 2: Analyze content (with internal safety second-pass) ────────
    await updateIngestStatus(ingestId, 'analyzing');
    emit(opts, { stage: 'analyze', status: 'start' });
    const analysis = await runStage(
      'analyze',
      () => analyzeContent(userId, scraped),
      stageOpts
    ).catch(async (err) => {
      await updateIngestStatus(ingestId, 'failed');
      emit(opts, { stage: 'analyze', status: 'failed', error: errMsg(err) });
      throw new Error(`Analysis failed: ${errMsg(err)}`);
    });

    await prisma.urlIngest.update({
      where: { id: ingestId },
      data: {
        aiAnalysis: toJsonColumn(analysis),
        status: 'analyzing',
      },
    });

    emit(opts, {
      stage: 'analyze',
      status: 'done',
      topic: analysis.topic,
      ageAppropriate: analysis.ageAppropriate,
      suggestedStage: analysis.suggestedStage,
    });

    if (!analysis.ageAppropriate) {
      await updateIngestStatus(ingestId, 'completed');
      emit(opts, {
        stage: 'analyze',
        status: 'blocked',
        reason: analysis.safetyFlags.join(', '),
      });
      return {
        ingestId,
        lessonId: '',
        cardCount: 0,
        status: 'completed',
        message: `Content not age-appropriate: ${analysis.safetyFlags.join(', ')}`,
      };
    }

    // Stage 3: Concept decomposition (S9-06 → S12-05) ────────────────────
    // S12-05 — when we have a ChildContext AND the Stage-3 feature flag is
    // on, route through the curriculum-architect skill. On controlled
    // failure (Zod exhausted / skill-runtime-error / missing-input / parse
    // error) we fall back to the legacy heuristic `decomposeConcepts()`.
    // Transient LLM errors still bubble via `runStage` + its retry layer,
    // and a total Stage-3 failure (both paths) is non-fatal — Stage 4's
    // legacy generator tolerates `decomposition = undefined`.
    await updateIngestStatus(ingestId, 'decomposing');
    let decomposition: ConceptDecomposition | undefined;
    let decompositionTrace: DecompositionTrace | undefined;
    const useSkillEngineStage3 =
      !!opts.childId && !!childContext && isSkillEngineStage3Enabled();

    if (useSkillEngineStage3 && childContext) {
      emit(opts, { stage: 'decompose', status: 'start', source: 'skill-engine' });
      try {
        const routeResult = await runStage(
          'decompose',
          () =>
            routeDecomposition({
              userId,
              baseContext: childContext!,
              analysis,
              scraped,
            }),
          stageOpts
        );
        decompositionTrace = routeResult.trace;
        if (routeResult.kind === 'ok') {
          decomposition = routeResult.decomposition;
          emit(opts, {
            stage: 'decompose',
            status: 'done',
            source: 'skill-engine',
            atomCount: decomposition.atoms.length,
            validatorStatus: routeResult.trace.validatorStatus,
            retryCount: routeResult.trace.retryCount,
          });
        } else {
          console.warn(
            `[Pipeline] Stage-3 skill engine failed (${routeResult.reason}); falling back to legacy decomposeConcepts. Detail: ${routeResult.trace.error ?? 'n/a'}`
          );
          emit(opts, {
            stage: 'decompose',
            status: 'failed',
            source: 'skill-engine',
            error: `${routeResult.reason}: ${routeResult.trace.error ?? 'n/a'}`,
          });
        }
      } catch (err) {
        // Transient exhaustion from runStage — skill-engine path is out.
        // Legacy fallback below still gets a shot.
        console.warn(
          `[Pipeline] Stage-3 skill engine threw transiently; falling back: ${errMsg(err)}`
        );
        emit(opts, {
          stage: 'decompose',
          status: 'failed',
          source: 'skill-engine',
          error: errMsg(err),
        });
      }
    }

    if (!decomposition) {
      emit(opts, { stage: 'decompose', status: 'start', source: 'legacy' });
      try {
        decomposition = await runStage(
          'decompose',
          () => decomposeConcepts(userId, analysis, scraped, guidance, sessionContext),
          stageOpts
        );
        emit(opts, {
          stage: 'decompose',
          status: 'done',
          source: 'legacy',
          atomCount: decomposition.atoms.length,
        });
      } catch (err) {
        // Non-fatal: the card generator has a legacy code path that works
        // without a decomposition. Log and continue.
        console.warn(`[Pipeline] Decomposition failed, falling back: ${errMsg(err)}`);
        emit(opts, {
          stage: 'decompose',
          status: 'failed',
          source: 'legacy',
          error: errMsg(err),
        });
      }
    }

    // Stage 4: Card generation ───────────────────────────────────────────
    // S10-12 · R4/R5 — when we have a valid ChildContext AND a decomposition
    // AND the feature flag is on, route per-atom through the skill engine
    // (story-writer / quiz-maker) with Zod-validated outputs. Atoms the engine
    // can't handle (no mapping, validator exhausted, etc.) fall back to the
    // legacy monolithic generator inside `generateCardsWithSkills`.
    await updateIngestStatus(ingestId, 'generating');
    let cards: GeneratedCard[];
    let skillEngineUsed = false;
    let skillTraces: AtomTrace[] | undefined;
    let skillSkippedAtoms: Array<{ atomId: string; reason: SkipReason }> | undefined;

    const useSkillEngine =
      !!opts.childId &&
      !!childContext &&
      !!decomposition &&
      isSkillEngineStage4Enabled();

    if (useSkillEngine && childContext && decomposition) {
      emit(opts, {
        stage: 'generate',
        status: 'start',
        source: 'skill-engine',
        atomCount: decomposition.atoms.length,
      });
      const skillResult = await runStage(
        'generate',
        () =>
          generateCardsWithSkills(
            userId,
            analysis,
            scraped,
            decomposition!,
            childContext!,
            guidance,
            sessionContext
          ),
        stageOpts
      ).catch(async (err) => {
        await updateIngestStatus(ingestId, 'failed');
        emit(opts, {
          stage: 'generate',
          status: 'failed',
          source: 'skill-engine',
          error: errMsg(err),
        });
        throw new Error(`Card generation failed: ${errMsg(err)}`);
      });
      cards = skillResult.cards;
      skillEngineUsed = true;
      skillTraces = skillResult.traces;
      skillSkippedAtoms = skillResult.skipped.length > 0 ? skillResult.skipped : undefined;
      if (skillResult.usedLegacyFallback) {
        console.warn(
          `[Pipeline] Skill engine produced ${skillResult.cards.length} cards; legacy fallback was invoked for ${skillResult.skipped.length} skipped atom(s).`
        );
      }
      // Per-atom retry tallies for the Dev Console — computed here so the
      // frontend doesn't need to re-iterate the trace array to render the
      // stage pill badge.
      const retryOkCount = skillTraces.filter((t) => t.validatorStatus === 'retry-ok').length;
      const retryFailedCount = skillTraces.filter((t) => t.validatorStatus === 'retry-failed').length;
      emit(opts, {
        stage: 'generate',
        status: 'done',
        source: 'skill-engine',
        cardCount: cards.length,
        skippedCount: skillResult.skipped.length,
        retryOkCount,
        retryFailedCount,
      });
    } else {
      emit(opts, {
        stage: 'generate',
        status: 'start',
        source: 'legacy',
        atomCount: decomposition?.atoms.length ?? 0,
      });
      cards = await runStage(
        'generate',
        () => generateCards(userId, analysis, scraped, decomposition, guidance, sessionContext),
        stageOpts
      ).catch(async (err) => {
        await updateIngestStatus(ingestId, 'failed');
        emit(opts, {
          stage: 'generate',
          status: 'failed',
          source: 'legacy',
          error: errMsg(err),
        });
        throw new Error(`Card generation failed: ${errMsg(err)}`);
      });
      emit(opts, {
        stage: 'generate',
        status: 'done',
        source: 'legacy',
        cardCount: cards.length,
      });
    }

    // Stage 6: Quality gate (S9-09) ──────────────────────────────────────
    let qualityReport: QualityReport | undefined;
    let regeneratedIndexes: number[] = [];
    if (!opts.skipQualityGate) {
      await updateIngestStatus(ingestId, 'quality_gate');
      emit(opts, { stage: 'quality', status: 'start' });
      try {
        const gateResult = await runStage(
          'quality_gate',
          () => runQualityGate(userId, analysis, cards, guidance, sessionContext),
          stageOpts
        );
        cards = gateResult.cards;
        qualityReport = gateResult.report;
        regeneratedIndexes = gateResult.regeneratedIndexes;
        emit(opts, {
          stage: 'quality',
          status: 'done',
          regeneratedCount: regeneratedIndexes.length,
          overallScore: qualityReport?.overallScore,
        });
      } catch (err) {
        // Non-fatal: proceed with original cards
        console.warn(`[Pipeline] Quality gate failed, proceeding without: ${errMsg(err)}`);
        emit(opts, {
          stage: 'quality',
          status: 'failed',
          error: errMsg(err),
        });
      }
    }

    // Persist the lesson + cards ────────────────────────────────────────
    // S10-12 · R8 — when the skill engine ran, stash the per-atom trace and
    // skip list into aiAnalysis so the Dev Console (R7) can rebuild the view
    // for any lesson without needing a separate table.
    // S12-05 — the `skillEngine` envelope now carries a Stage-3 slot so the
    // Dev Console Pipeline tab can render a `curriculum-architect` row
    // preceding per-atom rows. `used` stays true if *either* stage ran, so
    // downstream consumers that gate on `skillEngine.used` keep working.
    const stage3Used = !!decompositionTrace;
    const skillEngineEnvelope =
      stage3Used || skillEngineUsed
        ? {
            used: true,
            stage3: decompositionTrace ?? null,
            traces: skillTraces ?? [],
            skipped: skillSkippedAtoms ?? [],
          }
        : null;

    const aiMeta = {
      ...analysis,
      decomposition: decomposition ?? null,
      qualityReport: qualityReport ?? null,
      skillEngine: skillEngineEnvelope,
    };

    emit(opts, { stage: 'persist', status: 'start' });
    const lesson = await prisma.lesson.create({
      data: {
        userId,
        pathId,
        title: scraped.title || 'Untitled Lesson',
        description: analysis.summary,
        sourceUrl: ingest.url,
        difficulty: analysis.suggestedStage,
        aiAnalysis: toJsonColumn(aiMeta),
        status: 'draft',
        cards: {
          create: cards.map((card) => ({
            type: card.type,
            content: toJsonColumn(card.content),
            voiceScript: card.voiceScript,
            sortOrder: card.sortOrder,
          })),
        },
      },
      select: { id: true },
    });

    const lessonId = lesson.id;
    await updateIngestStatus(ingestId, 'completed');
    emit(opts, {
      stage: 'persist',
      status: 'done',
      lessonId,
      cardCount: cards.length,
    });

    // Stage 5: Kick off asset generation (fire-and-forget) ───────────────
    const config = getConfig();
    const apiKey = config.OPENAI_API_KEY;
    if (apiKey) {
      processLessonAssets(lessonId, apiKey, userId)
        .then((results) => {
          const completed = results.filter((r) => r.status === 'completed').length;
          const failed = results.filter((r) => r.status === 'failed').length;
          console.log(
            `[Pipeline] Asset generation for lesson ${lessonId}: ${completed} completed, ${failed} failed`
          );
        })
        .catch((err) => {
          console.error(`[Pipeline] Asset generation failed for lesson ${lessonId}:`, err);
        });
      console.log(`[Pipeline] Asset generation triggered for lesson ${lessonId}`);
    } else {
      console.warn('[Pipeline] OPENAI_API_KEY not set — skipping asset generation');
    }

    const elapsedMs = Date.now() - pipelineStart;
    if (elapsedMs > opts.pipelineTimeoutMs) {
      console.warn(
        `[Pipeline] Exceeded pipeline budget (${elapsedMs}ms > ${opts.pipelineTimeoutMs}ms)`
      );
    }

    emit(opts, {
      stage: 'pipeline',
      status: 'done',
      lessonId,
      cardCount: cards.length,
      elapsedMs,
    });

    return {
      ingestId,
      lessonId,
      cardCount: cards.length,
      status: 'completed',
      message: `Successfully created lesson with ${cards.length} cards${
        regeneratedIndexes.length ? ` (${regeneratedIndexes.length} regenerated by quality gate)` : ''
      }${skillEngineUsed ? ' [skill-engine]' : ''}${decompositionTrace ? ' [s12-05]' : ''}`,
      regeneratedCardIndexes: regeneratedIndexes,
      qualityScore: qualityReport?.overallScore,
      skillEngineUsed,
      skillSkippedAtoms,
      skillTraces,
      decompositionTrace,
    };
  } catch (error) {
    try {
      await updateIngestStatus(ingestId, 'failed');
    } catch {
      /* swallow */
    }
    emit(opts, { stage: 'pipeline', status: 'failed', error: errMsg(error) });
    throw error;
  }
}

async function updateIngestStatus(ingestId: string, status: string): Promise<void> {
  const prisma = getPrismaClient();
  await prisma.urlIngest.update({ where: { id: ingestId }, data: { status } });
}
