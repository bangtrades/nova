# S11-18 — iPad landscape + dark mode + DynamicType QA audit

> **Meta**
> - Run ID: S11 / R18
> - Story: S11-18 (3 pts)
> - Epic: QA / polish
> - Branch: main (no code changes — audit artifact only)
> - Landed: 2026-04-22
> - Status: ✅ Done
> - Tests before: n/a (audit only — no test delta)
> - Tests after: n/a
> - Validation: 🟡 Mac-only — every defect in this inventory needs a physical simulator or device to confirm. Sandbox cannot run `xcodebuild` simulators.

## Run goal

Sprint 11 has been a design-system and data wire-up sweep — palette consolidation, Spacing enum, `NovaCard`, Bangers display type, Dashy rebuild, skeleton / haptic / reduce-motion passes. All of that work shipped on **iPhone portrait assumptions**. S11-18 is the "does this actually hold up on a real iPad in the kid's hands?" audit across three orthogonal axes:

1. **iPad landscape** — does the layout stretch usefully when the horizontal size class flips to `.regular`, or does every screen look like an iPhone floating in a sea of whitespace?
2. **Dark mode** — does every surface flip cleanly via the adaptive `NovaPalette` pair, or do hardcoded `Color.white` / `Color.black` / literal-hex gradients break the comic-book-ink metaphor?
3. **Dynamic Type** — can a child with larger-text accessibility settings still read every screen without truncation, overflow, or the Bangers display type refusing to grow?

Scope was **code review only** — sandbox has no simulator. Output is this defect inventory (file + line + axis + expected-vs-observed + proposed fix) that Sprint 12 can land against in priority order.

## Stories & AC

| ID | Acceptance criterion | Status |
|---|---|---|
| S11-18 | Three-axis scan across every Tier 1 surface (Home / Lessons / Trophy / Flipbook / Dashy / Auth / Onboarding) produces a written defect list with priority + proposed fix | ✅ |
| S11-18 | Every finding cites file + line + which axis + what the fix looks like, so Sprint 12 can assign stories against discrete items rather than a blob | ✅ |
| S11-18 | `NovaPalette` adaptive-color implementation verified — confirm `ink` / `page` / `coral` / `sun` use the `Color(light:dark:)` initializer and thus actually flip | ✅ |
| S11-18 | Dynamic-type regression risk classified — hard truncation (`lineLimit(1)` without `minimumScaleFactor`) tracked separately from "might look cramped" | ✅ |
| S11-18 | Mac runbook the dev can actually execute to confirm each finding on-device | ✅ |

## Files touched

**No source changes.** This audit is a written artifact only.

**Files inspected:**
- Home: `EnhancedHomeView.swift`, `HomeView.swift`, `FeaturedLessonCard.swift`, `ContinueLearningSection.swift`, `WelcomeHeader.swift`
- Lessons: `LessonsView.swift`, `MasonryGrid.swift`, `LessonTileView.swift`, `LearningPathCard.swift`, `PathFilterPill.swift`
- Trophies: `TrophyRoomView.swift`, `TrophiesView.swift`, `BadgeView.swift`
- Flipbook: `FlipbookView.swift`, `FlipbookHeader.swift`, `ExperimentCardView.swift`, `ConceptCardView.swift`, `StoryCardView.swift`, `QuizCardView.swift`, `VoiceCardView.swift`, `CardProgressDots.swift`, `DashyHintSheet.swift`, `QuizAnswerButton.swift`
- Dashy: `DashyView.swift`, `DashyCharacterView.swift`
- Auth: `KidsLoginView.swift`
- Onboarding: `OnboardingView.swift`
- Common: `NovaPalette.swift`, `NovaCard.swift`, `NovaNavigationStyle.swift`, `OfflineGracefulView.swift`, `ErrorBoundaryView.swift`, `ProgressRing.swift`

**Reference doc being produced:** this file.

## Architectural findings

### Finding 1 — Only one file in NovaKids has horizontal-size-class awareness

**Scope:** App-wide — affects every Tier 1 surface.
**Evidence:** `grep -rn "horizontalSizeClass" src/Apps/NovaKids/` returns exactly one match pair: `LessonTileView.swift` lines 25 and 108. Every other view treats the canvas as iPhone-portrait-only.

