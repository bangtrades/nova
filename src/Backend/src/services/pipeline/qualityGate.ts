/**
 * Quality Gate Service — Grand Architect Pipeline Stage 6 (S9-09)
 *
 * After the card generator produces a full lesson, we send the lesson back to
 * Claude with a critic-flavored prompt to review it for:
 *   - fact accuracy
 *   - age appropriateness
 *   - card flow coherence / no duplicates
 *   - readability for an adult reading aloud
 *
 * Any card flagged with shouldRegenerate=true is regenerated with specific
 * guidance from the review. We cap regeneration at 1 pass per lesson to
 * bound cost and latency.
 */

import { routeRequest } from '../llm/providerRouter';
import type { LLMMessage } from '../llm/types';
import {
  getQualityGateSystemPrompt,
  getCardGenerationSystemPrompt,
} from './promptTemplates';
import type { ContentAnalysis } from './contentAnalyzer';
import type { GeneratedCard } from './cardGenerator';

export interface CardReview {
  index: number;
  score: number; // 0..1
  pass: boolean;
  issues: string[];
  shouldRegenerate: boolean;
  regenerationGuidance: string;
}

export interface QualityReport {
  overallPass: boolean;
  overallScore: number;
  flow: { score: number; notes: string };
  completeness: { score: number; notes: string };
  engagement: { score: number; notes: string };
  cards: CardReview[];
}

export interface QualityGateResult {
  report: QualityReport;
  cards: GeneratedCard[]; // cards after any regeneration
  regeneratedIndexes: number[];
}

const REGENERATION_CAP = 3; // never regenerate more than this many cards

/**
 * Review a generated lesson. Regenerate any cards flagged by the reviewer.
 * Returns the final (possibly-updated) card list plus the report.
 *
 * This is best-effort: if the reviewer LLM call fails or returns garbage,
 * we return the original cards with a pass-through report so the pipeline
 * never fails because of an over-cautious reviewer.
 */
export async function runQualityGate(
  userId: string,
  analysis: ContentAnalysis,
  cards: GeneratedCard[]
): Promise<QualityGateResult> {
  let report: QualityReport;
  try {
    report = await reviewLesson(userId, analysis, cards);
  } catch (error) {
    console.warn(
      `[QualityGate] Review failed, treating lesson as pass-through: ${
        error instanceof Error ? error.message : 'Unknown'
      }`
    );
    return {
      report: buildPassThroughReport(cards),
      cards,
      regeneratedIndexes: [],
    };
  }

  // Sort flagged cards by lowest score so we fix the worst first and stay
  // under the regeneration cap.
  const flagged = report.cards
    .filter((c) => c.shouldRegenerate)
    .sort((a, b) => a.score - b.score)
    .slice(0, REGENERATION_CAP);

  if (flagged.length === 0) {
    return { report, cards, regeneratedIndexes: [] };
  }

  const updatedCards = [...cards];
  const regeneratedIndexes: number[] = [];

  for (const review of flagged) {
    const original = updatedCards[review.index];
    if (!original) continue;

    try {
      const replacement = await regenerateCard(userId, analysis, original, review);
      if (replacement) {
        replacement.sortOrder = original.sortOrder;
        updatedCards[review.index] = replacement;
        regeneratedIndexes.push(review.index);
      }
    } catch (error) {
      console.warn(
        `[QualityGate] Regeneration of card ${review.index} failed: ${
          error instanceof Error ? error.message : 'Unknown'
        }`
      );
    }
  }

  return {
    report,
    cards: updatedCards,
    regeneratedIndexes,
  };
}

/**
 * Call Claude to review the generated lesson.
 */
async function reviewLesson(
  userId: string,
  analysis: ContentAnalysis,
  cards: GeneratedCard[]
): Promise<QualityReport> {
  const systemPrompt = getQualityGateSystemPrompt(
    analysis.topic,
    analysis.suggestedStage,
    analysis.summary
  );

  // Compact the cards so the reviewer sees structure without excessive tokens
  const compact = cards.map((card, index) => ({
    index,
    type: card.type,
    content: card.content,
    voiceScript: card.voiceScript,
  }));

  const messages: LLMMessage[] = [
    { role: 'system', content: systemPrompt },
    {
      role: 'user',
      content: `Here are the ${cards.length} cards generated for this lesson:\n\n${JSON.stringify(
        compact,
        null,
        2
      )}\n\nReview per instructions. Return JSON only.`,
    },
  ];

  const response = await routeRequest(
    userId,
    {
      model: 'claude-sonnet',
      messages,
      temperature: 0.2, // reviewer should be deterministic and strict
      maxTokens: 1400,
    },
    'quality_gate'
  );

  const jsonMatch = response.content.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    throw new Error('Reviewer returned no JSON');
  }

  return normalizeReport(JSON.parse(jsonMatch[0]), cards.length);
}

