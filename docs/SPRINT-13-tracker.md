# Sprint 13 — "Demo-Worthy" — Progress Tracker

**Sprint dates:** Apr 24 – May 8, 2026
**Goal:** Lift the iPad app from "kid can run a lesson" (S12) to "kid will *want* to run another lesson" (S13). Two pillars: (1) make the *voice* — the primary UX channel for kids who can't read fluently — sound human (OpenAI TTS, kid-pickable voice persona, persisted per child); (2) make the *content moments* land (comic-book panels on every card type, dopamine trophy/celebration loop, asset-pipeline retry surfaces in Oracle so bang can iterate fast). By end of Week 1 the kid who tested S12 should pick the iPad back up, hear a voice that sounds like a person not a robot, and earn his first trophy. By end of Week 2 we have content scale (≥6 lessons) plus a pre-TestFlight build (icon, splash, Info.plist) ready to ship.
**Velocity target:** 55 pts (mixed UX + iOS + backend; carry-in slips from S12 absorbed Week 1).
**Carry-in from S12:** S12-10 Run 2/3 lessons (Rainbow + Planet re-seed pending, ~3 pts), S12-11 touch-test write-up (2 pts), QA defect bin from S12-12 (2 pts).
**Demo path:** unchanged — Xcode-built Debug iPad on same wifi as Mac backend. The voice upgrade introduces a **backend TTS proxy** (`POST /api/v1/voice/tts`) so the iOS binary never carries `OPENAI_API_KEY` — the same auth token a kid already uses for /lessons covers /voice/tts. No infra change.

---

## Why this sprint exists (the framing)

S12 closed with the touch-test loop working: bang's kid completed Sky end-to-end, got the trophy, opened the Trophy room. But two qualitative observations from that session shaped this sprint:

1. **The voice is the friction.** Apple's `AVSpeechSynthesizer` — even on the highest-quality "narrator" voice — sounds like a robot reading a textbook to a 4-year-old. Kids who can't read fluently rely on the voice; if the voice doesn't engage them, the comic panels don't matter. **This is the single highest-leverage UX change available.** OpenAI TTS sounds like a human storyteller for ~$0.015 per 1k chars — at touch-test scale (≤ 30 lessons cached), the cost is rounding error. The technical lift is the architecture (proxy through backend, cache aggressively, kid-picks-once-and-forgets), not the API call.
2. **The asset-pipeline observability gap.** Oracle in S13 already has the Content Browser + per-lesson asset re-trigger button, but you can't *hear* the audio without flipping into the iPad. A Voice tab in Oracle that lets bang play any voice + any text + see latency-per-voice closes the loop: he iterates voice persona on the Mac, not by relaunching Xcode.

Everything in this sprint either lands the voice upgrade, retires asset-pipeline debt, or polishes the demo loop ahead of TestFlight.

---

## Epic breakdown

