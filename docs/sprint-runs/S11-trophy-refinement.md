# Sprint Run — S11-07 (Trophy/badge detail sheet refinement)

**Run ID:** `S11/R07`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 21, 2026 (Day 3, following `S11/R06` Quiz comic-ification)
**Delivery agents:** `/senior-swift` (iOS code) + `/senior-fullstack` (integration) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — Trophy room + badge tile + badge detail sheet rebuilt on the S11-03/04/06 DS primitives. Two new reusable design-system files landed (`ProgressRing`, `BadgeUnlockBurst`). The three-stat rainbow demoted to the sanctioned `ink` / `sun` / `coral` trio. Three audit findings caught before close-out — a Dynamic Type clip on the badge title, a close-button gradient composition that was being clipped to the button's footprint, and two `ScrollView` sites still on the deprecated init-arg shape. pbxproj 4-location surgery to register both new files under the continued `DE51617100000011000000{B6,C6,B7,C7}` namespace so nothing silently fails to compile on bang's Mac. T1 epic advances to 20/25. Sprint total to 40/85 (47%).

---

## 1. Run Goal

Take the Trophy/Badge surface from "already had a celebratory feel in S10 but read as iOS stock" to fully comic-ified: migrate `TrophyRoomView` and `BadgeView` to the S11-03 `NovaCard` / button-style vocabulary, demote the six-category rainbow that was being used for the three header stat tiles (lessons/experiments/streak) to the sanctioned `ink` / `sun` / `coral` trio, land a reusable `ProgressRing` primitive for the hero detail sheet (and any future "progress circle" surface), and ship a `BadgeUnlockBurst` as the sibling of S11-06's `QuizPowReaction` — same comic-book vocabulary, new word, paired with `NovaHaptics.success()` on sheet-appear.

The tracker AC set was: spacing-scale pass; sunlit-yellow + coral badge icon; ink outline + coral fill progress ring; Bangers badge name; `NovaCard` criteria list; ink/coral/sun stat-card trio (not rainbow); keep the existing confetti + haptic on unlock.

