/**
 * Anthropic Claude API Provider
 *
 * Calls the Anthropic Messages API for content generation.
 * Used for lesson content, curriculum planning, and concept decomposition.
 * Claude excels at structured educational content and following complex prompt chains.
 */

import type { LLMRequest, LLMResponse, UsageRecord } from './types';

interface AnthropicMessage {
  role: 'user' | 'assistant';
  content: string;
}

interface AnthropicRequest {
  model: string;
  max_tokens: number;
  system?: string;
  messages: AnthropicMessage[];
  temperature?: number;
}

interface AnthropicUsage {
  input_tokens: number;
  output_tokens: number;
}

interface AnthropicContentBlock {
  type: 'text';
  text: string;
}

interface AnthropicResponse {
  id: string;
  type: 'message';
  role: 'assistant';
  content: AnthropicContentBlock[];
  model: string;
  stop_reason: string;
  usage: AnthropicUsage;
}

interface AnthropicError {
  type: 'error';
  error: {
    type: string;
    message: string;
  };
}

export class AnthropicProviderError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    public retryable: boolean,
    message: string
  ) {
    super(message);
    this.name = 'AnthropicProviderError';
  }
}

/**
 * Calls the Anthropic Messages API
 * @param apiKey - Anthropic API key
 * @param request - LLM request (system message extracted from messages array)
 * @returns LLM response in standard format
 */
export async function claudeCompletion(
  apiKey: string,
  request: LLMRequest
): Promise<LLMResponse> {
  if (!apiKey) {
    throw new AnthropicProviderError('invalid_api_key', 401, false, 'Anthropic API key is required');
  }

  // Extract system message and conversation messages
  const systemMessage = request.messages.find(m => m.role === 'system')?.content;
  const conversationMessages: AnthropicMessage[] = request.messages
    .filter(m => m.role !== 'system')
    .map(m => ({
      role: m.role as 'user' | 'assistant',
      content: m.content,
    }));

  // Map model names: allow using short names
  const modelMap: Record<string, string> = {
    'claude-sonnet': 'claude-sonnet-4-20250514',
    'claude-haiku': 'claude-haiku-4-20250414',
    'claude-opus': 'claude-opus-4-20250514',
    'claude-sonnet-4': 'claude-sonnet-4-20250514',
    'claude-haiku-4': 'claude-haiku-4-20250414',
  };

  const model = modelMap[request.model] || request.model;

  const anthropicRequest: AnthropicRequest = {
    model,
    max_tokens: request.maxTokens || 4096,
    messages: conversationMessages,
    ...(systemMessage && { system: systemMessage }),
    ...(request.temperature !== undefined && { temperature: request.temperature }),
  };

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify(anthropicRequest),
    });

    if (!response.ok) {
      const errorData = (await response.json()) as AnthropicError;
      const errorMessage = errorData.error?.message || 'Unknown Anthropic API error';
      const errorType = errorData.error?.type || 'api_error';

      if (response.status === 429) {
        throw new AnthropicProviderError('rate_limit', 429, true, 'Anthropic rate limit exceeded');
      } else if (response.status === 401) {
        throw new AnthropicProviderError('invalid_api_key', 401, false, 'Invalid Anthropic API key');
      } else if (response.status === 529) {
        throw new AnthropicProviderError('overloaded', 529, true, 'Anthropic API overloaded');
      } else if (response.status >= 500) {
        throw new AnthropicProviderError(errorType, response.status, true, errorMessage);
      }

      throw new AnthropicProviderError(errorType, response.status, false, errorMessage);
    }

    const data = (await response.json()) as AnthropicResponse;

    if (!data.content || data.content.length === 0) {
      throw new AnthropicProviderError('invalid_response', 500, true, 'Claude returned no content');
    }

    // Combine all text blocks
    const content = data.content
      .filter(block => block.type === 'text')
      .map(block => block.text)
      .join('\n');

    const usage: UsageRecord = {
      promptTokens: data.usage.input_tokens,
      completionTokens: data.usage.output_tokens,
      totalTokens: data.usage.input_tokens + data.usage.output_tokens,
    };

    return {
      content,
      model: data.model,
      usage,
      provider: 'proxy',
      finishReason: data.stop_reason,
    };
  } catch (error) {
    if (error instanceof AnthropicProviderError) {
      throw error;
    }

    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new AnthropicProviderError('network_error', 0, true, `Network error: ${error.message}`);
    }

    throw new AnthropicProviderError(
      'unknown_error',
      500,
      true,
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}