### VOX — Voice library upgrade (24 pts) ⭐ primary epic

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S13-05 | Backend TTS proxy endpoint (`POST /voice/tts`) | 4 | bang | ✅ | `voice.ts` — POST /tts + GET /voices + GET /stats + POST /cache/clear. SHA-256 cache key, 500-entry/50MB LRU, latency tracking, cost via existing `logUsage`. Run summary: `docs/sprint-runs/S13-05-09-voice-upgrade.md`. |
| S13-06 | iOS BackendTTSClient + VoiceManager rewire | 4 | bang | ✅ | `RemoteTTSClient` repurposed to backend-proxy (zero direct OpenAI). `VoiceManager.speak(text:voice:preferLocal:)` defaults to remote; deprecated `speak(text:preferRemote:)` shim for compat. Closure-typed token resolver — no NovaCore dep cycle. |
| S13-07 | VoicePreferenceStore (per-child persistence) | 3 | bang | ✅ | UserDefaults JSON keyed under `voicePreference.records.v1`. `resolvedChildId(_:)` mirrors `LessonCompletionStore` exactly. Allow-list against `nova/fable/onyx/shimmer`. |
| S13-08 | VoicePickerView (4 character cards) | 5 | bang | ✅ | Nova / Pip / Boom / Sunny in 2×2 LazyVGrid. Tap plays sample → persists pick → highlights with gold ring. Reachable from HomeView toolbar (speaker.wave.2.bubble.fill). Reduce-motion path collapses pulse to instant fade. |
| S13-09 | Wire all 7 `voiceManager.speak()` call sites | 2 | bang | ✅ | All 7 sites flipped (Flipbook VM, Dashy VM, StoryCard, ConceptCard, VoiceCard ×3). Dashy hard-pinned to `shimmer`. Zero `preferRemote: false` left. |
| S13-10 | Dev Console "Voice" tab — playback + latency chart | 4 | bang | ✅ | Tab in `dev-pipeline.html#voice`. Free-text input + 4 voice playback rows, per-voice p50/p95 chart, cache state table, Clear Cache button. URL hash deep-link supported. |
| S13-11 | Persona-aware voice suggestion (stretch) | 2 | bang | ↪ S14 | Foundation: backend `/voice/voices` exposes `recommendedTopics` per persona. Full iOS-side "match the lesson" toggle deferred — kid demo doesn't block on it because the picker is the primary UX. |

### CON — Content scale + pipeline polish (12 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S13-01 | Oracle rebrand + per-lesson asset re-trigger | 3 | bang | ✅ | Landed `2226951`. Dev Console renamed Oracle in nav; per-lesson "regenerate assets" button surfaces in Content Browser. |
| S13-02 | Comic-book hero image on Story + Concept cards | 4 | bang | ✅ | Landed `d31c0ea` + `54b1e29` (pbxproj). `CardHeroImage` shared view; AsyncImage with gradient placeholder fallback. |
| S13-03 | Lesson completion → trophy + celebration loop | 5 | bang | ✅ | Landed `032d467` + `e0fcfdc` (signature fix) + `b3b25e8` (childId unify). LessonCompletionStore + LessonCompleteCelebration + TrophyRoomView trophies section. |
| S13-12 | Voice card + Quiz card hero images | 2 | bang | ⬜ | Carry the `CardHeroImage` pattern to the remaining 2 card types. |
| S13-13 | Curriculum-architect prompt: multi-question quiz | 1 | bang | ⬜ | Quiz lessons currently emit ≤1 question. One-line prompt tweak to emit 3-5 questions per quiz card. |

### CAR — S12 carry-in (5 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S13-14 | Re-seed Rainbow + Planet (S12-10 finish) | 3 | bang | ⬜ | Run via Author tab on Mac. Both expected ≤2 retry-ok. |
| S13-15 | S12-11 touch-test write-up | 2 | bang | ⬜ | Capture qualitative observations from kid's first session under `docs/sprint-runs/S12-11-touch-test.md`. |

### MVP — TestFlight pre-flight (10 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S13-20 | App icon + splash screen | 3 | bang | ⬜ | Per S12 out-of-scope deferral. Single 1024² icon, kid-friendly. |
| S13-21 | Info.plist marketing strings | 2 | bang | ⬜ | Display name, version, privacy strings (mic for Dashy STT, network for /voice/tts). |
| S13-22 | App Store screenshots (5 surfaces) | 3 | bang | ⬜ | Home, Lessons, Flipbook, Trophy room, Voice picker. iPad Pro 12.9". |
| S13-23 | Privacy policy + EULA + content rating | 2 | bang | ⬜ | Static markdown pages, served via `privacyRoutes` (already wired). |

### POL — Polish + QA (4 pts)

| ID | Title | Points | Owner | Status | Notes |
|---|---|---:|---|:---:|---|
| S13-30 | Parental gate + settings (deferred from S12) | 2 | bang | ⬜ | First-launch math gate; settings reachable only past it. |
| S13-31 | Sprint-close demo recording | 2 | bang | ⬜ | 90-second QuickTime walkthrough — voice picker, trophy unlock, kid-mode lesson flow. |

