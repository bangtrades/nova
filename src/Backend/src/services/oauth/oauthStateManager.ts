/**
 * OAuth state and PKCE verifier management
 *
 * Stores OAuth state tokens and PKCE code verifiers temporarily.
 * In production, this would use Redis for distributed deployments.
 * For MVP, an in-memory Map with 10-minute expiry is sufficient.
 *
 * State is used for CSRF protection, and code_verifier is needed
 * to complete the PKCE flow.
 */

interface OAuthState {
  codeVerifier: string;
  expiresAt: Date;
}

class OAuthStateManager {
  private states: Map<string, OAuthState> = new Map();
  private cleanupInterval: ReturnType<typeof setInterval> | null = null;
  private readonly STATE_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes

  /**
   * Initialize the state manager and start periodic cleanup.
   */
  public initialize(): void {
    if (!this.cleanupInterval) {
      this.cleanupInterval = setInterval(() => {
        this.cleanup();
      }, this.STATE_EXPIRY_MS);

      // Unref the timer so it doesn't prevent process exit
      this.cleanupInterval.unref();
    }
  }

  /**
   * Store OAuth state with its associated PKCE code verifier
   * @param state - The state string (from authorization URL)
   * @param codeVerifier - The PKCE code verifier
   */
  public storeState(state: string, codeVerifier: string): void {
    const expiresAt = new Date(Date.now() + this.STATE_EXPIRY_MS);
    this.states.set(state, { codeVerifier, expiresAt });
  }

  /**
   * Retrieve and consume OAuth state
   * @param state - The state string to retrieve
   * @returns The code verifier if state is valid, null otherwise
   */
  public consumeState(state: string): string | null {
    const entry = this.states.get(state);

    if (!entry) {
      return null;
    }

    // Check if expired
    if (entry.expiresAt <= new Date()) {
      this.states.delete(state);
      return null;
    }

    // Consume the state (one-time use)
    this.states.delete(state);

    return entry.codeVerifier;
  }

  /**
   * Clean up expired states
   */
  public cleanup(): void {
    const now = new Date();
    let removedCount = 0;

    for (const [state, entry] of this.states.entries()) {
      if (entry.expiresAt <= now) {
        this.states.delete(state);
        removedCount++;
      }
    }

    if (removedCount > 0) {
      console.log(`[OAuthStateManager] Cleaned up ${removedCount} expired states`);
    }
  }

  /**
   * Stop the cleanup interval (useful for testing and graceful shutdown)
   */
  public shutdown(): void {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  /**
   * Get the current size (useful for monitoring)
   */
  public size(): number {
    return this.states.size;
  }

  /**
   * Clear all states (useful for testing)
   */
  public clear(): void {
    this.states.clear();
  }
}

// Export singleton instance
export const oauthStateManager = new OAuthStateManager();

// Auto-initialize on first import
oauthStateManager.initialize();

export default oauthStateManager;
