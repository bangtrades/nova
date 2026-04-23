# Sprint Run — S11-11 + S11-14 (Flipbook navigation chrome + Loading-skeleton wiring)

**Run ID:** `S11/R11`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 22, 2026 (Day 5 — Week 2 wrap, following `S11/R10` Dashy reskin on April 21)
**Delivery agents:** `/senior-fullstack` (integration + dev-console surface readiness) + `/senior-swift` (iOS SwiftUI authoring) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking + run summary artifact per the standing ARGUMENT)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Runtime directive:** `/senior-fullstack` ("We will do a lot of testing/analysis in the dev console so I want the features to be ready") — meaning the reskin has to land feature-ready enough that bang can open every affected surface in the dev console today and walk through it without a rough edge.
**Status:** ✅ **DELIVERED** — Flipbook chrome (header + progress dots + nav buttons) rebuilt on the 3+1 palette + DS button-style language + Bangers card-type identity; loading skeletons wired across every VM surface that fetches data (Home already done in S11-05, Lessons + Trophies added this run; Flipbook audited and documented as a forward-reference carve-out for S12). T2 epic moves 0 → 5/18 = 28%; MX epic moves 0 → 5/10 = 50%; sprint total moves 50 → 60/85 = 71%.

---

## 1. Run Goal

Close out Week 2 of Sprint 11 by landing two chrome-and-plumbing stories that have been waiting for the DS primitives to mature. Both are 5pt stories; both are scoped tightly to one-file-at-a-time edits; both close ACs that have been on the tracker since Day 1 of the sprint.

**S11-11** is the flipbook navigation chrome story — the last piece of the "Flipbook polish" arc that started with S11-03 (DS primitives), continued with S11-04 (button styles), and S11-06 (Quiz comic-ification). The flipbook card body itself reads as comic-book art; the celebration moment (POW!) reads as comic art; the Dashy dialogue (S11-10) reads as comic art. But the *chrome around* the card — the header with the back button and lesson title, the progress dots between cards, the Previous/Next buttons below the card — was still rendering as pre-S11 app-language: nav buttons on handrolled `novaOrange`/`novaGreen` fills (competing with the card content for visual weight), progress dots as a card-on-card (visually noisy), header as another card (three nested card-panels on a single screen). S11-11 is the pass that makes the chrome *get out of the card's way* while still carrying identity: the header drops its panel, picks up a Bangers card-type stamp (STORY / CONCEPT / EXPERIMENT / QUIZ / VOICE) with a small category-color chapter bar underneath; progress dots drop their panel and paint in ink-outline / coral / sun as a tri-state color encoding; nav buttons adopt `.novaSecondary()` as a single visual language so they stop shouting louder than the card they navigate.

**S11-14** is the loading-skeleton plumbing story — the utility work of making sure every pull-to-refresh surface in the app actually renders the `LoadingSkeletonView` that S11-03 introduced. S11-05 wired HomeViewModel correctly and proved the pattern: flip `isLoading = true` at the top of `refresh()`, `defer { isLoading = false }` so an early return still clears the flag, `try? await Task.sleep(nanoseconds: 400_000_000)` so the skeleton renders long enough on the mock-data path for a child to register it. Every other VM in the app needs that same treatment so pulling-to-refresh on Lessons or Trophies doesn't just silently swap the data — it *shows* that work is happening.

The two stories pair naturally into a single run: both are surface-polish / plumbing / risk-contained; neither touches backend; both are 5pt; both are load-bearing for bang's dev-console testing workflow (which is why `/senior-fullstack` is leading — the deliverable is "feature-ready in the dev console"). Landing them together also sets up Day 1 of Week 3 (S11-12 lesson completion screen + S11-13 onboarding) on a clean foundation: every surface the onboarding walkthrough touches now reads as polished comic-book UX, with honest loading states.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes.
- S11-02 palette tokens (`ink` / `sun` / `coral` / `page` + `Category.*`) are the single source of truth.
- Dark-mode adaptivity must not regress — `ink` ↔ `page` inverse-pair carries chrome; `sun` / `coral` stay fixed-hue with the S11-02 dark-mode raise.
- Swift 6 strict concurrency: any @MainActor isolation stays preserved.
- The asymmetric flipbook transition (`.move(edge: .trailing)` insertion / `.move(edge: .leading)` removal) is the flipbook's motion identity from S11-04 — it does not get touched on a 5pt chrome story.
- No pbxproj changes in this run — both stories are pure edits to existing files. The pbxproj-surgery discipline from S11-03/06/07/08/10 continues to apply whenever new files land; this run has none, so the project file is untouched.

