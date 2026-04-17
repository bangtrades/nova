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

import { getPrismaClient } from '@db/client';
import { scrapeUrl } from './scraper';
import { analyzeContent } from './contentAnalyzer';
import { decomposeConcepts, type ConceptDecomposition } from './conceptDecomposer';
import { generateCards } from './cardGenerator';
import { runQualityGate, type QualityReport } from './qualityGate';
import { processLessonAssets } from '../assets/assetJobProcessor';
import { getConfig } from '@config';
import { runStage, errMsg, type RunStageOptions } from './pipelineUtils';
import type { Prisma } from '@prisma/client';

export interface PipelineResult {
  ingestId: string;
  lessonId: string;
  cardCount: number;
  status: 'completed' | 'partial';
  message: string;
  regeneratedCardIndexes?: number[];
  qualityScore?: number;
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

// Default timeouts (ms) for each LLM-facing stage. The full pipeline budget
// is ~120s end-to-end per the sprint plan; individual stage caps below.
const DEFAULTS = {
  stageTimeoutMs: 45_000,
  pipelineTimeoutMs: 120_000,
  maxAttempts: 2, // one retry on transient failure
  retryBackoffMs: 750,
} as const;

export interface PipelineOptions {
  stageTimeoutMs?: number;
  pipelineTimeoutMs?: number;
  maxAttempts?: number;
  skipQualityGate?: boolean;
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

    // Stage 1: Scrape ────────────────────────────────────────────────────
    const scraped = await runStage('scrape', () => scrapeUrl(ingest.url), stageOpts).catch(
      async (err) => {
        await updateIngestStatus(ingestId, 'failed');
        throw new Error(`Scrape failed: ${errMsg(err)}`);
      }
    );

    await prisma.urlIngest.update({
      where: { id: ingestId },
      data: { rawContent: scraped.content, status: 'scraped' },
    });

    // Stage 2: Analyze content (with internal safety second-pass) ────────
    await updateIngestStatus(ingestId, 'analyzing');
    const analysis = await runStage(
      'analyze',
      () => analyzeContent(userId, scraped),
      stageOpts
    ).catch(async (err) => {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(`Analysis failed: ${errMsg(err)}`);
    });

    await prisma.urlIngest.update({
      where: { id: ingestId },
      data: {
        aiAnalysis: analysis as Prisma.InputJsonValue,
        status: 'analyzing',
      },
    });

    if (!analysis.ageAppropriate) {
      await updateIngestStatus(ingestId, 'completed');
      return {
        ingestId,
        lessonId: '',
        cardCount: 0,
        status: 'completed',
        message: `Content not age-appropriate: ${analysis.safetyFlags.join(', ')}`,
      };
    }

    // Stage 3: Concept decomposition (S9-06) ─────────────────────────────
    await updateIngestStatus(ingestId, 'decomposing');
    let decomposition: ConceptDecomposition | undefined;
    try {
      decomposition = await runStage(
        'decompose',
        () => decomposeConcepts(userId, analysis, scraped),
        stageOpts
      );
    } catch (err) {
      // Non-fatal: the card generator has a legacy code path that works
      // without a decomposition. Log and continue.
      console.warn(`[Pipeline] Decomposition failed, falling back: ${errMsg(err)}`);
    }

    // Stage 4: Card generation ───────────────────────────────────────────
    await updateIngestStatus(ingestId, 'generating');
    let cards = await runStage(
      'generate',
      () => generateCards(userId, analysis, scraped, decomposition),
      stageOpts
    ).catch(async (err) => {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(`Card generation failed: ${errMsg(err)}`);
    });

    // Stage 6: Quality gate (S9-09) ──────────────────────────────────────
    let qualityReport: QualityReport | undefined;
    let regeneratedIndexes: number[] = [];
    if (!opts.skipQualityGate) {
      await updateIngestStatus(ingestId, 'quality_gate');
      try {
        const gateResult = await runStage(
          'quality_gate',
          () => runQualityGate(userId, analysis, cards),
          stageOpts
        );
        cards = gateResult.cards;
        qualityReport = gateResult.report;
        regeneratedIndexes = gateResult.regeneratedIndexes;
      } catch (err) {
        // Non-fatal: proceed with original cards
        console.warn(`[Pipeline] Quality gate failed, proceeding without: ${errMsg(err)}`);
      }
    }

    // Persist the lesson + cards ────────────────────────────────────────
    const aiMeta = {
      ...analysis,
      decomposition: decomposition ?? null,
      qualityReport: qualityReport ?? null,
    };

    const lesson = await prisma.lesson.create({
      data: {
        userId,
        pathId,
        title: scraped.title || 'Untitled Lesson',
        description: analysis.summary,
        sourceUrl: ingest.url,
        difficulty: analysis.suggestedStage,
        aiAnalysis: aiMeta as Prisma.InputJsonValue,
        status: 'draft',
        cards: {
          create: cards.map((card) => ({
            type: card.type,
            content: card.content as Prisma.InputJsonValue,
            voiceScript: card.voiceScript,
            sortOrder: card.sortOrder,
          })),
        },
      },
      select: { id: true },
    });

    const lessonId = lesson.id;
    await updateIngestStatus(ingestId, 'completed');

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

    return {
      ingestId,
      lessonId,
      cardCount: cards.length,
      status: 'completed',
      message: `Successfully created lesson with ${cards.length} cards${
        regeneratedIndexes.length ? ` (${regeneratedIndexes.length} regenerated by quality gate)` : ''
      }`,
      regeneratedCardIndexes: regeneratedIndexes,
      qualityScore: qualityReport?.overallScore,
    };
  } catch (error) {
    try {
      await updateIngestStatus(ingestId, 'failed');
    } catch {
      /* swallow */
    }
    throw error;
  }
}

async function updateIngestStatus(ingestId: string, status: string): Promise<void> {
  const prisma = getPrismaClient();
  await prisma.urlIngest.update({ where: { id: ingestId }, data: { status } });
}
