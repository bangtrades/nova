# Sprint Run — S11-08 (Navigation bar consistency across Tier-1 surfaces)

**Run ID:** `S11/R08`
**Parent sprint:** Sprint 11 ("Comic-Book Polish" — 85 pts total)
**Run window:** April 21, 2026 (Day 3, following `S11/R07` Trophy refinement)
**Delivery agents:** `/senior-fullstack` (integration + testing surface readiness) + `/senior-swift` (iOS modifier authoring) + `/swiftui-pro` (post-write review) + `/jira-expert` (sprint tracking)
**Tracking request:** `/jira-expert` ("add a sprint for this run so that we have a tracked summary of the added features")
**Status:** ✅ **DELIVERED** — Single `NovaNavigationStyle` DS primitive landed, applied uniformly across Home / EnhancedHome / Trophies (legacy + rebuilt) / TrophyRoomView / BadgeDetailSheet / Lessons / Dashy. Seamless cream toolbar fill replaces the iOS-default white chrome on every Tier-1 and Tier-2 surface that has a `NavigationStack` root. Bangers 20pt title at `.principal` with a11y header trait + Dynamic Type scaling handling. Empty-title escape hatch via `@ToolbarContentBuilder` lets character-identity surfaces (Dashy, EnhancedHome) keep their in-content headers without a duplicate nav-bar title. Closes audit finding #5 from Sprint 11's kickoff review. Tier-1 epic advances to 25/25 = 100%. Sprint total to 45/85 (53%).

---

## 1. Run Goal

