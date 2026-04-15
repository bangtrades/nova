# Nova Backend — Learning Platform API

Production-grade Node.js/Fastify backend for the Nova learning platform, a visual AI education app for 4-year-olds.

## Features

- **User Authentication**: Apple Sign In with JWT tokens
- **Child Profiles**: Multi-child support with individual progress tracking
- **Learning Paths**: Organized content structure with sorting
- **Lessons & Cards**: Rich content delivery with 5+ card types
- **Progress Tracking**: Session management and interaction analytics
- **Badge System**: Gamification with earned achievement badges
- **Asset Pipeline**: Stub for future image/audio generation
- **OAuth Integration**: Placeholder for LLM provider connections
- **Type Safety**: Full TypeScript with Zod validation
- **Database**: PostgreSQL with Prisma ORM
- **Docker**: Production-ready multi-stage builds

## Quick Start

### Prerequisites

- Node.js 20+
- PostgreSQL 16+
- Docker (optional)

### Installation

```bash
# Install dependencies
npm install

# Set up environment
cp .env.example .env
# Edit .env with your configuration

# Create database and run migrations
npm run db:push

# Seed with sample data (optional)
npm run db:seed

# Start development server
npm run dev
```

### Development with Docker

```bash
# Start PostgreSQL and API server
npm run docker:up

# Seed database
npm run db:seed

# Stop services
npm run docker:down
```

## Project Structure

```
src/
├── config.ts           # Environment configuration with Zod
├── server.ts           # Fastify server setup
├── db/
│   ├── client.ts       # Prisma client singleton
│   ├── schema.prisma   # Database schema
│   └── seed.ts         # Database seeding
├── middleware/
│   ├── auth.ts         # JWT authentication
│   └── validate.ts     # Zod validation helpers
├── routes/
│   ├── index.ts        # Route registration
│   ├── health.ts       # Health check
│   ├── auth.ts         # Authentication endpoints
│   ├── users.ts        # User profile endpoints
│   ├── children.ts     # Child profile endpoints
│   ├── paths.ts        # Learning path endpoints
│   ├── lessons.ts      # Lesson endpoints
│   ├── cards.ts        # Card endpoints
│   ├── progress.ts     # Progress tracking endpoints
│   ├── badges.ts       # Badge endpoints
│   ├── oauth.ts        # OAuth endpoints (Sprint 4)
│   └── pipeline.ts     # Asset pipeline endpoints (Sprint 5)
└── types/
    └── index.ts        # TypeScript type definitions
```

## API Endpoints

### Health Check
- `GET /api/v1/health` — Server status (no auth required)

### Authentication
- `POST /api/v1/auth/apple` — Apple Sign In
- `POST /api/v1/auth/refresh` — Refresh JWT token
- `POST /api/v1/auth/logout` — Logout (invalidate token)
- `DELETE /api/v1/auth/account` — Delete account (COPPA)

### Users
- `GET /api/v1/users/me` — Get current user
- `PATCH /api/v1/users/me` — Update user profile

### Children
- `GET /api/v1/children` — List children
- `POST /api/v1/children` — Create child profile
- `GET /api/v1/children/:id` — Get child
- `PATCH /api/v1/children/:id` — Update child
- `DELETE /api/v1/children/:id` — Delete child

### Learning Paths
- `GET /api/v1/paths` — List paths
- `POST /api/v1/paths` — Create path
- `GET /api/v1/paths/:id` — Get path
- `PATCH /api/v1/paths/:id` — Update path
- `POST /api/v1/paths/reorder` — Reorder paths
- `DELETE /api/v1/paths/:id` — Delete path

### Lessons
- `GET /api/v1/lessons` — List lessons (paginated, filterable)
- `POST /api/v1/lessons` — Create lesson
- `GET /api/v1/lessons/:id` — Get lesson with cards
- `PATCH /api/v1/lessons/:id` — Update lesson
- `POST /api/v1/lessons/:id/publish` — Publish lesson
- `DELETE /api/v1/lessons/:id` — Delete lesson

### Cards
- `GET /api/v1/cards?lessonId=xxx` — Get cards for lesson
- `POST /api/v1/cards` — Create card
- `PATCH /api/v1/cards/:id` — Update card
- `POST /api/v1/cards/reorder` — Batch reorder cards
- `DELETE /api/v1/cards/:id` — Delete card

### Progress
- `POST /api/v1/progress/sync` — Sync learning session data
- `GET /api/v1/progress/:childId` — Get progress summary
- `GET /api/v1/progress/:childId/sessions` — Get session history (paginated)

### Badges
- `GET /api/v1/badges` — List all badges
- `GET /api/v1/badges/earned/:childId` — Get earned badges
- `POST /api/v1/badges/check/:childId` — Check and award badges