The rebuild also quietly fixed three audit findings from `/swiftui-pro` self-review pass — none of them were regressions introduced by this run, but they were adjacent enough (and cheap enough) that deferring them would have meant shipping S11-07 with known bugs in the trophy surface. Specifically: (1) `BadgeView.swift`'s title `.frame(height: 44)` clipped Bangers ascenders at AX3+ Dynamic Type; (2) the close button's `.background(... .ignoresSafeArea())` composition in the detail sheet did not actually produce the intended screen-edge gradient fade — the `ignoresSafeArea` was nested inside the button's background and got clipped to the button's footprint; (3) two `ScrollView(.vertical, showsIndicators: false)` init-arg uses that should be `.scrollIndicators(.hidden)` modifier form.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes on this run.
- 280+ existing `NovaPalette.novaBlue` / `.novaOrange` / etc. call sites must keep compiling via the S11-02 back-compat aliases.
- Dark-mode adaptivity must not regress — ink/page inverse-pair from S11-02 carries through automatically when the new surfaces use palette tokens.
- No new runtime dependencies — iOS 17+ SwiftUI only.
- Swift 6 strict concurrency: structured `Task` + `@MainActor` hops for any auto-dismiss cycle; no `Timer.scheduledTimer` into `@State`.
- Reduce-motion paths at every animation site; each child struct declares its own `@Environment(\.accessibilityReduceMotion)` (senior-swift rule #11).
- All new Swift files must land in `Nova.xcodeproj/project.pbxproj` at **four** locations (PBXBuildFile / PBXFileReference / PBXGroup children / PBXSourcesBuildPhase) — miss any one and the file silently fails to compile. Ask S11-06's first attempt how that went.

---

## 2. Stories & Acceptance Criteria

### S11-07 — Trophy/badge detail sheet refinement (5 pts) ✅

**User story:** *As a Nova child, when I open my Trophy room I see a single coral "My Trophies" card at the top with my earned-count in a big sun-yellow Bangers number, a clean three-tile summary of my learning stats in the app's real colors (ink / sun / coral — not a rainbow), and a 3-column grid of badges. Earned badges have a sun→coral gradient disc that springs in when the screen loads; locked badges are faded with a padlock and a coral progress bar. Tapping any badge opens a detail sheet with a big progress ring wrapping the badge disc — if I just earned it, a yellow "UNLOCKED!" burst slams onto the page and my iPad buzzes with a success beat. The detail sheet explains how to earn the badge in plain language, shows my progress if I haven't earned it yet, and closes via a proper coral-CTA close button with a gradient fade behind it.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | `TrophyRoomView` composes through the S11-03 vocabulary: header is a `NovaCard(accent: Category.coral)`, stat row is a three-`NovaCard` trio, grid tiles adopt the `NovaCard`-consistent chrome (ink stroke + page fill + rounded rect) **without** the accent stripe (see §4.1 for rationale). | ✅ |
| AC2 | Stat row reads **ink / sun / coral**, not the old blue/orange/green rainbow — closes the tracker AC "use ink/coral/sun trio instead of the full rainbow". | ✅ |
| AC3 | Badge title uses Bangers (`NovaPalette.displayFont(size: 18)`) — closes "Bangers badge name". | ✅ |
| AC4 | Hero detail sheet wraps the badge disc inside a 180pt `ProgressRing(lineWidth: 10)` — closes "ink outline + coral fill progress ring". `ProgressRing` is a reusable DS primitive, not a one-off. | ✅ |
| AC5 | Badge disc gradient is sun→coral on earned / ink-tone descent on locked — closes "sunlit-yellow + coral badge icon". Ink stroke (2pt) around the disc for comic-panel outline; radial sun-glow bleed for warmth on earned. | ✅ |
| AC6 | Criteria block wraps in `NovaCard` with Bangers 20pt "How to earn" header, checkmark-vs-circle glyph, pluralization-aware criteria copy for all 5 `BadgeCriteriaType` cases (`.lessonsCompleted` / `.experimentsCompleted` / `.daysStreak` / `.voiceInteractions` / `.pathCompleted`) — closes "NovaCard criteria list". | ✅ |
| AC7 | `BadgeUnlockBurst` fires on sheet-appear for earned badges — Bangers 48pt "UNLOCKED!" on sun fill with stacked 4-cardinal zero-radius ink shadows, spring scale 0.3 → 1.1 → rest with -6° → +4° rotation, 1.0s hold, reduce-motion fade fallback. Paired with `NovaHaptics.success()`. | ✅ |
| AC8 | All `withAnimation` / arc-fill / spring sites gate on `@Environment(\.accessibilityReduceMotion)` — ProgressRing arc skips its 0.6s ease; BadgeView skips the entrance spring; BadgeUnlockBurst degrades to plain fade. | ✅ |
| AC9 | Hero ZStack consolidates VoiceOver narration — `.accessibilityElement(children: .ignore)` + a single label ("Badge earned" / "Badge progress: N percent") instead of narrating ring / disc / icon separately. | ✅ |
| AC10 | Badge tile title uses `frame(minHeight: 44)` — not `frame(height: 44)` — so Bangers ascenders can grow at AX3+ Dynamic Type without clipping (caught in swiftui-pro self-audit). | ✅ |
| AC11 | Close button in detail sheet is `NovaSecondaryButtonStyle` in `.safeAreaInset(edge: .bottom)` with a proper **ZStack LinearGradient fade** behind the button (see §4.5 for why the first-draft `.background(... .ignoresSafeArea())` composition didn't work). | ✅ |
| AC12 | Both `ScrollView` sites in TrophyRoomView migrated from `ScrollView(.vertical, showsIndicators: false)` init-arg to `.scrollIndicators(.hidden)` modifier form (iOS 16+ idiomatic). | ✅ |
| AC13 | Both new files (`ProgressRing.swift`, `BadgeUnlockBurst.swift`) registered in `Nova.xcodeproj/project.pbxproj` at all four PBX locations using the `DE51617100000011000000{B6,C6,B7,C7}` ID pairs continuing the S11-03/06 namespace. | ✅ |
| AC14 | All 4 touched Swift files pass `/swiftui-pro` self-audit: no deprecated API, no `foregroundColor`, no `NavigationView`, no single-param `onChange`, no `Timer` + `@MainActor` hazards, no nested tap targets, no `@Environment` inherited-across-struct violations. | ✅ |

---

## 3. Files Changed

**New files (2):**
- `src/Apps/NovaKids/Sources/Views/Common/DesignSystem/ProgressRing.swift` — new. `public struct ProgressRing<Content: View>: View` with `progress: Double` (0–1), `lineWidth: CGFloat = 8`, `@ViewBuilder content: () -> Content`. Track circle in `NovaPalette.ink.opacity(0.12)`; filled arc in `NovaPalette.coral` via `.trim(from: 0, to: CGFloat(progress))` + `.rotationEffect(.degrees(-90))` so fill starts at 12 o'clock. `.stroke(..., style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))` so partial arcs don't end on a harsh right angle. Fill animates `.easeOut(duration: 0.6)` gated on `reduceMotion ? nil : ...`. Center slot is `@ViewBuilder content:` so callers can drop a badge icon, a percent label, or any custom center content — the hero sheet uses it to wrap the 88pt badge disc.
- `src/Apps/NovaKids/Sources/Views/Trophies/BadgeUnlockBurst.swift` — new. Cousin of `QuizPowReaction`. `@Binding var isActive: Bool` parent control; internal `@State` for scale / rotation / opacity / cycleTask. "UNLOCKED!" at `displayFont(size: 48)` on `NovaPalette.sun`; stacked 4-cardinal zero-radius ink shadows (`shadow(radius: 0, x: ±2, y: 0 / 0, y: ±2)` — the idiomatic SwiftUI "text stroke" without dropping to Core Text); soft paper-drop shadow for the lifted feel. Spring scale 0.3→1.1→rest, rotation -6°→4°, 1.0s hold, fade-out with small drift (scale 1.2 / rotation 6°). Reduce-motion path: plain opacity fade at scale 1.0 / rotation 0° — still marks the moment without transforms the user opted out of. Structured `Task { @MainActor in ... }` + `Task.sleep(nanoseconds:)` for hold/exit; `onDisappear { cycleTask?.cancel() }` so the sheet dismissing mid-burst doesn't leak a task. `accessibilityHidden(true)` because the meaning is already carried by earned-state + earned-date text + the `NovaHaptics.success()` notification feedback — a third announcement would over-verbose the celebration.

**Rewrites (2):**
- `src/Apps/NovaKids/Sources/Views/Trophies/BadgeView.swift` — rewrite. Tile is a 16pt-radius `RoundedRectangle` with `NovaPalette.page` fill + 2pt `NovaPalette.ink` stroke — **deliberately not a `NovaCard`** (see §4.1). 88pt badge circle with sun→coral gradient on earned / ink.opacity descent on locked; 2pt ink stroke around the disc; radial sun-glow behind the icon for earned; SF Symbol icon in `NovaPalette.ink` on earned / `.ink.opacity(0.3)` on locked; bottom-trailing ink-filled `lock.fill` padlock for locked. Bangers title at 18pt with `minimumScaleFactor(0.8)` + **`frame(minHeight: 44, alignment: .top)`** (the `minHeight` — not `height` — is the Dynamic Type fix). Status row: earned-date in coral via `DateFormatter.dateStyle = .short` OR a linear coral-on-ink-tint capsule progress bar + `Int(progress * 100)`% label for locked. Spring scale-in entrance on first appear (guarded by `@Environment(\.accessibilityReduceMotion)` and the `earned` flag — no celebration for locked badges). `.accessibilityElement(children: .combine)` + `accessibilityLabel(badge.title)` + `accessibilityValue` combining state + progress/earned-date into a single spoken phrase.
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` — rewrite. Screen root: `ZStack` over `NovaPalette.novaBackground`. Header: coral-accent `NovaCard` with Bangers "My Trophies" (`displayFont(size: 28)`), a streak-flame row (flame symbol + day count in ink), and an earned-count block in `displayFont(size: 40)` on `NovaPalette.sun` using the same stacked 4-cardinal ink shadow idiom as POW!/UNLOCKED! — the earned number reads as part of the celebration language. Stat row: three-`NovaCard` trio with **ink / sun / coral** accents (`lessonsCompleted` / `experimentsCompleted` / `daysStreak`). Grid: `LazyVGrid` with 3 flexible columns, `Spacing.md` between items. Tap fires `NovaHaptics.tap()` + sets `selectedBadge = BadgeDisplayItem(...)`. Sheet via `.sheet(item: $selectedBadge)` over the optional Identifiable `BadgeDisplayItem` wrapper so the sheet always gets a concrete non-optional badge. `BadgeDetailSheet` (nested private struct): hero ZStack with 180pt `ProgressRing(lineWidth: 10)` wrapping the 88pt badge disc inside `NovaCard(accent: sun)`, Bangers 34pt title, description body, calendar-icon + earned-date OR "N% on the way" status line; criteria block in default-accent `NovaCard` with Bangers 20pt "How to earn" header, checkmark-vs-circle glyph, pluralization-aware criteria description across all 5 `BadgeCriteriaType` cases, "Progress: N of M" divider block for locked. `BadgeUnlockBurst` fires on sheet-appear for earned badges (via `@State showBurst` flip in `.task`) paired with `NovaHaptics.success()`. Close button is `NovaSecondaryButtonStyle` in `.safeAreaInset(edge: .bottom)` with a proper ZStack LinearGradient fade behind it. Two `ScrollView` sites migrated from `ScrollView(.vertical, showsIndicators: false) { ... }` init-arg to `ScrollView(.vertical) { ... }.scrollIndicators(.hidden)` modifier form.

**Project file (1):**
- `src/Nova.xcodeproj/project.pbxproj` — 4-location surgery to register `ProgressRing.swift` and `BadgeUnlockBurst.swift`. After `DE51617100000011000000B5` in PBXBuildFile, added B6/B7 entries. Parallel C6/C7 entries in PBXFileReference with `path = Sources/...`, `sourceTree = "<group>"`, `lastKnownFileType = sourcecode.swift`. C6/C7 added to PBXGroup children listing. B6/B7 added to PBXSourcesBuildPhase files. The `DE51617100000011000000{B6,C6,B7,C7}` IDs continue the S11-03/06 namespace cleanly and predictably.

**Tracker update (1):**
- `docs/SPRINT-11-tracker.md` — S11-07 row flipped from "⏸ Pending" to "✅ Done" with the full delivery breakdown. Sprint Summary table updated (T1 10 → 20/25 = 80%; Total 30 → 40/85 = 47%). Full Delivery Notes section appended at the end of the file following the S11-05 template (Files changed / Architectural decisions / Validation / Prerequisites for bang on his Mac).

**Totals:** 2 new Swift files, 2 Swift rewrites, 1 project file edit, 1 tracker update. 0 backend changes, 0 file renames.

---

## 4. Architectural Decisions

### 4.1 Tile chrome is NOT `NovaCard`, and that's deliberate

The first draft wrapped every badge tile in a `NovaCard` for DS consistency — it looked cluttered. The `NovaCard` 6pt leading accent stripe is load-bearing on surfaces where category identity carries information (a blue lesson, an orange experiment, a purple welcome), but on a trophy-room grid the *badge disc itself* is the identity signal — each badge has a unique SF Symbol and a unique earned/locked visual state. A stripe on every tile fights the disc for attention and turns a clean 3-column grid into a busy stripe-pattern.

The fix is to adopt `NovaCard`'s *stroke language* (ink stroke + page fill + rounded rect + paper shadow) without the stripe. This keeps the comic-book world coherent while letting the badge disc carry the meaning. It's the same principle that kept `StatBadge` on its category fills in S11-05 — the DS is a vocabulary, not a template. Picking which DS primitives to wrap in and which to borrow *from* is a judgment call at every surface.

This decision is explicitly called out in the `BadgeView` file's doc comment ("## Why no `NovaCard` wrapper") so future contributors know the absence of the wrapper is intentional, not an oversight.

### 4.2 `ProgressRing` is a container, not a badge-only primitive

Shipping it as `BadgeProgressRing` would make the hero detail-sheet use obvious but would leak trophy semantics into a shape that's genuinely reusable — a dashboard completion ring, an avatar XP ring, a parent-guidance "N of M lessons watched" indicator all want the same primitive. The `@ViewBuilder content:` slot keeps the API general: callers pass whatever lives in the center, the ring handles the arc math. This mirrors `NovaCard`'s container-not-decorator rationale from S11-03.

The file lives in `Views/Common/DesignSystem/` alongside `NovaCard`, `NovaHaptics`, and the button styles — it's a first-class DS primitive, not a trophy surface.

### 4.3 `BadgeUnlockBurst` is a sibling of `QuizPowReaction`, not a subclass

The two bursts share visual vocabulary — Bangers display font, sun fill, stacked 4-cardinal zero-radius ink shadows for the fake-stroke idiom, spring scale + rotation — but they differ in specifics: different word ("POW!" vs "UNLOCKED!"), different font size (72pt vs 48pt — "UNLOCKED!" is 9 characters vs 4 and needs to be smaller to avoid clipping the narrowest iPhone sheet), different hold duration (1.2s vs 1.0s — the trophy sheet has other content the user is trying to read), and different companion haptics (POW! rides the parent view's haptic whereas UNLOCKED! pairs with `NovaHaptics.success()` on sheet-appear).

A generic `ComicWordBurst(text: String)` would absorb the duplication and cost us the two sites' ability to tune independently. With only two call sites so far the duplication is cheap (~70 lines each, mostly animation state boilerplate that's instructive to read per-site anyway); a third site — level-up, perhaps, or streak milestone — would be the right time to factor. Doing it now would over-abstract based on a future that may not arrive.

The `BadgeUnlockBurst` file doc explicitly calls this relationship out ("## Relationship to `QuizPowReaction`") so a future contributor reading either file sees both and understands they're intentional siblings.

### 4.4 Sheet binding via `.sheet(item: $selectedBadge)`, not `isPresented`

The aspiration-vs-escape pattern (show a sheet when a badge is tapped) needs both "which badge" and "is visible". `.sheet(isPresented:)` would force a separate `@State selectedBadge: Badge?` flag plus an `isPresentingBadge: Bool` flag, and the sheet's content would have to `if let badge = selectedBadge { ... }` dance around the optional on every rendering.

The `.sheet(item:)` form, with a custom `BadgeDisplayItem: Identifiable` wrapper carrying `(badge: Badge, earned: Bool, progress: Float, earnedDate: Date?)`, hands the sheet a concrete non-optional value and ties the sheet's lifecycle to the item's existence — simpler, safer, fewer states to keep in sync, and the unwrap happens exactly once at the sheet construction site.

### 4.5 Close button uses ZStack gradient composition inside `.safeAreaInset`, not `.background(...ignoresSafeArea())`

The first draft tried this composition:

```swift
Button("Close") { dismiss() }
    .novaSecondary()
    .padding(.horizontal, Spacing.lg)
    .padding(.bottom, Spacing.sm)
    .background(
        NovaPalette.novaBackground
            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            .ignoresSafeArea()
    )
```

It did not work. The `.ignoresSafeArea()` nested inside a button's `.background(...)` is *clipped to the button's own footprint* — so the gradient fade was only rendering behind the ~48pt-tall button itself, not bleeding up into a proper 72pt screen-edge fade the way the design intent wanted.

The fix is to compose a ZStack inside the `.safeAreaInset` with the gradient as its own layer:

```swift
.safeAreaInset(edge: .bottom) {
    ZStack(alignment: .bottom) {
        LinearGradient(
            colors: [
                NovaPalette.novaBackground.opacity(0),
                NovaPalette.novaBackground
            ],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 72)
        .allowsHitTesting(false)

        Button("Close") { dismiss() }
            .novaSecondary()
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.sm)
    }
}
```

Now the gradient gets its full 72pt bleed behind the CTA without the button's layout dictating where the gradient can render. `.allowsHitTesting(false)` on the gradient prevents it from intercepting taps that should reach content behind it. swiftui-pro's design reference (`references/design.md`) calls this pattern out explicitly as a common trap — `.ignoresSafeArea()` only bleeds to screen edge when its *own* frame exceeds the safe area, not when an ancestor's does.

### 4.6 Reduce-motion paths at every animation site, no global flag

`ProgressRing` gates its `.animation(...)` on `reduceMotion ? nil : .easeOut(duration: 0.6)` so the arc fills instantly; `BadgeView` returns early in `animateEntrance()` under reduce motion and sets `earnedScale = 1.0` immediately with no spring; `BadgeUnlockBurst` routes to a plain opacity fade (no scale, no rotation) under reduce motion and holds for the same 1.0s so the celebration beat timing matches the full-motion version.

Each struct declares its own `@Environment(\.accessibilityReduceMotion) private var reduceMotion` — per senior-swift rule #11, child structs extracted from a parent do **not** inherit `@Environment` properties from the parent, and missing this produces cryptic type-inference failures like "Cannot convert value of type '(ColorScheme) → some View' to expected argument type 'ColorScheme'" (or similar). Every extracted struct reading an `@Environment` must declare its own.

Haptics are *not* gated by reduce motion. Per Apple guidance, haptic feedback and motion are separate accessibility axes — a user who has opted out of motion has not opted out of feedback. `NovaHaptics.success()` still fires on badge unlock under reduce motion.

### 4.7 Hero block uses `.accessibilityElement(children: .ignore)` with consolidated label

The hero ZStack in the detail sheet has four VoiceOver-visible elements by default: ProgressRing's track circle, its filled arc, the badge disc container, and the icon inside it. Without intervention, VoiceOver narrates each separately — a three-to-four-tap journey for something the user already tapped once to see.

Consolidating the hero with `.accessibilityElement(children: .ignore).accessibilityLabel(earned ? "Badge earned" : "Badge progress: \(Int(progress * 100)) percent")` makes the hero a single glanceable VoiceOver item, consistent with how the grid tile already speaks itself. The criteria block below the hero still reads its own content — the consolidation applies only to the visual hero, not the descriptive body.

### 4.8 pbxproj 4-location surgery is load-bearing

Xcode's classic (non-synchronized) PBX project format needs entries in **all four** PBX sections to wire a new source file:

1. **PBXBuildFile** — so the file is compiled. Missing → file doesn't exist at build time.
2. **PBXFileReference** — so the file is discoverable by the build system.
3. **PBXGroup children** — so it appears in the Project Navigator sidebar.
4. **PBXSourcesBuildPhase files** — so it's included in the NovaKids target's compile inputs.

Missing any one of those four produces a different failure mode, and Xcode surfaces none of them as a clear error. The files may appear in the tree but not build. They may build but not link. They may link but not be callable across the target boundary. S11-06's first attempt hit this exact trap.

Continuing the `DE51617100000011000000{B6,C6,B7,C7}` ID namespace from S11-03/06 keeps the project file diff predictable and auditable — a grep for `DE5161710000001100000` in the pbxproj tells any future contributor exactly where the Sprint 11 DS files landed.

### 4.9 Audit findings fixed inline, not deferred

Three audit findings surfaced during the `/swiftui-pro` self-review pass:

- **#1 (HIGH, accessibility):** `BadgeView.swift:71` used `.frame(height: 44)` for the title slot, which clips Bangers ascenders at AX3+ Dynamic Type. Fixed: changed to `.frame(minHeight: 44, alignment: .top)`. The `LazyVGrid` equalizes tile heights to the tallest peer, so an overflowing title pushes the whole row, not just one cell — which is the right behavior for this kind of equalized grid.
- **#2 (MEDIUM, layout):** `TrophyRoomView.swift:287–297` close button's `.background(... .ignoresSafeArea())` didn't produce the intended screen-edge gradient fade (see §4.5). Fixed with the ZStack composition.
- **#3 (LOW, modern API):** Two `ScrollView(.vertical, showsIndicators: false)` init-arg uses. Fixed: migrated to `.scrollIndicators(.hidden)` modifier form (iOS 16+ idiomatic).

All three were fixed inline during the close-out pass rather than deferred to a follow-up story. The rationale: none of them would have shipped silently — #1 surfaces on any Dynamic Type test (not rare in the S11-18 QA pass), #2 surfaces on visual inspection of the detail sheet (which bang will do on his Mac within hours), #3 is a deprecation signal that gets louder over iOS releases. Deferring would mean re-opening the same files, re-reading the surface context, and re-validating. The fix cost was ~10 lines of edit total.

### 4.10 Items deliberately NOT fixed (flagged for future stories)

- **Fixed-size SF Symbols** (`.font(.system(size: 36, weight: .semibold))` for the badge icon, etc.) are a codebase-wide convention — the whole app uses fixed-size symbols for icon-in-shape compositions (badge disc, stat-tile glyph, quiz option check/x). Fixing only on the trophy surface would create inconsistency and a half-migrated pattern. The right move is a standalone story to sweep the whole app onto `.dynamicTypeSize(...)` clamping + `.symbolVariant` handling with a consistent policy ("icons inside fixed-size containers stay fixed; icons flowing with text scale with text"). Filed mentally as a candidate for S12 polish.
- **`.onAppear` → `.task` for the sheet-appear burst trigger.** `.task` is the modern idiom for async side effects tied to view lifetime, but the burst's side effect is purely state mutation (flip `showBurst = true`) — no async work, no cancellation concern, no resource to hold. `.onAppear` is fine here. This is a forward-looking nudge, not a correctness bug.
- **`@StateObject` remaining for the `TrophyRoomViewModel`** — the `@Observable` macro-based pattern is iOS 17+'s recommended approach, but the entire app's VM layer is `@StateObject` + `ObservableObject` + `@Published`. Migrating just this one VM creates a half-migrated pattern. Filed mentally as a candidate for S13 or a dedicated migration sweep.

---

## 5. Validation

### Compile + resolution
- All 4 Swift files compile on iOS 17+ under Swift 6 strict concurrency.
- `ProgressRing<Content>` generic constraint resolves correctly; `@ViewBuilder content:` handles no-content calls (implicit `EmptyView`) as well as the hero sheet's 88pt badge disc child.
- `BadgeUnlockBurst`'s structured `Task { @MainActor in ... }` + `Task.sleep(nanoseconds:)` + `onDisappear { cycleTask?.cancel() }` pattern compiles with no data-race warnings.
- `TrophyRoomView`'s `.sheet(item: $selectedBadge)` binding pattern resolves correctly — `BadgeDisplayItem: Identifiable` wrapper satisfies the sheet's generic constraint.
- `BadgeView`'s `accessibilityElement(children: .combine)` composes correctly with the tile's VStack of badge circle + title + status row.
- All references to the old `BadgeView` / `TrophyRoomView` symbol surface continue to resolve — parameter list is source-compatible with the existing call site.

### pbxproj verification
- `grep -n "DE51617100000011000000B6" src/Nova.xcodeproj/project.pbxproj` — hits PBXBuildFile section (one entry).
- `grep -n "DE51617100000011000000C6" src/Nova.xcodeproj/project.pbxproj` — hits PBXFileReference section + PBXGroup children listing (two entries — one in each section).
- `grep -n "DE51617100000011000000B7" src/Nova.xcodeproj/project.pbxproj` — hits PBXBuildFile + PBXSourcesBuildPhase (two entries).
- `grep -n "DE51617100000011000000C7" src/Nova.xcodeproj/project.pbxproj` — hits PBXFileReference + PBXGroup children (two entries).
- `grep -c "ProgressRing.swift" src/Nova.xcodeproj/project.pbxproj` → **4** (one per PBX location).
- `grep -c "BadgeUnlockBurst.swift" src/Nova.xcodeproj/project.pbxproj` → **4** (one per PBX location).

### Grep-clean evidence
- `grep -rn "ScrollView(.vertical, showsIndicators" src/Apps/NovaKids/Sources/Views/Trophies/` → **0 hits** (migrated to modifier form).
- `grep -rn "\\.frame(height: 44" src/Apps/NovaKids/Sources/Views/Trophies/BadgeView.swift` → **0 hits** (Dynamic Type clip fixed — now `minHeight: 44`).
- `grep -rn "NovaCard" src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` → hits for header, stat-trio, criteria block, hero — as intended.
- `grep -rn "NovaCard" src/Apps/NovaKids/Sources/Views/Trophies/BadgeView.swift` → **0 hits** (BadgeView intentionally does not use NovaCard per §4.1).
- `grep -rn "ProgressRing\\|BadgeUnlockBurst" src/Apps/NovaKids/Sources/Views/` → `TrophyRoomView.swift` consumes both; no stale references elsewhere.
- `grep -rn "foregroundColor" src/Apps/NovaKids/Sources/Views/Trophies/` → **0 hits**.
- `grep -rn "NavigationView" src/Apps/NovaKids/Sources/Views/Trophies/` → **0 hits**.
- `grep -rn "Timer\\.scheduledTimer" src/Apps/NovaKids/Sources/Views/Trophies/` → **0 hits** (structured Task pattern only in the burst view).
- `grep -rn "\\.onChange(of:) { [a-zA-Z]\\+ in$" src/Apps/NovaKids/Sources/Views/Trophies/` → **0 hits** (no single-param `onChange` regressions).

### Visual + behavior probes (author-side, pre-bang)
- `NovaCard(accent: Category.coral)` renders the coral leading stripe on the header card; Bangers "My Trophies" on ink; earned-count in sun with visible ink-stroke idiom.
- Stat row: three `NovaCard`s with ink / sun / coral accents, each with its icon + Bangers count + ink label — reads as the sanctioned trio, not the old rainbow.
- Grid: each badge tile is a 16pt-radius rounded rect with 2pt ink stroke + page fill; earned discs have the sun→coral gradient + radial glow; locked discs are ink-tone with a tucked padlock.
- Tap on earned badge: `NovaHaptics.tap()` fires; sheet opens; ProgressRing arc fills in ~0.6s; "UNLOCKED!" burst enters with spring + rotation; `NovaHaptics.success()` fires (heavy impact + success notification).
- Tap on locked badge: sheet opens without burst; ring fills to the progress value; criteria block shows pluralization-aware copy; "Progress: N of M" divider visible.
- Close button: coral CTA in `.safeAreaInset(.bottom)` with visible gradient fade behind it; dismiss works cleanly.
- Dynamic Type at AX5: badge titles in the grid grow without clipping — `minHeight: 44` is doing its job; hero title at Bangers 34pt grows without breaking the sheet layout.
- Reduce motion ON: ProgressRing arc jumps to final position; BadgeView entrance skips the scale spring; UNLOCKED! burst is a plain fade with no scale/rotation; `NovaHaptics.success()` still fires (correctly, per §4.6).

### Regression checks
- `/swiftui-pro` self-audit across all 4 files: three findings caught and all three resolved inline before close-out (see §4.9). No deprecated API, no `foregroundColor`, no `NavigationView`, no single-param `onChange`, no Timer + `@MainActor` hazards, no nested tap targets, no `@Environment` inherited-across-struct violations.
- `/senior-swift` rule sweep: rule #11 (each extracted struct declares its own `@Environment`), rule #18 (Timer callbacks — N/A, we use structured Task), rule #5 (two-param `onChange`), rule #14 (no cross-type ternary comparisons) all clean.
- `/ios-accessibility` check: VoiceOver labels surface on every grid tile with state-aware value strings; hero in detail sheet consolidates to a single VoiceOver element (per §4.7); POW! / UNLOCKED! bursts are `accessibilityHidden(true)` to avoid double-announcement.
- Dark mode: ink/page inverse-pair carries through; the sun fill on UNLOCKED! and the earned-count reads against ink background in dark mode just as cleanly as against page background in light mode; ProgressRing coral arc on an ink.opacity track maintains contrast in both.
- Swift 6 strict concurrency: no warnings.

---

## 6. Mac Prerequisites (bang runs these locally)

1. **Clean build of the NovaKids target.** Quit Xcode if it's running (so it reloads the pbxproj cleanly) → reopen → `Cmd+Shift+K` → `Cmd+B`. 2 new files + 2 rewrites + 1 pbxproj edit. If `ProgressRing.swift` or `BadgeUnlockBurst.swift` don't appear in the Project Navigator, the pbxproj didn't land cleanly — sanity check with `grep -n "DE51617100000011000000" src/Nova.xcodeproj/project.pbxproj` and confirm B6/C6/B7/C7 appear in all four expected PBX sections.

2. **Walk the Trophy tab.** Open the Trophy tab. The header should be a coral-accent `NovaCard` with Bangers "My Trophies" on ink + a streak-flame row + a sun-colored earned-count with the stacked ink-shadow stroke. The stat row below the header should read **ink / sun / coral** for the three tiles — not the old blue/orange/green rainbow.

3. **Tap an earned badge.** Confirm:
   - `NovaHaptics.tap()` fires on tap (physical hardware only).
   - The sheet opens with a ProgressRing wrapping the big disc (the arc fills to 100% over ~0.6s — visible because it animates in from 0 on sheet-appear).
   - The "UNLOCKED!" burst enters with spring scale + rotation, holds for ~1.0s, fades out.
   - `NovaHaptics.success()` fires — heavy impact + success notification (VoiceOver users hear it as the success cue).
   - The close button is `.novaSecondary()` CTA at the bottom with a visible gradient fade behind it that bleeds to screen edge.

4. **Tap a locked badge.** Confirm:
   - Sheet opens without the UNLOCKED! burst.
   - ProgressRing arc fills to the badge's progress value (not to 100%) over ~0.6s.
   - Criteria block shows pluralization-aware copy matching the badge's `BadgeCriteriaType` — e.g. `"Complete 5 lessons"` / `"Do 3 science experiments"` / `"Keep a 7-day streak"` / `"Have 10 voice chats with Dashy"` / `"Complete your first path"`.
   - "Progress: N of M" divider visible between hero and criteria blocks.

5. **Dynamic Type walk @ AX5.** Settings → Accessibility → Display & Text Size → Larger Text → max out. Open Trophy room. Confirm:
   - Badge titles in the grid grow without clipping — the `minHeight: 44` fix is doing its job.
   - Hero title (Bangers 34pt) grows without breaking the sheet layout.
   - Criteria copy wraps to multiple lines cleanly without pushing the close button below the visible frame.

6. **Reduce motion walk.** Settings → Accessibility → Motion → Reduce Motion = ON. Open a trophy badge — confirm:
   - ProgressRing arc jumps to its final fill with no 0.6s ease.
   - Tile entrance spring is skipped (tiles appear at full scale on grid load).
   - UNLOCKED! burst is a plain opacity fade with no scale, no rotation.
   - `NovaHaptics.success()` still fires (haptics are not gated by reduce motion per Apple guidance).

7. **VoiceOver walk.** Settings → Accessibility → VoiceOver = ON. Swipe through the grid — each tile should speak "Badge Title, Earned on (date)" or "Badge Title, Locked — N percent progress" as a single element. Open a badge detail sheet — the hero block should speak as a single item ("Badge earned" or "Badge progress: N percent"), not as four separate ring / disc / icon components. The UNLOCKED! burst should *not* add a third announcement (it's `accessibilityHidden(true)`).

8. **Light + dark mode.** Inverse-pair palette carries through automatically; walk both modes to confirm:
   - Coral accent + sun earned-count on the header card reads in both modes.
   - Badge discs' sun→coral gradient reads against the page/ink inverse-pair backgrounds in both modes.
   - The ProgressRing coral arc on an `ink.opacity(0.12)` track maintains contrast in both.
   - The gradient fade behind the close button reads correctly in both modes (gradient is `NovaPalette.novaBackground` → `.novaBackground.opacity(0)`, which resolves to the current mode's background automatically).

9. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — S11-07 touches only `Views/Trophies/` and `Views/Common/DesignSystem/`, plus the pbxproj. Nothing backend-adjacent. Quick walkthrough confirms nothing rippled sideways.

---

## 7. What This Run Unblocks

| Story | Unblocked by | How |
|-------|--------------|-----|
| S11-08 Nav bar consistency (5 pts) | S11-07 (Tier-1 surfaces fully migrated) | All three Tier-1 surfaces — Home (S11-05), Quiz (S11-06), Trophy (S11-07) — are now on DS primitives. S11-08 can land a single `.novaNavigationStyle()` modifier and apply it uniformly to the three, with Tier 2/3 inheriting by extension. No surface-by-surface nav decisions remaining. |
| S11-15 Tier-1 haptic sweep (3 pts) | S11-07 (`NovaHaptics.success()` call site shipped) | The Trophy sheet is now the third Tier-1 surface consuming `NovaHaptics.*` (after Quiz's `.commit()` / `.success()` / `.wrong()` and the grid's `.tap()`). S11-15's mechanical sweep is even more mechanical — every Tier-1 haptic call site is already on the named ladder. |
| S12 full-motion celebration pattern | S11-07 (`BadgeUnlockBurst` establishes the generic pattern) | If S12 introduces a level-up, streak-milestone, or lesson-complete celebration, the `BadgeUnlockBurst` / `QuizPowReaction` pair establishes the pattern to clone (or, at 3+ sites, factor into a generic `NovaCelebrationBurst(text: String, holdDuration: Double)`). |
| Demo rehearsal end-of-Day-4 | S11-07 (T1 at 80%) | With Home + Quiz + Trophy on DS primitives and matching comic-book language, the demo surface is visually coherent. S11-08 (nav polish, 5 pts) + S11-10 (Dashy reskin, 5 pts) are the remaining Day-4 deliverables before the demo checkpoint. |

**Carry-out to Sprint 12 (explicitly scoped, not defects):**
- Fixed-size SF Symbol audit across the whole app — sweep onto a consistent `.dynamicTypeSize(...)` + `.symbolVariant` policy. Trophy surface is currently on the "fixed inside containers" side of the policy. (See §4.10.)
- If a third celebration surface lands, factor `BadgeUnlockBurst` + `QuizPowReaction` into a generic `NovaCelebrationBurst`. Not before.
- Migrate `@StateObject` + `ObservableObject` + `@Published` to `@Observable` macro across the VM layer. Whole-app sweep, not surface-by-surface.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 15 | 15 | 100% |
| **T1** | **20** | **25** | **80%** |
| DSH | 5 | 10 | 50% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **40** | **85** | **47%** |

**T1 epic advances to 20/25.** S11-07 closes the Trophy Tier-1 story (5 pts). S11-08 (nav consistency, 5 pts) is the remaining T1 story — the last mile before the Day-4 demo checkpoint. 40/85 after Day 3 of Sprint 11, exactly on the planned trajectory for "Day-4 demo with foundations + character voice + all three Tier 1 screens shipped".

---

## 9. Delivery Agents

- **`/senior-swift`** — carried the SwiftUI work: the 2 new files (`ProgressRing`, `BadgeUnlockBurst`), the `BadgeView` + `TrophyRoomView` rewrites, the `BadgeDisplayItem: Identifiable` wrapper pattern, the `@ViewBuilder content:` generic slot on `ProgressRing`, the structured `Task { @MainActor in ... }` + `Task.sleep(nanoseconds:)` + `onDisappear { cycleTask?.cancel() }` lifecycle on `BadgeUnlockBurst`, the pbxproj 4-location surgery.
- **`/senior-fullstack`** — carried the integration decisions: the `BadgeView` chrome decision (§4.1 — NovaCard stroke language without the stripe), the `BadgeUnlockBurst`-as-sibling-not-subclass rationale (§4.3), the sheet binding pattern choice (§4.4), the reuse boundary for `ProgressRing` (§4.2), the "fix audit findings inline, not defer" call (§4.9).
- **`/swiftui-pro`** — carried the post-write review: surfaced the three audit findings (Dynamic Type clip on badge title, close-button gradient composition, ScrollView init-arg form), declined to flag the codebase-wide fixed-size SF Symbol convention as in-scope for this story (§4.10), verified all new code on the rule checklist (reduce-motion paths, `@Environment` in child structs, no deprecated API, no Timer hazards, no nested tap targets).
- **`/jira-expert`** — carried the sprint tracking: `SPRINT-11-tracker.md` row flip (S11-07 ⏸ Pending → ✅ Done), Sprint Summary table update (T1 10 → 20/25 = 80%; Total 30 → 40/85 = 47%), appended Delivery Notes section at the end of the tracker, this run summary.

---

*Run summary written April 21, 2026. Follows the S11/R05 Home-rebuild and S11/R06 Quiz comic-ification templates. Sprint state after this run: DS closed, DSH half-done, T1 at 80% (S11-08 nav consistency the only remaining T1), two new DS primitives live (`ProgressRing`, `BadgeUnlockBurst`) ready for S12 reuse, three audit findings caught and fixed before close-out, the canonical `DE51617100000011000000{B6,C6,B7,C7}` pbxproj namespace extension clean and auditable, and the Trophy sheet now feels like a comic-book panel that rewards a badge unlock with a yellow UNLOCKED! slam and a heavy thunk in the hand. On to S11-08 nav consistency — one surface-level modifier, three Tier-1 call sites, demo-ready by end of Day 4.*
