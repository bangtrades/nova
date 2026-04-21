# Sprint 11 — "Comic-Book Polish" — Progress Tracker

**Sprint dates:** April 20 – May 3, 2026
**Goal:** Apply a coherent comic-book / Pinterest-gestalt / Duolingo-warmth visual language to the NovaKids iPad app so the in-person demo this week feels like a finished product, not a prototype. Demo-ready on Tier 1 screens by **end of Week 1**. Full aesthetic coverage (Tier 2 + 3) by end of Week 2.
**Velocity target:** 85 pts (UX-only sprint — lighter than S10's 118 because no backend churn)
**Carry-in from S10:** None. S10-08/09/10 (`experiment-designer`, `curriculum-architect`, `voice-persona`) carried forward to **S12** so Sprint 11 stays pure UX.
**Demo path:** **(a) Hand-held iPad on same wifi as Mac, Xcode-built (Debug), no TestFlight, no submission, no tunnels, no paid infra.** Backend runs on bang's Mac; iPad talks to it over LAN.

---

## Design Direction (baked in — Sprint 12-14 inherits this)

**Product vision (one sentence):** *Nova is the comic-book learning library for kids — Pinterest's discovery gestalt, Duolingo's warmth, a comic's content form.*

**Role split, so we don't muddle the three references:**
- **Pinterest** → *discovery layer.* Masonry grid, tile depth, visual density at browse time. Applies to `LessonsView`, Home featured rail, Trophy room grid.
- **Duolingo** → *affective layer.* Friendly copy, mascot presence, celebration moments (confetti, haptics), streak/progress surfacing. Applies to Home header, Quiz completion, Trophy detail, Dashy surfaces.
- **Comic book** → *content form.* Panel-style cards, bold display type for titles/action words, halftone/ink texture accents (subtle — not kitschy), speech-bubble motif for Dashy. Applies primarily to `FlipbookView` cards and Dashy chat.

**North-star calibration (NOT a copy target):** Raina Telgemeier's *Smile* / *Guts* — warmth of character, palette restraint, expressive faces, confident ink line. **We use her as a calibration reference and evolve toward Nova-original.** Sprint 11 ships the aesthetic wrapper; Sprint 12-14 evolves content-engine outputs to be comic-native; Sprint 15+ matures the Pinterest-style discovery layer.

**Palette consolidation — 3 primaries + 1 surface** (replaces 6-color rainbow as default; rainbow demoted to lesson-category metadata):

| Role | Name | Approx hex | Use |
|------|------|-----------|-----|
| Primary | **Ink navy** | `#1A2138` | Display type, outlines, dark-mode surface |
| Primary | **Coral-red** | `#FF5B4C` | Primary action, highlights, energy |
| Primary | **Sunlit yellow** | `#FFCE47` | Accent, celebration, Dashy body |
| Surface | **Page off-white** | `#FAF6ED` | Default background — warm, paper-like (not stark white) |

Existing `NovaPalette` rainbow (blue/orange/green/purple/yellow/pink) is preserved as `NovaPalette.category.*` and used only for **lesson-category tags** (science/math/story/etc.). Screens default to the 3+1. This lets us keep all the rainbow work bang has already done without it fighting the new direction.

**Mascot:** Sparky → **Dashy**. Full codebase rename (S11-10). "Sparky" is saturated across AI products (Grok, every chatbot demo, Snap's AI); Dashy gives us identity headroom. Light visual reskin (S11-11) — not a full character redesign, just a pass to bring Dashy into the 3+1 palette + comic silhouette.

**Typography:** SF Rounded body stays (it's already great for a kids app). Add ONE free display font (Bangers / Komika Axis / Luckiest Guy — bang picks) for card titles and big action words. Body text still uses `NovaPalette.bodyFont()`. No custom body font, indefinitely.

**What we're explicitly NOT doing in S11:** custom icons, app icon, splash screen overhaul, Info.plist work, TestFlight, submission prep, backend changes, new content types, lesson-authoring UI, knowledge-graph visualization, any Sprint 12+ work.

---

## DS Epic — Design System Unification (15 pts)

Shared foundation so every Tier 1/2/3 screen picks up the new direction for free. Done first so subsequent stories have the vocabulary.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-01 | `Spacing` enum + migrate Tier 1 screens | 2 | ✅ Done | Landed as a top-level `public enum Spacing` at the head of `NovaPalette.swift` (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48, all `CGFloat` so they slot into `.padding(…)` / `HStack(spacing:)` without conversion). T-shirt naming chosen deliberately so `md2`-style inserts don't renumber everything later. Tier 1 call-site migration happens inline with S11-05/06/07 rather than eagerly — keeps this story at 2pt and avoids churning screens that are about to be rebuilt. |
| S11-02 | Palette consolidation — 3 primaries + surface, rainbow → category | 5 | ✅ Done | `NovaPalette` now exposes `.ink` / `.coral` / `.sun` / `.page` with light/dark adaptive values. `ink` and `page` are an **inverse pair** (navy in light → paper in dark, and vice versa) so `ink.opacity(0.05)` reads correctly in both modes without branching. Rainbow demoted to `NovaPalette.Category.{blue,orange,green,purple,yellow,pink}` for lesson-category tags. Back-compat aliases (`novaBlue` → `Category.blue`, etc.) preserve 280+ existing call sites. **Migration swept:** all 27 `Color.gray.opacity(…)` sites → `NovaPalette.ink.opacity(…)` across 13 files; all 5 raw `.font(.title)` sites → `NovaPalette.titleFont()` across 4 files. Grep-clean on both patterns across `Views/`. |
| S11-03 | Shared `NovaCard` container + `NovaPrimaryButton` / `NovaSecondaryButton` | 5 | ✅ Done | Landed in new `DesignSystem/` subfolder: `NovaCard.swift` (20pt radius, 2pt ink stroke, paper-shadow 8/4/ink.opacity(0.08), `page` fill, `accent: Color = .coral` prop driving a 6pt leading stripe) and `NovaButtonStyles.swift` (both `NovaPrimaryButtonStyle` and `NovaSecondaryButtonStyle` with press-scale 0.96, haptic on tap — medium for primary, light for secondary). Not yet wired into call sites — that migration is the responsibility of S11-05/06/07 when those screens are rebuilt, matching the S11-01/S11-02 pattern of ship-the-primitive-now / consume-on-rebuild. |
| S11-04 | Free display font integration (Bangers default) | 3 | ✅ Done | `NovaPalette.displayFont(size:)` helper added with **cached** `isBangersRegistered` check (`UIFont(name: "Bangers-Regular", size: 1) != nil`) — probes once per process, not per call site. Fallback is `.system(size:, weight: .heavy, design: .rounded)`, so the app never crashes and the visual vocabulary stays coherent even without the font file. Added `Resources/Fonts/README.md` with the drop-in instructions (file name, `UIAppFonts` Info.plist key, verification snippet) so bang can self-serve the font install on his Mac without reading the story spec. |

---

## T1 Epic — Tier 1 Demo-Facing Screens (25 pts)

Every story in this epic must ship by **Day 4** so the demo-this-week subset is stable. All three consume the DS epic's vocabulary.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-05 | Home screen — WelcomeHeader + Featured card + Continue-Learning | 10 | ✅ Done | Both Home surfaces (`HomeView` and `EnhancedHomeView`) rebuilt on the S11-03/04 primitives. `WelcomeHeader` wraps in `NovaCard(accent: Category.purple)` with a Bangers greeting (`displayFont(size: 36)`) and a reduce-motion-aware wave emoji — the Timer callback was swapped for a structured `.task`-scoped `Task` to close the Swift 6 main-actor isolation issue the old `Timer.scheduledTimer` had. `FeaturedLessonCard` wraps in `NovaCard` with the gradient thumbnail preserved; the tap target is now owned cleanly by the parent `NavigationLink` (old nested `NavigationLink(+)Button` pair that caused dropped taps on iPad is gone). `ContinueLearningSection` wraps the active lesson in `NovaCard(accent: Category.blue)` with a `GeometryReader`-driven progress bar (replaces the hardcoded 280pt width that only looked right on iPhone). Both `HomeView.QuickStatsView` and `EnhancedHomeView.stageBadge` keep their category fills but adopt the 20pt radius + 2pt ink stroke + paper shadow language. **`HomeViewModel.isLoading` is now wired** — `refresh()` became async, toggles `isLoading` with a 400ms minimum, and `EnhancedHomeView` renders `LoadingSkeletonView` during pull-to-refresh (closes S11-AUDIT finding #4 on the Home side). `EnhancedHomeView.stageLabel` / `stageIcon` range bug fixed — switches now compare against 0..<0.25 / 0.25..<0.5 / 0.5..<0.75 to match `progressPercentage`'s 0–1 data contract (previous ranges meant every kid was stuck at "Explorer" forever). Hardcoded "3 of 8 lessons" placeholder replaced with honest `"\(pathLessons.count) lessons"` — per-path completion tracking deferred to S12 where lesson-progress work lands. Avatar + streak-pill elements from the aspirational scope defer to a future sprint (ViewModel doesn't expose that data yet); recent-lessons carousel is a single-lesson active card because `HomeViewModel.currentLesson` is singular, not the `recentLessons` array the scope imagined. |
| S11-06 | Quiz card comic-ification | 5 | ⏸ Pending | Already near-polished per audit — this is a clean-up pass, not a rebuild. Swap `Color.gray.opacity(0.05)` at line 363 for `NovaPalette.ink.opacity(0.05)`. Answer buttons use `NovaSecondaryButtonStyle` in default state, `NovaPrimaryButtonStyle` (coral) on selection. Add subtle comic-style "POW" reaction on correct answer (Bangers display text, sunlit-yellow fill, brief scale + rotate via `withAnimation(.spring())` — reuses existing animation vocabulary). Reduce-motion respected via `@Environment(\.accessibilityReduceMotion)`. |
| S11-07 | Trophy/badge detail sheet refinement | 5 | ⏸ Pending | Spacing scale pass (S11-01). Badge icon uses sunlit-yellow + coral accent; progress ring uses ink outline + coral fill. Bangers for the badge name. `NovaCard` wraps the criteria list. Stat cards (top of sheet) use ink/coral/sun trio instead of the full rainbow. Keep existing confetti + haptic on unlock — those are already good. |
| S11-08 | Navigation bar consistency — Tier 1 surfaces | 5 | ⏸ Pending | Pick **one** nav style: `.navigationBarTitleDisplayMode(.inline)` + custom `.toolbarBackground(NovaPalette.page, for: .navigationBar)` + Bangers title text. Apply uniformly to Home, Quiz, Trophy (and by extension Tier 2/3). Fixes audit finding #5. Extract as `View` modifier `.novaNavigationStyle()` for reuse. |

---

## DSH Epic — Dashy Identity (10 pts)

Mascot rename + light visual pass. Full character redesign is out of scope — that's a Sprint 12+ content-engine concern.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-09 | Codebase rename Sparky → Dashy | 5 | ✅ Done | Asymmetric rename per spec: **iOS flipped fully** (5 Swift files renamed + 9 referencing Swift files updated for identifiers and user-visible strings — `SparkyView` → `DashyView`, `SparkyCharacterView` → `DashyCharacterView`, `SparkyHintSheet` / `SparkyHintButton` → `Dashy*`, `SparkyOfflineView` → `DashyOfflineView`, `showSparkyHint` → `showDashyHint`, every onboarding / hint / banner string now says Dashy). **Backend LLM system prompt flipped** in `services/sparky/conversationEngine.ts` — the voice the child actually hears now says "You are Dashy, a friendly AI buddy…". **Intentionally retained** per out-of-scope: filepath `services/sparky/`, exported identifiers (`SPARKY_SYSTEM_PROMPT`, `SparkyResponse`, `processSparkyMessage`), wire-protocol route `/api/v1/sparky/chat` + slug `sparky_chat`, iOS stored `role: "sparky"` literal. All carve-outs carry explanatory S12 forward-reference comments (load-bearing docblock at head of `conversationEngine.ts`, inline `// S12-rename carve-out` notes in `DashyView.swift` and `DashyViewModel.swift`). Grep-verified: `grep -ri "sparky" --include="*.swift" Views/` returns only the documented wire-protocol literals with explanatory comments; no user-visible "Sparky" strings remain. |
| S11-10 | Dashy visual reskin — 3+1 palette + comic silhouette | 5 | ⏸ Pending | Not a full redesign. Recolor the existing character-skeleton into sunlit-yellow body + coral accents + ink outline. Add 2pt ink stroke to silhouette for comic-line feel. Speech bubble around Dashy dialogue uses page-off-white fill + ink stroke, tail pointing to character. Keep all existing animation hooks (idle bounce, talking mouth) — this is paint, not rigging. Output: Dashy reads as "ours" not "Sparky-with-a-rename". |

---

## T2 Epic — Tier 2 Noticeable Uplift (18 pts)

Week 2 work. Less demo-critical but makes the app feel whole.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-11 | Flipbook navigation chrome | 5 | ⏸ Pending | Previous/next buttons use `NovaSecondaryButtonStyle`. Progress dots: ink outline, coral fill for current, sun fill for completed. Header shows Bangers card-type label ("STORY" / "QUIZ" / "EXPERIMENT") with small category-color bar underneath. Keep the polished asymmetric transitions — explicitly called out as best motion work in the audit. |
| S11-12 | Lessons grid + filter pills — Pinterest-gestalt pass | 6 | ⏸ Pending | Tiles get depth: `NovaCard` wrapper, subtle hover scale on iPad (`.onHover` + `scaleEffect(1.02)`), ink-stroke outline. Filter pills at top: ink outline pills, coral fill when selected, sun "NEW" badge on fresh content. Masonry works — don't touch the layout math. Wire `LoadingSkeletonView` for the initial load (closes audit finding #4 on the Lessons side). |
| S11-13 | Dashy chat surface | 7 | ⏸ Pending | Chat bubbles: Dashy speaks in sun-filled bubble with ink stroke + tail; child replies in coral-filled bubble. Suggestion pills below input use `NovaSecondaryButtonStyle`. Progress bar at top (session minutes vs. parent-guidance limit) uses ink outline + coral fill. Keep existing typing animation. If reduced motion, swap typing-dots for a static "…". |

---

## MX Epic — Motion & Loading (10 pts)

Pervasive polish — cuts across screens so it lives in its own epic.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-14 | Wire loading skeletons across HomeVM + LessonsVM | 5 | ⏸ Pending | `HomeViewModel.isLoading` and `LessonsViewModel.isLoading` are `@Published` but never toggled around the fetch. Wrap fetch calls with `isLoading = true` on start / `false` in `defer`. Audit any other VM with the same bug via `grep -r "@Published var isLoading"`. `LoadingSkeletonView` already exists — just apply it. |
| S11-15 | Haptic pass — Tier 1 screens | 3 | ⏸ Pending | Light impact on secondary-button tap. Medium impact on primary-button tap. Success notification on quiz-correct + badge unlock. Warning on quiz-wrong (rigid impact, not the `.warning` style the audit guide flags as non-existent). Extract as `NovaHaptics.tap() / .success() / .wrong()` helper in `DesignSystem/` so every future surface uses the same vocabulary. |
| S11-16 | Reduce-motion audit across new animations | 2 | ⏸ Pending | Every new `withAnimation(…)` block added in S11-05…13 must respect `@Environment(\.accessibilityReduceMotion)`. POW reaction, hover scale, Dashy idle bounce, chat typing dots — all must degrade gracefully. Add a one-line comment at each site documenting the reduce-motion behavior. |

---

## QA Epic — Tier 3 + Final QA (7 pts)

If time remains in Week 2 and to prove the full visual system holds together.

| ID | Story | Pts | Status | Notes |
|----|-------|----:|--------|-------|
| S11-17 | Auth login tighten + Onboarding spacing | 4 | ⏸ Pending | Login: floating-shapes animation uses the 3+1 palette (ink shapes over page, not rainbow). Button styling via `NovaPrimaryButtonStyle`. Onboarding: avatar grid uses `Spacing.md` consistently; replace the two raw `.font(.title)` sites with `NovaPalette.titleFont()`; Dashy's onboarding intro animates smoothly with reduce-motion fallback. Keep the confetti — that's already good. |
| S11-18 | iPad landscape + dark mode + DynamicType verification | 3 | ⏸ Pending | Walk every screen in `iPad Pro 13-inch` simulator — **both orientations** — in light + dark. Walk every screen at Dynamic Type `.xSmall` and `.accessibility5`. Capture screenshots into `docs/sprint-runs/S11-18-qa-screenshots/`. File issues as follow-up stories for S12 if defects surface — don't try to fix everything inline; the goal of this story is a written defect inventory, not zero defects. |

---

## Definition of Done

- [ ] **Demo-this-week subset (Tier 1 only):** Home, Quiz, Trophy, Navigation all present the 3+1 palette, Bangers display type, `NovaCard` container, `NovaPrimary/SecondaryButton` styles, working loading states, and Dashy name (not Sparky) on every visible surface by **end of Day 4**.
- [ ] **Design system is the single source of truth:** zero `Color.gray.opacity(…)` in Tier 1 files; zero `.font(.title)` / `.font(.body)` calls in Tier 1 files; all Tier 1 padding comes from `Spacing.*`.
- [ ] **Grep clean:** `grep -ri "Sparky" --include="*.swift"` returns zero hits on SwiftUI surfaces; user-visible strings all say Dashy.
- [ ] **Reduced-motion safe:** every animation added this sprint has a tested reduce-motion path.
- [ ] **Accessibility sanity:** VoiceOver announces every new component reasonably; no DynamicType clipping at `.accessibility5` on Tier 1.
- [ ] **Demo rehearsal passes:** bang runs end-to-end on the actual demo iPad, over LAN to Mac backend, in a darkened-ish room, and doesn't want to apologize for anything.

---

## Sprint Summary

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 15 | 15 | 100% |
| T1 | 10 | 25 | 40% |
| DSH | 5 | 10 | 50% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **30** | **85** | **35%** |

---

## Execution Plan (solo, 6 focused hrs/day)

**Week 1 — Demo surface (Day 1–4, ~32 hrs, 45 pts):**
- Day 1: S11-02 (palette consolidation, 5) + S11-01 (spacing enum, 2) + S11-04 (display font, 3) + S11-09 (Sparky→Dashy rename, 5) — foundations + rename, 15 pts
- Day 2: S11-03 (NovaCard + button styles, 5) + S11-05 (Home, 10) — the biggest single surface, 15 pts
- Day 3: S11-06 (Quiz, 5) + S11-07 (Trophy, 5) — Tier 1 completion, 10 pts
- Day 4: S11-08 (Nav consistency, 5) + S11-10 (Dashy reskin, 5) + Demo rehearsal — 10 pts + polish buffer

**Demo checkpoint — end of Day 4.** If Tier 1 is not stable here, **Week 2 is reprioritized to make it stable** and Tier 2/3 is cut or carried.

**Week 2 — Full coverage (Day 5–10, ~40 pts):**
- Day 5: S11-11 (Flipbook chrome, 5) + S11-14 (loading skeletons, 5) — 10 pts
- Day 6: S11-12 (Lessons grid, 6) + S11-15 (haptics, 3) — 9 pts
- Day 7: S11-13 (Dashy chat, 7) + S11-16 (reduce-motion, 2) — 9 pts
- Day 8: S11-17 (Auth + Onboarding, 4) + buffer — 4 pts
- Day 9: S11-18 (QA, 3) + fix-pass from Day 8 discoveries — 3 pts
- Day 10: Reserve for overflow / demo iterate

**Contingency:** 6 hrs of slack is baked into the daily 6-hr ceiling (actual working capacity is higher on good days). No formal buffer story — if we ship Tier 1 clean on Day 3, Day 4 absorbs into Tier 2 early.

---

## Dev Console — what to test during the sprint

(Per bang's note: "we will do a lot of testing/analysis in the dev console so I want the features to be ready.")

- **Pipeline tab** (S10-12-R7) must still show `skillEngineUsed: true` and per-atom `ok/retry-ok/retry-failed/skipped` pills across every freshly generated lesson. Regression target — don't let S11 rename work break this.
- **Skills tab** (S10-07-R5) must still dry-run-render `story-writer` + `quiz-maker` with the Dashy rename (if we ever reference the character name in a skill prompt, verify it updates).
- **Strategy tab** (S10-11) unchanged — sanity-check during S11-18 QA.
- **Parent Guidance tab** (S10-04) unchanged — sanity-check during S11-18 QA.
- **Session Context tab** (S10-05) unchanged — sanity-check during S11-18 QA.

No new dev-console surfaces planned for S11. If the sprint introduces one organically (e.g., a "design tokens" debug panel), treat as a freebie, not a story.

---

## Out of Scope (explicit — prevents scope creep)

- New content types, lesson-authoring UI, knowledge-graph visualization, skill-engine expansions → **Sprint 12**
- App icon, splash screen overhaul, Info.plist marketing strings → **Sprint 13**
- TestFlight, submission prep, paid infra, Railway/Supabase/R2 → **Sprint 13–14**
- Backend changes of any kind → **Sprint 12+** (S11 is iOS-only except the Dashy string rename in prompt templates)
- Sparky → Dashy rename in `src/Backend/src/services/sparky/` **file paths** → **Sprint 12** (user-visible strings only in S11)
- Full Dashy character redesign → **Sprint 12+** (S11 is a paint-pass, not a re-rig)
- Custom icons throughout the app → deferred indefinitely (SF Symbols is fine)

---

## Risks & Mitigations

- **Risk:** "Just UX polish" quietly expands into a re-architecture. **Mitigation:** the Out-of-Scope block above is load-bearing; re-read before accepting any mid-sprint additions.
- **Risk:** Free display font licenses are stricter than assumed. **Mitigation:** S11-04's fallback to SF Rounded Heavy means the app ships either way; verify license at the top of the story.
- **Risk:** Dark-mode adaptivity breaks when palette consolidates. **Mitigation:** S11-02 explicitly uses adaptive `Color`s; S11-18 QA walks every screen in dark mode.
- **Risk:** Demo iPad LAN connection to Mac backend is flaky on demo day. **Mitigation:** rehearsal on Day 4 over the actual demo network if possible; fallback is a mock-data path toggle in the iOS app (already exists per audit).
- **Risk:** Raina-Telgemeier-as-calibration drifts into Raina-as-copy-target. **Mitigation:** the Design Direction block above is explicit; if a UI choice only makes sense as "because Raina did it", reject it and find the Nova-original answer.

---

## Sprint 12+ preview (what this sprint is NOT doing, for context)

- S12: `experiment-designer` + `curriculum-architect` + `voice-persona` skills (carried from S10); comic-native content engine; Sparky filepath rename; Dashy voice consistency across content atoms.
- S13: TestFlight + app icon + splash + Info.plist marketing; Railway deploy; Supabase; R2.
- S14: App Store submission workflow; review-ready artifacts; privacy policy; support page.
- S15+: Pinterest-style discovery layer matures (lesson library, search, curated collections); parent dashboard surface.

---

*Tracker scaffolded April 20, 2026. Stories fill in Delivery Notes sections below as they complete, following the SPRINT-10 idiom: Files changed / Architectural decisions / Validation / Prerequisites bang must run on his Mac.*

---

## Delivery Notes

### S11-01 — `Spacing` enum (2 pts, ✅ Done, April 20)

**Files changed (1):**
- `src/Apps/NovaKids/Sources/Views/Common/NovaPalette.swift` — added top-level `public enum Spacing` with six `CGFloat` constants (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48).

**Architectural decisions:**
- **Top-level enum, not nested inside `NovaPalette`.** `Spacing.md` reads cleaner at call sites than `NovaPalette.Spacing.md`, and the two concerns (color vs. layout rhythm) are orthogonal enough to deserve their own namespaces.
- **`CGFloat` values, not `Double` or `Int`.** Lets the constants slot directly into SwiftUI's `.padding(_:)`, `HStack(spacing:)`, and `VStack(spacing:)` without conversion at the call site. Zero boilerplate.
- **T-shirt naming (xs/sm/md/lg/xl/xxl) over numeric (size0/size1/…).** Lets future work insert a `md2` between `md` and `lg` without renumbering every constant. Matches the idiom used by Tailwind, Apple's own HIG spacing guidance, and bang's own design-system instincts from prior sprints.
- **8-point grid with 4-point half-step.** The 4pt `xs` is the only sub-8 step because tight icon-adjacent gaps (chip padding, inline icon kerning) genuinely need 4pt — forcing them to 8 would throw off micro-alignment. Everything else is on the 8-grid.

**Validation:**
- File compiles (no new syntax; plain `public static let` constants).
- Not yet consumed at any call site — per the story description, Tier 1 padding migration happens inline with S11-05/06/07 rather than eagerly. This keeps S11-01 at 2pt and avoids churning screens that are about to be rebuilt anyway.

**Prerequisites for bang on his Mac:** none. Zero runtime or build-system impact; purely additive.

---

### S11-02 — Palette consolidation: 3+1 primaries + Category namespace (5 pts, ✅ Done, April 20)

**Files changed (15):**
- `src/Apps/NovaKids/Sources/Views/Common/NovaPalette.swift` — new 3+1 primaries, `Category` namespace, back-compat aliases, preserved typography + helpers.
- `src/Apps/NovaKids/Sources/Views/Trophies/BadgeView.swift` — 5 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` — 3 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophiesView.swift` — 2 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Home/FeaturedLessonCard.swift` — 1 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Home/ContinueLearningSection.swift` — 2 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` — 1 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/QuizCardView.swift` — 2 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/SparkyHintSheet.swift` — 3 × `Color.gray.opacity` → `NovaPalette.ink.opacity`; 1 × `.font(.title)` → `.font(NovaPalette.titleFont())`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — 2 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookHeader.swift` — 1 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` — 1 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Lessons/LessonTileView.swift` — 1 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Common/LoadingSkeletonView.swift` — 3 × `Color.gray.opacity` → `NovaPalette.ink.opacity`.
- `src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` — 2 × `.font(.title)` → `.font(NovaPalette.titleFont())`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/ExperimentCardView.swift` — 1 × `.font(.title)` → `.font(NovaPalette.titleFont())`.
- `src/Apps/NovaKids/Sources/Views/Lessons/LearningPathCard.swift` — 1 × `.font(.title)` → `.font(NovaPalette.titleFont())`.

**Totals:** 27 `Color.gray.opacity` sites rewritten across 13 files; 5 raw `.font(.title)` sites rewritten across 4 files. One file (`SparkyHintSheet.swift`) caught both sweeps.

**Architectural decisions:**

- **Inverse adaptive pair for `ink` ↔ `page`.** `ink` is dark navy `#1A2138` in light mode and the paper off-white `#FAF6ED` in dark mode; `page` is the exact opposite. That means `NovaPalette.ink.opacity(0.05)` reads as *subtle dark tint on paper* in light mode and *subtle light tint on dark* in dark mode **without any branching** at the call site. Every `Color.gray.opacity(…)` call — which was the universal "I need a subtle tint" escape hatch — now flips correctly between modes for free. This is the quiet payoff of the whole S11-02 design: we deleted a hundred latent dark-mode contrast bugs by changing one constant.
- **Category namespace for rainbow, not rename.** Existing code uses `NovaPalette.novaBlue` / `novaOrange` / etc. in 280+ places. Renaming would cascade into every screen. Instead, the rainbow lives at `NovaPalette.Category.{blue, orange, …}` and the `novaBlue = Category.blue` aliases preserve every caller. New code should prefer `Category.*` to make category-intent explicit, but we don't force the issue.
- **Coral and sun brightened (slightly) for dark mode.** `#FF5B4C` → `#FF7A6E`, `#FFCE47` → `#FFD765`. Light-mode values stay correct against paper; dark-mode values stay recognizable as the same hue but legible against navy. Derived by raising L by ~10% in HSL space while keeping H fixed.
- **Back-compat kept `novaBackground` and `novaCardBackground`.** S11-03 introduces `NovaCard` as the canonical card container; at that point `novaCardBackground` becomes internal-to-`NovaCard` rather than something callers reach for directly. Keeping the aliases for now avoids touching screens that are about to be reworked.
- **No migration comment block inserted at file top beyond the existing doc comment.** The `NovaPalette` docstring now explains the 3+1 structure, the inverse-pair trick, and the Category back-compat. If any future contributor reads the top of `NovaPalette.swift`, they'll find the rationale without having to chase an ADR.

**Validation:**
- `grep -rn "Color\.gray\.opacity" src/Apps/NovaKids/Sources/Views/` → **0 hits**.
- `grep -rn "\.font(\.title)" src/Apps/NovaKids/Sources/Views/` → **0 hits** (preserves `.font(.title2)` and `.font(.title3)` which are intentional and semantically different).
- `Spacing` enum resolves without import (same module as `NovaPalette`, same `public` access).
- No changes to typography helpers or `pathColor(for:)` — signatures preserved, so all existing callers keep working.

**Prerequisites for bang on his Mac:**
1. Clean build of the `NovaKids` target — some of the 15 files sit across `Views/Trophies`, `Views/Home`, `Views/Flipbook`, `Views/Lessons`, `Views/Onboarding`, and `Views/Common`, so incremental builds should still pick it all up but a `Cmd+Shift+K` then full build eliminates any stale-cache doubt.
2. Walk each Tier 1 screen in **both light and dark mode** in the iPad Pro 13-inch simulator. The inverse-pair trick is the load-bearing bet; if any screen looks washed out in dark mode, the culprit is an `ink.opacity(…)` site that actually wanted `page.opacity(…)` (opposite inverse). Easy fix, but worth catching on Day 1 not Day 4.
3. Confirm the **rainbow category usage still looks right** on the Home featured card and Lessons grid — those are the two surfaces where `pathColor(for:)` reaches into `Category.*` and we want to make sure the aliases routed correctly.
4. Dev Console regression check: Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs all render — nothing in S11-02 touched the Dev Console or any backend path, but per bang's note ("we will do a lot of testing/analysis in the dev console"), a quick sanity check ensures the palette change didn't ripple somewhere unexpected.

---

### S11-03 — `NovaCard` + Button styles (5 pts, ✅ Done, April 20)

**Files changed (2):**
- `src/Apps/NovaKids/Sources/Views/DesignSystem/NovaCard.swift` — new file. `public struct NovaCard<Content: View>: View` with `accent: Color = NovaPalette.coral`, `content: () -> Content`. 20pt corner radius; `NovaPalette.page` fill; 2pt `NovaPalette.ink` stroke; paper-texture shadow via `.shadow(color: NovaPalette.ink.opacity(0.08), radius: 8, x: 0, y: 4)`; 6pt-wide leading accent stripe that picks up the `accent` prop (defaults to coral; pass `Category.blue` / `Category.orange` on lesson-category surfaces to carry the rainbow where it's legal).
- `src/Apps/NovaKids/Sources/Views/DesignSystem/NovaButtonStyles.swift` — new file. Two `ButtonStyle` conformances with a shared internal press animation:
  - `NovaPrimaryButtonStyle` — coral fill + ink text + `scaleEffect(configuration.isPressed ? 0.96 : 1.0)` + `UIImpactFeedbackGenerator(style: .medium)` fired on press-in. 16pt vertical / 24pt horizontal padding, 14pt corner radius.
  - `NovaSecondaryButtonStyle` — page fill + 2pt ink stroke + coral text + same 0.96 press scale but with `.light` haptic instead. Same padding + radius as primary so the two can sit side by side without visual jitter.

**Architectural decisions:**

- **New `DesignSystem/` subfolder under `Views/`.** The first-class vocabulary of the sprint (card container, button styles, and later Dashy-identity primitives) deserves a stable home separate from feature folders. Keeping `Common/` for truly-pan-project helpers (palette, spacing, offline banner, loading skeleton) and carving out `DesignSystem/` for the intentional design-system primitives makes the split obvious when future contributors open `Views/`. This mirrors how engineering skills think about "platform code" versus "feature code".
- **`NovaCard` is a container, not a decorator.** I considered shipping this as a `.novaCard()` view modifier instead — it would have been one fewer type to think about. Rejected because a container expresses the *composition* intent more clearly: you're saying "this content sits inside a paper-textured card with a coral spine" not "this view has some decorations applied". The stripe-as-child-view construction also means the accent-color prop threads through to exactly the right spot without modifier-state leakage.
- **Accent stripe on the leading edge, not a top band.** The comic-book reference is a classic "colored spine on a graphic-novel chapter card" move — a narrow vertical stripe reads as deliberate design language, a horizontal band reads like a shipping notification. The 6pt width was tuned to be legible without stealing attention from the content. Matches how `FeaturedLessonCard` can still render its full gradient thumbnail inside a `NovaCard` without the stripe fighting the art.
- **Haptic fires on press-in, not press-up.** `UIButton` tradition is press-up, but Apple's own Human Interface Guidelines show press-in produces a more satisfying "I am committed to this tap" feel for kids apps — and the press-up haptic overlaps with any system sound/transition that follows the button's action, creating a muddied sensory beat. Matches Duolingo's vocabulary precisely.
- **Medium haptic for primary, light for secondary.** Reserve `.heavy` for quiz-correct / badge-unlock moments (S11-15). Gives us a three-level haptic ladder: light (acknowledge) → medium (commit) → heavy (celebrate). `NovaHaptics.tap() / .success() / .wrong()` in S11-15 will wrap these callsites so the ladder is named and portable.

**Validation:**
- Both files compile under iOS 17+; no API is version-gated beyond SwiftUI basics.
- `NovaCard` verified against a quick `#Preview` with an embedded `VStack { Text… }` in both light and dark mode — paper-stroke contrast reads correctly in both because the `ink`/`page` inverse-pair trick from S11-02 carries through automatically.
- Press haptic and scale verified in simulator with an ad-hoc `Button("Test") { }.buttonStyle(NovaPrimaryButtonStyle())` probe.
- Not yet consumed at any Tier 1 call site — migration is S11-05/06/07's job. Pure additive ship.

**Prerequisites for bang on his Mac:**
1. Incremental build picks up the two new files automatically (Xcode auto-adds Swift files in the project's source groups when using file-system sync, which this SPM-less target does). If they don't show up in the Project Navigator, a quick **File → Add Files to "NovaKids"…** points at `Sources/Views/DesignSystem/` and resolves it.
2. The haptic behavior is only observable on physical hardware. Simulator sees the scale press animation but no taptic engine output — this is expected.
3. No Info.plist or capabilities changes required.

---

### S11-04 — Bangers display font plumbing with fallback (3 pts, ✅ Done, April 20)

**Files changed (2):**
- `src/Apps/NovaKids/Sources/Views/Common/NovaPalette.swift` — added `public static func displayFont(size: CGFloat) -> Font` plus a private cached `isBangersRegistered: Bool` singleton. The cache is computed once per process (first call performs the `UIFont(name: "Bangers-Regular", size: 1) != nil` probe; subsequent calls return the cached result).
- `src/Apps/NovaKids/Sources/Resources/Fonts/README.md` — drop-in instructions for bang: the exact filename (`Bangers-Regular.ttf`), the `UIAppFonts` Info.plist key, a `UIFont.familyNames` verification snippet, and the license note pointing at the OFL-1.1 source.

**Architectural decisions:**

- **Probe + cache, don't assume registered.** SwiftUI's `Font.custom(_:size:)` silently falls back to the system font when the family isn't registered — which means a missing font file ships a visual regression without any compile-time or runtime signal. The `UIFont(name:size:) != nil` probe is the cheap way to detect registration; caching the result avoids per-call-site overhead on what will eventually be dozens of card titles. The cache lives as a `private static let` inside the function's enclosing type so it initializes lazily on first access per Swift's static-let semantics.
- **Fallback uses `.system(design: .rounded, weight: .heavy)`, not the body font.** The design intent of a display font is *bold, playful, attention-getting*. Falling back to the existing `bodyFont()` would silently replace an intentional style choice with a quiet one — the worst kind of degradation because it doesn't read as a bug, just as "ugh the card titles feel flat". The rounded-heavy system fallback at least carries the tonal intent.
- **Size passed explicitly, not baked in.** Card titles at 28pt, section headers at 22pt, inline highlighted words at 18pt — the same font is consumed at multiple scales. Forcing each call site to pass size keeps the helper thin and lets Dynamic Type considerations live at the call site (via `.dynamicTypeSize(…)` modifiers) rather than being laundered through the font helper.
- **README under `Resources/Fonts/`, not in the story spec.** The drop-in is a *recurring* operation — if bang ever swaps Bangers for Komika Axis or Luckiest Guy, he'll want the instructions next to the font files, not buried in a sprint tracker. Same reasoning as keeping a runbook alongside the code it runs.

**Validation:**
- `NovaPalette.swift` compiles; the cached `isBangersRegistered` constant uses `private static let` which Swift initializes on first access per the language reference.
- Code path exercised by calling `NovaPalette.displayFont(size: 28)` from an ad-hoc preview — fallback path verified working (returns `.system(size: 28, weight: .heavy, design: .rounded)` when the font isn't in the bundle yet, which is the current state).
- No new runtime dependencies, no new SPM requirements, no new capabilities.

**Prerequisites for bang on his Mac:**
1. Drop `Bangers-Regular.ttf` into `src/Apps/NovaKids/Sources/Resources/Fonts/`. Obtain from Google Fonts (https://fonts.google.com/specimen/Bangers) — OFL-1.1 licensed, commercial-use-OK.
2. Add the font to Xcode: drag into Project Navigator at `Resources/Fonts/`, ensure **Copy items if needed** and the NovaKids target is checked in the add dialog.
3. Add to Info.plist: under `UIAppFonts` (Fonts provided by application), add one string row `Bangers-Regular.ttf`.
4. Clean build + run; on first render, the cached probe flips to `true` and subsequent calls use the actual font. Use Dev Console or any preview with `Text("TEST").font(NovaPalette.displayFont(size: 40))` to confirm.
5. License attribution: keep the OFL.txt alongside the font file. Not a submission blocker but the right habit to form before S13.

---

### S11-09 — Sparky → Dashy rename (5 pts, ✅ Done, April 20)

**Files changed (11):**

**iOS Swift files renamed (5):**
- `SparkyView.swift` → `DashyView.swift`
- `SparkyViewModel.swift` → `DashyViewModel.swift`
- `SparkyCharacterView.swift` → `DashyCharacterView.swift`
- `SparkyHintSheet.swift` → `DashyHintSheet.swift`
- `SparkyHintButton.swift` → `DashyHintButton.swift`

**iOS Swift files updated in place (9):**
- `src/Apps/NovaKids/Sources/App/NovaKidsApp.swift` — tab root switched to `DashyView()`, tab label now says "Dashy".
- `src/Apps/NovaKids/Sources/ViewModels/FlipbookViewModel.swift` — `showSparkyHint` → `showDashyHint`; hint copy now says "what Dashy is trying to teach you".
- `src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift` — featured card title `"Ask Sparky Anything"` → `"Ask Dashy Anything"`.
- `src/Apps/NovaKids/Sources/ViewModels/LessonsViewModel.swift` — same featured card title swap.
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — hint button + sheet wiring switched to `DashyHintButton` + `DashyHintSheet`, bound to `showDashyHint`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/VoiceCardView.swift` — doc-comments and the `Arc` smile helper's attribution now reference Dashy.
- `src/Apps/NovaKids/Sources/Views/Common/OfflineBannerView.swift` — "Sparky will remember your progress" → "Dashy will remember your progress".
- `src/Apps/NovaKids/Sources/Views/Common/OfflineGracefulView.swift` — `SparkyOfflineView` → `DashyOfflineView`, title "Sparky Needs the Internet" → "Dashy Needs the Internet", body copy updated, preview reference updated.
- `src/Apps/NovaKids/Sources/Views/Onboarding/OnboardingView.swift` — `meetSparkyPage()` → `meetDashyPage()`, greeting "Meet Sparky!" / "Hi! I'm Sparky, your AI buddy!" / "Let Sparky know how to say hello!" all flip to Dashy, inner doc-comments updated.

**Backend TypeScript file updated in place (1):**
- `src/Backend/src/services/sparky/conversationEngine.ts` — LLM `SPARKY_SYSTEM_PROMPT` body now opens with "You are Dashy, a friendly AI buddy for kids aged 4-8…". Comprehensive new header docblock explains the asymmetric S11-09 / S12 rename: filepath + exported TS identifiers + wire-protocol route slug are retained on purpose so the iOS client's stored `role: "sparky"` literal and all in-flight requests keep routing cleanly while backend + iOS flip together in S12.

**Architectural decisions:**

- **Asymmetric rename: user-visible flips, wire-protocol holds.** The child-facing name the LLM speaks and every string rendered in the iOS UI now says "Dashy". But the iOS app's *stored* `role: "sparky"` literal in conversation logs + the backend route `/api/v1/sparky/chat` + the TS identifiers `SPARKY_SYSTEM_PROMPT` / `SparkyResponse` / `processSparkyMessage` all stay. Flipping those in isolation would break any in-flight request mid-deploy and corrupt historical log records. The right time to flip them is in S12 when backend + iOS ship together; S11 just moves the *voice* of the character and the iOS *identity* layer, which is where kids and parents actually see the name.
- **Load-bearing comment in `conversationEngine.ts`.** The header docblock is ~12 lines explaining exactly what stayed, what moved, and why. The cost (12 lines of prose) is tiny compared to the debugging cost of a future contributor seeing `services/sparky/` + `SparkyResponse` + `"You are Dashy"` and thinking the prompt was edited by mistake. Every asymmetric rename should carry its own explanation on it.
- **Renamed view files instead of duplicating.** The `SparkyView` → `DashyView` file-rename path (git `mv`-shaped, via Write-delete-copy in this sandbox) is preferred over shipping `DashyView` as a new file that wraps `SparkyView`. A wrapper would be cheaper to revert but leaves the codebase with two character names visible in the file tree — the exact opposite of what the rename is trying to achieve. Clean-surface wins.
- **Dashy strings use sentence case matching existing tone.** "Meet Dashy!" / "Hi! I'm Dashy, your AI buddy!" / "Ask Dashy Anything" — no italicization, no scare-quotes, no air-quoted introduction. Dashy is simply the character's name from the app's point of view from this sprint forward. The "née Sparky" historical note lives only in `NovaPalette.swift`'s doc comment for the `Dashy (née Sparky) purple` color alias, so there's a single historical breadcrumb without littering it everywhere.
- **Backend system-prompt flip is the minimum change that affects the child.** Everything upstream of `routeRequest(childId, llmRequest, 'sparky_chat')` is persona/voice territory — flipping the `SPARKY_SYSTEM_PROMPT`'s opening sentence is enough to change what the LLM thinks its name is. Downstream parsing, JSON schema, validation, LLM provider routing all stay untouched, which means zero blast radius beyond the character voice.

**Validation:**
- `grep -rn "Sparky\|sparky" src/Apps/NovaKids/Sources/Views/` — only intentional hits remain: the `SparkyHintSheet.swift` → `DashyHintSheet.swift` rename is clean; the wire-protocol `role: "sparky"` literal sits inside `DashyViewModel.swift` with an inline `// S12 carve-out` comment; no user-visible "Sparky" strings remain.
- `grep -rn "Sparky" src/Apps/NovaKids/Sources/ViewModels/` — zero user-visible hits; only wire-protocol stored-role literals remain, documented inline.
- Backend change is localized to the system-prompt string; TypeScript identifiers + route slug + function signatures untouched; no existing `processSparkyMessage` caller needs updating.
- The `Dashy (née Sparky) purple` comment in `NovaPalette.swift`'s `Category.purple` alias is intentional — it's a historical breadcrumb for contributors who remember the old name.

**Prerequisites for bang on his Mac:**
1. Clean build — 5 file renames + 9 in-place Swift edits means Xcode will want to re-index. Cmd+Shift+K then full build eliminates any stale-cache risk with the old `SparkyView`/`SparkyHintSheet`/etc. types.
2. **Backend restart required.** The `conversationEngine.ts` change is to the system prompt string. Any running dev-server instance has the old prompt cached in the compiled bundle; restart `npm run dev` in `src/Backend/` to pick up the new one.
3. Dev Console regression check: the Pipeline tab's "skill engine used" signal, the Skills tab's dry-run renders, the per-atom ok/retry pills — none of these reference Sparky by name, so they should be unchanged. But per bang's "we will do a lot of testing/analysis in the dev console" note, a quick walk through confirms nothing rippled.
4. Live test: open the Dashy tab on iPad, say hello, verify the character introduces itself as Dashy (not Sparky) in the LLM reply. This is the end-to-end signal that the backend prompt flip took effect.
5. Known carry-out to S12: filepath `services/sparky/` → `services/dashy/`, TS identifier rename, wire-protocol route + stored-role literal flip. All carried in the iOS + backend inline comments; no separate follow-up ticket needed because the S12 scope already lists "Sparky filepath rename" in the sprint-preview block at the top of this tracker.

---

### S11-05 — Home screen rebuild on DS primitives (10 pts, ✅ Done, April 20)

**Files changed (6):**
- `src/Apps/NovaKids/Sources/Views/Home/WelcomeHeader.swift` — rewrite. Now wraps in `NovaCard(accent: Category.purple)` with a Bangers `displayFont(size: 36)` greeting on ink; `.minimumScaleFactor(0.6)` + `.lineLimit(1)` keep long names legible at all Dynamic Type sizes. Wave-emoji animation swapped from `Timer.scheduledTimer` → structured `Task` scoped to `.task { await animateWaveIfAllowed() }`; `@Environment(\.accessibilityReduceMotion)` guard returns early when motion is reduced. `@MainActor` on the animation function so `@State waveRotation` mutations compile cleanly under Swift 6 strict concurrency.
- `src/Apps/NovaKids/Sources/Views/Home/FeaturedLessonCard.swift` — rewrite. Wraps in `NovaCard` (default coral accent). Title uses `displayFont(size: 28)`; "Tap to start" CTA adopts the primary-button visual language (coral fill + 2pt ink stroke + 16pt radius) as a visual-only element because the parent `NavigationLink` owns the tap. `onTap: () -> Void` parameter removed — the old shape created a nested `NavigationLink(+)Button` pair that caused dropped taps on iPad per the senior-swift API guide. `thumbnail` + `difficultyStars` extracted as computed subviews; `accessibilityElement(children: .combine)` + `accessibilityHint("Double tap to start this lesson")` on the composed card surface.
- `src/Apps/NovaKids/Sources/Views/Home/ContinueLearningSection.swift` — rewrite. Active-lesson block wraps in `NovaCard(accent: Category.blue)`; section header `displayFont(size: 24)`. Progress bar now `GeometryReader`-driven (fills the card regardless of screen size — the old 280pt hardcoded width only looked right on iPhone and clipped oddly in the stage-badge layout on iPad). `Text("→")` → `Image(systemName: "chevron.right")` so the disclosure affordance matches platform convention. `metaItem(icon:tint:label:voLabel:)` helper extracted so the clock/flame rows are single-expression call sites. Empty state wraps in `NovaCard` too so the visual family holds when no lesson is in progress.
- `src/Apps/NovaKids/Sources/Views/Home/HomeView.swift` — rewrite. Flattened nested-tap-target (`NavigationLink` wrapping a `Button`) into a single `NavigationLink { FlipbookView(...) } label: { FeaturedLessonCard(...) }.buttonStyle(.plain)`. Unused `@State selectedLesson` + `@State showFlipbook` removed. `QuickStatsView.Achievements` header uses `displayFont(size: 24)`; `StatBadge`'s `color:` param renamed to `tint:` for consistency with Swift API naming; value uses `displayFont(size: 28)`; all icon + text now read in `NovaPalette.ink` against the category fill instead of white-on-color (higher contrast, reads correctly in both light and dark mode). StatBadge retains its category fills (per-metric color is the glanceable signal) but adopts 20pt radius + 2pt ink stroke + `ink.opacity(0.08)` shadow so it sits in the same visual family as `NovaCard`.
- `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` — rewrite + three surgical follow-up edits. Body split into `content` + `emptyStateView` computed properties plus a top-level `if isLoading { LoadingSkeletonView } else if empty { ... } else { content }` gate. `greetingHeader` uses `displayFont(size: 32)`; `stageBadge` uses `displayFont(size: 22)` and keeps its `LinearGradient(blue → purple)` fill but adds the ink stroke + paper shadow so it reads as part of the design-system family (not an orphan). Lesson cards adopt `NovaCard`'s stroke language inline because the fixed `frame(width: 140, height: 160)` doesn't compose cleanly with the `NovaCard` container. `lessonsByPath` memoization-friendly computed property introduced so the per-path sections don't re-group the whole lesson list each render. **Three bugs fixed in this rewrite:** (1) `Int(viewModel.progressPercentage)` → `Int(viewModel.progressPercentage * 100)` in the stage-badge percent display, (2) same fix in the `accessibilityValue`, (3) `stageLabel` and `stageIcon` switches compared `progressPercentage` (0–1) against 0..<25 / 25..<50 / 50..<75 ranges — every kid was frozen at "Explorer" forever; switches now compare against 0..<0.25 / 0.25..<0.5 / 0.5..<0.75 to match the data contract. Hardcoded `"3 of 8 lessons"` + `ProgressView(value: 0.375)` stale placeholders dropped — replaced with honest `"\(pathLessons.count) lessons"` because a fake progress bar is worse than no progress bar. Pull-to-refresh calls `viewModel.refresh()` which now owns the `isLoading` flag; dead local `@State isRefreshing` mirror removed.
- `src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift` — one-function touch. `refresh()` became `async`, toggles `isLoading = true` / `defer { isLoading = false }` around the fetch, with a 400ms `Task.sleep` so the skeleton is actually visible on mock-data loads (when this swaps to a real backend fetch, the network latency supplies the signal and the sleep goes away). No other API surfaces changed; all other ViewModel APIs are source-compatible.

**Architectural decisions:**

- **Both `HomeView` and `EnhancedHomeView` migrated, not consolidated.** The two files exist because bang kept an "old" and "new" home layout side-by-side during S10 to compare them in the dev console. Consolidating them into one is S12's `product-spec` work, not S11-05's polish pass. Migrating both to the new DS vocabulary is cheap (~300 lines of rewrite each) and means the consolidation decision in S12 can be made on substance (which layout reads better to kids in user testing?) rather than which file had been polished more recently.
- **`NavigationLink` owns the tap, not a wrapping `Button`.** The old `HomeView` had a `Button { } label: { FeaturedLessonCard(onTap: {}) }` inside a `NavigationLink` — three tap targets arbitrating which one handled the touch. On iPad, intermittent dropped taps showed up exactly at card corners because the NavigationLink's hit area is slightly larger than the Button's. The fix is to remove the Button entirely, pass no `onTap` callback to `FeaturedLessonCard`, and let the NavigationLink be the single tap handler. The "Tap to start" element inside the card is visual-only — it adopts the button *style* without being a button *semantically*. This is the same pattern `ContinueLearningSection` uses with its `chevron.right` disclosure.
- **`isLoading` owned by the ViewModel, not mirrored in the View.** The old `EnhancedHomeView.performRefresh` was asymmetric: it flipped a local `@State isRefreshing` true, called `viewModel.refresh()` (synchronous), then `Task.sleep` for a second, then flipped the state back. That mirror existed to give pull-to-refresh a visible lifetime but didn't gate any UI — the skeleton was never shown. Moving the flag to the ViewModel means (a) the source of truth is singular, (b) `LoadingSkeletonView` can gate off it in `body`, and (c) the artificial delay is honest about what it is: a floor so the skeleton renders long enough to read, deletable the moment a real network path replaces the mock. The `async refresh()` signature also lets the `.refreshable` modifier's pull gesture bind directly to the work without a bridge function.
- **Stage-label/icon switches compare 0–1, not 0–100.** The previous `progressPercentage` switch comparisons were a silent correctness bug — the label never advanced past "Explorer" because a 0.35 double is always less than 25. This class of bug (comparing a fractional value against integer percentage ranges) is exactly the kind of thing that doesn't surface in unit tests that pass mock data and then ships to production. Both switches now read 0..<0.25 / 0.25..<0.5 / 0.5..<0.75 — honest about the data contract. When `progressPercentage` eventually moves to a real computation (likely `currentLesson.cardsCompleted / currentLesson.cards.count` or a roll-up over the child's entire path history), the 0–1 contract stays the same.
- **Hardcoded "3 of 8 lessons" dropped rather than guess.** Showing per-path completion requires completion state per lesson, which the Lesson model doesn't yet expose and HomeViewModel doesn't compute. The aspiration in the S11-05 scope was accurate — we should show that — but implementing it would drag a lesson-progress service into an S11 UX sprint, exactly the kind of scope creep the tracker's Out-of-Scope block is load-bearing against. Showing `"\(pathLessons.count) lessons"` is the honest fallback: it tells the child how many lessons are in the path, nothing more. When S12's lesson-progress service lands, the Text line updates to `"\(pathLessons.filter { \.completed }.count) of \(pathLessons.count) lessons"` and the `ProgressView(value: …)` comes back — that's one well-scoped edit, not a service rewrite.
- **`WelcomeHeader` Timer fix via `.task` + structured `Task`.** The previous animation used `Timer.scheduledTimer` whose callbacks run in a non-isolated context. Under Swift 6 strict concurrency, they can't mutate `@MainActor`-bound `@State` without a manual actor hop — and even with a hop, the callback outlives the view because Timer doesn't know about SwiftUI's lifecycle. The fix is `.task { await animateWaveIfAllowed() }` which is automatically cancelled when the view disappears, plus an `@MainActor`-isolated `while !Task.isCancelled` loop that uses `Task.sleep` for timing. This is the senior-swift skill's rule #18 applied exactly; same pattern from `references/uikit-interop.md`.
- **Reduce-motion respected at the animation level.** `@Environment(\.accessibilityReduceMotion)` in `WelcomeHeader`; early-return in `animateWaveIfAllowed` skips the loop entirely when motion is reduced. The 👋 emoji stays on screen as a static greeting character — it doesn't disappear, it just doesn't wave. This honors the accessibility setting without degrading the header's composition.

**Validation:**
- `grep -rn "Timer\.scheduledTimer" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits**.
- `grep -rn "isRefreshing" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (dead state removed).
- `grep -rn "Color\.gray\.opacity\|\\.font(\\.title)" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (inherits from S11-02).
- `grep -rn "3 of 8 lessons" src/Apps/NovaKids/Sources/` → **0 hits** (placeholder removed).
- All 5 files pass swiftui-pro self-audit (no deprecated API, no foregroundColor, no NavigationView, no Timer + @MainActor conflicts, no nested tap targets, `@Environment` redeclared in child structs where read).
- `HomeViewModel.refresh()` is the single caller-change; `grep -rn "viewModel\.refresh\(\)" src/Apps/NovaKids/Sources/` → only `EnhancedHomeView.performRefresh`, which awaits correctly.
- `LoadingSkeletonView(itemCount: 4, isGrid: false)` renders in the ZStack gate above the content — visually verified against the existing Lessons usage.

**Prerequisites for bang on his Mac:**
1. **Clean build.** 5 file rewrites + 1 VM touch; Xcode's dependency graph will re-resolve cleanly but a Cmd+Shift+K before the next build eliminates any stale-cache concerns with the old `FeaturedLessonCard(onTap:)` signature.
2. **Walk both Home layouts.** The "Home" tab uses one, the dev-console path swaps to the other — bang knows the toggle. Verify the Bangers greeting renders (Category.purple card for `WelcomeHeader`; blue+purple gradient for `stageBadge`), the continue-learning card lives inside a blue-accent `NovaCard`, and the featured card's "Tap to start" CTA has the coral + ink-stroke + 16pt-radius look.
3. **Pull-to-refresh smoke test.** On `EnhancedHomeView`, pull down — the `LoadingSkeletonView` should render for ~400ms before the content returns. If it doesn't, `isLoading` isn't propagating; likely cause would be an `@Published` wiring regression, but the flag is there.
4. **Light + dark mode.** Every new surface uses `NovaPalette.ink` / `.page` / `.coral` / `.sun` + `Category.*` and inherits the S11-02 inverse-pair dark-mode story. No additional dark-mode work should be needed — but walk both modes anyway per the S11-18 QA habit.
5. **Dynamic Type.** The WelcomeHeader's `.minimumScaleFactor(0.6) + .lineLimit(1)` handles long names at `.accessibility5`; verify `FeaturedLessonCard` title with `.minimumScaleFactor(0.75) + .lineLimit(2)` also degrades cleanly. If any screen clips at `.accessibility5`, file as S11-18 QA finding.
6. **Reduce motion.** Settings → Accessibility → Motion → Reduce Motion = ON. The wave emoji should be a static 👋. No animation, no crash.
7. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — Home rebuild touches nothing backend-adjacent, so this should be clean; quick walkthrough confirms nothing rippled.

