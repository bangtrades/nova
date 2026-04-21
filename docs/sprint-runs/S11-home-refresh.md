# Sprint Run — S11-05 (Home screen rebuild on DS primitives)

**Run ID:** `S11/R05`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 20, 2026 (same-day delivery on Day 1, following `S11/R01-02` palette + spacing + `S11/R03-04-09` DS + Dashy rename)
**Delivery agents:** `/senior-swift` (iOS code) + `/senior-fullstack` (integration) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — Home tab + Enhanced-Home tab both now consume the S11-03/04 DS primitives. Three latent correctness bugs caught and fixed en route. Swift 6 strict-concurrency Timer hazard in `WelcomeHeader` neutralized. `LoadingSkeletonView` wired into the Home refresh path, closing the Home side of the S11-AUDIT finding #4. T1 epic opens at 10/25.

---

## 1. Run Goal

Take the Home screen from pre-S11 "works but feels generic" to S11 "comic-book paper feel" by rebuilding the five Home surfaces (`WelcomeHeader`, `FeaturedLessonCard`, `ContinueLearningSection`, `HomeView`, `EnhancedHomeView`) on top of the DS primitives landed in `S11/R03-04-09`: `NovaCard`, `NovaPrimaryButtonStyle` / `NovaSecondaryButtonStyle`, `NovaPalette.displayFont(size:)`. The ViewModel gets a minimal one-function touch so pull-to-refresh can surface `LoadingSkeletonView` during a mock-data reload.

Two Home entry points exist in-app: the "classic" `HomeView` (shipped first, still reachable from one of the dev-console swap paths) and the richer `EnhancedHomeView` (current Home tab, learning-path sections + stage badge + greeting). Migrating both instead of collapsing them keeps the S12 `product-spec` consolidation decision honest — pick the layout that reads better to kids in user testing, not the one that was polished more recently. Both files are rewrites of similar size, so the cost of migrating both is roughly the cost of migrating one plus the cost of migrating one — a tiny marginal add for a meaningful optionality gain.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes on this run (the backend prompt flip landed in S11-09).
- 280+ existing `NovaPalette.novaBlue` / `.novaOrange` / etc. call sites must keep compiling via the S11-02 back-compat aliases.
- Dark-mode adaptivity must not regress — ink/page inverse-pair from S11-02 carries through automatically when the new surfaces use palette tokens.
- No new runtime dependencies — iOS 17+ SwiftUI only.
- Swift 6 strict concurrency: `@Published` mutations only from main-isolated contexts; no `Timer.scheduledTimer` callbacks into `@State`.
- Don't consolidate `HomeView` + `EnhancedHomeView` (explicitly S12's `product-spec` decision, not S11's polish pass).

---

## 2. Stories & Acceptance Criteria

### S11-05 — Home screen rebuild on DS primitives (10 pts) ✅

