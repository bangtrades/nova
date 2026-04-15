/**
 * Content Scraper Service
 *
 * Extracts clean content from URLs using a simple DOM parser approach.
 * Falls back to basic text extraction for reliability.
 */

import { CONTENT_SCRAPER_TIMEOUT, MAX_CONTENT_LENGTH } from './promptTemplates';

export interface ScrapedContent {
  url: string;
  title: string;
  content: string;
  excerpt: string;
  siteName: string;
  byline: string;
  length: number;
  publishedTime?: string;
}

/**
 * Scrape a URL and extract readable content using Readability
 */
export async function scrapeUrl(url: string): Promise<ScrapedContent> {
  // Validate URL
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(url);
  } catch {
    throw new Error(`Invalid URL: ${url}`);
  }

  // Enforce HTTPS or HTTP only
  if (!['http:', 'https:'].includes(parsedUrl.protocol)) {
    throw new Error(`Unsupported protocol: ${parsedUrl.protocol}`);
  }

  // Fetch the URL with timeout
  let html: string;
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), CONTENT_SCRAPER_TIMEOUT);

    const response = await fetch(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
      signal: controller.signal,
    });

    clearTimeout(timeoutId);

    // Check response status
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    // Get content type
    const contentType = response.headers.get('content-type') || '';
    if (!contentType.includes('text/html')) {
      throw new Error(`Expected HTML content, got: ${contentType}`);
    }

    html = await response.text();

    // Check content length
    if (html.length > MAX_CONTENT_LENGTH) {
      html = html.substring(0, MAX_CONTENT_LENGTH);
    }
  } catch (error) {
    if (error instanceof Error) {
      if (error.name === 'AbortError') {
        throw new Error(`Scrape timeout (${CONTENT_SCRAPER_TIMEOUT}ms)`);
      }
      throw new Error(`Failed to fetch URL: ${error.message}`);
    }
    throw new Error('Failed to fetch URL: Unknown error');
  }

  // Simple HTML parsing - extract title, meta tags, and body text
  try {
    // Extract title from <title> tag
    const titleMatch = html.match(/<title[^>]*>([^<]*)<\/title>/i);
    const title = titleMatch ? titleMatch[1].trim() : parsedUrl.hostname || 'Untitled';

    // Extract description from meta tags
    const descMatch = html.match(/<meta\s+name="description"\s+content="([^"]*)"/i);
    const excerpt = descMatch ? descMatch[1] : '';

    // Extract Open Graph description if available
    const ogMatch = html.match(/<meta\s+property="og:description"\s+content="([^"]*)"/i);
    const ogDescription = ogMatch ? ogMatch[1] : excerpt;

    // Extract publish date if available
    const publishedMatch = html.match(/<meta[^>]*property="article:published_time"[^>]*content="([^"]*)"/i);
    const publishedTime = publishedMatch ? publishedMatch[1] : undefined;

    // Extract site name
    const siteNameMatch = html.match(/<meta[^>]*property="og:site_name"[^>]*content="([^"]*)"/i);
    const siteName = siteNameMatch ? siteNameMatch[1] : parsedUrl.hostname?.replace('www.', '') || '';

    // Extract body text - remove scripts and styles first
    let content = html
      .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ')
      .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ')
      .replace(/<[^>]*>/g, ' ') // Remove all HTML tags
      .replace(/\s+/g, ' ') // Collapse whitespace
      .trim();

    // Limit content length
    if (content.length > MAX_CONTENT_LENGTH) {
      content = content.substring(0, MAX_CONTENT_LENGTH);
    }

    return {
      url,
      title,
      content,
      excerpt: ogDescription || excerpt,
      siteName,
      byline: '', // Not easily extractable without complex parsing
      length: content.length,
      publishedTime,
    };
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to parse content: ${error.message}`);
    }
    throw new Error('Failed to parse content: Unknown error');
  }
}