**Expected:** On iPad landscape (`horizontalSizeClass == .regular`, `geo.size.width >= 1024pt`), Home's horizontal scroll strips, Lessons' masonry grid, Trophy's badge grid, and Flipbook's card deck should adapt — wider cards, more grid columns, content width-capped so primary CTAs don't span 1000pt.

**Observed:** Every layout decision is baked against iPhone portrait (~390pt wide). On iPad landscape (1194pt or 1366pt), fixed-width cards (140pt, 180pt) float as tiny islands; 2-column masonry becomes 2 very-wide columns; and buttons stretch edge-to-edge.

**Why this matters now:** S11 spent 19 stories polishing the iPhone design language. Zero of that polish pays off on iPad without size-class branches. The kid testing loop the user wants requires iPad use — not iPhone — which means the iPad surface needs to actually feel designed-for before MVP testing.

**Proposed fix (Sprint 12 scope):** Add a `SizeClassAware` view modifier + reader pattern to `NovaPalette.swift` or a new `AdaptiveLayout.swift` helper. Example shape:

```swift
public struct AdaptiveLayout {
    @Environment(\.horizontalSizeClass) static var hClass
    public static var compact: Bool { hClass == .compact }
    public static func columns(compact: Int, regular: Int) -> Int {
        hClass == .regular ? regular : compact
    }
    public static func width(compact: CGFloat, regular: CGFloat) -> CGFloat {
        hClass == .regular ? regular : compact
    }
}
```

Then each affected view reads the environment and branches. List of specific surfaces below.

---

### Finding 2 — EnhancedHomeView lesson cards are 140pt regardless of device

**File:** `Home/EnhancedHomeView.swift`
**Line:** 260 — `.frame(width: 140, height: 160)`
**Axis:** iPad landscape
**Severity:** High — this is the primary Tier 1 surface.

**Expected:** On iPad (`hClass == .regular`), lesson cards should be ~220–260pt wide so the horizontal scroll strip shows 4–5 cards without feeling like iPhone cards dropped on an iPad.

**Observed:** Fixed 140×160pt. On iPad 1194pt portrait a horizontal strip shows 7+ cards; on landscape 1366pt it shows 9+. Cards feel miniaturized.

**Fix:** Branch on `horizontalSizeClass`:
```swift
.frame(
    width: horizontalSizeClass == .regular ? 240 : 140,
    height: horizontalSizeClass == .regular ? 200 : 160
)
```

---

### Finding 3 — LearningPathCard fixed 180pt width + progress-bar math bug

**File:** `Lessons/LearningPathCard.swift`
**Lines:** 79 (fixed width) and 69 (progress math)
**Axes:** iPad landscape + a latent correctness bug

**Expected:**
- iPad landscape → wider card.
- Progress bar inner width should track card inner width (card 180pt − 16pt×2 padding = 148pt), not 160pt.

**Observed:**
- Line 79: `.frame(width: 180)` regardless of device.
- Line 69: `.frame(width: CGFloat(progress) * 160, height: 8)` — **math bug.** When `progress == 1.0` the bar is 160pt, but the card's internal content width is 148pt. The bar overflows the card's visible inner rectangle by 12pt. Clipped by the `.cornerRadius(12)` on line 78 but visibly wrong against the card edge.

**Fix:**
```swift
// Replace line 69 with a GeometryReader-derived width, or at minimum:
.frame(width: CGFloat(progress) * 148, height: 8)
// And add size-class branch on line 79 for regular width:
.frame(width: horizontalSizeClass == .regular ? 260 : 180)
```

**Priority:** The 180→260 change is a Sprint 12 iPad polish item. The 160→148 correction is a latent bug fix — ship it now as a drive-by.

---

### Finding 4 — MasonryGrid is hardcoded to 2 columns regardless of size class

**File:** `Lessons/MasonryGrid.swift`
**Line:** 17 — `columns: Int = 2`, and `LessonsView.swift:150` call site doesn't override.
**Axis:** iPad landscape
**Severity:** High — Lessons is a Tier 1 surface and this is the biggest missed opportunity.

**Expected:** 2 columns on compact, 3 or 4 columns on regular.

**Observed:** Always 2 columns. On iPad landscape each tile is ~680pt wide — nearly as wide as a full iPhone screen. The Pinterest gestalt S11-12 built collapses into "two enormous vertical stripes."