---

## Definition of Done

- [ ] **Voice is human:** kid taps any narration card on any lesson and hears OpenAI TTS, not AVSpeech. Apple voice survives only as the offline fallback.
- [ ] **Voice picker works for the kid:** kid taps a character on the picker, hears the sample, the choice persists across app launches per-child. No adult intervention to switch voices.
- [ ] **Backend proxy is the only path to OpenAI TTS from iOS:** zero `OPENAI_API_KEY` references in iOS source; `RemoteTTSClient` no longer points at `api.openai.com`; backend proxy serves all 4 voices end-to-end with auth + rate limit + cache.
- [ ] **Oracle Voice tab is the testing surface:** bang plays any voice with any text from his Mac, sees per-voice latency (p50/p95), and can re-trigger TTS for a specific lesson with a different voice without rebuilding the app.
- [ ] **Six lessons green:** Sky + Rainbow + Planet (S12 carry-in) plus three new seed lessons authored Week 2 — all with hero images on every card type, all with audio cached on the backend, all completable with trophy unlock.
- [ ] **Pre-TestFlight build assembled:** icon, splash, Info.plist marketing strings, screenshots, privacy policy, EULA. No actual TestFlight submission — that's the *next* sprint's first hour.
- [ ] **Oracle regression clean:** all S12 tabs (Pipeline / Skills / Strategy / Parent Guidance / Session Context / Author / Content Browser) still functional after the Voice tab landing.
- [ ] **All carry-in retired:** S12-10 Rainbow+Planet ✅, S12-11 touch-test write-up ✅.

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| VOX | 22 | 24 | 92% |
| CON | 12 | 15 | 80% |
| CAR | 0 | 5 | 0% |
| MVP | 0 | 10 | 0% |
| POL | 0 | 4 | 0% |
| **Sprint 13 Total** | **34** | **58** | **59%** |

> S13-11 (2 pts) deferred to S14 by design — no impact on kid demo readiness.
> Effective VOX completion is 22/22 of in-plan stories; 24/24 if S13-11 is
> counted as "scaffolded but not finished".

---

## Execution Plan (solo, 6 focused hrs/day)

**Week 1 — Voice ships (Day 1–4, ~24 pts):**
- Day 1: S13-05 (proxy endpoint, 4) + S13-06 (VoiceManager rewire, 4). VOX backend + iOS scaffolding. 8 pts.
- Day 2: S13-07 (VoicePreferenceStore, 3) + S13-08 (VoicePickerView, 5). VOX kid-facing UI. 8 pts.
- Day 3: S13-09 (call-site sweep, 2) + S13-10 (Oracle Voice tab, 4). VOX testing surface. 6 pts.
- Day 4: kid demo with new voice + S13-11 persona-aware voice (2, stretch). VOX epic closes Day 4 ideal-line.

**Week 1 checkpoint — end of Day 4:** kid hears human voice, picks his favorite, the choice sticks. If VOX isn't clean by Day 4 noon, **cut S13-11** and let persona-aware voice carry to S14.

**Week 2 — Content + pre-flight (Day 5–10, ~22 pts):**
- Day 5: S13-14 (Rainbow + Planet, 3) + S13-12 (voice/quiz hero, 2) + S13-13 (multi-q quiz, 1). 6 pts.
- Day 6: S13-15 (touch-test writeup, 2) + S13-30 (parental gate, 2) + 3 new seed lessons (animal/space/food categories). 4 pts + content.
- Day 7: S13-20 (icon + splash, 3) + S13-21 (Info.plist, 2). 5 pts.
- Day 8: S13-22 (screenshots, 3) + S13-23 (privacy/EULA, 2). 5 pts.
- Day 9: S13-31 (demo recording, 2). 2 pts.
- Day 10: buffer + sprint close.

**Contingency:** Week 2 absorbs Week 1 slip. Under no circumstance does VOX cut — the voice upgrade is the sprint goal. If Week 1 slips, MVP carries to S14.

---

