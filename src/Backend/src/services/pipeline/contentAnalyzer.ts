/**
 * Content Analyzer Service
 *
 * Uses the LLM provider router to analyze web content for child-appropriateness
 * and extract key concepts, learning stage, and safety information.
 */

import { routeRequest } from '../llm/providerRouter';
import type { LLMMessage } from '../llm/types';
import { getContentAnalysisSystemPrompt, SAFETY_FILTER_PROMPT } from './promptTemplates';
import type { ScrapedContent } from './scraper';

export interface ContentAnalysis {
  topic: string;
  keyConcepts: string[];
  suggestedStage: 1 | 2 | 3 | 4;
  ageAppropriate: boolean;
  safetyFlags: string[];
  suggestedCardCount: number;
  summary: string;
}

/**
 * Analyze scraped content for child-appropriateness and structure
 */
export async function analyzeContent(
  userId: string,
  content: ScrapedContent
): Promise<ContentAnalysis> {
  // Prepare the content for analysis
  const contentText = `Title: ${content.title}\n\nContent:\n${content.content}`;

  if (!contentText.trim()) {
    throw new Error('No content to analyze');
  }

  // First pass: analyze content structure and age-appropriateness
  const systemPrompt = getContentAnalysisSystemPrompt();
  const messages: LLMMessage[] = [
    {
      role: 'system',
      content: systemPrompt,
    },
    {
      role: 'user',
      content: contentText,
    },
  ];

  let analysisResponse;
  try {
    analysisResponse = await routeRequest(userId, {
      model: 'claude-sonnet',
      messages,
      temperature: 0.5,
      maxTokens: 500,
    }, 'content_analysis');
  } catch (error) {
    throw new Error(`LLM analysis failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }

  // Parse the JSON response
  let analysis: ContentAnalysis;
  try {
    const jsonMatch = analysisResponse.content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in response');
    }
    const parsed = JSON.parse(jsonMatch[0]);

    analysis = {
      topic: parsed.topic || 'Unknown Topic',
      keyConcepts: Array.isArray(parsed.keyConcepts) ? parsed.keyConcepts : [],
      suggestedStage: Math.max(1, Math.min(4, parsed.suggestedStage || 1)) as 1 | 2 | 3 | 4,
      ageAppropriate: parsed.ageAppropriate !== false,
      safetyFlags: Array.isArray(parsed.safetyFlags) ? parsed.safetyFlags : [],
      suggestedCardCount: Math.max(5, Math.min(8, parsed.suggestedCardCount || 6)),
      summary: parsed.summary || 'No summary available',
    };
  } catch (error) {
    throw new Error(
      `Failed to parse analysis response: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }

  // Second pass: safety filtering if content seems appropriate
  if (analysis.ageAppropriate && analysis.safetyFlags.length === 0) {
    try {
      const safetyMessages: LLMMessage[] = [
        {
          role: 'system',
          content: SAFETY_FILTER_PROMPT,
        },
        {
          role: 'user',
          content: contentText.substring(0, 5000), // Limit for safety check
        },
      ];

      const safetyResponse = await routeRequest(userId, {
        model: 'claude-sonnet',
        messages: safetyMessages,
        temperature: 0.3,
        maxTokens: 300,
      }, 'safety_filter');

      const jsonMatch = safetyResponse.content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const safeguards = JSON.parse(jsonMatch[0]);
        if (!safeguards.isSafe) {
          analysis.ageAppropriate = false;
          analysis.safetyFlags = safeguards.concerns || ['Failed safety review'];
        }
      }
    } catch (error) {
      // Log but don't fail if safety check fails
      console.warn('Safety filter error:', error);
    }
  }

  return analysis;
}
