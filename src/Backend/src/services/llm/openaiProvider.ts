/**
 * Direct OpenAI API provider
 *
 * Calls OpenAI Chat Completions API directly with a user's BYOK (Bring Your Own Key) token
 */

import type { LLMRequest, LLMResponse, UsageRecord } from './types';

interface OpenAIMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

interface OpenAIRequest {
  model: string;
  messages: OpenAIMessage[];
  temperature?: number;
  max_tokens?: number;
}

interface OpenAIUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface OpenAIChoice {
  finish_reason: string;
  message: {
    role: string;
    content: string;
  };
}

interface OpenAIResponse {
  id: string;
  object: string;
  created: number;
  model: string;
  usage: OpenAIUsage;
  choices: OpenAIChoice[];
}

interface OpenAIError {
  error?: {
    code?: string;
    message: string;
    type: string;
    status?: number;
  };
}

class OpenAIProviderError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    public retryable: boolean,
    message: string
  ) {
    super(message);
    this.name = 'OpenAIProviderError';
  }
}

/**
 * Calls OpenAI Chat Completions API with a user's API key
 * @param apiKey - The user's OpenAI API key
 * @param request - The LLM request
 * @returns The LLM response
 * @throws OpenAIProviderError on API errors
 */
export async function chatCompletion(
  apiKey: string,
  request: LLMRequest
): Promise<LLMResponse> {
  if (!apiKey) {
    throw new OpenAIProviderError('invalid_api_key', 401, false, 'API key is required');
  }

  const openaiRequest: OpenAIRequest = {
    model: request.model,
    messages: request.messages,
    ...(request.temperature !== undefined && { temperature: request.temperature }),
    ...(request.maxTokens !== undefined && { max_tokens: request.maxTokens }),
  };

  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(openaiRequest),
    });

    if (!response.ok) {
      const errorData = (await response.json()) as OpenAIError;
      const errorMessage = errorData.error?.message || 'Unknown OpenAI API error';
      const errorCode = errorData.error?.code || 'unknown_error';
      const errorType = errorData.error?.type || 'server_error';

      // Determine if error is retryable
      let retryable = false;
      if (response.status === 429) {
        // Rate limited
        throw new OpenAIProviderError('rate_limit', 429, true, 'Rate limit exceeded');
      } else if (response.status === 401) {
        // Invalid API key
        throw new OpenAIProviderError('invalid_api_key', 401, false, 'Invalid OpenAI API key');
      } else if (response.status === 403) {
        // Forbidden (probably billing issue)
        throw new OpenAIProviderError(
          'permission_error',
          403,
          false,
          'Access denied: Check your OpenAI billing'
        );
      } else if (response.status >= 500) {
        // Server error
        retryable = true;
        throw new OpenAIProviderError(
          errorCode || 'server_error',
          response.status,
          retryable,
          errorMessage
        );
      } else if (response.status >= 400) {
        // Client error
        throw new OpenAIProviderError(
          errorCode || 'client_error',
          response.status,
          false,
          errorMessage
        );
      }

      throw new OpenAIProviderError(
        errorCode || 'unknown_error',
        response.status,
        retryable,
        errorMessage
      );
    }

    const data = (await response.json()) as OpenAIResponse;

    if (!data.choices || data.choices.length === 0) {
      throw new OpenAIProviderError(
        'invalid_response',
        500,
        true,
        'OpenAI returned no choices'
      );
    }

    const choice = data.choices[0];
    if (!choice.message || !choice.message.content) {
      throw new OpenAIProviderError(
        'invalid_response',
        500,
        true,
        'OpenAI returned empty response'
      );
    }

    const usage: UsageRecord = {
      promptTokens: data.usage.prompt_tokens,
      completionTokens: data.usage.completion_tokens,
      totalTokens: data.usage.total_tokens,
    };

    return {
      content: choice.message.content,
      model: data.model,
      usage,
      provider: 'byok',
      finishReason: choice.finish_reason,
    };
  } catch (error) {
    // Re-throw OpenAI provider errors
    if (error instanceof OpenAIProviderError) {
      throw error;
    }

    // Handle network errors
    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new OpenAIProviderError(
        'network_error',
        0,
        true,
        `Network error: ${error.message}`
      );
    }

    // Unknown error
    throw new OpenAIProviderError(
      'unknown_error',
      500,
      true,
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}

export { OpenAIProviderError };