## Dev Console / Oracle — what to test during the sprint

- **NEW — Voice tab** (S13-10) — primary new surface. Free-text input + 4 voice rows + per-voice latency bar + cache counter. "Regenerate audio for lesson X with voice Y" affordance triggers the asset pipeline against an existing card.
- **Pipeline tab** — regression-critical post-VOX. Confirm `voice` field flows through TTS asset job correctly.
- **Content Browser** (S12-10) — confirm per-lesson re-seed still works with new voice column.
- **Skills tab** — voice-persona skill still dry-runs; persona-aware suggestion (S13-11) surfaces in skill output if shipped.
- **Author tab** (S12-09) — new lessons created Week 2 should auto-pick a sensible default voice per topic.

---

## Out of Scope (explicit — prevents scope creep)

- **TestFlight submission** — pre-flight artifacts only this sprint. Submission is S14 hour 1.
- **Cloud asset storage** (R2 / S3 for cached audio) — sandbox local-FS storage continues. S14 work.
- **Multi-language voices** — English only; translation/localization is S15+.
- **Real-time voice (streaming)** — `tts-1` returns whole MP3, played from cache. Streaming TTS is S15+ if latency demands it.
- **Voice cloning / custom voices** — OpenAI's stock 6 voices are it.
- **Parent dashboard** — still S15+.
- **Lesson editing in iPad** — Oracle authoring stays the single edit surface.

---

## Risks & Mitigations

- **Risk:** OpenAI TTS latency on cold cache exceeds kid attention span. tts-1 typically returns in 1–3s for short text but can spike to 5s+ on rate-limit edges. **Mitigation:** S13-05 caches aggressively (hash key includes voice+model+text); the Author pipeline pre-generates audio for every voice card at lesson-create time, so kid-side hits are mostly cache hits. Voice picker samples are pre-generated once at app first-launch.
- **Risk:** Backend proxy becomes the rate-limit bottleneck. OpenAI API quota for tts-1 is generous but not infinite. **Mitigation:** in-memory LRU cache + per-user request budget logged via existing `logUsage` machinery; if a single user pegs the proxy, a `429` returns and iOS falls back to local AVSpeech for that session.
- **Risk:** OPENAI_API_KEY rotation breaks production. **Mitigation:** key lives in backend `.env` only; rotation is a one-place edit. iOS doesn't ship the key.
- **Risk:** Kid hates all 4 voices. **Mitigation:** unlikely with OpenAI's stock 6 — 4 cover the major personality archetypes. If kid bounces, S14 adds 2 more (alloy, echo) without code change.
- **Risk:** Voice picker UX confuses a 4-year-old. **Mitigation:** UI is character-card style (icon + name + sample-button), not a settings dropdown. Onboarding nudges them through it. Adult can lock a default in parental settings.
- **Risk:** Pre-cached audio bloats the database. Each MP3 is ~30–80KB; 6 lessons × 8 cards × 4 voices = 192 clips × 50KB = ~10MB. **Mitigation:** sandbox FS is fine for this scale; S14 cloud-storage migration handles real growth.

---

## Sprint 14+ preview

- **S14 — "Submit":** TestFlight submit. Cloud asset storage (R2 or S3). Supabase Auth + Postgres migration off SQLite. Trophy backend sync (currently UserDefaults-only). Multi-kid family UX polish.
- **S15 — "Discover":** Pinterest-style discovery layer matures (library, search, curated collections). Streaming TTS if S13 cold-cache hits prove a problem. Parent dashboard spike.
- **S16+ — "Scale":** Localization + multi-language voices. Voice cloning for custom characters. App Store launch.

---

*Tracker scaffolded April 24, 2026 mid-marathon. CON epic carried in already-shipped (commits `2226951` / `d31c0ea` / `032d467`); VOX epic is this run's focus, scaffolded together with the implementation. Stories fill in Delivery Notes sections below as they complete, following the SPRINT-10/11/12 idiom: Files changed / Architectural decisions / Validation / Prerequisites bang must run on his Mac.*

