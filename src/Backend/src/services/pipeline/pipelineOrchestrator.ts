/**
 * Pipeline Orchestrator Service
 *
 * Orchestrates the full content pipeline:
 * 1. Scrape URL
 * 2. Analyze content
 * 3. Generate cards
 * 4. Create lesson and cards in database
 */

import { getPrismaClient } from '@db/client';
import { scrapeUrl } from './scraper';
import { analyzeContent } from './contentAnalyzer';
import { generateCards } from './cardGenerator';
import type { Prisma } from '@prisma/client';

export interface PipelineResult {
  ingestId: string;
  lessonId: string;
  cardCount: number;
  status: 'completed' | 'partial';
  message: string;
}

export interface PipelineStepResult {
  status: 'scraped' | 'analyzing' | 'generating' | 'completed' | 'failed';
  error?: string;
}

/**
 * Run the full content pipeline
 */
export async function runPipeline(
  userId: string,
  ingestId: string,
  pathId?: string
): Promise<PipelineResult> {
  const prisma = getPrismaClient();

  try {
    // Step 1: Get the ingest record
    const ingest = await prisma.urlIngest.findUnique({
      where: { id: ingestId },
    });

    if (!ingest) {
      throw new Error('Ingest not found');
    }

    if (ingest.userId !== userId) {
      throw new Error('Unauthorized');
    }

    // Step 2: Scrape the URL
    let scraped;
    try {
      scraped = await scrapeUrl(ingest.url);

      // Update ingest with raw content
      await prisma.urlIngest.update({
        where: { id: ingestId },
        data: {
          rawContent: scraped.content,
          status: 'scraped',
        },
      });
    } catch (error) {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(`Scrape failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

    // Step 3: Analyze content
    let analysis;
    try {
      await updateIngestStatus(ingestId, 'analyzing');
      analysis = await analyzeContent(userId, scraped);

      // Update ingest with analysis
      await prisma.urlIngest.update({
        where: { id: ingestId },
        data: {
          aiAnalysis: analysis as Prisma.InputJsonValue,
          status: 'analyzing',
        },
      });

      // If content is not age-appropriate, stop here
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
    } catch (error) {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(`Analysis failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

    // Step 4: Generate cards
    let cards;
    try {
      await updateIngestStatus(ingestId, 'generating');
      cards = await generateCards(userId, analysis, scraped);
    } catch (error) {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(`Card generation failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }

    // Step 5: Create lesson and cards in database
    let lessonId = '';
    try {
      const lesson = await prisma.lesson.create({
        data: {
          userId,
          pathId,
          title: scraped.title || 'Untitled Lesson',
          description: analysis.summary,
          sourceUrl: ingest.url,
          difficulty: analysis.suggestedStage,
          aiAnalysis: analysis as Prisma.InputJsonValue,
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

      lessonId = lesson.id;

      // Update ingest status to completed
      await updateIngestStatus(ingestId, 'completed');

      return {
        ingestId,
        lessonId,
        cardCount: cards.length,
        status: 'completed',
        message: `Successfully created lesson with ${cards.length} cards`,
      };
    } catch (error) {
      await updateIngestStatus(ingestId, 'failed');
      throw new Error(
        `Database write failed: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  } catch (error) {
    // Ensure ingest is marked as failed
    try {
      await updateIngestStatus(ingestId, 'failed');
    } catch {
      // Ignore errors updating status
    }

    throw error;
  }
}

/**
 * Update the ingest status
 */
async function updateIngestStatus(ingestId: string, status: string): Promise<void> {
  const prisma = getPrismaClient();
  await prisma.urlIngest.update({
    where: { id: ingestId },
    data: { status },
  });
}