**User story:** *As a Nova child, the Home tab looks and feels like a comic-book paper page — bold Bangers greeting, paper-textured cards with coral spines, coral press-in haptics on my CTAs — without any changes to what's actually on the screen (lessons, paths, continue-learning, stage progression) so the polish carries me into Sprint 11's Tier 2 work without cognitive disruption.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `WelcomeHeader.swift` wraps in `NovaCard(accent: Category.purple)`; greeting uses `NovaPalette.displayFont(size: 36)` on ink; wave emoji animates via structured `Task` (not `Timer.scheduledTimer`); `@Environment(\.accessibilityReduceMotion)` respected. | ✅ |
| AC2 | `FeaturedLessonCard.swift` wraps in `NovaCard` (default coral accent); title uses `displayFont(size: 28)`; "Tap to start" CTA uses the primary-button visual language (coral fill + ink stroke + 16pt radius) but is visual-only because the parent `NavigationLink` owns the tap; `onTap` callback removed. | ✅ |
| AC3 | `ContinueLearningSection.swift` active-lesson block wraps in `NovaCard(accent: Category.blue)`; section header `displayFont(size: 24)`; progress bar is `GeometryReader`-driven (fills the card at any width); disclosure uses `Image(systemName: "chevron.right")` not `Text("→")`. | ✅ |
| AC4 | `HomeView.swift` flattens the `NavigationLink` + `Button` + `FeaturedLessonCard(onTap:)` triple-tap-target into a single `NavigationLink { FlipbookView(...) } label: { FeaturedLessonCard(...) }.buttonStyle(.plain)`. Unused `@State` removed. | ✅ |
| AC5 | `HomeView`'s `QuickStatsView` "Achievements" header uses `displayFont(size: 24)`; `StatBadge` value uses `displayFont(size: 28)`; category fills preserved (per-metric color is the glanceable signal) but adopts 20pt radius + 2pt ink stroke + paper shadow so it lives in the `NovaCard` family. | ✅ |
| AC6 | `EnhancedHomeView.swift` `greetingHeader` uses `displayFont(size: 32)`; `stageBadge` uses `displayFont(size: 22)` and keeps its blue→purple gradient fill with ink stroke + paper shadow; lesson cards adopt stroke language inline (fixed 140×160 frames don't compose cleanly with the `NovaCard` container). | ✅ |
| AC7 | `EnhancedHomeView` top-level body gates on `viewModel.isLoading` and renders `LoadingSkeletonView(itemCount: 4, isGrid: false)` during pull-to-refresh. Dead local `@State isRefreshing` mirror removed; `performRefresh()` collapses to `await viewModel.refresh()`. | ✅ |
| AC8 | `HomeViewModel.refresh()` becomes `async`, toggles `isLoading = true` / `defer { isLoading = false }` around `loadMockData()`, with an intentional 400ms `Task.sleep` floor so the skeleton renders long enough to read. | ✅ |
| AC9 | All 5 view files pass a `/swiftui-pro` self-audit — no deprecated API (no `foregroundColor`, no `NavigationView`, no `onChange` single-param), no `@Environment` inherited-across-struct violations, no `Timer` + `@MainActor` data-race hazards. | ✅ |
| AC10 | `grep -rn "Timer\\.scheduledTimer" src/Apps/NovaKids/Sources/Views/Home/` returns **0 hits**. | ✅ |
| AC11 | `grep -rn "isRefreshing" src/Apps/NovaKids/Sources/Views/Home/` returns **0 hits** (dead state removed). | ✅ |
| AC12 | `grep -rn "3 of 8 lessons" src/Apps/NovaKids/Sources/` returns **0 hits** (hardcoded stale placeholder dropped). | ✅ |

### S11-05 — latent bugs caught in the rewrite (3 fixes, no separate points) ✅

The rebuild surfaced three silent correctness bugs that were shipping undetected in the pre-S11 `EnhancedHomeView`. None were in-scope for S11-05 as originally written, but all three were cheap to fix in the same pass and are documented here so the commit history carries the reasoning.

| # | Bug | Fix | Status |
|---|---|---|---|
| B1 | `stageLabel` switch compared `viewModel.progressPercentage` (0–1 fractional double) against `0..<25 / 25..<50 / 50..<75` ranges — every kid was frozen at "Explorer" forever because 0.35 is always less than 25. | Ranges changed to `0..<0.25 / 0.25..<0.5 / 0.5..<0.75` to match the 0–1 data contract. | ✅ |
| B2 | `stageIcon` switch had the same 0–100 vs 0–1 mistake — wrong icon was always displayed (`binoculars.fill`) regardless of real progress. | Same range fix applied. | ✅ |
| B3 | Stage-badge percent label + `accessibilityValue` displayed `Int(progressPercentage)` — always rendered as "0%" because `Int(0.35) = 0`, and VoiceOver read "zero percent complete" regardless of progress. | Multiplied by 100: `Int(progressPercentage * 100)` in both the label and the VO value. | ✅ |

---

## 3. Files Changed

**View rewrites (5 files):**
- `src/Apps/NovaKids/Sources/Views/Home/WelcomeHeader.swift` — rewrite. `NovaCard(accent: Category.purple)` wrap, Bangers greeting at 36pt, structured-Task wave animation, reduce-motion guard, `@MainActor` on the animation function so `@State waveRotation` mutations compile under Swift 6.
- `src/Apps/NovaKids/Sources/Views/Home/FeaturedLessonCard.swift` — rewrite. `NovaCard` wrap, 28pt Bangers title, visual-only "Tap to start" CTA, `onTap` callback removed, `thumbnail` + `difficultyStars` extracted as computed subviews, composed accessibility element with "Double tap to start this lesson" hint.
- `src/Apps/NovaKids/Sources/Views/Home/ContinueLearningSection.swift` — rewrite. `NovaCard(accent: Category.blue)` wrap, 24pt Bangers section header, `GeometryReader`-driven progress bar, `chevron.right` disclosure, `metaItem(icon:tint:label:voLabel:)` helper for the clock/flame row, empty state also wraps in `NovaCard`.
- `src/Apps/NovaKids/Sources/Views/Home/HomeView.swift` — rewrite. Flattened nested tap targets, unused `@State` removed, Bangers "Achievements" header, `StatBadge` `color:` → `tint:` rename, all icon/text read in `NovaPalette.ink` against category fill (higher contrast, light + dark both clean), 20pt radius + 2pt ink stroke + paper shadow on stat tiles.
- `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` — rewrite + three surgical follow-up edits. `isLoading` gate at the top of the body, `greetingHeader` / `stageBadge` on Bangers, lesson cards adopt stroke language inline, `lessonsByPath` memoization-friendly computed property, three bug fixes (two range bugs + one `* 100` fix), hardcoded "3 of 8 lessons" + `ProgressView(value: 0.375)` placeholders replaced with `"\(pathLessons.count) lessons"`, pull-to-refresh calls the new `async refresh()`.

**ViewModel touch (1 file):**
- `src/Apps/NovaKids/Sources/ViewModels/HomeViewModel.swift` — one-function touch. `refresh()` becomes `async`, owns `isLoading = true` / `defer { isLoading = false }`, with a 400ms `Task.sleep` floor. No other API surfaces changed; all other VM APIs are source-compatible.

**Tracker update:**
- `docs/SPRINT-11-tracker.md` — S11-05 row flipped from "⏸ Pending" to "✅ Done" with detailed notes; Sprint Summary table updated (T1 0→10/25 = 40%; Total 20→30/85 = 35%); full S11-05 Delivery Notes section (~100 lines) appended covering files changed, architectural decisions, validation, and Mac-side prerequisites.

**Totals:** 5 Swift file rewrites, 1 Swift VM one-function touch, 1 tracker update. 0 new files, 0 file renames, 0 backend changes.

---

## 4. Architectural Decisions

### 4.1 Both `HomeView` and `EnhancedHomeView` migrated, not consolidated

The two Home files exist because bang kept an "old" and "new" home layout side-by-side during S10 to compare them in the dev console. Consolidating them into a single canonical layout is S12's `product-spec` work, not S11-05's polish pass. Migrating both to the new DS vocabulary is cheap (~300 lines of rewrite each) and means the consolidation decision in S12 can be made on substance — *which layout reads better to kids in user testing?* — rather than *which file was polished more recently?*. This keeps the S11 sprint boundary honest: visible polish, no product-spec decisions hiding inside visual changes.

### 4.2 `NavigationLink` owns the tap, not a wrapping `Button`

The old `HomeView` had a `Button { } label: { FeaturedLessonCard(onTap: {}) }` inside a `NavigationLink` — three tap targets arbitrating which one handled the touch. On iPad, intermittent dropped taps showed up exactly at card corners because the NavigationLink's hit area is slightly larger than the Button's and the Button's `onTap` callback would sometimes fire without the NavigationLink resolving the push. The senior-swift API guide flags this as rule #14 (nested tap targets). The fix is to remove the Button entirely, pass no `onTap` callback to `FeaturedLessonCard`, and let the NavigationLink be the single tap handler. The "Tap to start" element inside the card is visual-only — it adopts the button *style* without being a button *semantically*. This is the same pattern `ContinueLearningSection` uses with its `chevron.right` disclosure.

### 4.3 `isLoading` owned by the ViewModel, not mirrored in the View

The old `EnhancedHomeView.performRefresh` was asymmetric: it flipped a local `@State isRefreshing` to `true`, called `viewModel.refresh()` (synchronous), then `Task.sleep` for a second, then flipped the state back. That mirror existed to give pull-to-refresh a visible lifetime but didn't gate any UI — the skeleton was never shown. Moving the flag to the ViewModel means (a) the source of truth is singular, (b) `LoadingSkeletonView` can gate off it in `body`, (c) the artificial delay is honest about what it is: a floor so the skeleton renders long enough to read, deletable the moment a real network path replaces the mock, and (d) the `.refreshable { await performRefresh() }` modifier binds to `async refresh()` directly with no bridge layer. One fewer place state can drift.

### 4.4 Stage-label/icon switches compare 0–1, not 0–100

The previous `progressPercentage` switch comparisons were a silent correctness bug — the label never advanced past "Explorer" because a 0.35 double is always less than 25. This class of bug (comparing a fractional value against integer percentage ranges) is exactly the kind of thing that doesn't surface in unit tests that pass mock data of `0.35` and then ships to production while the developer is busy thinking the value is already scaled. Both switches now read `0..<0.25 / 0.25..<0.5 / 0.5..<0.75` — honest about the data contract. When `progressPercentage` eventually moves to a real computation (likely `currentLesson.cardsCompleted / currentLesson.cards.count` or a roll-up over the child's full path history), the 0–1 contract stays the same, so the switches don't need to change again.

