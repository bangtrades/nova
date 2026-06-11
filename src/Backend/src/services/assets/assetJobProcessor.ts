/**
 * Asset Job Processor Service
 *
 * Orchestrates asset generation jobs (TTS, images) with retry logic.
 * Processes jobs sequentially to avoid rate limiting.
 * Updates asset jobs and card records in the database.
 */

import { getPrismaClient, toJsonColumn, fromJsonColumn } from '@db/client';
import { getConfig } from '@config';
import { generateTTSAudio } from './ttsGenerator';
import { generateImage, buildImagePrompt, downloadImage } from './imageGenerator';
import { uploadAudio, uploadImage } from './assetUploader';
import { logUsage } from '../llm/costTracker';

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
  userId: string = 'system',
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

      // Log TTS cost
      logUsage({
        userId,
        provider: 'openai',
        model: 'tts-1',
        feature: 'tts',
        metadata: { charCount: text.length, lessonId },
      });
    } else if (type === 'image') {
      // Generate DALL-E image
      const concept = input.concept as string;
      const cardType = input.cardType as string;
      const subject = typeof input.subject === 'string' ? input.subject : undefined;

      if (!concept || !concept.trim()) {
        throw new AssetProcessorError('invalid_input', false, 'Image concept is required');
      }

      const prompt = buildImagePrompt(concept, cardType || 'concept', subject);
      const result = await generateImage(apiKey, prompt);
      const imageBuffer = await downloadImage(result.url);
      outputUrl = await uploadImage(imageBuffer, lessonId, 0);

      // Log DALL-E 3 cost
      logUsage({
        userId,
        provider: 'openai',
        model: 'dall-e-3',
        feature: 'image_gen',
        metadata: { lessonId, promptLength: prompt.length },
      });
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

      return processJobWithRetry(jobId, lessonId, type, input, apiKey, userId, retryCount + 1);
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
  apiKey: string,
  userId: string = 'system'
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
    fromJsonColumn<Record<string, unknown>>(job.input),
    apiKey,
    userId
  );
}

/**
 * Process all asset jobs for a lesson
 */