/**
 * Regenerate a single card using the reviewer's guidance.
 */
async function regenerateCard(
  userId: string,
  analysis: ContentAnalysis,
  original: GeneratedCard,
  review: CardReview
): Promise<GeneratedCard | null> {
  const systemPrompt = getCardGenerationSystemPrompt(
    analysis.topic,
    analysis.summary,
    analysis.keyConcepts
  );

  const issuesList = review.issues.length ? review.issues.join('; ') : 'low quality';

  const userPrompt = `A previously-generated card was flagged by the quality reviewer and needs to be replaced.

ORIGINAL CARD (index ${review.index}, type "${original.type}"):
${JSON.stringify({ content: original.content, voiceScript: original.voiceScript }, null, 2)}

REVIEWER FEEDBACK:
Issues: ${issuesList}
Guidance: ${review.regenerationGuidance || 'Improve overall quality, accuracy, and readability for the target age.'}

Generate ONE replacement card for this same position. Keep the same card type ("${original.type}") unless a different type would fix the issues.

Return a JSON array with a single card object in the same shape as the original card generation prompt.`;

  const messages: LLMMessage[] = [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userPrompt },
  ];

  const response = await routeRequest(
    userId,
    {
      model: 'claude-sonnet',
      messages,
      temperature: 0.6,
      maxTokens: 500,
    },
    'card_regeneration'
  );

  const arrMatch = response.content.match(/\[[\s\S]*\]/);
  if (!arrMatch) return null;

  let parsed: unknown;
  try {
    parsed = JSON.parse(arrMatch[0]);
  } catch {
    return null;
  }

  if (!Array.isArray(parsed) || parsed.length === 0) return null;

  const first = parsed[0] as Record<string, unknown>;
  const type = (first.type as string) ?? original.type;
  const content = (first.content as Record<string, unknown>) ?? {};
  const voiceScript = String(first.voiceScript ?? original.voiceScript ?? '').trim();

  if (!voiceScript) return null;

  return {
    type: type as GeneratedCard['type'],
    content: content as GeneratedCard['content'],
    voiceScript,
    sortOrder: original.sortOrder,
  };
}

export function normalizeReport(raw: unknown, cardCount: number): QualityReport {
  const obj = (raw as Record<string, unknown>) ?? {};
  const rawCards = Array.isArray(obj.cards) ? (obj.cards as unknown[]) : [];

  const cardReviews: CardReview[] = [];
  for (let i = 0; i < cardCount; i++) {
    const match = rawCards.find(
      (c) => Number((c as Record<string, unknown>).index) === i
    ) as Record<string, unknown> | undefined;

    if (match) {
      cardReviews.push({
        index: i,
        score: clamp01(Number(match.score ?? 1)),
        pass: match.pass !== false,
        issues: Array.isArray(match.issues) ? (match.issues as unknown[]).map(String) : [],
        shouldRegenerate: match.shouldRegenerate === true,
        regenerationGuidance:
          typeof match.regenerationGuidance === 'string' ? match.regenerationGuidance : '',
      });
    } else {
      // No review for this index — assume pass
      cardReviews.push({
        index: i,
        score: 0.8,
        pass: true,
        issues: [],
        shouldRegenerate: false,
        regenerationGuidance: '',
      });
    }
  }

  const flow = normalizeSubScore(obj.flow);
  const completeness = normalizeSubScore(obj.completeness);
  const engagement = normalizeSubScore(obj.engagement);

  const overallScore = clamp01(
    Number(obj.overallScore ?? (flow.score + completeness.score + engagement.score) / 3)
  );
  const overallPass = obj.overallPass !== false && overallScore >= 0.6;

  return {
    overallPass,
    overallScore,
    flow,
    completeness,
    engagement,
    cards: cardReviews,
  };
}

function normalizeSubScore(raw: unknown): { score: number; notes: string } {
  if (!raw || typeof raw !== 'object') return { score: 0.8, notes: '' };
  const obj = raw as Record<string, unknown>;
  return {
    score: clamp01(Number(obj.score ?? 0.8)),
    notes: typeof obj.notes === 'string' ? obj.notes : '',
  };
}

function buildPassThroughReport(cards: GeneratedCard[]): QualityReport {
  return {
    overallPass: true,
    overallScore: 0.8,
    flow: { score: 0.8, notes: 'Reviewer unavailable — pass-through' },
    completeness: { score: 0.8, notes: 'Reviewer unavailable — pass-through' },
    engagement: { score: 0.8, notes: 'Reviewer unavailable — pass-through' },
    cards: cards.map((_card, index) => ({
      index,
      score: 0.8,
      pass: true,
      issues: [],
      shouldRegenerate: false,
      regenerationGuidance: '',
    })),
  };
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0.5;
  if (n < 0) return 0;
  if (n > 1) return 1;
  return Math.round(n * 100) / 100;
}