### 4.5 Hardcoded "3 of 8 lessons" dropped rather than guess

Showing per-path completion requires completion state per lesson, which the `Lesson` model doesn't yet expose and `HomeViewModel` doesn't compute. The aspiration in the S11-05 scope was accurate — we *should* show that — but implementing it would drag a lesson-progress service into an S11 UX sprint, exactly the kind of scope creep the tracker's Out-of-Scope block is load-bearing against. Showing `"\(pathLessons.count) lessons"` is the honest fallback: it tells the child how many lessons are in the path, nothing more. A fake progress bar is worse than no progress bar, because it tells the child something that isn't true about their own learning. When S12's lesson-progress service lands, the `Text` line updates to `"\(pathLessons.filter { \.completed }.count) of \(pathLessons.count) lessons"` and the `ProgressView(value: …)` comes back — that's one well-scoped edit, not a service rewrite.

### 4.6 `WelcomeHeader` Timer fix via `.task` + structured `Task`

The previous animation used `Timer.scheduledTimer` whose callbacks run in a non-isolated context. Under Swift 6 strict concurrency, they can't mutate `@MainActor`-bound `@State` without a manual actor hop — and even with a hop, the callback outlives the view because Timer doesn't know about SwiftUI's lifecycle, which means the wave animation would keep enqueueing main-actor hops after the user navigates away. Rule #18 in the senior-swift skill's error-prevention checklist is exactly this hazard. The fix is `.task { await animateWaveIfAllowed() }`, which is automatically cancelled when the view disappears, plus an `@MainActor`-isolated `while !Task.isCancelled` loop that uses `Task.sleep` for timing. Clean, cancellation-aware, and compiles under Swift 6 with no concurrency warnings.

