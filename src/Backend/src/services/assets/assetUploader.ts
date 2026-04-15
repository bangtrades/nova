/**
 * Asset Uploader Service
 *
 * Uploads generated assets (images, audio) to Cloudflare R2 (S3-compatible).
 * Falls back to local file simulation in dev mode if R2 is not configured.
 * Uses S3 v4 signing for authentication.
 */

import { createHmac, randomUUID, createHash } from 'crypto';
import { getConfig } from '@config';

interface S3SigningParameters {
  bucket: string;
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  service: string;
  date: string;
  dateTime: string;
}

class AssetUploaderError extends Error {
  constructor(
    public code: string,
    public statusCode: number,
    message: string
  ) {
    super(message);
    this.name = 'AssetUploaderError';
  }
}

/**
 * Generate a secure filename with UUID and extension
 */
function generateSecureFilename(lessonId: string, type: string, extension: string): string {
  // Generate UUID v4
  const uuid = randomUUID();
  // Sanitize lessonId to prevent path traversal
  const safeLessonId = lessonId.replace(/[^a-z0-9-]/gi, '');
  const safeType = type.replace(/[^a-z0-9-]/gi, '');
  return `assets/${safeLessonId}/${safeType}/${uuid}.${extension}`;
}

/**
 * Calculate S3 v4 signature for authentication
 */
function calculateS3Signature(
  secretAccessKey: string,
  dateStr: string,
  regionStr: string,
  stringToSign: string
): string {
  const kDate = createHmac('sha256', `AWS4${secretAccessKey}`)
    .update(dateStr)
    .digest();

  const kRegion = createHmac('sha256', kDate)
    .update(regionStr)
    .digest();

  const kService = createHmac('sha256', kRegion)
    .update('s3')
    .digest();

  const kSigning = createHmac('sha256', kService)
    .update('aws4_request')
    .digest();

  return createHmac('sha256', kSigning)
    .update(stringToSign)
    .digest('hex');
}

/**
 * Upload asset to Cloudflare R2
 * @param buffer - File data as buffer
 * @param filename - Target filename in R2 bucket
 * @param contentType - MIME type (e.g., audio/mpeg, image/png)
 * @returns CDN URL to the uploaded asset
 * @throws AssetUploaderError on upload failures
 */
export async function uploadToR2(
  buffer: Buffer,
  filename: string,
  contentType: string
): Promise<string> {
  const config = getConfig();

  // Dev fallback: if R2 not configured, return mock URL
  if (!config.R2_ACCESS_KEY_ID || !config.R2_SECRET_ACCESS_KEY || !config.R2_PUBLIC_URL) {
    const mockUrl = `${config.R2_PUBLIC_URL || 'http://localhost:3000'}/assets/mock/${filename}`;
    return mockUrl;
  }

  const bucket = config.R2_BUCKET_NAME || 'nova-assets';
  const accountId = config.R2_ACCOUNT_ID || 'dev';
  const accessKeyId = config.R2_ACCESS_KEY_ID;
  const secretAccessKey = config.R2_SECRET_ACCESS_KEY;
  const publicUrl = config.R2_PUBLIC_URL;

  // R2 uses us-east-1 region
  const region = 'us-east-1';
  const service = 's3';
  const host = `${bucket}.${accountId}.r2.cloudflarestorage.com`;

  // Generate timestamps
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0].replace(/-/g, '');
  const dateTimeStr = now.toISOString().replace(/[:-]/g, '').replace(/\.\d{3}/, '');

  // Create canonical request
  const method = 'PUT';
  const canonicalUri = `/${filename}`;
  const canonicalQueryString = '';

  const payloadHash = createHash('sha256').update(buffer).digest('hex');

  const canonicalHeaders = `content-type:${contentType}\nhost:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${dateTimeStr}\n`;
  const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
  const canonicalRequest = `${method}\n${canonicalUri}\n${canonicalQueryString}\n${canonicalHeaders}\n${signedHeaders}\n${payloadHash}`;

  // Create string to sign
  const canonicalRequestHash = createHash('sha256').update(canonicalRequest).digest('hex');
  const credentialScope = `${dateStr}/${region}/${service}/aws4_request`;
  const stringToSign = `AWS4-HMAC-SHA256\n${dateTimeStr}\n${credentialScope}\n${canonicalRequestHash}`;

  // Calculate signature
  const signature = calculateS3Signature(secretAccessKey, dateStr, region, stringToSign);

  // Create authorization header
  const authorizationHeader = `AWS4-HMAC-SHA256 Credential=${accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  try {
    const response = await fetch(`https://${host}${canonicalUri}`, {
      method: 'PUT',
      headers: {
        'Content-Type': contentType,
        'x-amz-date': dateTimeStr,
        'x-amz-content-sha256': payloadHash,
        Authorization: authorizationHeader,
        'Cache-Control': 'public, max-age=31536000, immutable',
      },
      body: buffer as any,
    });

    if (!response.ok) {
      let errorMessage = `R2 upload failed with status ${response.status}`;

      try {
        const text = await response.text();
        if (text) {
          errorMessage = text.substring(0, 200);
        }
      } catch (parseError) {
        // Ignore parse errors
      }

      throw new AssetUploaderError(
        'upload_failed',
        response.status,
        `Failed to upload to R2: ${errorMessage}`
      );
    }

    // Construct the CDN URL
    const cdnUrl = `${publicUrl}/${filename}`;
    return cdnUrl;
  } catch (error) {
    if (error instanceof AssetUploaderError) {
      throw error;
    }

    if (error instanceof TypeError && error.message.includes('fetch')) {
      throw new AssetUploaderError(
        'network_error',
        0,
        `Network error uploading to R2: ${error.message}`
      );
    }

    throw new AssetUploaderError(
      'unknown_error',
      500,
      error instanceof Error ? error.message : 'Unknown error uploading to R2'
    );
  }
}

/**
 * Upload audio asset to R2
 * @param buffer - Audio buffer (mp3)
 * @param lessonId - Lesson ID for organizing files
 * @param cardIndex - Card index in lesson
 * @returns CDN URL to the audio file
 */
export async function uploadAudio(
  buffer: Buffer,
  lessonId: string,
  cardIndex: number
): Promise<string> {
  const filename = generateSecureFilename(lessonId, 'audio', 'mp3');
  return uploadToR2(buffer, filename, 'audio/mpeg');
}

/**
 * Upload image asset to R2
 * @param buffer - Image buffer (png)
 * @param lessonId - Lesson ID for organizing files
 * @param cardIndex - Card index in lesson
 * @returns CDN URL to the image file
 */
export async function uploadImage(
  buffer: Buffer,
  lessonId: string,
  cardIndex: number
): Promise<string> {
  const filename = generateSecureFilename(lessonId, 'images', 'png');
  return uploadToR2(buffer, filename, 'image/png');
}

export { AssetUploaderError };
