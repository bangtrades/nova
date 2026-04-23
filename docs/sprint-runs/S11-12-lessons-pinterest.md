# Sprint Run — S11-12 (Lessons grid + filter pills — Pinterest-gestalt pass)

**Run ID:** `S11/R12`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 22, 2026 (Day 6 — Week 2, immediately following `S11/R11` flipbook + skeletons on April 22 and `S11-haptic-ladder-sweep` S11/R? on April 22)
**Delivery agents:** `/senior-fullstack` (integration + dev-console surface readiness) + `/senior-swift` (iOS SwiftUI authoring) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking + run summary artifact per the standing ARGUMENT)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Runtime directive:** `/senior-fullstack` ("We will do a lot of testing/analysis in the dev console so I want the features to be ready") — the Lessons tab is one of the four primary tab-bar surfaces the user lands on, so it has to be feature-ready enough to open, filter, and scroll through without a rough edge the first time bang puts it on the demo iPad.
**Status:** ✅ **DELIVERED** — `LessonTileView` rebuilt on DS chrome (ink outline + page background + difficulty-coded accent stripe + iPad hover lift + 7-day NEW badge + completion badge); `PathFilterButton` → `PathFilterPill` (ink-outline default / coral-fill selected, matching S11-06 Quiz answer-chip selection rule); all Lessons-tab padding routed through `Spacing` enum; `MasonryGrid` column-width math preserved byte-for-byte. T2 epic moves 5 → 11/18 = 61%; sprint total moves 63 → 69/85 = 81%.

---

## 1. Run Goal

Land the Lessons tab on the S11-02/03/04 design-system foundation so a child scanning the lesson library gets the same comic-book vocabulary the rest of the app speaks. The tile is a masonry-grid card (flexible heights, 2-column Pinterest-style layout) that has historically been the Lessons tab's defining gestalt — so S11-12 explicitly does not touch the layout math. It reskins the chrome that wraps each tile and the filter pills above the grid, and nothing else.

