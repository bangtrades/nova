import type { FastifyRequest, FastifyReply } from 'fastify';
import { z } from 'zod';

interface ValidationError {
  field: string;
  message: string;
}

function formatZodErrors(error: z.ZodError): ValidationError[] {
  return error.issues.map((issue) => ({
    field: issue.path.join('.'),
    message: issue.message,
  }));
}

export function validateBody<T>(schema: z.ZodSchema<T>) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    try {
      request.body = schema.parse(request.body);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return reply.status(400).send({
          statusCode: 400,
          error: 'Validation Error',
          message: 'Request body validation failed',
          errors: formatZodErrors(error),
        });
      }
      throw error;
    }
  };
}

export function validateQuery<T>(schema: z.ZodType<T, z.ZodTypeDef, unknown>) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    try {
      request.query = schema.parse(request.query) as typeof request.query;
    } catch (error) {
      if (error instanceof z.ZodError) {
        return reply.status(400).send({
          statusCode: 400,
          error: 'Validation Error',
          message: 'Query parameters validation failed',
          errors: formatZodErrors(error),
        });
      }
      throw error;
    }
  };
}

export function validateParams<T>(schema: z.ZodSchema<T>) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    try {
      request.params = schema.parse(request.params);
    } catch (error) {
      if (error instanceof z.ZodError) {
        return reply.status(400).send({
          statusCode: 400,
          error: 'Validation Error',
          message: 'Route parameters validation failed',
          errors: formatZodErrors(error),
        });
      }
      throw error;
    }
  };
}
