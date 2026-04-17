/**
 * Image Generator Service
 *
 * Generates kid-friendly illustrations via DALL-E 3.
 * Produces images suitable for lesson cards with child-appropriate styling.
 */

const DEFAULT_MODEL = 'dall-e-3';
const DEFAULT_SIZE = '1024x1024';
const UNSAFE_KEYWORDS = [
  'violence',
  'explicit',
  'adult',
  'gun',
  'weapon',
  'blood',
  'death',
  'suicide',
  'drug',
  'alcohol',
  'hate',
  'harassment',
];

interface ImageGenerationResult {
  url: string;
  revisedPrompt: string;
}

interface OpenAIImageError {
  error?: {
    message?: string;
    type?: string;
    code?: string;
  };
}

interface OpenAIImageResponse {
  data: Array<{
    url: string;
    revised_prompt: string;
  }>;
}

class ImageGeneratorError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    public retryable: boolean,
    message: string
  ) {
    super(message);
    this.name = 'ImageGeneratorError';
  }
}

/**
 * Check if prompt contains unsafe keywords for children
 */
function isSafePrompt(prompt: string): boolean {
  const lowerPrompt = prompt.toLowerCase();
  return !UNSAFE_KEYWORDS.some((keyword) => lowerPrompt.includes(keyword));
}

/**
 * Build a child-safe, kid-friendly image prompt from a concept.
 *
 * DALL-E-3 weights the FIRST ~200 characters heaviest and handles negative
 * phrasing ("no X", "without Y") poorly — it tends to include what you ask
 * it not to. So this builder:
 *   1. Frontloads the lesson subject noun (the most important token).
 *   2. Uses only positive stylistic anchors, no negatives.
 *   3. Keeps the prompt short and concrete (~200-280 chars).
 *
 * @param concept - The card-specific scene description (already includes the
 *   subject when produced by `buildCardConcept`). May also be a raw LLM
 *   `imagePrompt` that already names the subject.
 * @param cardType - story | concept | experiment | quiz | voice.
 * @param subject - Optional lesson subject noun (e.g., "hippopotamus"). When
 *   provided and not already present in `concept`, it is frontloaded.
 * @returns A safe, kid-friendly DALL-E-3 prompt.
 */
export function buildImagePrompt(
  concept: string,
  cardType: string,
  subject?: string
): string {
  // Positive stylistic anchors only — no "no X" phrases.
  const style =
    'Flat digital illustration for a children\'s book, warm friendly palette, soft rounded shapes, soft lighting, wholesome mood';

  // Card-type-specific scene framing. Each adds action/setting around the
  // subject rather than replacing it.
  let framing = '';
  if (cardType === 'story') {
    framing = 'Storybook scene';
  } else if (cardType === 'experiment') {
    framing = 'Kid-safe science activity scene';
  } else if (cardType === 'concept') {
    framing = 'Clear educational illustration';
  } else if (cardType === 'quiz') {
    framing = 'Playful scene matching a multiple-choice question';
  } else if (cardType === 'voice') {
    framing = 'Expressive scene inviting the child to speak';
  } else {
    framing = 'Friendly educational illustration';
  }

  const cleanSubject = (subject || '').trim();
  const cleanConcept = concept.trim();

  // Frontload the subject if it isn't already the first thing mentioned.
  // DALL-E-3 weights tokens by position; the subject MUST come first.
  let subjectPrefix = '';
  if (
    cleanSubject &&
    !cleanConcept.toLowerCase().startsWith(cleanSubject.toLowerCase())
  ) {
    subjectPrefix = `Subject: ${cleanSubject}. `;
  }

  return `${subjectPrefix}${framing}: ${cleanConcept}. ${style}. For children ages 4-8.`;
}

/**
 * Generate an image using DALL-E 3
 * @param apiKey - OpenAI API key
 * @param prompt - Image prompt
 * @param size - Image size: 1024x1024, 1792x1024, 1024x1792 (default: 1024x1024)
 * @returns Object with image URL and revised prompt
 * @throws ImageGeneratorError on API errors
 */
