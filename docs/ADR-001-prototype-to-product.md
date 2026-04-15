# ADR-001: Nova — Prototype to App Store Product

**Status:** Proposed
**Date:** April 14, 2026
**Deciders:** bang (founder/developer)

---

## Context

Nova is a dual iOS app teaching kids (4-8) about AI through interactive flipbook lessons. The prototype is feature-complete and compiling clean after a full security/accessibility audit (28 issues resolved). The codebase is ~32k LOC across 135 Swift files and 64 TypeScript backend files.

**What works now:** SwiftUI frontend for both apps, onboarding flow, flipbook card system (Story, Quiz, Experiment, Voice, Concept), Sparky character, trophy room, offline sync architecture, COPPA-compliant encrypted storage, Dark Mode support, full accessibility.

**What's missing for a shippable product:**
1. Real LLM connection (Sparky is a dead shell — no actual AI behind it)
2. Content generation pipeline (URL→lesson conversion isn't wired to a real LLM)
3. Image/audio asset generation (DALL-E 3 + TTS endpoints exist but aren't live)
4. Backend deployment (Fastify server + Postgres exist but aren't hosted)
5. StoreKit 2 subscription flow (code exists, not tested with sandbox)
6. App Store Review compliance (privacy nutrition labels, COPPA declaration, review guidelines)
7. TestFlight beta distribution

This ADR defines the architecture for going from prototype to v1.0 App Store submission.

---

## Decision

Ship in 3 phases over ~6 weeks. Each phase produces a testable milestone. No big-bang launch.

---

## Phase 1: Backend Live + LLM Connection (Week 1-2)

**Goal:** Real data flowing through the app. Sparky talks. Lessons load from server.

### 1.1 Deploy Backend

| Dimension | Decision |
|-----------|----------|
| Hosting | Railway or Render for Fastify server (simple Node deployment, $5-20/mo) |
| Database | Supabase Postgres (already connected via MCP — use existing project) |
| Asset Storage | Cloudflare R2 (already in architecture — $0 egress) |
| Domain | api.nova.app or nova-api.railway.app initially |

**Why not Vercel/serverless:** The pipeline service does long-running LLM calls (30-60s for lesson generation). Serverless timeouts at 10-30s won't work. Railway/Render give persistent containers.

**Action items:**
- [ ] Migrate Prisma schema to Supabase Postgres (or keep Prisma + Supabase as raw Postgres)
- [ ] Deploy Fastify to Railway with environment variables
- [ ] Configure R2 bucket + API keys
- [ ] Point iOS app's `baseURL` from `https://api.nova.local` to real endpoint
- [ ] Seed database with 24 pre-built lessons + 3 learning paths

### 1.2 Wire LLM Provider Layer

The backend already has `services/llm/` and `services/sparky/`. Wire them to real endpoints.

| Component | Provider | Model | Cost Estimate |
|-----------|----------|-------|---------------|
| Sparky voice chat | OpenAI Realtime API | gpt-4o-realtime | ~$0.06/min audio |
| Lesson generation | Claude API (Anthropic) | claude-sonnet-4 | ~$0.003/lesson |
| Card content writing | Claude API | claude-sonnet-4 | ~$0.001/card |
| Image generation | OpenAI DALL-E 3 | dall-e-3 | $0.04/image (1024x1024) |
| Text-to-speech | OpenAI TTS | tts-1 | $0.015/1K chars |

**Architecture decision — proxy model for COPPA:**
All LLM calls go through the Nova backend, never directly from the child's device. This gives us:
- Content filtering before delivery to child
- No API keys on-device
- Usage metering for subscription tiers
- Audit log for COPPA compliance
- Ability to swap providers without app update

```
iPad → Nova API → Content Filter → LLM Provider → Filter Response → iPad
```

**BYOK users:** Their OpenAI key is stored encrypted in our backend (via EncryptedStorage pattern), and we proxy through our content filter. The key never touches the device beyond the initial OAuth flow.

**Action items:**
- [ ] Add Anthropic SDK to backend for lesson generation (Claude has no OAuth but API key works server-side)
- [ ] Wire OpenAI Realtime API for Sparky voice conversations
- [ ] Implement content safety filter (block inappropriate topics, enforce age-appropriate language)
- [ ] Add rate limiting per subscription tier (Free: 5 Sparky chats/day, Pro: unlimited)
- [ ] Test round-trip: iPad → API → LLM → response on screen

### 1.3 Curriculum Generator

The `services/pipeline/` already has the URL→lesson scaffold. Make it real:

```
Parent pastes URL in Companion app
  → Backend scrapes URL content
  → Claude analyzes: extract key concepts, age-appropriate framing
  → Claude generates 6-8 cards per lesson (Story, Quiz, Experiment, Concept mix)
  → DALL-E 3 generates hero image + card illustrations
  → TTS generates audio narration for each card
  → Assets uploaded to R2
  → Lesson saved to Postgres
  → Pushed to kid's iPad via sync
```

**Key constraint:** Generation takes 30-90 seconds. Use a job queue (BullMQ + Redis, or simple database polling) so the Companion app shows progress and the parent can close the app.

**Action items:**
- [ ] Implement URL scraping service (Cheerio or Playwright for JS-heavy sites)
- [ ] Build Claude prompt chain: URL content → concept extraction → card generation
- [ ] Wire DALL-E 3 for illustration generation with kid-friendly style prompt
- [ ] Wire TTS for card narration
- [ ] Add job queue for async lesson generation
- [ ] Add WebSocket or polling endpoint for generation progress

---

## Phase 2: Polish + Subscription (Week 3-4)

**Goal:** Monetization works. App feels finished, not prototype-y.

### 2.1 StoreKit 2 Integration

The code for `SubscriptionView` and `entitlements` routes already exists. Wire to real StoreKit.

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | 3 starter paths (24 lessons), manual card creation, basic progress |
| Pro | $6.99/mo | AI pipeline, Sparky voice chat, all paths, advanced progress |
| BYOK | $2.99/mo | Connect own OpenAI account, all Pro features |

**Action items:**
- [ ] Configure products in App Store Connect
- [ ] Test StoreKit 2 sandbox purchasing flow
- [ ] Implement server-side receipt validation (App Store Server API v2)
- [ ] Wire entitlement checks: gate Sparky chat + pipeline behind Pro/BYOK
- [ ] Add subscription management in Companion app Settings
- [ ] Handle grace periods, billing retry, and involuntary churn

### 2.2 App Design Polish

The current UI is functional but needs polish for a paid product.

**Priority fixes:**
- [ ] Launch screen / splash animation (Sparky waving)
- [ ] App icon (vibrant, recognizable at small sizes)
- [ ] Empty states throughout (no lessons yet, no badges earned, etc.)
- [ ] Loading states and skeleton screens for network-dependent content
- [ ] Haptic feedback refinement (currently using UIKit — migrate to `.sensoryFeedback()`)
- [ ] Sound effects for quiz correct/incorrect, badge earned, level up
- [ ] Confetti/celebration animations that actually trigger on real achievements
- [ ] Pull-to-refresh polish on Home and Lessons tabs

### 2.3 Offline-First Hardening

The sync architecture exists but needs real-world testing:

- [ ] Test: airplane mode → complete lesson → restore connectivity → verify sync
- [ ] Test: poor connectivity → partial sync → retry → data integrity
- [ ] Pre-cache next 2-3 lessons' assets when on WiFi
- [ ] Show clear offline indicator with "last synced X ago" timestamp
- [ ] Queue Sparky conversations for later if offline (or show friendly "Sparky needs WiFi" message)

---

## Phase 3: App Store Submission (Week 5-6)

**Goal:** Pass App Store Review on first submission.

### 3.1 App Store Review Compliance

Apple rejects ~40% of kids' app submissions on the first try. The most common rejection reasons for kids' apps:

| Rejection Risk | How We Address It |
|----------------|-------------------|
| **Guideline 1.3 — Kids Category requires no third-party analytics** | Strip any analytics SDKs. Use only Apple's App Analytics. |
| **Guideline 5.1.1(iii) — Data Collection from Kids** | COPPA consent gate (done), encrypted storage (done), no tracking without consent (done) |
| **Guideline 3.1.2 — Subscriptions must clearly explain what users get** | Detailed subscription description on paywall, free tier is genuinely usable |
| **Guideline 5.1.1(ix) — Sign in with Apple required if other social logins** | We only use Sign in with Apple (done) |
| **Guideline 2.3.1 — Don't use public APIs in unauthorized ways** | Clean audit (done), no private API usage |
| **Guideline 5.1.2 — Privacy Nutrition Labels** | Must be accurate — declare speech recognition, microphone, child data |
| **Guideline 1.4.1 — Parental Gate** | Implemented with 5 choices + lockout (done) |
| **Guideline 5.1.7 — Kids Category Age Band** | Declare "Ages 5-8" band, ensure all content is age-appropriate |

**Action items:**
- [ ] Fill out App Store Connect metadata (description, screenshots, keywords)
- [ ] Create Privacy Nutrition Labels (App Privacy section)
- [ ] COPPA declaration in Kids Category settings
- [ ] Prepare 5 iPad screenshots + 3 iPhone screenshots (Companion)
- [ ] Write App Store description focusing on parent value proposition
- [ ] Create App Preview video (30 seconds, showing lesson flow)
- [ ] Submit to Apple Review with detailed review notes explaining the parental gate, LLM usage, and content filtering

### 3.2 TestFlight Beta

Before App Store submission, run a 2-week TestFlight beta:

- [ ] Internal testing: you + family (immediate feedback loop)
- [ ] External testing: 5-10 families with kids 4-8 (need parental consent for each)
- [ ] Focus areas: onboarding completion rate, lesson engagement time, crash-free rate
- [ ] Monitor: Xcode Organizer crashes, console errors, sync failures

### 3.3 Infrastructure for Launch

| Component | Launch Config | Scale Trigger |
|-----------|---------------|---------------|
| Fastify server | 1 container, 512MB RAM | >100 concurrent users → horizontal scale |
| Postgres | Supabase Free/Pro ($25/mo) | >10GB storage → upgrade |
| Redis (job queue) | Upstash serverless ($0-10/mo) | >1000 jobs/day → dedicated |
| R2 storage | Free tier (10GB) | >50GB → $0.015/GB/mo |
| LLM costs | ~$50-100/mo for first 100 users | Scales linearly with usage |
| **Total estimated infra** | **$30-80/mo at launch** | |

---

## Architecture Diagram — Phase 2 Target

```
┌─────────────────────────────────────────────────────────┐
│                    NOVA PLATFORM                         │
├──────────────────┬──────────────────────────────────────┤
│                  │                                      │
│  ┌────────────┐  │  ┌────────────────────────────────┐  │
│  │ Nova Kids  │  │  │        Nova Backend             │  │
│  │  (iPad)    │──┼──│  Fastify + Postgres + R2       │  │
│  │            │  │  │                                │  │
│  │ • Flipbook │  │  │  Routes:                       │  │
│  │ • Sparky   │  │  │  ├─ /auth (Apple Sign In)     │  │
│  │ • Trophies │  │  │  ├─ /lessons (CRUD + sync)    │  │
│  │ • Voice    │  │  │  ├─ /sparky (voice chat proxy) │  │
│  └────────────┘  │  │  ├─ /pipeline (URL→lesson)    │  │
│                  │  │  ├─ /progress (tracking)       │  │
│  ┌────────────┐  │  │  └─ /entitlements (StoreKit)  │  │
│  │ Companion  │  │  │                                │  │
│  │ (iPhone)   │──┼──│  Services:                     │  │
│  │            │  │  │  ├─ LLM Router ──→ Claude API  │  │
│  │ • Pipeline │  │  │  ├─ Sparky ────→ OpenAI RT API│  │
│  │ • Editor   │  │  │  ├─ Images ────→ DALL-E 3     │  │
│  │ • Progress │  │  │  ├─ TTS ───────→ OpenAI TTS   │  │
│  │ • Settings │  │  │  ├─ Filter (content safety)   │  │
│  └────────────┘  │  │  └─ Jobs (BullMQ/Redis)       │  │
│                  │  └────────────────────────────────┘  │
│                  │                                      │
│  ┌────────────┐  │  ┌────────────────────────────────┐  │
│  │ StoreKit 2 │──┼──│  App Store Server API v2       │  │
│  └────────────┘  │  └────────────────────────────────┘  │
└──────────────────┴──────────────────────────────────────┘
```

---

## Key Trade-offs

### Claude vs GPT-4 for Lesson Generation
**Decision:** Claude for content generation, OpenAI for voice/images.
**Reasoning:** Claude produces better structured educational content and follows complex prompt chains more reliably. OpenAI has the Realtime API for voice (no Claude equivalent) and DALL-E for images. This dual-provider approach means no single vendor lock-in.

### Proxy All LLM Calls vs Direct Device-to-LLM
**Decision:** All calls proxied through Nova backend.
**Reasoning:** COPPA requires content filtering for kids. Proxying lets us filter before delivery, meter usage, swap providers, and keep API keys off devices. The ~100ms latency overhead is acceptable for educational content.

### Native Swift vs React Native / Flutter
**Decision:** Stay native Swift (already built).
**Reasoning:** The prototype is 32k LOC of native SwiftUI. Rewriting would cost months. Native gives us the best accessibility, performance, and App Store Review experience for a kids' app. If Android is needed later, consider KMP (Kotlin Multiplatform) for shared business logic.

### Subscription vs One-Time Purchase
**Decision:** Freemium + subscription.
**Reasoning:** LLM costs are per-use, so a one-time purchase doesn't work economically. The free tier must be genuinely useful (3 full learning paths, 24 lessons) so parents can evaluate before committing. $6.99/mo is competitive with ABCmouse ($12.99) and Homer ($9.99).

---

## Consequences

**What becomes easier:**
- Adding new lesson types (backend generates, frontend renders)
- A/B testing content quality (swap Claude prompts without app update)
- Scaling to new topics (parent pastes any URL, AI does the rest)
- Supporting multiple languages (LLM translates, TTS generates)

**What becomes harder:**
- LLM cost management (must monitor per-user spend closely)
- Content safety at scale (need ongoing prompt engineering + human review queue)
- Offline experience degrades without pre-cached content
- Two LLM providers to maintain (Anthropic + OpenAI)

**What we'll need to revisit:**
- Android version decision (after App Store traction data — 3-6 months post-launch)
- Content moderation at scale (manual review queue if >1000 families)
- Multi-language support (high value but doubles content QA effort)
- Age band expansion (9-12 requires different content complexity)

---

## Immediate Next Steps (This Week)

1. **Deploy backend to Railway** — get a real API endpoint running
2. **Seed Supabase with the 24 pre-built lessons** — app has real content immediately
3. **Wire Sparky to OpenAI Realtime API** — the single biggest "wow" moment for kids
4. **Test full flow:** age gate → onboarding → login → home → open lesson → complete quiz → earn badge

That's your fastest path to a demo you can show people and get feedback on before investing in the full pipeline.
