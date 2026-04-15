/**
 * Privacy & Legal Routes (NOVA-303)
 *
 * GET /api/v1/legal/privacy-policy - Privacy policy
 * GET /api/v1/legal/terms-of-service - Terms of service
 * No authentication required (public endpoints)
 */

import type { FastifyInstance } from 'fastify';

interface LegalSection {
  heading: string;
  content: string;
}

interface LegalDocument {
  title: string;
  lastUpdated: string;
  sections: LegalSection[];
}

const PRIVACY_POLICY: LegalDocument = {
  title: 'Nova Privacy Policy',
  lastUpdated: '2026-04-13',
  sections: [
    {
      heading: 'Data Collection',
      content:
        'Nova collects information to provide and improve our educational services. We collect: learning progress data, lesson completion records, voice recordings (only with explicit consent), device identifiers, and IP addresses for security purposes.',
    },
    {
      heading: 'Data Usage',
      content:
        'We use collected data to: personalize learning experiences, generate progress reports for parents, improve our AI models and lesson content, and ensure compliance with laws protecting children.',
    },
    {
      heading: "Children's Privacy (COPPA)",
      content:
        'Nova is designed for children ages 4-8. We comply with the Children\'s Online Privacy Protection Act (COPPA). Parents provide consent for data collection. We do not sell or share children\'s personal information with third parties for marketing purposes.',
    },
    {
      heading: 'Data Storage & Security',
      content:
        'All data is encrypted in transit (TLS) and at rest. We store data on secure servers with regular backups. Access is restricted to authorized staff. We conduct regular security audits and maintain SOC 2 compliance.',
    },
    {
      heading: 'Third-Party Services',
      content:
        'Nova uses third-party services for: cloud storage (Cloudflare R2), AI models (OpenAI), and analytics. These partners have their own privacy policies. We ensure data processing agreements are in place for child data protection.',
    },
    {
      heading: 'Data Rights',
      content:
        'Parents can request to view, modify, or delete their child\'s data at any time. We provide data export functionality for portability. Data deletion requests are processed within 30 days.',
    },
    {
      heading: 'Contact',
      content:
        'For privacy questions or concerns, contact privacy@nova-app.com. We respond to inquiries within 14 days.',
    },
  ],
};

const TERMS_OF_SERVICE: LegalDocument = {
  title: 'Nova Terms of Service',
  lastUpdated: '2026-04-13',
  sections: [
    {
      heading: 'Acceptance of Terms',
      content:
        'By using Nova, you agree to these Terms of Service. If you do not agree, do not use the app. We may update these terms at any time. Continued use constitutes acceptance of updates.',
    },
    {
      heading: 'Description of Service',
      content:
        'Nova is an AI-powered learning platform for children ages 4-8. We provide interactive lessons, progress tracking, voice chat with AI tutors, and parental controls. Service availability and features may change.',
    },
    {
      heading: 'User Accounts',
      content:
        'Parents create accounts and are responsible for all activity. You must keep passwords confidential. You agree not to share accounts with unauthorized users. Nova reserves the right to terminate accounts that violate these terms.',
    },
    {
      heading: 'Subscription & Payment',
      content:
        'Nova offers free and premium tiers. Paid subscriptions auto-renew monthly. Cancellation is available anytime via settings. Refunds are provided within 30 days of purchase per App Store policies.',
    },
    {
      heading: 'Content & Intellectual Property',
      content:
        'All Nova content (lessons, images, voice scripts) is protected by copyright. You may not reproduce, modify, or distribute content without permission. User-generated content remains your property.',
    },
    {
      heading: 'Prohibited Use',
      content:
        'You agree not to: use offensive language, share inappropriate content, attempt to hack or disrupt the service, collect data without permission, or violate laws.',
    },
    {
      heading: 'Termination',
      content:
        'We may terminate accounts that violate these terms. Upon termination, your data is retained per privacy policy. Deletion requests are processed within 30 days.',
    },
    {
      heading: 'Limitation of Liability',
      content:
        'Nova is provided "as is" without warranties. We are not liable for data loss, service interruptions, or indirect damages. Our liability is limited to fees paid in the past 12 months.',
    },
    {
      heading: 'Contact',
      content:
        'For legal questions, contact legal@nova-app.com. We respond to inquiries within 14 days.',
    },
  ],
};

export default async function privacyRoutes(fastify: FastifyInstance): Promise<void> {
  // GET /legal/privacy-policy - Return privacy policy as JSON
  fastify.get('/legal/privacy-policy', async (request, reply) => {
    try {
      return reply.status(200).send(PRIVACY_POLICY);
    } catch (error) {
      fastify.log.error(`Privacy policy error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch privacy policy',
      });
    }
  });

  // GET /legal/terms-of-service - Return terms of service as JSON
  fastify.get('/legal/terms-of-service', async (request, reply) => {
    try {
      return reply.status(200).send(TERMS_OF_SERVICE);
    } catch (error) {
      fastify.log.error(`Terms of service error: ${error}`);
      return reply.status(500).send({
        statusCode: 500,
        error: 'Internal Server Error',
        message: 'Failed to fetch terms of service',
      });
    }
  });
}