export async function generateImage(
  apiKey: string,
  prompt: string,
  size: string = DEFAULT_SIZE
): Promise<ImageGenerationResult> {
  // Validate inputs
  if (!apiKey) {
    throw new ImageGeneratorError('invalid_api_key', 401, false, 'OpenAI API key is required');
  }

  if (!prompt || !prompt.trim()) {
    throw new ImageGeneratorError('invalid_input', 400, false, 'Prompt is required and cannot be empty');
  }

  // Check for unsafe content
  if (!isSafePrompt(prompt)) {
    throw new ImageGeneratorError(
      'unsafe_content',
      400,
      false,
      'Prompt contains unsafe keywords. Images must be appropriate for children.'
    );
  }

  // Validate size
  const validSizes = ['1024x1024', '1792x1024', '1024x1792'];
  if (!validSizes.includes(size)) {
    throw new ImageGeneratorError(
      'invalid_size',
      400,
      false,
      `Invalid size. Must be one of: ${validSizes.join(', ')}`
    );
  }

  try {
    const response = await fetch('https://api.openai.com/v1/images/generations', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: DEFAULT_MODEL,
        prompt: prompt.trim(),
        size,
        quality: 'standard',
        n: 1,
        response_format: 'url',
      }),
    });

    if (!response.ok) {
      let errorMessage = 'Unknown image generation error';

      // Try to parse error response
      const contentType = response.headers.get('content-type');
      if (contentType && contentType.includes('application/json')) {
        try {
          const errorData = (await response.json()) as OpenAIImageError;
          errorMessage = errorData.error?.message || errorMessage;
        } catch (parseError) {
          // Ignore parse errors and use generic message
        }
      }

      // Handle specific status codes
      if (response.status === 401) {
        throw new ImageGeneratorError('invalid_api_key', 401, false, 'Invalid OpenAI API key');
      } else if (response.status === 429) {
        throw new ImageGeneratorError('rate_limit', 429, true, 'OpenAI API rate limit exceeded');
      } else if (response.status === 400) {
        throw new ImageGeneratorError(
          'invalid_request',
          400,
          false,
          `Invalid request: ${errorMessage}`
        );
      } else if (response.status === 500 || response.status === 503) {
        throw new ImageGeneratorError(
          'service_unavailable',
          response.status,
          true,
          `OpenAI service error: ${errorMessage}`
        );
      } else if (response.status >= 500) {
        throw new ImageGeneratorError(
          'server_error',
          response.status,
          true,
          `OpenAI server error: ${errorMessage}`
        );
      } else if (response.status >= 400) {
        throw new ImageGeneratorError(
          'client_error',
          response.status,
          false,
          `OpenAI client error: ${errorMessage}`
        );
      }

      throw new ImageGeneratorError(
        'unknown_error',
        response.status,
        response.status >= 500,
        errorMessage
      );
    }

    const data = (await response.json()) as OpenAIImageResponse;

    if (!data.data || data.data.length === 0) {
      throw new ImageGeneratorError('no_images_generated', 500, true, 'OpenAI returned no images');
    }

    const imageData = data.data[0];

    if (!imageData.url) {
      throw new ImageGeneratorError('invalid_response', 500, true, 'OpenAI returned invalid image URL');
    }

    return {
      url: imageData.url,
      revisedPrompt: imageData.revised_prompt || prompt,
    };
  } catch (error) {
    // Re-throw image generator errors
    if (error instanceof ImageGeneratorError) {
      throw error;
    }

    // Handle network errors
    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new ImageGeneratorError(
        'network_error',
        0,
        true,
        `Network error: ${error.message}`
      );
    }

    // Unknown error
    throw new ImageGeneratorError(
      'unknown_error',
      500,
      true,
      error instanceof Error ? error.message : 'Unknown error'
    );
  }
}

/**
 * Download image from URL and return as buffer
 * @param url - Image URL
 * @returns Image data as Buffer
 */
export async function downloadImage(url: string): Promise<Buffer> {
  if (!url || !url.trim()) {
    throw new ImageGeneratorError('invalid_input', 400, false, 'Image URL is required');
  }

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Nova-AssetGenerator/1.0',
      },
    });

    if (!response.ok) {
      throw new ImageGeneratorError(
        'download_failed',
        response.status,
        response.status >= 500,
        `Failed to download image: HTTP ${response.status}`
      );
    }

    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    if (buffer.length === 0) {
      throw new ImageGeneratorError('empty_response', 500, true, 'Downloaded image is empty');
    }

    return buffer;
  } catch (error) {
    if (error instanceof ImageGeneratorError) {
      throw error;
    }

    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new ImageGeneratorError(
        'network_error',
        0,
        true,
        `Network error downloading image: ${error.message}`
      );
    }

    throw new ImageGeneratorError(
      'unknown_error',
      500,
      true,
      error instanceof Error ? error.message : 'Unknown error downloading image'
    );
  }
}

export { ImageGeneratorError };
export type { ImageGenerationResult };