### OAuth (Sprint 4)
- `POST /api/v1/oauth/connect` — Initiate OAuth flow
- `GET /api/v1/oauth/callback` — OAuth callback handler
- `GET /api/v1/oauth/providers` — List connected providers
- `DELETE /api/v1/oauth/providers/:id` — Disconnect provider

### Pipeline (Sprint 5)
- `POST /api/v1/pipeline/ingest` — Ingest URL for content
- `GET /api/v1/pipeline/ingest/:id` — Get ingest status
- `POST /api/v1/pipeline/generate` — Generate cards from ingest
- `POST /api/v1/pipeline/assets/:lessonId` — Trigger asset generation

## Scripts

```bash
# Development
npm run dev              # Start dev server with hot reload
npm run build            # Build TypeScript
npm run start            # Run production build

# Database
npm run db:migrate       # Run pending migrations
npm run db:push          # Sync schema to database
npm run db:seed          # Seed database with test data
npm run db:studio        # Open Prisma Studio

# Testing
npm run test             # Run tests once
npm run test:watch       # Run tests in watch mode

# Linting
npm run lint             # Check code style
npm run lint:fix         # Fix code style issues

# Docker
npm run docker:up        # Start Docker containers
npm run docker:down      # Stop Docker containers
```

## Environment Variables

See `.env.example` for all available options:

- `DATABASE_URL` — PostgreSQL connection string
- `JWT_SECRET` — Secret key for JWT tokens (min 32 chars)
- `JWT_REFRESH_SECRET` — Secret for refresh tokens (min 32 chars)
- `PORT` — Server port (default: 3000)
- `HOST` — Bind address (default: 0.0.0.0)
- `NODE_ENV` — Environment (development/production/test)
- `LOG_LEVEL` — Logging level (debug/info/warn/error)
- `R2_*` — Cloudflare R2 credentials for asset storage
- `OPENAI_*` — OpenAI API and OAuth credentials

## Database Schema

14 tables with full type safety via Prisma:

- `users` — User accounts (Apple ID based)
- `child_profiles` — Children associated with users
- `subscriptions` — Subscription plans and status
- `llm_providers` — Connected LLM providers
- `learning_paths` — Content organization
- `lessons` — Individual lessons
- `cards` — Card content (story, concept, interactive, quiz)
- `learning_sessions` — User learning sessions
- `card_interactions` — Session interaction data
- `badges` — Available badges
- `earned_badges` — User earned badges
- `url_ingests` — URL scraping jobs
- `asset_jobs` — Image/audio generation jobs

## Testing

```bash
# Run all tests
npm run test

# Watch mode
npm run test:watch

# Tests include:
# - Health endpoint connectivity
# - Authentication middleware
# - Route authorization checks
# - API response validation
```

## Production Deployment

1. Build Docker image: `docker build -t nova-api:0.1.0 .`
2. Push to registry (ECR, Docker Hub, etc.)
3. Deploy with environment variables for:
   - Production PostgreSQL URL
   - Secure JWT secrets
   - R2 credentials
   - OpenAI credentials
4. Run migrations before startup
5. Configure CORS for iOS app domain

## Security Checklist

- [x] JWT authentication on all protected routes
- [x] Input validation with Zod schemas
- [x] SQL injection protection (Prisma)
- [x] Rate limiting on all endpoints
- [x] CORS configured
- [x] Helmet security headers
- [x] Non-root Docker user
- [x] Proper error handling (no leaking internals)
- [ ] HTTPS/TLS (configure in production)
- [ ] API key rotation strategy
- [ ] Audit logging for sensitive operations
- [ ] WAF/DDoS protection (CloudFlare, AWS)

## Performance Optimization

- Prisma query optimization with select statements
- Pagination on list endpoints (max 100 items)
- Database indexes on frequently queried fields
- Connection pooling (Prisma)
- Rate limiting (9 req/min per IP)
- Caching strategy ready (Redis placeholder)

## Troubleshooting

**Database connection failed:**
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check DATABASE_URL in .env
# Format: postgresql://user:password@host:port/database
```

**Migration issues:**
```bash
# Reset database (careful!)
npm run db:push -- --force-reset

# View migration status
npx prisma migrate status
```

**Port already in use:**
```bash
# Change PORT in .env or kill process on port 3000
lsof -ti:3000 | xargs kill -9
```

## Roadmap

- **Sprint 1** (Current): Core API, authentication, content management
- **Sprint 2**: Real-time progress sync, WebSocket support
- **Sprint 3**: Asset management (Cloudflare R2)
- **Sprint 4**: OAuth for LLM providers
- **Sprint 5**: Content generation pipeline (AI)

## License

Proprietary — Nova Learning Platform

## Support

For issues and questions, contact the development team.
