/**
 * YouTube Transcript Extractor Service
 *
 * Extracts video transcripts and metadata from YouTube URLs.
 * Uses the YouTube timedtext API which doesn't require authentication.
 * Gracefully handles missing or unavailable transcripts.
 */

interface YouTubeTranscript {
  videoId: string;
  title: string;
  transcript: string;
  duration?: number;
}

class YouTubeExtractorError extends Error {
  constructor(
    public code: string,
    message: string
  ) {
    super(message);
    this.name = 'YouTubeExtractorError';
  }
}

/**
 * Extract video ID from various YouTube URL formats
 * @param url - YouTube URL
 * @returns Video ID or null if not a valid YouTube URL
 */
function extractVideoId(url: string): string | null {
  if (!url || typeof url !== 'string') {
    return null;
  }

  const urlStr = url.trim();

  // Match youtube.com/watch?v=VIDEO_ID
  const match1 = urlStr.match(/(?:youtube\.com\/watch\?v=|youtube\.com\/.*[?&]v=)([^&\n?#]+)/);
  if (match1 && match1[1]) {
    return match1[1];
  }

  // Match youtu.be/VIDEO_ID
  const match2 = urlStr.match(/youtu\.be\/([^?&\n#]+)/);
  if (match2 && match2[1]) {
    return match2[1];
  }

  // Match youtube.com/embed/VIDEO_ID
  const match3 = urlStr.match(/youtube\.com\/embed\/([^?&\n#]+)/);
  if (match3 && match3[1]) {
    return match3[1];
  }

  return null;
}

/**
 * Check if a URL is a valid YouTube URL
 * @param url - URL to check
 * @returns True if URL is a YouTube URL
 */
export function isYouTubeUrl(url: string): boolean {
  if (!url || typeof url !== 'string') {
    return false;
  }

  const youtubePattern = /(?:youtube\.com|youtu\.be)\//;
  return youtubePattern.test(url);
}

/**
 * Parse captions XML format and extract text
 */
function parseCaptionsXml(xmlString: string): string {
  try {
    // Simple regex-based parsing since we don't have XML parser
    const captionTexts: string[] = [];

    // Match <text ...>...</text> tags
    const textRegex = /<text[^>]*>([^<]*)<\/text>/g;
    let match: RegExpExecArray | null;

    // Use regex exec in a loop instead of matchAll
    while ((match = textRegex.exec(xmlString)) !== null) {
      if (match[1]) {
        // Decode HTML entities
        const decoded = match[1]
          .replace(/&amp;/g, '&')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&quot;/g, '"')
          .replace(/&#39;/g, "'")
          .replace(/&nbsp;/g, ' ')
          .replace(/<br\s*\/?>/g, ' ');

        // Clean up whitespace
        const cleaned = decoded.trim().replace(/\s+/g, ' ');
        if (cleaned) {
          captionTexts.push(cleaned);
        }
      }
    }

    return captionTexts.join(' ');
  } catch (error) {
    return '';
  }
}

/**
 * Fetch the YouTube watch page and extract info
 */
async function fetchVideoPage(videoId: string): Promise<{ html: string; title: string }> {
  const url = `https://www.youtube.com/watch?v=${videoId}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (!response.ok) {
      throw new YouTubeExtractorError(
        'fetch_failed',
        `Failed to fetch YouTube page: HTTP ${response.status}`
      );
    }

    const html = await response.text();

    // Extract title from <title> tag
    const titleMatch = html.match(/<title>([^<]+)<\/title>/);
    const title = titleMatch ? titleMatch[1].replace(' - YouTube', '').trim() : `Video ${videoId}`;

    return { html, title };
  } catch (error) {
    if (error instanceof YouTubeExtractorError) {
      throw error;
    }

    throw new YouTubeExtractorError(
      'fetch_error',
      error instanceof Error ? error.message : 'Failed to fetch YouTube page'
    );
  }
}

/**
 * Extract caption track URLs from the page HTML
 */
function extractCaptionUrls(html: string): string[] {
  const urls: Set<string> = new Set();

  // Look for captions in the initial data
  const captionTracksMatch = html.match(/"captions":\s*\{[^}]*"playerCaptionsTracklistRenderer"[^}]*"captionTracks"\s*:\s*(\[[^\]]*\])/);

  if (captionTracksMatch) {
    try {
      const trackData = JSON.parse(captionTracksMatch[1]);

      if (Array.isArray(trackData)) {
        for (const track of trackData) {
          if (track && typeof track === 'object' && (track as Record<string, unknown>).baseUrl) {
            urls.add((track as Record<string, unknown>).baseUrl as string);
          }
        }
      }
    } catch (e) {
      // Ignore JSON parse errors, continue with other extraction methods
    }
  }

  // Fallback: look for direct caption URLs in the HTML
  const urlRegex = /\/api\/timedtext\?[^"&\s<]*(?:&[^"&\s<]*)*v=[a-zA-Z0-9_-]+[^"&\s<]*/g;
  let match: RegExpExecArray | null;

  while ((match = urlRegex.exec(html)) !== null) {
    if (match[0]) {
      const fullUrl = match[0].startsWith('http') ? match[0] : `https://www.youtube.com${match[0]}`;
      urls.add(fullUrl);
    }
  }

  return Array.from(urls);
}

/**
 * Fetch and parse captions from URL
 */
async function fetchCaptions(captionUrl: string): Promise<string> {
  try {
    const response = await fetch(captionUrl, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    });

    if (!response.ok) {
      return '';
    }

    const xml = await response.text();
    return parseCaptionsXml(xml);
  } catch (error) {
    return '';
  }
}

/**
 * Extract transcript and metadata from a YouTube URL
 * @param url - YouTube URL (supports multiple formats)
 * @returns Transcript data including video ID, title, and transcript text
 */
export async function extractYouTubeTranscript(url: string): Promise<YouTubeTranscript> {
  // Validate and extract video ID
  if (!url || typeof url !== 'string') {
    throw new YouTubeExtractorError('invalid_input', 'URL is required');
  }

  const videoId = extractVideoId(url);

  if (!videoId) {
    throw new YouTubeExtractorError('invalid_youtube_url', 'Invalid YouTube URL format');
  }

  try {
    // Fetch the video page
    const { html, title } = await fetchVideoPage(videoId);

    // Extract caption URLs
    const captionUrls = extractCaptionUrls(html);

    let transcript = '';

    // Try to fetch captions from available URLs
    if (captionUrls.length > 0) {
      for (const captionUrl of captionUrls) {
        const text = await fetchCaptions(captionUrl);

        if (text && text.length > 0) {
          transcript = text;
          break; // Use the first successful transcript
        }
      }
    }

    // If no transcripts found, return graceful empty response
    if (!transcript) {
      console.warn(`No transcript available for video ${videoId}`);
    }

    return {
      videoId,
      title,
      transcript: transcript || '',
    };
  } catch (error) {
    if (error instanceof YouTubeExtractorError) {
      throw error;
    }

    // Graceful fallback: return video info even if transcript fails
    const videoId = extractVideoId(url);

    if (videoId) {
      return {
        videoId,
        title: `Video ${videoId}`,
        transcript: '',
      };
    }

    throw new YouTubeExtractorError(
      'extraction_failed',
      error instanceof Error ? error.message : 'Failed to extract YouTube transcript'
    );
  }
}

export { YouTubeExtractorError };
export type { YouTubeTranscript };
