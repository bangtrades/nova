# Sprint 11 Reassessment — Demo & App Store Track

**Date:** April 19, 2026
**Informed by:** PHASE2-sprint-plan.md, ADR-001, iPad codebase audit, SPRINT-9 + SPRINT-10 trackers
**Trigger:** bang's pivot back to the iPad app with two stated goals — **demo this week, submit to App Store if possible**

---

## TL;DR

**Demo this week is realistic.** Submission this week is not. The app codebase is structurally ready but the packaging layer (icons, launch screen, privacy manifest, Info.plist, screenshots, App Store Connect listing) is entirely absent, and a kids' app faces extra review scrutiny that makes a one-week submission window a near-guaranteed rejection.

**Realistic window for submission: 2–3 weeks** if prioritized aggressively. That maps to Sprint 11 = demo-enable + submission-prep, Sprint 12 = submit + review-iterate.

**The single highest-leverage move is deploying the backend.** Everything else cascades from that — iOS integration, live LLM calls, TestFlight screenshots-from-real-data, end-to-end demo scenarios all unblock the moment the backend has a public URL.

---

## What we actually have vs what PHASE2 assumed

The PHASE2-sprint-plan.md critical path was: `S8 Deploy → S8 iOS integrate → S8 Sparky wire → S9 Pipeline → S10 Memory+Skills → S11 Viz+Subs → S12 TestFlight → S13 Submit`. That chain has drifted substantially from reality.

### ✅ Done, better than plan

- **Sprint 10 content engine (skill router, childContextBuilder, story-writer, quiz-maker, retry-on-Zod, Dev Console Pipeline tab)** — fully landed, 646/646 tests green, ahead of where the memory+skills epic was budgeted. The skill-engine architecture is more mature than the plan anticipated.
- **Grand Architect pipeline stages 1–6** — present in code under `src/Backend/src/services/` — unclear which are tested against real LLMs vs mocked, needs verification.
- **iOS SwiftUI surface area** — ~95 complete screens across NovaKids + NovaCompanion. All feature modules scaffolded (onboarding, age gate, flipbook with 9 card types, trophy room, dashboard, curriculum editor, weekly reports, StoreKit UI shells).
- **Shared Swift packages** — NovaCore (API client + router + cert pinning), NovaAuth (Sign in with Apple + OpenAI OAuth), NovaStorage (COPPA-aware encrypted persistence), NovaVoice (STT/TTS wrappers) — clean SPM architecture.
- **COPPA-aware patterns** — encrypted storage, parental gates, age gate, no third-party analytics visible, event logs flagged as PII.

### 🟡 Built in code but unverified / un-deployed

- **Backend Fastify server** — running locally on `:3000`, no staging or production deployment. Not on Railway/Render yet.
- **LLM connections** — API keys in `.env.example` but unknown whether Sparky Realtime, Claude, DALL-E 3, OpenAI TTS are wired and exercised end-to-end against real endpoints.
- **StoreKit 2 subscriptions** — UI present (`SubscriptionView`, entitlement gating in code) but no sandbox transactions tested.
- **BullMQ + Upstash job queue** (pipeline async exec) — unclear whether it's running.
- **Certificate pinning, rate limiting, safety filters** — present as Swift classes and backend middleware, unknown whether wired into the request path end-to-end.

### ❌ Not yet started

