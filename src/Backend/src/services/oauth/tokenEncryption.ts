/**
 * AES-256-GCM encryption/decryption for OAuth tokens
 *
 * Tokens are encrypted before storage in the database to ensure
 * that even if the database is compromised, the tokens remain secure.
 *
 * Each encrypted token includes:
 * - The ciphertext (encrypted token)
 * - The IV (initialization vector) - unique for each encryption
 * - The auth tag (for authentication tag)
 *
 * All components are base64 encoded for storage.
 */

import { randomBytes, createCipheriv, createDecipheriv } from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 16; // bytes
const AUTH_TAG_LENGTH = 16; // bytes
const SALT_LENGTH = 16; // bytes for key derivation

/**
 * Encrypts a plaintext token using AES-256-GCM
 * @param plaintext - The token to encrypt
 * @param key - The encryption key (32 bytes for AES-256)
 * @returns Base64 encoded string containing iv:ciphertext:authTag
 */
export function encryptToken(plaintext: string, key: string): string {
  // Convert hex key to Buffer
  const keyBuffer = Buffer.from(key, 'hex');

  if (keyBuffer.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (256 bits)');
  }

  // Generate a random IV for this encryption
  const iv = randomBytes(IV_LENGTH);

  // Create cipher
  const cipher = createCipheriv(ALGORITHM, keyBuffer, iv);

  // Encrypt the plaintext
  let ciphertext = cipher.update(plaintext, 'utf8', 'hex');
  ciphertext += cipher.final('hex');

  // Get the authentication tag
  const authTag = cipher.getAuthTag();

  // Combine all components: iv:ciphertext:authTag
  // Each encoded separately for easier parsing
  const combined = [
    iv.toString('hex'),
    ciphertext,
    authTag.toString('hex'),
  ].join(':');

  // Base64 encode the combined result for storage
  return Buffer.from(combined).toString('base64');
}

/**
 * Decrypts a base64 encoded token
 * @param encrypted - Base64 encoded string from encryptToken()
 * @param key - The encryption key (must match the key used for encryption)
 * @returns The decrypted plaintext token
 */
export function decryptToken(encrypted: string, key: string): string {
  // Convert hex key to Buffer
  const keyBuffer = Buffer.from(key, 'hex');

  if (keyBuffer.length !== 32) {
    throw new Error('Encryption key must be 32 bytes (256 bits)');
  }

  try {
    // Decode from base64 back to the original iv:ciphertext:authTag string
    const combined = Buffer.from(encrypted, 'base64').toString('utf8');

    // Split the combined string
    const [ivHex, ciphertext, authTagHex] = combined.split(':');

    if (!ivHex || !ciphertext || !authTagHex) {
      throw new Error('Invalid encrypted token format');
    }

    const iv = Buffer.from(ivHex, 'hex');
    const authTag = Buffer.from(authTagHex, 'hex');

    // Create decipher
    const decipher = createDecipheriv(ALGORITHM, keyBuffer, iv);

    // Set the authentication tag for verification
    decipher.setAuthTag(authTag);

    // Decrypt
    let plaintext = decipher.update(ciphertext, 'hex', 'utf8');
    plaintext += decipher.final('utf8');

    return plaintext;
  } catch (error) {
    throw new Error(
      `Failed to decrypt token: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Generates a random 32-byte (256-bit) encryption key in hex format
 * Useful for generating ENCRYPTION_KEY env variable
 * @returns A 64-character hex string (32 bytes)
 */
export function generateEncryptionKey(): string {
  return randomBytes(32).toString('hex');
}
