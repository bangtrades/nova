/**
 * In-memory token blacklist service for JWT revocation.
 *
 * In production, this would be backed by Redis for distributed deployments.
 * For MVP, an in-memory Set with periodic cleanup is sufficient.
 *
 * Each blacklisted token is stored with its expiration time.
 * Expired entries are automatically cleaned up every 15 minutes.
 */

interface BlacklistedToken {
  expiresAt: Date;
}

class TokenBlacklistService {
  private blacklist: Map<string, BlacklistedToken> = new Map();
  private cleanupInterval: ReturnType<typeof setInterval> | null = null;

  /**
   * Initialize the blacklist service and start periodic cleanup.
   */
  public initialize(): void {
    if (!this.cleanupInterval) {
      this.cleanupInterval = setInterval(() => {
        this.cleanup();
      }, 15 * 60 * 1000); // 15 minutes

      // Unref the timer so it doesn't prevent process exit
      this.cleanupInterval.unref();
    }
  }

  /**
   * Add a token to the blacklist.
   *
   * @param jti - The JWT ID claim (unique token identifier)
   * @param expiresAt - The token expiration date
   */
  public blacklistToken(jti: string, expiresAt: Date): void {
    this.blacklist.set(jti, { expiresAt });
  }

  /**
   * Check if a token is blacklisted.
   *
   * @param jti - The JWT ID claim to check
   * @returns true if the token is blacklisted, false otherwise
   */
  public isBlacklisted(jti: string): boolean {
    return this.blacklist.has(jti);
  }

  /**
   * Remove expired entries from the blacklist.
   *
   * This method is called periodically (every 15 minutes) to clean up
   * tokens that have already expired and are no longer a security concern.
   */
  public cleanup(): void {
    const now = new Date();
    let removedCount = 0;

    for (const [jti, token] of this.blacklist.entries()) {
      if (token.expiresAt <= now) {
        this.blacklist.delete(jti);
        removedCount++;
      }
    }

    if (removedCount > 0) {
      console.log(`[TokenBlacklist] Cleaned up ${removedCount} expired tokens`);
    }
  }

  /**
   * Stop the cleanup interval (useful for testing and graceful shutdown).
   */
  public shutdown(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  /**
   * Get the current size of the blacklist (useful for monitoring).
   */
  public size(): number {
    return this.blacklist.size;
  }

  /**
   * Clear the entire blacklist (useful for testing).
   */
  public clear(): void {
    this.blacklist.clear();
  }
}

// Export singleton instance
export const tokenBlacklistService = new TokenBlacklistService();

// Auto-initialize on first import
tokenBlacklistService.initialize();

export default tokenBlacklistService;