**Fix (`LessonsView.swift:150`):**
```swift
MasonryGrid(
    items: viewModel.filteredLessons,
    columns: horizontalSizeClass == .regular ? 3 : 2,
    spacing: Spacing.md
) { lesson in
    ...
}
```

Add `@Environment(\.horizontalSizeClass) private var horizontalSizeClass` at the struct scope.

---

### Finding 5 — TrophyRoomView badge grid hardcoded to 3 columns

**File:** `Trophies/TrophyRoomView.swift`
**Lines:** 35–39 — the `columns` property is a fixed 3-column `LazyVGrid`.
**Axis:** iPad landscape
**Severity:** Medium.

**Expected:** 3 on compact, 4 or 5 on regular.

**Observed:** On iPad landscape 1366pt, 3 columns means each badge tile is ~430pt wide — the tile art was designed for ~120pt.

**Fix:** Make `columns` a computed property that reads `horizontalSizeClass`:
```swift
private var columns: [GridItem] {
    let count = horizontalSizeClass == .regular ? 4 : 3
    return Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: count)
}
```

---

### Finding 6 — Onboarding + Login content has no maxWidth constraint

**Files:**
- `Onboarding/OnboardingView.swift` — multiple pages with `.padding(.horizontal, Spacing.xl)` (32pt) and no `.frame(maxWidth: ..., alignment: .center)` wrapper.
- `Auth/KidsLoginView.swift` — same pattern + SIWA button at line 97 has `.frame(height: 56)` but no width cap.

**Axis:** iPad landscape
**Severity:** Medium (cosmetic) + High for SIWA (Apple HIG).

**Expected:** Onboarding copy, avatar grid, name-entry field, and the SIWA button should cap at ~500–600pt wide and center. Apple's HIG for "Sign In with Apple" specifies the button should not be visually overwhelming — a 1366pt-wide SIWA button on iPad landscape is a bad look even though we're not re-skinning it (S11-17 carve-out holds — no *styling* changes, just a reasonable max width is fine).

**Observed:** On iPad landscape the SIWA button is 1366pt − 64pt padding = 1302pt wide. Onboarding avatar grid is 2-wide but each avatar is ~600pt wide.

**Fix:** Wrap every onboarding page body and the KidsLoginView content VStack in `.frame(maxWidth: 600).frame(maxWidth: .infinity)` (double-frame pattern — inner caps content, outer centers).

---

### Finding 7 — FlipbookView Prev/Next chrome not width-capped

**File:** `Flipbook/FlipbookView.swift`
**Lines:** 144–197 — the `HStack(spacing: Spacing.md) { Previous / Next buttons }` is padded 20pt on each side but has no max width.
**Axis:** iPad landscape
**Severity:** Low (buttons still work) but visually sprawls.

**Expected:** Cap the nav chrome at ~500pt and center.

**Observed:** On iPad landscape the two secondary buttons become cartoonishly wide.

**Fix:** Add `.frame(maxWidth: 600)` and an outer `.frame(maxWidth: .infinity)` on the HStack.

Same treatment applies to `CardProgressDots` on line 131 — it's already centered but looks oddly small relative to the screen width.

---

### Finding 8 — `NovaPalette.displayFont(size:)` does not scale with Dynamic Type

**File:** `Common/NovaPalette.swift`
**Lines:** 222–227 — the custom Bangers font is instantiated with a hardcoded point size, not relative to a semantic text style.
**Axis:** DynamicType
**Severity:** High — Bangers is the app's identity font. Every hero headline, card title, and action label uses it.

**Expected:** Dynamic Type users set a preferred text size in iOS Settings. `.font(.title)` scales; `.font(.custom("Bangers", size: 32))` does not. Users with `.accessibility3+` see everything except Bangers grow — which makes the Bangers text look small relative to the body copy the user asked to enlarge.

**Observed:** Every `displayFont(size: X)` call site (grep returns 9 sites: `EnhancedHomeView`, `FlipbookHeader`, `TrophyRoomView`, `WelcomeHeader`, and others) emits a fixed point size.