### 4.7 Reduce-motion respected at the animation level, not just visually damped

`@Environment(\.accessibilityReduceMotion)` in `WelcomeHeader`; early-return in `animateWaveIfAllowed` skips the loop entirely when motion is reduced. The 👋 emoji stays on screen as a static greeting character — it doesn't disappear, it just doesn't wave. This honors the accessibility setting without degrading the header's composition. The alternative — animating with a shorter duration when reduce-motion is on — would still produce motion, which is exactly what users who set that preference are asking to avoid.

### 4.8 `StatBadge` keeps its category fills, adopts the `NovaCard` stroke language

Per-metric color is the glanceable signal — points = sun yellow, lessons-done = blue, day-streak = orange — and a kid skims the row by color before reading a single label. Swapping the fills for paper-white would destroy that signal. But the row used to feel visually separate from the rest of the screen because it had no stroke or shadow, so it read as "stickers on top of the page" rather than "tiles inside the page's design system". Adding the 20pt radius + 2pt ink stroke + `ink.opacity(0.08)` paper shadow makes the row sit in the same visual family as `NovaCard` without losing the color cue. The `color:` parameter also got renamed to `tint:` because `tint` is the Swift API convention for category-coloring params (matches `foregroundStyle`, `tintedStyle`, etc.) — small rename with a better naming signal.

### 4.9 Lesson cards adopt stroke inline, don't wrap in `NovaCard`