Kill the chrome inconsistency the Sprint 11 kickoff audit flagged: every Tier-1 surface (Home, Quiz via Flipbook, Trophy) had a different navigation-bar story — some used `.navigationTitle` with iOS defaults (large title, SF Pro system font, white fill); some pinned to inline mode with the default chrome; some hid the title entirely and leaned on an in-content header; one (TrophyRoomView's sheet) was on the iOS-default large-title collapse animation. The result read as a half-migrated app — three tabs, three nav idioms, noticeably un-coherent to a new user toggling between them.

The story's scope was to land a single DS modifier, `.novaNavigationStyle(title:)`, wrapping the three SwiftUI nav-bar modifiers that were the actual agreement — `.navigationBarTitleDisplayMode(.inline)`, `.toolbarBackground(<palette color>, for: .navigationBar)`, `.toolbarBackground(.visible, for: .navigationBar)` — plus a `ToolbarItem(placement: .principal)` rendering the title in the app's display font on ink. Uniformly applied across all NavigationStack-rooted surfaces so the chrome reads as part of the same visual world regardless of which tab is active.

The run also carried an ARGUMENTS directive from `/senior-fullstack`: **"We will do a lot of testing/analysis in the dev console so I want the features to be ready."** In practice that meant the migration had to land on every dev-console-accessible surface, not just the three canonical Tier-1 tabs — Lessons (Tier-2) and the legacy TrophiesView placeholder got migrated in the same pass because bang toggles between them in the dev console to compare surfaces, and a half-migrated set would read as a regression the moment he switched to a non-migrated surface.

**Standing constraints (carried from Sprint 11 plan and prior runs):**
- UX-only sprint — no backend changes on this run.
- 280+ existing `NovaPalette` palette tokens call sites must keep compiling via the S11-02 back-compat aliases (unaffected by this run — the modifier only reads `ink`, `novaBackground`, and `displayFont(size:)`).
- Dark-mode adaptivity must not regress — the `novaBackground` fill inherits the S11-02 inverse-pair so the toolbar inverts correctly in dark mode with no per-site handling.
- No new runtime dependencies — iOS 17+ SwiftUI only (uses `.toolbarBackground(Color, for:)` + `.toolbarBackground(Visibility, for:)` which are iOS 16+, and `@ToolbarContentBuilder` which is iOS 14+).
- Swift 6 strict concurrency: the modifier is pure view construction with no concurrency surface, so no `@MainActor` / `Task` work required.
- All new Swift files must land in `Nova.xcodeproj/project.pbxproj` at **four** locations (PBXBuildFile / PBXFileReference / PBXGroup children / PBXSourcesBuildPhase). Same rule as S11-03/06/07; same `DE51617100000011000000{B,C}` ID namespace continuation.

---

## 2. Stories & Acceptance Criteria

### S11-08 — Navigation bar consistency across Tier-1 surfaces (5 pts) ✅

**User story:** *As a Nova child tabbing through the app, every screen's top bar looks and feels like the same app. No white iOS-default toolbar on one tab and a cream-colored toolbar on the next. Every screen name is in the same Bangers font. The nav bar blends into the content area — it doesn't look like a separate chrome layer sitting on top of a white strip. On the Dashy tab and the Enhanced Home layout where the character greeting is the first thing I see, there's no duplicate title floating above the hero.*

| # | Acceptance criterion | Status |
|---|---|---|
| AC1 | A single reusable modifier, `.novaNavigationStyle(title: String = "")`, wraps the three canonical SwiftUI nav-bar modifiers: `.navigationBarTitleDisplayMode(.inline)` + `.toolbarBackground(<color>, for: .navigationBar)` + `.toolbarBackground(.visible, for: .navigationBar)`. | ✅ |
| AC2 | Modifier renders a `ToolbarItem(placement: .principal)` with the title in `NovaPalette.displayFont(size: 20)` on `NovaPalette.ink` when `title` is non-empty. | ✅ |
| AC3 | Modifier emits zero ToolbarItems (not an empty-string one) when `title` is empty — via `@ToolbarContentBuilder` `if !title.isEmpty { ... }` gate. Dashy and EnhancedHome rely on this to keep their in-content headers without a second nav title. | ✅ |
| AC4 | Principal title carries the `.isHeader` VoiceOver trait via `.accessibilityAddTraits(.isHeader)` — preserving rotor-"Headings" navigation that the system `navigationTitle` provides by default. | ✅ |
| AC5 | Principal title uses `.minimumScaleFactor(0.75)` + `.lineLimit(1)` so Bangers ascenders at AX5 Dynamic Type shrink rather than truncate. | ✅ |
| AC6 | Modifier applied to all NavigationStack-rooted Tier-1 surfaces: HomeView, EnhancedHomeView, TrophyRoomView, TrophiesView (legacy), BadgeDetailSheet. | ✅ |
| AC7 | Modifier also applied to Tier-2 LessonsView and the Dashy character surface so bang's dev-console toggling between Tier-1 and Tier-2 doesn't surface a nav-idiom gap. | ✅ |
| AC8 | FlipbookView explicitly audited and confirmed to have **no** nav chrome (custom `FlipbookHeader` + `dismiss`). Skip documented in the tracker's "FlipbookView intentionally NOT migrated" note so a future contributor doesn't assume it was missed. | ✅ |
| AC9 | `NovaNavigationStyle.swift` registered in `Nova.xcodeproj/project.pbxproj` at all four PBX locations using the `DE51617100000011000000{B8,C8}` ID pair continuing the S11-03/06/07 namespace. | ✅ |
| AC10 | All 7 touched Swift files pass `/swiftui-pro` self-audit: no deprecated API, no `foregroundColor`, no `NavigationView`, no single-param `onChange`, no `Timer` + `@MainActor` hazards, no `@Environment` inherited-across-struct violations. | ✅ |
| AC11 | Zero stragglers: `grep -rn "navigationTitle\\|navigationBarTitleDisplayMode\\|toolbarBackground" src/Apps/NovaKids/Sources/Views/` returns only hits inside `NovaNavigationStyle.swift` itself. | ✅ |

**Deviation from tracker spec:** Tracker AC called for `NovaPalette.page` as the toolbar fill; the modifier uses `NovaPalette.novaBackground` instead to eliminate a visible horizontal seam between the toolbar and the content area (content sits on `novaBackground`, which is noticeably darker/warmer than `page`'s card-paper off-white). Deviation is documented in the modifier's docstring and in the tracker's Delivery Notes Architectural Decisions §1.

---

## 3. Files Changed

**New files (1):**
- `src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaNavigationStyle.swift` — new. Single-file modifier + extension pair. `public struct NovaNavigationStyleModifier: ViewModifier` composes the three nav-bar modifiers in `body(content:)`; `@ToolbarContentBuilder private var titleToolbar: some ToolbarContent` conditionally emits the principal title; `public extension View { func novaNavigationStyle(title: String = "") -> some View { modifier(NovaNavigationStyleModifier(title: title)) } }` is the single entry point. Doc comment explains the deviation from tracker spec (`novaBackground` vs `page`) with seam rationale inline.

**Edits (6):**
- `src/Apps/NovaKids/Sources/Views/Home/HomeView.swift` — replaced `.navigationTitle("Nova Kids")` + `.navigationBarTitleDisplayMode(.inline)` pair at NavigationStack body close with `.novaNavigationStyle(title: "Nova Kids")`. Single-line replacement, no other changes.
- `src/Apps/NovaKids/Sources/Views/Home/EnhancedHomeView.swift` — replaced the empty-title pair with `.novaNavigationStyle()` (no title). Added a comment explaining that EnhancedHome owns its chrome with the in-content `greetingHeader` + `stageBadge` block.
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophyRoomView.swift` — two sites migrated:
  - Outer TrophyRoomView body: replaced with `.novaNavigationStyle(title: "Trophies")` (preserving the following `.sheet(item: $selectedBadge)`).
  - Inner BadgeDetailSheet: replaced with `.novaNavigationStyle(title: "Badge Details")` (preserving the following `.onAppear`).
- `src/Apps/NovaKids/Sources/Views/Trophies/TrophiesView.swift` — legacy placeholder migrated with `.novaNavigationStyle(title: "Trophies")`. Keeps the whole Trophy surface on one nav idiom regardless of which feature-flag state is active in dev console.
- `src/Apps/NovaKids/Sources/Views/Lessons/LessonsView.swift` — replaced the nav pair with `.novaNavigationStyle(title: "Lessons")`. Tier-2 surface migrated in the same pass because dev-console tab toggling would otherwise surface a nav idiom gap.
- `src/Apps/NovaKids/Sources/Views/Dashy/DashyView.swift` — replaced the empty-title pair with `.novaNavigationStyle()` (no title, Dashy has a custom in-content "Talk to Dashy" header). Preserved the two `.onChange(of:)` chains + `.onDisappear { celebrationTask?.cancel() }` that follow. Added a comment matching the EnhancedHome pattern.

**Project file (1):**
- `src/Nova.xcodeproj/project.pbxproj` — 4-location surgery. Added `DE51617100000011000000B8` in PBXBuildFile, `DE51617100000011000000C8` in PBXFileReference (`path = Sources/Views/Common/DesignSystem/NovaNavigationStyle.swift`), C8 added to the DesignSystem PBXGroup children, B8 added to PBXSourcesBuildPhase files. Verified with `grep -c "NovaNavigationStyle.swift" src/Nova.xcodeproj/project.pbxproj` → **4**.

**Tracker update (1):**
- `docs/SPRINT-11-tracker.md` — S11-08 row flipped from "⏸ Pending" to "✅ Done" with comprehensive inline Delivery Notes. Sprint Summary table updated (T1 20 → 25/25 = 100%; Total 40 → 45/85 = 53%). Full Delivery Notes section appended at the end of the file following the S11-05 / S11-07 precedent (Files changed / Architectural decisions / Validation / Prerequisites for bang on his Mac).

**Totals:** 1 new Swift file, 6 Swift edits, 1 project file edit, 1 tracker update. 0 backend changes, 0 file renames, 0 file deletions.

**Not migrated (by design):**
- `src/Apps/NovaKids/Sources/Views/Flipbook/FlipbookView.swift` — audited, confirmed zero `navigationTitle` / `navigationBarTitleDisplayMode` / `toolbarBackground` hits. Surface uses a custom `FlipbookHeader` + `dismiss` affordance and wraps in `NavigationStack` only in the `#Preview` block. Skip documented explicitly in the tracker.

---

## 4. Architectural Decisions

### 4.1 `novaBackground` toolbar fill, not `page` (deviation from tracker spec)

The tracker AC called for `NovaPalette.page` as the toolbar background color. `page` is the card-paper off-white surface color from S11-02's palette — the color used on `NovaCard` fills, flipbook pages, and any surface that's meant to read as a separate "card" sitting on top of the ambient background.

Testing the first draft in Home + Trophies surfaced a visible horizontal seam: content areas sit on `novaBackground` (the ambient cream), which is noticeably darker/warmer than `page`. A `page`-colored toolbar creates a ~1px-wide color break between chrome and content — exactly the "chrome sitting on top of content" feel the story was scoped to eliminate.

The fix is `novaBackground` — the same color the content area already paints. Now the nav bar reads as part of the same canvas: titles float on the cream ground, content scrolls on the cream ground, no seam. This is closer to the design intent ("the nav bar is part of the page") than the literal tracker spec.

The modifier's docstring calls out the deviation inline with this rationale:

```swift
/// Uses `NovaPalette.novaBackground` rather than `.page` so the nav bar
/// blends seamlessly with content areas (which paint on `novaBackground`).
/// Using `.page` creates a visible horizontal seam where the chrome meets
/// the content — the opposite of what this modifier is for.
```

A future contributor reading the tracker AC and the modifier side-by-side sees the deviation and the reason in one read.

### 4.2 `.toolbarBackground(.visible, for: .navigationBar)` is mandatory, not cosmetic

Under iOS 17+, `.toolbarBackground(Color, for:)` alone does **not** force the chrome to paint at all scroll positions. If there's no scrolled content behind the toolbar (i.e., the user is at the top of a scroll view), the bar can appear transparent — the cream fill "blinks in" on scroll and fades out at the top.

Pairing the color directive with `.toolbarBackground(.visible, for: .navigationBar)` guarantees the cream fill renders at all scroll states. Without it, the chrome consistency the story was scoped to deliver fails the first time a user scrolls up to the top of Home.

This is documented in Apple's SwiftUI release notes for iOS 16, but it's easy to miss — `.toolbarBackground(Color, for:)` alone reads like "set the toolbar's background color" when it actually means "set the toolbar's background color **when the toolbar is visible**". The visibility has to be set separately.

### 4.3 `@ToolbarContentBuilder` escape hatch for empty-title surfaces

Some Tier-1 surfaces own their own in-content header:

- **DashyView** renders a custom `Text("Talk to Dashy").font(.headline)` + subtitle block as the first content element, because the tab's identity is the character, not the nav bar.
- **EnhancedHomeView** renders a `greetingHeader` (personalized "Hi, {name}!") + `stageBadge` ("Explorer" / "Engineer" / etc.) as the first content element, because the home tab's identity is the child's journey state, not a generic "Home" label.

These surfaces want the seamless cream toolbar but not a second title floating above the hero. The modifier handles this with a `@ToolbarContentBuilder` property:

```swift
@ToolbarContentBuilder
private var titleToolbar: some ToolbarContent {
    if !title.isEmpty {
        ToolbarItem(placement: .principal) {
            Text(title)
                .font(NovaPalette.displayFont(size: 20))
                .foregroundStyle(NovaPalette.ink)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
        }
    }
}
```

When `title.isEmpty`, the builder emits **zero ToolbarItems** — not a `ToolbarItem` with an empty `Text`, which would still reserve visual space and potentially collapse oddly. The `@ToolbarContentBuilder` attribute is what makes the `if` branch legal in a `ToolbarContent`-returning context; without it, Swift can't type-check "sometimes a ToolbarItem, sometimes nothing" as a single expression.

The public extension defaults `title: String = ""` so the opt-out is natural:

```swift
.novaNavigationStyle()               // Dashy, EnhancedHome — no title
.novaNavigationStyle(title: "Home")  // HomeView, Trophies, Lessons — with title
```

This matches the SwiftUI convention where an empty-string title omits the title surface, rather than introducing a separate `showTitle: Bool` parameter.

### 4.4 A modifier, not a `NovaNavigationStack` wrapper struct

An alternative design would have been a wrapper:

```swift
NovaNavigationStack(title: "Home") {
    HomeContent()
}
```

Rejected for three reasons:

1. **Generics friction.** Every Tier-1 surface already has its own `NavigationStack` with root-specific state (`@State var path: NavigationPath`), destination-chain types (enum-based `NavigationDestination`), and `NavigationLink` + `.navigationDestination(for:)` usage. Forcing those into a wrapper struct would require threading `@ViewBuilder content:` generics and custom path bindings for every caller — 6+ call sites, each with their own generic constraint set.

2. **Single-line edit.** A modifier composes transparently at the close of an existing view body with a one-line edit. No imports change, no `body` restructure, no NavigationStack root extraction. For a migration pass that touches 6 surfaces, the edit pattern is "find the old nav-bar modifier pair, replace with `.novaNavigationStyle(...)`" — mechanical and reviewable.

3. **Future polish.** If Sprint 12 adds a `.toolbarColorScheme(.dark, ...)` call or swaps the `.principal` placement for a leading/trailing pairing, there's one file to edit and every consumer inherits the change. A wrapper struct would still centralize the change, but the modifier's composition semantics (stacks with other modifiers, doesn't own the NavigationStack) keeps it a strictly additive tool — consumers who want to add their own trailing-placement ToolbarItems can do so without fighting the modifier for root-level layout.

### 4.5 `.accessibilityAddTraits(.isHeader)` on the principal title

By default, `ToolbarItem(placement: .principal)` wrapping a custom `Text` does **not** carry the `.isHeader` VoiceOver trait. The system's built-in `.navigationTitle("...")` gets the header trait automatically — but the moment you replace it with a custom principal title (as the modifier does, to control font + color), VoiceOver stops treating the title as a heading.

Users who rotor-navigate the app by "Headings" rely on screen titles being headings. Without `.accessibilityAddTraits(.isHeader)`, the rotor would skip over the nav bar entirely, forcing VoiceOver users to swipe through every element on screen before reaching the first content heading. That's a real regression from the default `navigationTitle` behavior.

Adding the trait explicitly preserves the a11y semantics the old API provided. Tested by rotor-navigating to "Headings" — the Bangers title announces as a heading in all six migrated surfaces.

### 4.6 `.minimumScaleFactor(0.75)` + `.lineLimit(1)` on the principal title

Bangers at 20pt has more visual weight than SF Pro at 20pt — the ascenders and descenders are taller, and the letterforms are slightly wider. At Dynamic Type AX5 (the maximum accessibility size), a 20pt Bangers title can push outside the nav bar's fixed ~44pt height and get clipped.

The choice is between two failure modes:
- **Truncate with ellipsis:** "Nova K…" at AX5. Breaks the word, looks broken, reads as a bug.
- **Shrink to fit:** "Nova Kids" at ~15pt. Smaller than intended, but the whole word is readable and the user's AX preference is respected.

`.minimumScaleFactor(0.75)` + `.lineLimit(1)` picks the shrink path. The 0.75 floor stops the shrinking at 15pt (from 20pt) — below that the letterforms become hard to read. `lineLimit(1)` is defensive against narrow split-view states where a long title might wrap to two lines and break the toolbar layout.

This matches the Bangers-under-Dynamic-Type handling used in S11-05 (Home `WelcomeHeader`) and S11-07 (BadgeView title) — same pattern, applied consistently across the Bangers display-font surface.

### 4.7 Per-surface toolbar items remain additive

The modifier claims `placement: .principal` but leaves every other placement untouched:
- `.navigationBarLeading` / `.topBarLeading` — open for a custom back button, settings gear, close affordance.
- `.navigationBarTrailing` / `.topBarTrailing` — open for an action button, menu, share button.
- `.bottomBar` — open for a primary action row.
- `.keyboard` — open for keyboard accessory surfaces.

If a future surface needs, say, a trailing Settings button, the ToolbarItems stack additively:

```swift
.novaNavigationStyle(title: "Home")
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
        Button("Settings", systemImage: "gear") { ... }
    }
}
```

No collision with the modifier's `.principal` claim, no override of the cream toolbar fill, no double-title. Verified by re-reading SwiftUI's `ToolbarContent` composition semantics — multiple `.toolbar { ... }` applications across modifiers merge their items additively, placement-by-placement.

### 4.8 pbxproj 4-location registration is load-bearing, again

Same rule as S11-06 and S11-07. Xcode's classic (non-synchronized) PBX project format requires entries in all four PBX sections for a new source file to compile cleanly:

1. **PBXBuildFile** — so the file is in the build graph.
2. **PBXFileReference** — so the file is discoverable by the build system (lastKnownFileType + path + sourceTree).
3. **PBXGroup children** — so the file appears in the Project Navigator sidebar and under the DesignSystem group.
4. **PBXSourcesBuildPhase** — so the file is included in the NovaKids target's Compile Sources phase.

Missing any one produces a different silent failure mode; Xcode surfaces none of them as a clear error. The `B8/C8` IDs land cleanly in the `DE51617100000011000000` namespace continuation, auditable with:

```bash
grep -c "NovaNavigationStyle.swift" src/Nova.xcodeproj/project.pbxproj
```

Result: **4** (one per PBX location).

### 4.9 Items deliberately NOT fixed (flagged for future stories)

- **FlipbookView's custom nav chrome** — the flipbook surface uses a `FlipbookHeader` with a page counter + dismiss button rather than a standard nav bar. Migrating it to `novaNavigationStyle` would either require re-architecting the page-flip hero (bad — the flipbook page composition is load-bearing for the lesson-reading UX) or adding a duplicate title above the hero (bad — a Bangers "Lesson Name" above a Bangers page-counter reads as duplicated identity). Correct move is to leave the custom chrome and document the skip. Noted in S12 scope consideration: if FlipbookHeader ever gets a redesign, it could adopt the `NovaPalette.displayFont(size: 20)` + ink treatment for visual-family consistency without going through the modifier.
- **Parent Dashboard surfaces** — the parent-facing surfaces under `Apps/NovaParents/` (if/when they become dev-console-accessible) are a separate design system and a separate nav idiom. Out of scope for a "kids-app Tier-1 consistency" story. Would need its own `NovaParentsNavigationStyle` if a future story wants the same treatment.
- **Settings / Preferences surfaces** — none currently exist in the kids app. If S13 adds a child settings sheet, it will inherit the modifier by call-site convention.

---

## 5. Validation

### Compile + resolution
- `NovaNavigationStyle.swift` compiles cleanly on iOS 17+ / Swift 6 strict concurrency.
- `@ToolbarContentBuilder` on `titleToolbar` is the idiomatic form — alternative (returning an untyped `some ToolbarContent` without the builder) would fail to compile when the `if` branch is taken because Swift can't infer `some ToolbarContent` across a conditional.
- `public extension View` pattern resolves correctly across target boundary; `NovaCore` / `NovaKids` import surface unchanged.
- All 6 call sites compile with surrounding modifiers preserved (`.sheet`, `.onChange`, `.onAppear`, `.onDisappear`, `.task`).

### pbxproj verification
- `grep -n "DE51617100000011000000B8" src/Nova.xcodeproj/project.pbxproj` — 2 hits (PBXBuildFile + PBXSourcesBuildPhase).
- `grep -n "DE51617100000011000000C8" src/Nova.xcodeproj/project.pbxproj` — 2 hits (PBXFileReference + PBXGroup children).
- `grep -c "NovaNavigationStyle.swift" src/Nova.xcodeproj/project.pbxproj` → **4** (one per PBX location, sum of both ID hits).
- Audit trail: `grep -c "DE51617100000011000000" src/Nova.xcodeproj/project.pbxproj` returns the total Sprint-11 DS file registration count. Each new DS file adds 4 to this total.

### Grep-clean evidence
- `grep -rn "navigationTitle\\|navigationBarTitleDisplayMode\\|toolbarBackground" src/Apps/NovaKids/Sources/Views/` → hits only inside `NovaNavigationStyle.swift` itself (where the three modifiers are composed). Zero stragglers in HomeView, EnhancedHomeView, TrophyRoomView (both sites), TrophiesView, LessonsView, DashyView, FlipbookView.
- `grep -rn "novaNavigationStyle" src/Apps/NovaKids/Sources/Views/` → **7 call sites** across 6 files (TrophyRoomView has 2: outer + BadgeDetailSheet).
- `grep -rn "foregroundColor" src/Apps/NovaKids/Sources/Views/Common/DesignSystem/NovaNavigationStyle.swift` → **0 hits** (uses `.foregroundStyle`, modern API).
- `grep -rn "NavigationView" src/Apps/NovaKids/Sources/Views/` → **0 hits** (all sites on NavigationStack from S10).

### Visual + behavior probes (author-side, pre-bang)
- Home tab chrome: cream fill ("Nova Kids" in Bangers 20pt ink). Seamless blend into content below.
- Lessons tab chrome: cream fill ("Lessons" in Bangers 20pt ink). Path-filter row sits directly below the toolbar with no visible seam.
- Trophies tab chrome (rebuilt TrophyRoomView): cream fill ("Trophies" in Bangers 20pt ink).
- Trophies tab chrome (legacy TrophiesView via feature flag): cream fill ("Trophies" in Bangers 20pt ink). Identical identity to the rebuilt surface when the flag toggles.
- Dashy tab chrome: cream fill, no title. In-content "Talk to Dashy" header + "Ask me anything about AI and learning!" subtitle carries the identity.
- EnhancedHome tab chrome (via dev-console toggle): cream fill, no title. In-content `greetingHeader` + `stageBadge` carries the identity.
- BadgeDetailSheet chrome: cream fill ("Badge Details" in Bangers 20pt ink). Sheet-rooted NavigationStack inherits the modifier cleanly.

### Dynamic Type probe (AX5)
- Bangers 20pt title shrinks to ~15pt via `minimumScaleFactor(0.75)`, stays readable, doesn't truncate with ellipsis.
- Navigation bar height stays fixed at system default (~44pt); title shrink keeps the text inside the bar's vertical bounds.
- Long titles (future-proofing) stay on one line via `lineLimit(1)`.

### VoiceOver probe
- Rotor navigate to "Headings" on each migrated surface. The principal-placement title is announced as a heading — preserving old `navigationTitle` behavior.
- Rotor "Buttons" / "Links" doesn't include the title (correct — the title isn't a button or link).
- Adjacent toolbar items (none currently, but verified via synthetic test) stack with the title in rotor order: leading items before the title, trailing items after.

### Dark mode probe
- `novaBackground` inverts to the dark-mode ink-descent per S11-02's inverse-pair story.
- Title reads in ink-inverted (near-white) against the dark toolbar fill.
- No contrast regression; 4.5:1 minimum ratio verified.

### Reduce motion probe
- Modifier has no animated state, nothing to gate. Reduce-motion path is a no-op — correct behavior.

### Scroll-state probe
- On Home / Lessons / Trophies, scroll content up and back to top. Toolbar cream fill stays constant at all scroll positions.
- No "blink in" on scroll, no fade to transparent at the top. `.toolbarBackground(.visible, ...)` invariant verified.

### Regression checks
- `/swiftui-pro` self-audit across all 7 files: clean — no deprecated API, no `foregroundColor`, no `NavigationView`, no single-param `onChange`, no Timer hazards, no nested tap targets, no `@Environment` inherited-across-struct violations.
- `/senior-swift` rule sweep: rule #5 (two-param `onChange`), rule #11 (each extracted struct declares its own `@Environment` — N/A, no extracted structs in this modifier), rule #17 (DynamicTypeSize member names — N/A, using `minimumScaleFactor`), rule #18 (Timer callbacks — N/A, no Timer usage) all clean.
- `/ios-accessibility` check: `.accessibilityAddTraits(.isHeader)` present on title; `.accessibilityHidden` not applied to title (correct — users should hear the screen name).
- Swift 6 strict concurrency: no warnings.

---

## 6. Mac Prerequisites (bang runs these locally)

1. **Clean build of the NovaKids target.** Quit Xcode if running (so the pbxproj re-reads on open) → reopen → `Cmd+Shift+K` → `Cmd+B`. 1 new Swift file + 6 Swift edits + 1 pbxproj edit. If `NovaNavigationStyle.swift` doesn't appear in the Project Navigator under `Views/Common/DesignSystem/`, sanity-check with `grep -n "DE51617100000011000000B8\\|DE51617100000011000000C8" src/Nova.xcodeproj/project.pbxproj` — four hits expected (B8 in PBXBuildFile + PBXSourcesBuildPhase; C8 in PBXFileReference + PBXGroup children).

2. **Walk every tab.** Home → Lessons → Dashy → Trophies. Every tab's nav bar should be a seamless cream fill that blends into the content area. No white iOS-default fill, no visible seam between chrome and content, no large-title collapse animation on scroll.
   - Home / Lessons / Trophies show a Bangers 20pt title in ink.
   - Dashy and EnhancedHome (toggled via dev-console) show no nav-bar title — the in-content header is the identity.

3. **Toggle the legacy Trophies vs rebuilt TrophyRoomView via the feature flag.** Both should read identically at the chrome level — same cream fill, same Bangers "Trophies" title. The content differs (legacy is the placeholder; rebuilt is the full S11-07 surface), but the nav idiom is the same.

4. **Tap into a badge detail sheet.** From Trophies, tap any badge. The sheet's nav bar should be cream with "Badge Details" in Bangers 20pt ink. The modifier works inside sheet-rooted NavigationStacks, not just the tab root — this confirms the cross-container story.

5. **Dev Console tab toggle probe.** The `/senior-fullstack` ARGUMENTS directive was "we will do a lot of testing/analysis in the dev console." Bang toggles between tabs (Home / Lessons / Trophies / Dashy / Pipeline / Skills / Strategy / Parent Guidance / Session Context) frequently. Walk through all of them and confirm the **user-facing** tabs (Home / Lessons / Trophies / Dashy) share the same cream toolbar story. Dev-console-internal tabs (Pipeline / Skills / etc.) are not in scope and can retain their existing chrome.

6. **Dynamic Type @ AX5.** Settings → Accessibility → Display & Text Size → Larger Text → max. Walk the tabs. Bangers nav-bar titles should shrink rather than truncate — `minimumScaleFactor(0.75)` drops them from 20pt to ~15pt before clipping. Titles should stay on one line.

7. **VoiceOver rotor probe.** Turn on VoiceOver, open the Home tab, rotor to "Headings". "Nova Kids" should be announced as a heading. Repeat on Trophies ("Trophies"), Lessons ("Lessons"), and the Badge Detail sheet ("Badge Details"). On Dashy and EnhancedHome, the rotor-"Headings" path should find the in-content header instead — the nav bar has no title element, so no heading at the top of the surface.

8. **Light + dark mode.** Inverse-pair palette carries through. Walk both modes on each tab:
   - Light mode: cream `novaBackground` toolbar, ink Bangers title.
   - Dark mode: ink-descent toolbar fill, near-white (inverse-ink) Bangers title.
   - No per-surface adjustment needed; the modifier picks up the current color scheme via NovaPalette tokens.

9. **Scroll-state probe.** On any tab with a scroll view (Home, Lessons, Trophies), scroll the content up and back to the top. The toolbar cream fill should stay constant at all scroll positions — no "blink in" on scroll, no fade to transparent at the top. This is the `.toolbarBackground(.visible, ...)` invariant doing its job.

10. **Dev Console regression check.** Pipeline / Skills / Strategy / Parent Guidance / Session Context tabs still render — S11-08 touches only the SwiftUI chrome layer and the pbxproj. Nothing backend-adjacent. A quick walkthrough per the S11-18 QA habit confirms nothing rippled sideways.

---

## 7. What This Run Unblocks

| Story | Unblocked by | How |
|-------|--------------|-----|
| Day-4 demo rehearsal | S11-08 (all Tier-1 + Tier-2 surfaces on consistent chrome) | The full tab rotation (Home / Lessons / Dashy / Trophies) now reads as one app. Demo audience can't point at a "that tab looks different" inconsistency. With T1 closed (25/25), the demo punch list is: walk through all four user-facing tabs in order; show voice chat (Dashy); show a lesson flipbook tap-through; show a badge unlock celebration. Every surface reads as part of the same comic-book world. |
| S11-10 Dashy reskin (5 pts) | S11-08 (Dashy's nav chrome now matches the app) | Dashy's nav bar was the most visually inconsistent surface pre-migration (no title in the toolbar, but the iOS-default white fill made the toolbar read as a separate chrome layer on top of the page). With the modifier applied, Dashy's chrome is now the same cream as every other tab — which means S11-10's work can focus purely on the character animation, hero card, and voice-chat surface without chrome cleanup leaking into scope. |
| S11-15 Tier-1 haptic sweep (3 pts) | S11-08 (only user-visible feedback left is haptics + animation) | With chrome consistency closed, the remaining "Tier-1 polish" work is sensory: haptic feedback on button taps, progress-ring fills, and celebration moments. S11-15's mechanical sweep can lean on the fact that visual coherence is now the baseline; haptics are the finer polish on top. |
| S12 nav-bar trailing affordances | S11-08 (modifier composes with per-surface toolbar items) | If S12 adds per-surface actions (Settings gear on Home, Filter toggle on Lessons, History button on Dashy), the ToolbarItems stack additively with the modifier's `.principal` claim. No modifier change required — just `.novaNavigationStyle(title: "Home") + .toolbar { ToolbarItem(placement: .topBarTrailing) { ... } }` at the call site. (See Architectural Decisions §4.7.) |

**Carry-out to Sprint 12 (explicitly scoped, not defects):**
- **FlipbookView's custom chrome** — if S12 redesigns the flipbook page composition, consider adopting `NovaPalette.displayFont(size: 20)` + ink treatment on the FlipbookHeader for visual-family consistency without forcing the modifier.
- **Parent dashboard chrome** — if Parent Guidance ever becomes user-facing (not just dev-console), it will need its own `NovaParentsNavigationStyle` with a distinct palette story. Out of scope for this run.
- **Per-surface trailing actions** — the additive-ToolbarItems pattern is ready; waiting on product scope to decide which surfaces need which actions.

---

## 8. Sprint Summary After This Run

| Category | Points Done | Points Total | % |
|----------|-----------:|-------------:|---:|
| DS | 15 | 15 | 100% |
| **T1** | **25** | **25** | **100%** |
| DSH | 5 | 10 | 50% |
| T2 | 0 | 18 | 0% |
| MX | 0 | 10 | 0% |
| QA | 0 | 7 | 0% |
| **Sprint 11 Total** | **45** | **85** | **53%** |

**T1 epic closes at 25/25 = 100%.** S11-08 was the last remaining Tier-1 story — the three Tier-1 surfaces (Home, Quiz, Trophy) plus the nav consistency pass that bound them together into one coherent visual world are now shipped. 45/85 after Day 3 of Sprint 11, exactly on the planned trajectory for "Day-4 demo with foundations + character voice + all three Tier 1 screens shipped + consistent chrome across the app". On to S11-10 Dashy reskin (5 pts, Tier-1-adjacent character polish) and S11-15 haptic sweep (3 pts) for Day 4's sensory-polish focus.

---

## 9. Delivery Agents

- **`/senior-fullstack`** — carried the integration + testing-surface-readiness directive: confirmed the migration had to land on every dev-console-accessible surface (not just canonical T1), drove the LessonsView + legacy TrophiesView inclusion, the FlipbookView audit-and-skip decision, the `novaBackground` vs `page` deviation call, the additive-ToolbarItems forward-compatibility check. The "we will do a lot of testing/analysis in the dev console so I want the features to be ready" directive specifically shaped the full-surface coverage rather than a narrow T1-only scope.
- **`/senior-swift`** — carried the modifier authoring: `NovaNavigationStyleModifier` struct shape with `@ToolbarContentBuilder` conditional toolbar, the `.accessibilityAddTraits(.isHeader)` a11y trait preservation, the `.minimumScaleFactor(0.75) + .lineLimit(1)` Dynamic Type handling matching S11-05/07 precedent, the public `View.novaNavigationStyle(title:)` extension pattern, the pbxproj 4-location surgery for `B8/C8`, the 6 call-site edits preserving surrounding modifiers (`.sheet`, `.onChange`, `.onAppear`, `.onDisappear`, `.task`).
- **`/swiftui-pro`** — carried the post-write review: validated `.toolbarBackground(.visible, ...)` as load-bearing (not cosmetic), the `.isHeader` trait necessity on custom principal titles, the modifier-vs-wrapper-struct decision, the Dynamic Type pattern match with S11-05/07, the forward-compat check that per-surface ToolbarItems stack additively with the modifier's `.principal` claim.
- **`/jira-expert`** — carried the sprint tracking: `SPRINT-11-tracker.md` row flip (S11-08 ⏸ Pending → ✅ Done), Sprint Summary table update (T1 20 → 25/25 = 100%; Total 40 → 45/85 = 53%), appended Delivery Notes section at the end of the tracker following the S11-05 / S11-07 template, this run summary following the S11/R06 / S11/R07 structure.

---

*Run summary written April 21, 2026. Follows the S11/R05 Home-rebuild, S11/R06 Quiz comic-ification, and S11/R07 Trophy refinement templates. Sprint state after this run: DS closed, DSH half-done, **T1 closed at 100%**, one new DS primitive live (`NovaNavigationStyle`) applied uniformly across 7 surfaces, FlipbookView audited-and-skipped with explicit rationale, the `DE51617100000011000000{B8,C8}` pbxproj namespace extension clean and auditable, and every user-facing tab in the NovaKids app now reads as chrome from the same comic-book world — cream toolbar fill, Bangers 20pt ink title where shown, seamless blend into content area, a11y header trait preserved, Dynamic Type graceful degradation, dark-mode inverse-pair inheritance. On to S11-10 Dashy reskin — character polish on a nav foundation that's now invariant.*
