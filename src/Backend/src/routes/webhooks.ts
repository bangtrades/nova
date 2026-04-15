/**
 * Webhook Routes
 *
 * Handles server notifications from Apple's StoreKit 2.
 * Processes subscription events and updates user subscription status.
 *
 * No authentication required - Apple calls these endpoints directly.
 */

import type { FastifyInstance } from 'fastify';
import { getPrismaClient } from '@db/client';

/**
 * StoreKit 2 event types
 */
type StoreKitEventType =
  | 'SUBSCRIBED'
  | 'DID_RENEW'
  | 'DID_FAIL_TO_RENEW'
  | 'DID_CHANGE_RENEWAL_STATUS'
  | 'EXPIRED'
  | 'GRACE_PERIOD_EXPIRES';

/**
 * StoreKit 2 notification payload
 */
interface StoreKitNotification {
  signedPayload: string;
}

/**
 * Decoded StoreKit transaction info
 */
interface TransactionInfo {
  transactionId: string;
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;
  originalPurchaseDate: number;
  expiresDate: number;
  quantity: number;
  type: string;
  appAccountToken: string;
  inAppOwnershipType: string;
  signedDate: number;
  environment: string;
  transactionReason: string;
  storefront: string;
  storefrontId: string;
}

/**
 * Decoded renewal info
 */
interface RenewalInfo {
  expirationIntent: number;
  originalTransactionId: string;
  autoRenewProductId: string;
  productId: string;
  autoRenewStatus: number;
  isUpgraded: boolean;
  signedDate: number;
  environment: string;
  renewalDate: number;
  recentSubscriptionStartDate: number;
}

/**
 * Decoded notification data
 */
interface DecodedNotification {
  notificationType: StoreKitEventType;
  subtype?: string;
  data?: {
    transactionInfo?: string; // JWT
    renewalInfo?: string; // JWT
    status?: string;
  };
  notificationUUID: string;
  signedDate: number;
  appId: number;
}

/**
 * Parse JWT payload without verification (for now)
 * In production, verify the signature using Apple's JWKS
 */
function parseJWT<T>(token: string): T | null {
  try {
    const parts = token.split('.');
    if (parts.length !== 3) {
      return null;
    }

    // Decode the payload (second part)
    const payload = parts[1];

    // Add padding if needed
    const padded = payload + '='.repeat((4 - (payload.length % 4)) % 4);
    const decoded = Buffer.from(padded, 'base64').toString('utf-8');

    return JSON.parse(decoded) as T;
  } catch (error) {
    return null;
  }
}

/**
 * Calculate subscription status based on event type
 */
function getSubscriptionStatus(eventType: StoreKitEventType): string {
  switch (eventType) {
    case 'SUBSCRIBED':
    case 'DID_RENEW':
      return 'active';

    case 'EXPIRED':
      return 'expired';

    case 'GRACE_PERIOD_EXPIRES':
      return 'grace_period';

    case 'DID_FAIL_TO_RENEW':
      return 'billing_retry';

    case 'DID_CHANGE_RENEWAL_STATUS':
      return 'active';

    default:
      return 'unknown';
  }
}

export async function webhookRoutes(fastify: FastifyInstance): Promise<void> {
  // POST /webhooks/appstore - Apple StoreKit 2 notifications
  fastify.post<{ Body: StoreKitNotification }>(
    '/appstore',
    async (request, reply) => {
      const prisma = getPrismaClient();

      try {
        const { signedPayload } = request.body;

        if (!signedPayload) {
          fastify.log.warn('Webhook received without signedPayload');
          return reply.status(200).send({ received: true });
        }

        // Parse the JWT payload
        const notification = parseJWT<DecodedNotification>(signedPayload);

        if (!notification) {
          fastify.log.warn('Failed to parse webhook payload');
          return reply.status(200).send({ received: true });
        }

        const eventType = notification.notificationType as StoreKitEventType;

        // Log the event
        fastify.log.info(`StoreKit webhook: ${eventType} - ${notification.notificationUUID}`);

        // Extract transaction and renewal info
        const transactionToken = notification.data?.transactionInfo;
        const renewalToken = notification.data?.renewalInfo;

        if (!transactionToken) {
          fastify.log.warn(`Missing transaction info for event ${eventType}`);
          return reply.status(200).send({ received: true });
        }

        const transactionInfo = parseJWT<TransactionInfo>(transactionToken);
        const renewalInfo = parseJWT<RenewalInfo | null>(renewalToken || '');

        if (!transactionInfo) {
          fastify.log.warn('Failed to parse transaction info');
          return reply.status(200).send({ received: true });
        }

        // For now, we use transactionId as the storeKitTransactionId
        // In production, you'd need to map appAccountToken or other identifiers to userId
        const storeKitTransactionId = transactionInfo.transactionId;
        const expiresAtMs = renewalInfo?.renewalDate || transactionInfo.expiresDate || Date.now();
        const expiresAt = new Date(expiresAtMs);

        // Check for existing subscription with this transaction ID (idempotency)
        const existingSubscription = await prisma.subscription.findFirst({
          where: { storeKitTransactionId },
          select: { id: true, userId: true },
        });

        // Determine subscription status
        const newStatus = getSubscriptionStatus(eventType);

        if (existingSubscription) {
          // Update existing subscription
          await prisma.subscription.update({
            where: { id: existingSubscription.id },
            data: {
              status: newStatus,
              expiresAt,
              storeKitTransactionId,
              updatedAt: new Date(),
            },
          });

          fastify.log.info(`Updated subscription: ${existingSubscription.userId} -> ${newStatus}`);
        } else {
          // For new subscriptions, we'd need the userId from the appAccountToken
          // This is a limitation of the webhook - we don't have direct user context
          // In production, store the transaction info and match it when the user provides it
          fastify.log.warn(
            `New subscription event but cannot map to user. Transaction: ${storeKitTransactionId}`
          );

          // Optionally: store in a temporary table to be matched later when user authenticates
        }

        return reply.status(200).send({ received: true });
      } catch (error) {
        fastify.log.error(`Webhook processing error: ${error}`);
        // Always return 200 to acknowledge receipt to Apple
        return reply.status(200).send({ received: true });
      }
    }
  );

  // GET /webhooks/appstore/test - For Apple's URL validation
  // Apple makes a test GET request to verify the webhook endpoint
  fastify.get('/appstore/test', async (request, reply) => {
    fastify.log.info('Webhook test request received');
    return reply.status(200).send({ status: 'ok' });
  });
}
