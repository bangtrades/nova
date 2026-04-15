/**
 * Asset Job Processor Service
 *
 * Orchestrates asset generation jobs (TTS, images) with retry logic.
 * Processes jobs sequentially to avoid rate limiting.
 * Updates asset jobs and card records in the database.
 */

import { getPrismaClient } from '@db/client';
import { getConfig } from '@config';
import { generateTTSAudio } from './ttsGenerator';
import { generateImage, buildImagePrompt, downloadImage } from './imageGenerator';
import { uploadAudio, uploadImage } from './assetUploader';

const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

interface AssetJobStatus {
  total: number;
  completed: number;
  failed: number;
  pending: number;
  jobs: Array<{
    id: string;
    type: string;
    status: string;
    outputUrl?: string;
    createdAt: Date;
  }>;
}

interface AssetJobResult {
  jobId: string;
  type: string;
  status: string;
  outputUrl?: string;
  error?: string;
}

class AssetProcessorError extends Error {
  constructor(
    public code: string,
    public retryable: boolean,
    message: string
  ) {
    super(message);
    this.name = 'AssetProcessorError';
  }
}

/**
 * Sleep for a specified duration
 */
function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Process a single asset generation job with retry logic
 */
async function processJobWithRetry(
  jobId: string,
  lessonId: string,
  type: string,
  input: Record<string, unknown>,
  apiKey: string,
  retryCount: number = 0
): Promise<string> {
  const prisma = getPrismaClient();

  try {
    // Update job status to processing
    await prisma.assetJob.update({
      where: { id: jobId },
      data: { status: 'processing' },
    });

    let outputUrl: string | null = null;

    if (type === 'tts') {
      // Generate TTS audio
      const text = input.text as string;
      const voice = (input.voice as string) || 'nova';

      if (!text || !text.trim()) {
        throw new AssetProcessorError('invalid_input', false, 'TTS text is required');
      }

      const audioBuffer = await generateTTSAudio(apiKey, text, voice);
      outputUrl = await uploadAudio(audioBuffer, lessonId, 0);
    } else if (type === 'image') {
      // Generate DALL-E image
      const concept = input.concept as string;
      const cardType = input.cardType as string;

      if (!concept || !concept.trim()) {
        throw new AssetProcessorError('invalid_input', false, 'Image concept is required');
      }

      const prompt = buildImagePrompt(concept, cardType || 'concept');
      const result = await generateImage(apiKey, prompt);
      const imageBuffer = await downloadImage(result.url);
      outputUrl = await uploadImage(imageBuffer, lessonId, 0);
    } else {
      throw new AssetProcessorError('invalid_type', false, `Unknown asset type: ${type}`);
    }

    // Update job with completed status and output URL
    await prisma.assetJob.update({
      where: { id: jobId },
      data: {
        status: 'completed',
        outputUrl,
      },
    });

    return outputUrl;
  } catch (error) {
    const isRetryable =
      error instanceof AssetProcessorError ? error.retryable : true;
    const shouldRetry = retryCount < MAX_RETRIES && isRetryable;

    if (shouldRetry) {
      // Wait before retrying
      await sleep(RETRY_DELAY_MS * (retryCount + 1));

      return processJobWithRetry(jobId, lessonId, type, input, apiKey, retryCount + 1);
    }

    // Mark job as failed
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    await prisma.assetJob.update({
      where: { id: jobId },
      data: {
        status: 'failed',
      },
    });

    throw error;
  }
}

/**
 * Process a single asset job
 */
export async function processAssetJob(
  jobId: string,
  apiKey: string
): Promise<void> {
  const prisma = getPrismaClient();

  // Fetch the job
  const job = await prisma.assetJob.findUnique({
    where: { id: jobId },
  });

  if (!job) {
    throw new AssetProcessorError('not_found', false, `Asset job not found: ${jobId}`);
  }

  if (!job.lessonId) {
    throw new AssetProcessorError('invalid_job', false, 'Asset job has no associated lesson');
  }

  // Process the job with retry logic
  await processJobWithRetry(
    jobId,
    job.lessonId,
    job.type,
    job.input as Record<string, unknown>,
    apiKey
  );
}

