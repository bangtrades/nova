import type { FastifyRequest } from 'fastify';

export interface TokenPayload {
  userId: string;
  iat: number;
  exp: number;
}

export interface JWTPair {
  accessToken: string;
  refreshToken: string;
}

declare global {
  namespace Express {
    interface Request {
      userId?: string;
      user?: {
        id: string;
      };
    }
  }
}

declare module 'fastify' {
  interface FastifyRequest {
    userId?: string;
    user?: {
      id: string;
    };
  }
}

export interface PaginationQuery {
  skip?: number;
  take?: number;
  page?: number;
  limit?: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}