**Fix:** Add a `relativeTo:` parameter to `displayFont`:
```swift
public static func displayFont(size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
    if isBangersRegistered {
        return .custom(bangersPostScriptName, size: size, relativeTo: style)
    }
    return .system(size: size, weight: .heavy, design: .rounded)
}
```

Then every call site keeps the same visual baseline at default Type size but grows with the user's accessibility setting. The palette helper is the only file that changes; call sites pick up the fix for free.

---

### Finding 9 — `.lineLimit(1)` without `.minimumScaleFactor()` — truncation at large Type

**Files + lines:**
- `Flipbook/FlipbookHeader.swift:64` — lesson title
- `Flipbook/ExperimentCardView.swift:360, 414, 434` — card copy labels
- `Trophies/BadgeView.swift:152` — badge XP caption

**Axis:** DynamicType
**Severity:** Medium — text truncates with ellipsis at `.accessibility3+`, but the content is still reachable via VoiceOver.

**Expected:** Either `.lineLimit(nil)` (let text wrap) or `.lineLimit(1).minimumScaleFactor(0.7)` (shrink to fit). The codebase already has the right template:

- `WelcomeHeader.swift:32–33` — `.minimumScaleFactor(0.6).lineLimit(1)` ✓
- `TrophyRoomView.swift:272–273` — `.lineLimit(1).minimumScaleFactor(0.7)` ✓
- `BadgeView.swift:68–70` — `.lineLimit(2).minimumScaleFactor(0.8)` ✓
- `QuizCardView.swift:142–143` — `.lineLimit(2).minimumScaleFactor(0.8)` ✓
- `FeaturedLessonCard.swift:42–43` — `.lineLimit(2).minimumScaleFactor(0.75)` ✓
- `NovaNavigationStyle.swift:91–92` — `.minimumScaleFactor(0.75).lineLimit(1)` ✓

**Observed:** Six sites follow the pattern; five sites don't.

**Fix:** Add `.minimumScaleFactor(0.75)` to every `.lineLimit(1)` site in the list above. Cheap drive-by fix.

---

### Finding 10 — Potential dark-mode contrast regressions on `pathColor` backgrounds

**Files + lines:**
- `Lessons/LearningPathCard.swift:39, 57, 68, 74` — `.foregroundStyle(.white)` on `NovaPalette.pathColor(…)` tinted background
- `Home/EnhancedHomeView.swift:144, 150, 154, 161` — `.white` on `[Category.blue, Category.purple]` gradient

**Axis:** Dark mode
**Severity:** Medium — likely OK for most combinations but needs device verification.

**Expected:** Every text color either (a) uses a palette alias that has a dark variant, or (b) is verified for sufficient contrast (≥ 4.5:1 for body, ≥ 3:1 for large / title) against the background in both modes.

