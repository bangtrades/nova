# Sparky — AI & Tech Learning Platform for Kids

> A parent-curated learning pipeline that transforms web content into visual, interactive, voice-enabled lessons. Two native iOS apps — one for kids, one for parents.

---

## 1. Product Vision

**For** parents of young children (ages 4–8) **who** want to introduce AI and technology concepts early, **Sparky** is a dual-app iOS platform — a parent companion app (iPhone + iPad) and a kid-facing learning app (iPad) — **that** turns any web content into age-appropriate, visual, interactive learning cards. **Unlike** YouTube Kids or generic educational apps, Sparky gives parents full curation control while using AI to do the heavy lifting of content transformation.

### Core Loop

```
Parent finds interesting content (article, video, tool)
    → Pastes URL into Sparky Companion (iPhone/iPad)
    → AI extracts key concepts, suggests lesson cards
    → Parent reviews, edits, approves
    → Lesson syncs to Sparky Kids (iPad)
    → Child taps, swipes, listens, and interacts
    → Progress tracked back to companion app
```

### App Store Products

| App | Platform | Price | Description |
|-----|----------|-------|-------------|
| **Sparky Kids** | iPad | Free (limited) | Kid-facing learning app with flipbook lessons, Sparky AI buddy, experiments |
| **Sparky Companion** | iPhone + iPad | Free (limited) | Parent management app — URL intake, card editor, progress dashboard, account management |
| **Sparky Pro** (IAP) | Both apps | $6.99/mo or $49.99/yr | Unlimited AI-generated lessons, voice chat with Sparky, all learning paths, priority asset generation |

### Monetization Model: Freemium + Subscription

**Free Tier:**
- 3 pre-built "starter" learning paths (hand-crafted, no AI needed)
- Manual lesson creation (parent writes cards by hand)
- Basic progress tracking
- No voice chat with Sparky

**Pro Subscription ($6.99/mo):**
- Unlimited URL → lesson AI pipeline (powered by Sparky backend)
- Voice chat with Sparky AI buddy
- All learning paths unlocked
- TTS narration generation
- AI illustration generation
- Advanced progress analytics

**BYOK Option (Bring Your Own Key):**
- Parent connects their OpenAI account via OAuth
- AI pipeline uses parent's own OpenAI credits instead of Sparky's proxy
- Unlocks Pro AI features without the subscription compute cost
- Parent still needs Pro sub for non-AI features (content library, analytics) — or a separate "BYOK tier" at reduced price ($2.99/mo)

### Target User Profiles

| User | Device | Role | Key Need |
|------|--------|------|----------|
| **Parent** | iPhone / iPad | Curator & guide | Fast content-to-lesson pipeline with editorial control, on-the-go management |
| **Child** | iPad | Learner | Fun, visual, tap-friendly experience with voice guidance |

---

## 2. Curriculum Philosophy

### Progressive Skill Ladder

The curriculum moves through four stages, each unlocking when the child demonstrates comfort with the previous:

| Stage | Name | Age Range | Concepts | Interaction Style |
|-------|------|-----------|----------|-------------------|
| **1** | **Explorer** | 4–5 | What is a computer? What is the internet? Helpers (AI assistants) | Tap cards, listen to narration, simple matching |
| **2** | **Thinker** | 5–6 | How AI learns (patterns, sorting), good/bad data, privacy basics | Drag-and-drop experiments, "teach the robot" games |
| **3** | **Maker** | 6–7 | Prompting AI, simple cause-and-effect logic, visual block coding | Voice commands to AI, Scratch Jr-style sequencing |
| **4** | **Creator** | 7–8+ | Real prompting, basic code concepts, building simple projects | Guided project mode, text+voice input, AI pair partner |

### Content Types

Each lesson is built from composable card types:

| Card Type | Description | Example |
|-----------|-------------|---------|
| **Story Card** | Illustrated narrative with tap-to-advance | "Once upon a time, a robot needed to learn what a cat looks like..." |
| **Concept Card** | Big visual + one sentence explanation | Image of a neural network as a "brain made of tiny lights" |
| **Experiment Card** | Interactive cause-and-effect | "Tap the blue pictures to teach the robot what 'blue' means" |
| **Quiz Card** | Simple choice or matching | "Which one did the robot learn? Tap it!" |
| **Voice Card** | Speak-and-respond interaction | "Say 'Hello Sparky!' and see what happens" |
| **Video Card** | Short clip (15-30s) with pause points | Embedded animation explaining how WiFi works |

---