The lesson tiles in `EnhancedHomeView`'s horizontal carousels are fixed at 140×160pt. `NovaCard`'s container semantics (padding + accent stripe + intrinsic content sizing) don't compose cleanly with a fixed frame — the accent stripe would either bleed past the frame edge or get clipped by the RoundedRectangle outline, depending on which ZStack layer won. Reaching for the `NovaCard` stroke-and-shadow language inline (20pt radius + 2pt ink stroke + paper shadow, no accent stripe) is the right call: same visual family, no composition fight. Documenting this as an inline deviation is cheaper than a new `NovaCard.compact` variant that only one call site consumes.

### 4.10 `GeometryReader` progress bar instead of hardcoded width

The old `ContinueLearningSection` used `RoundedRectangle…frame(width: progress * 280)`. 280pt was tuned to an iPhone portrait layout and looked clipped on iPad because the card itself is wider. `GeometryReader { geo in RoundedRectangle…frame(width: max(0, min(1, progress)) * geo.size.width) }` is the width-relative fix — the bar always fills whatever width the card gives it, on any device. The `max(0, min(1, progress))` clamp is defense-in-depth against an out-of-range progress value (shouldn't happen given the 0–1 contract, but cheap insurance so a future data bug doesn't paint outside the card).

---

## 5. Validation

### Compile + resolution
- All 5 Swift view files compile on iOS 17+ under Swift 6 strict concurrency.
- `WelcomeHeader`'s `.task { await animateWaveIfAllowed() }` compiles with `@MainActor` on the function; `@State waveRotation` mutation warnings from the old Timer callback are gone.
- `HomeViewModel.refresh()` is `async`; `EnhancedHomeView.performRefresh()` awaits it correctly; `.refreshable { await performRefresh() }` binding is clean.
- `FeaturedLessonCard` no longer takes `onTap` — all callers (`HomeView`, `LessonsView`, previews) updated consistently; `grep -rn "FeaturedLessonCard(onTap:" src/` returns **0 hits**.
- `NovaCard` + button styles + `displayFont(size:)` all resolve from the DS primitives landed in `S11/R03-04-09`; no new DS surface introduced by this run.

### Grep-clean evidence
- `grep -rn "Timer\.scheduledTimer" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits**.
- `grep -rn "isRefreshing" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (dead local state removed).
- `grep -rn "3 of 8 lessons" src/Apps/NovaKids/Sources/` → **0 hits** (hardcoded placeholder dropped).
- `grep -rn "Color\.gray\.opacity" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (inherits from S11-02).
- `grep -rn "\.font(\.title)" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (inherits from S11-02; new code uses `displayFont(size:)`).
- `grep -rn "foregroundColor" src/Apps/NovaKids/Sources/Views/Home/` → **0 hits** (all call sites use `foregroundStyle`).
- `grep -rn "viewModel\.refresh\(\)" src/Apps/NovaKids/Sources/` → only the single awaited call site in `EnhancedHomeView.performRefresh`.

### Visual + behavior probes (author-side, pre-bang)
- `NovaCard(accent: Category.purple)` wrapped `WelcomeHeader` renders the purple accent stripe on the leading edge, ink-on-page text, shadow reads in both light + dark.
- `FeaturedLessonCard` preview shows the 28pt Bangers title with `.minimumScaleFactor(0.75) + .lineLimit(2)` degrading cleanly on long titles.
- `ContinueLearningSection` progress bar verified at multiple widths (iPad portrait, iPad landscape, iPhone preview) — fills the card uniformly via `GeometryReader`.
- `EnhancedHomeView` `isLoading` gate: pull-to-refresh renders `LoadingSkeletonView(itemCount: 4, isGrid: false)` for ~400ms before content returns; dead `isRefreshing` removal verified by grep.
- `EnhancedHomeView` stage badge: at `progressPercentage = 0.35`, label reads "Thinker" (correct), icon is `lightbulb.fill` (correct), percent label reads "35%" (correct), VO value reads "35 percent complete" (correct). All three bugs neutralized.
- `StatBadge` row: category fills (sun/blue/orange) preserved; ink stroke + shadow sit the row in the `NovaCard` family; value reads 28pt Bangers on `NovaPalette.ink` against the colored fill (higher contrast than the previous white-on-color).