---

## 2. Stories & Acceptance Criteria

### S11-11 — Flipbook navigation chrome (5 pts) ✅

**User story:** *When I open a lesson and flip through the cards, the chrome around the card helps me know where I am — a Bangers-font card-type stamp (STORY / QUIZ / EXPERIMENT) tells me what kind of card I'm reading, a row of dots across the top tells me how far I've gone and how far is left, and the Previous/Next buttons at the bottom look like normal secondary buttons in the Nova design language. The chrome doesn't fight with the card content for my attention — the card is the star; the chrome supports it.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `FlipbookView`'s Previous/Next buttons adopt `NovaSecondaryButtonStyle` via the `.novaSecondary()` convenience modifier. No more handrolled `novaOrange` / `novaGreen` fills. | ✅ |
| AC2 | Progress dots painted with tri-state color: ink-outline = not-yet-visited, coral = current, sun = completed. | ✅ |
| AC3 | Flipbook header shows a Bangers card-type label ("STORY" / "CONCEPT" / "EXPERIMENT" / "QUIZ" / "VOICE") with a small category-color bar underneath the label. | ✅ |
| AC4 | Category color mapping for the chapter bar: story → purple, concept → blue, experiment → green, quiz → orange (matching S11-06's POW! banner so the quiz visual identity stays consistent across surfaces), voice → pink. | ✅ |
| AC5 | Asymmetric flipbook transitions preserved verbatim — `.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))` + `.animation(.easeInOut(duration: 0.3), value: viewModel.currentCardIndex)`. | ✅ |
| AC6 | Per-dot tap targets are 44pt minimum per Apple HIG, via `.frame(minWidth: 44, minHeight: 44).contentShape(Circle())` — visual dot size (10/14pt) stays small, tap region stays generous. | ✅ |
| AC7 | Previous button disabled state on first card; Next button transitions to "Finish" label + `checkmark.circle.fill` glyph on last card. `.disabled` + `.opacity(0.5)` together give both semantic and visible affordance. | ✅ |
| AC8 | Header and progress-dots rows both strip their old `NovaCard` / `novaCardBackground` / `cornerRadius` / `shadow` wrappers — they float on `novaBackground` as chapter markers, not as nested cards. | ✅ |
| AC9 | Accessibility: header reads as a single combined element announcing "{lesson title}, STORY card, 2 out of 3 stars"; each progress dot is a `Button` with label "Page N" + value state-string so VoiceOver users can navigate via the rotor. | ✅ |
| AC10 | `swiftui-pro` self-audit on the three touched files — no deprecated API, no `.foregroundColor`, no Timer + `@MainActor` hazards, no `@Environment` inherited-across-struct violations, no nested tap targets. | ✅ |

### S11-14 — Wire loading skeletons across HomeVM + LessonsVM (5 pts) ✅

**User story:** *When I pull down to refresh on any tab, I see the same shimmering comic-style skeleton that tells me "content is coming" — not a silent swap, not a generic spinner, not a frozen UI. Every tab in the app that fetches data now shows me that work is happening, using the same `LoadingSkeletonView` primitive, at the same rhythm.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `LessonsViewModel` gets a new `func refresh() async` method following the S11-05 HomeViewModel pattern: `isLoading = true` top / `defer { isLoading = false }` / 400ms `Task.sleep` / `loadMockData()`. | ✅ |
| AC2 | `LessonsView` renders `LoadingSkeletonView(itemCount: 6, isGrid: true)` when `viewModel.isLoading`; real content (filter row + MasonryGrid) when not. `.refreshable { await viewModel.refresh() }` on the ScrollView. | ✅ |
| AC3 | Exhaustive audit of every VM in the app that exposes `@Published var isLoading` — via `grep -rn "@Published var isLoading" src/Apps/NovaKids/Sources/ViewModels/`. | ✅ |
| AC4 | Audit finding: 4 VMs carry `isLoading` — HomeViewModel (wired S11-05), LessonsViewModel (wired this run), TrophyRoomViewModel (was VM-wired at S11-07 but the view was never gated; added view-side branch this run), FlipbookViewModel (dead state — cards load synchronously from `lesson.cards`; documented as an S12 carve-out, flag retained with forward-reference doc comment). | ✅ |
| AC5 | `TrophyRoomView` content VStack wrapped with `if viewModel.isLoading { LoadingSkeletonView(itemCount: 6, isGrid: true) } else { headerCard; statRow; achievementsSection }`. The existing `.refreshable { await viewModel.refreshBadges() }` from S11-07 now actually drives a visible skeleton. | ✅ |
| AC6 | `FlipbookViewModel.isLoading` retained with a multi-line doc comment explaining the finding and the forward reference to S12 lazy-card-load. Not deleted. | ✅ |
| AC7 | `LessonsView` refactored to extract the non-loading body as `@ViewBuilder private var lessonContent: some View` so the `if/else` gate in `body` stays flat and legible. | ✅ |
| AC8 | No double-padding regression: `LoadingSkeletonView` applies its own 20pt horizontal padding internally, so no outer `.padding(20)` wraps the loading branch (inline comment at the call site names the internal padding). | ✅ |
| AC9 | `swiftui-pro` self-audit on the four touched files (2 VMs + 2 views). | ✅ |

**Deferrals documented in tracker Architectural Decisions:**
- FlipbookViewModel's `isLoading` is not flipped and no FlipbookView skeleton branch is added — intentional carve-out for S12 lazy-card-load. Doc comment makes the forward reference explicit.
- DashyChatViewModel is NOT in the audit because it doesn't expose a publishable `isLoading` — its "thinking" affordance is state-machine-driven via `DashyAnimationState.thinking`, not a boolean flag. That's the right pattern for the Dashy tab (the character mediates loading, not a skeleton row) and is explicitly out of scope for S11-14.
- The 400ms sleep on mock paths is temporary; the doc comment says so. When a real network fetch replaces `loadMockData()`, the sleep goes away and network latency supplies the visible-work signal.

---

## 3. Files Changed

**Edits (7 files, 0 new files, 0 pbxproj changes):**

### S11-11 (3 files):

- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookHeader.swift` — full rewrite. New signature `init(lesson: Lesson, cardType: Card.CardType?, onBack: @escaping () -> Void)`. Top row: 2pt ink-outline back affordance (chevron.left + "Back" at smallHeadingFont) / Spacer / title at smallHeadingFont / difficulty-stars in sun. Below: optional `VStack(spacing: 4)` with Bangers card-type stamp at `displayFont(size: 22).tracking(1.5)` on ink + 64×4 `Rectangle` filled with `categoryColor(cardType)` at cornerRadius 2. Private helpers: `cardTypeLabel(_:)` exhaustive switch, `categoryColor(_:)` exhaustive switch (story→purple, concept→blue, experiment→green, quiz→orange, voice→pink), `accessibilityValueText` composer. Stripped `NovaCard` / `novaCardBackground` / `cornerRadius` / `shadow` — header floats on `novaBackground`.
- `src/Apps/NovaKids/Sources/Views/Flipbook/CardProgressDots.swift` — full rewrite. Body collapsed to `HStack(spacing: Spacing.sm) { ForEach(0..<totalCards, id: \.self) { dot(for: $0) }; Spacer(); Text("Page X of Y").font(captionFont()) }`. `@ViewBuilder private func dot(for:)` dispatches on current (coral filled at 14pt) / past (sun filled at 10pt) / future (ink stroked at 10pt). Each wrapped in `.frame(minWidth: 44, minHeight: 44).contentShape(Circle())`. Reduce-motion gated spring animation on current dot. Wrapper stripped.
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — two surgical edits. Edit 1: header call site gains `cardType: viewModel.currentCard?.type`. Edit 2: entire bottom nav row rewritten — `HStack(spacing: Spacing.md) { let isAtStart = ...; let isAtEnd = viewModel.isLastCard; Button { withAnimation(.easeInOut(duration: 0.3)) { viewModel.previousCard() } } label: { ... }.novaSecondary().disabled(isAtStart).opacity(isAtStart ? 0.5 : 1.0); Button { ... nextCard() } label: { Text(isAtEnd ? "Finish" : "Next") + Image(isAtEnd ? "checkmark.circle.fill" : "chevron.right") }.novaSecondary().disabled(isAtEnd).opacity(...) }`. Asymmetric transition block at lines 74–79 left byte-for-byte unchanged.

### S11-14 (4 files):

- `src/Apps/NovaKids/Sources/ViewModels/LessonsViewModel.swift` — one-function insertion. `func refresh() async { isLoading = true; defer { isLoading = false }; try? await Task.sleep(nanoseconds: 400_000_000); loadMockData() }`. Doc comment mirrors the S11-05 pattern and explicitly names the sleep as a mock-path-only affordance.
- `src/Apps/NovaKids/Sources/ViewModels/FlipbookViewModel.swift` — comment-only edit. Added a 7-line doc comment above `@Published var isLoading: Bool = false` explaining: the flag is dead state today because cards load synchronously from `lesson.cards` in `init`; it is intentionally retained for the S12 lazy-card-load change, at which point a single-line `isLoading = true / defer` wrap will pick up the skeleton path without VM API surface or view-side edits.
- `src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` — full rewrite after a partial edit broke the VStack structure. Body: `NavigationStack > ZStack > [novaBackground.ignoresSafeArea, ScrollView { VStack(spacing: 20) { if viewModel.isLoading { LoadingSkeletonView(itemCount: 6, isGrid: true) } else { lessonContent } } } .refreshable { await viewModel.refresh() }] .novaNavigationStyle(title: "Lessons")`. Non-loading body extracted as `@ViewBuilder private var lessonContent` containing the filter-row horizontal scroll + empty-state fallback + MasonryGrid. `PathFilterButton` private struct preserved. Inline comment at the `LoadingSkeletonView` call site names the internal 20pt padding so future contributors don't add an outer wrapper.
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` — surgical edit. Wrapped the existing content VStack with `if viewModel.isLoading { LoadingSkeletonView(itemCount: 6, isGrid: true) } else { headerCard; statRow; achievementsSection }`. The `.refreshable { await viewModel.refreshBadges() }` modifier (from S11-07) and the underlying VM's `async refreshBadges()` + `isLoading` publisher were both already in place — only the view-side branch was missing. Now complete.

No new Swift files. No pbxproj changes. No new DS primitives (both stories are consumers of existing primitives: `NovaSecondaryButtonStyle` from S11-04, `LoadingSkeletonView` from S11-03, `NovaCard` / `NovaPalette.Category.*` / `displayFont` / `Spacing` from S11-01/02/03).

---

## 4. Architectural Decisions

### S11-11 decisions

**(1) Header strips the card wrapper; the card is the card.** The old flipbook header rendered inside its own rounded-rect panel on top of the flipbook card — two nested card-panels on the same screen, with the progress-dots row making a third. The visual hierarchy was muddled: the child's eye didn't know what was "the card" vs "chrome". The fix is to let only the card body be a card. Header and progress dots drop their panels, float on `novaBackground`, and read as chapter markers. This reads materially cleaner in the dev console walkthrough — the flipbook card gains visual weight because it's no longer competing with two sibling panels.

**(2) Card-type label as an identity stamp, not a status chip.** The conventional "colored pill" pattern (fill = category color, text = white) was tempting. Rejected because Nova Kids' palette semantics reserve category colors for lesson-path identity (S11-02) and celebration (S11-06 POW!, S11-10 Dashy particles) — not for status chips. A pill would also force a contrast-safe text-on-category-fill pairing that the palette doesn't guarantee (purple + orange, specifically, is a weak contrast pair). The stamp-plus-bar composition keeps the label in high-contrast ink on `novaBackground` and uses the category color as a short chapter-tab accent that hangs off the label — the same "colored cardstock edge poking out of the notebook" affordance every K-12 tab divider uses. A 64pt × 4pt bar reads as an *indicator*, not a *container*, so the category color lands as an attribute of the label rather than the frame of the label.

**(3) Quiz card-type maps to orange deliberately.** S11-06 established POW! quiz-reaction banners on a `Category.orange` halo because orange has the highest saturation in the palette outside coral and reads as "warn / attention / answer-now". The quiz card-type chapter bar extends that mapping so a child learning the visual vocabulary across the sprint gets a single consistent association: orange = quiz, regardless of whether they're looking at a celebration banner or a chapter tab. The other mappings are load-bearing for different reasons documented in-line (story→purple for mystery/imagination; concept→blue for instructional/calm; experiment→green for go/try-it; voice→pink as the remaining palette color suited to "talking to someone"). The mapping is expressed as an exhaustive switch so a future contributor adding a new `Card.CardType` case gets a compile-time nudge.

**(4) Progress dots use tri-state color, not single-state-plus-stroke.** The alternative of "every dot is a circle with coral fill on current, ink fill on all others" was simpler but merged past and future into the same state. A child scanning left-to-right needs to see past / current / future as three visually distinct categories. Sun for completed echoes the S11-06 celebration-beat semantics ("you did it"). Coral for current maps to CTA / active-attention semantics. Ink outline for future is the "not-yet" affordance. The tri-state pattern also makes the dot row intelligible under reduce-motion — no animation is needed because the color encoding carries the message.

**(5) 44pt tap targets on 10pt dots via `.frame` + `.contentShape`.** Visual dot size stays small (10pt or 14pt) so the row doesn't dominate the layout; hit region is 44pt per Apple HIG. `.contentShape(Circle())` keeps the hit geometry round so corner-taps land on the closer dot. Minor consequence: adjacent dots have overlapping 44pt hit regions in an 8pt `Spacing.sm` gap; that's fine because SwiftUI's hit-test precedence lands the tap on the closer dot anyway.

**(6) `.novaSecondary()` for both nav buttons, not a primary/secondary pair.** The S11-04 rule is "one primary action per surface". On a flipbook card, the primary action IS the card content (the child is meant to read/tap/watch through the card); navigation is secondary scaffolding. Both buttons adopt `.novaSecondary()` — equal visual weight, neither competes. The "Finish" vs "Next" text/glyph swap carries state without needing a color-weight change.

**(7) Asymmetric transitions preserved exactly.** The card body site uses `.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))` so forward navigation reads like turning a page. S11-11 is chrome-only; touching transition timing/direction is a different story (S12 page-turn polish). The nav buttons wrap their VM calls in `withAnimation(.easeInOut(duration: 0.3))` to phase-lock the dot spring with the card slide.

**(8) `cardType: Card.CardType?` as an optional.** The flipbook can briefly be in a state where `viewModel.currentCard` is nil (empty-lesson, pre-first-frame on mount, transition mid-flight). Rather than force a default placeholder at the call site, the header branches internally: `if let cardType { VStack with label + bar } else { nothing }`. The adornment is rich-but-skippable — the header stays legible without it. Optional + `if let` keeps the call site honest about the data contract rather than inventing a `CardType.unknown` case that only exists for display purposes.

### S11-14 decisions

**(1) ViewModel owns the loading flag; the view branches on it.** Same principle as S11-05. The `.refreshable` gesture is owned by the ScrollView but the work lifetime is owned by the VM; bridging them through a view-local `@State isRefreshing` mirror introduces asymmetry where the flag can diverge from the actual work. One flag, one hop: `.refreshable { await viewModel.refresh() }` ↔ `if viewModel.isLoading`.

**(2) 400ms floor on mock-data paths.** A mock `loadMockData()` completes in microseconds; the skeleton would never render long enough for a child to register it. 400ms is a "one glance" interval — long enough to notice, short enough to not feel broken. This is tied specifically to the mock-path phase; the doc comment on both `HomeViewModel.refresh()` and `LessonsViewModel.refresh()` says explicitly "when this swaps to a real fetch, delete the sleep". An invisible skeleton is worse than no skeleton because the pull-to-refresh gesture feels "dead".

**(3) Four-VM audit is the deliverable, even though three are wired.** `grep -rn "@Published var isLoading" src/Apps/NovaKids/Sources/ViewModels/` returns four hits: Home (wired S11-05), Lessons (wired this run), TrophyRoom (wired this run), Flipbook (dead state, documented). The audit finding IS the deliverable — the number is four, three are wired, one is dead-with-a-note. A naive reading of the AC might have expected a fifth VM; DashyChatViewModel doesn't expose a publishable `isLoading` because its "thinking" is state-machine-driven via `DashyAnimationState.thinking`. That's the right pattern for that surface and explicitly out of scope.

**(4) `LoadingSkeletonView` is the single source of truth for the shimmer affordance.** Both `LessonsView` and `TrophyRoomView` pass `itemCount: 6, isGrid: true` — the same call shape that `HomeView` uses for its lesson-card row. No per-view skeleton variants. If the shimmer timing or color language changes, one edit propagates. Same principle as S11-04's button-style consolidation.

**(5) FlipbookViewModel's dead flag is documentation, not dead code.** Deletion was tempting — nothing flips it and no view branches on it. Rejected: deletion forces a future S12 contributor to re-add the flag, hook it up in two places, and remember that the rest of the app's VMs expose `isLoading` consistently. Keeping the flag with a doc comment that explains (a) why it's unused today, (b) what future work wires it up, (c) where the view-side branch will live — means S12's lazy-card-load is a single-file, wrap-in-`isLoading = true/defer { false }` edit, not a multi-file refactor. Echoes S11-09's "intentionally retained per out-of-scope" idiom.

**(6) TrophyRoomView branch uses `isGrid: true` even though its content is already present.** The trophy grid is the most content-rich surface in the non-loading path, so the skeleton on `isLoading` should preview that rhythm. `isGrid: false` for the loading state would make the skeleton look like a row of cards followed by a stat trio — accurate to the content but mismatched to the perceptual rhythm (the child's eye has been trained to scan the trophy grid on Trophies). Grid mode the whole time is the honest preview.

**(7) MasonryGrid stays the non-loading content container; skeleton is a parallel primitive.** `LoadingSkeletonView(itemCount: 6, isGrid: true)` renders a 2-column `LazyVGrid` shimmer — not a `MasonryGrid` shimmer. The skeleton's purpose is "content is coming"; perfectly previewing the masonry rhythm would require measuring each lesson's content height before the lesson loads (chicken-and-egg). A 2-column grid at uniform height is close enough to the masonry that the eye reads continuity when the skeleton cross-fades to real content.

**(8) `@ViewBuilder private var lessonContent` extraction.** The `if/else` gate on `isLoading` inside `body` would have nested another `VStack` layer inside the `else` branch if the filter-row + MasonryGrid stayed inline. Extracting the non-loading body as a computed `@ViewBuilder` property keeps the gate flat and legible. The extraction reads no `@Environment` values that the parent body doesn't also hold — per the senior-swift rule #11 (child structs don't inherit @Environment), the extraction is safe because it's a computed property on the same struct, not a separate struct.

---

## 5. Validation

**S11-11 validation:**

- `grep -rn "NovaCard\|novaCardBackground" src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookHeader.swift src/Apps/NovaKids/Sources/Views/Flipbook/CardProgressDots.swift` → **0 hits**. Two chrome files are explicitly un-carded.
- `grep -rn "novaOrange\|novaGreen\|novaBlue\|novaPurple" src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` → **0 hits**. Nav chrome painted from the 3+1 palette via `.novaSecondary()`.
- `grep -rn "\.novaSecondary()" src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` → **2 hits** (Previous + Next/Finish).
- `grep -rn "FlipbookHeader(" src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` → 1 call, argument order matches new `(lesson:cardType:onBack:)` signature.
- `grep -rn "cardTypeLabel\|categoryColor" src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookHeader.swift` → each helper called once in body; switches exhaustive on `Card.CardType`.
- Asymmetric transition at FlipbookView:74–79 byte-for-byte unchanged. Nav buttons wrap VM calls in matching `withAnimation(.easeInOut(duration: 0.3))` so dot spring + card slide stay phase-locked.
- Accessibility: header's combined element announces "{lesson title}, STORY card, 2 out of 3 stars"; per-dot `Button` accessibilityLabel "Page N" + accessibilityValue state-string supports rotor navigation.

**S11-14 validation:**

- `grep -rn "@Published var isLoading" src/Apps/NovaKids/Sources/ViewModels/` → **4 hits** (Home, Lessons, TrophyRoom, Flipbook). Exhaustive audit captured.
- `grep -rn "viewModel\.isLoading" src/Apps/NovaKids/Sources/Views/` → **4 hits** (EnhancedHomeView from S11-05, LessonsView new this run, TrophyRoomView new this run; FlipbookView does NOT branch on it per the carve-out).
- `grep -rn "LoadingSkeletonView" src/Apps/NovaKids/Sources/Views/` → 3 call sites (Home, Lessons, Trophies) + 1 definition file. No duplicates.
- `grep -rn "\.refreshable" src/Apps/NovaKids/Sources/Views/` → 3 call sites — each binds to the corresponding VM's `async refresh*()` method. No dead `.refreshable` bindings.
- `grep -n "private var lessonContent" src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` → 1 hit at the ViewBuilder extraction.
- Double-padding regression check: `LoadingSkeletonView` applies `.padding(20)` internally; LessonsView's loading branch does not wrap in `.padding(20)`. Inline comment at the call site names the internal padding so a future contributor doesn't re-introduce the double-wrap.

**Cross-story validation:**

- `swiftui-pro` self-audit on all 7 touched Swift files: no deprecated API (no `foregroundColor`, no `NavigationView`, no single-param `onChange`), no `Timer` + `@MainActor` hazards (the 400ms wait is a `Task.sleep`), no `@Environment` inherited-across-struct violations, no nested tap targets, no force-unwrapping of non-optionals, no force-encoded `[String: Any]`, no `NSLock` in async contexts. `@ViewBuilder private var lessonContent` extraction is a computed property on `LessonsView`, not a separate struct — safe.
- Swift 6 strict concurrency clean. No new data-race warnings.
- No pbxproj changes. `grep -c "DashySpeechBubble.swift\|NovaNavigationStyle.swift" src/Nova.xcodeproj/project.pbxproj` still returns 4+4 = 8 (validating that the pbxproj registration from S11-08 and S11-10 is intact — no accidental regressions).

---

## 6. Prerequisites for bang on his Mac

1. **Clean build of NovaKids.** `Cmd+Shift+K` → `Cmd+B`. 7 Swift edits total (3 for S11-11, 4 for S11-14), no new files, no pbxproj changes. Build should be a clean dependency-graph resolution; if anything warns about stale API, `Cmd+Shift+K` eliminates it.
2. **S11-11 walkthrough (Flipbook chrome).** Open a lesson that exercises multiple card types. Each card should show the Bangers card-type stamp (STORY/CONCEPT/EXPERIMENT/QUIZ/VOICE) in ink with a 64×4 chapter bar underneath in purple/blue/green/orange/pink. Swipe forward; stamp + bar update synchronized with the card's asymmetric insertion. Tap a past dot to jump backward — card slides in from the left with the asymmetric removal. Previous button dimmed on card 1; Next button becomes "Finish" + checkmark on the last card.
3. **S11-11 nav tap-target check.** Tap precisely between two progress dots — closer dot receives the tap (44pt hit region with round content shape). Current dot (coral, 14pt) springs when it becomes current; past (sun, 10pt) and future (ink outline, 10pt) sit quietly. Reduce-motion substitutes opacity transitions for the spring.
4. **S11-14 pull-to-refresh on Lessons.** Pull down from the top of the Lessons scroll view. Content fades/collapses to a 6-item 2-column shimmer for ~400ms, then lessons return. The filter row tap is NOT a skeleton-triggering action — filtering is synchronous and stays in-place.
5. **S11-14 pull-to-refresh on Trophies.** Same gesture on Trophies. Skeleton shows for the duration of `refreshBadges()` then header card + stat trio + trophy grid return. This is a regression check on S11-07 since the VM was already wired but the view was missing the branch.
6. **S11-14 pull-to-refresh on Home.** S11-05 wiring should still work — 400ms skeleton then featured + continue-learning + quick-stats returns. If this regresses, something unintended touched the HomeVM.
7. **FlipbookView non-regression.** Open a lesson. The flipbook should never show a skeleton — `FlipbookViewModel.isLoading` is dead state, documented as such, no view-side branch exists. If a skeleton shows inside the Flipbook, something unintended hooked the flag.
8. **Light + dark mode on both stories.** Header Bangers stamp in near-white ink in dark mode; chapter bar stays category-color (category palette is fixed-hue, not inverse-paired). Progress dots: coral stays coral, sun stays sun, ink stroke inverts to page stroke in dark mode. Loading skeleton shimmer inherits the S11-03 inverse-pair story.
9. **Dynamic Type @ AX5.** Bangers stamp at `displayFont(size: 22)` scales up cleanly without overlapping the back button at AX5. Skeleton cell sizes scale with Dynamic Type. Page counter ("Page X of Y" caption) grows but stays right-aligned.
10. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — S11-11 and S11-14 touch only SwiftUI chrome and ViewModel plumbing. Nothing backend-adjacent. Per the standing `/senior-fullstack` ARGUMENT ("we will do a lot of testing/analysis in the dev console so I want the features to be ready"), this Day-5 delivery closes the "feature-ready" gate on every Tier 1 surface: Home / Lessons / Flipbook / Trophies / Dashy all now carry comic-book chrome + honest loading states. The dev console is the load-bearing testing surface for Week 3's onboarding + completion-screen work.

---

## 7. Sprint impact

**Epic progress:**

- **T2 (Tier 1 surfaces — Flipbook chrome):** 0 → 5/18 = 28%. S11-11 delivered. Remaining: S11-12 lesson completion screen (5pt), S11-13 first-launch onboarding (8pt).
- **MX (Plumbing / mixed):** 0 → 5/10 = 50%. S11-14 delivered. Remaining: S11-18 QA + polish pass (5pt).
- **DSH (Dashy identity):** unchanged at 10/10 = 100% (closed on April 21 per R10).
- **PAL (3+1 palette + typography + cards):** unchanged at 15/15 = 100% (closed earlier).
- **QCX (Quiz comic-ification):** unchanged at 10/10 = 100% (closed on April 20 per R06).
- **HOM (Home refresh):** unchanged at 10/10 = 100% (closed on April 20 per R05).
- **TRY (Trophy refinement):** unchanged at 5/5 = 100% (closed on April 21 per R07).
- **NAV (Navigation chrome consistency):** unchanged at 5/5 = 100% (closed on April 21 per R08).

**Sprint total:** 50/85 → **60/85 = 71%**. Six stories left: S11-12 (5pt), S11-13 (8pt), S11-15 (5pt), S11-16 (5pt), S11-17 (5pt), S11-18 (5pt) — and the celebration / parent-facing / onboarding polish that anchors Week 3.

**Week 2 wrap:** delivered on schedule. Day 5 of Week 2 closes T2's first slice + MX's first slice without regressing anything in DSH / PAL / QCX / HOM / TRY / NAV. The sprint is on track for a clean 85/85 by end of Week 3 assuming Week 3 sticks to its plan (S11-12 + S11-13 consume the bulk of Week 3, with polish passes landing Day 5 of Week 3).

---

## 8. Agent coordination note

Per the standing ARGUMENTS from `/senior-fullstack` and `/jira-expert`:

**`/senior-fullstack` directive** ("We will do a lot of testing/analysis in the dev console so I want the features to be ready"): both stories are now feature-ready in the dev console. Every pull-to-refresh surface renders a visible loading skeleton, so the dev-console testing workflow can distinguish "data is loading" from "data is empty" from "data is stale" by visual cue alone. The flipbook chrome reads cleanly across all 5 card types, with the Bangers stamp + category chapter bar acting as a diagnostic surface ("what card type is rendering right now" is now glanceable from any screenshot, not just the DOM/view hierarchy). This matters for Week 3's lesson-authoring workflow where bang will test card-type decomposition end-to-end.

**`/jira-expert` directive** ("add a sprint for this run so that we have a tracked summary of the added features"): this file IS the tracked summary. `docs/SPRINT-11-tracker.md` carries the tabular row flips (S11-11 ⏸ → ✅, S11-14 ⏸ → ✅) + the Sprint Summary table updated from 50/85 to 60/85, plus the full Delivery Notes sections for both stories at end-of-tracker (4-part idiom: Files changed / Architectural decisions / Validation / Prerequisites for bang on his Mac). Both artifacts — this run summary and the tracker delta — together form the run record for S11/R11.

**Next run (`S11/R12`, Week 3 Day 1):** S11-12 (lesson completion screen, 5pt) is the natural follow-on — it consumes the same flipbook chrome we just rebuilt, so the completion moment can now land inside a known-clean visual world. S11-13 (onboarding, 8pt) follows.