## 3. System Architecture

### High-Level Overview

Two native iOS apps sharing a Swift Package ecosystem, backed by a Node.js API server with PostgreSQL, and a pluggable LLM provider layer starting with OpenAI OAuth.

```
┌─────────────────────────────────────────────────────────────────┐
│                     iOS APP LAYER                                │
│                                                                  │
│  ┌───────────────────────┐      ┌───────────────────────────┐   │
│  │  SPARKY KIDS           │      │  SPARKY COMPANION          │   │
│  │  (iPad only)           │      │  (iPhone + iPad)           │   │
│  │                        │      │                            │   │
│  │  • Pinterest grid home │      │  • URL intake + AI draft   │   │
│  │  • Flipbook lessons    │      │  • Card editor (WYSIWYG)   │   │
│  │  • Experiment cards    │      │  • Curriculum manager       │   │
│  │  • Sparky voice chat   │      │  • Progress dashboard      │   │
│  │  • Trophy room         │      │  • LLM provider settings   │   │
│  │  • Offline cache       │      │  • Subscription management │   │
│  │                        │      │  • Child profile management│   │
│  └────────┬───────────────┘      └──────────┬────────────────┘   │
│           │                                  │                    │
│  ┌────────┴──────────────────────────────────┴────────────────┐  │
│  │  SHARED SWIFT PACKAGES                                      │  │
│  │  SparkCore    — Models, API client, sync engine             │  │
│  │  SparkAuth    — JWT, Apple Sign In, OAuth flows             │  │
│  │  SparkVoice   — TTS + speech recognition wrappers           │  │
│  │  SparkStorage — Core Data stack, asset cache, offline sync  │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                                │ REST API + WebSocket (sync)
                                ▼
┌───────────────────────────────────────────────────────────────────┐
│                      BACKEND LAYER                                 │
│                                                                    │
│  ┌────────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  API Server     │  │  Auth Service │  │  Content Store       │  │
│  │  (Node.js /     │  │              │  │  (PostgreSQL)        │  │
│  │   Fastify)      │  │  • JWT issue │  │                      │  │
│  │                 │  │  • Apple SSO │  │  • Lessons & cards   │  │
│  │  /api/v1/...    │  │  • OAuth mgr │  │  • Progress data     │  │
│  │                 │  │    (OpenAI)  │  │  • User profiles     │  │
│  └────────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  LLM PROVIDER LAYER (pluggable)                              │  │
│  │                                                               │  │
│  │  ┌─────────────┐  ┌─────────────────┐  ┌────────────────┐   │  │
│  │  │  Provider    │  │  OpenAI OAuth   │  │  Sparky Proxy  │   │  │
│  │  │  Router      │──│  (user's key)   │  │  (our API key) │   │  │
│  │  │              │  │                 │  │                │   │  │
│  │  │  Routes to   │  │  • OAuth 2.0    │  │  • Rate-limited│   │  │
│  │  │  user's own  │  │  • Token store  │  │  • Metered     │   │  │
│  │  │  provider or │  │  • Token refresh│  │  • Sub-gated   │   │  │
│  │  │  our proxy   │  │                 │  │                │   │  │
│  │  └─────────────┘  └─────────────────┘  └────────────────┘   │  │
│  │                                                               │  │
│  │  Future providers: [Anthropic?], Google Gemini, Mistral, ... │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  AI CONTENT PIPELINE                                         │  │
│  │                                                               │  │
│  │  URL Scraper → Content Analyzer → Card Generator              │  │
│  │  (Readability    (LLM: extract      (LLM: age-adapt          │  │
│  │   + Puppeteer)    key concepts)       + card format)          │  │
│  │                                                               │  │
│  │  TTS Generator → Image Generator → Asset Uploader            │  │
│  │  (OpenAI TTS /    (DALL-E / Flux)    (Cloudflare R2)         │  │
│  │   ElevenLabs)                                                 │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌─────────────────┐  ┌────────────────────────────────────────┐ │
│  │  Sync Engine     │  │  Subscription & Billing                │ │
│  │  (WebSocket +    │  │  • StoreKit 2 server validation        │ │
│  │   background     │  │  • Entitlement checks                  │ │
│  │   refresh)       │  │  • BYOK vs proxy routing               │ │
│  └─────────────────┘  └────────────────────────────────────────┘ │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Tech Stack Decision Matrix

| Component | Technology | Why |
|-----------|-----------|-----|
| **Sparky Kids** | SwiftUI (iPad) | Native gestures, Speech framework, App Store ready, offline Core Data |
| **Sparky Companion** | SwiftUI (iPhone + iPad) | Shared packages with Kids app, adaptive layout, native feel |
| **Shared Packages** | Swift Package Manager | Code reuse between apps — models, networking, auth, storage |
| **API Server** | Node.js / Fastify | Fast JSON, good ecosystem, async-friendly for AI pipeline |
| **Database** | PostgreSQL | Relational structure fits curriculum hierarchy, good with Prisma ORM |
| **File Storage** | Cloudflare R2 | S3-compatible, free egress, fast CDN for images/audio |
| **LLM (MVP)** | OpenAI API (via OAuth or proxy) | GPT-4o for content analysis + card generation, TTS for narration |
| **LLM Router** | Custom provider abstraction | Pluggable interface — swap/add providers without app changes |
| **Image Gen** | DALL-E 3 (via OpenAI) | Consistent illustration style, same OAuth token as LLM |
| **Voice/TTS** | OpenAI TTS + Apple AVSpeech | OpenAI for high-quality narration, Apple for real-time fallback |
| **Auth** | Apple Sign In + JWT | Required by Apple for App Store, clean UX |
| **OAuth** | OpenAI OAuth 2.0 | BYOK model — parent connects their own OpenAI account |
| **Subscriptions** | StoreKit 2 | Server-side validation, family sharing support |
| **Sync** | REST + background app refresh | Simple for MVP, WebSocket for real-time later |

---

## 4. LLM Provider Architecture

### OpenAI OAuth Flow

```
1. Parent taps "Connect OpenAI" in Companion app
2. App opens ASWebAuthenticationSession to OpenAI OAuth endpoint
3. Parent logs into their OpenAI account, grants permissions
4. Callback returns authorization code to app
5. App sends code to Sparky backend
6. Backend exchanges code for access_token + refresh_token
7. Tokens stored encrypted in backend (per-user, never on device)
8. All subsequent AI calls route through user's OpenAI credentials
9. Backend handles token refresh transparently
```

### Provider Router Design

```swift
// Shared package: SparkCore