---

## Delivery Notes

### S13-01 / S13-02 / S13-03 — CON epic Apr 23 closure

Three coordinated Apr 23 commits closed the CON epic's UX-layer ahead of VOX:

**S13-01 — Oracle rebrand + per-lesson asset re-trigger** — `2226951`. Dev Console renamed Oracle in nav. Per-lesson "regenerate assets" button in the Content Browser triggers the asset pipeline against an existing lesson without re-seeding. Unblocks S13-10's Voice tab "regenerate audio for lesson X with voice Y" affordance.

**S13-02 — Comic-book hero image on Story + Concept cards** — `d31c0ea` (view) + `54b1e29` (pbxproj registration). New `CardHeroImage` shared view: AsyncImage of `card.imageURL` with a gradient placeholder fallback for cards without DALL-E assets. Story + Concept cards now read `card.imageURL` and full-bleed render the hero image — comic-book panel feel achieved. Voice + Quiz card carry forward as S13-12.

**S13-03 — Lesson-complete trophy + celebration loop** — `032d467` (feature) + `e0fcfdc` (NovaPalette signature fix) + `b3b25e8` (childId resolution unification). New: `LessonCompletionStore` (UserDefaults-backed @Published @MainActor ObservableObject), `LessonCompleteCelebration` (orchestrated TimelineView reveal at 0.0/0.2/0.4/0.7/1.0/1.3s with reduce-motion fallback), `TrophyRoomView` "Your Trophies" section. The childId resolution bug (FlipbookView wrote under fallback UUID; LessonsView read with nil → false short-circuit) is fixed by routing every read AND write through `resolvedChildId(_:)` so writes and reads always agree on the storage key.

