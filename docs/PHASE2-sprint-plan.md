# Nova Phase 2 — Sprint Plan: Prototype to App Store

**Date:** April 15, 2026
**Informed by:** ADR-001, AI-Native Platform Vision, Sprint 1-7 history, codebase audit
**Methodology:** Scrum (2-week sprints), story points (Fibonacci), solo developer velocity

---

## Velocity Baseline

Phase 1 sprints averaged 97 pts/sprint across 7 sprints (range: 52-142, trend: accelerating). For Phase 2, the work shifts from greenfield feature building to integration, testing, and polish — historically slower. Conservative baseline: **80 pts/sprint**.

**Planning capacity:** 6 sprints × 80 pts = **480 story points** across 12 weeks.

---

## Epic Structure

| Epic | Code | Sprint(s) | Points | Description |
|------|------|-----------|--------|-------------|
| Backend Deployment | DEPLOY | S8 | 55 | Live API, database migration, R2 config, CI/CD |
| LLM Integration | LLM | S8-S9 | 89 | Sparky voice, content generation, safety filters |
| Grand Architect Pipeline | PIPE | S9-S10 | 105 | URL→lesson pipeline with 6-stage intelligence |
| Child Memory System | MEM | S10-S11 | 80 | Knowledge graph, engagement profiles, context engine |
| Content Skills Engine | SKILL | S10-S11 | 68 | Story-writer, quiz-maker, experiment-designer skills |
| Subscriptions & Monetization | PAY | S11 | 42 | StoreKit 2 sandbox, entitlement gating, receipt validation |
| App Store Submission | SHIP | S12-S13 | 55 | TestFlight, privacy labels, screenshots, review prep |

**Total: 494 points across 6 sprints + 1 buffer sprint**

---

## Sprint 8: Infrastructure & First LLM Connection (Week 1-2)

**Goal:** Live backend. Sparky says its first real words. App connects to real data.

**Theme:** "Lights On"

### DEPLOY Epic (55 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S8-01 | Deploy Fastify server to Railway with env config | 8 | Server responds to /health, env vars for DB/R2/LLM keys configured, auto-deploy on push to main |
| S8-02 | Migrate Prisma schema to Supabase Postgres | 8 | All 14 tables created, indexes applied, seed script runs clean, Prisma client connects from Railway |
| S8-03 | Configure Cloudflare R2 bucket + signed URLs | 5 | Upload endpoint works, signed read URLs return assets, path traversal prevention verified |
| S8-04 | Seed database with 24 pre-built lessons (144 cards) | 5 | All 3 learning paths populated, card content + metadata matches Sprint 7 demo data |
| S8-05 | Point iOS app baseURL to live endpoint | 3 | App loads lessons from real API, sync endpoint returns 200, dev bypass still works |
| S8-06 | Add health monitoring + error alerting | 5 | /health returns DB status + memory + uptime, Railway alerts on crash/restart |
| S8-07 | Configure HTTPS + domain (api subdomain) | 3 | SSL cert active, custom domain resolves, HSTS headers set |
| S8-08 | Set up CI: lint + test on PR, deploy on merge to main | 8 | GitHub Actions workflow runs 133 backend tests, blocks merge on failure, auto-deploys on pass |

### LLM Epic — Phase A (34 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S8-09 | Wire Sparky to OpenAI Realtime API | 13 | Kid sends voice → backend proxies to Realtime API → response plays on iPad. Round-trip < 3s. Kid-safe system prompt enforced. |
| S8-10 | Implement content safety filter service | 8 | Filter runs on every LLM response before delivery. Blocks violence, sexual content, hate speech, misinformation. Logs blocked content for review. |
| S8-11 | Add rate limiting per subscription tier | 5 | Free: 5 Sparky chats/day. Pro: 100/day. BYOK: unlimited. 429 response with retry-after header. Usage counter resets daily. |
| S8-12 | Wire Claude API for text content generation | 8 | Backend calls Claude Sonnet for lesson content. Prompt template returns structured JSON matching Card schema. Error handling for rate limits + timeouts. |

**Sprint 8 Total: 89 pts** (stretch — first sprint sets the pace)

**Sprint 8 Definition of Done:**
- [ ] App loads real lessons from live API on iPad Simulator
- [ ] "Hey Sparky" voice conversation works end-to-end
- [ ] Content safety filter blocks test-case bad inputs
- [ ] 133 backend tests still passing on Railway

---

## Sprint 9: Grand Architect Pipeline — Stages 1-4 (Week 3-4)

**Goal:** Parent pastes a URL, AI generates a real lesson. The magic moment.

