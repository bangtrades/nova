import { PrismaClient } from '@prisma/client';
import { getConfig } from '@config';

// Fields that store JSON as text (SQLite doesn't support native Json type)
const JSON_STRING_FIELDS: Record<string, string[]> = {
  lesson: ['aiAnalysis'],
  card: ['content', 'interactionConfig'],
  cardInteraction: ['result'],
  badge: ['criteria'],
  urlIngest: ['aiAnalysis'],
  assetJob: ['input'],
  sparkyConversation: ['followUpQuestions'],
  llmUsageLog: ['metadata'],
  concept: ['prerequisites'], // S10-01: knowledge graph — array of concept IDs
};

let prismaClient: PrismaClient | null = null;

export function getPrismaClient(): PrismaClient {
  if (!prismaClient) {
    const config = getConfig();
    prismaClient = new PrismaClient({
      log:
        config.NODE_ENV === 'development'
          ? ['info', 'warn', 'error']
          : ['error'],
    });

    // Middleware: auto-stringify JSON fields on write, auto-parse on read
    prismaClient.$use(async (params, next) => {
      const model = params.model?.charAt(0).toLowerCase() + (params.model?.slice(1) ?? '');
      const jsonFields = JSON_STRING_FIELDS[model] ?? [];

      // Helper: stringify JSON fields in a data object for a given model
      const stringifyFields = (data: any, modelName: string) => {
        if (!data || typeof data !== 'object') return;
        const fields = JSON_STRING_FIELDS[modelName] ?? [];
        for (const field of fields) {
          const val = data[field];
          if (val !== undefined && val !== null && typeof val === 'object') {
            data[field] = JSON.stringify(val);
          }
        }
      };

      // Stringify top-level model fields on the primary `data` payload.
      //   - create / update / updateMany → args.data (single object)
      //   - createMany                   → args.data (ARRAY of objects)
      if (jsonFields.length > 0 && params.args?.data) {
        if (Array.isArray(params.args.data)) {
          (params.args.data as any[]).forEach((row) => stringifyFields(row, model));
        } else {
          stringifyFields(params.args.data, model);
        }
      }

      // Upsert uses `create` + `update` siblings on args instead of `data`.
      // Without this, upserts skip the middleware entirely.
      if (jsonFields.length > 0 && params.action === 'upsert') {
        if (params.args?.create) stringifyFields(params.args.create, model);
        if (params.args?.update) stringifyFields(params.args.update, model);
      }

      // Stringify nested relation creates (e.g. lesson.create({ cards: { create: [...] } }))
      const nestedRoots: any[] = [];
      if (params.args?.data) nestedRoots.push(params.args.data);
      if (params.action === 'upsert') {
        if (params.args?.create) nestedRoots.push(params.args.create);
        if (params.args?.update) nestedRoots.push(params.args.update);
      }
      for (const root of nestedRoots) {
        if (!root || typeof root !== 'object') continue;
        for (const [key, value] of Object.entries(root)) {
          if (value && typeof value === 'object' && 'create' in (value as any)) {
            const nestedModel = key.replace(/s$/, ''); // "cards" -> "card"
            const nestedFields = JSON_STRING_FIELDS[nestedModel] ?? [];
            if (nestedFields.length > 0) {
              const creates = (value as any).create;
              if (Array.isArray(creates)) {
                creates.forEach((item: any) => stringifyFields(item, nestedModel));
              } else if (typeof creates === 'object') {
                stringifyFields(creates, nestedModel);
              }
            }
          }
        }
      }

      const result = await next(params);

      // Parse JSON strings after read
      if (result && jsonFields.length > 0) {
        const parseFields = (obj: any) => {
          if (!obj || typeof obj !== 'object') return obj;
          for (const field of jsonFields) {
            if (typeof obj[field] === 'string') {
              try { obj[field] = JSON.parse(obj[field]); } catch {}
            }
          }
          return obj;
        };

        if (Array.isArray(result)) {
          result.forEach(parseFields);
        } else if (typeof result === 'object') {
          parseFields(result);
        }
      }

      return result;
    });
  }

  return prismaClient;
}

export async function disconnectPrisma(): Promise<void> {
  if (prismaClient) {
    await prismaClient.$disconnect();
    prismaClient = null;
  }
}

// Graceful shutdown
process.on('SIGINT', async () => {
  await disconnectPrisma();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await disconnectPrisma();
  process.exit(0);
});