**Files changed (CON closure totals, ~700 LOC):**
- `Apps/NovaKids/Sources/Views/Flipbook/CardHeroImage.swift` — new (~80 LOC)
- `Apps/NovaKids/Sources/Views/Flipbook/StoryCardView.swift` — wraps in CardHeroImage
- `Apps/NovaKids/Sources/Views/Flipbook/ConceptCardView.swift` — wraps in CardHeroImage
- `Apps/NovaKids/Sources/Services/LessonCompletionStore.swift` — new (~175 LOC)
- `Apps/NovaKids/Sources/Views/Flipbook/LessonCompleteCelebration.swift` — new (~260 LOC)
- `Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — finishLesson() + fullScreenCover overlay
- `Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` — Your Trophies section
- `Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` — completion checkmark badge
- `Apps/NovaKids/Sources/App/NovaKidsApp.swift` — `@StateObject completionStore` + injection
- `Nova.xcodeproj/project.pbxproj` — 3 new files registered (CA3D1EA022269… UUID series)

**Architectural decisions:**
1. **UserDefaults-first, backend-sync deferred to S14.** Kid demo cadence wants instant — no round-trip latency on the celebration. Cross-device sync (kid switches iPads) is real but not for this sprint. Shadow-write to `progress` endpoint is S14 work.
2. **Composite key `<childId>:<lessonId>` as record id.** SwiftUI ForEach happy; idempotent re-completion (replay) overwrites by id.
3. **`resolvedChildId(_:)` is the single source of truth.** Every read AND write goes through it. Eliminates the entire class of "trophy persisted but invisible" bugs.
4. **fullScreenCover, not inline overlay.** The dopamine moment is the focal interaction; nothing else on screen should compete.
5. **Reduce-motion collapses every reveal to instant fade.** Confetti is the carve-out per S11-16's discrete-event survival exception — particles fire even under reduce-motion because the visual cue *is* the celebration.

**In-plan vs drift:**
- In-plan: every CON bullet from sprint scaffolding.
- Drift (positive): childId resolution unification in `LessonCompletionStore`. Originally the fallback lived in `FlipbookView.finishLesson()`. Reads in `LessonsView`/`TrophyRoomView` short-circuited on `nil`. Moved into the store so every consumer agrees on the key. Pure win, no scope creep.
- Drift (deferred to S13-12): voice-card + quiz-card hero images. Pattern is shipped; carrying the modifier is a 2-pt follow-up not a defect.

**Validation (sandbox ✅):**
- File-by-file syntax check on every Swift file edited.
- LessonCompletionStore.swift compiles standalone (Foundation + Combine only).
- LessonCompleteCelebration.swift uses TimelineView pattern from S11-07 BadgeUnlockBurst — same shape, same reveal-stage discipline.

**Validation left for bang's Mac (🟡):**
```bash
cd ~/Projects/Novai/src
xcodebuild -workspace Nova.xcworkspace -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build
# expect: BUILD SUCCEEDED with all 3 new files registered
# Then: launch on iPad, complete Sky lesson, see celebration overlay,
#       confirm trophy on Trophy tab, replay Sky, confirm "Welcome back" beat.
```

### S13-05 / S13-06 / S13-07 / S13-08 / S13-09 / S13-10 — VOX epic Apr 24 closure

Six VOX-epic stories landing as one coordinated run — the kid-facing voice channel goes from robotic AVSpeech to OpenAI TTS, with a per-child picker and an Oracle Voice tab for testing/analysis from the Mac. **22 pts → ✅** (S13-11 deferred to S14 by design). Full write-up: `docs/sprint-runs/S13-05-09-voice-upgrade.md`.

**Files changed (~1,460 LOC across 10 files, 3 new + 7 edited):**

- `src/Backend/src/routes/voice.ts` — new (~340 LOC). POST `/tts` proxy + GET `/voices` + GET `/stats` + POST `/cache/clear`. SHA-256 hash cache, 500-entry / 50MB LRU, per-voice latency rolling window.
- `src/Backend/src/routes/index.ts` — +1 import + 1 register line.
- `src/Backend/public/dev-pipeline.html` — +210 LOC (Voice tab markup + JS module). Tab button, 4 voice rows, latency chart, cache table, clear button.
- `src/Packages/NovaVoice/.../RemoteTTSClient.swift` — repurposed from direct-OpenAI to backend-proxy (~190 LOC). Closure-typed `TokenResolver` (no NovaCore dep). New `TTSResult` carrying observability metadata.
- `src/Packages/NovaVoice/.../VoiceManager.swift` — rewritten (~220 LOC). New `speak(text:voice:preferLocal:)` defaults to remote; deprecated `speak(text:preferRemote:)` shim for compat. Two-level cache integration (iOS L1 + backend L2). `setVoice(_:)`, `preload(lines:)` helpers.
- `src/Apps/NovaKids/Sources/Services/VoicePreferenceStore.swift` — new (~155 LOC). Per-child voice persistence mirroring `LessonCompletionStore` pattern.
- `src/Apps/NovaKids/Sources/Views/Settings/VoicePickerView.swift` — new (~310 LOC). Kid-facing 2×2 grid of voice character cards with sample playback + selection persistence.
- `src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` — +30 LOC. RemoteTTSClient construction + voicePreferenceStore env injection + onChange bridges that hydrate VoiceManager.currentVoice from store on appear, child-switch, and store update.
- `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` — +30 LOC. Toolbar speaker-bubble icon → VoicePickerView sheet.
- 7 call-site edits (FlipbookViewModel, DashyViewModel, StoryCardView, ConceptCardView, VoiceCardView ×3) — flipped `preferRemote: false` → default remote. Dashy hard-pinned to `shimmer`.
- `Nova.xcodeproj/project.pbxproj` — +6 entries (UUID series `CA3D1EA02226951D31C0EA0{7..A}`).

**Architectural decisions (condensed — full version in run summary):**

1. **Backend proxy, not embedded `OPENAI_API_KEY` in iOS.** Defense-in-depth — IPA leak / strings / jailbreak don't expose the key.
2. **Remote-by-default, AVSpeech as fallback only.** S12's opt-in idiom was wrong-shaped for kid UX.
3. **Two-level caching: iOS L1 (per-process) + backend L2 (shared across users).** Picker samples cache after request 2.
4. **Per-child preference, not global.** Sibling switch → voice switch.
5. **Four voices, not six.** alloy/echo too close to nova for a 4-year-old. Backend allow-lists all 6 for S14 expansion.
6. **`tts-1`, not `tts-1-hd`.** -hd is 2× cost for marginal kid-perceptible quality lift. Oracle can manually drive -hd for A/B.
7. **Closure-typed token resolver, not protocol dep.** Keeps NovaVoice's package graph lean.
8. **Picker writes preference *before* it plays the sample.** Silence-not-loss as failure mode.
9. **Oracle Voice tab as the testing surface.** Iterate→hear loop drops from ~30s (Mac → iPad → ear) to ~2s (Mac → ear).
10. **Persona-aware voice deferred to S14.** Foundation in `/voice/voices.recommendedTopics`; iOS toggle is S14 work.

**Validation (sandbox ✅):**

- `npx tsc --noEmit` clean for `voice.ts` + `routes/index.ts` (51-error baseline held).
- All Swift files reviewed end-to-end against NovaPalette/NovaHaptics/SpeechSynthesizer/AuthManager APIs.
- All 7 `voiceManager.speak()` call sites swept — `grep "preferRemote: false"` returns zero.
- pbxproj registration verified file-by-file.

**Validation left for bang's Mac (🟡):** see S13-05-09 run summary for full curl + xcodebuild + iPad-on-LAN runbook. Critical demo path: pre-cache 4 picker samples + 3 lesson narrations via curl loop, then build to physical iPad with `NOVA_BACKEND_HOST=<mac-ip>:3000`, kid taps lesson → hears OpenAI voice (not robot).

**Cost shape:** Pre-caching the entire S13 catalog (6 lessons × 8 cards × 4 voices) at $0.015/1k chars costs $0.58 — less than a coffee. Live-traffic re-plays are free (cache hit).

**In-plan vs drift:**

- **In-plan:** every bullet of S13-05/06/07/08/09/10 from sprint scaffolding.
- **Drift (positive):** deprecated shim on `speak(text:preferRemote:)` keeps S12 callers compiling. Cache-clear button on Oracle Voice tab. HomeView toolbar entry.
- **Drift NOT absorbed:** S13-11 persona-aware voice → S14 (intentionally — kid demo doesn't block on it).

**Retired debt:**

1. Embedded API key threat retired — iOS no longer carries `OPENAI_API_KEY`.
2. Robotic-voice perception retired — kids hear human storyteller voices on every narration card.
3. Two-step `preferRemote: false` opt-in mistake retired — remote is the default; opt-out is the explicit path.
4. Per-voice latency invisibility retired — Oracle shows p50/p95 + cache hit rate without log-grepping.

---

## VOX touch-test follow-ups (Apr 24–25, kid-demo session)

Six issues surfaced live during the touch-test sequence on bang's Mac + iPad. Every one was either resolved with a one-line workaround in the moment or logged here for proper repair in the next sprint. Capturing them here so the kid demo path stays repeatable and the underlying contract drift gets retired structurally rather than per-incident.

### Resolved in-session (workarounds shipped, structural fix needed)

1. **ISO 8601 fractional-seconds decoder mismatch.** Prisma serializes `DateTime` with millisecond precision (`2026-04-24T02:26:24.746Z`). Swift's `JSONDecoder.DateDecodingStrategy.iso8601` is strict and rejects fractional seconds. Every `Lesson` and `LearningPath` decode failed at the first record; iPad fell back to mock content. Fixed in `APIClient.swift` with a custom date strategy that tries `ISO8601DateFormatter.withFractionalSeconds` first, falls back to plain ISO 8601, otherwise throws. Same wire-shape contract drift class as S12-12's UUID-lowercasing issue. **Structural fix: none needed** — the custom decoder handles both shapes. Drift retired.

2. **localhost-baked asset URLs.** Backend's dev-mode `assetUploader.ts:98` hardcodes `http://localhost:${PORT}/dev/assets/...` into the Card row at generation time. iPad's localhost is the iPad itself → AsyncImage silently fails on every comic-book panel. Worked around inside `CardHeroImage.swift` body — when a URL's host is `localhost`/`127.0.0.1`/`::1`, swap the scheme/host/port for `APIHost.baseURL()`'s components. Path/query/fragment preserved. **Structural fix: S14** — backend `PUBLIC_BASE_URL` env var (default `http://localhost:${PORT}` for solo-dev convenience) so URLs are correct at write time. Once shipped, iOS rewrite is deletable — but harmless to leave.