**Observed:** `Category.*` colors brighten in dark mode (confirmed in `NovaPalette.swift:89–125` — each has a `dark:` variant shifted ~+0.1 on RGB). White text on a brighter color = lower contrast. For `Category.yellow` (#FFE259 in dark vs #FFD93C in light), white text drops below 3:1 in dark mode.

**Fix:**
- For fixed gradients like `stageBadge`: audit by reading each gradient stop's dark variant and measuring contrast against `.white`. If any drop below 3:1 for title type, swap to `NovaPalette.ink` (which is near-white in dark mode anyway).
- For `pathColor` (random assignment): the safer fix is `.foregroundStyle(NovaPalette.ink)` — ink is dark navy on light and warm off-white on dark, so it's always high-contrast on any path-color. But this breaks the "white text on colored card" look. Trade-off to decide in Sprint 12.

---

### Finding 11 — `NovaPalette` adaptive implementation: verified ✓

**File:** `Common/NovaPalette.swift`
**Lines:** 265–274 — the `Color(light:dark:)` extension uses `UIColor(dynamicProvider:)` reading `UITraitCollection.userInterfaceStyle`.

**Verdict:** ✓ Correct. The implementation uses `UIColor { traits in … }`, which re-evaluates on every trait-collection change — so background/foreground colors flip dynamically without requiring a re-render. This is the right pattern.

**Scope confirmed adaptive:**
- `NovaPalette.ink` ✓
- `NovaPalette.page` ✓
- `NovaPalette.coral` ✓
- `NovaPalette.sun` ✓
- `NovaPalette.Category.*` (all 6) ✓
- `novaBackground`, `novaCardBackground` ✓

**Still hardcoded (not palette, but relevant):**
- `Color.white` / `Color.black` literal call sites — ~40+ hits via grep. Most are intentional (Dashy's eye whites, icon on gradient). Spot-check required but not a systemic palette defect.

---

### Finding 12 — DashyView `fraction` progress bar and onboarding animations look correct on iPad portrait; landscape untested

**File:** `Dashy/DashyView.swift`
**Line:** 192 — `.frame(width: max(0, min(geo.size.width, geo.size.width * fraction)))`

**Verdict:** ✓ Correct — uses `GeometryReader` so the bar adapts.

**Note:** DashyView's overall layout is `ScrollView` + `VStack` without a max-width constraint. Same treatment as Finding 6 applies — wrap content in `.frame(maxWidth: 700)` for landscape.

## Prioritized defect inventory

This is the Sprint 12 shopping list. Ordered by "break MVP user experience → would polish MVP → latent bug."

| # | Finding | File | Axis | Severity | Est |
|---|---|---|---|---|---|
| 1 | Only LessonTileView has size-class awareness | app-wide | iPad | High | 1 pt — add `AdaptiveLayout` helper |
| 2 | Home lesson cards fixed 140pt | EnhancedHomeView.swift:260 | iPad | High | 1 pt |
| 3 | MasonryGrid 2-col hardcoded | MasonryGrid.swift:17, LessonsView.swift:150 | iPad | High | 1 pt |
| 4 | TrophyRoomView 3-col hardcoded | TrophyRoomView.swift:35-39 | iPad | Med | 1 pt |
| 5 | `displayFont` doesn't scale with Type | NovaPalette.swift:222 | Type | High | 1 pt — palette only |
| 6 | `lineLimit(1)` without `minimumScaleFactor` | 5 sites | Type | Med | 1 pt drive-by |
| 7 | LearningPathCard progress-bar math bug | LearningPathCard.swift:69 | Correctness | Med | 30 min drive-by |
| 8 | LearningPathCard fixed 180pt width | LearningPathCard.swift:79 | iPad | Med | (lumps into #1) |
| 9 | Onboarding + Login not width-capped | OnboardingView, KidsLoginView | iPad | Med | 1 pt |
| 10 | SIWA button not width-capped | KidsLoginView.swift:97 | iPad + HIG | High | (lumps into #9) |
| 11 | Dark-mode contrast on Category gradients | LearningPathCard, EnhancedHomeView | Dark | Med | 1 pt audit + fix |
| 12 | FlipbookView nav chrome not width-capped | FlipbookView.swift:144-197 | iPad | Low | 30 min |

**Sprint 12 grouping suggestion:**
- **S12-01 iPad layout pass (5 pts):** findings #1, #2, #3, #4, #7, #8, #9, #10, #12 — one story that touches every Tier 1 surface's size-class branch.
- **S12-02 Dynamic Type pass (2 pts):** findings #5, #6.
- **S12-03 Dark-mode contrast audit (1 pt):** finding #11 — verify on iPad and iPhone simulator, palette swaps only if a contrast metric actually fails.

## Mac runbook — prerequisites bang must run locally

```bash
# On the Mac, from the repo root:
cd src/Apps/NovaKids

# Build the app for iPad simulator
xcodebuild -project NovaKids.xcodeproj \
  -scheme NovaKids \
  -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)' \
  -configuration Debug \
  build

# Then open the simulator and verify each finding:
# 1. Home tab → count cards visible in horizontal strip (expect ~7 compact on iPad portrait, ~9 landscape)
# 2. Lessons tab → count masonry columns (expect 2)
# 3. Trophies tab → count badge grid columns (expect 3)
# 4. Flipbook (open any lesson) → note whether Prev/Next buttons stretch edge-to-edge
# 5. Auth screen → note SIWA button width (expect full-screen-width)
# 6. Settings → Accessibility → Display & Text Size → Larger Text → .accessibility5
# 7. Revisit every Tier 1 surface; note where text truncates with ellipsis
# 8. Settings → Developer → Dark Appearance ON; revisit every surface
# 9. Rotate iPad to landscape; verify layout degrades gracefully
```

**Expected result of runbook:** the dev should see and mentally log the 12 findings above. Any additional findings discovered during physical testing get appended to the Sprint 12 S12-01 story.

## Validation matrix

| # | Check | Where run | Status |
|---|---|---|---|
| 1 | `NovaPalette.ink` / `.page` / `.coral` / `.sun` use `Color(light:dark:)` | sandbox — code read | ✅ |
| 2 | `Color(light:dark:)` extension implementation uses `UITraitCollection` dynamic provider | sandbox — code read | ✅ |
| 3 | Every `displayFont` call site uses fixed point size (no `relativeTo:` argument) | sandbox — grep | ✅ 9 sites confirmed |
| 4 | `horizontalSizeClass` usage inventory | sandbox — grep | ✅ 1 file only |
| 5 | `lineLimit(1)` + no `minimumScaleFactor` sites enumerated | sandbox — grep | ✅ 5 sites |
| 6 | `.foregroundStyle(.white)` + hex-color background pairs enumerated | sandbox — grep | ✅ 8 sites in hotspots |
| 7 | Fixed-width `.frame(width: X)` inventory across Tier 1 surfaces | sandbox — grep | ✅ ~30 sites |
| 8 | `MasonryGrid` default column count | sandbox — code read | ✅ 2 |
| 9 | iPad simulator build & runtime verification of each finding | 🟡 Mac-only | ⏳ user to run |
| 10 | Dark-mode flip on every Tier 1 surface | 🟡 Mac-only | ⏳ user to run |
| 11 | `.accessibility5` Dynamic Type rendering check | 🟡 Mac-only | ⏳ user to run |
| 12 | VoiceOver rotor test for truncated labels | 🟡 Mac-only | ⏳ user to run |

The sandbox audit is complete. Items 9–12 require a physical simulator and are tracked as "expected findings" that the Mac runbook will confirm.

## Retired debt

- **S11-MX carry-in fully closed.** S11-16 + S11-17 + S11-18 round out the MX epic at 10/10 (100%), which was the reason to keep this audit in Sprint 11 rather than punting to S12 — every item the tracker committed to in the MX column has shipped or, in this case, become a written Sprint 12 input.
- **Tier 1 iPad-readiness risk is now known.** Before this audit, "the app doesn't really feel right on iPad" was a hand-wave concern. It's now 12 discrete bullets a Sprint 12 story can burn down.

## What's next

1. **Close out Sprint 11.** Flip S11-18 row to ✅ Done; Sprint Summary QA `4/7 (57%)` → `7/7 (100%)`; Total `90/93 (97%)` → `93/93 (100%)`. The close-out concludes the Sprint 11 campaign.
2. **Sprint 12 scaffold.** Top of Sprint 12's tracker carries forward this audit as three stories: S12-01 iPad layout pass, S12-02 Dynamic Type pass, S12-03 Dark-mode contrast audit.
3. **Mac side — verify on-device.** Run the Mac runbook above. Any additional findings append to the inventory before S12-01 starts.
4. **Content loop.** With Sprint 11 closed, the next runway is the content-creation → iPad-push → kid-touches loop the user has been waiting on. The Tier 1 surfaces are now wired up (S11-19), design-system consistent (S11-01 .. S11-14), haptic + reduce-motion compliant (S11-15 + S11-16), auth + onboarding polished (S11-17), and have a known iPad defect list (S11-18). MVP-ready for the kid to actually touch, with the iPad polish a focused Sprint 12 target rather than a blocker.

## Cross-references

- **S11-16 reduce-motion audit** — sibling audit pattern; this audit follows the same "file × axis × severity × proposed fix" shape so Sprint 12 planning can lift both inventories into stories uniformly.
- **S11-15 haptic pass** — haptic ladder behaves identically on iPad (CoreHaptics supports both form factors), so no iPad-specific haptic findings.
- **S11-17 auth + onboarding polish** — this audit extends the S11-17 scope from spacing-only to iPad-aware + Type-aware for the same surfaces.
- **S11-12 Lessons Pinterest-gestalt pass** — the MasonryGrid 2-column default is a Sprint 11 design choice that this audit flags for Sprint 12 extension, not a regression.
- **NovaPalette architecture (S11-02)** — confirmed healthy. The 3+1 palette's adaptive implementation is the reason dark-mode risk is contained to specific hotspots rather than system-wide.