**Theme:** "The Pipeline"

### LLM Epic — Phase B (21 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S9-01 | Wire DALL-E 3 for lesson image generation | 8 | Each lesson gets hero image + 2-3 card illustrations. Style prompt enforces kid-friendly aesthetic. Images uploaded to R2. Cost: ~$0.12/lesson. |
| S9-02 | Wire OpenAI TTS for card narration | 5 | Each card gets audio narration. 6 voice options available. Audio cached in R2. Cost: ~$0.02/lesson. |
| S9-03 | Implement LLM cost tracking per user | 8 | Every LLM call logged with model, tokens, cost. Per-child and per-parent aggregation. Monthly cost dashboard in admin/monitoring endpoint. |

### PIPE Epic — Grand Architect Stages 1-4 (68 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S9-04 | Stage 1: URL intake, scraping, source research | 13 | Scrape URL content (Cheerio + Puppeteer fallback). Extract core topic. Cross-reference with 2-3 sources for accuracy. Identify subject domain. Works for articles, Wikipedia, YouTube transcripts. |
| S9-05 | Stage 2: Safety & suitability filter | 8 | Auto-reject (violence, sexual, hate, dangerous). Flag for review (scary, religious, death, news). Auto-pass (STEM, nature, art, social). Notify parent on reject with reason. |
| S9-06 | Stage 3: Concept decomposition | 13 | Break topic into 3-6 teachable atoms. Map against child's current knowledge (placeholder — full graph in Sprint 10). Rank by engagement potential + learning value. Select teaching strategy per concept. |
| S9-07 | Stage 4: Card generation with skill invocation | 13 | For each concept, invoke appropriate content skill (story-writer, quiz-maker, experiment-designer). Generate 6-8 cards per lesson. Output matches Card schema. Difficulty adapts to child's age setting. |
| S9-08 | Stage 5: Asset generation orchestration | 8 | Trigger DALL-E 3 + TTS for all cards in parallel. Upload to R2. Retry on failure (max 3). Total generation time < 90s for a full lesson. |
| S9-09 | Stage 6: Quality gate (second-model review) | 8 | Second Claude call reviews generated lesson for: fact accuracy, age appropriateness, card flow coherence, readability score. Regenerate flagged cards. Log quality scores. |
| S9-10 | Job queue for async pipeline execution | 5 | Pipeline runs as background job (BullMQ + Redis/Upstash). Companion app polls for progress. Parent can close app and come back. Job timeout at 120s. |

**Sprint 9 Total: 89 pts**

**Sprint 9 Definition of Done:**
- [ ] Parent pastes URL in Companion → lesson appears in kid's app within 90 seconds
- [ ] Generated lesson has hero image, 6-8 cards with narration, and a quiz
- [ ] Safety filter blocks test URLs with inappropriate content
- [ ] Quality gate catches and regenerates low-quality cards
- [ ] Pipeline handles errors gracefully (timeout, LLM failure, image generation failure)

---

## Sprint 10: Child Memory System + Content Skills (Week 5-6)

**Goal:** The AI starts learning each child. Content quality jumps from "generic for age" to "personalized for this kid."

**Theme:** "The Brain"

### MEM Epic — Knowledge Graph + Engagement (50 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S10-01 | Design and implement child knowledge graph schema | 13 | Postgres tables: concepts (id, name, domain, prerequisites), child_concepts (child_id, concept_id, confidence, last_tested, attempts). Seeded with 50 base concepts across 3 domains (computers, robots, AI). |
| S10-02 | Track concept mastery from quiz results | 8 | Each quiz answer updates confidence score. Correct: +0.15 (capped at 1.0). Wrong: -0.1 (floor at 0.0). Confidence decays 0.02/week without reinforcement. |
| S10-03 | Build engagement profile from interaction data | 13 | Track per-child: avg session length, preferred card types (ranked), topic affinities (by time spent), frustration signals (rapid wrong answers), flow signals (consecutive correct). Store encrypted per COPPA requirements. |
| S10-04 | Implement parent guidance API | 8 | Companion app endpoints: set topic focus, adjust difficulty (-2 to +2), set content boundaries (array of strings), set session limits. Stored in child profile. Consumed by pipeline at generation time. |
| S10-05 | Context engine: session-aware state for real-time adaptation | 8 | Current session: time of day, session duration, recent quiz results, lessons completed today, current streak. Injected into every LLM prompt as context block. |

