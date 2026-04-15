import { z } from 'zod';
import * as dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
  // Server
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.string().pipe(z.coerce.number()).default('3000'),
  HOST: z.string().default('0.0.0.0'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),

  // Database
  DATABASE_URL: z.string(),

  // JWT
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 characters'),
  JWT_REFRESH_SECRET: z.string().min(32, 'JWT_REFRESH_SECRET must be at least 32 characters'),

  // Cloudflare R2
  R2_ACCOUNT_ID: z.string().optional(),
  R2_ACCESS_KEY_ID: z.string().optional(),
  R2_SECRET_ACCESS_KEY: z.string().optional(),
  R2_BUCKET_NAME: z.string().default('nova-assets'),
  R2_PUBLIC_URL: z.string().url().optional(),

  // OpenAI
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_OAUTH_CLIENT_ID: z.string().optional(),
  OPENAI_OAUTH_CLIENT_SECRET: z.string().optional(),
  OPENAI_OAUTH_REDIRECT_URI: z.string().url().optional(),

  // Encryption
  ENCRYPTION_KEY: z
    .string()
    .length(64, 'ENCRYPTION_KEY must be a 64-character hex string (32 bytes)')
    .default('0000000000000000000000000000000000000000000000000000000000000000'), // Dev default (zeros)
});

type Config = z.infer<typeof envSchema>;

let config: Config | null = null;

export function getConfig(): Config {
  if (!config) {
    const result = envSchema.safeParse(process.env);

    if (!result.success) {
      const missingVars = result.error.issues
        .map((issue) => issue.path.join('.'))
        .join(', ');
      throw new Error(`Invalid environment variables: ${missingVars}`);
    }

    config = result.data;
  }

  return config;
}

export const configuration = getConfig();
