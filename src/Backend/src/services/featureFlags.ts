/**
 * Feature Flag System (NOVA-300)
 *
 * Server-side feature flag management with:
 * - In-memory store with DB persistence
 * - Hash-based deterministic rollout
 * - Tier-based access control
 */

import { getPrismaClient } from '@db/client';

export interface FeatureFlag {
  key: string;
  enabled: boolean;
  rolloutPercentage: number;
  allowedTiers: string[];
  metadata: Record<string, any>;
}

// In-memory cache
let flagCache: Map<string, FeatureFlag> = new Map();

// Default flags configuration
const DEFAULT_FLAGS: FeatureFlag[] = [
  {
    key: 'sparky_voice_chat',
    enabled: true,
    rolloutPercentage: 100,
    allowedTiers: ['free', 'pro', 'premium'],
    metadata: { description: 'Voice chat with Sparky AI assistant' },
  },
  {
    key: 'ai_image_generation',
    enabled: true,
    rolloutPercentage: 100,
    allowedTiers: ['free', 'pro', 'premium'],
    metadata: { description: 'AI-generated illustrations for lessons' },
  },
  {
    key: 'youtube_import',
    enabled: true,
    rolloutPercentage: 50,
    allowedTiers: ['pro', 'premium'],
    metadata: { description: 'Import lessons from YouTube videos' },
  },
  {
    key: 'advanced_analytics',
    enabled: false,
    rolloutPercentage: 0,
    allowedTiers: ['premium'],
    metadata: { description: 'Advanced learning analytics dashboard' },
  },
  {
    key: 'family_sharing',
    enabled: false,
    rolloutPercentage: 0,
    allowedTiers: ['premium'],
    metadata: { description: 'Share learning paths with family members' },
  },
];

/**
 * Simple hash function to convert userId to deterministic bucket (0-99)
 */
function hashUserId(userId: string): number {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    const char = userId.charCodeAt(i);
    hash = (hash << 5) - hash + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  return Math.abs(hash) % 100;
}

/**
 * Check if a feature is enabled for a specific user
 * Takes into account: enabled status, rollout percentage, and tier
 */
export function isFeatureEnabled(
  flagKey: string,
  userId?: string,
  userTier: string = 'free'
): boolean {
  const flag = flagCache.get(flagKey);

  if (!flag) {
    return false;
  }

  // Check if flag is globally enabled
  if (!flag.enabled) {
    return false;
  }

  // Check if user's tier has access
  if (!flag.allowedTiers.includes(userTier)) {
    return false;
  }

  // Check rollout percentage for this user
  if (flag.rolloutPercentage < 100) {
    if (!userId) {
      return false;
    }
    const bucket = hashUserId(userId);
    return bucket < flag.rolloutPercentage;
  }

  return true;
}

/**
 * Get all feature flags
 */
export function getAllFlags(): FeatureFlag[] {
  return Array.from(flagCache.values());
}

/**
 * Update a feature flag
 */
export function setFlag(key: string, updates: Partial<FeatureFlag>): void {
  const existing = flagCache.get(key);

  if (!existing) {
    throw new Error(`Feature flag not found: ${key}`);
  }

  const updated: FeatureFlag = {
    ...existing,
    ...updates,
    key: existing.key, // Ensure key is not changed
  };

  flagCache.set(key, updated);
}

/**
 * Initialize feature flags from DB or use defaults
 * Called once at server startup
 */
export async function initializeFlags(): Promise<void> {
  try {
    const prisma = getPrismaClient();

    // Try to load from DB using Prisma model
    const dbFlags = await (prisma as any).featureFlag.findMany();

    if (Array.isArray(dbFlags) && dbFlags.length > 0) {
      // Use DB flags
      flagCache.clear();
      dbFlags.forEach((flag: any) => {
        flagCache.set(flag.key, {
          key: flag.key,
          enabled: flag.enabled,
          rolloutPercentage: flag.rolloutPercentage,
          allowedTiers: Array.isArray(flag.allowedTiers) ? flag.allowedTiers : [],
          metadata: flag.metadata || {},
        });
      });
      console.log(`Loaded ${dbFlags.length} feature flags from database`);
    } else {
      // Use defaults
      flagCache.clear();
      DEFAULT_FLAGS.forEach((flag) => {
        flagCache.set(flag.key, flag);
      });
      console.log(`Initialized ${DEFAULT_FLAGS.length} default feature flags`);
    }
  } catch (error) {
    // If DB query fails, use defaults
    console.warn(`Failed to load feature flags from DB, using defaults: ${error}`);
    flagCache.clear();
    DEFAULT_FLAGS.forEach((flag) => {
      flagCache.set(flag.key, flag);
    });
  }
}

/**
 * Force reset flags to defaults (for testing)
 */
export function resetToDefaults(): void {
  flagCache.clear();
  DEFAULT_FLAGS.forEach((flag) => {
    flagCache.set(flag.key, flag);
  });
}