3. **`/lessons/:id/publish` requires non-empty JSON body.** Even though the route doesn't read a body, Fastify rejects POST with `Content-Type: application/json` + empty body with a 400 ("Body cannot be empty when content-type is set to 'application/json'"). bulk-publish curl invocation needed `-d '{}'` to satisfy validation. Worked around manually for 11 lessons. **Structural fix: S14** — add `validateBody(z.object({}).optional())` or a `bodyLimit: 0` opt-in on this route (and any other "no body" POST routes) so body validation doesn't block legitimate empty-payload calls.

4. **`devBypassLogin()` half-measure.** iOS `AuthManager.devBypassLogin()` sets `isAuthenticated = true` and a mock User in memory but never calls the backend and never writes a token to the keychain. Two consequences: (a) any stale token from a previous session is still in the keychain and gets sent on every API call → 401 → fetches throw → mock content stays; (b) developer can't reason about which userId iOS is talking to without grepping the dev-bypass middleware path on the backend. Worked around mid-demo by uninstalling the iPad app to clear the keychain. **Structural fix: S14** — `devBypassLogin()` actually hits `POST /api/v1/auth/dev-bypass` to mint a real JWT and stores it via `updateTokens(...)`. Production auth path becomes the same one used in dev. Eliminates the entire "stale keychain bites you" failure mode.

