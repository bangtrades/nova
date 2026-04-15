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
 * Build a child-safe, kid-friendly image prompt from a concept
 * @param concept - The learning concept to illustrate
 * @param cardType - Type of card (story, concept, experiment, etc.)
 * @returns A safe, kid-friendly DALL-E prompt
 */
export function buildImagePrompt(concept: string, cardType: string): string {
  // Base style for all images
  const baseStyle = 'Pixar-style, bright colorful illustration, rounded shapes, cheerful, no text, no people faces';

  // Context-specific prompt building
  let contextPrompt = '';

  if (cardType === 'story') {
    contextPrompt = `A storybook illustration depicting: ${concept}`;
  } else if (cardType === 'experiment') {
    contextPrompt = `A fun science experiment scene showing: ${concept}`;
  } else if (cardType === 'concept') {
    contextPrompt = `An educational illustration explaining: ${concept}`;
  } else if (cardType === 'quiz') {
    contextPrompt = `A learning-themed illustration about: ${concept}`;
  } else {
    contextPrompt = `A friendly educational illustration of: ${concept}`;
  }

  // Combine with safety prefix
  const fullPrompt = `Colorful, friendly illustration for a 4-8 year old child. ${contextPrompt}. ${baseStyle}`;

  return fullPrompt;
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