- **Backend deployment** — S8-01 through S8-08 entirely undone. No Railway app, no custom domain, no HTTPS cert, no CI/CD pipeline, no health monitoring.
- **iOS baseURL configuration** — hardcoded `http://localhost:3000/api/v1` at three call sites in `NovaKidsApp.swift` and `https://api.nova.local` (ghost URL) in `AuthViewModel.swift`. No `xcconfig`, no build-configuration split, no environment-aware config.
- **App icons** — no `.xcassets` directories exist in either NovaKids/Resources/ or NovaCompanion/Resources/. Literally zero icon work done.
- **Launch screen** — none.
- **PrivacyInfo.xcprivacy manifest** — none. Required by Apple since iOS 17 for all apps; required in more detail for apps in the Kids category.
- **Info.plist files** — missing entirely from both app targets. No usage descriptions (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSLocalNetworkUsageDescription`), no `UILaunchScreen`, no `UISupportedInterfaceOrientations`, no `CFBundleDisplayName`.
- **COPPA parental-consent email-verification flow** — mentioned in legal disclosures but no enforced flow (age gate is self-declaration; true COPPA consent for kids-category apps typically requires parent email confirmation or credit-card verification).
- **iOS tests** — zero XCTest or Swift Testing targets. 646 backend tests, 0 iOS tests.
- **TestFlight / fastlane / build automation** — none. No signing config visible in repo, no archive scripts.
- **App Store Connect listing** — not started. No screenshots, no preview video, no description, no keywords, no age-rating questionnaire, no privacy-nutrition-labels answered.
- **Seed lessons** — PHASE2 called for 24 pre-built lessons / 144 cards. Unknown whether any are actually seeded into a Postgres instance.

---

## Gap analysis — Demo vs Submission tracks

These two goals have very different completion criteria. Conflating them is the biggest risk to this week.

### Demo track — what "demo this week" requires

A demo needs: a device (iPad), a running app, content to show, and a believable story about the flow. It does NOT need: App Store metadata, icons the App Store will accept, privacy manifests, TestFlight. A demo can run over ngrok, can have placeholder icons, can skip purchase flows entirely, and can use pre-seeded lessons rather than live-generated ones.

Minimum viable demo path:

1. **Backend reachable from the iPad** — either Railway deploy (cleaner, ~half a day) or ngrok tunnel from your Mac (sketchier but ~10 minutes). For a demo to *external* people not in your local network, Railway is almost required; ngrok works for in-person on-network demos but breaks if the iPad is on cellular.
2. **iOS baseURL config** — introduce an `xcconfig` with `API_BASE_URL` so DEBUG points at dev, RELEASE points at prod. 2–3 hours of work, unblocks everything after it.
3. **Seed 3–5 compelling lessons** in the database with full assets (images generated + cached, TTS narration generated + cached) — this is the demo script. Better to have 3 perfect lessons than 24 rough ones.
4. **Smoke-test the end-to-end flow on real iPad** — "parent pastes URL → lesson generates → kid opens flipbook → answers quiz → talks to Sparky → earns badge". Catch the obvious failures (env vars missing, API auth broken, asset URLs not resolving).
5. **One backup plan per failure mode** — if Sparky lags, pre-record a Sparky response. If DALL-E fails live, have pre-generated images cached. If the pipeline times out, open a pre-generated lesson directly.

### Submission track — what App Store actually requires

This is the list you can't compress:

**Kids-category-specific requirements (all HARD blockers):**
- Parental gate for any outbound links, purchases, or contact-the-developer flows (you have a `ParentalGateView` — verify it wraps every regulated surface)
- No third-party analytics SDKs (you look clean here)
- No behavioral advertising, no targeted ads
- Age band declared (5–8 fits your content)
- Privacy nutrition labels answered honestly and comprehensively
- COPPA compliance checkbox — and the app must actually comply, not just claim to

**Standard iOS requirements:**
- App icon set (1024×1024 App Store icon + all app-launch icons, typically via `AppIcon.appiconset`)
- Launch screen (`LaunchScreen.storyboard` or `UILaunchScreen` Info.plist key with asset references)
- `PrivacyInfo.xcprivacy` declaring all Required Reason APIs used and any tracking
- `Info.plist` with every usage description for every permission requested, written in user-friendly language
- Screenshots: 5 per device size (12.9" iPad Pro + 11" iPad Pro minimum for iPad)
- 30-second App Preview video (optional but significantly improves conversion)
- App description (~4000 chars), keywords (100 chars), marketing URL, support URL, privacy policy URL
- Apple Developer account + signing config + provisioning profiles
- TestFlight internal beta with at least one successful crash-free install

**Review time:**
- Kids apps average 2–5 days in review (vs ~1 day for standard apps)
- First-submission rejection rate for kids apps is high — plan on at least one iteration
- Rejection-to-resubmission cycle: 1–3 days per iteration

**Honest estimate:** even if you work this aggressively, realistic submission lands in weeks 2–3, not week 1.

---

## Proposed Sprint 11 — "Demo + Submission Prep"

**Dates:** April 19 → May 3, 2026 (2 weeks)
**Goal:** Demoable by end of week 1. Submission-ready by end of week 2.
**Velocity target:** 85 pts (slightly above PHASE2 baseline given the parallel demo+prep tracks)

### Week 1 — Demo-enable (target Fri April 24)

The single critical path. Nothing else matters until these are done.

| ID | Story | Pts | Rationale |
|----|-------|-----|-----------|
| S11-01 | Deploy Fastify backend to Railway with env config | 8 | Unblocks everything. Use Railway over Render because their deployment UX is faster and they handle long-lived BullMQ workers well. |
| S11-02 | Migrate Prisma schema to Supabase Postgres + seed 5 demo lessons | 8 | Supabase because auth + Postgres + real-time in one vendor. Five lessons, not 24 — optimize for demo polish. |
| S11-03 | Cloudflare R2 bucket + signed URLs + upload pre-generated assets for demo lessons | 5 | Demo cannot tolerate live DALL-E latency. Pre-generate, cache, serve. |
| S11-04 | Introduce `xcconfig` for `API_BASE_URL` + refactor hardcoded localhost | 3 | Three call sites, ~1 hour. Makes the app switch environments by build scheme. |
| S11-05 | Wire Sparky to OpenAI Realtime with kid-safe system prompt | 8 | The magic moment of the demo. Pre-cache some canned responses as fallback if live latency spikes. |
| S11-06 | Content safety filter wired into LLM response path | 5 | Required for any live demo to an external audience — you can't risk an LLM hallucination offending a parent. |
| S11-07 | End-to-end smoke test: paste URL → lesson → iPad flipbook → quiz → Sparky | 5 | Run this on real iPad, not simulator. Find the dumb bugs (CORS, cert issues, auth token expiry) before the demo. |
| S11-08 | Demo script + backup plan per failure mode | 3 | Write the 5-minute demo narrative. Pre-record Sparky fallbacks. Have offline flipbook ready. |

**Week 1 total: 45 pts**

### Week 2 — Submission-prep (target Fri May 1)

Parallel tracks now that demo is stable. Split work between polish (icons/screens) and paperwork (App Store Connect).

| ID | Story | Pts | Rationale |
|----|-------|-----|-----------|
| S11-09 | Commission + integrate app icons for both apps | 5 | Either hire (Fiverr/99designs, 2-day turnaround, ~$200) or DIY in Figma. INK character from BRAND docs is a natural icon basis. |
| S11-10 | Launch screen with INK splash animation | 3 | Simple first pass — static image of Sparky on Novai background. Fancy animations can wait for v1.1. |
| S11-11 | `PrivacyInfo.xcprivacy` manifest for both apps | 3 | Enumerate every Required Reason API (`NSUserDefaults`, file timestamps, etc.), tracking domains (none), and data types collected. Apple's docs are prescriptive here. |
| S11-12 | `Info.plist` for both apps with usage descriptions, orientations, launch screen | 3 | Kid-friendly language in every `NS*UsageDescription`. Apple rejects for vague or scary permission copy in kids apps. |
| S11-13 | COPPA parental-consent email flow | 8 | This is the highest-risk submission item. Options: SendGrid + magic link, or Apple-style re-auth. Whichever you pick, document it in review notes. |
| S11-14 | StoreKit 2 sandbox purchase flow end-to-end | 5 | Create test users in App Store Connect, run through subscribe/renew/cancel/restore. |
| S11-15 | 5 screenshots per device size × 2 apps × 2 sizes = 20 images | 5 | Captured from real app on real iPad Pro. Composed with marketing text + feature callouts. |
| S11-16 | 30-second App Preview video | 5 | Screen-recorded flow + voiceover + music. Figma/CapCut. Aim for "parent pastes URL → kid learns" arc. |
| S11-17 | App Store Connect listing for both apps | 3 | Name, subtitle, description, keywords, categories, age-rating questionnaire, privacy labels, app review notes. |
| S11-18 | Internal TestFlight build + install on personal iPad | 5 | Archive → upload → wait for processing → install via TestFlight → crash-free launch verified. |

**Week 2 total: 45 pts**

**Sprint 11 total: 90 pts** (slightly over the 85 target — accept the stretch, keep S11-16 and S11-17 as cut candidates if week 2 gets tight)

### Sprint 11 scope cuts (in priority order if pressed)

If you need to cut: drop S11-16 (preview video) first — you can submit without it. Then S11-14 (StoreKit sandbox testing) — you can launch with subscriptions disabled / coming-soon and enable in v1.1. Do NOT cut S11-13 (COPPA consent) — that's a submission blocker for kids category.

---

## Sprint 12 — "Submit + Iterate on Review"

**Dates:** May 4 → May 17, 2026 (2 weeks)
**Goal:** App Store submission for both apps. Handle review feedback. Launch if approved.

Structure: 1 week external TestFlight (5–10 families, feedback loop) + 1 week submission + review iteration buffer. Planning this now because "submit if possible" is an explicit goal and it's better to have the map.

Key stories (budget ~55 pts): external TestFlight recruitment + consent collection (8), bug bash on TestFlight feedback (8), submission of both apps (3), rejection-response buffer (13), load test at 100 concurrent users (8), launch monitoring dashboard (5), post-launch hotfix buffer (10).

---

## Key risks

1. **Apple rejects on first submission** — high likelihood for a kids app. The top three rejection reasons for kids apps are: weak parental gate (our gate looks sound — verify it wraps every regulated surface), inadequate privacy disclosure (mitigation: S11-11 + S11-12 + honest privacy labels), and COPPA non-compliance (mitigation: S11-13). Plan on at least one round of rejection-response.

2. **Icon design is the unknown-unknown** — if you try to DIY icons in a day, they'll look DIY. If you commission, expect 2–5 day turnaround. Start that workstream on day 1, in parallel with backend deploy.

3. **Backend deployment drags past Friday** — if Railway gives trouble or Supabase migration hits a snag, the demo slips. Mitigation: have ngrok as Plan B for the demo, even if it means the audience has to be on your network.

4. **LLM costs blow up on first live demo** — PHASE2 estimates $0.12/lesson for DALL-E and $0.02/lesson for TTS. A demo that accidentally loops the pipeline could burn real money. Mitigation: set hard per-day spend caps in OpenAI dashboard before going live.

5. **COPPA consent flow is the hidden submission killer** — the gate you have today is self-declared age. Apple's review team specifically tests for "can a kid get past this by lying". S11-13 is non-negotiable.

6. **Sprint 10 skill-engine features untested against real LLMs** — all 646 tests pass but they mock the LLM calls. First live call may surface issues (prompt formatting, response parsing, retry logic under real latency). Allocate time in S11-05 to fix anything that breaks.

---

## Questions for bang

Before scaffolding the Sprint 11 tracker via sprint-runner, three decisions drive story prioritization:

1. **Icon workstream — DIY or commission?** DIY saves money but adds ~1.5 days of your time and risks amateurish output. Commissioning costs ~$200 and takes 2–5 days of wall time but zero of your time. Recommend commissioning — your hourly rate developing > designer rate and the critical path needs you on integration.

2. **Demo audience — who?** In-person with-you-in-the-room demo tolerates Plan B (ngrok, pre-cached content, manual recovery if something breaks). External "watch this screen recording I send you" demo requires near-production polish. Recommend clarifying before scoping Week 1 — the polish delta is meaningful.

3. **Submission-this-week stretch — take the shot or defer?** If you submit a rough build this week and get rejected, you get formative feedback but burn review-cycle time. If you wait until Sprint 11 is fully done, you submit once with higher approval odds. Recommend waiting — kids apps accumulate "strikes" in the reviewer's memory and a clean first pass is the best outcome.

---

## Checkpoints for the week

| When | Gate | Action if miss |
|------|------|----------------|
| Mon EOD | Railway backend responds to `/health` | Fall back to ngrok for demo continuity |
| Tue EOD | iOS app loads lessons from deployed API | Fix `xcconfig` / auth / CORS before anything else |
| Wed EOD | Sparky voice round-trip works end-to-end | Use pre-recorded fallback for demo if latency unfixable |
| Thu EOD | 5 demo lessons seeded + assets cached in R2 | Reduce to 3 lessons, polish those |
| Fri EOD | Full demo flow runs on real iPad, 3 times | Demo Friday / Monday morning with known-stable flow |

Week 2 checkpoints tracked in the Sprint 11 tracker once scaffolded.

---

*Sprint 11 tracker to be scaffolded via the sprint-runner skill after the three questions above are answered.*