### Logged but not blocking

5. **Oracle Content Browser missing publish action.** Each lesson row has ↻ regenerate / ⇄ move / 🎨 assets / ✕ delete — no publish toggle. Lessons sit in `draft` indefinitely. iOS technically renders drafts, but the kid-app product semantic is "published is what kids see." Add a publish/unpublish toggle to each row + a bulk-publish-path action. Pairs naturally with the validateBody fix from #3 above.

6. **pbxproj hand-edits with `+` in filename break Xcode container loading.** Added `URL+RewriteLocalhost.swift` via direct pbxproj edits (4 entries — PBXBuildFile, PBXFileReference, group children, PBXSourcesBuildPhase). pbxproj passed visual inspection but Xcode reported "Failed to load container for document at url: file:///...Nova.xcodeproj" on next workspace open. Cause unconfirmed — the format permits `+` in paths and other Apple convention files use that pattern (`String+Extensions.swift`-style). Reverted the 4 entries; inlined the rewrite logic directly into `CardHeroImage.swift` (already in project) instead of as a standalone file. **Going forward — convention change:** raw pbxproj edits limited to renames + hardcoded UUID modifications only; **new files always go through Xcode's File → Add Files UI** so target membership and group placement are guaranteed correct. Logged here so future sprints don't re-litigate.

### Deferred to S14 (TestFlight prep gates)

- Backend `PUBLIC_BASE_URL` env var + asset uploader respects it (#2 structural fix).
- `devBypassLogin()` mints a real JWT (#4 structural fix).
- Empty-body POST validation exemptions (#3 structural fix).
- Oracle Content Browser publish/unpublish toggle (#5).

### Direct-from-demo retired debt

The mismatch class that *each* of these items represents — backend serializes one way, iOS decodes a stricter subset, mismatch silent until live data hits a real device on a real network — is the same class S12-12 retired with the global UUID-lowercasing preValidation hook. The structural answer pattern is consistent: surface the contract at one boundary (decoder, hook, env var) and validate it once. Each S14 fix lands in that shape.
