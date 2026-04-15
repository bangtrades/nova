/**
 * TTS Audio Generator Service
 *
 * Generates text-to-speech audio via OpenAI API for kid-friendly narration.
 * Produces mp3 audio files suitable for lesson cards.
 */

const MAX_TEXT_LENGTH = 4096;
const DEFAULT_VOICE = 'nova';
const DEFAULT_MODEL = 'tts-1';

interface TTSError {
  code: string;
  statusCode: number;
  retryable: boolean;
  message: string;
}

class TTSGeneratorError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    public retryable: boolean,
    message: string
  ) {
    super(message);
    this.name = 'TTSGeneratorError';
  }
}

/**
 * Generate TTS audio for text using OpenAI's TTS API
 * @param apiKey - OpenAI API key
 * @param text - Text to convert to speech (max 4096 chars)
 * @param voice - Voice selection: alloy, echo, fable, onyx, nova, shimmer (default: nova)
 * @param model - TTS model: tts-1 or tts-1-hd (default: tts-1)
 * @returns Audio buffer in mp3 format
 * @throws TTSGeneratorError on API errors
 */
export async function generateTTSAudio(
  apiKey: string,
  text: string,
  voice: string = DEFAULT_VOICE,
  model: string = DEFAULT_MODEL
): Promise<Buffer> {
  // Validate inputs
  if (!apiKey) {
    throw new TTSGeneratorError('invalid_api_key', 401, false, 'OpenAI API key is required');
  }

  if (!text || !text.trim()) {
    throw new TTSGeneratorError('invalid_input', 400, false, 'Text is required and cannot be empty');
  }

  if (text.length > MAX_TEXT_LENGTH) {
    throw new TTSGeneratorError(
      'text_too_long',
      400,
      false,
      `Text exceeds maximum length of ${MAX_TEXT_LENGTH} characters`
    );
  }

  // Validate voice selection
  const validVoices = ['alloy', 'echo', 'fable', 'onyx', 'nova', 'shimmer'];
  if (!validVoices.includes(voice)) {
    throw new TTSGeneratorError(
      'invalid_voice',
      400,
      false,
      `Invalid voice. Must be one of: ${validVoices.join(', ')}`
    );
  }

  // Validate model selection
  const validModels = ['tts-1', 'tts-1-hd'];
  if (!validModels.includes(model)) {
    throw new TTSGeneratorError(
      'invalid_model',
      400,
      false,
      `Invalid model. Must be one of: ${validModels.join(', ')}`
    );
  }

  try {
    const response = await fetch('https://api.openai.com/v1/audio/speech', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        input: text.trim(),
        voice,
        response_format: 'mp3',
      }),
    });

    if (!response.ok) {
      let errorMessage = 'Unknown TTS error';

      // Try to parse error response
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        try {
          const errorData = (await response.json()) as {
            error?: {
              message?: string;
              type?: string;
              code?: string;
            };
          };
          errorMessage = errorData.error?.message || errorMessage;
        } catch (parseError) {
          // Ignore parse errors and use generic message
        }
      }

      // Handle specific status codes
      if (response.status === 401) {
        throw new TTSGeneratorError('invalid_api_key', 401, false, 'Invalid OpenAI API key');
      } else if (response.status === 429) {
        throw new TTSGeneratorError('rate_limit', 429, true, 'OpenAI API rate limit exceeded');
      } else if (response.status === 500 || response.status === 503) {
        throw new TTSGeneratorError(
          'service_unavailable',
          response.status,
          true,
          `OpenAI service error: ${errorMessage}`
        );
      } else if (response.status >= 500) {
        throw new TTSGeneratorError(
          'server_error',
          response.status,
          true,
          `OpenAI server error: ${errorMessage}`
        );
      } else if (response.status >= 400) {
        throw new TTSGeneratorError(
          'client_error',
          response.status,
          false,
          `OpenAI client error: ${errorMessage}`
        );
      }

      throw new TTSGeneratorError(
        'unknown_error',
        response.status,
        response.status >= 500,
        errorMessage
      );
    }

    // Read response as buffer
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    if (buffer.length === 0) {
      throw new TTSGeneratorError('empty_response', 500, true, 'OpenAI returned empty audio data');
    }

    return buffer;
  } catch (error) {
    // Re-throw TTS generator errors
    if (error instanceof TTSGeneratorError) {
      throw error;
    }

    // Handle network errors
    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new TTSGeneratorError(
        'network_error',
        0,
        true,
        `Network error: ${error.message}`
      );
    }

    // Unknown error
    throw new TTSGeneratorError(
      'unknown_error',
      500,
      true,
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}

export { TTSGeneratorError };
export type { TTSError };