### SKILL Epic — Content Generation Skills v1 (68 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S10-06 | Build `story-writer` skill with age profiles | 13 | Skill directory with SKILL.md + references (age-profiles.md, topics.md, styles.md). Generates narrative cards. Vocabulary adapts to age. Incorporates child's interest topics from engagement profile. Output quality tested across ages 4, 6, 8. |
| S10-07 | Build `quiz-maker` skill with difficulty curves | 13 | Generates quiz cards. 4-5 options (not 3). Difficulty based on demonstrated knowledge + age. Includes plausible distractors based on common misconceptions. Adapts question format: visual, textual, audio. |
| S10-08 | Build `experiment-designer` skill | 8 | Generates drag-and-drop experiment card configs. Adapts complexity to age + motor skill level. Includes success criteria and hint system. |
| S10-09 | Build `curriculum-architect` skill | 13 | Given child's knowledge graph + parent goals + engagement profile, generates a 4-8 lesson sequence. Maps prerequisites. Avoids repeating mastered concepts. Prioritizes gap-filling. Output: ordered lesson plan with per-lesson concept targets. |
| S10-10 | Build `voice-persona` skill for character dialogue | 8 | Defines the character's voice at each age level. Vocabulary, humor style, emotional range, slang. Outputs dialogue lines that feel natural for the child's age. Consumed by Sparky conversation engine + card narration. |
| S10-11 | Teaching strategy matrix implementation | 5 | Given concept type + child learning style, select optimal card format. Matrix: [vocabulary, abstract, process, comparison, cause-effect, factual] × [visual, auditory, kinesthetic]. Returns ranked card type recommendations. |
| S10-12 | Integrate skills into Grand Architect pipeline | 8 | Pipeline Stage 4 now invokes real skills instead of generic prompts. Each concept routed to appropriate skill based on teaching strategy matrix. Skills receive child context (age, knowledge, engagement, parent guidance). |

**Sprint 10 Total: 118 pts** (heaviest sprint — core intelligence layer)