export async function processLessonAssets(
  lessonId: string,
  apiKey: string,
  userId: string = 'system'
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

  // Extract the lesson subject noun ("hippopotamus", "volcano", ...) from the
  // Stage 2 analysis / Stage 3 decomposition. This is what anchors every image
  // prompt so DALL-E-3 actually paints the right subject, not generic stock
  // classroom imagery. Without a subject, we fall back to the lesson title.
  const aiAnalysis = parseLessonAiAnalysis(lesson.aiAnalysis);
  const subject = (aiAnalysis?.topic || lesson.title || '').trim();
  const atoms = Array.isArray(aiAnalysis?.decomposition?.atoms)
    ? (aiAnalysis!.decomposition!.atoms as Array<Record<string, unknown>>)
    : [];

  // Create asset jobs for cards that need them
  const jobsToProcess: typeof lesson.cards = [];

  // Track which image-eligible card we're on so we can pair it to its atom
  // (decomposition and cards are in sortOrder, see cardGenerator Stage 4).
  let atomCursor = 0;

  for (const card of lesson.cards) {
    // Create TTS job if card has a voice script
    if (card.voiceScript && !card.audioUrl) {
      const ttsJob = await prisma.assetJob.create({
        data: {
          lessonId,
          type: 'tts',
          input: toJsonColumn({
            text: card.voiceScript,
            voice: 'nova',
          }),
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
    const cardContent = fromJsonColumn<Record<string, unknown> | null>(card.content);
    if (cardContent && !card.imageUrl) {
      const atom = atoms[atomCursor];
      const concept = buildCardConcept(cardContent, card.type, subject, atom);
      atomCursor++;

      const imageJob = await prisma.assetJob.create({
        data: {
          lessonId,
          type: 'image',
          input: toJsonColumn({
            concept,
            cardType: card.type,
            subject,
          }),
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
  // Fetch actual job records so we have real input data
  const allJobs = await prisma.assetJob.findMany({
    where: { lessonId, status: 'queued' },
    orderBy: { createdAt: 'asc' },
  });

  // Track which card index we're on for TTS and images separately
  let ttsCardIndex = 0;
  let imageCardIndex = 0;

  for (const job of allJobs) {
    const resultEntry = results.find((r) => r.jobId === job.id);
    if (!resultEntry) continue;

    try {
      const jobInput = (typeof job.input === 'string' ? JSON.parse(job.input) : job.input) as Record<string, unknown>;

      const outputUrl = await processJobWithRetry(
        job.id,
        lessonId,
        job.type,
        jobInput,
        apiKey,
        userId
      );

      resultEntry.status = 'completed';
      resultEntry.outputUrl = outputUrl;

      // Update the corresponding card with the asset URL
      if (job.type === 'tts') {
        // Find cards with voiceScript but no audioUrl, in order
        const ttsCards = lesson.cards.filter((c) => c.voiceScript && !c.audioUrl);
        if (ttsCards[ttsCardIndex]) {
          await prisma.card.update({
            where: { id: ttsCards[ttsCardIndex].id },
            data: { audioUrl: outputUrl },
          });
        }
        ttsCardIndex++;
      } else if (job.type === 'image') {
        // Find cards without imageUrl, in order
        const imageCards = lesson.cards.filter((c) => !c.imageUrl);
        if (imageCards[imageCardIndex]) {
          await prisma.card.update({
            where: { id: imageCards[imageCardIndex].id },
            data: { imageUrl: outputUrl },
          });
        }
        imageCardIndex++;
      }
    } catch (error) {
      resultEntry.status = 'failed';
      resultEntry.error = error instanceof Error ? error.message : 'Unknown error';
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
    jobs: jobs.map((j) => ({ ...j, outputUrl: j.outputUrl ?? undefined })),
  };

  return status;
}

/**
 * Parse the lesson.aiAnalysis JSON blob (stored as TEXT in SQLite).
 * Returns a structured object with topic + decomposition, or null on failure.
 * Non-throwing — a malformed blob must not block asset generation.
 */
function parseLessonAiAnalysis(
  raw: string | null
): { topic?: string; decomposition?: { atoms?: unknown[] } } | null {
  if (!raw) return null;
  try {
    const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
    if (parsed && typeof parsed === 'object') {
      return parsed as { topic?: string; decomposition?: { atoms?: unknown[] } };
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Build the `concept` string that will be forwarded to `buildImagePrompt`.
 *
 * Priority (highest wins):
 *   1. LLM-authored `imagePrompt` on the card (already subject-anchored per
 *      the updated CARD_GENERATION_PROMPT).
 *   2. Synthesized "<subject> — <atom.name>: <card title/text excerpt>".
 *   3. "<subject> — <card title/text excerpt>".
 *   4. Plain subject if nothing else.
 *
 * This replaces the old `text || title || imagePrompt || "learning concept"`
 * chain, which dropped the lesson subject entirely and collapsed to the
 * literal string "learning concept" for quiz cards.
 */
export function buildCardConcept(
  cardContent: Record<string, unknown>,
  cardType: string,
  subject: string,
  atom?: Record<string, unknown>
): string {
  const llmPrompt =
    typeof cardContent.imagePrompt === 'string'
      ? cardContent.imagePrompt.trim()
      : '';
  if (llmPrompt) {
    // If the LLM already anchored the subject, use its prompt verbatim.
    // If not, prepend the subject so DALL-E-3 sees it in the first tokens.
    if (subject && !llmPrompt.toLowerCase().includes(subject.toLowerCase())) {
      return `${subject}: ${llmPrompt}`;
    }
    return llmPrompt;
  }

  const atomName =
    atom && typeof atom.name === 'string' ? atom.name.trim() : '';
  const cardTitle =
    typeof cardContent.title === 'string' ? cardContent.title.trim() : '';
  const cardText =
    typeof cardContent.text === 'string'
      ? cardContent.text.trim().slice(0, 140)
      : '';
  const cardQuestion =
    typeof cardContent.question === 'string'
      ? cardContent.question.trim()
      : '';

  const detail = cardTitle || cardQuestion || cardText || cardType;

  if (subject && atomName) {
    return `${subject} — ${atomName}: ${detail}`;
  }
  if (subject) {
    return `${subject}: ${detail}`;
  }
  if (atomName) {
    return `${atomName}: ${detail}`;
  }
  return detail || 'educational scene';
}

export { AssetProcessorError };
export type { AssetJobStatus, AssetJobResult };
