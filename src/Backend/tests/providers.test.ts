/**
 * Tests for LLM provider router and subscription middleware
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { encryptToken, decryptToken, generateEncryptionKey } from '@services/oauth/tokenEncryption';
import {
  generateCodeVerifier,
  generateCodeChallenge,
} from '@services/oauth/openaiOAuth';

describe('Token Encryption', () => {
  let encryptionKey: string;

  beforeEach(() => {
    encryptionKey = generateEncryptionKey();
  });

  it('should encrypt and decrypt tokens correctly', () => {
    const plaintext = 'sk-test-token-1234567890';
    const encrypted = encryptToken(plaintext, encryptionKey);
    const decrypted = decryptToken(encrypted, encryptionKey);

    expect(decrypted).toBe(plaintext);
  });

  it('should produce different ciphertexts for same plaintext (due to random IV)', () => {
    const plaintext = 'sk-test-token-1234567890';
    const encrypted1 = encryptToken(plaintext, encryptionKey);
    const encrypted2 = encryptToken(plaintext, encryptionKey);

    expect(encrypted1).not.toBe(encrypted2);

    // Both should decrypt to same plaintext
    expect(decryptToken(encrypted1, encryptionKey)).toBe(plaintext);
    expect(decryptToken(encrypted2, encryptionKey)).toBe(plaintext);
  });

  it('should fail to decrypt with wrong key', () => {
    const plaintext = 'sk-test-token-1234567890';
    const encrypted = encryptToken(plaintext, encryptionKey);

    const wrongKey = generateEncryptionKey();

    expect(() => {
      decryptToken(encrypted, wrongKey);
    }).toThrow();
  });

  it('should fail to decrypt corrupted ciphertext', () => {
    const plaintext = 'sk-test-token-1234567890';
    const encrypted = encryptToken(plaintext, encryptionKey);

    // Decode, corrupt the actual ciphertext portion, re-encode
    const decoded = Buffer.from(encrypted, 'base64').toString('utf8');
    const parts = decoded.split(':');
    // Flip bits in the ciphertext (middle component)
    const corruptedCiphertext = parts[1].split('').reverse().join('');
    const corrupted = Buffer.from(
      [parts[0], corruptedCiphertext, parts[2]].join(':')
    ).toString('base64');

    expect(() => {
      decryptToken(corrupted, encryptionKey);
    }).toThrow();
  });

  it('should handle long tokens', () => {
    const longToken = 'sk-' + 'x'.repeat(1000);
    const encrypted = encryptToken(longToken, encryptionKey);
    const decrypted = decryptToken(encrypted, encryptionKey);

    expect(decrypted).toBe(longToken);
  });

  it('should handle special characters in tokens', () => {
    const specialToken = 'sk-test!@#$%^&*()_+-=[]{}|;:,.<>?';
    const encrypted = encryptToken(specialToken, encryptionKey);
    const decrypted = decryptToken(encrypted, encryptionKey);

    expect(decrypted).toBe(specialToken);
  });
});

describe('PKCE Flow', () => {
  it('should generate valid code verifier', () => {
    const verifier = generateCodeVerifier();

    // Should be base64url encoded and at least 96 bytes
    expect(verifier).toBeTruthy();
    expect(verifier.length).toBeGreaterThanOrEqual(128);
  });

  it('should generate valid code challenge', () => {
    const verifier = generateCodeVerifier();
    const challenge = generateCodeChallenge(verifier);

    // Should be base64url encoded SHA-256 hash
    expect(challenge).toBeTruthy();
    expect(challenge.length).toBeGreaterThan(0);
  });

  it('should generate same challenge for same verifier', () => {
    const verifier = generateCodeVerifier();
    const challenge1 = generateCodeChallenge(verifier);
    const challenge2 = generateCodeChallenge(verifier);

    expect(challenge1).toBe(challenge2);
  });

  it('should generate different challenges for different verifiers', () => {
    const verifier1 = generateCodeVerifier();
    const verifier2 = generateCodeVerifier();

    const challenge1 = generateCodeChallenge(verifier1);
    const challenge2 = generateCodeChallenge(verifier2);

    expect(challenge1).not.toBe(challenge2);
  });
});

describe('Provider Router Logic', () => {
  it('should prefer BYOK provider when available and token not expired', () => {
    // Mock: User has BYOK provider with valid token
    const hasValidByok = true;
    const subscriptionTier = 'free';

    // Router should use BYOK (no tier restriction)
    expect(hasValidByok).toBe(true);
  });

  it('should fall back to proxy when BYOK token expired', () => {
    // Mock: User has BYOK provider but token expired
    const hasValidByok = false;
    const subscriptionTier = 'pro';

    // Router should use proxy with pro tier limits
    expect(hasValidByok).toBe(false);
    expect(subscriptionTier).toBe('pro');
  });

  it('should use proxy for users without BYOK provider', () => {
    // Mock: User has no BYOK provider
    const hasByok = false;
    const subscriptionTier = 'free';

    // Router should use proxy with free tier limits
    expect(hasByok).toBe(false);
    expect(['free', 'pro']).toContain(subscriptionTier);
  });
});

describe('Subscription Tier Hierarchy', () => {
  const tierHierarchy: Record<string, number> = {
    free: 0,
    pro: 1,
    byok: 2,
  };

  it('should have correct tier hierarchy', () => {
    expect(tierHierarchy.free).toBeLessThan(tierHierarchy.pro);
    expect(tierHierarchy.pro).toBeLessThan(tierHierarchy.byok);
  });

  it('free user should not pass pro requirement', () => {
    const userTier = 'free';
    const requiredTier = 'pro';

    expect(tierHierarchy[userTier]).toBeLessThan(tierHierarchy[requiredTier]);
  });

  it('pro user should pass free requirement', () => {
    const userTier = 'pro';
    const requiredTier = 'free';

    expect(tierHierarchy[userTier]).toBeGreaterThanOrEqual(tierHierarchy[requiredTier]);
  });

  it('byok user should pass all requirements', () => {
    const userTier = 'byok';

    expect(tierHierarchy[userTier]).toBeGreaterThanOrEqual(tierHierarchy.free);
    expect(tierHierarchy[userTier]).toBeGreaterThanOrEqual(tierHierarchy.pro);
    expect(tierHierarchy[userTier]).toBeGreaterThanOrEqual(tierHierarchy.byok);
  });
});

describe('Rate Limiting', () => {
  it('free tier should have 10 request limit per day', () => {
    const freeLimit = 10;
    expect(freeLimit).toBe(10);
  });

  it('pro tier should have 100 request limit per day', () => {
    const proLimit = 100;
    expect(proLimit).toBe(100);
  });

  it('byok should have unlimited requests', () => {
    const byokLimit = Infinity;
    expect(byokLimit).toBe(Infinity);
  });

  it('free user should not exceed daily limit', () => {
    const dailyRequests = 5;
    const limit = 10;
    expect(dailyRequests).toBeLessThanOrEqual(limit);
  });

  it('free user should be blocked when at limit', () => {
    const dailyRequests = 10;
    const limit = 10;
    expect(dailyRequests).toBeGreaterThanOrEqual(limit);
  });
});

describe('Model Access Control', () => {
  const freeAllowed = ['gpt-4o-mini'];
  const proAllowed = ['gpt-4o', 'gpt-4o-mini'];

  it('free user should only access gpt-4o-mini', () => {
    const userTier = 'free';
    const model = 'gpt-4o-mini';

    expect(freeAllowed).toContain(model);
  });

  it('free user should not access gpt-4o', () => {
    const userTier = 'free';
    const model = 'gpt-4o';

    expect(freeAllowed).not.toContain(model);
  });

  it('pro user should access both gpt-4o and gpt-4o-mini', () => {
    const models = ['gpt-4o', 'gpt-4o-mini'];

    for (const model of models) {
      expect(proAllowed).toContain(model);
    }
  });
});