The story has sat on the tracker at ⏸ Pending since Day 1 of the sprint because it's load-bearing for the T2 "full coverage" pass: once Lessons lands on DS chrome, only Dashy chat (S11-13) and Auth/Onboarding (S11-17) remain as surfaces that could still feel "pre-S11" when bang runs the demo iPad walkthrough. Closing S11-12 tips the visual-system adoption curve past 80% of the app's surface area, which matters for the end-of-sprint QA pass (S11-18) — at that point QA is validating a unified system, not inventorying a patchwork.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes.
- S11-02 palette tokens (`ink` / `sun` / `coral` / `page` + `Category.*`) are the single source of truth — zero `Color.gray.opacity(…)` and zero raw `.font(.title)` / `.font(.body)` in touched files.
- The masonry layout math (`MasonryGrid`'s `GeometryReader`-derived column-width calculation) is the Lessons tab's visual DNA. S11-12 reskins *tile chrome*, not layout.
- Swift 6 strict concurrency: any @MainActor isolation on `LessonsViewModel` stays preserved.
- `LoadingSkeletonView` + `.refreshable { await viewModel.refresh() }` were already wired in S11-14 — S11-12 preserves that path and does not re-implement loading chrome.
- No pbxproj changes in this run — both files edited (`LessonTileView.swift`, `LessonsView.swift`) are pre-existing in the target; no new files land.

---

## 2. Stories & Acceptance Criteria

### S11-12 — Lessons grid + filter pills — Pinterest-gestalt pass (6 pts) ✅

**User story:** *When I open the Lessons tab, each tile in the grid looks like it belongs in the same comic-book world as the Home, Quiz, and Trophy screens. The tiles have a satisfying drawn-outline feel; the accent stripe on the leading edge tells me at a glance how hard a lesson is; a bright "NEW" badge catches my eye on lessons that just dropped; a completion checkmark shows me which lessons I've already done. On my parent's iPad, hovering my cursor over a tile lifts it slightly — just enough to feel responsive. The filter pills at the top look like little buttons I can stamp to filter by learning path; the one I've tapped fills in coral so I know which filter is active.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `LessonTileView` drops the pre-S11 soft-shadow card chrome in favor of a 2pt ink stroke on a 20pt continuous rounded-rect silhouette over `NovaPalette.page` — matching the `NovaCard` language but authored inline because the tile has a custom thumbnail region. | ✅ |
| AC2 | 6pt leading-edge accent stripe, color-keyed to `lesson.difficulty` (1 → `novaGreen` easy, 2 → `novaOrange` medium, 3 → `novaPurple` challenging, fallback → `coral`). Stripe is clipped to the same 20pt rounded-rect so the leading corners curve inward; the trailing edge of the stripe stays straight because 20pt of radius can't fit in 6pt of width — matching `NovaCard`'s stripe technique. | ✅ |
| AC3 | NEW badge: Bangers "NEW" at `displayFont(size: 14)` in ink on a sun-filled Capsule with a 2pt ink stroke, positioned top-leading via `.overlay(alignment: .topLeading)`. Badge visibility gated on `lesson.publishedAt` within the last 7 days — "if every tile is NEW, none of them are". | ✅ |
| AC4 | Completion badge: coral-filled Circle with 2pt ink stroke + `checkmark` glyph in page-color, positioned top-trailing via a separate `.overlay(alignment: .topTrailing)` so the NEW and completion signals land in opposite corners and never collide regardless of tile width. | ✅ |
| AC5 | iPad / Mac hover lift: `.onHover` + `@Environment(\.horizontalSizeClass) == .regular` + `!reduceMotion` triple-gate drives a 1.02 scaleEffect. iPhone (compact width) never fires `.onHover` on touch, so the gate is free — but the explicit `horizontalSizeClass` check means the scaleEffect math is also skipped on compact-width iPad multitasking windows. | ✅ |
| AC6 | Filter pills (`PathFilterPill`): capsule silhouette, ink-outline / page-fill default, coral-fill / page-text when selected — matching the S11-06 Quiz answer-chip selection-as-coral rule. Replaces the earlier `PathFilterButton` implementation. | ✅ |
| AC7 | Thumbnail gradient (accentColor.opacity(0.5) → `sun`.opacity(0.35)) fills the top 140pt of the tile flush to the card edges. The rounded silhouette clip is applied *before* the background color, so the gradient does not leak past the stroke. | ✅ |
| AC8 | All padding in `LessonsView` + `LessonTileView` routed through `Spacing` enum (`.xs` / `.sm` / `.md` / `.lg`). Zero raw point values except the intentional 6pt accent stripe width, 140pt thumbnail height, 36pt completion badge diameter, 20pt corner radius, and 2pt ink stroke — all of which are geometric constants, not spacing. | ✅ |
| AC9 | `MasonryGrid` column-width math untouched. The tile's outer size behavior (fills parent width, intrinsic content height) is preserved, so the grid's GeometryReader-derived column-width and staggered-height calculations read the new chrome identically to the old. | ✅ |
| AC10 | Accessibility: tile announces "{New lesson: }{title}" as label, "{difficulty} stars{, completed}" as value, "Double tap to open this lesson" as hint. NEW badge is `.accessibilityHidden(true)` because the label already carries the "New lesson:" prefix; completion checkmark + difficulty stars + thumbnail icons all hidden. `PathFilterPill` exposes its title as label, "Selected" / "Not selected" as value, and adds `.isButton` trait explicitly. | ✅ |
| AC11 | Loading-state path preserved: `LessonsView` still branches on `viewModel.isLoading` to render `LoadingSkeletonView(itemCount: 6, isGrid: true)`, and `.refreshable { await viewModel.refresh() }` stays wired — S11-14 closed audit finding #4 on the Lessons side and S11-12 does not re-implement that path. | ✅ |
| AC12 | `swiftui-pro` self-audit on the two touched files — no deprecated API (no `.foregroundColor`, no single-param `.onChange`, no `NavigationView`), no force-unwrapping, no `@Environment` inherited-across-struct violations (`PathFilterPill` declares its own `@Environment(\.accessibilityReduceMotion)` rather than reading from parent), no Timer + `@MainActor` hazards. | ✅ |

---

## 3. Files Changed (2)

- `src/Apps/NovaKids/Sources/Views/Lessons/LessonTileView.swift` — **full rewrite**. Signature preserved (`init(lesson:isComplete:onTap:)`), body rebuilt on DS chrome. The outer shell is now a `VStack(alignment: .leading, spacing: 0) { thumbnail; content }` wrapped in a `Button(action: onTap)`, with a specific modifier ordering that matters: `.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))` **first** (clips the thumbnail gradient to the rounded silhouette so the gradient does not leak past the stroke), then `.background(NovaPalette.page, in: RoundedRectangle(cornerRadius: 20, style: .continuous))` (paints the warm page color behind everything in the same shape), then `.overlay(alignment: .leading) { accentColor.frame(width: 6).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)).allowsHitTesting(false) }` (6pt leading-edge accent stripe, clipped to the same 20pt radius so top/bottom leading corners curve inward — the `.allowsHitTesting(false)` makes sure the stripe doesn't intercept the Button's tap), then `.overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(NovaPalette.ink, lineWidth: 2) }` (the 2pt ink stroke is the last overlay so prior `.clipShape` doesn't eat into the stroke width). Two more overlays land the NEW and completion badges in opposite corners: `.overlay(alignment: .topLeading) { if isNew { newBadge.padding(Spacing.sm) } }` and `.overlay(alignment: .topTrailing) { if isComplete { completionBadge.padding(Spacing.sm) } }` — two separate overlays rather than one ZStack+alignment so the two signals land independently regardless of tile width. Below the Button: `.scaleEffect(shouldLift ? 1.02 : 1.0)` + `.animation(reduceMotion ? .none : .easeOut(duration: 0.15), value: isHovering)` + `.onHover { hovering in isHovering = hovering }`, where `shouldLift` is a computed property gating on `isHovering && horizontalSizeClass == .regular && !reduceMotion` so iPhone's compact width class never pays the layout cost. Accessibility: `.accessibilityElement(children: .combine) .accessibilityLabel(accessibilityLabel) .accessibilityValue(accessibilityValue) .accessibilityHint("Double tap to open this lesson")`. New computed properties: `accentColor` (switch on `lesson.difficulty`: 1 → `novaGreen`, 2 → `novaOrange`, 3 → `novaPurple`, default → `coral`); `isNew` (7-day window via `Date().timeIntervalSince(publishedAt) < sevenDays` where `sevenDays: TimeInterval = 7 * 24 * 60 * 60`); `accessibilityLabel` ("New lesson: {title}" if `isNew`, else `title`); `accessibilityValue` ("{difficulty} stars{, completed}"); `shouldLift` (hover + regular width + not reduce-motion). New subviews: `thumbnail` (unchanged visual — gradient from `accentColor.opacity(0.5)` to `sun.opacity(0.35)` at 140pt height, with `book.circle.fill` + "Lesson" caption at center, all accessibilityHidden); `content` (title at `smallHeadingFont()` / 2-line limit, difficulty stars as 3 `star.fill` / `star` glyphs in `sun` / `ink.opacity(0.3)`, description at `captionFont()` / 2-line limit in `ink.opacity(0.7)` — all padding via `Spacing.md`); `completionBadge` (coral-filled Circle + ink stroke + bold checkmark in page color, 36pt diameter); `newBadge` (Bangers "NEW" in ink on sun-filled Capsule with ink stroke, `displayFont(size: 14)`, padded `.horizontal, Spacing.sm` + `.vertical, Spacing.xs`, `.accessibilityHidden(true)` since the label prefix already announces it). `#Preview` refreshed with two test lessons — one with `publishedAt: Date()` (fresh — NEW badge should render) and one with `publishedAt: Date(timeIntervalSinceNow: -30 * 24 * 60 * 60)` (30 days — no badge).

- `src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` — **full rewrite** to route all spacing through the `Spacing` enum and swap the filter-pill component. Body shape unchanged: `NavigationStack > ZStack > [novaBackground.ignoresSafeArea, ScrollView(.vertical) { VStack(spacing: Spacing.lg) { if viewModel.isLoading { LoadingSkeletonView(itemCount: 6, isGrid: true) } else { lessonContent } } .refreshable { await viewModel.refresh() }] .novaNavigationStyle(title: "Lessons")`. The `lessonContent` `@ViewBuilder` private var extracted in S11-14 is kept as the clean-swap anchor; inside it, the filter row now uses `Spacing.sm` between pills, `Spacing.xs` on the horizontal scroll's inner padding, and `Spacing.lg` on the outer padding-horizontal/padding-top — replacing the earlier mix of raw `12`/`16`/`20` point values. "All" sentinel pill maps to `selectedPath == nil`; the `ForEach(viewModel.learningPaths)` loop renders a `PathFilterPill` per path with `isSelected: viewModel.selectedPath?.id == path.id` and the action closure calling `viewModel.selectPath(path)`. `MasonryGrid` call site gains `spacing: Spacing.md` (was raw `16`), and the `.padding(Spacing.lg)` on the grid (was raw `20`). `EmptyStateView` call unchanged. New nested private struct `PathFilterPill`: `Button(action: action) { Text(title) ... }` with the text at `smallHeadingFont()`, `.foregroundStyle(isSelected ? NovaPalette.page : NovaPalette.ink)`, `.padding(.vertical, Spacing.sm)` + `.padding(.horizontal, Spacing.md)`, background `Capsule(style: .continuous).fill(isSelected ? NovaPalette.coral : NovaPalette.page)`, overlay `Capsule(style: .continuous).stroke(NovaPalette.ink, lineWidth: 2)`; `.buttonStyle(PlainButtonStyle())`; `.animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isSelected)` — light spring on selection, respects reduce-motion. Accessibility: `.accessibilityElement(children: .combine) .accessibilityLabel(title) .accessibilityValue(isSelected ? "Selected" : "Not selected") .accessibilityAddTraits(.isButton)`. The old `PathFilterButton` struct is replaced wholesale — no migration shim because it's private to `LessonsView.swift` and has only the two call sites in this same file.

---

## 4. Architectural Decisions

- **Difficulty drives the accent stripe color.** The stripe could have been any of: (a) per-lesson-path category color (routing `lesson.pathId` → the path's theme color), (b) a single brand-accent (coral everywhere, as a "Nova says: here's a lesson" signal), or (c) difficulty-coded (green / orange / purple for 1 / 2 / 3 stars). Rejected (a) because path-color in the masonry grid would make the stripe compete with the thumbnail gradient (which already carries accent identity) — two competing color anchors on a single tile. Rejected (b) because a monotone stripe doesn't earn its 6pt of leading-edge real estate; the strip isn't pulling semantic weight. Chose (c) because a row of tiles then reads as a **difficulty curve** at a glance — a child scanning left to right sees "green green orange green orange purple" and gets a map of "easy ones first, then some medium, then a challenge" without a text label or a legend. The mapping is 1 → `novaGreen`, 2 → `novaOrange`, 3 → `novaPurple` — an ordered climb from calm to warn to intense, not an arbitrary rainbow. Difficulty `0` or out-of-range falls back to `coral` (the brand accent) so the stripe always paints, and the switch default makes the fallback explicit. A future 4-star difficulty would map to coral deliberately until the design decides on a new rung — the fallback reads as "here's a lesson" rather than "here's a silent rendering bug".

- **NEW badge window is 7 days, not 24 hours, not 30 days.** The window has to be long enough that a badge is still on-screen when a returning child opens the app a day or two after a new drop, and short enough that the signal stays scarce. 24 hours is too tight — a Friday drop is gone by Monday. 30 days is too generous — on an active authoring schedule, half the grid would carry the badge and the badge would collapse into noise. 7 days sits in the sweet spot: a child who opens the app once a week still sees newness; a child who opens it daily sees the same badge collect "context" (it appeared Friday, I didn't tap it; Saturday it's still there; by next Friday it's gone) without the badge turning into a permanent sticker. The implementation is `Date().timeIntervalSince(publishedAt) < sevenDays` with `sevenDays: TimeInterval = 7 * 24 * 60 * 60` — one line, re-computable at render time, no state, no scheduler. `publishedAt: Date?` is already on the `Lesson` model from the backend (S10 era), so no migration.

- **NEW lands top-leading, completion lands top-trailing — two overlays, not one ZStack.** The pre-S11 tile used a single `ZStack(alignment: .topTrailing)` for the completion checkmark. Adding a NEW badge into that same stack would either (i) force a shared alignment so both land in the same corner (visually collides, unreadable), or (ii) introduce an explicit `VStack` inside the ZStack to separate them vertically (busy, tile becomes a layered sandwich of positional logic). The chosen path is two independent `.overlay(alignment:)` modifiers on the outer container — NEW via `.overlay(alignment: .topLeading) { if isNew { newBadge.padding(Spacing.sm) } }`, completion via `.overlay(alignment: .topTrailing) { if isComplete { completionBadge.padding(Spacing.sm) } }`. Each overlay anchors to its own corner; the padding is symmetric so the two badges sit at mirrored insets; and because overlays stack in declaration order, if a tile somehow ended up with both isNew and isComplete on different occasions, each badge still lands in its dedicated corner with zero overlap. The `if` inside each overlay means a tile that is *neither* new nor complete pays only the cost of two empty overlays — negligible.

- **`.clipShape` before `.background(_, in:)`, then stripe overlay, then stroke.** Modifier ordering in SwiftUI matters because each modifier wraps the view tree and sees the cumulative result. The ordering here is load-bearing: (1) `.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))` clips the **inner VStack content** (the thumbnail gradient + content block) to the rounded silhouette so the thumbnail gradient — which fills the full tile width flush to the top — doesn't paint outside the rounded corners at the top edge. (2) `.background(NovaPalette.page, in: RoundedRectangle(cornerRadius: 20, style: .continuous))` paints the warm page color **behind** the clipped content in the same rounded shape — so the region between the thumbnail and the card edges reads as page-warmth, not as a seam. (3) The stripe overlay lands on top of the background, also clipped to the same 20pt radius so its leading corners curve; `allowsHitTesting(false)` keeps it from intercepting the Button's tap. (4) The 2pt ink stroke overlay lands **last** so no subsequent `.clipShape` eats into it — the stroke sits precisely on the 20pt path, rendering as an inked silhouette rather than a softened outline. The two badge overlays (topLeading NEW, topTrailing completion) come after the stroke so they sit above the ink line — intentional, because a completion checkmark behind the stroke would look like a dirty smudge. Alternative: a single ZStack with explicit `z`-ordered children. Rejected because overlays carry better semantic pairing (modifier attached to the element it decorates) and are trivially gated by `if isNew` / `if isComplete` without adding conditional children to a stack. The ZStack form would also require explicit frame matching on the background layer, which the overlay form gets for free.

- **iPad hover lift is triple-gated: `isHovering && horizontalSizeClass == .regular && !reduceMotion`.** `.onHover` only fires when a pointing device is available (iPad with trackpad / mouse, Mac with Catalyst-style pointer). On iPhone, touch events don't trigger `.onHover` at all, so the basic gate (isHovering) already keeps the scale math dormant on pure-touch devices. But `horizontalSizeClass == .regular` adds a second gate: an iPad running Nova in a compact-width multitasking window still has a pointer, and the hover event would still fire, but the tile is now sized for a phone-style layout where a scaleEffect lift reads as "something's glitching" rather than "this is responsive". The size-class gate ensures hover-lift is an iPad-landscape / iPad-portrait-full-width feature, not a "every device with a pointer" feature. Third gate, `!reduceMotion`, short-circuits the entire effect for users who've opted out of motion — the `shouldLift` computed property returns false, the scaleEffect math produces 1.0 with no animation trigger, and the `.animation(..., value: isHovering)` modifier still respects the reduce-motion branch even if hover fired. The redundancy is intentional: the scaleEffect is harmless (`1.0 * frame = frame`) when any gate is false, but having the triple-gate read at the declaration site makes the intent readable without having to trace which modifier handles which case.

- **`PathFilterPill` is a capsule, not a rounded rect.** The pre-S11 `PathFilterButton` used a `RoundedRectangle(cornerRadius: 12)` — not wrong, but it read as a button-button (like a "Submit" in a form) rather than a filter affordance. A capsule (`Capsule(style: .continuous)`) with ink outline reads as a **tag / chip / stamp** — the visual idiom for "tap me to filter by this", which is exactly the semantic the pill carries. The capsule also lets the text sit in the horizontal middle with equal vertical breathing room above/below regardless of font size, which matters at Dynamic Type `.accessibility5` where a rounded-rect can look squeezed. The "selected = coral fill, unselected = page fill, border always ink" mapping matches S11-06 Quiz answer-chip selection-as-coral rule, S11-11 flipbook nav secondary-button rule, and the broader coral-is-the-action-color convention the 3+1 palette imposes. A future contributor adding a new filter surface gets the pattern for free by reusing the pill struct — worth extracting to DS if a third filter surface appears in S12.

- **Light spring on pill selection, gated on reduce-motion.** A pill that snaps from outlined to coral-filled on tap feels harsh — SwiftUI's default animation is so subtle the color swap reads as a render glitch rather than a state change. A heavy spring (`.bouncy`, `.interactiveSpring`) overshoots in a way that's inappropriate for a filter chip (filters aren't playful; they're tools). `.easeInOut(duration: 0.2)` sits exactly at "you pressed it and it committed" — long enough to register as a transition, short enough to feel decisive. Gated on `@Environment(\.accessibilityReduceMotion)` so users who've opted out of motion get the instantaneous swap they asked for. The animation is attached to `.animation(_:value:)` with `isSelected` as the value, so only selection-state changes trigger it — layout-driven rerenders (grid resize, keyboard appearance) don't animate.

- **`MasonryGrid` column-width math is NOT touched.** The masonry grid reads tile size through intrinsic content sizing (parent gives width; tile decides height). S11-12 changes the tile's **visual** chrome — the outer container still fills the column width and sizes height to content, so the grid's `GeometryReader`-based column-width calculation and staggered row-height pack still see the new chrome identically to the old. This is why S11-12 is a 6pt story and not a 12pt story: the layout system already does the right thing; the tile's visual upgrade slots in without layout-side changes. Verified by reading `MasonryGrid.swift` (86 lines) and confirming the column-width derivation (`cachedColumnWidth` keyed on `GeometryReader`'s proxy.size.width) reads only the grid's own bounds, not the tile content.

- **`LessonTileView` remains a `Button` wrapped in `NavigationLink` at the call site — known quirk, preserved deliberately.** The pre-S11 `LessonsView` wraps each tile in a `NavigationLink` that navigates to `FlipbookView`; the tile itself is a `Button` with an `onTap` closure. The Button's action also sets `selectedLesson` + `showFlipbook` state — which is orphan state today because there's no matching `.sheet(isPresented: $showFlipbook)` on the view. The NavigationLink handles the navigation; the Button onTap is dead code *from a navigation standpoint* but lives as a future hook if `FlipbookView` ever needs to be opened as a sheet rather than pushed on the stack. S11-12 is chrome-only — refactoring navigation is a different scope. Documented here so the next contributor (S12 authoring) either keeps the hook or removes it deliberately rather than stumbling on it as an apparent bug. The PlainButtonStyle inside a NavigationLink works correctly today because the NavigationLink's tap handler takes precedence over the Button's action when both would fire.

- **NEW badge is `accessibilityHidden(true)`; the accessibility label carries the "New lesson:" prefix.** VoiceOver should announce "New lesson: What Makes AI Smart? 2 stars" as a single utterance, not "New. What Makes AI Smart? 2 stars" or "What Makes AI Smart? 2 stars. New lesson." The badge glyph is a visual redundancy for VoiceOver users who already get the information via the combined accessibility element. Implementation: `accessibilityLabel` computed property branches on `isNew` and prepends "New lesson: " to `lesson.title`; the badge view itself gets `.accessibilityHidden(true)` so it doesn't contribute an independent announcement. Same pattern for the completion badge (`accessibilityHidden(true)` on the badge glyph) paired with the accessibility value's ", completed" suffix — one combined announcement, no redundancy.

- **Bangers "NEW" over ink-on-sun, WCAG-safe.** The NEW badge uses `NovaPalette.ink` (≈ `#1A2138`) text on `NovaPalette.sun` (≈ `#FFCE47`) fill. WCAG contrast ratio at those approximate hex values is ~10:1 — well above the 7:1 AAA threshold. The 2pt ink stroke around the capsule adds a belt-and-suspenders frame (the badge reads as "drawn" rather than "floating"). Bangers at `size: 14` feels small but the caps-only rendering + 1pt of tracking on the Bangers metrics keeps it legible — the badge is a glance-read, not a read-read, and the shape + color do more work than the letterforms. Text-to-stroke contrast also matters for ≤AX3 DynamicType users where the letterforms scale but the stroke doesn't — at AX5, the 14pt base scales to ~26pt, which stays within the capsule width comfortably.

---

## 5. Validation

### Sandbox ✅ (what ran here)

| Check | Method | Result |
|---|---|---|
| No deprecated SwiftUI API | `grep -E "foregroundColor\(|NavigationView|\.onChange\(of: [a-zA-Z_]+\) \{ [a-zA-Z_]+ in" LessonTileView.swift LessonsView.swift` | 0 hits |
| Spacing enum coverage | `grep -n "Spacing\." LessonTileView.swift LessonsView.swift` | 14 hits across the two files, 0 raw point-value padding |
| 3+1 palette coverage | `grep -n "NovaPalette\." LessonTileView.swift LessonsView.swift` | 18 hits; zero `Color.gray.opacity` or ad-hoc `Color(hex:)` |
| `MasonryGrid` untouched | `git diff --stat src/Apps/NovaKids/Sources/Views/Common/MasonryGrid.swift` | Expected: 0 changes (pre-commit check) |
| Thumbnail modifier ordering | Re-read `LessonTileView.swift` body — `.clipShape` precedes `.background(_, in:)` precedes stripe overlay precedes stroke overlay | Confirmed in final file |
| Dual-overlay badge pattern | Re-read `LessonTileView.swift` — `.overlay(alignment: .topLeading)` for NEW and `.overlay(alignment: .topTrailing)` for completion are two independent modifiers, not sharing a ZStack | Confirmed |
| Triple-gate hover lift | `shouldLift` reads `isHovering && horizontalSizeClass == .regular && !reduceMotion` | Confirmed in `shouldLift` computed property |
| Accessibility element / label / value / hint | Re-read `body` trailing modifiers on `LessonTileView` | All 4 modifiers present on outer Button; badge views carry `.accessibilityHidden(true)` |
| `PathFilterPill` capsule silhouette | Re-read `PathFilterPill` body — background and overlay both use `Capsule(style: .continuous)` | Confirmed |
| `PathFilterPill` selection animation gated on reduce-motion | Re-read — `.animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isSelected)` | Confirmed |
| `swiftui-pro` self-audit (inline) | Walked both files per `swiftui-pro` reference list — views / data / navigation / accessibility / performance / swift / hygiene | No findings |
| 7-day NEW window math | `isNew` computed property reads `Date().timeIntervalSince(publishedAt) < 7*24*60*60`; guard returns false when `publishedAt` is nil | Confirmed |
| `#Preview` refreshed to exercise both branches | Preview builds two `Lesson` instances — one with `publishedAt: Date()` (fresh), one with `publishedAt: Date(timeIntervalSinceNow: -30 * 24 * 60 * 60)` (30 days old) | Confirmed |

### 🟡 Mac-only (bang must run these locally)

- **Clean iOS build.** Xcode → Cmd+B. Two files edited, both pre-existing in the target — no pbxproj touch. If stale compile artifacts show (unlikely since the public surface of both files is unchanged), Cmd+Shift+K → Cmd+B.
- **Walk the Lessons tab on iPhone (compact width).** Tiles render with ink outline + accent stripe + thumbnail gradient + title/stars/description. No hover lift (no pointer). Tap a tile — navigates to FlipbookView via the existing `NavigationLink`. NEW badge renders on any lesson with `publishedAt` within 7 days; completion badge renders on lessons flagged by `viewModel.isLessonComplete(lesson)`.
- **Walk the Lessons tab on iPad (regular width, landscape).** Hover a trackpad cursor over a tile — tile should scale to 1.02 with a 0.15s ease-out. Move cursor off — scale returns to 1.0. Verify this does NOT happen on compact-width iPad multitasking windows (drag the split into a narrow 1/3 width — the hover should no longer lift the tile because `horizontalSizeClass` flips to `.compact`).
- **Walk the filter pills.** Tap "All" — the pill is already selected (coral fill). Tap a path name — pill transitions to coral fill with a light spring, "All" transitions back to ink outline. Tap it again — same path stays selected (no toggle; the selection model is single-path, not multi-select). Verify the scroll-horizontal gesture works with `.xs` inner padding.
- **Verify the Sun-NEW badge.** Open the Dev Console and publish a new lesson (or shift a sample lesson's `publishedAt` to `now`). Pull to refresh on the Lessons tab — the freshly published lesson should now wear the NEW badge in the top-leading corner. Change `publishedAt` to 8 days ago — refresh — badge disappears. This is the 7-day gate.
- **Verify the completion checkmark.** Complete a lesson end-to-end through FlipbookView. Navigate back to Lessons — the lesson's tile should carry the completion badge in the top-trailing corner. Verify the two badges can coexist on the same tile without collision (unusual but possible: a fresh lesson that the child speed-ran immediately).
- **Dynamic Type @ AX5.** Settings → Accessibility → Display & Text Size → Larger Text → AX5. Return to Lessons. Tile titles scale to the AX5 rendering of `smallHeadingFont()`; descriptions scale to `captionFont()` at AX5; filter pill titles scale to `smallHeadingFont()` at AX5. Verify the masonry grid's staggered heights still read cleanly — tiles can be taller at AX5 but should not clip text.
- **Light + dark mode.** Dark mode: `ink ↔ page` inversion is carried by `NovaPalette`; the sun NEW badge stays visibly yellow; coral selection-fill on pills stays coral; the accent stripe's novaGreen / novaOrange / novaPurple / coral all survive the inversion per S11-02's dark-mode raise. Verify the 2pt ink outline reads as a clean stroke in both modes.
- **VoiceOver walkthrough.** Rotor → Headings → "Lessons" landing. Swipe right through: "Filter by Path" heading, then the filter pills announcing "{title}, Selected" / "{title}, Not selected, button". After the filter row, swipe right through tile elements announcing "New lesson: {title}, {N} stars, completed. Double tap to open this lesson." (or "{title}, {N} stars" for non-new / non-completed variants). Tap into a lesson — navigation announces the FlipbookView.
- **Reduce-motion verification.** Settings → Accessibility → Motion → Reduce Motion ON. Hover a tile with a trackpad — no scale animation (the scaleEffect snaps instantaneously when hover state changes). Tap a filter pill — fill transitions without the spring (instantaneous color swap). Pull to refresh — LoadingSkeletonView still renders but its shimmer animation is disabled per S11-14's internal `.shimmering(active:)` gate.
- **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs on the backend web dev console all still render — S11-12 is iOS SwiftUI only; no backend code changed.

---

## 6. Prerequisites for bang on his Mac

```bash
# 1. Fetch and confirm clean tree.
cd ~/Novai
git status
# expect: modified: src/Apps/NovaKids/Sources/Views/Lessons/LessonTileView.swift
#         modified: src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift
#         modified: docs/SPRINT-11-tracker.md
#         new file:  docs/sprint-runs/S11-12-lessons-pinterest.md
#         modified: docs/sprint-runs/index.md

# 2. Clean build — two Swift files edited, no pbxproj touch, no new files in the iOS target.
cd src/Apps/NovaKids
open Novai.xcodeproj  # or your current workspace path
# Cmd+B  — expect: green, no warnings
# If stale artifacts: Cmd+Shift+K → Cmd+B

# 3. Run on iPhone simulator (compact width).
# In Xcode: Scheme = NovaKids, Destination = iPhone 15 Pro
# Cmd+R
# - Navigate to Lessons tab
# - Observe: 2-column masonry, each tile with ink outline + accent stripe + gradient thumbnail
# - Tap a tile → FlipbookView opens via NavigationLink

# 4. Run on iPad simulator (regular width, landscape).
# In Xcode: Destination = iPad Pro 13-inch (M4), rotate to landscape
# Cmd+R
# - Navigate to Lessons tab
# - With trackpad sim enabled (Simulator → I/O → Send Device Input → Shake ... or use hardware trackpad), hover over a tile
# - Observe: 1.02 scaleEffect lift, 0.15s ease-out
# - Drag the simulator into compact-width split
# - Re-hover: lift should no longer fire (horizontalSizeClass == .compact gate)

# 5. Verify NEW badge.
# Open the backend Dev Console → Pipeline tab → publish a test lesson (or directly manipulate a lesson's publishedAt via the debug menu).
# Pull-to-refresh on the Lessons tab — the fresh lesson should carry the sun "NEW" badge top-leading.

# 6. Verify completion badge.
# Run a lesson to completion. Return to Lessons. Tile for the completed lesson should carry the coral checkmark badge top-trailing.

# 7. Dynamic Type @ AX5.
# Simulator → Features → Toggle Appearance to set up Light/Dark, then Settings → Accessibility → Display & Text Size → Larger Text → AX5
# Walk the Lessons tab — titles, descriptions, pills all scale cleanly.

# 8. Dark mode.
# Cmd+Shift+A (Simulator → Toggle Appearance) — ink/page invert, accent stripe stays hue-correct.

# 9. VoiceOver.
# Cmd+Opt+F5 (Simulator → Features → VoiceOver → On) → walk tiles and pills; verify labels/values/hints per Section 5 Mac-only.
```

---

## 7. Sprint Impact

| Epic | Before R12 | After R12 | Delta |
|------|-----------:|----------:|------:|
| DS | 15/15 (100%) | 15/15 (100%) | — |
| T1 | 25/25 (100%) | 25/25 (100%) | — |
| DSH | 10/10 (100%) | 10/10 (100%) | — |
| T2 | 5/18 (28%) | **11/18 (61%)** | +6 pts |
| MX | 8/10 (80%) | 8/10 (80%) | — |
| QA | 0/7 (0%) | 0/7 (0%) | — |
| **Total** | **63/85 (74%)** | **69/85 (81%)** | **+6 pts** |

T2 epic crosses the 60% threshold with S11-12 landing — only S11-13 (Dashy chat, 7pt) remains for T2 completion. Sprint total clears 80%, with 16 pts across 4 stories remaining (S11-13 / S11-17 / S11-16 / S11-18). Day 6 of the 10-day sprint; 4 days of working capacity left for 16 pts — on pace if S11-16 and S11-18 stay small.

**Execution plan check-in:** Day 6 originally planned S11-12 (6pt) + S11-15 (3pt) for 9pts. S11-15 landed on April 22 alongside the S11/R11 run; S11-12 lands on April 22 in R12. Day 6's scheduled load delivered on schedule. Day 7 plan is S11-13 (7pt) + S11-16 (2pt) for 9pts — the S11-13 Dashy chat rebuild is the next priority, with the reduce-motion audit (S11-16) sweeping over every `withAnimation` block added in S11-05..13 including the pill selection spring and hover scaleEffect that landed in this run.

---

## 8. What's Next

1. **S11-13 — Dashy chat surface rebuild (7pt, T2).** Replace the current Dashy chat view's non-DS bubble chrome with sun-filled Dashy bubbles (ink stroke + tail pointing to the speaker) and coral-filled child reply bubbles. Suggestion pills at the bottom adopt `NovaSecondaryButtonStyle` per the pill-is-secondary-button convention. Session-time progress bar at the top reads as an ink-outlined track with a coral fill proportional to session-minutes-vs-parent-guidance-limit. Keep the existing typing animation but add a reduce-motion fallback rendering a static "…". This is the last T2 story; landing it closes T2 at 18/18 = 100%.

2. **S11-17 — Auth login + Onboarding spacing polish (4pt, QA).** Login: floating-shapes animation rebuilt to use only the 3+1 palette (ink shapes over page, no rainbow). Login primary CTA wraps in `NovaPrimaryButtonStyle`. Onboarding: replace the two raw `.font(.title)` sites in the onboarding flow with `NovaPalette.titleFont()`; avatar grid gains `Spacing.md` between avatars; Dashy's onboarding intro animation respects `@Environment(\.accessibilityReduceMotion)`. Keep the confetti — that's already tuned.

3. **S11-16 — Reduce-motion audit (2pt, MX).** Sweep every `withAnimation` / `.animation(_:value:)` call added in S11-05 through S11-13 (inclusive of the PathFilterPill spring and LessonTileView hover scale landed in this run) and verify each respects `@Environment(\.accessibilityReduceMotion)`. Add a one-line comment at each site documenting the reduce-motion behavior. Known sites: S11-05 WelcomeHeader blink timer, S11-06 POW reaction, S11-07 BadgeUnlockBurst + ProgressRing fills, S11-10 Dashy particles + idle bounce, S11-11 flipbook transition + dot spring, S11-12 hover scale + pill selection.

4. **S11-18 — iPad landscape + dark mode + DynamicType QA (3pt, QA, blocked on S11-13/16/17).** Walk every screen in `iPad Pro 13-inch` simulator in both orientations, in light + dark mode, at Dynamic Type `.xSmall` and `.accessibility5`. Screenshots into `docs/sprint-runs/S11-18-qa-screenshots/`. File a defect inventory as S12 follow-up stories; the goal here is a written inventory, not zero defects.

Final sprint close-out ETA: Day 9 of 10, with Day 10 reserved for demo-iterate.

---

## 9. Retired Debt

None retired in this run — S11-12 was carried on the tracker from Day 1 as planned work, not carry-in debt. Audit finding #4 (loading skeleton on Lessons tab) was closed in S11-14; S11-12 verified the path intact but did not re-close the finding.

---

## 10. Cross-references

- Preceding run: [`S11-flipbook-skeletons.md`](./S11-flipbook-skeletons.md) — `S11/R11` — S11-11 (Flipbook chrome) + S11-14 (loading skeletons). S11-12 consumes the `LoadingSkeletonView(itemCount:isGrid:)` pattern S11-14 proved and preserves the `LessonsViewModel.refresh()` method S11-14 added.
- Preceding run: [`S11-haptic-ladder-sweep.md`](./S11-haptic-ladder-sweep.md) — `S11/R?` — S11-15 (haptic ladder sweep on Tier 1). S11-12's PathFilterPill inherits the haptic wiring through `.novaSecondary()`-adjacent patterns when extracted.
- Preceding run: [`S11-palette-spacing.md`](./S11-palette-spacing.md) — `S11/R1` — S11-01 (Spacing enum) + S11-02 (3+1 palette). S11-12 consumes these as the sole sources of padding values and color tokens.
- Preceding run: [`S11-ds-dashy-rename.md`](./S11-ds-dashy-rename.md) — `S11/R2` — S11-03 (`NovaCard` + button styles) + S11-04 (Bangers display font). S11-12's tile chrome mirrors `NovaCard`'s stripe clipShape technique; the NEW badge uses `NovaPalette.displayFont(size: 14)` from S11-04.
- Preceding run: [`S11-quiz-comic-ification.md`](./S11-quiz-comic-ification.md) — `S11/R6` — S11-06 (Quiz comic-ification). PathFilterPill's "selection = coral" rule follows the Quiz answer-chip convention S11-06 established.
- Tracker: [`SPRINT-11-tracker.md`](../SPRINT-11-tracker.md) — S11-12 row flipped ⏸ Pending → ✅ Done; Sprint Summary percentages updated (T2 28% → 61%, Total 74% → 81%).
- Next run (queued): S11-13 — Dashy chat surface rebuild (7pt). Target file: `src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift`.