protocol LLMProvider {
    func analyzeContent(_ content: String) async throws -> ContentAnalysis
    func generateCards(_ analysis: ContentAnalysis, stage: Stage) async throws -> [CardDraft]
    func generateSpeech(_ text: String, voice: VoiceStyle) async throws -> AudioData
    func generateImage(_ prompt: String, style: IllustrationStyle) async throws -> ImageData
}

// Concrete implementations
class OpenAIProvider: LLMProvider { ... }   // MVP
class SparkProxyProvider: LLMProvider { ... } // Uses our backend API key
// Future:
// class GeminiProvider: LLMProvider { ... }
// class AnthropicProvider: LLMProvider { ... } // when/if they add OAuth
```

### Routing Logic

```
IF user has connected OpenAI via OAuth:
    → Route all AI calls through user's OpenAI credentials
    → No compute cost to Sparky
    → User pays their own OpenAI usage
    
ELSE IF user has Pro subscription:
    → Route through Sparky proxy (our OpenAI API key)
    → Rate-limited (e.g., 50 lessons/month, 100 voice chats/month)
    → Compute cost covered by subscription revenue

ELSE (free tier):
    → No AI pipeline access
    → Manual card creation only
    → Pre-built starter lessons available
```

---

## 5. Content Pipeline Deep Dive

### URL → Lesson Card Flow

```
Step 1: INGEST
├── Parent pastes URL into Companion app
├── Backend scrapes content (Readability + Puppeteer for JS-heavy sites)
├── Extracts: title, body text, images, video embeds, metadata
└── Stores raw content in database

Step 2: AI ANALYSIS (via LLM Provider Router)
├── Analyze content for key concepts
├── Determine age-appropriateness
├── Suggest which curriculum stage it fits
├── Extract 3-5 teachable moments
└── Flag anything that needs parent review

Step 3: CARD GENERATION (via LLM Provider Router)
├── For each teachable moment, generate card(s):
│   ├── Story Card: narrative text + image prompt
│   ├── Concept Card: one-liner + visual description
│   ├── Experiment Card: interaction spec + correct answers
│   ├── Quiz Card: question + options
│   └── Voice Card: dialogue script
├── Generate voice narration scripts
├── Generate image prompts for illustrations
└── Assemble into lesson draft

Step 4: PARENT REVIEW (in Companion app)
├── Cards displayed in card editor
├── Parent can: reorder, edit text, swap images,
│   remove cards, adjust difficulty
├── Preview mode: simulates iPad flipbook experience
└── Approve → publish to child's app