/**
 * Process all asset jobs for a lesson
 */
export async function processLessonAssets(
  lessonId: string,
  apiKey: string
): Promise<AssetJobResult[]> {
  const prisma = getPrismaClient();
  const results: AssetJobResult[] = [];

  // Fetch the lesson with its cards
  const lesson = await prisma.lesson.findUnique({
    where: { id: lessonId },
    include: { cards: true },
  });

  if (!lesson) {
    throw new AssetProcessorError('not_found', false, `Lesson not found: ${lessonId}`);
  }

  if (!apiKey) {
    throw new AssetProcessorError('invalid_api_key', false, 'OpenAI API key is required');
  }

  // Create asset jobs for cards that need them
  const jobsToProcess: typeof lesson.cards = [];

  for (const card of lesson.cards) {
    // Create TTS job if card has a voice script
    if (card.voiceScript && !card.audioUrl) {
      const ttsJob = await prisma.assetJob.create({
        data: {
          lessonId,
          type: 'tts',
          input: {
            text: card.voiceScript,
            voice: 'nova',
          },
          status: 'queued',
        },
      });

      results.push({
        jobId: ttsJob.id,
        type: 'tts',
        status: 'queued',
      });

      jobsToProcess.push(card);
    }

    // Create image job if card needs illustration and doesn't have one
    const cardContent = card.content as Record<string, unknown> | null;
    if (cardContent && !card.imageUrl) {
      const concept = (cardContent.text ||
        cardContent.title ||
        cardContent.imagePrompt ||
        'learning concept') as string;

      const imageJob = await prisma.assetJob.create({
        data: {
          lessonId,
          type: 'image',
          input: {
            concept,
            cardType: card.type,
          },
          status: 'queued',
        },
      });

      results.push({
        jobId: imageJob.id,
        type: 'image',
        status: 'queued',
      });
    }
  }

  // Process jobs sequentially to avoid rate limits
  for (const result of results) {
    try {
      const outputUrl = await processJobWithRetry(
        result.jobId,
        lessonId,
        result.type,
        result.type === 'tts'
          ? { text: 'processing' }
          : { concept: 'processing', cardType: 'concept' },
        apiKey
      );

      result.status = 'completed';
      result.outputUrl = outputUrl;

      // Update card with the new asset URL
      const cardIndex = jobsToProcess.findIndex((c: any) => c.lessonId === lessonId);

      if (result.type === 'tts' && cardIndex >= 0) {
        await prisma.card.update({
          where: { id: jobsToProcess[cardIndex].id },
          data: { audioUrl: outputUrl },
        });
      } else if (result.type === 'image') {
        const card = lesson.cards.find((c: any) => {
          const content = c.content as Record<string, unknown> | null;
          return content && (content.imagePrompt || content.text);
        });

        if (card) {
          await prisma.card.update({
            where: { id: card.id },
            data: { imageUrl: outputUrl },
          });
        }
      }
    } catch (error) {
      result.status = 'failed';
      result.error = error instanceof Error ? error.message : 'Unknown error';
    }

    // Small delay between requests to avoid rate limiting
    await sleep(500);
  }

  return results;
}

/**
 * Get status of all asset jobs for a lesson
 */
export async function getAssetJobStatus(lessonId: string): Promise<AssetJobStatus> {
  const prisma = getPrismaClient();

  const jobs = await prisma.assetJob.findMany({
    where: { lessonId },
    select: {
      id: true,
      type: true,
      status: true,
      outputUrl: true,
      createdAt: true,
    },
    orderBy: { createdAt: 'desc' },
  });

  const status: AssetJobStatus = {
    total: jobs.length,
    completed: jobs.filter((j: any) => j.status === 'completed').length,
    failed: jobs.filter((j: any) => j.status === 'failed').length,
    pending: jobs.filter((j: any) => j.status === 'queued' || j.status === 'processing').length,
    jobs,
  };

  return status;
}

export { AssetProcessorError };
export type { AssetJobStatus, AssetJobResult };