**Sprint 10 Definition of Done:**
- [ ] New lesson generated for child uses their knowledge graph (doesn't re-teach mastered concepts)
- [ ] Quiz difficulty reflects actual demonstrated ability, not just age
- [ ] Generated story references the child's interest topics
- [ ] Curriculum architect produces a coherent 4-lesson sequence with prerequisites respected
- [ ] Parent changes difficulty in Companion → next generated lesson reflects the change

---

## Sprint 11: Memory Depth + Subscriptions (Week 7-8)

**Goal:** Memory deepens. Monetization works. The product feels finished.

**Theme:** "The Polish"

### MEM Epic — Phase B (30 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S11-01 | Knowledge graph visualization for parent dashboard | 13 | Interactive graph in Companion showing mastered (green), in-progress (yellow), not-yet-introduced (gray) concepts. Tap a node to see which lessons covered it. Uses existing ProgressDashboardView. |
| S11-02 | Weekly learning report generation | 8 | Auto-generated markdown report: concepts mastered this week, growth areas, recommended next topics, session time, streak status. Delivered via push notification + in-app. |
| S11-03 | Sparky remembers past conversations | 5 | Sparky references previous lessons: "Remember when we learned about binary?" Uses child's knowledge graph to seed conversation context. Maximum 500-token history injection per conversation. |
| S11-04 | Character age adaptation based on parent setting | 4 | When parent changes age setting, character's vocabulary, humor, teaching style, and visual complexity shift over next 5 sessions (gradual transition, not instant swap). Uses voice-persona skill age profiles. |

### PAY Epic (42 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S11-05 | Configure StoreKit 2 products in App Store Connect | 5 | 2 subscription products (Pro monthly, BYOK monthly). Pricing configured. Sandbox products testable. |
| S11-06 | Test StoreKit 2 sandbox purchase flow end-to-end | 8 | Purchase → receipt validation → entitlement granted → features unlocked. Test: new purchase, renewal, cancellation, grace period, billing retry. |
| S11-07 | Implement server-side receipt validation (App Store Server API v2) | 13 | Server validates JWS-signed transactions. Handles all 6 subscription states. Idempotent processing. Webhook for server notifications (already scaffolded in Sprint 5). |
| S11-08 | Wire entitlement checks throughout both apps | 8 | Free users: 3 paths, no Sparky chat, no pipeline. Pro: all features. BYOK: all features + own API key. Gate checks cached 5 min. Upgrade prompts on gated features. |
| S11-09 | Subscription management UI in Companion Settings | 5 | Show current tier, renewal date, manage button (opens system subscription sheet). Upgrade/downgrade path. BYOK key entry with validation. |
| S11-10 | Grace period + involuntary churn handling | 3 | If subscription lapses: 7-day grace period with "renew" banner. After grace: downgrade to free, preserve data. Re-subscribe restores Pro instantly. |

**Sprint 11 Total: 72 pts** (lighter sprint — polish and testing focus)

**Sprint 11 Definition of Done:**
- [ ] Full purchase flow works in StoreKit sandbox
- [ ] Free user hits gate on Sparky → upgrade prompt shown
- [ ] Parent sees knowledge graph of their child's learning
- [ ] Weekly report generates and displays correctly
- [ ] Sparky references something from a previous session naturally

---

## Sprint 12: App Store Prep + TestFlight (Week 9-10)

**Goal:** Internal beta running. External beta recruiting. Submission-ready.

**Theme:** "Ready to Ship"

### SHIP Epic (55 pts)

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S12-01 | App Store Connect setup for both apps | 5 | Both apps registered, bundle IDs configured, team roles assigned, categories set (Education, Kids Age 5-8). |
| S12-02 | Privacy Nutrition Labels | 5 | Accurate declarations for: speech recognition, microphone, child name/age, learning progress, analytics. No third-party data sharing declared. |
| S12-03 | COPPA declaration in Kids Category | 3 | Age band: 5-8. Parental gate declared. No behavioral advertising. No third-party analytics. COPPA compliance checkbox. |
| S12-04 | Create 5 iPad screenshots per app | 8 | Home, Flipbook lesson, Sparky conversation, Quiz interaction, Trophy room (Kids). Dashboard, Pipeline, Knowledge graph, Card editor, Progress (Companion). 12.9" and 11" sizes. |
| S12-05 | Create 30-second App Preview video | 8 | Shows: parent pastes URL → lesson generates → kid opens flipbook → answers quiz → talks to Sparky → earns badge. Captured from real app on real iPad. |
| S12-06 | Write App Store descriptions + keywords | 3 | Kids app: child-focused, benefit-driven. Companion: parent value proposition. Keywords: AI learning, kids education, STEM, personalized, COPPA. |
| S12-07 | Prepare App Review notes | 3 | Explain: parental gate mechanism, LLM usage and content filtering, COPPA compliance, demo account credentials, how to test voice features. |
| S12-08 | Internal TestFlight distribution | 5 | Build uploaded, internal testing group created, install verified on iPad + iPhone. Crash-free launch. All core flows functional. |
| S12-09 | External TestFlight beta (5-10 families) | 8 | Beta invite sent, parental consent collected, test script provided. Focus areas: onboarding completion, lesson engagement time, crash-free rate, Sparky conversation quality. |
| S12-10 | Bug bash — fix TestFlight feedback | 7 | Triage all beta feedback. Fix critical/high bugs. Document known issues for v1.1. |

**Sprint 12 Total: 55 pts** (lower velocity — testing and non-code work)

**Sprint 12 Definition of Done:**
- [ ] Both apps running on TestFlight for 5+ external families
- [ ] Crash-free rate > 99% across 7 days
- [ ] Screenshots and preview video approved by team
- [ ] All App Store metadata complete
- [ ] No critical bugs outstanding

---

## Sprint 13: Submit + Launch Buffer (Week 11-12)

**Goal:** App Store submission. Handle review feedback. Launch.

**Theme:** "Go Live"

| ID | Story | Points | Acceptance Criteria |
|----|-------|--------|-------------------|
| S13-01 | Submit both apps to App Store Review | 3 | Both apps submitted with all metadata, screenshots, review notes. |
| S13-02 | Handle App Store Review feedback (if rejected) | 13 | Buffer for rejection response. Most common kids' app rejections pre-addressed. Respond within 24 hours. |
| S13-03 | Infrastructure load testing | 8 | Simulate 100 concurrent users. Verify: API latency < 500ms p95, LLM pipeline handles 10 concurrent jobs, no database connection exhaustion. |
| S13-04 | Launch monitoring dashboard | 5 | Railway metrics + custom dashboard: active users, lessons generated, Sparky conversations, error rate, LLM costs, subscription conversions. |
| S13-05 | Post-launch hotfix buffer | 8 | Reserved capacity for Day 1 issues. |
| S13-06 | v1.1 planning based on beta + launch data | 5 | Document: top user requests, engagement metrics, content quality scores, churn signals. Prioritize v1.1 backlog. |

**Sprint 13 Total: 42 pts** (intentionally light — launch buffer)

---

## Summary Dashboard

```
PHASE 2 SPRINT PLAN
═══════════════════════════════════════════════════════
Sprint 8  ████████████████████░░  89 pts  "Lights On"
Sprint 9  ████████████████████░░  89 pts  "The Pipeline"
Sprint 10 ████████████████████████ 118 pts "The Brain"
Sprint 11 ████████████████░░░░░░  72 pts  "The Polish"
Sprint 12 ██████████████░░░░░░░░  55 pts  "Ready to Ship"
Sprint 13 ██████████░░░░░░░░░░░░  42 pts  "Go Live"
═══════════════════════════════════════════════════════
Total: 465 pts across 6 sprints (12 weeks)
Budget: 480 pts capacity → 15 pts buffer (3%)

Epics:
  DEPLOY  ███░░░░░░░░░░░  55 pts (12%)
  LLM     ████████░░░░░░  89 pts (19%)
  PIPE    █████████████░  105 pts (23%)
  MEM     ██████████░░░░  80 pts (17%)
  SKILL   ████████░░░░░░  68 pts (15%)
  PAY     █████░░░░░░░░░  42 pts (9%)
  SHIP    ███████░░░░░░░  55 pts (12%)
```

---

## Critical Path

The longest dependency chain determines the minimum timeline:

```
S8-01 Deploy backend
  └→ S8-05 Point iOS to live API
      └→ S8-09 Wire Sparky to OpenAI RT
          └→ S8-12 Wire Claude for content
              └→ S9-04 Pipeline Stage 1 (scraping)
                  └→ S9-07 Pipeline Stage 4 (card gen)
                      └→ S10-01 Knowledge graph schema
                          └→ S10-06 Story-writer skill
                              └→ S10-12 Integrate skills into pipeline
                                  └→ S11-01 Knowledge graph visualization
                                      └→ S12-08 TestFlight
                                          └→ S13-01 Submit
```

**Critical path length: 12 items across 6 sprints.** No parallelism shortcut exists — each step depends on the previous. The buffer is in Sprint 13 (intentionally light) and the 15-point capacity margin.

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Apple rejects kids app on first submission | Medium | 2-week delay | Pre-addressed top 8 rejection reasons in audit. Demo account ready. Detailed review notes. Sprint 13 has 13-pt buffer for rejection response. |
| LLM content quality too low for kids | Medium | Requires skill refinement | Quality gate (Stage 6) catches bad output. Start with pre-built lessons + generated supplements. Iterate skills based on beta feedback. |
| OpenAI Realtime API latency too high for kids | Low | Bad UX for Sparky | Fallback to standard API + TTS if Realtime latency > 3s. Pre-generate common Sparky responses. |
| LLM costs exceed projections | Medium | Margin pressure | Cost tracking from Sprint 9. Set hard limits per child/day. Aggressive caching of common content. Claude is 10x cheaper than GPT-4 for text. |
| Solo developer burnout over 12 weeks | High | Velocity collapse | Sprints 11-13 intentionally lighter. Sprint 13 is mostly buffer. No crunch — sustainable pace. |
| StoreKit 2 sandbox issues | Low | Delays monetization | StoreKit 2 is mature. Scaffold already exists from Sprint 5. Most work is testing, not building. |
| Supabase or Railway outage at launch | Low | App down | Both have 99.9% SLA. Add health check monitoring. R2 assets served via CDN (independent). Offline mode covers short outages. |

---

## Definition of Done — Phase 2 Complete

- [ ] Both apps approved and live on App Store
- [ ] 24 pre-built lessons + at least 10 AI-generated lessons tested
- [ ] Sparky voice conversation works on real iPad
- [ ] Full URL → lesson pipeline produces quality content in < 90 seconds
- [ ] Knowledge graph tracks per-child concept mastery
- [ ] Subscription purchase flow verified with real transactions
- [ ] Crash-free rate > 99.5% across 7-day TestFlight beta
- [ ] 5+ families completed beta test with feedback collected
- [ ] Infrastructure handles 100 concurrent users without degradation
- [ ] Monthly infrastructure cost < $100 at launch scale
- [ ] LLM cost per lesson generation < $0.20
- [ ] All COPPA, privacy, and App Store guidelines satisfied

---

## Milestone Checkpoints

| Week | Milestone | Go/No-Go Gate |
|------|-----------|---------------|
| Week 2 | Backend live, Sparky talks | Can a kid have a real conversation with Sparky? |
| Week 4 | Pipeline works end-to-end | Can a parent paste a URL and get a real lesson? |
| Week 6 | Memory system operational | Does the AI generate different content for different kids? |
| Week 8 | Subscriptions working | Can a parent purchase Pro and unlock features? |
| Week 10 | TestFlight beta live | Are 5+ families using the app daily? |
| Week 12 | App Store submission | All review criteria satisfied? |