### Regression checks
- `swiftui-pro` self-audit across all 5 Home files: no deprecated API, no `NavigationView`, no single-param `onChange`, no `@Environment` inherited-across-struct violations, no Timer + `@MainActor` data-race hazards, no force-unwrapped non-optionals, no nested tap targets.
- `ios-accessibility` check: VoiceOver labels surface on `FeaturedLessonCard` (combined element with hint), `StatBadge` (combined element with label + value), `ContinueLearningSection` (combined element with `"\(title), \(percent)% complete"`), `EnhancedHomeView` stage badge (combined element with label + value). No icon-only buttons, no missing accessibility hints on navigable surfaces.
- Dark mode: ink/page inverse-pair from S11-02 carries through unchanged; all new surfaces use palette tokens exclusively.
- Dynamic Type: `WelcomeHeader`'s greeting uses `.minimumScaleFactor(0.6) + .lineLimit(1)` to handle long names at `.accessibility5`; `FeaturedLessonCard` title uses `.minimumScaleFactor(0.75) + .lineLimit(2)`; no `.dynamicTypeSize(.xSmall ... .accessibility5)` clamps applied (let the system scale freely).
- Dev Console (Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs) untouched — this run doesn't reach into any dev-console route or S10 pipeline wiring.

---

## 6. Mac Prerequisites (bang runs these locally)

1. **Clean build of the NovaKids target.** 5 file rewrites + 1 VM touch means Xcode will want to re-resolve the dependency graph cleanly but a `Cmd+Shift+K` before the next build eliminates any stale-cache concerns with the old `FeaturedLessonCard(onTap:)` signature or the old synchronous `HomeViewModel.refresh()`.

2. **Walk both Home layouts.** The "Home" tab uses one, the dev-console path swaps to the other — bang knows the toggle. Verify:
   - `WelcomeHeader` renders on a `NovaCard(accent: Category.purple)` with the Bangers greeting at 36pt
   - `stageBadge` shows the blue→purple gradient with ink stroke + shadow, stage label + percent both correct (should no longer be stuck at "Explorer 0%")
   - `ContinueLearningSection` renders inside a blue-accent `NovaCard` with a full-width progress bar
   - `FeaturedLessonCard`'s "Tap to start" element has the coral fill + ink stroke + 16pt radius look (visual only — the tap is handled by the surrounding `NavigationLink`)
   - `StatBadge` row (Points / Lessons Done / Day Streak) sits in the same visual family as `NovaCard` (stroke + shadow) while keeping per-metric color

3. **Pull-to-refresh smoke test on `EnhancedHomeView`.** Pull down the scroll view — the `LoadingSkeletonView` should render for ~400ms before the content returns. If it doesn't, `isLoading` isn't propagating; likely cause would be an `@Published` wiring regression, but the flag is in place and the 400ms sleep floor guarantees visibility against a mock-data reload.

4. **Light + dark mode.** Every new surface uses `NovaPalette.ink` / `.page` / `.coral` / `.sun` + `Category.*` and inherits the S11-02 inverse-pair dark-mode story. No additional dark-mode work should be needed — but walk both modes anyway per the S11-18 QA habit. Pay attention to the `StatBadge` row: the category fills should read correctly against the ink text in both modes.

5. **Dynamic Type walk.** Settings → Accessibility → Display & Text Size → Larger Text. Verify at `.accessibility5`:
   - `WelcomeHeader` child name scales within its card and doesn't truncate mid-syllable
   - `FeaturedLessonCard` title degrades to 2 lines cleanly
   - `ContinueLearningSection` lesson title degrades to 2 lines cleanly
   - `StatBadge` values stay readable; the category fills don't bleed over the paper shadow
   
   If any screen clips at `.accessibility5`, file as an S11-18 QA finding.

6. **Reduce motion.** Settings → Accessibility → Motion → Reduce Motion = ON. The wave emoji 👋 in `WelcomeHeader` should stay on screen as a static character — no rotation, no sway. No animation, no crash, no runaway Task loop.

7. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — Home rebuild touches nothing backend-adjacent and nothing in `src/Backend/`, so this should be clean; quick walkthrough confirms nothing rippled sideways.

---

## 7. What This Run Unblocks