Step 5: ASSET GENERATION (via LLM Provider Router)
├── TTS generates audio for all narration
├── Image gen creates illustrations
├── Assets uploaded to Cloudflare R2
└── Lesson marked as ready

Step 6: SYNC TO SPARKY KIDS
├── Kids app checks for new lessons on launch + background refresh
├── Downloads lesson data + assets
├── Caches locally in Core Data for offline use
└── New lesson appears with a sparkle animation
```

### AI Prompt Strategy

```
System: You are a children's education specialist creating 
learning content for a {age}-year-old child. The content must be:
- Visual-first (every concept needs an image)
- One idea per card (no cognitive overload)  
- Conversational tone (like a friendly teacher)
- Interactive where possible (ask questions, prompt actions)
- Progressive (build on what came before)

Stage: {Explorer|Thinker|Maker|Creator}
Source URL: {url}
Extracted content: {scraped_text}

Generate a lesson with 5-8 cards following the card schema.
Return structured JSON matching the Card model.
```

---

## 6. Sparky Kids — iPad App Design Spec

### Navigation Model

```
Home (Pinterest Grid)
├── Learning Paths (horizontal scroll of themed collections)
│   ├── "What is AI?" (8 lessons)
│   ├── "How Computers Think" (6 lessons)
│   └── "Talk to Robots" (5 lessons)
├── Individual Lesson Cards (tap to open)
│   └── Flipbook View (swipe through cards)
│       ├── Story Card → tap anywhere to advance
│       ├── Concept Card → tap image to hear explanation
│       ├── Experiment Card → drag/drop interaction
│       ├── Quiz Card → tap answer
│       └── Voice Card → microphone activates
├── Sparky (AI buddy character)
│   └── Voice chat mode (guided conversations)
└── Trophy Room (progress, badges, streaks)
```

### Visual Design Principles

| Principle | Implementation |
|-----------|---------------|
| **Big & Bold** | Minimum tap target 60pt, large illustrations, minimal text |
| **Consistent Character** | "Sparky" — a friendly robot character guides every lesson |
| **Gestalt Grouping** | Related cards cluster visually; lessons feel like "chapters" |
| **Color = Meaning** | Blue = AI/tech, Green = nature/real world, Orange = experiments, Purple = creativity |
| **No Dead Ends** | Every screen has a clear "next" action; always a way forward |
| **Celebration** | Haptic feedback, particle animations, sound effects on completion |

### Key Screens

**1. Home Grid (Pinterest Layout)**
- Masonry grid of lesson thumbnails
- Each card: illustration, lesson title, 1-3 star difficulty, completion badge
- Long-press for "peek" preview
- Pull-to-refresh for new content
- Top row: current learning path with progress bar

**2. Flipbook View**
- Full-screen card with swipe-to-advance
- Bottom: progress dots showing position in lesson
- Top-right: Sparky's face (tap for voice hint)
- Swipe right = next, swipe left = previous
- Pinch to zoom back to grid

**3. Experiment View**
- Interactive canvas (drag targets, tap zones)
- Sparky provides voice instructions
- Success = confetti + badge
- Failure = gentle "try again" with hint

**4. Voice Chat with Sparky**
- Large Sparky animation in center
- Tap-and-hold microphone button to talk
- Sparky responds with animated expressions
- Guardrails: only discusses lesson topics, redirects off-topic gently

---

## 7. Sparky Companion — Parent App Design Spec

### Platform Considerations

The companion app runs on both iPhone and iPad. On iPhone it's optimized for quick actions (approve a lesson, check progress, paste a URL on the go). On iPad it expands to a full editor workspace.

### Navigation Model (TabView)

```
Tab 1: Dashboard
├── Activity feed (child's recent completions)
├── Quick-add URL bar
├── Lesson status overview (draft / published / in-progress)
└── Weekly stats summary

Tab 2: Content Studio
├── URL Intake flow
│   ├── Paste URL → "Sparky is reading this..."
│   ├── AI analysis: topic, stage, key concepts
│   └── "Generate Lesson" → Card drafts
├── Card Editor
│   ├── iPhone: vertical card stack with edit-in-place
│   ├── iPad: side-by-side editor + preview
│   ├── Reorder cards (drag)
│   ├── Edit text, swap images, adjust voice script
│   └── Preview → Publish
└── Lesson Library (all drafts + published)

Tab 3: Curriculum
├── Learning paths (drag to reorder)
├── Assign lessons to paths
├── Set prerequisites
└── Stage progression timeline

Tab 4: Progress
├── Completion timeline
├── Time-per-card heatmap  
├── Voice interaction highlights
├── Suggested next lessons (AI-powered)
└── Badge gallery

Tab 5: Settings
├── Child Profile
│   ├── Name, age, avatar
│   ├── Stage override
│   └── Content filters
├── LLM Providers
│   ├── Connect OpenAI (OAuth flow)
│   ├── Provider status + usage stats
│   └── [Future: add more providers]
├── Subscription Management
│   ├── Current plan (Free / Pro / BYOK)
│   ├── Manage via StoreKit
│   └── Usage dashboard (AI calls remaining)
└── Account
    ├── Apple ID (Sign In with Apple)
    ├── Family sharing settings
    └── Data export / deletion (COPPA)
```

---

## 8. Swift Project Structure

### Monorepo Layout

```
Sparky/
├── Sparky.xcworkspace
│
├── Apps/
│   ├── SparkKids/                          # iPad-only kid app
│   │   ├── SparkKids.xcodeproj
│   │   ├── Sources/
│   │   │   ├── SparkKidsApp.swift          # Entry point
│   │   │   ├── Features/
│   │   │   │   ├── Home/
│   │   │   │   │   ├── HomeView.swift               # Pinterest grid
│   │   │   │   │   ├── LessonTileView.swift          # Grid cell
│   │   │   │   │   └── LearningPathRow.swift         # Horizontal scroll
│   │   │   │   ├── Flipbook/
│   │   │   │   │   ├── FlipbookView.swift            # Card container + swipe
│   │   │   │   │   ├── StoryCardView.swift
│   │   │   │   │   ├── ConceptCardView.swift
│   │   │   │   │   ├── ExperimentCardView.swift
│   │   │   │   │   ├── QuizCardView.swift
│   │   │   │   │   └── VoiceCardView.swift
│   │   │   │   ├── Sparky/
│   │   │   │   │   ├── SparkyView.swift              # AI buddy interface
│   │   │   │   │   └── SparkyAnimator.swift          # Character animations
│   │   │   │   └── Trophy/
│   │   │   │       ├── TrophyRoomView.swift
│   │   │   │       └── BadgeView.swift
│   │   │   └── App/
│   │   │       └── KidsAppState.swift                # Environment object
│   │   └── Resources/
│   │       ├── Assets.xcassets
│   │       ├── SparkySpriteSheet/
│   │       └── Sounds/
│   │
│   └── SparkCompanion/                     # iPhone + iPad parent app
│       ├── SparkCompanion.xcodeproj
│       ├── Sources/
│       │   ├── SparkCompanionApp.swift     # Entry point
│       │   ├── Features/
│       │   │   ├── Dashboard/
│       │   │   │   ├── DashboardView.swift
│       │   │   │   ├── ActivityFeedView.swift
│       │   │   │   └── QuickAddURLView.swift
│       │   │   ├── ContentStudio/
│       │   │   │   ├── URLIntakeView.swift
│       │   │   │   ├── CardEditorView.swift
│       │   │   │   ├── CardEditorPhone.swift          # Compact layout
│       │   │   │   ├── CardEditorPad.swift             # Side-by-side layout
│       │   │   │   ├── LessonPreviewView.swift
│       │   │   │   └── LessonLibraryView.swift
│       │   │   ├── Curriculum/
│       │   │   │   ├── CurriculumView.swift
│       │   │   │   └── PathEditorView.swift
│       │   │   ├── Progress/
│       │   │   │   ├── ProgressView.swift
│       │   │   │   ├── TimeHeatmapView.swift
│       │   │   │   └── VoiceLogView.swift
│       │   │   └── Settings/
│       │   │       ├── SettingsView.swift
│       │   │       ├── ChildProfileView.swift
│       │   │       ├── LLMProviderView.swift
│       │   │       ├── OAuthFlowView.swift            # ASWebAuthSession
│       │   │       └── SubscriptionView.swift          # StoreKit 2
│       │   └── App/
│       │       └── CompanionAppState.swift
│       └── Resources/
│           └── Assets.xcassets
│
├── Packages/
│   ├── SparkCore/                          # Shared models & API
│   │   ├── Package.swift
│   │   └── Sources/SparkCore/
│   │       ├── Models/
│   │       │   ├── Lesson.swift
│   │       │   ├── Card.swift
│   │       │   ├── LearningPath.swift
│   │       │   ├── Progress.swift
│   │       │   ├── ChildProfile.swift
│   │       │   └── Subscription.swift
│   │       ├── API/
│   │       │   ├── APIClient.swift
│   │       │   ├── APIRouter.swift
│   │       │   └── Endpoints.swift
│   │       └── Sync/
│   │           ├── SyncManager.swift
│   │           └── ConflictResolver.swift
│   │
│   ├── SparkAuth/                          # Auth + OAuth
│   │   ├── Package.swift
│   │   └── Sources/SparkAuth/
│   │       ├── AuthManager.swift
│   │       ├── AppleSignIn.swift
│   │       ├── JWTHandler.swift
│   │       └── OAuth/
│   │           ├── OAuthManager.swift
│   │           ├── OpenAIOAuth.swift       # OpenAI-specific OAuth
│   │           └── OAuthTokenStore.swift   # Keychain storage
│   │
│   ├── SparkVoice/                         # TTS + Speech Recognition
│   │   ├── Package.swift
│   │   └── Sources/SparkVoice/
│   │       ├── SpeechSynthesizer.swift     # AVSpeechSynthesizer wrapper
│   │       ├── SpeechRecognizer.swift      # SFSpeechRecognizer wrapper
│   │       └── RemoteTTSClient.swift       # OpenAI TTS API client
│   │
│   └── SparkStorage/                       # Core Data + Asset Cache
│       ├── Package.swift
│       └── Sources/SparkStorage/
│           ├── CoreDataStack.swift
│           ├── SparkModel.xcdatamodeld
│           ├── AssetCache.swift
│           └── OfflineSyncQueue.swift
│
└── Backend/                                # Node.js API (separate repo eventually)
    ├── package.json
    ├── src/
    │   ├── server.ts
    │   ├── routes/
    │   │   ├── auth.ts
    │   │   ├── lessons.ts
    │   │   ├── cards.ts
    │   │   ├── progress.ts
    │   │   ├── oauth.ts                   # OAuth callback handler
    │   │   └── webhooks.ts                # StoreKit server notifications
    │   ├── services/
    │   │   ├── scraper.ts                 # URL content extraction
    │   │   ├── llm/
    │   │   │   ├── provider-router.ts     # Routes to user's provider or proxy
    │   │   │   ├── openai-provider.ts
    │   │   │   └── proxy-provider.ts
    │   │   ├── card-generator.ts          # LLM → structured cards
    │   │   ├── tts-generator.ts
    │   │   ├── image-generator.ts
    │   │   └── asset-uploader.ts          # R2 upload
    │   ├── middleware/
    │   │   ├── auth.ts                    # JWT verification
    │   │   ├── rate-limit.ts
    │   │   └── entitlement.ts             # Subscription gating
    │   └── db/
    │       ├── schema.prisma
    │       └── migrations/
    └── Dockerfile
```

---

## 9. Data Model

```sql
-- Users & auth
users (
    id UUID PK,
    apple_id TEXT UNIQUE,
    email TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ
)

child_profiles (
    id UUID PK,
    user_id UUID FK → users,
    name TEXT,
    birth_date DATE,
    avatar_url TEXT,
    current_stage INT DEFAULT 1,
    created_at TIMESTAMPTZ
)

-- Subscriptions & providers
subscriptions (
    id UUID PK,
    user_id UUID FK → users,
    plan TEXT, -- 'free' | 'pro' | 'byok'
    storekit_transaction_id TEXT,
    status TEXT, -- 'active' | 'expired' | 'cancelled'
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ
)

llm_providers (
    id UUID PK,
    user_id UUID FK → users,
    provider TEXT, -- 'openai' | future providers
    access_token_encrypted BYTEA,
    refresh_token_encrypted BYTEA,
    token_expires_at TIMESTAMPTZ,
    status TEXT, -- 'active' | 'expired' | 'revoked'
    connected_at TIMESTAMPTZ
)

-- Curriculum & content
learning_paths (
    id UUID PK,
    user_id UUID FK → users,
    title TEXT,
    description TEXT,
    color TEXT,
    icon TEXT,
    sort_order INT,
    stage INT,
    is_premium BOOLEAN DEFAULT false
)

lessons (
    id UUID PK,
    path_id UUID FK → learning_paths,
    user_id UUID FK → users,
    title TEXT,
    description TEXT,
    thumbnail_url TEXT,
    difficulty INT,
    source_url TEXT,
    ai_analysis JSONB,
    status TEXT, -- 'draft' | 'generating' | 'review' | 'published'
    sort_order INT,
    created_at TIMESTAMPTZ,
    published_at TIMESTAMPTZ
)

cards (
    id UUID PK,
    lesson_id UUID FK → lessons,
    type TEXT, -- 'story' | 'concept' | 'experiment' | 'quiz' | 'voice' | 'video'
    sort_order INT,
    content JSONB,       -- type-specific structured content
    voice_script TEXT,
    image_url TEXT,
    audio_url TEXT,
    interaction_config JSONB -- for experiment/quiz cards
)

-- Progress tracking
learning_sessions (
    id UUID PK,
    child_id UUID FK → child_profiles,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    device_id TEXT
)

card_interactions (
    id UUID PK,
    session_id UUID FK → learning_sessions,
    card_id UUID FK → cards,
    action TEXT, -- 'viewed' | 'completed' | 'skipped' | 'voice_input' | 'experiment_attempt'
    duration_ms INT,
    voice_transcript TEXT,
    result JSONB, -- correct/incorrect, choices made, etc.
    timestamp TIMESTAMPTZ
)

badges (
    id UUID PK,
    title TEXT,
    description TEXT,
    icon TEXT,
    criteria JSONB -- e.g., {"type": "lessons_completed", "count": 5}
)

earned_badges (
    id UUID PK,
    child_id UUID FK → child_profiles,
    badge_id UUID FK → badges,
    earned_at TIMESTAMPTZ
)

-- Content pipeline
url_ingests (
    id UUID PK,
    user_id UUID FK → users,
    url TEXT,
    raw_content TEXT,
    ai_analysis JSONB,
    status TEXT, -- 'scraped' | 'analyzed' | 'cards_generated' | 'failed'
    created_at TIMESTAMPTZ
)

asset_jobs (
    id UUID PK,
    lesson_id UUID FK → lessons,
    type TEXT, -- 'tts' | 'image' | 'video_thumbnail'
    input JSONB,
    output_url TEXT,
    status TEXT, -- 'queued' | 'processing' | 'completed' | 'failed'
    created_at TIMESTAMPTZ
)
```

---

## 10. Phased Roadmap

### Phase 1: Foundation (Weeks 1–3) — "Sparky Says Hello"

**Goal:** Both apps scaffolded, one hand-crafted lesson playable on iPad.

| Week | Deliverable |
|------|------------|
| **1** | Monorepo + Swift packages scaffolded. SparkKids: tab nav shell. SparkCompanion: tab nav shell. Backend: Fastify + Prisma + PostgreSQL, basic CRUD endpoints. Shared models defined in SparkCore. |
| **2** | SparkKids: Pinterest grid home + flipbook view with Story + Concept cards. Hardcoded sample lesson "What is a Computer?" Swipe gestures + basic page-flip animation. SparkCompanion: Dashboard with lesson list, stub screens for other tabs. |
| **3** | SparkVoice: AVSpeechSynthesizer narration on cards. Tap-Sparky-to-hear. SparkAuth: Apple Sign In flow in both apps. Backend auth (JWT). Basic sync: companion publishes → kids app fetches on launch. |

**Milestone:** Your son swipes through a 5-card lesson on his iPad with voice narration. You see it in the companion app on your phone.

---

### Phase 2: AI Pipeline + OAuth (Weeks 4–6) — "Feed the Machine"

**Goal:** Paste URL → AI lesson draft → edit → publish. OpenAI OAuth working.

| Week | Deliverable |
|------|------------|
| **4** | OpenAI OAuth flow in Companion app (ASWebAuthenticationSession). Backend OAuth callback + encrypted token storage. Provider router (BYOK vs proxy). LLM provider settings screen. |
| **5** | URL scraping service (Readability + Puppeteer). AI content analysis + card generation via provider router. URLIntakeView in Companion: paste → loading → AI draft → "Generate Lesson." |
| **6** | Card editor in Companion (iPhone: vertical stack, iPad: side-by-side). Preview mode. Publish flow → sync to SparkKids. Asset pipeline: OpenAI TTS for narration audio, DALL-E for illustrations, R2 upload. |

**Milestone:** You paste a URL about "How robots learn" on your iPhone → AI generates 6 cards → you edit and publish → your son sees it on his iPad with AI-generated illustrations and voice narration.

---

### Phase 3: Interaction + Subscription (Weeks 7–9) — "Sparky Plays"

**Goal:** Interactive cards, voice chat, StoreKit subscription.

| Week | Deliverable |
|------|------------|
| **7** | Experiment cards in SparkKids: drag-and-drop engine, "teach the robot" interaction, haptic feedback. Quiz cards: multiple choice with tap. Card interaction types in generator prompt. |
| **8** | Progress tracking: learning sessions, card interactions, badge system, trophy room. Dashboard progress view in Companion: completion timeline, time heatmap, voice logs. |
| **9** | Sparky voice chat (SparkKids): speech recognition → LLM → TTS response loop. Kid-safe guardrails. StoreKit 2 integration: subscription paywall, entitlement checks, server-side validation webhook. Free vs Pro vs BYOK tier gating. |

**Milestone:** Your son teaches Sparky what blue things are, earns a badge, and has a voice conversation. Subscription flow works end-to-end.

---

### Phase 4: Polish & App Store (Weeks 10–13) — "Ship It"

**Goal:** App Store ready. Complete Explorer curriculum. Polished UX.

| Week | Deliverable |
|------|------------|
| **10** | Learning paths in both apps. Curriculum manager in Companion. Prerequisite system. Pinterest home grid polished with path progress. |
| **11** | Offline mode: Core Data cache, asset pre-download, offline sync queue. Background app refresh. Graceful degradation when offline. |
| **12** | Polish sprint: animations, sound design, onboarding flows for both apps, error states, loading states, empty states. COPPA compliance audit. App Store screenshots + metadata. |
| **13** | TestFlight beta with family/friends. Bug fixes. App Store submission for both apps. Privacy nutrition labels. App Review preparation. |

**Milestone:** Both apps submitted to App Store with complete "Explorer" stage curriculum (8-10 lessons across 3 learning paths).

---

### Future Phases

| Phase | Focus | Timeline |
|-------|-------|----------|
| **5** | Multi-child profiles, family sharing, "Thinker" stage content | Months 4–5 |
| **6** | Additional LLM providers (Gemini, etc.), block coding integration | Months 5–6 |
| **7** | Community features: shareable learning paths, parent ratings | Months 7–8 |
| **8** | Marketplace: parents sell curated curriculum packs | Month 9+ |

---

## 11. Key Technical Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| AI generates inappropriate content for a 4-year-old | High | Parent review gate is mandatory; content safety pre-screen; no auto-publish ever |
| OpenAI changes OAuth scope or deprecates endpoints | Medium | Provider abstraction layer means swapping providers is a backend change, not an app update |
| Voice recognition unreliable for young children | Medium | Tap-to-talk (not always-on); fallback to tap interactions; Apple Speech framework improves with use |
| Content scraping fails on JS-heavy sites | Medium | Puppeteer fallback; manual paste option; YouTube transcript extraction; PDF upload |
| App Store rejection (COPPA, Kids category rules) | High | Design for Kids category from day 1; no third-party analytics; no ads; parental gate on all settings |
| Scope creep delays MVP | High | Phase 1 milestone is the forcing function — one working lesson in 3 weeks |
| StoreKit subscription edge cases | Medium | Server-side validation; handle grace periods, billing retry, family sharing |

---

## 12. COPPA & App Store Kids Category

Since this targets children under 13, both apps must comply with Apple's Kids category requirements:

- **No personal data collection** from the child without verifiable parental consent
- **No behavioral advertising** — ever, in either app
- **No third-party analytics SDKs** in SparkKids (Apple's built-in analytics only)
- **Voice data** processed locally via Apple Speech framework where possible; server-processed voice goes through parent's connected provider only
- **AI conversations** bounded to lesson topics with strict content filters and safety system prompts
- **Parental gate** on all settings, account management, and external links
- **Parent controls all content** — nothing appears in SparkKids without explicit publish action
- **Offline-first** design minimizes data transmission from the child's device
- **Age gate** in SparkKids — no free-text input in Explorer/Thinker stages
- **Privacy nutrition labels** must be accurate for both apps
- **No links out** of SparkKids to external websites or app stores

---

## 13. Success Metrics (MVP)

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Lessons completed per week | 3+ | card_interactions table |
| Average session length | 5–10 min | learning_sessions table |
| Cards requiring parent edit after AI generation | <30% | lesson edit tracking |
| URL-to-published lesson time | <15 min | url_ingests → lessons timestamps |
| Child re-opens SparkKids voluntarily | 4+ days/week | app launch events |
| Voice interactions per session | 2+ | card_interactions with voice |
| OAuth connection success rate | >95% | llm_providers status |
| Free → Pro conversion rate | >5% within 30 days | subscriptions table |
