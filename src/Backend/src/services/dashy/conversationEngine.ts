/**
 * Dashy Conversation Engine
 *
 * Handles voice conversations with Dashy, a friendly AI buddy for kids aged 4-8.
 * Dashy explains technology concepts in simple, fun ways and celebrates curiosity.
 *
 * See the S12-07/08 rename note in the sprint runs index for the
 * coordinated-deploy history of this file + its exported identifiers +
 * the `/dashy/chat` route + the iOS `role` literal.
 */

import { routeRequest } from '@services/llm/providerRouter';
import type { LLMRequest, LLMResponse } from '@services/llm/types';
import {
  buildParentGuidancePreamble,
  buildSessionContextPreamble,
} from '@services/pipeline/promptTemplates';
import { getGuidance } from '@services/guidance/parentGuidance';
import { buildSessionContext } from '@services/context/sessionContext';

export const DASHY_SYSTEM_PROMPT = `You are Dashy, a friendly AI buddy for kids aged 4-8. You explain technology concepts in simple, fun ways. You celebrate curiosity. You NEVER discuss violence, politics, adult content, or anything inappropriate for children. If asked about something off-topic, gently redirect to learning about technology and science.

When responding:
1. Use simple, playful language with short sentences
2. Use emojis occasionally to add fun and expression
3. Suggest 2-3 follow-up questions that encourage learning
4. Keep responses to 150 words maximum
5. Show enthusiasm and celebrate the child's curiosity

Format your response as JSON:
{
  "text": "Your friendly response",
  "followUpQuestions": ["question 1", "question 2"],
  "emotion": "happy|curious|excited|thinking"
}`;

export interface DashyResponse {
  text: string;
  followUpQuestions: string[];
  emotion: 'happy' | 'curious' | 'excited' | 'thinking';
  conversationId?: string;
}

export interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
}

/**
 * Process a message from a child and get Dashy's response
 */
export async function processDashyMessage(
  childId: string,
  transcript: string,
  conversationHistory: ConversationMessage[] = [],
  providerId?: string
): Promise<DashyResponse> {
  // Validate transcript
  if (!transcript || transcript.trim().length === 0) {
    throw new Error('Transcript cannot be empty');
  }

  // Limit history to 10 messages (5 exchanges)
  const limitedHistory = conversationHistory.slice(-10);

  // Build messages for LLM
  const messages: Array<{ role: 'user' | 'assistant'; content: string }> = [
    ...limitedHistory,
    {
      role: 'user',
      content: transcript,
    },
  ];

  // S10-04 / S10-05: fetch parent guidance + session context for this turn.
  // Failures degrade to "no preamble" — Dashy never dies on a missing row.
  let preamble = '';
  try {
    const [guidance, sessionContext] = await Promise.all([
      getGuidance(childId),
      buildSessionContext(childId),
    ]);
    preamble =
      buildParentGuidancePreamble(guidance) +
      buildSessionContextPreamble(sessionContext);
  } catch (err) {
    // Swallow — no preamble is the old Sprint 6 behavior.
    console.warn(
      `[Dashy] Failed to compose guidance/context preamble for child ${childId}: ${
        err instanceof Error ? err.message : 'Unknown'
      }`
    );
  }

  try {
    // Create LLM request
    const llmRequest: LLMRequest = {
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: preamble + DASHY_SYSTEM_PROMPT,
        },
        ...messages,
      ],
      temperature: 0.8,
      maxTokens: 300,
    };

    // Route to appropriate LLM provider
    const response: LLMResponse = await routeRequest(childId, llmRequest, 'dashy_chat');

    // Parse the response
    const responseText = response.content;

    // Try to extract JSON from the response
    let parsedResponse: {
      text: string;
      followUpQuestions: string[];
      emotion: 'happy' | 'curious' | 'excited' | 'thinking';
    };

    try {
      // Look for JSON in the response
      const jsonMatch = responseText.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        parsedResponse = JSON.parse(jsonMatch[0]);
      } else {
        // Fallback if no JSON found
        parsedResponse = {
          text: responseText,
          followUpQuestions: generateFallbackQuestions(transcript),
          emotion: 'happy',
        };
      }
    } catch (parseError) {
      // Fallback parsing
      parsedResponse = {
        text: responseText,
        followUpQuestions: generateFallbackQuestions(transcript),
        emotion: 'happy',
      };
    }

    // Validate response structure
    const emotion = validateEmotion(parsedResponse.emotion);
    const followUpQuestions = Array.isArray(parsedResponse.followUpQuestions)
      ? parsedResponse.followUpQuestions.slice(0, 3)
      : generateFallbackQuestions(transcript);

    return {
      text: parsedResponse.text || `That's a great question about ${extractTopic(transcript)}!`,
      followUpQuestions,
      emotion,
    };
  } catch (error) {
    console.error(`Error processing Dashy message for child ${childId}:`, error);

    // Fallback response if LLM fails
    return {
      text: `That's a wonderful question! Can you tell me more about what you're curious about?`,
      followUpQuestions: generateFallbackQuestions(transcript),
      emotion: 'curious',
    };
  }
}

/**
 * Validate emotion value
 */
function validateEmotion(
  emotion: unknown
): 'happy' | 'curious' | 'excited' | 'thinking' {
  const validEmotions: Array<'happy' | 'curious' | 'excited' | 'thinking'> = [
    'happy',
    'curious',
    'excited',
    'thinking',
  ];

  if (typeof emotion === 'string' && validEmotions.includes(emotion as any)) {
    return emotion as 'happy' | 'curious' | 'excited' | 'thinking';
  }

  return 'happy';
}

/**
 * Generate fallback follow-up questions
 */
function generateFallbackQuestions(transcript: string): string[] {
  const topic = extractTopic(transcript);

  const defaultQuestions: Record<string, string[]> = {
    robot: [
      'What do you think robots can do?',
      'Have you ever seen a robot?',
      'Can robots think like we do?',
    ],
    computer: [
      'What do computers help us do?',
      'How do computers work?',
      'What\'s your favorite thing to do on a computer?',
    ],
    ai: [
      'What do you think AI means?',
      'How does AI help us?',
      'Can AI be smarter than humans?',
    ],
    code: [
      'Do you know what code is?',
      'Would you like to learn about coding?',
      'What would you want a computer to do?',
    ],
    default: [
      'That sounds interesting! Can you tell me more?',
      'Why do you ask about that?',
      'What else would you like to learn about?',
    ],
  };

  const questions = defaultQuestions[topic] || defaultQuestions.default;
  return questions.slice(0, 3);
}

/**
 * Extract main topic from transcript
 */
function extractTopic(transcript: string): string {
  const lowerTranscript = transcript.toLowerCase();

  const topics: Record<string, string[]> = {
    robot: ['robot', 'robots', 'mechanical'],
    computer: ['computer', 'laptop', 'phone', 'device'],
    ai: ['ai', 'artificial intelligence', 'smart'],
    code: ['code', 'coding', 'program', 'programming'],
  };

  for (const [topic, keywords] of Object.entries(topics)) {
    if (keywords.some((keyword: string) => lowerTranscript.includes(keyword))) {
      return topic;
    }
  }

  return 'default';
}