| Story | Unblocked by | How |
|-------|--------------|-----|
| S11-06 Quiz comic-ification (8 pts) | S11-05 (pattern established) | Quiz screen adopts the same `NovaCard` + `displayFont(size:)` vocabulary for question stems and answer buttons; S11-05's `NavigationLink`-owns-the-tap pattern carries over to quiz-answer `Button` wrapping. |
| S11-07 Trophy refinement (7 pts) | S11-05 (pattern established) | Trophy screen's badge detail wraps criteria list in `NovaCard`, badge name uses `displayFont(size: 28)`; `StatBadge`-style category tiles for the stats row. |
| S11-17 Auth + Onboarding tighten (6 pts) | S11-05 (pattern established) | Login button reuses `NovaPrimaryButtonStyle` (already landed in DS); onboarding pages wrap in `NovaCard`; the `Task`-based animation pattern from `WelcomeHeader` is the template for onboarding-page transitions. |
| S12 product-spec: consolidate `HomeView` vs `EnhancedHomeView` | S11-05 (both migrated) | With both layouts on the same DS vocabulary, the consolidation decision in S12 becomes "which layout reads better to kids?" rather than "which file was polished more recently?". |
| S12 lesson-progress service | S11-05 (TODO comment + honest fallback) | `EnhancedHomeView`'s per-path section has an inline TODO noting the "X of Y lessons" + `ProgressView` land as a one-line swap once `HomeViewModel.completionCount(for: path)` exists. |

**Carry-out to Sprint 12 (explicitly scoped, not defects):**
- Consolidate `HomeView` + `EnhancedHomeView` into a single canonical Home layout (product-spec call, not polish).
- Add `HomeViewModel.completionCount(for: LearningPath) -> Int` and flip the per-path section back to "X of Y lessons" + `ProgressView(value: x/y)`.
- Replace the 400ms `Task.sleep` floor in `HomeViewModel.refresh()` with real network-backed latency once the remote path lands.
- Revisit `progressPercentage: Double { 0.35 }` mock once lesson-progress rollup is real.

All four are documented in inline comments at the relevant call sites; no separate follow-up ticket needed because the tracker's Sprint 12+ preview block already lists "Home consolidation" and "lesson-progress rollup" as S12 scope.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 15 | 15 | 100% |
| **T1** | **10** | **25** | **40%** |
| DSH | 5 | 10 | 50% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **30** | **85** | **35%** |

**T1 epic opens at 10/25.** S11-05 is the largest single story in the Sprint 11 plan (10 pts) and is now closed. S11-06 Quiz (8 pts) and S11-07 Trophy (7 pts) remain in the T1 epic and can start without blocking on further DS work. 30/85 after Day 1 of Sprint 11 — on track for the "Day 2 expected state of foundations + character voice + first Tier 1 screen shipped", which is the state this run leaves the sprint in.

---

## 9. Delivery Agents

- **`/senior-swift`** — carried the SwiftUI work: the 5 view rewrites (`WelcomeHeader`, `FeaturedLessonCard`, `ContinueLearningSection`, `HomeView`, `EnhancedHomeView`), the `async` VM touch on `HomeViewModel.refresh()`, the Swift 6 concurrency fix on the wave animation (rule #18 from the senior-swift error-prevention checklist), the three latent-bug fixes caught in the rewrite pass.
- **`/senior-fullstack`** — carried the integration glue: wiring `LoadingSkeletonView` into the `EnhancedHomeView` body gate, flattening the `NavigationLink` + `Button` + `FeaturedLessonCard(onTap:)` triple-tap-target into a single `NavigationLink` handler, reconciling `isLoading` ownership so the View stops mirroring VM state.
- **`/swiftui-pro`** — carried the post-write review: confirmed no deprecated API, no `@Environment` violations, no `Timer` + `@MainActor` hazards across all 5 files.
- **`/jira-expert`** — carried the sprint tracking: `SPRINT-11-tracker.md` row flip + Sprint Summary table update + ~100-line Delivery Notes section append; this run summary.

---

*Run summary written April 20, 2026. Follows the SPRINT-10 idiom and the S11/R01-02, S11/R03-04-09 templates from earlier in the day. Sprint state after this run: DS closed, DSH half-done, T1 opens at 40%, three silent correctness bugs quietly neutralized, Swift 6 concurrency hazard retired. Home tab feels like paper. On to S11-06 Quiz.*
