/**
 * Card Generator Service
 *
 * Uses the LLM to generate structured lesson cards from analyzed content.
 * Cards are validated and returned ready for database insertion.
 */

import { routeRequest } from '../llm/providerRouter';
import type { LLMMessage } from '../llm/types';
import { getCardGenerationSystemPrompt } from './promptTemplates';
import type { ContentAnalysis } from './contentAnalyzer';
import type { ScrapedContent } from './scraper';

export type CardType = 'story' | 'concept' | 'experiment' | 'quiz' | 'voice';

export interface CardContent {
  text?: string;
  title?: string;
  imagePrompt?: string;
  options?: string[];
  correctIndex?: number;
  materials?: string[];
}

export interface GeneratedCard {
  type: CardType;
  content: CardContent;
  voiceScript: string;
  sortOrder: number;
}

/**
 * Generate lesson cards from analyzed content
 */
export async function generateCards(
  userId: string,
  analysis: ContentAnalysis,
  scraped: ScrapedContent
): Promise<GeneratedCard[]> {
  // Prepare content text
  const contentText = `Title: ${scraped.title}\n\nContent:\n${scraped.content.substring(0, 3000)}`;

  const systemPrompt = getCardGenerationSystemPrompt(
    analysis.topic,
    analysis.summary,
    analysis.keyConcepts
  );

  const messages: LLMMessage[] = [
    {
      role: 'system',
      content: systemPrompt,
    },
    {
      role: 'user',
      content: `Create ${analysis.suggestedCardCount} lesson cards for stage ${analysis.suggestedStage} children:\n\n${contentText}`,
    },
  ];

  let response;
  try {
    response = await routeRequest(userId, {
      model: 'gpt-4o-mini',
      messages,
      temperature: 0.7,
      maxTokens: 2000,
    });
  } catch (error) {
    throw new Error(`Card generation failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }

  // Parse and validate the JSON response
  let cards: GeneratedCard[];
  try {
    const jsonMatch = response.content.match(/\[[\s\S]*\]/);
    if (!jsonMatch) {
      throw new Error('No JSON array found in response');
    }

    const parsed = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(parsed)) {
      throw new Error('Response is not an array');
    }

    cards = parsed
      .map((card: unknown, index: number) => validateAndNormalizeCard(card as Record<string, unknown>, index))
      .filter((card): card is GeneratedCard => card !== null);

    if (cards.length === 0) {
      throw new Error('No valid cards generated');
    }

    // Ensure sortOrder is sequential
    cards.forEach((card, index) => {
      card.sortOrder = index;
    });

    return cards;
  } catch (error) {
    throw new Error(
      `Failed to parse card response: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Validate and normalize a single card
 */
function validateAndNormalizeCard(card: Record<string, unknown>, fallbackIndex: number): GeneratedCard | null {
  const type = card.type as string;

  // Validate card type
  const validTypes: CardType[] = ['story', 'concept', 'experiment', 'quiz', 'voice'];
  if (!validTypes.includes(type as CardType)) {
    console.warn(`Invalid card type: ${type}, skipping`);
    return null;
  }

  const voiceScript = String(card.voiceScript || '').trim();
  if (!voiceScript) {
    console.warn('Card missing voiceScript, skipping');
    return null;
  }

  // Validate content
  const content = card.content as Record<string, unknown>;
  if (!content || typeof content !== 'object') {
    console.warn('Card missing content object, skipping');
    return null;
  }

  // Normalize content by type
  let normalizedContent: CardContent = {};

  if (type === 'story') {
    normalizedContent = {
      text: String(content.text || '').trim(),
      title: content.title ? String(content.title).trim() : undefined,
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'concept') {
    normalizedContent = {
      title: String(content.title || '').trim(),
      text: String(content.text || '').trim(),
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'experiment') {
    normalizedContent = {
      title: content.title ? String(content.title).trim() : undefined,
      text: String(content.text || '').trim(),
      materials: Array.isArray(content.materials) ? content.materials.map(String) : [],
      imagePrompt: content.imagePrompt ? String(content.imagePrompt).trim() : undefined,
    };
  } else if (type === 'quiz') {
    const options = Array.isArray(content.options)
      ? content.options.map(String).filter(Boolean)
      : [];

    if (options.length < 2) {
      console.warn('Quiz card missing valid options, skipping');
      return null;
    }

    const correctIndex = Number(content.correctIndex) || 0;
    if (correctIndex < 0 || correctIndex >= options.length) {
      console.warn('Quiz card has invalid correctIndex, skipping');
      return null;
    }

    normalizedContent = {
      text: String(content.text || '').trim(),
      options,
      correctIndex,
    };
  } else if (type === 'voice') {
    normalizedContent = {
      text: String(content.text || '').trim(),
      title: content.title ? String(content.title).trim() : undefined,
    };
  }

  return {
    type: type as CardType,
    content: normalizedContent,
    voiceScript,
    sortOrder: fallbackIndex,
  };
}
